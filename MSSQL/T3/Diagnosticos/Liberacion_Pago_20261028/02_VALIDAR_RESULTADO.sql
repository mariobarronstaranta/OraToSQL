/*
  Solo lectura, DESPUES de la corrida. Completar @Desde con el inicio real y,
  si se conoce, @PID del proceso 613. No iniciar otra ejecucion desde aqui.
  Para conciliacion por asignacion pegar el baseline 10 de la consulta previa
  como JSON: [{"Asignacion_ID":"ID_REAL","LayoutsAntes":0,"DocumentosAntes":0,
               "CobranzasMarcadasAntes":0}]
  Dejar [] permite ver bitacoras, pero NO acredita que todos generaron salida.
*/
SET NOCOUNT ON;
DECLARE @Desde datetime2(0)=NULL; -- Obligatorio: hora real anterior al EXEC.
DECLARE @Hasta datetime2(0)=SYSDATETIME();
DECLARE @PID decimal(10,0)=NULL;
DECLARE @Baseline nvarchar(max)=N'[]';
IF @Desde IS NULL THROW 52760,'Completar @Desde con el inicio real de la corrida.',1;
IF @Hasta<@Desde THROW 52761,'La ventana temporal no es valida.',1;
IF ISJSON(@Baseline)<>1 THROW 52762,'Baseline debe ser un JSON valido.',1;

SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@Desde AS Desde,@Hasta AS Hasta,@PID AS PID;
SELECT '02_CORRIDAS_613' AS Seccion,PID,INICIO,FIN,PROCESO_1 AS FilasRecorridas,
       CASE WHEN FIN IS NULL THEN N'SIN CIERRE' ELSE N'CIERRE REGISTRADO; REVISAR DESTINOS' END AS Estado
FROM T3.RF_PROCESOS_LOG WHERE PROCESO=613
 AND ((@PID IS NOT NULL AND PID=@PID) OR (@PID IS NULL AND INICIO>=@Desde AND INICIO<=@Hasta))
ORDER BY INICIO;
SELECT '03_COMPONENTE' AS Seccion,Component,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component=613;
SELECT '04_ERRORES_COORDINADOR' AS Seccion,CREATED,JOB_PID,REFERENCE,SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE QUEUE_NAME='PROC_CFDI_LIBERACION_PAGO'
 AND CREATED>=@Desde AND CREATED<=@Hasta AND (@PID IS NULL OR JOB_PID=@PID)
ORDER BY CREATED;
-- El generador real usa este nombre historico en RF_ERROR_LOG; su Referencia
-- puede ser Folio_ID y no Asignacion_ID. No filtrar unicamente por PID.
SELECT '05_ERRORES_GENERADOR' AS Seccion,FECHA,RUTINA,REFERENCIA,ERROR_DESC
FROM T3.RF_ERROR_LOG WHERE FECHA>=@Desde AND FECHA<=@Hasta
 AND RUTINA LIKE '%GENERAR_PAGO%' ORDER BY FECHA;

DECLARE @Ids table(Asignacion_ID varchar(50) COLLATE DATABASE_DEFAULT PRIMARY KEY,
 LayoutsAntes bigint,DocumentosAntes bigint,CobranzasMarcadasAntes bigint);
INSERT @Ids SELECT Asignacion_ID,LayoutsAntes,DocumentosAntes,CobranzasMarcadasAntes
FROM OPENJSON(@Baseline) WITH(Asignacion_ID varchar(50),LayoutsAntes bigint,
 DocumentosAntes bigint,CobranzasMarcadasAntes bigint);
IF NOT EXISTS(SELECT 1 FROM @Ids)
BEGIN
 SELECT '06_SIN_BASELINE' AS Seccion,
 N'Se muestran bitacoras. Falta lista/baseline de asignaciones para acreditar altas y detectar omisiones.' AS Resultado;
 RETURN;
END;
SELECT '06_CONCILIACION' AS Seccion,I.Asignacion_ID,I.LayoutsAntes,E.N AS LayoutsAhora,
 E.N-I.LayoutsAntes AS DiferenciaLayouts,I.DocumentosAntes,D.N AS DocumentosAhora,
 D.N-I.DocumentosAntes AS DiferenciaDocumentos,D.NEnVentana AS DocumentosLiberadosEnVentana,
 I.CobranzasMarcadasAntes,C.Marcadas AS CobranzasMarcadasAhora,C.Pendientes,C.SinReferencia,
 CASE WHEN I.LayoutsAntes IS NULL OR I.DocumentosAntes IS NULL OR I.CobranzasMarcadasAntes IS NULL
      THEN N'BASELINE INCOMPLETO'
      WHEN E.N>I.LayoutsAntes AND D.N>I.DocumentosAntes AND D.NEnVentana>0
       AND C.Pendientes=0 AND C.Marcadas>I.CobranzasMarcadasAntes
      THEN N'HAY ALTAS Y MARCAS; REVISAR CONTENIDO/ERRORES'
      ELSE N'REVISAR: NO SE ACREDITAN TODAS LAS SALIDAS ESPERADAS' END AS Estado
FROM @Ids I
OUTER APPLY(SELECT COUNT_BIG(*) N FROM T3.CFDI_DOCUMENTOS_ENVIAR WHERE Nota_Venta=I.Asignacion_ID) E
OUTER APPLY(SELECT COUNT_BIG(*) N,
 SUM(CASE WHEN Fecha_Liberacion>=@Desde AND Fecha_Liberacion<=@Hasta THEN 1 ELSE 0 END) AS NEnVentana
 FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta=I.Asignacion_ID) D
OUTER APPLY(SELECT COUNT_BIG(*) AS Total,
 SUM(CASE WHEN Fecha_Envio IS NOT NULL THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) Marcadas,
 SUM(CASE WHEN Fecha_Envio IS NULL THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) Pendientes,
 CASE WHEN COUNT_BIG(*)=0 THEN 1 ELSE 0 END AS SinReferencia
 FROM T3.CFDI_COBRANZA WHERE Asignacion_ID=I.Asignacion_ID) C;
-- No se expone el layout completo: solo presencia, longitud y cabecera.
SELECT '07_LAYOUTS' AS Seccion,E.Nota_Venta,DATALENGTH(E.Informacion) AS BytesLayout,
 LEFT(E.Informacion,60) AS InicioLayout
FROM T3.CFDI_DOCUMENTOS_ENVIAR E INNER JOIN @Ids I ON I.Asignacion_ID=E.Nota_Venta;
SELECT '08_DOCUMENTOS' AS Seccion,D.Nota_Venta,D.Ctro,D.Fecha_Liberacion,D.Fecha_Envio,
 D.Status,D.Folio_Fiscal,D.Fecha_Timbre
FROM T3.CFDI_DOCUMENTOS D INNER JOIN @Ids I ON I.Asignacion_ID=D.Nota_Venta;
SELECT '09_ALCANCE' AS Seccion,
 N'Layouts carece de fecha: su alta se contrasta con baseline, sin atribucion exclusiva si hubo concurrencia. '
 +N'Fin y Proceso_1 no acreditan generacion. Altas/marcas no acreditan contenido fiscal ni timbrado.' AS Resultado;
