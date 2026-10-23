-- Ejecutar en AZCRNMXNEVTD06 / T3QA. Solo lectura; no ejecuta facturas.
SET NOCOUNT ON;
IF DB_NAME()<>N'T3QA' THROW 51940,'Seleccionar la base T3QA.',1;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual;
-- Guardar esta definicion como archivo .sql antes del cambio.
SELECT M.definition AS DefinicionAntesDelCambio,M.uses_ansi_nulls,M.uses_quoted_identifier
FROM sys.sql_modules M WHERE M.object_id=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC');

-- Planes en cache de los DELETE: buscar CONVERT_IMPLICIT sobre ReferenceID,
-- Index Scan/Seek. Puede no haber resultados si el plan fue expulsado.
SELECT Q.execution_count,Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) AS Media_ms,
 Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) AS LecturasPorEjecucion,
 S.Sentencia,TRY_CONVERT(xml,P.query_plan) AS PlanXML
FROM sys.dm_exec_query_stats Q CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) T
CROSS APPLY (SELECT SUBSTRING(T.text,Q.statement_start_offset/2+1,
 (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text) ELSE Q.statement_end_offset END
 -Q.statement_start_offset)/2+1)) S(Sentencia)
OUTER APPLY sys.dm_exec_text_query_plan(Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset) P
WHERE T.dbid=DB_ID() AND T.objectid=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC')
 AND S.Sentencia LIKE N'%DELETE%TMP_DOCUMENT%';
