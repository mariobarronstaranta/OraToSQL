/*
 Solo lectura en AZCRNMXNEVTD06 / T3QA.
 No ejecuta ni reprocesa remisiones. No modifica procedimientos ni indices.
 Corrige la limitacion del diagnostico general: no usa TOP 40 global.
 Ejecutar en SSMS con resultados en cuadricula (Ctrl+D).
 Las metricas son acumuladas; no sumarlas a tiempos inclusivos de los padres.
*/
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51960,'Seleccionar T3QA.',1;
DECLARE @id int=OBJECT_ID(N'T3.DELIVERY_IDOC_TO_REMISION');
IF @id IS NULL THROW 51966,'No se encuentra DELIVERY_IDOC_TO_REMISION.',1;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,SYSDATETIMEOFFSET() Captura;

SELECT N'01_PROCEDIMIENTO' Seccion,P.cached_time,P.last_execution_time,P.execution_count,
 P.total_elapsed_time/1000.0 Total_ms,
 P.total_elapsed_time/1000.0/NULLIF(P.execution_count,0) Media_ms,
 P.last_elapsed_time/1000.0 Ultima_ms,
 P.last_worker_time/1000.0 UltimaCPU_ms,P.last_logical_reads UltimasLecturas,
 P.total_logical_reads
FROM sys.dm_exec_procedure_stats P WHERE P.database_id=DB_ID() AND P.object_id=@id;

SELECT N'02_SENTENCIAS_REMISION' Seccion,Q.creation_time,Q.last_execution_time,Q.execution_count,
 Q.total_elapsed_time/1000.0 Total_ms,
 Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) Media_ms,
 Q.last_elapsed_time/1000.0 Ultima_ms,Q.last_worker_time/1000.0 UltimaCPU_ms,
 Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) LecturasPorEjecucion,
 Q.last_logical_reads UltimasLecturas,
 SUBSTRING(T.text,Q.statement_start_offset/2+1,
  (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
   ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1) Sentencia,
 TRY_CONVERT(xml,QP.query_plan) PlanXML
FROM sys.dm_exec_query_stats Q
CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
OUTER APPLY sys.dm_exec_text_query_plan(Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset) QP
WHERE T.dbid=DB_ID() AND T.objectid=@id
ORDER BY Q.total_elapsed_time DESC;

-- Plan completo: incluye definiciones/operaciones de cursores que no siempre
-- quedan bien representadas en la lista de sentencias. Es plan de cache,
-- no contiene necesariamente contadores reales por operador.
SELECT N'03_PLAN_COMPLETO' Seccion,P.cached_time,P.execution_count,QP.query_plan PlanXML
FROM sys.dm_exec_procedure_stats P
OUTER APPLY sys.dm_exec_query_plan(P.plan_handle) QP
WHERE P.database_id=DB_ID() AND P.object_id=@id;

-- Errores de remision y sus hijos, acotados al dia actual.
-- Los hijos tambien atienden otros procesos: correlacionar por referencia/hora.
SELECT TOP (50) N'04_ERRORES' Seccion,CREATED,QUEUE_NAME,REFERENCE,
 SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE CREATED>=CONVERT(date,SYSDATETIME())
 AND QUEUE_NAME IN('DELIVERY_TO_REMISION','GET_REMISION_INFO','Folio Interno')
ORDER BY CREATED DESC;

-- Verificar tipos de claves/joins y tamanos de catalogos sin recorrer datos.
DECLARE @Tablas table(Nombre nvarchar(256),ID int);
INSERT @Tablas(Nombre) VALUES
 (N'EAI_OWNER.TMP_DOCUMENT_HEADER'),(N'EAI_OWNER.TMP_DOCUMENT_DETAIL'),
 (N'T3.REMISION_GENERAL'),(N'T3.REMISION_DETALLE'),(N'T3.MATERIAL'),
 (N'T3.REMISION_CTRO_SOCIEDAD'),(N'T3.DISTRIBUIDOR_FISCAL'),
 (N'EAI_OWNER.MX_HASHTABLE'),(N'EAI.ZSDFE_SOC');
UPDATE @Tablas SET ID=OBJECT_ID(Nombre);
SELECT N'05_TAMANOS' Seccion,T.Nombre,SUM(P.row_count) FilasAproximadas
FROM @Tablas T JOIN sys.dm_db_partition_stats P ON P.object_id=T.ID AND P.index_id IN(0,1)
GROUP BY T.Nombre;
SELECT N'06_TIPOS' Seccion,T.Nombre,C.name Columna,
 TYPE_NAME(C.system_type_id) Tipo,C.max_length,C.precision,C.scale,C.collation_name
FROM @Tablas T JOIN sys.columns C ON C.object_id=T.ID
WHERE C.name IN(N'REFERENCEID',N'FACTURA',N'FACTURASAP',N'MATERIAL',N'NUM_LINEA',
 N'CTRO',N'SHIPPINGPOINT',N'SHIP_TO_SAP',N'TYPE',N'SOURCE',N'TARGET',N'BUKRS',N'KUNNR')
ORDER BY T.Nombre,C.column_id;
