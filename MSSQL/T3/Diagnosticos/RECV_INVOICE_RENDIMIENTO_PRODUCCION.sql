/*
  Ejecutar en OTRA ventana de SSMS, en la base PRODUCTIVA correcta,
  mientras RECV_INVOICE esta trabajando. No contiene USE fijo.
  Solo lectura de catalogos/DMVs y variables locales; espera 10 segundos.
  No ejecuta facturas, no captura XML de clientes, no crea indices ni altera SP.
  No hace COUNT sobre la cola ni limpia cache/estadisticas.
  Requiere acceso autorizado a las DMVs de servidor: VIEW SERVER STATE o,
  segun DMV/version, VIEW SERVER PERFORMANCE STATE en SQL Server 2022+.

  Guardar TODOS los resultados. Cache = llamadas terminadas, no la corrida
  exacta. Los tiempos de padres e hijos son inclusivos: NO sumarlos.
  Una marca presente/ausente orienta la revision; el plan determina el acceso.
*/
SET NOCOUNT ON;
DECLARE @SesionObjetivo INT = NULL; -- Opcional: SPID conocido de la ejecucion lenta.
DECLARE @Inicio DATETIME2(3) = SYSDATETIME();
DECLARE @Objetos TABLE (Nombre NVARCHAR(256) COLLATE DATABASE_DEFAULT, Id INT);
INSERT INTO @Objetos (Nombre) VALUES
 (N'EAI_OWNER.RECV_INVOICE'),(N'EAI_OWNER.RECV_INVOICE_OPTIMIZADO'),
 (N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'),(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC_OPTIMIZADO'),
 (N'EAI_OWNER.INVOICE_TO_PREVENTA'),(N'EAI_OWNER.INVOICE_TO_FACTURA'),
 (N'EAI_OWNER.DEBITNOTE_TO_IFC'),(N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),
 (N'EAI_OWNER.WA_FOLIO_FACTURA'),(N'EAI_OWNER.WA_CANTIDAD_UMV'),
 (N'T3.DELIVERY_WA_OXXO'),(N'T3.GET_REMISION_INFO');
UPDATE @Objetos SET Id = OBJECT_ID(Nombre, N'P');

SELECT '01_AMBIENTE' AS Seccion, @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura, @@SPID AS SpidDiagnostico,
       SERVERPROPERTY('ProductVersion') AS VersionSQL,
       D.compatibility_level, D.collation_name,
       D.recovery_model_desc, D.is_query_store_on
FROM sys.databases AS D WHERE D.database_id = DB_ID();

IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE',N'P') IS NULL
    THROW 52601, 'RECV_INVOICE no es visible: verificar base seleccionada y permisos de metadatos.', 1;

SELECT '02_VERSIONES' AS Seccion, X.Nombre, O.modify_date,
       DATALENGTH(M.definition) AS BytesDefinicion,
       CONVERT(VARCHAR(64),HASHBYTES('SHA2_256',M.definition),2) AS HashDefinicion,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_HEADER',M.definition)>0 THEN 1 ELSE 0 END AS MarcaSeekHeader,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_DETAIL',M.definition)>0 THEN 1 ELSE 0 END AS MarcaSeekDetail,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_CONDITIONS',M.definition)>0 THEN 1 ELSE 0 END AS MarcaSeekConditions,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'WHILE@i<=(SELECTCOUNT_BIG(*)FROM@Records)',
                 REPLACE(REPLACE(REPLACE(REPLACE(M.definition,N' ',N''),CHAR(13),N''),CHAR(10),N''),CHAR(9),N''))>0
            THEN 1 ELSE 0 END AS PatronConteoDentroWhile
FROM @Objetos AS X
LEFT JOIN sys.objects AS O ON O.object_id=X.Id
LEFT JOIN sys.sql_modules AS M ON M.object_id=X.Id
ORDER BY X.Nombre;

DECLARE @CacheAntes TABLE
 (Id INT, PlanHandle VARBINARY(64), CachedTime DATETIME, Ejecuciones BIGINT,
  Tiempo BIGINT, Cpu BIGINT, Lecturas BIGINT, Escrituras BIGINT);
INSERT INTO @CacheAntes
SELECT P.object_id,P.plan_handle,P.cached_time,P.execution_count,
       P.total_elapsed_time,P.total_worker_time,P.total_logical_reads,P.total_logical_writes
FROM sys.dm_exec_procedure_stats AS P
WHERE P.database_id=DB_ID() AND EXISTS (SELECT 1 FROM @Objetos X WHERE X.Id=P.object_id);

SELECT '03_CACHE_ACUMULADA' AS Seccion, X.Nombre, P.cached_time, P.last_execution_time,
       P.execution_count,
       P.total_elapsed_time/1000.0/NULLIF(P.execution_count,0) AS Media_ms,
       P.total_worker_time/1000.0/NULLIF(P.execution_count,0) AS CPU_Media_ms,
       P.total_logical_reads*1.0/NULLIF(P.execution_count,0) AS LecturasPorLlamada,
       P.last_elapsed_time/1000.0 AS UltimaLlamada_ms
FROM sys.dm_exec_procedure_stats AS P
INNER JOIN @Objetos AS X ON X.Id=P.object_id
WHERE P.database_id=DB_ID()
ORDER BY P.total_elapsed_time/NULLIF(P.execution_count,0) DESC;

-- Sentencias de mayor duracion media; no suma la duracion del padre con la hija.
SELECT TOP (20) '04_SENTENCIAS_CACHE' AS Seccion, X.Nombre,
       Q.creation_time,Q.last_execution_time,Q.execution_count,
       Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) AS Media_ms,
       Q.total_worker_time/1000.0/NULLIF(Q.execution_count,0) AS CPU_Media_ms,
       Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) AS LecturasPorLlamada,
       Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,
       CONVERT(NVARCHAR(200),LEFT(S.Sentencia,200)) AS InicioSentencia
FROM sys.dm_exec_query_stats AS Q
CROSS APPLY sys.dm_exec_sql_text(Q.sql_handle) AS T
INNER JOIN @Objetos AS X ON X.Id=T.objectid
CROSS APPLY (SELECT SUBSTRING(T.text,Q.statement_start_offset/2+1,
    (CASE Q.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
     ELSE Q.statement_end_offset END-Q.statement_start_offset)/2+1)) AS S(Sentencia)
WHERE T.dbid=DB_ID()
ORDER BY Q.total_elapsed_time/NULLIF(Q.execution_count,0) DESC;

DECLARE @Sesiones TABLE (Spid INT PRIMARY KEY, LoginTime DATETIME);
INSERT INTO @Sesiones
SELECT DISTINCT R.session_id,S.login_time
FROM sys.dm_exec_requests AS R
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=R.session_id
WHERE R.session_id<>@@SPID AND S.is_user_process=1
  AND ((@SesionObjetivo IS NULL AND R.database_id=DB_ID()) OR R.session_id=@SesionObjetivo);

SELECT '05_ACTIVIDAD_INICIAL' AS Seccion, R.session_id,R.request_id,
       S.program_name,R.status,R.command,R.cpu_time,R.total_elapsed_time,
       R.logical_reads,R.reads,R.writes,R.blocking_session_id,
       R.wait_type,R.wait_time,R.wait_resource,S.open_transaction_count,
       OBJECT_SCHEMA_NAME(T.objectid,T.dbid) AS EsquemaSentencia,
       OBJECT_NAME(T.objectid,T.dbid) AS ModuloSentencia,
       CONVERT(NVARCHAR(200),SUBSTRING(T.text,R.statement_start_offset/2+1,200)) AS InicioSentencia
FROM sys.dm_exec_requests AS R
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=R.session_id
INNER JOIN @Sesiones AS A ON A.Spid=S.session_id AND A.LoginTime=S.login_time
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) AS T;

SELECT DISTINCT '06_BLOQUEADORES' AS Seccion, B.session_id,B.status,
       B.program_name,B.host_name,B.open_transaction_count,
       B.last_request_start_time,B.last_request_end_time
FROM sys.dm_exec_requests AS R
INNER JOIN @Sesiones AS A ON A.Spid=R.session_id
INNER JOIN sys.dm_exec_sessions AS B ON B.session_id=R.blocking_session_id
WHERE R.blocking_session_id>0;

DECLARE @EsperasAntes TABLE
 (Spid INT, Tipo NVARCHAR(120) COLLATE DATABASE_DEFAULT,
  Tiempo BIGINT, Senal BIGINT, Tareas BIGINT);
INSERT INTO @EsperasAntes
SELECT W.session_id,W.wait_type,W.wait_time_ms,W.signal_wait_time_ms,W.waiting_tasks_count
FROM sys.dm_exec_session_wait_stats AS W
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=W.session_id
INNER JOIN @Sesiones AS A ON A.Spid=S.session_id AND A.LoginTime=S.login_time;

DECLARE @MuestraInicio DATETIME2(3)=SYSDATETIME();
WAITFOR DELAY '00:00:10';
DECLARE @MuestraFin DATETIME2(3)=SYSDATETIME();

-- Solo resta contadores si el mismo plan sigue en cache y no retrocedieron.
SELECT '07_DELTA_LLAMADAS' AS Seccion, X.Nombre,
       DATEDIFF(MILLISECOND,@Inicio,@MuestraFin) AS VentanaObservada_ms,
       CASE WHEN A.Id IS NULL OR P.execution_count<A.Ejecuciones
                      OR P.total_elapsed_time<A.Tiempo OR P.total_worker_time<A.Cpu
                      OR P.total_logical_reads<A.Lecturas OR P.total_logical_writes<A.Escrituras
            THEN N'PLAN NUEVO/CONTADORES NO COMPARABLES'
            ELSE N'MISMO PLAN' END AS Comparabilidad,
       CASE WHEN P.execution_count>=A.Ejecuciones THEN P.execution_count-A.Ejecuciones END AS LlamadasTerminadas,
       CASE WHEN P.execution_count>A.Ejecuciones AND P.total_elapsed_time>=A.Tiempo
            THEN (P.total_elapsed_time-A.Tiempo)/1000.0/(P.execution_count-A.Ejecuciones) END AS MediaEnVentana_ms,
       CASE WHEN P.execution_count>A.Ejecuciones AND P.total_worker_time>=A.Cpu
            THEN (P.total_worker_time-A.Cpu)/1000.0/(P.execution_count-A.Ejecuciones) END AS CPU_MediaEnVentana_ms,
       CASE WHEN P.execution_count>A.Ejecuciones AND P.total_logical_reads>=A.Lecturas
            THEN (P.total_logical_reads-A.Lecturas)*1.0/(P.execution_count-A.Ejecuciones) END AS LecturasPorLlamadaEnVentana
FROM sys.dm_exec_procedure_stats AS P
INNER JOIN @Objetos AS X ON X.Id=P.object_id
LEFT JOIN @CacheAntes AS A
  ON A.Id=P.object_id AND A.PlanHandle=P.plan_handle AND A.CachedTime=P.cached_time
WHERE P.database_id=DB_ID()
ORDER BY X.Nombre;

SELECT TOP (20) '08_DELTA_ESPERAS' AS Seccion, W.session_id,W.wait_type,
       DATEDIFF(MILLISECOND,@MuestraInicio,@MuestraFin) AS VentanaEsperas_ms,
       W.wait_time_ms-ISNULL(B.Tiempo,0) AS Espera_ms,
       W.signal_wait_time_ms-ISNULL(B.Senal,0) AS EsperaSenal_ms,
       W.waiting_tasks_count-ISNULL(B.Tareas,0) AS Tareas
FROM sys.dm_exec_session_wait_stats AS W
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=W.session_id
INNER JOIN @Sesiones AS A ON A.Spid=S.session_id AND A.LoginTime=S.login_time
LEFT JOIN @EsperasAntes AS B
  ON B.Spid=W.session_id AND B.Tipo=W.wait_type COLLATE DATABASE_DEFAULT
WHERE W.wait_time_ms>ISNULL(B.Tiempo,0)
  AND W.signal_wait_time_ms>=ISNULL(B.Senal,0)
  AND W.waiting_tasks_count>=ISNULL(B.Tareas,0)
ORDER BY W.wait_time_ms-ISNULL(B.Tiempo,0) DESC;

SELECT '09_ACTIVIDAD_FINAL' AS Seccion,R.session_id,R.status,R.cpu_time,
       R.total_elapsed_time,R.logical_reads,R.blocking_session_id,R.wait_type,
       OBJECT_NAME(T.objectid,T.dbid) AS ModuloSentencia,
       CONVERT(NVARCHAR(200),SUBSTRING(T.text,R.statement_start_offset/2+1,200)) AS InicioSentencia
FROM sys.dm_exec_requests AS R
INNER JOIN sys.dm_exec_sessions AS S ON S.session_id=R.session_id
INNER JOIN @Sesiones AS A ON A.Spid=S.session_id AND A.LoginTime=S.login_time
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) AS T;

-- Solo catalogos: tipos de claves e indices que pueden servir al parser/folios.
SELECT '10_ACCESOS' AS Seccion, SC.name AS Esquema,O.name AS Tabla,
       I.name AS Indice,I.is_disabled,I.has_filter,I.filter_definition,
       IC.key_ordinal,IC.is_included_column,C.name AS Columna,
       TYPE_NAME(C.system_type_id) AS TipoColumna,C.max_length,C.collation_name
FROM sys.objects AS O
INNER JOIN sys.schemas AS SC ON SC.schema_id=O.schema_id
INNER JOIN sys.indexes AS I ON I.object_id=O.object_id AND I.index_id>0
INNER JOIN sys.index_columns AS IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
INNER JOIN sys.columns AS C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE O.object_id IN
 (OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_HEADER'),OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_DETAIL'),
  OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_CONDITIONS'),OBJECT_ID(N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG'),
  OBJECT_ID(N'EAI_OWNER.MX_NRIV_RELACION'),OBJECT_ID(N'EAI_OWNER.MX_NRIV'),
  OBJECT_ID(N'EAI_OWNER.MX_HASHTABLE'),OBJECT_ID(N'T3.MATERIAL'))
ORDER BY SC.name,O.name,I.index_id,IC.is_included_column,IC.key_ordinal,IC.index_column_id;

SELECT '11_ALCANCE' AS Seccion,
       N'Captura de metadatos y cache; no ejecuta negocio. Sin sesiones o sin nuevas llamadas, '
       + N'repetir durante el lote activo. Processed/cantidad de llamadas no prueba insercion final. '
       + N'No sumar tiempos de RECV_INVOICE, parser e hijos; son inclusivos.' AS Observacion;
