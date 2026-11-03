/*
  Solo lectura de catalogos y DMVs. Ejecutar completo en la misma base,
  en OTRA ventana de SSMS, mientras se procesa una carga normal de Invoice.
  Espera diez segundos. No cambia configuracion, indices, SP ni datos.
  No limpia cache ni recorre todas las paginas/indices.
  SQL Server 2022: requiere VIEW SERVER PERFORMANCE STATE para estas DMVs.
  Guardar todos los resultados, incluso si no hubo actividad.

  Contexto: captura 17:31:57 con PAGEIOLATCH_SH/EX en INVOICE_TO_FACTURA.
  Los contadores por archivo incluyen TODAS las sesiones de esta base.
  Una espera PAGEIOLATCH no identifica por si sola la causa del I/O lento.
*/
SET NOCOUNT ON;
DECLARE @SesionObjetivo int=NULL; -- Opcional: SPID ACTUAL; 105 fue el de la captura anterior.
DECLARE @BaseId int=DB_ID(),@Inicio datetime2(3),@Fin datetime2(3);

SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@@SPID AS SpidDiagnostico,
       @SesionObjetivo AS SesionObjetivo,D.state_desc,D.is_auto_close_on,
       D.is_auto_shrink_on,D.recovery_model_desc
FROM sys.databases D WHERE D.database_id=@BaseId;

-- Los promedios de esta seccion son historicos, no corresponden al lote.
SELECT '02_ARCHIVOS_ACUMULADO' AS Seccion,F.file_id,F.name AS Archivo,
       F.type_desc,F.physical_name,F.size/128.0 AS Tamano_MB,
       F.max_size,F.growth,F.is_percent_growth,
       V.num_of_reads,V.num_of_writes,
       V.io_stall_read_ms*1.0/NULLIF(V.num_of_reads,0) AS LecturaMediaHistorica_ms,
       V.io_stall_write_ms*1.0/NULLIF(V.num_of_writes,0) AS EscrituraMediaHistorica_ms
FROM sys.database_files F
LEFT JOIN sys.dm_io_virtual_file_stats(@BaseId,NULL) V ON V.file_id=F.file_id
ORDER BY F.file_id;

SELECT '03_MEMORIA_SISTEMA' AS Seccion,
       total_physical_memory_kb/1024.0 AS MemoriaFisicaTotal_MB,
       available_physical_memory_kb/1024.0 AS MemoriaFisicaDisponible_MB,
       system_low_memory_signal_state,system_high_memory_signal_state,
       system_memory_state_desc
FROM sys.dm_os_sys_memory;
SELECT '03B_MEMORIA_SQL' AS Seccion,
       physical_memory_in_use_kb/1024.0 AS MemoriaFisicaProcesoSQL_MB,
       locked_page_allocations_kb/1024.0 AS PaginasBloqueadas_MB,
       process_physical_memory_low,process_virtual_memory_low
FROM sys.dm_os_process_memory;
SELECT '03C_CONFIG_MEMORIA' AS Seccion,name,value,value_in_use
FROM sys.configurations WHERE name IN(N'min server memory (MB)',N'max server memory (MB)');

DECLARE @Sesiones TABLE(Spid int PRIMARY KEY,LoginTime datetime);
INSERT @Sesiones
SELECT DISTINCT S.session_id,S.login_time
FROM sys.dm_exec_sessions S INNER JOIN sys.dm_exec_requests R ON R.session_id=S.session_id
WHERE S.is_user_process=1 AND S.session_id<>@@SPID
  AND ((@SesionObjetivo IS NULL AND R.database_id=@BaseId) OR S.session_id=@SesionObjetivo);

SELECT '04_ACTIVIDAD_INICIAL' AS Seccion,S.session_id,S.program_name,
       R.database_id,R.status,R.command,R.cpu_time,R.total_elapsed_time,
       R.logical_reads,R.reads,R.writes,R.blocking_session_id,R.wait_type,
       R.wait_time,R.wait_resource,
       OBJECT_SCHEMA_NAME(T.objectid,T.dbid) AS Esquema,
       OBJECT_NAME(T.objectid,T.dbid) AS Modulo,
       CONVERT(nvarchar(200),SUBSTRING(T.text,R.statement_start_offset/2+1,200)) AS InicioSentencia
FROM @Sesiones A INNER JOIN sys.dm_exec_sessions S
 ON S.session_id=A.Spid AND S.login_time=A.LoginTime
INNER JOIN sys.dm_exec_requests R ON R.session_id=S.session_id
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) T;

DECLARE @Antes TABLE
 (FileId int PRIMARY KEY,HandleArchivo varbinary(64),Lecturas bigint,BytesLeidos bigint,
  EsperaLectura bigint,Escrituras bigint,BytesEscritos bigint,EsperaEscritura bigint);
DECLARE @Despues TABLE
 (FileId int PRIMARY KEY,HandleArchivo varbinary(64),Lecturas bigint,BytesLeidos bigint,
  EsperaLectura bigint,Escrituras bigint,BytesEscritos bigint,EsperaEscritura bigint);
DECLARE @EsperasAntes TABLE
 (Spid int,Tipo nvarchar(120) COLLATE DATABASE_DEFAULT,Tiempo bigint,Tareas bigint,
  PRIMARY KEY(Spid,Tipo));
INSERT @EsperasAntes
SELECT W.session_id,W.wait_type,W.wait_time_ms,W.waiting_tasks_count
FROM sys.dm_exec_session_wait_stats W
INNER JOIN @Sesiones A ON A.Spid=W.session_id
INNER JOIN sys.dm_exec_sessions S ON S.session_id=A.Spid AND S.login_time=A.LoginTime;
INSERT @Antes
SELECT file_id,file_handle,num_of_reads,num_of_bytes_read,io_stall_read_ms,
       num_of_writes,num_of_bytes_written,io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(@BaseId,NULL);
SET @Inicio=SYSDATETIME();
WAITFOR DELAY '00:00:10';
INSERT @Despues
SELECT file_id,file_handle,num_of_reads,num_of_bytes_read,io_stall_read_ms,
       num_of_writes,num_of_bytes_written,io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(@BaseId,NULL);
SET @Fin=SYSDATETIME();

-- Solo comparar el mismo archivo abierto con contadores monotonos.
;WITH Delta AS
(
 SELECT D.FileId,
        D.Lecturas-A.Lecturas AS Lecturas,D.BytesLeidos-A.BytesLeidos AS BytesLeidos,
        D.EsperaLectura-A.EsperaLectura AS EsperaLectura,
        D.Escrituras-A.Escrituras AS Escrituras,D.BytesEscritos-A.BytesEscritos AS BytesEscritos,
        D.EsperaEscritura-A.EsperaEscritura AS EsperaEscritura,
        CASE WHEN A.FileId IS NULL OR A.HandleArchivo<>D.HandleArchivo
          OR D.Lecturas<A.Lecturas OR D.BytesLeidos<A.BytesLeidos
          OR D.EsperaLectura<A.EsperaLectura OR D.Escrituras<A.Escrituras
          OR D.BytesEscritos<A.BytesEscritos OR D.EsperaEscritura<A.EsperaEscritura
          THEN 0 ELSE 1 END AS Comparable
 FROM @Despues D LEFT JOIN @Antes A ON A.FileId=D.FileId
)
SELECT '05_IO_VENTANA' AS Seccion,F.file_id,F.name AS Archivo,F.type_desc,
       F.physical_name,@Inicio AS Inicio,@Fin AS Fin,
       DATEDIFF(millisecond,@Inicio,@Fin) AS Ventana_ms,
       CASE WHEN D.Comparable=0 THEN N'CONTADORES NO COMPARABLES'
            WHEN D.Lecturas+D.Escrituras=0 THEN N'SIN IO EN VENTANA'
            ELSE N'COMPARABLE' END AS Estado,
       CASE WHEN D.Comparable=1 THEN D.Lecturas END AS Lecturas,
       CASE WHEN D.Comparable=1 THEN D.Escrituras END AS Escrituras,
       CASE WHEN D.Comparable=1 THEN D.EsperaLectura*1.0/NULLIF(D.Lecturas,0) END AS LecturaMedia_ms,
       CASE WHEN D.Comparable=1 THEN D.EsperaEscritura*1.0/NULLIF(D.Escrituras,0) END AS EscrituraMedia_ms,
       CASE WHEN D.Comparable=1 THEN D.BytesLeidos/1048576.0 END AS Leidos_MB,
       CASE WHEN D.Comparable=1 THEN D.BytesEscritos/1048576.0 END AS Escritos_MB
FROM Delta D INNER JOIN sys.database_files F ON F.file_id=D.FileId
ORDER BY F.file_id;

SELECT TOP(20) '06_ESPERAS_SESION' AS Seccion,W.session_id,W.wait_type,
       W.wait_time_ms-ISNULL(B.Tiempo,0) AS Espera_ms,
       W.waiting_tasks_count-ISNULL(B.Tareas,0) AS Tareas
FROM sys.dm_exec_session_wait_stats W
INNER JOIN @Sesiones A ON A.Spid=W.session_id
INNER JOIN sys.dm_exec_sessions S ON S.session_id=A.Spid AND S.login_time=A.LoginTime
LEFT JOIN @EsperasAntes B ON B.Spid=W.session_id AND B.Tipo=W.wait_type COLLATE DATABASE_DEFAULT
WHERE W.wait_time_ms>ISNULL(B.Tiempo,0) AND W.waiting_tasks_count>=ISNULL(B.Tareas,0)
ORDER BY W.wait_time_ms-ISNULL(B.Tiempo,0) DESC;

SELECT '07_ACTIVIDAD_FINAL' AS Seccion,S.session_id,R.status,R.command,
       R.cpu_time,R.total_elapsed_time,R.logical_reads,R.reads,R.writes,
       R.blocking_session_id,R.wait_type,R.wait_time,R.wait_resource,
       OBJECT_NAME(T.objectid,T.dbid) AS Modulo,
       CONVERT(nvarchar(200),SUBSTRING(T.text,R.statement_start_offset/2+1,200)) AS InicioSentencia
FROM @Sesiones A INNER JOIN sys.dm_exec_sessions S
 ON S.session_id=A.Spid AND S.login_time=A.LoginTime
INNER JOIN sys.dm_exec_requests R ON R.session_id=S.session_id
OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) T;

-- Contexto concurrente al cierre; una instantanea no mide consumo en la ventana.
SELECT '08_OTRA_ACTIVIDAD_ACTUAL' AS Seccion,R.session_id,DB_NAME(R.database_id) AS BaseActual,
       S.program_name,R.status,R.command,R.cpu_time,R.total_elapsed_time,
       R.reads,R.writes,R.logical_reads,R.wait_type,R.blocking_session_id
FROM sys.dm_exec_requests R INNER JOIN sys.dm_exec_sessions S ON S.session_id=R.session_id
WHERE R.session_id<>@@SPID AND NOT EXISTS(SELECT 1 FROM @Sesiones A WHERE A.Spid=R.session_id)
  AND (S.is_user_process=1 OR R.command LIKE N'%BACKUP%' OR R.command LIKE N'%RESTORE%')
ORDER BY R.reads DESC,R.writes DESC;

-- Frente adicional: nuevas llamadas a remision en el intervalo entre capturas.
-- Estos costos son ACUMULADOS; fecha/cache permiten separar su historia.
SELECT TOP(12) '09_SENTENCIAS_REMISION_CACHE' AS Seccion,
       OBJECT_SCHEMA_NAME(P.object_id) + N'.' + OBJECT_NAME(P.object_id) AS Modulo,
       P.cached_time,Q.creation_time,Q.last_execution_time,Q.execution_count,
       Q.total_elapsed_time/1000.0 AS TiempoTotal_ms,
       Q.total_elapsed_time/1000.0/NULLIF(Q.execution_count,0) AS Media_ms,
       Q.total_worker_time/1000.0/NULLIF(Q.execution_count,0) AS CPU_Media_ms,
       Q.total_logical_reads*1.0/NULLIF(Q.execution_count,0) AS LecturasPorLlamada,
       Q.plan_handle,Q.statement_start_offset,Q.statement_end_offset,
       CONVERT(nvarchar(200),SUBSTRING(T.text,Q.statement_start_offset/2+1,200)) AS InicioSentencia
FROM
 (SELECT object_id,sql_handle,MIN(cached_time) AS cached_time
  FROM sys.dm_exec_procedure_stats
  WHERE database_id=@BaseId
    AND object_id IN(OBJECT_ID(N'T3.GET_REMISION_INFO'),OBJECT_ID(N'T3.DELIVERY_WA_OXXO'))
  GROUP BY object_id,sql_handle) P
INNER JOIN sys.dm_exec_query_stats Q ON Q.sql_handle=P.sql_handle
OUTER APPLY sys.dm_exec_sql_text(Q.sql_handle) T
ORDER BY Q.total_elapsed_time DESC;

SELECT '10_INDICES_REMISION' AS Seccion,SC.name AS Esquema,O.name AS Tabla,
       I.name AS Indice,I.type_desc,I.is_disabled,I.has_filter,I.filter_definition,
       IC.key_ordinal,IC.is_included_column,C.name AS Columna,
       TYPE_NAME(C.system_type_id) AS TipoColumna,C.max_length,C.collation_name
FROM sys.objects O INNER JOIN sys.schemas SC ON SC.schema_id=O.schema_id
LEFT JOIN sys.indexes I ON I.object_id=O.object_id
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE O.object_id IN(OBJECT_ID(N'T3.CLIENTE'),OBJECT_ID(N'T3.DISTRIBUIDOR_FISCAL'),
 OBJECT_ID(N'EAI_OWNER.TAO_CEDIS_VALID'),OBJECT_ID(N'EAI.ZSDFE_SOC'),OBJECT_ID(N'T3.REMISION_CTRO_SOCIEDAD'))
ORDER BY SC.name,O.name,I.index_id,IC.is_included_column,IC.key_ordinal,IC.index_column_id;

SELECT '11_ALCANCE' AS Seccion,
 N'IO por archivo incluye todas las sesiones de esta base; no es exclusivo del lote. '
 +N'Historicos de 02 no equivalen a latencias de 05. Una captura de memoria no acredita ni descarta presion intermitente. '
 +N'Esperas de sesion pueden cruzar limites de la ventana; no sumar como porcentaje exacto. '
 +N'09 es cache acumulada, no costo exclusivo del lote; 10 solo catalogos. '
 +N'Sin actividad, repetir durante una carga normal. No cambia configuracion ni datos.' AS Observacion;
