/*
  EJECUCION REAL, autorizada por el usuario: llama al procedimiento existente
  SIN PARAMETROS. A diferencia de 01-04, este archivo SI inicia el proceso
  y sus cambios de negocio a traves del SP. No altera su definicion.
  Seleccionar T3QA, el ambiente analizado. Ejecutar completo y conservar
  todos los resultados y la pestana Mensajes.

  Se conserva el generador instalado con VARCHAR(4). Que el EXEC retorne
  normalmente no certifica importes, layout ni timbrado; revisar evidencias.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 52780,'Seleccionar T3QA, la base analizada.',1;
IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
 THROW 52781,'Ejecutar sin transacciones externas ni implicitas.',1;
IF OBJECT_ID(N'T3.PROC_CFDI_LIBERACION_PAGO',N'P') IS NULL
 THROW 52782,'No se encuentra o no es visible el procedimiento en esta base.',1;

DECLARE @Inicio datetime2(3)=SYSDATETIME(),@Fin datetime2(3),
        @Retorno int=NULL,@ErrorPropagado int=NULL;
SELECT '01_INICIO_REAL' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       @@SPID AS SpidEjecucion,SUSER_SNAME() AS LoginActual,@Inicio AS Inicio;

BEGIN TRY
    EXEC @Retorno = T3.PROC_CFDI_LIBERACION_PAGO;
END TRY
BEGIN CATCH
    SET @ErrorPropagado=ERROR_NUMBER();
    SELECT '02_ERROR_PROPAGADO' AS Seccion,ERROR_NUMBER() AS Numero,
           ERROR_PROCEDURE() AS Procedimiento,ERROR_LINE() AS Linea,ERROR_MESSAGE() AS Mensaje;
END CATCH;
SET @Fin=SYSDATETIME();
SELECT '03_FIN_REAL' AS Seccion,@Inicio AS Inicio,@Fin AS Fin,
       DATEDIFF_BIG(millisecond,@Inicio,@Fin) AS Duracion_ms,@Retorno AS CodigoRetorno,
       @ErrorPropagado AS ErrorPropagado,@@TRANCOUNT AS TranCountFinal,XACT_STATE() AS XactStateFinal,
       N'El CATCH interno puede ocultar errores; consultar bitacoras y destinos.' AS Observacion;

-- Un segundo de margen por columnas de bitacora con precision de segundos.
-- Si hubo otra corrida simultanea, no atribuirle automaticamente todas las filas.
DECLARE @Desde datetime2(3)=DATEADD(second,-1,@Inicio),
        @Hasta datetime2(3)=DATEADD(second,1,@Fin);
SELECT '04_BITACORA_PROCESO_613' AS Seccion,PID,INICIO,FIN,
       PROCESO_1 AS FilasRecorridas,PROCESO_2,PROCESO_3,PROCESO_4
FROM T3.RF_PROCESOS_LOG
WHERE PROCESO=613 AND INICIO>=@Desde AND INICIO<=@Hasta ORDER BY INICIO,PID;
SELECT '05_COMPONENTE_613' AS Seccion,Component,Name,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component=613;
SELECT '06_ERRORES_COORDINADOR' AS Seccion,CREATED,JOB_PID,REFERENCE,
       SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='PROC_CFDI_LIBERACION_PAGO' AND CREATED>=@Desde AND CREATED<=@Hasta
ORDER BY CREATED;
-- El generador usa un nombre historico y puede registrar Folio_ID como
-- Referencia; sus errores no tienen necesariamente el PID de esta corrida.
SELECT '07_ERRORES_GENERADOR_EN_VENTANA' AS Seccion,FECHA,RUTINA,REFERENCIA,ERROR_DESC
FROM T3.RF_ERROR_LOG
WHERE FECHA>=@Desde AND FECHA<=@Hasta AND RUTINA LIKE '%GENERAR_PAGO%'
ORDER BY FECHA;
SELECT '08_ALCANCE' AS Seccion,
 N'Ejecucion real del SP sin parametros. Proceso_1 cuenta filas recorridas; no pagos generados. '
 +N'Estas bitacoras no concilian todos los layouts/documentos ni acreditan timbrado. '
 +N'Conservar PID/horarios/mensajes para la revision posterior; no se modifico el procedimiento.' AS Resultado;
