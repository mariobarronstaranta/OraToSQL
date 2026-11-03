/* SOLO LECTURA. No ejecuta el procedimiento ni consume secuencias.
   Ejecutar completo en T3QA y guardar Resultados y Mensajes.
   Identifica la corrida por PID; el nombre se etiqueta desde el SP revisado,
   no desde MX_COMPONENTS, donde 109 corresponde a otro nombre historico.
   RF_PROCESOS_LOG no guarda una relacion padre/hijo entre PID 109 y PID 614.
*/
USE [T3QA];
SET NOCOUNT ON;

DECLARE @Desde datetime2(0)='20261029';
DECLARE @Hasta datetime2(0)='20261030'; -- Exclusivo; fechas/hora del servidor.
DECLARE @PID109 decimal(10,0)=NULL; -- Completar si aparece mas de una corrida.
DECLARE @PID614 decimal(10,0)=NULL; -- Opcional: solo si se identifico esa corrida.

IF @Hasta<=@Desde THROW 53500,'Ventana de consulta invalida.',1;
SELECT '01_AMBIENTE' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
       SYSDATETIMEOFFSET() FechaExtraccion,@Desde DesdeIncluido,@Hasta HastaExcluido;

SELECT '02_CORRIDAS_109' Seccion,PID,Proceso,Inicio,Fin,
       Proceso_1 GruposCreados,Proceso_2 RelacionesInsertadas,
       Proceso_3,Proceso_4 Parametro_nDias
FROM T3.RF_PROCESOS_LOG
WHERE Proceso=109 AND Inicio>=@Desde AND Inicio<@Hasta
ORDER BY Inicio,PID;

IF @PID109 IS NULL
BEGIN
 IF (SELECT COUNT_BIG(*) FROM T3.RF_PROCESOS_LOG
     WHERE Proceso=109 AND Inicio>=@Desde AND Inicio<@Hasta AND Proceso_4=30)<>1
 BEGIN
  SELECT '03_SELECCION_REQUERIDA' Seccion,
   'Completar @PID109 con la corrida correcta de la seccion 02. Si no hay filas, revisar fecha/ambiente. No repetir el SP solo para generar evidencia.' Mensaje;
  RETURN;
 END;
 SELECT @PID109=PID FROM T3.RF_PROCESOS_LOG
 WHERE Proceso=109 AND Inicio>=@Desde AND Inicio<@Hasta AND Proceso_4=30;
END;
IF (SELECT COUNT_BIG(*) FROM T3.RF_PROCESOS_LOG
    WHERE Proceso=109 AND PID=@PID109 AND Inicio>=@Desde AND Inicio<@Hasta)<>1
 THROW 53501,'PID109 ausente, repetido o fuera de ventana.',1;

DECLARE @Inicio109 datetime2(0),@Fin109 datetime2(0),@FinRevision datetime2(0);
SELECT @Inicio109=Inicio,@Fin109=Fin FROM T3.RF_PROCESOS_LOG WHERE Proceso=109 AND PID=@PID109;
IF @PID614 IS NOT NULL AND
 (SELECT COUNT_BIG(*) FROM T3.RF_PROCESOS_LOG WHERE Proceso=614 AND PID=@PID614
  AND Inicio>=@Inicio109 AND Inicio<@Hasta)<>1
 THROW 53502,'PID614 invalido, repetido o fuera de ventana.',1;
SET @FinRevision=@Hasta;
IF @PID614 IS NOT NULL
 SELECT @FinRevision=ISNULL(Fin,@Hasta) FROM T3.RF_PROCESOS_LOG WHERE Proceso=614 AND PID=@PID614;

SELECT '03_EVIDENCIA_AGRUPADOR' Seccion,
 'T3.PROC_CFDI_PROCESA_PAGO_AGR' Procedimiento,
 @@SERVERNAME Servidor,DB_NAME() BaseDatos,PID,Proceso,Inicio,Fin,
 DATEDIFF_BIG(millisecond,Inicio,Fin) DuracionAgrupacion_ms,
 Proceso_4 Parametro_nDias,Proceso_1 GruposCreados,Proceso_2 RelacionesInsertadas,
 CASE WHEN Fin IS NULL THEN 'SIN CIERRE REGISTRADO'
      WHEN Proceso_1=0 AND Proceso_2=0 THEN 'AGRUPACION REGISTRADA SIN ALTAS DE GRUPOS NI RELACIONES'
      ELSE 'AGRUPACION REGISTRADA CON CONTADORES; REVISAR DESTINOS' END Resultado
FROM T3.RF_PROCESOS_LOG WHERE Proceso=109 AND PID=@PID109;

SELECT '04_CORRIDAS_614_EN_VENTANA' Seccion,PID,Proceso,Inicio,Fin,
       Proceso_1 GruposQuePasaronCheck,
 CASE WHEN PID=@PID614 THEN 'SELECCIONADO POR USUARIO'
      ELSE 'CANDIDATO TEMPORAL; NO PRUEBA FILIACION' END RelacionCon109
FROM T3.RF_PROCESOS_LOG
WHERE Proceso=614 AND Inicio>=@Inicio109 AND Inicio<@Hasta
ORDER BY Inicio,PID;

SELECT '05_ERRORES_RUTINAS_EN_VENTANA' Seccion,FECHA,RUTINA,REFERENCIA,ERROR_DESC,JOB_PID
FROM T3.RF_ERROR_LOG
WHERE FECHA>=@Inicio109 AND FECHA<=@FinRevision
 AND RUTINA IN ('PROC_CFDI_PROCESA_PAGO_AGR','PROC_CFDI_LIBERA_PAGO_CHECK',
                'PROC_V20_GENERAR_PAGO_AGR','PROC_CFDI_GENERAR_PAGO_AGR')
ORDER BY FECHA;

SELECT '06_ERRORES_LIBERADOR' Seccion,CREATED,JOB_PID,REFERENCE,
       SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='PROC_CFDI_LIBERA_PAGO_CENTRAL'
 AND ((@PID614 IS NOT NULL AND JOB_PID=@PID614)
      OR (@PID614 IS NULL AND CREATED>=@Inicio109 AND CREATED<=@FinRevision))
ORDER BY CREATED;

SELECT '07_ALCANCE_EVIDENCIA' Seccion,
 'RF_PROCESOS_LOG acredita la corrida registrada del proceso 109 y sus contadores. Su Fin se escribe antes de llamar al liberador 614, por lo que su duracion no mide toda la cadena. No guarda el SQL ejecutado ni el usuario ejecutor. Los errores por fecha pueden incluir otras corridas. La ausencia de errores no certifica timbrado; contadores cero no validan la generacion con datos.' Observacion;
