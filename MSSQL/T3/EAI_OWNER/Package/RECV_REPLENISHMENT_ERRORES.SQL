-- Solo lectura. Ejecutar completo en AZCRNMXNEVTD06 / T3QA.
-- No ejecuta documentos, no modifica procedimientos ni limpia errores.
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51960,'Seleccionar T3QA.',1;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,SYSDATETIMEOFFSET() Captura;

-- Incluye errores de los hijos; algunos de estos hijos tambien sirven otros flujos.
-- El filtro de siete dias permite contrastar la muestra acumulada del diagnostico.
SELECT TOP (100)
 CREATED,QUEUE_NAME,JOB_PID,REFERENCE,STATUS,
 SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED >= DATEADD(DAY,-7,SYSDATETIME())
 AND QUEUE_NAME IN
 ('RECV_REPLENISHMENT','SF_PROC_REPLENISHMENT',
  'PROC_REPLENISHMENT_SUBDEPOT','Delivery to T3',
  'DELIVERY_TO_SUBDEPOT','DELIVERY_TO_REMISION','GET_REMISION_INFO','Folio Interno')
ORDER BY CREATED DESC;

-- Indices y tipo de PID: el cierre del proceso tambien tuvo muchas lecturas.
SELECT C.name Columna,TYPE_NAME(C.system_type_id) Tipo,C.max_length,C.precision,C.scale
FROM sys.columns C WHERE C.object_id=OBJECT_ID(N'T3.RF_PROCESOS_LOG')
 AND C.name=N'PID';
SELECT I.name Indice,I.is_disabled,I.filter_definition,IC.key_ordinal,
 IC.is_included_column,C.name Columna
FROM sys.indexes I
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=OBJECT_ID(N'T3.RF_PROCESOS_LOG')
ORDER BY I.index_id,IC.index_column_id;
