/*
  Evidencia disponible de PROC_T3_OT_GENERAL y sus hijos. SOLO LECTURA
  de tablas permanentes; @Facturas es una variable local de esta consulta.
  No ejecuta SP, genera layouts, desmarca cabeceras ni cambia datos de negocio.

  Hoy = fecha local de GETDATE() en SQL Server. Cambiar @Fecha para otro dia.
  Rango semiabierto: desde las 00:00 de @Fecha hasta las 00:00 del dia siguiente.
  @VerLayoutCompleto=1 incluye Informacion completa; con 0 muestra 1000 caracteres.

  ALCANCE: fechas/referencias permiten correlacionar registros, no identificar
  cada ejecucion ni certificar que este SP fue el unico escritor. No tiene PID
  propio. Fecha_Proc_BATMD puede marcarse aunque el generador registre un error.
  CFDI_DOCUMENTOS_ENVIAR no tiene fecha: solo se muestra su estado actual.
  Fecha_Liberacion es evidencia temporal, no auditoria de fecha fisica de INSERT.
  MetodoPago y centinela 2999-12-31 tampoco tienen fecha del UPDATE disponible.
  Sin auditoria previa no se reconstruyen cambios sobreescritos o filas eliminadas.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @Captura datetime=GETDATE();
DECLARE @Fecha date=CONVERT(date,@Captura); -- Ejemplo fijo: '20261029'.
DECLARE @VerLayoutCompleto bit=0;
DECLARE @Desde datetime2(0)=CONVERT(datetime2(0),@Fecha),
        @Hasta datetime2(0)=DATEADD(DAY,1,CONVERT(datetime2(0),@Fecha));

SELECT '00_CONTEXTO' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
       @Captura HoraServidor,@Desde DesdeIncluido,@Hasta HastaExcluido,
       'Correlacion por fechas/factura; no auditoria exclusiva por ejecucion.' Alcance;
SELECT '00_MODULO_INSTALADO' Seccion,O.name,O.modify_date UltimaModificacionDelModulo,
       CASE WHEN M.definition IS NULL THEN 'DEFINICION NO VISIBLE'
            WHEN CHARINDEX('THROW 53805',M.definition)>0 THEN 'CON VALIDACION ADICIONAL DE SALIDA'
            ELSE 'SIN MARCADOR DE VALIDACION ADICIONAL; REVISAR DEFINICION' END VersionObservada
FROM sys.objects O LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id=OBJECT_ID('T3.PROC_T3_OT_GENERAL');

-- Construir una lista unica evita multiplicar salidas al unir cabeceras,
-- documentos, layouts y bitacoras que puedan tener mas de una fila por factura.
DECLARE @Facturas table(
    Factura varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    MarcaEnPeriodo bit NOT NULL,LiberacionEnPeriodo bit NOT NULL,
    ErrorRFEnPeriodo bit NOT NULL,ErrorMapeoOHelperEnPeriodo bit NOT NULL);
;WITH Evidencia AS (
    SELECT G.Factura COLLATE DATABASE_DEFAULT Factura,
           1 Marca,0 Liberacion,0 ErrorRF,0 ErrorEAI
    FROM T3.OTROS_GENERAL G
    WHERE G.Fecha_Proc_BATMD>=@Desde AND G.Fecha_Proc_BATMD<@Hasta
    UNION ALL
    SELECT D.Nota_Venta COLLATE DATABASE_DEFAULT,0,1,0,0
    FROM T3.CFDI_DOCUMENTOS D
    WHERE D.Fecha_Liberacion>=@Desde AND D.Fecha_Liberacion<@Hasta AND D.Ctro='CTRL'
      AND EXISTS(SELECT 1 FROM T3.OTROS_GENERAL G
                 WHERE G.Factura COLLATE DATABASE_DEFAULT=D.Nota_Venta COLLATE DATABASE_DEFAULT)
    UNION ALL
    SELECT E.Referencia COLLATE DATABASE_DEFAULT,0,0,1,0
    FROM T3.RF_ERROR_LOG E
    WHERE E.Fecha>=@Desde AND E.Fecha<@Hasta
      AND E.Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS','PROC_T3_OT_GENERAL')
    UNION ALL
    SELECT E.REFERENCE COLLATE DATABASE_DEFAULT,0,0,0,1
    FROM EAI_OWNER.MX_EAI_MESSAGE_LOG E
    WHERE E.Created>=@Desde AND E.Created<@Hasta
      AND E.Queue_Name IN ('GET_SAT_CLAVEPRODUCTO','WA_ERR_INVOICE_PAYMETHOD')
)
INSERT @Facturas(Factura,MarcaEnPeriodo,LiberacionEnPeriodo,ErrorRFEnPeriodo,ErrorMapeoOHelperEnPeriodo)
SELECT Factura,MAX(Marca),MAX(Liberacion),MAX(ErrorRF),MAX(ErrorEAI)
FROM Evidencia WHERE Factura IS NOT NULL GROUP BY Factura;

SELECT '01_RESUMEN' Seccion,
    (SELECT COUNT_BIG(*) FROM @Facturas) FacturasConEvidencia,
    (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL
      WHERE Fecha_Proc_BATMD>=@Desde AND Fecha_Proc_BATMD<@Hasta) FilasCabeceraConMarcaEnPeriodo,
    (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D
      WHERE D.Fecha_Liberacion>=@Desde AND D.Fecha_Liberacion<@Hasta AND D.Ctro='CTRL'
        AND EXISTS(SELECT 1 FROM @Facturas F
                   WHERE F.Factura=D.Nota_Venta COLLATE DATABASE_DEFAULT)) DocumentosCTRLConLiberacionEnPeriodo,
    (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E
      WHERE EXISTS(SELECT 1 FROM @Facturas F
                   WHERE F.Factura=E.Nota_Venta COLLATE DATABASE_DEFAULT)) LayoutsActualesRelacionados_SinFecha,
    (SELECT COUNT_BIG(*) FROM T3.RF_ERROR_LOG
      WHERE Fecha>=@Desde AND Fecha<@Hasta
        AND Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS','PROC_T3_OT_GENERAL')) ErroresRFEnPeriodo;

-- Incluye tambien intentos con error sin marca ni cabecera visible.
SELECT '02_FACTURAS_Y_ESTADO_ACTUAL' Seccion,F.*,
       (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL G
         WHERE G.Factura COLLATE DATABASE_DEFAULT=F.Factura) CabecerasActuales,
       (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D
         WHERE D.Nota_Venta COLLATE DATABASE_DEFAULT=F.Factura) DocumentosActuales_TodasLasFechas,
       (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E
         WHERE E.Nota_Venta COLLATE DATABASE_DEFAULT=F.Factura) LayoutsActuales_SinFecha
FROM @Facturas F ORDER BY F.Factura;

-- Fecha_Trn es contexto del origen; este coordinador no inserta cabeceras.
SELECT '03_CABECERAS_ESTADO_ACTUAL' Seccion,
       F.MarcaEnPeriodo,F.LiberacionEnPeriodo,F.ErrorRFEnPeriodo,F.ErrorMapeoOHelperEnPeriodo,
       G.Factura,G.FacturaSAP,G.PedidoSAP,G.Sociedad,G.Cliente_SAP,G.RFC,
       G.Clase_Factura,G.Fecha_Factura,G.Fecha_Trn,G.Fecha_Proc_BATMD,
       G.Fecha_Cancelacion,G.MetodoPago,G.Moneda,G.Valor_Subt,G.Valor_IVA,G.Retencion_IVA,
       CASE WHEN G.Fecha_Proc_BATMD>=@Desde AND G.Fecha_Proc_BATMD<@Hasta
            THEN 'MARCA EN PERIODO; NO CERTIFICA EXITO DEL GENERADOR'
            ELSE 'CONTEXTO ACTUAL; MARCA FUERA DEL PERIODO O PENDIENTE' END Evidencia
FROM T3.OTROS_GENERAL G JOIN @Facturas F ON F.Factura=G.Factura COLLATE DATABASE_DEFAULT
ORDER BY G.Factura,G.Fecha_Proc_BATMD;

-- Mostrar tambien documentos historicos ayuda a detectar facturas marcadas
-- hoy cuyo unico documento corresponde a una liberacion anterior.
SELECT '04_DOCUMENTOS_RELACIONADOS' Seccion,D.*,
       CASE WHEN D.Fecha_Liberacion>=@Desde AND D.Fecha_Liberacion<@Hasta THEN 1 ELSE 0 END LiberacionEnPeriodo,
       'Fecha_Liberacion no prueba fecha fisica del INSERT ni autor exclusivo.' Alcance
FROM T3.CFDI_DOCUMENTOS D
WHERE EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=D.Nota_Venta COLLATE DATABASE_DEFAULT)
ORDER BY D.Nota_Venta,D.Fecha_Liberacion;

SELECT '05_LAYOUTS_ACTUALES_SIN_FECHA' Seccion,E.Nota_Venta,
       DATALENGTH(E.Informacion) BytesLayout,LEFT(E.Informacion,1000) VistaPrevia,
       CASE WHEN @VerLayoutCompleto=1 THEN E.Informacion END LayoutCompleto,
       'La tabla no registra fecha: no se puede afirmar que se inserto hoy.' Alcance
FROM T3.CFDI_DOCUMENTOS_ENVIAR E
WHERE EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=E.Nota_Venta COLLATE DATABASE_DEFAULT)
ORDER BY E.Nota_Venta;

SELECT '06_ERRORES_RF_DEL_PERIODO' Seccion,E.Fecha,E.Rutina,E.Referencia,E.Error_Desc,E.Job_PID
FROM T3.RF_ERROR_LOG E
WHERE E.Fecha>=@Desde AND E.Fecha<@Hasta
  AND E.Rutina IN ('GENERAR_OTROS','PROC_CFDI_GENERAR_OTROS','PROC_T3_OT_GENERAL')
ORDER BY E.Fecha,E.Referencia;

SELECT '07_MENSAJES_EAI_DEL_PERIODO' Seccion,
       E.Created,E.Queue_Name,E.REFERENCE,E.Status,E.Siebel_Error_Code,E.Siebel_Error_Message,E.Job_PID,
       CASE WHEN E.Queue_Name='RECV_INVOICE_INTERCOMPANY'
            THEN 'CONTEXTO DEL PADRE; NO ES PID PROPIO DEL COORDINADOR'
            ELSE 'ERROR DE HELPER/MAPEO; REVISAR REFERENCIA' END Alcance
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG E
WHERE E.Created>=@Desde AND E.Created<@Hasta
  AND E.Queue_Name IN ('GET_SAT_CLAVEPRODUCTO','WA_ERR_INVOICE_PAYMETHOD','RECV_INVOICE_INTERCOMPANY')
ORDER BY E.Created,E.Queue_Name,E.REFERENCE;

-- El mapeo del generador se invoca con EXPO y quita puntos del material.
-- La relacion material/factura no prueba quien creo cada registro del catalogo.
SELECT '08_CATALOGO_SAT_FECHA_CREACION_EN_PERIODO' Seccion,P.*,
       'Relacion por material; no registra la factura que origino el alta.' Alcance
FROM T3.CFDI_PRODSERV P
WHERE P.Fecha_Creacion>=@Desde AND P.Fecha_Creacion<@Hasta
  AND P.Modulo='EXPO' AND P.Creado_Por='INVOICING'
  AND EXISTS(SELECT 1 FROM T3.OTROS_DETALLE D
             JOIN @Facturas F ON F.Factura=D.Factura COLLATE DATABASE_DEFAULT
             WHERE REPLACE(D.Material,'.','') COLLATE DATABASE_DEFAULT=P.Material COLLATE DATABASE_DEFAULT)
ORDER BY P.Fecha_Creacion,P.Material;

-- Estos dos conjuntos son contexto, NO cambios fechados de hoy. MetodoPago
-- y centinela pueden haberse establecido antes del periodo. No se incluyen
-- como evidencia temporal en @Facturas por su sola condicion actual.
SELECT '09_METODO_PAGO_ACTUAL_CON_MATERIAL_R900' Seccion,
       G.Factura,G.Fecha_Factura,G.Fecha_Trn,G.Fecha_Proc_BATMD,G.MetodoPago,
       'ESTADO ACTUAL; SIN FECHA DE CAMBIO DE METODOPAGO' Alcance
FROM T3.OTROS_GENERAL G
WHERE G.MetodoPago='03'
  AND EXISTS(SELECT 1 FROM T3.OTROS_DETALLE D
             WHERE D.Factura COLLATE DATABASE_DEFAULT=G.Factura COLLATE DATABASE_DEFAULT
               AND D.Material='R900' AND D.MaterialDescripcion='FIXED ASSET - External Sales')
  AND (EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=G.Factura COLLATE DATABASE_DEFAULT)
       OR G.Fecha_Factura>=DATEADD(DAY,-4,@Desde) AND G.Fecha_Factura<@Hasta)
ORDER BY G.Factura;

SELECT '10_APARTADOS_CENTINELA_ESTADO_ACTUAL' Seccion,
       G.Factura,G.Sociedad,G.RFC,G.Fecha_Trn,G.Fecha_Proc_BATMD,
       'ESTADO ACTUAL; 2999-12-31 NO INDICA DIA DEL APARTADO' Alcance
FROM T3.OTROS_GENERAL G
WHERE G.Fecha_Proc_BATMD=CONVERT(datetime2(0),'29991231',112)
  AND G.Fecha_Trn>=DATEADD(DAY,-4,@Desde) AND G.Fecha_Trn<@Hasta
ORDER BY G.Factura;
