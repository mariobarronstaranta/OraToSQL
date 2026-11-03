/* Solo lectura. No mata sesiones ni elimina respaldos.
   Ejecutar en una ventana nueva. DMV/XE pueden requerir permisos de servidor.
   El ring_buffer es limitado: ausencia de evento no descarta el deadlock.
*/
USE [T3QA];
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,@@SPID Sesion,
       @@TRANCOUNT TransaccionesSesion,XACT_STATE() EstadoTransaccion,
       SCHEMA_ID('REPAIR_AGR_20261028') EsquemaReparacion;
SELECT T.name Tabla,T.create_date
FROM sys.tables T WHERE T.schema_id=SCHEMA_ID('REPAIR_AGR_20261028');
IF OBJECT_ID('REPAIR_AGR_20261028.Estado','U') IS NOT NULL
 EXEC(N'SELECT * FROM REPAIR_AGR_20261028.Estado;');

BEGIN TRY
 SELECT R.session_id,R.status,R.command,R.blocking_session_id,
        R.wait_type,R.wait_time,R.wait_resource,R.open_transaction_count,
        S.host_name,S.program_name,S.login_name
 FROM sys.dm_exec_requests R JOIN sys.dm_exec_sessions S ON S.session_id=R.session_id
 WHERE R.session_id<>@@SPID
 AND (R.database_id=DB_ID() OR R.blocking_session_id<>0);
END TRY
BEGIN CATCH
 SELECT ERROR_MESSAGE() ErrorConsultaSesiones;
END CATCH;

BEGIN TRY
 ;WITH Eventos AS (
 SELECT TRY_CONVERT(xml,T.target_data) Datos
 FROM sys.dm_xe_session_targets T
 JOIN sys.dm_xe_sessions S ON S.address=T.event_session_address
 WHERE S.name='system_health' AND T.target_name='ring_buffer'
 )
 SELECT TOP(5) E.N.value('@timestamp','datetime2') FechaUTC,
        E.N.query('(data/value/deadlock)[1]') DeadlockXML
 FROM Eventos CROSS APPLY Datos.nodes('/RingBufferTarget/event[@name="xml_deadlock_report"]') E(N)
 ORDER BY FechaUTC DESC;
END TRY
BEGIN CATCH
 SELECT ERROR_MESSAGE() ErrorConsultaDeadlocks;
END CATCH;
