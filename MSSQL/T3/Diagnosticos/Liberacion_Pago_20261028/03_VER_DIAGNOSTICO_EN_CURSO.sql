/*
  Solo lectura, una instantanea, sin WAITFOR ni recorridos de tablas de negocio.
  Ejecutar en OTRA ventana mientras 01 siga trabajando. Si se conoce el SPID
  de la ventana de 01, ponerlo en @Spid; de lo contrario se buscan sus marcadores.
  No cancela sesiones ni hace KILL. No inicia el procedimiento de negocio.
  SQL 2022 requiere VIEW SERVER PERFORMANCE STATE para observar otras sesiones.
*/
SET NOCOUNT ON;
DECLARE @Spid int=NULL;
SELECT '01_AMBIENTE' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,@@SPID AS SpidObservador,@Spid AS SpidBuscado;
DECLARE @R table(SessionId int,RequestId int,SqlHandle varbinary(64),PlanHandle varbinary(64),
 Inicio int,Fin int,Estado nvarchar(60),Comando nvarchar(32),CPU_ms int,Tiempo_ms int,
 LecturasLogicas bigint,LecturasFisicas bigint,Escrituras bigint,Bloqueador int,
 Espera nvarchar(60),Espera_ms int,Recurso nvarchar(256),BaseId int);
INSERT @R
SELECT R.session_id,R.request_id,R.sql_handle,R.plan_handle,R.statement_start_offset,
 R.statement_end_offset,R.status,R.command,R.cpu_time,R.total_elapsed_time,
 R.logical_reads,R.reads,R.writes,R.blocking_session_id,R.wait_type,R.wait_time,
 R.wait_resource,R.database_id
FROM sys.dm_exec_requests R OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) T
WHERE R.session_id<>@@SPID AND
 ((@Spid IS NOT NULL AND R.session_id=@Spid)
 OR (@Spid IS NULL AND R.database_id=DB_ID() AND
 (T.text LIKE N'%DeclaraFacturaPagadaVarchar4%' OR T.text LIKE N'%#Config%'
  OR T.text LIKE N'%#Candidatos%' OR T.text LIKE N'%#Hallazgos%')));

SELECT '02_SOLICITUD_ACTIVA' AS Seccion,R.SessionId,R.RequestId,DB_NAME(R.BaseId) AS BaseActual,
 S.login_name,S.program_name,R.Estado,R.Comando,R.Tiempo_ms,R.CPU_ms,
 R.LecturasLogicas,R.LecturasFisicas,R.Escrituras,R.Bloqueador,R.Espera,R.Espera_ms,
 R.Recurso,S.open_transaction_count,
 SUBSTRING(T.text,R.Inicio/2+1,
  CASE WHEN R.Fin=-1 THEN (DATALENGTH(T.text)-R.Inicio)/2+1
       ELSE (R.Fin-R.Inicio)/2+1 END) AS SentenciaActual,
 R.PlanHandle,R.Inicio AS OffsetInicio,R.Fin AS OffsetFin
FROM @R R INNER JOIN sys.dm_exec_sessions S ON S.session_id=R.SessionId
OUTER APPLY sys.dm_exec_sql_text(R.SqlHandle) T;

SELECT '03_BLOQUEADORES' AS Seccion,S.session_id,S.login_name,S.program_name,S.status,
 S.open_transaction_count,S.last_request_start_time,S.last_request_end_time
FROM sys.dm_exec_sessions S WHERE EXISTS(SELECT 1 FROM @R R
 WHERE R.Bloqueador>0 AND R.Bloqueador=S.session_id);

SELECT TOP(15) '04_ESPERAS_ACUMULADAS_SESION' AS Seccion,W.session_id,W.wait_type,
 W.wait_time_ms,W.signal_wait_time_ms,W.waiting_tasks_count
FROM sys.dm_exec_session_wait_stats W
WHERE EXISTS(SELECT 1 FROM @R R WHERE R.SessionId=W.session_id)
ORDER BY W.wait_time_ms DESC;

IF NOT EXISTS(SELECT 1 FROM @R)
 SELECT '05_SIN_COINCIDENCIA' AS Seccion,
 N'No se encontro la solicitud. Puede haber terminado o cambiado de contexto; si sigue activa, completar @Spid.' AS Resultado;
SELECT '06_ALCANCE' AS Seccion,
 N'Una instantanea no mide progresion ni duracion total de una espera. Las esperas de sesion incluyen historia anterior. '
 +N'Guardar SentenciaActual completa si la exportacion la corta. No cancela ni modifica sesiones.' AS Resultado;
