/*
  Solo lectura. Ejecutar en la misma base de la captura anterior.
  No contiene USE, WAITFOR ni ejecuciones del proceso de facturacion.
  Consulta primero los handles de tres procedimientos, evitando aplicar
  dm_exec_sql_text a todos los planes de la instancia antes de filtrar.
  Se pueden obtener planes de cache aunque el lote ya haya terminado.
  Requiere permisos de monitoreo y visibilidad de las definiciones/indices.

  Guardar resultados de texto y los XML de 05_PLANES como archivos .sqlplan.
  El plan de cache es compilado; no contiene necesariamente contadores reales.
  Los datos de cache son acumulados y no se suman los tiempos padre/hijo.
*/
SET NOCOUNT ON;
SELECT '01_AMBIENTE' AS Seccion, @@SERVERNAME AS Servidor,
       DB_NAME() AS BaseActual, SYSDATETIMEOFFSET() AS FechaCaptura;

DECLARE @Objetos TABLE(Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,Id INT);
INSERT INTO @Objetos VALUES
 (N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'P')),
 (N'T3.DELIVERY_WA_OXXO',OBJECT_ID(N'T3.DELIVERY_WA_OXXO',N'P')),
 (N'T3.GET_REMISION_INFO',OBJECT_ID(N'T3.GET_REMISION_INFO',N'P'));

-- Conserva los planes con sus metadatos para no seleccionar otro entre consultas.
DECLARE @Planes TABLE
 (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,PlanHandle VARBINARY(64),
  SqlHandle VARBINARY(64),CachedTime DATETIME,UltimaEjecucion DATETIME,Ejecuciones BIGINT);
INSERT INTO @Planes
SELECT X.Nombre,P.plan_handle,P.sql_handle,P.cached_time,P.last_execution_time,P.execution_count
FROM @Objetos AS X
INNER JOIN sys.dm_exec_procedure_stats AS P ON P.object_id=X.Id AND P.database_id=DB_ID();

-- Solamente los sql_handle de los procedimientos objetivo; no filtra por T.dbid,
-- que puede no estar informado en otros tipos de planes/textos.
SELECT TOP (20) '02_SENTENCIAS_OBJETIVO' AS Seccion,H.Nombre,
       Q.creation_time,Q.last_execution_time,Q.execution_count,
       Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) AS Media_ms,
       Q.total_worker_time/1000.0/NULLIF(Q.execution_count,0) AS CPU_Media_ms,
       Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) AS LecturasPorLlamada,
       Q.last_dop,Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,
       CONVERT(NVARCHAR(200),LEFT(S.Sentencia,200)) AS InicioSentencia
FROM sys.dm_exec_query_stats AS Q
INNER JOIN (SELECT DISTINCT Nombre,SqlHandle FROM @Planes) AS H ON H.SqlHandle=Q.sql_handle
CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) AS T
CROSS APPLY (SELECT SUBSTRING(T.text,Q.statement_start_offset/2+1,
   (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
    ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1)) AS S(Sentencia)
ORDER BY Q.total_elapsed_time/NULLIF(Q.execution_count,0) DESC;

DECLARE @Tablas TABLE (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT,Id INT);
INSERT INTO @Tablas VALUES
 (N'EAI_OWNER.TMP_DOCUMENT_HEADER',OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_HEADER')),
 (N'EAI_OWNER.TMP_DOCUMENT_DETAIL',OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_DETAIL')),
 (N'EAI_OWNER.TMP_DOCUMENT_CONDITIONS',OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_CONDITIONS'));

-- El LEFT JOIN conserva una fila incluso si falta un indice inicial por REFERENCEID.
SELECT '03_CLAVE_REFERENCEID' AS Seccion,X.Nombre,
       TYPE_NAME(C.system_type_id) AS TipoReferenceId,C.max_length,C.collation_name,
       I.name AS IndiceConReferenceIdPrimero,I.is_disabled,I.has_filter,I.filter_definition
FROM @Tablas AS X
LEFT JOIN sys.columns AS C
 ON C.object_id=X.Id AND C.column_id=COLUMNPROPERTY(X.Id,N'REFERENCEID',N'ColumnId')
LEFT JOIN sys.index_columns AS IC
 ON IC.object_id=C.object_id AND IC.column_id=C.column_id AND IC.key_ordinal=1
LEFT JOIN sys.indexes AS I ON I.object_id=IC.object_id AND I.index_id=IC.index_id
ORDER BY X.Nombre,I.name;

DECLARE @Def NVARCHAR(MAX)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'P'));
SELECT '04_DELETE_INSTALADO' AS Seccion,X.Nombre,
       CASE WHEN @Def IS NULL THEN N'DEFINICION NO VISIBLE'
            WHEN P.Posicion=0 THEN N'FORMATO DIFERENTE; REVISAR DEFINICION'
            ELSE N'FRAGMENTO ENCONTRADO' END AS Estado,
       CASE WHEN P.Posicion>0 THEN CONVERT(NVARCHAR(200),
            SUBSTRING(@Def,P.Posicion,CHARINDEX(N';',@Def+N';',P.Posicion)-P.Posicion+1)) END AS Fragmento,
       CASE WHEN @Def IS NULL THEN NULL
            WHEN CHARINDEX(N'RI_REF_SEEK_'+PARSENAME(X.Nombre,1),@Def)>0 THEN 1 ELSE 0 END AS MarcaSeek
FROM @Tablas AS X
CROSS APPLY (SELECT CHARINDEX(N'DELETE FROM [EAI_OWNER].'+QUOTENAME(PARSENAME(X.Nombre,1)),@Def)) AS P(Posicion);

-- Un plan por procedimiento: el de actividad mas reciente. Si es NULL, el plan
-- pudo salir de cache o superar los limites del XML; informar ese resultado.
SELECT '05_PLANES' AS Seccion,X.Nombre,P.CachedTime,P.UltimaEjecucion,
       P.Ejecuciones,P.PlanHandle,Q.query_plan AS PlanXML
FROM @Objetos AS X
OUTER APPLY (SELECT TOP (1) A.* FROM @Planes AS A
             WHERE A.Nombre=X.Nombre
             ORDER BY A.UltimaEjecucion DESC,A.Ejecuciones DESC) AS P
OUTER APPLY sys.dm_exec_query_plan(P.PlanHandle) AS Q
ORDER BY X.Nombre;

-- Foto instantanea, sin esperar: registrar bloqueos si el lote esta activo.
SELECT '06_ACTIVIDAD' AS Seccion,R.session_id,R.status,R.blocking_session_id,
       R.wait_type,R.wait_time,R.wait_resource,R.cpu_time,R.total_elapsed_time,
       R.logical_reads,S.program_name,
       OBJECT_SCHEMA_NAME(T.objectid,T.dbid) AS EsquemaSentencia,
       OBJECT_NAME(T.objectid,T.dbid) AS ModuloSentencia,
       CONVERT(NVARCHAR(200),SUBSTRING(T.text,R.statement_start_offset/2+1,200)) AS InicioSentencia
FROM sys.dm_exec_requests AS R
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=R.session_id
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) AS T
WHERE R.session_id<>@@SPID AND R.database_id=DB_ID() AND S.is_user_process=1;

SELECT '07_ALCANCE' AS Seccion,
       N'Guardar los tres PlanXML como .sqlplan y los resultados de texto. '
       + N'Sin ejecucion del lote se pueden revisar planes/cache, pero no se acreditan esperas actuales. '
       + N'No cambia procedimientos ni crea indices.' AS Observacion;
