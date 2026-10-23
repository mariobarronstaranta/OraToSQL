/*
 Ejecutar completo en AZCRNMXNEVTD06 / T3QA despues de un lote habitual.
 Solo lectura de metadatos/cache: NO ejecuta documentos ni cambia objetos.
 SSMS: Ctrl+D (resultados en cuadricula), F5, guardar las tablas de resultados.
 Captura opcional durante el lote para ver bloqueos/transacciones.
 Las metricas son acumuladas de cache, no exclusivamente del ultimo lote.
 SQL Server 2022: las DMVs requieren permisos de monitoreo, normalmente
 VIEW SERVER PERFORMANCE STATE y visibilidad de metadatos de la base.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51960,'Seleccionar T3QA.',1;
DECLARE @Objetos table(Nombre nvarchar(256) PRIMARY KEY, ID int NULL);
INSERT @Objetos(Nombre) VALUES
 (N'EAI_OWNER.RECV_REPLENISHMENT'),(N'EAI_OWNER.SF_PROC_REPLENISHMENT'),
 (N'EAI_OWNER.PROC_REPLENISHMENT_SUBDEPOT'),(N'EAI_OWNER.INVOICE_TO_ENTREGA'),
 (N'T3.DELIVERY_TO_SUBDEPOT'),(N'T3.DELIVERY_IDOC_TO_REMISION'),
 (N'T3.GET_REMISION_INFO'),(N'EAI_OWNER.WA_FOLIO_FACTURA'),
 (N'EAI_OWNER.GETCONV'),(N'dbo.getConv'),(N'T3.FN_EVAL_REMISION_OBD'),
 (N'EAI_OWNER.FN_CHECK_INSTANCE'),(N'EAI_OWNER.FN_GET_CLIENTE_TMD'),
 (N'EAI_OWNER.LOG_START');
UPDATE @Objetos SET ID=OBJECT_ID(Nombre);

SELECT N'01_ENTORNO' Seccion,SYSDATETIMEOFFSET() Captura,
 @@SERVERNAME Servidor,DB_NAME() BaseActual,D.compatibility_level,D.collation_name,
 D.is_query_store_on,@@TRANCOUNT TransaccionesSesionDiagnostico
FROM sys.databases D WHERE D.database_id=DB_ID();

SELECT N'02_MODULOS' Seccion,X.Nombre,O.type_desc,O.modify_date,
 CASE WHEN X.ID IS NULL THEN N'AUSENTE O NO VISIBLE'
      WHEN M.definition IS NULL THEN N'SIN DEFINICION VISIBLE'
      ELSE N'VISIBLE' END Estado,
 DATALENGTH(M.definition) BytesDefinicion,
 CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) HashDefinicion
FROM @Objetos X LEFT JOIN sys.objects O ON O.object_id=X.ID
LEFT JOIN sys.sql_modules M ON M.object_id=X.ID ORDER BY X.Nombre;

SELECT N'03_PROCEDIMIENTOS' Seccion,X.Nombre,P.cached_time,P.last_execution_time,
 P.execution_count,
 P.total_elapsed_time/1000.0/NULLIF(P.execution_count,0) Media_ms,
 P.total_worker_time/1000.0/NULLIF(P.execution_count,0) CPU_media_ms,
 P.total_logical_reads*1.0/NULLIF(P.execution_count,0) LecturasPorEjecucion
FROM sys.dm_exec_procedure_stats P JOIN @Objetos X ON X.ID=P.object_id
WHERE P.database_id=DB_ID() ORDER BY P.total_elapsed_time DESC;

-- No sumar los tiempos inclusivos del padre y sus hijos.
-- Se materializan solo las 40 sentencias mas costosas antes de pedir sus planes.
DROP TABLE IF EXISTS #ReplenishmentSentencias;
SELECT TOP (40) X.Nombre,Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,
 Q.creation_time,Q.last_execution_time,Q.execution_count,
 Q.total_elapsed_time/1000.0 Total_ms,
 Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) Media_ms,
 Q.total_worker_time/1000.0/NULLIF(Q.execution_count,0) CPU_media_ms,
 Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) LecturasPorEjecucion,
 SUBSTRING(T.text,Q.statement_start_offset/2+1,
  (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
   ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) Sentencia
INTO #ReplenishmentSentencias
FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
JOIN @Objetos X ON X.ID=T.objectid
WHERE T.dbid=DB_ID() ORDER BY Q.total_elapsed_time DESC;

SELECT N'04_SENTENCIAS' Seccion,S.Nombre,S.creation_time,S.last_execution_time,
 S.execution_count,S.Total_ms,S.Media_ms,S.CPU_media_ms,S.LecturasPorEjecucion,
 CASE WHEN P.query_plan LIKE N'%CONVERT_IMPLICIT%' THEN N'SI (revisar operador)'
      WHEN P.query_plan IS NULL THEN N'PLAN NO DISPONIBLE' ELSE N'NO' END ConversionImplicitaEnPlan,
 S.Sentencia,TRY_CONVERT(xml,P.query_plan) PlanXML
FROM #ReplenishmentSentencias S
OUTER APPLY sys.dm_exec_text_query_plan(S.plan_handle,S.statement_start_offset,S.statement_end_offset) P
ORDER BY S.Total_ms DESC;
DROP TABLE #ReplenishmentSentencias;

DECLARE @Claves table(Tabla nvarchar(256),Columna sysname);
INSERT @Claves VALUES
 (N'EAI_OWNER.TMP_DOCUMENT_HEADER',N'ReferenceID'),
 (N'EAI_OWNER.TMP_DOCUMENT_DETAIL',N'ReferenceID'),
 (N'EAI_OWNER.TMP_DOCUMENT_CONDITIONS',N'ReferenceID'),
 (N'EAI_OWNER.TMP_DOCUMENT_PARTNERS',N'ReferenceID'),
 (N'T3.MATERIAL',N'Material'),(N'T3.CFDI_PRODSERV',N'Material'),
 (N'T3.PREVENTA_GENERAL',N'Referencia'),(N'T3.PREVENTA_GENERAL',N'Factura'),
 (N'T3.ENTREGA',N'Factura'),(N'T3.RF_COMPLEMENTO',N'Factura'),
 (N'EAI.IFC_FOLIOS_FE',N'Var_1'),
 (N'T3.REMISION_GENERAL',N'Factura'),(N'T3.REMISION_DETALLE',N'Factura'),
 (N'T3.MOV_CLIENTE',N'Cliente_SAP'),(N'T3.CLIENTE',N'Cliente_SAP'),
 (N'T3.CLIENTE',N'Cliente_V3'),(N'T3.DISTRIBUIDOR_FISCAL',N'Ctro'),
 (N'T3.REMISION_CTRO_SOCIEDAD',N'Ctro'),
 (N'EAI_OWNER.MX_PRINT_DELIVERY',N'Cust_to_SAP'),
 (N'EAI_OWNER.MX_PRINT_DELIVERY',N'Cliente_SAP'),
 (N'EAI_OWNER.MX_HASHTABLE',N'Type'),
 (N'EAI_OWNER.MX_NRIV_RELACION',N'FacturaSAP'),
 (N'EAI_OWNER.MX_NRIV',N'Centro'),
 (N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG',N'Row_ID'),
 (N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG',N'QUEUE_NAME'),
 (N'EAI_OWNER.TAO_CEDIS_VALID',N'Shipto_Hub'),(N'EAI.ZSDFE_SOC',N'BUKRS');

SELECT N'05_CLAVES' Seccion,K.Tabla,K.Columna,TY.name Tipo,
 C.max_length,C.collation_name,
 CASE WHEN C.column_id IS NULL THEN N'AUSENTE O NO VISIBLE'
      WHEN EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.index_columns IC
       ON IC.object_id=I.object_id AND IC.index_id=I.index_id
       WHERE I.object_id=C.object_id AND IC.column_id=C.column_id AND IC.key_ordinal=1
        AND I.type IN(1,2) AND I.is_disabled=0 AND I.is_hypothetical=0 AND I.has_filter=0)
      THEN N'CLAVE INICIAL EXISTENTE'
      ELSE N'REVISAR INDICES COMPUESTOS/FILTRADOS' END Acceso
FROM @Claves K LEFT JOIN sys.columns C
 ON C.object_id=OBJECT_ID(K.Tabla)
 -- El catalogo y las variables pueden tener intercalaciones distintas.
 AND C.name COLLATE DATABASE_DEFAULT = K.Columna COLLATE DATABASE_DEFAULT
LEFT JOIN sys.types TY ON TY.user_type_id=C.user_type_id
ORDER BY K.Tabla,K.Columna;

SELECT N'06_INDICES' Seccion,K.Tabla,I.name Indice,I.is_disabled,I.filter_definition,
 IC.key_ordinal,IC.is_included_column,C.name Columna
FROM (SELECT DISTINCT Tabla FROM @Claves) K
JOIN sys.indexes I ON I.object_id=OBJECT_ID(K.Tabla)
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
ORDER BY K.Tabla,I.index_id,IC.index_column_id;

SELECT N'07_ACTIVIDAD' Seccion,R.session_id,R.status,R.command,
 R.blocking_session_id,R.wait_type,R.wait_time,R.cpu_time,R.total_elapsed_time,
 R.logical_reads,S.open_transaction_count,S.program_name
FROM sys.dm_exec_requests R JOIN sys.dm_exec_sessions S ON S.session_id=R.session_id
WHERE R.database_id=DB_ID() AND R.session_id<>@@SPID;

SELECT N'08_TRANSACCIONES' Seccion,ST.session_id,S.status,S.program_name,
 AT.transaction_begin_time,AT.transaction_state,
 DT.database_transaction_log_bytes_used
FROM sys.dm_tran_session_transactions ST
JOIN sys.dm_tran_active_transactions AT ON AT.transaction_id=ST.transaction_id
JOIN sys.dm_tran_database_transactions DT ON DT.transaction_id=ST.transaction_id
JOIN sys.dm_exec_sessions S ON S.session_id=ST.session_id
WHERE DT.database_id=DB_ID();

SELECT N'09_DEPENDENCIAS' Seccion,X.Nombre Llamador,
 D.referenced_database_name,D.referenced_schema_name,D.referenced_entity_name
FROM @Objetos X JOIN sys.sql_expression_dependencies D ON D.referencing_id=X.ID
ORDER BY X.Nombre;

SELECT N'10_TRIGGERS' Seccion,K.Tabla,TR.name,TR.is_disabled,
 TS.execution_count,TS.total_elapsed_time/1000.0 Total_ms
FROM (SELECT DISTINCT Tabla FROM @Claves) K
JOIN sys.triggers TR ON TR.parent_id=OBJECT_ID(K.Tabla)
LEFT JOIN sys.dm_exec_trigger_stats TS ON TS.object_id=TR.object_id AND TS.database_id=DB_ID();

-- Dependencias sin fuente local: exportar estas celdas completas desde cuadricula.
SELECT N'11_FUENTES_FALTANTES' Seccion,X.Nombre,M.definition Definicion
FROM @Objetos X LEFT JOIN sys.sql_modules M ON M.object_id=X.ID
WHERE X.Nombre IN(N'T3.FN_EVAL_REMISION_OBD',N'dbo.getConv');
