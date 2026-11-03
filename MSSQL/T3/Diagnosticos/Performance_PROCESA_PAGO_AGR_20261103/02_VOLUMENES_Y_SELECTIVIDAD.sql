/* SOLO LECTURA de datos permanentes. No ejecuta agrupador, CHECK o generador,
   no consume secuencias y no modifica fechas. Crea temporales locales de sesion.
   Puede leer muchas filas y usar tempdb: ejecutar primero 01_METADATOS_Y_TIEMPOS.
   Modelo del ESTADO ACTUAL, antes del UPDATE de Asignacion_Central de una nueva
   ejecucion. No reconstruye candidatos ya marcados por una corrida anterior.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @nDias numeric(18,0)=30; -- Ajustar al parametro real: NULL se interpreta como 0.
DECLARE @AnalizarLiberacion bit=0; -- 1 agrega joins de pagos/documentos y repeticion de factura.
DECLARE @RevisarAsignacionCentral bit=0; -- 1 ejecuta el JOIN de lectura equivalente al UPDATE inicial.
DECLARE @Captura datetime=GETDATE();
DECLARE @Limite date=CAST(DATEADD(DAY,-ISNULL(@nDias,0),@Captura) AS date),
        @Ejercicio varchar(4)=CONVERT(varchar(4),YEAR(@Captura));
SELECT '00_CONTEXTO' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,@Captura Captura,@nDias nDias,
    @Limite LimiteExclusivoFechaProceso,@Ejercicio EjercicioAsignacion;

-- Solo temporales con nombres reservados para este diagnostico; permite
-- reejecutarlo en la misma sesion si una consulta previa se interrumpio.
IF OBJECT_ID('tempdb..#PerfAGR_Controles') IS NOT NULL DROP TABLE #PerfAGR_Controles;
IF OBJECT_ID('tempdb..#PerfAGR_Grupos') IS NOT NULL DROP TABLE #PerfAGR_Grupos;
IF OBJECT_ID('tempdb..#PerfAGR_Pendientes') IS NOT NULL DROP TABLE #PerfAGR_Pendientes;

SELECT '01_PENDIENTES_GENERALES' Seccion,COUNT_BIG(*) CobranzasTotales,
       COUNT_BIG(CASE WHEN Fecha_Envio IS NULL THEN 1 END) FechaEnvioNull,
       COUNT_BIG(CASE WHEN Fecha_Proceso>@Limite THEN 1 END) Recientes,
       COUNT_BIG(CASE WHEN Fecha_Proceso>@Limite AND Asignacion_Central IS NULL THEN 1 END) RecientesSinAsignacionCentral
FROM T3.CFDI_COBRANZA;

-- El detalle original NO tiene filtro Fecha_Proceso; conservar todo el pendiente
-- elegible aqui evita medir un conjunto artificialmente mas pequeno.
SELECT C.Asignacion_ID,C.Factura,C.Fecha_Proceso,CAST(C.Fecha_Pago AS date) Fecha_Pago,
       C.RFC,CASE C.Via_Pago WHEN 'NA' THEN '03' ELSE C.Via_Pago END Via_Pago,
       ISNULL(C.Banco_Nombre,'NoBanco') Banco_Nombre,ISNULL(C.Banco_Num_Cuenta,'NoCuenta') Banco_Num_Cuenta,
       ISNULL(C.Asignacion_Central,'NoAsigna') Asignacion_Central,C.Importe,C.Accnt_ID,C.Cliente_SAP
INTO #PerfAGR_Pendientes
FROM T3.CFDI_COBRANZA C
WHERE C.Fecha_Envio IS NULL AND C.Created_By<>'INTERFACE' AND C.Via_Pago NOT IN('01','CM','AI')
  AND ISNULL(C.Status,'1') NOT IN('Debit Note','Canc Pago')
  AND NOT EXISTS(SELECT 1 FROM T3.WA_FACTORAJE F WHERE F.Factura=C.Factura);

SELECT P.Fecha_Pago,P.RFC,P.Via_Pago,P.Banco_Nombre,P.Banco_Num_Cuenta,P.Asignacion_Central,
       SUM(P.Importe) Importe,COUNT(P.Importe) Cantidad_Pagos,COUNT_BIG(*) Filas,
       MAX(P.Accnt_ID) Accnt_ID,MAX(P.Cliente_SAP) Cliente_SAP
INTO #PerfAGR_Grupos
FROM #PerfAGR_Pendientes P
WHERE P.Fecha_Proceso>@Limite AND P.RFC<>'XAXX010101000'
GROUP BY P.Fecha_Pago,P.RFC,P.Via_Pago,P.Banco_Nombre,P.Banco_Num_Cuenta,P.Asignacion_Central;

SELECT '02_TAMANOS_DEL_MODELO' Seccion,
    (SELECT COUNT_BIG(*) FROM #PerfAGR_Pendientes) PendientesConFiltrosComunesSinCorteFecha,
    (SELECT COUNT_BIG(*) FROM #PerfAGR_Pendientes WHERE Fecha_Proceso>@Limite AND RFC<>'XAXX010101000') FilasParaResumir,
    (SELECT COUNT_BIG(*) FROM #PerfAGR_Grupos) Grupos,
    (SELECT COUNT_BIG(*) FROM #PerfAGR_Grupos WHERE Fecha_Pago IS NULL) GruposConFechaPagoNull,
    (SELECT COUNT_BIG(*) FROM #PerfAGR_Pendientes WHERE Asignacion_ID IS NULL) PendientesAsignacionIDNull;

SELECT '03_DETALLE_QUE_COINCIDE_CON_GRUPOS' Seccion,COUNT_BIG(*) FilasDelDetalle,
       COUNT_BIG(CASE WHEN P.Fecha_Proceso>@Limite THEN 1 END) FilasRecientes,
       COUNT_BIG(CASE WHEN P.Fecha_Proceso<=@Limite OR P.Fecha_Proceso IS NULL THEN 1 END) FilasFueraVentanaIncluidasPorDiseno
FROM #PerfAGR_Grupos G JOIN #PerfAGR_Pendientes P
 ON P.Fecha_Pago=G.Fecha_Pago AND P.RFC=G.RFC AND P.Via_Pago=G.Via_Pago
 AND P.Banco_Nombre=G.Banco_Nombre AND P.Banco_Num_Cuenta=G.Banco_Num_Cuenta
 AND P.Asignacion_Central=G.Asignacion_Central;

SELECT TOP(20) '04_ASIGNACIONES_REPETIDAS_EN_PENDIENTES' Seccion,Asignacion_ID,COUNT_BIG(*) Filas
FROM #PerfAGR_Pendientes GROUP BY Asignacion_ID HAVING COUNT_BIG(*)>1 ORDER BY Filas DESC;
SELECT '05_LIBERACION_GLOBAL_PENDIENTE' Seccion,COUNT_BIG(*) ControlesPendientes,
       COUNT(DISTINCT Agrupacion) AgrupacionesDistintas,
       MIN(Fecha_Pago) FechaPagoMasAntigua,MAX(Fecha_Pago) FechaPagoMasReciente
FROM T3.CFDI_AGRUPACION_CTRL
WHERE Fecha_Pago>=CONVERT(datetime,'20220101',112) AND Fecha_Envio IS NULL AND Accnt_ID<>'Contado';

IF @AnalizarLiberacion=1
BEGIN
    SELECT DISTINCT Agrupacion INTO #PerfAGR_Controles
    FROM T3.CFDI_AGRUPACION_CTRL
    WHERE Fecha_Pago>=CONVERT(datetime,'20220101',112) AND Fecha_Envio IS NULL AND Accnt_ID<>'Contado';
    SELECT '06_FILAS_DEL_CHECK_EN_CONJUNTO' Seccion,COUNT_BIG(*) FilasDelJoin,
       COUNT_BIG(CASE WHEN LEN(ISNULL(C.UUID_Venta,'NULL'))>20 THEN 1 END) FilasQueCumplenLongitudUUID,
       COUNT_BIG(CASE WHEN CAST(C.Fecha_Asignacion AS date)=CAST(C.Fecha_Factura AS date) AND D.Metodo_Pago='PUE' THEN 1 END) FilasConCondicionPUE
    FROM T3.CFDI_AGRUPACION_PAGO A JOIN #PerfAGR_Controles P ON P.Agrupacion=A.Agrupacion
    JOIN T3.CFDI_COBRANZA C ON C.Asignacion_ID=A.Asignacion_ID
    JOIN T3.CFDI_DOCUMENTOS D ON D.Nota_Venta=C.Nota_Venta;
    -- Es un indicador de repeticion potencial de ScrImpuestos, no numero real
    -- de llamadas: antes intervienen CHECK, version y posibles errores.
    SELECT TOP(30) '07_FACTURAS_REPETIDAS_PARA_IMPUESTOS' Seccion,C.Factura,
       COUNT_BIG(*) FilasDePago,COUNT(DISTINCT A.Agrupacion) Agrupaciones
    FROM T3.CFDI_AGRUPACION_PAGO A JOIN #PerfAGR_Controles P ON P.Agrupacion=A.Agrupacion
    JOIN T3.CFDI_COBRANZA C ON C.Asignacion_ID=A.Asignacion_ID
    GROUP BY C.Factura HAVING COUNT_BIG(*)>1 ORDER BY FilasDePago DESC;
    DROP TABLE #PerfAGR_Controles;
END;

IF @RevisarAsignacionCentral=1
BEGIN
    SELECT TOP(20) '08_MULTIPLICIDAD_ASIGNACION_CENTRAL' Seccion,C.Asignacion_ID,C.Factura,
        COUNT_BIG(*) FilasDelJoin,COUNT(DISTINCT A.Assignment) AsignacionesDistintas
    FROM T3.CFDI_COBRANZA C
    JOIN EAI_OWNER.TMP_ACCOUNT_HEADER A ON SUBSTRING(C.Asignacion_ID,3,10)=A.ClearingDocNumber AND A.FiscalYear=@Ejercicio
    JOIN T3.REGISTRO_FISCAL R ON R.Factura=C.Factura
    WHERE C.Fecha_Proceso>@Limite AND C.Asignacion_Central IS NULL
      AND ISNULL(A.Assignment,R.Entrega)<>R.Entrega AND ISNULL(A.Assignment,R.Entrega)<>'B001 - Bank I'
      AND ISNULL(A.Assignment,R.Entrega)<>C.Factura+',' AND ISNULL(A.Assignment,R.Entrega) NOT LIKE '1-1%'
      AND ISNULL(A.Assignment,R.Entrega)<>R.Referencia
    GROUP BY C.Asignacion_ID,C.Factura HAVING COUNT_BIG(*)>1 ORDER BY AsignacionesDistintas DESC,FilasDelJoin DESC;
END;

DROP TABLE #PerfAGR_Grupos;
DROP TABLE #PerfAGR_Pendientes;
SELECT '09_ALCANCE' Seccion,'Modelo con Asignacion_Central actual; no ejecuta su UPDATE. No equivale a una medicion de tiempo del procedimiento.' Mensaje;
