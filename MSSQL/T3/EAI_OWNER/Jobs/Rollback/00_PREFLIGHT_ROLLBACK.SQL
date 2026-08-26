/*
    PASO 0 - PREFLIGHT DE SOLO LECTURA.

    No modifica objetos. Confirma el servidor/base, muestra los jobs que aún
    están ejecutándose y resume los objetos de seguridad que serán retirados.
    No continúe si Running_Jobs es mayor que cero.
*/
USE [T3QA];
GO

SET NOCOUNT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 51610, 'Ejecute el preflight con una cuenta sysadmin.', 1;

DECLARE @TechnicalSid VARBINARY(85) = SUSER_SID(N'T3_SQLAGENT_OWNER');
DECLARE @CurrentAgentSession INT =
(
    SELECT MAX(session_id) FROM msdb.dbo.syssessions
);

SELECT @@SERVERNAME AS Server_Name, DB_NAME() AS Database_Name,
       SUSER_SNAME() AS Executed_By, SYSDATETIME() AS Checked_At;

SELECT J.[name] AS Running_Job, A.start_execution_date
FROM msdb.dbo.sysjobactivity AS A
INNER JOIN msdb.dbo.sysjobs AS J ON J.job_id = A.job_id
WHERE A.session_id = @CurrentAgentSession
  AND A.start_execution_date IS NOT NULL
  AND A.stop_execution_date IS NULL
  AND (@TechnicalSid IS NULL OR J.owner_sid = @TechnicalSid);

IF EXISTS
(
    SELECT 1
    FROM msdb.dbo.sysjobactivity AS A
    INNER JOIN msdb.dbo.sysjobs AS J ON J.job_id = A.job_id
    WHERE A.session_id = @CurrentAgentSession
      AND A.start_execution_date IS NOT NULL
      AND A.stop_execution_date IS NULL
      AND (@TechnicalSid IS NULL OR J.owner_sid = @TechnicalSid)
)
    THROW 51611, 'Hay jobs del alcance en ejecucion. Espere a que terminen o solicite a DBA que los detenga.', 1;

SELECT
    SUM(CASE WHEN J.[enabled] = 1 THEN 1 ELSE 0 END) AS Enabled_Jobs,
    COUNT(*) AS Migrated_Jobs_Found
FROM msdb.dbo.sysjobs AS J
WHERE J.[name] LIKE N'ORA[_]%'
  AND J.[description] LIKE N'Migrado de Oracle DBMS_JOB%';

SELECT
    SUSER_ID(N'T3_SQLAGENT_OWNER') AS Technical_Login_Id,
    OBJECT_ID(N'msdb.dbo.T3_JOB_NEXT_RUN', N'P') AS Wrapper_Object_Id,
    (SELECT principal_id FROM msdb.sys.database_principals WHERE [name]=N'T3JobExecutors') AS Msdb_Role_Id,
    (SELECT principal_id FROM T3QA.sys.database_principals WHERE [name]=N'T3BODExecutors') AS T3_BOD_Role_Id,
    (SELECT principal_id FROM T3QA.sys.database_principals WHERE [name]=N'T3SqlAgentJobExecutor') AS T3_Agent_Role_Id;
GO
