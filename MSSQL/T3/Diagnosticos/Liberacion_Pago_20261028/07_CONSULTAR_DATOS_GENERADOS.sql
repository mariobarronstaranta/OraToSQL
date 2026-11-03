/*
  Consultar en T3QA despues de PROC_CFDI_LIBERACION_PAGO.
  Solo lectura de tablas de negocio; usa tablas temporales de sesion.
  @PID NULL selecciona la ultima corrida registrada, incluso si no cerro.
  Las salidas no guardan PID: fechas y claves permiten relacionarlas, pero
  no atribuirlas exclusivamente a una corrida si hubo concurrencia.
  El layout no tiene fecha: se muestra su estado actual por asignacion.
  No se reconstruyen candidatos omitidos ni se certifican altas sin baseline.
*/
USE [T3QA];
SET NOCOUNT ON;

DECLARE @PID numeric(10,0) = NULL; -- Opcional: PID concreto de RF_PROCESOS_LOG.
DECLARE @VerLayoutCompleto bit = 0; -- Cambiar a 1 para ver Informacion completa.
DECLARE @Desde datetime, @Hasta datetime, @Fin datetime;

IF @PID IS NULL
    SELECT TOP (1) @PID = PID
    FROM T3.RF_PROCESOS_LOG
    WHERE Proceso = 613
    ORDER BY Inicio DESC, PID DESC;

SELECT @Desde = Inicio, @Fin = Fin
FROM T3.RF_PROCESOS_LOG
WHERE Proceso = 613 AND PID = @PID;
IF @Desde IS NULL
    THROW 52795, 'No se encontro la corrida del proceso 613. Revisar @PID.', 1;
SET @Hasta = ISNULL(@Fin, GETDATE());
IF @Hasta < @Desde
    THROW 52796, 'La fecha final de la corrida es anterior al inicio.', 1;

SELECT '01_CORRIDA' AS Seccion, @@SERVERNAME AS Servidor, DB_NAME() AS BaseDatos,
       L.*, @Hasta AS HastaConsultado,
       CASE WHEN @Fin IS NULL THEN 'SIN CIERRE: RESULTADOS PARCIALES'
            ELSE 'CORRIDA CERRADA' END AS EstadoConsulta
FROM T3.RF_PROCESOS_LOG L WHERE L.Proceso = 613 AND L.PID = @PID;

DROP TABLE IF EXISTS #LP07Ids;
-- Usar ambas marcas permite incluir documentos insertados antes de un fallo
-- del UPDATE de cobranza. No aplicar de nuevo los filtros de pendientes.
SELECT K.Asignacion_ID INTO #LP07Ids
FROM (
    SELECT C.Asignacion_ID COLLATE DATABASE_DEFAULT AS Asignacion_ID
    FROM T3.CFDI_Cobranza C
    WHERE C.Fecha_Envio >= @Desde AND C.Fecha_Envio <= @Hasta
      AND C.Asignacion_ID IS NOT NULL
    UNION
    SELECT D.Nota_Venta COLLATE DATABASE_DEFAULT
    FROM T3.CFDI_Documentos D
    WHERE D.Fecha_Liberacion >= @Desde AND D.Fecha_Liberacion <= @Hasta
      AND EXISTS (SELECT 1 FROM T3.CFDI_Cobranza C
                  WHERE C.Asignacion_ID = D.Nota_Venta)
) K;

-- Conteos por separado evitan multiplicar importes por joins uno-a-muchos.
SELECT '02_RESUMEN_POR_ASIGNACION' AS Seccion, K.Asignacion_ID,
       C.CobranzasActuales, C.ImporteCobranzaActual, C.MarcasEnVentana,
       D.DocumentosActuales, D.LiberadosEnVentana, E.LayoutsActuales
FROM #LP07Ids K
OUTER APPLY (
    SELECT COUNT_BIG(*) AS CobranzasActuales, SUM(C.Importe) AS ImporteCobranzaActual,
           COUNT_BIG(CASE WHEN C.Fecha_Envio >= @Desde AND C.Fecha_Envio <= @Hasta
                          THEN 1 END) AS MarcasEnVentana
    FROM T3.CFDI_Cobranza C WHERE C.Asignacion_ID = K.Asignacion_ID
) C
OUTER APPLY (
    SELECT COUNT_BIG(*) AS DocumentosActuales,
           COUNT_BIG(CASE WHEN D.Fecha_Liberacion >= @Desde AND D.Fecha_Liberacion <= @Hasta
                          THEN 1 END) AS LiberadosEnVentana
    FROM T3.CFDI_Documentos D WHERE D.Nota_Venta = K.Asignacion_ID
) D
OUTER APPLY (
    SELECT COUNT_BIG(*) AS LayoutsActuales
    FROM T3.CFDI_DOCUMENTOS_ENVIAR E WHERE E.Nota_Venta = K.Asignacion_ID
) E
ORDER BY K.Asignacion_ID;

SELECT '03_COBRANZA_ESTADO_ACTUAL' AS Seccion,
       CASE WHEN C.Fecha_Envio >= @Desde AND C.Fecha_Envio <= @Hasta
            THEN 1 ELSE 0 END AS MarcaEnVentana, C.*
FROM T3.CFDI_Cobranza C
WHERE EXISTS (SELECT 1 FROM #LP07Ids K WHERE K.Asignacion_ID = C.Asignacion_ID)
ORDER BY C.Asignacion_ID, C.Factura;

SELECT '04_DOCUMENTOS_PAGO_ESTADO_ACTUAL' AS Seccion,
       CASE WHEN D.Fecha_Liberacion >= @Desde AND D.Fecha_Liberacion <= @Hasta
            THEN 1 ELSE 0 END AS LiberadoEnVentana, D.*
FROM T3.CFDI_Documentos D
WHERE EXISTS (SELECT 1 FROM #LP07Ids K WHERE K.Asignacion_ID = D.Nota_Venta)
ORDER BY D.Nota_Venta, D.Fecha_Liberacion;

SELECT '05_LAYOUTS_ACTUALES' AS Seccion, E.Nota_Venta,
       DATALENGTH(E.Informacion) AS BytesLayout,
       LEFT(E.Informacion, 500) AS InicioLayout,
       CASE WHEN @VerLayoutCompleto = 1 THEN E.Informacion END AS LayoutCompleto
FROM T3.CFDI_DOCUMENTOS_ENVIAR E
WHERE EXISTS (SELECT 1 FROM #LP07Ids K WHERE K.Asignacion_ID = E.Nota_Venta)
ORDER BY E.Nota_Venta;

-- Documento de venta original: contexto preexistente, no alta del liberador.
SELECT '06_DOCUMENTOS_VENTA_RELACIONADOS' AS Seccion, D.*
FROM T3.CFDI_Documentos D
WHERE EXISTS (
    SELECT 1 FROM T3.CFDI_Cobranza C
    INNER JOIN #LP07Ids K ON K.Asignacion_ID = C.Asignacion_ID
    WHERE C.Nota_Venta = D.Nota_Venta
)
ORDER BY D.Nota_Venta;

-- Incluye errores sin salida generada; Referencia puede ser Folio_ID.
-- RF_ERROR_LOG no tiene PID: estos errores son de la ventana, no exclusivos.
SELECT '07_ERRORES_GENERADOR_EN_VENTANA' AS Seccion, E.*
FROM T3.RF_ERROR_LOG E
WHERE E.Fecha >= @Desde AND E.Fecha <= @Hasta
  AND E.Rutina LIKE '%GENERAR_PAGO%'
ORDER BY E.Fecha;

SELECT '08_ERRORES_COORDINADOR_POR_PID' AS Seccion, M.*
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG M
WHERE M.JOB_PID = @PID AND M.QUEUE_NAME = 'PROC_CFDI_LIBERACION_PAGO'
ORDER BY M.CREATED;

SELECT '09_COMPONENTE_ESTADO_ACTUAL' AS Seccion, Component, Status, Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component = 613;

SELECT '10_ALCANCE' AS Seccion,
 N'Seleccion por fechas y asignacion; las salidas no guardan PID. Los detalles muestran el estado actual, que puede incluir cambios posteriores. Layouts sin fecha: su existencia no demuestra un alta en esta corrida. Proceso_1 cuenta filas recorridas, no pagos generados. Revisar Folio_Fiscal/Fecha_Timbre para el estado actual de timbrado.' AS Observacion;

DROP TABLE #LP07Ids;
