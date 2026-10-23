/* Diagnostico de solo lectura. Ejecutar en la base productiva correcta.
   No ejecuta RECV_INVOICE, no crea indices ni cambia configuraciones.
   SQL Server 2016+; visibilidad de DMVs sujeta a permisos de monitoreo del DBA
   (VIEW SERVER STATE; en SQL Server 2022+ varias requieren VIEW SERVER PERFORMANCE STATE).
   Ejecutar antes y despues del mismo lote y guardar ambos resultados.
   Cache acumulada != duracion del ultimo lote. Comparar deltas solo si coinciden
   plan_handle/cached_time; no sumar tiempos inclusivos de padre e hijos.
*/
SET NOCOUNT ON;
DECLARE @SesionObjetivo int = NULL; -- SPID que ejecuta el lote; NULL: sesiones activas de esta BD.
DECLARE @ConsultarQueryStore bit = 0; -- 1: consultar historia ya capturada; no habilita Query Store.
DECLARE @Desde datetimeoffset = DATEADD(HOUR,-1,SYSDATETIMEOFFSET());
DECLARE @Objetos table (Nombre nvarchar(256) PRIMARY KEY, ID int NULL);
INSERT @Objetos (Nombre) VALUES
 (N'EAI_OWNER.RECV_INVOICE'),(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'),
 (N'EAI_OWNER.INVOICE_TO_PREVENTA'),(N'EAI_OWNER.INVOICE_TO_FACTURA'),
 (N'EAI_OWNER.DEBITNOTE_TO_IFC'),(N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),
 (N'EAI_OWNER.WA_FOLIO_FACTURA'),(N'EAI_OWNER.WA_CANTIDAD_UMV'),
 (N'EAI_OWNER.GETCONV'),(N'EAI_OWNER.FN_CHECK_INSTANCE'),
 (N'EAI_OWNER.FN_GET_DOC_TYPE'),(N'EAI_OWNER.FN_GET_CLIENTE_TMD'),
 (N'EAI_OWNER.LINE_ITEM_TEXT'),(N'EAI_OWNER.LOG_START'),
 (N'EAI.CONV_PLANT_TO_DIST'),(N'T3.DELIVERY_WA_OXXO'),
 (N'T3.GET_REMISION_INFO'),(N'T3.FN_EVAL_REMISION');
UPDATE @Objetos SET ID=OBJECT_ID(Nombre);

SELECT SYSDATETIMEOFFSET() AS Captura, @@SERVERNAME AS Servidor, DB_NAME() AS Base,
       SERVERPROPERTY('ProductVersion') AS Version, SERVERPROPERTY('Edition') AS Edicion,
       D.compatibility_level,D.collation_name,D.is_read_committed_snapshot_on,
       D.recovery_model_desc,D.is_query_store_on,
       @@TRANCOUNT AS TransaccionesSesionDiagnostico
FROM sys.databases D WHERE D.database_id=DB_ID();

-- Version desplegada y presencia de dependencias; hash para comparar con QA.
SELECT X.Nombre,O.type_desc,O.modify_date,M.uses_ansi_nulls,M.uses_quoted_identifier,
       DATALENGTH(M.definition) AS BytesDefinicion,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',M.definition),2) AS HashDefinicion
FROM @Objetos X LEFT JOIN sys.objects O ON O.object_id=X.ID
LEFT JOIN sys.sql_modules M ON M.object_id=X.ID ORDER BY X.Nombre;

SELECT X.Nombre AS Llamador,D.referenced_database_name,D.referenced_schema_name,
       D.referenced_entity_name,D.is_caller_dependent
FROM @Objetos X JOIN sys.sql_expression_dependencies D ON D.referencing_id=X.ID
ORDER BY X.Nombre,D.referenced_schema_name,D.referenced_entity_name;

-- Tiempo inclusivo, CPU y lecturas acumulados de ejecuciones terminadas.
SELECT X.Nombre,P.plan_handle,P.cached_time,P.last_execution_time,P.execution_count,
       P.total_elapsed_time/1000.0 AS ElapsedTotal_ms,
       P.total_worker_time/1000.0 AS CpuTotal_ms,
       P.total_elapsed_time/1000.0/NULLIF(P.execution_count,0) AS ElapsedMedio_ms,
       P.total_worker_time/1000.0/NULLIF(P.execution_count,0) AS CpuMedio_ms,
       P.total_logical_reads,P.total_logical_writes,P.total_physical_reads,
       P.last_elapsed_time/1000.0 AS UltimaDuracion_ms
FROM sys.dm_exec_procedure_stats P JOIN @Objetos X ON X.ID=P.object_id
WHERE P.database_id=DB_ID() ORDER BY P.total_elapsed_time DESC;

-- Sentencias internas: los planes expulsados/recompilados reinician su muestra.
SELECT TOP (40) X.Nombre,Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,
       Q.creation_time,Q.last_execution_time,Q.execution_count,
       Q.total_elapsed_time/1000.0 AS ElapsedTotal_ms,
       Q.total_worker_time/1000.0 AS CpuTotal_ms,Q.total_logical_reads,Q.total_logical_writes,
       SUBSTRING(T.text,Q.statement_start_offset/2+1,
           (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
            ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) AS Sentencia
FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
JOIN @Objetos X ON X.ID=T.objectid
WHERE T.dbid=DB_ID() ORDER BY Q.total_elapsed_time DESC;

-- Capturar DURANTE el lote. Los bloqueadores pueden estar inactivos.
SELECT R.session_id,R.status,R.command,R.blocking_session_id,R.wait_type,R.wait_time,
       R.wait_resource,R.cpu_time,R.total_elapsed_time,R.logical_reads,R.reads,R.writes,
       S.open_transaction_count,S.transaction_isolation_level,S.program_name,
       SUBSTRING(T.text,R.statement_start_offset/2+1,
           (CASE R.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
            ELSE R.statement_end_offset END-R.statement_start_offset)/2+1) AS SentenciaActiva
FROM sys.dm_exec_requests R JOIN sys.dm_exec_sessions S ON S.session_id=R.session_id
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) T
WHERE R.session_id<>@@SPID AND
      ((@SesionObjetivo IS NULL AND R.database_id=DB_ID()) OR R.session_id=@SesionObjetivo);

SELECT S.session_id,S.status,S.open_transaction_count,S.last_request_start_time,
       S.last_request_end_time,S.program_name,S.host_name
FROM sys.dm_exec_sessions S
WHERE S.session_id IN
 (SELECT blocking_session_id FROM sys.dm_exec_requests
  WHERE database_id=DB_ID() AND blocking_session_id>0);

SELECT ST.session_id,AT.transaction_begin_time,AT.transaction_type,AT.transaction_state,
       DT.database_transaction_log_bytes_used,DT.database_transaction_log_bytes_reserved
FROM sys.dm_tran_session_transactions ST
JOIN sys.dm_tran_active_transactions AT ON AT.transaction_id=ST.transaction_id
JOIN sys.dm_tran_database_transactions DT ON DT.transaction_id=ST.transaction_id
WHERE DT.database_id=DB_ID() AND (@SesionObjetivo IS NULL OR ST.session_id=@SesionObjetivo);

DECLARE @Tablas table (Nombre nvarchar(256) PRIMARY KEY,ID int NULL);
INSERT @Tablas (Nombre) VALUES
 (N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG'),(N'EAI_OWNER.TMP_DOCUMENT_HEADER'),
 (N'EAI_OWNER.TMP_DOCUMENT_DETAIL'),(N'EAI_OWNER.TMP_DOCUMENT_CONDITIONS'),
 (N'EAI_OWNER.MX_HASHTABLE'),(N'EAI_OWNER.MX_NRIV'),(N'EAI_OWNER.MX_NRIV_RELACION'),
 (N'EAI_OWNER.TAO_CEDIS_VALID'),(N'EAI_OWNER.MX_EAI_MESSAGE_LOG'),
 (N'T3.MATERIAL'),(N'T3.PREVENTA_GENERAL'),(N'T3.PREVENTA_DETALLE'),
 (N'T3.FACTURA_GENERAL'),(N'T3.FACTURA_DETALLE'),(N'T3.RF_COMPLEMENTO'),
 (N'T3.REMISION_GENERAL'),(N'T3.REMISION_DETALLE'),(N'T3.MOV_CLIENTE'),(N'T3.CLIENTE'),
 (N'T3.DISTRIBUIDOR_FISCAL'),(N'T3.REMISION_CTRO_SOCIEDAD'),
 (N'T3.DEBIT_NOTE_IFC'),(N'T3.RF_PROCESOS_LOG'),(N'EAI.IFC_FOLIOS_FE'),(N'EAI.ZSDFE_SOC');
UPDATE @Tablas SET ID=OBJECT_ID(Nombre);

SELECT T.Nombre,P.index_id,SUM(P.row_count) AS FilasAproximadas,
       SUM(P.reserved_page_count)*8.0/1024 AS MBReservados
FROM @Tablas T JOIN sys.dm_db_partition_stats P ON P.object_id=T.ID
GROUP BY T.Nombre,P.index_id ORDER BY T.Nombre,P.index_id;

-- Una fila por columna de indice: permite comprobar orden, INCLUDE y filtro.
SELECT T.Nombre,I.name AS Indice,I.type_desc,I.is_unique,I.is_disabled,I.filter_definition,
       IC.key_ordinal,IC.is_included_column,IC.is_descending_key,C.name AS Columna,
       U.user_seeks,U.user_scans,U.user_lookups,U.user_updates
FROM @Tablas T JOIN sys.indexes I ON I.object_id=T.ID
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id=DB_ID()
 AND U.object_id=I.object_id AND U.index_id=I.index_id
ORDER BY T.Nombre,I.index_id,IC.is_included_column,IC.key_ordinal,IC.index_column_id;

SELECT T.Nombre,S.name AS Estadistica,S.auto_created,S.user_created,S.no_recompute,
       P.last_updated,P.rows,P.rows_sampled,P.modification_counter
FROM @Tablas T JOIN sys.stats S ON S.object_id=T.ID
OUTER APPLY sys.dm_db_stats_properties(S.object_id,S.stats_id) P
ORDER BY T.Nombre,S.stats_id;

-- Verificar varchar/nvarchar y collations en claves usadas por el parser.
SELECT T.Nombre,C.name,TY.name AS Tipo,C.max_length,C.precision,C.scale,C.collation_name
FROM @Tablas T JOIN sys.columns C ON C.object_id=T.ID
JOIN sys.types TY ON TY.user_type_id=C.user_type_id
WHERE C.name IN ('ROW_ID','REFERENCEID','MATERIAL','FACTURA','TYPE','SOURCE','TARGET',
                'FACTURASAP','CLASE_FACTURA','CENTRO','VAR_1','CLIENTE_SAP')
ORDER BY T.Nombre,C.column_id;

-- Trabajo indirecto: triggers de tablas escritas/leidas en el flujo.
SELECT T.Nombre,OBJECT_SCHEMA_NAME(TR.object_id) AS Esquema,TR.name AS TriggerNombre,
       TR.is_disabled,TR.is_instead_of_trigger,TS.execution_count,
       TS.total_elapsed_time/1000.0 AS ElapsedTotal_ms,TS.total_worker_time/1000.0 AS CpuTotal_ms
FROM @Tablas T JOIN sys.triggers TR ON TR.parent_id=T.ID
LEFT JOIN sys.dm_exec_trigger_stats TS ON TS.object_id=TR.object_id AND TS.database_id=DB_ID();

-- Contadores acumulados de archivos. Comparar deltas, no inferir el lote de un promedio historico.
SELECT F.name,F.type_desc,V.num_of_reads,V.num_of_writes,V.io_stall_read_ms,V.io_stall_write_ms,
       V.num_of_bytes_read,V.num_of_bytes_written
FROM sys.dm_io_virtual_file_stats(DB_ID(),NULL) V
JOIN sys.database_files F ON F.file_id=V.file_id;

IF @ConsultarQueryStore=1 AND EXISTS
 (SELECT 1 FROM sys.databases WHERE database_id=DB_ID() AND is_query_store_on=1)
BEGIN
    SELECT actual_state_desc,desired_state_desc,readonly_reason,current_storage_size_mb
    FROM sys.database_query_store_options;
    -- Ventana por intervalos solapados, no por cada ejecucion individual; promedio ponderado.
    SELECT TOP (30) X.Nombre,Q.query_id,P.plan_id,
           SUM(R.count_executions) AS Ejecuciones,
           SUM(CONVERT(float,R.count_executions)*R.avg_duration)/1000.0 AS ElapsedTotal_ms,
           SUM(CONVERT(float,R.count_executions)*R.avg_cpu_time)/1000.0 AS CpuTotal_ms,
           SUM(CONVERT(float,R.count_executions)*R.avg_logical_io_reads) AS LecturasTotales,
           MIN(I.start_time) AS PrimerIntervalo,MAX(I.end_time) AS UltimoIntervalo
    FROM sys.query_store_query Q JOIN @Objetos X ON X.ID=Q.object_id
    JOIN sys.query_store_plan P ON P.query_id=Q.query_id
    JOIN sys.query_store_runtime_stats R ON R.plan_id=P.plan_id
    JOIN sys.query_store_runtime_stats_interval I ON I.runtime_stats_interval_id=R.runtime_stats_interval_id
    WHERE I.end_time>=@Desde AND R.execution_type=0
    GROUP BY X.Nombre,Q.query_id,P.plan_id ORDER BY ElapsedTotal_ms DESC;
END;
