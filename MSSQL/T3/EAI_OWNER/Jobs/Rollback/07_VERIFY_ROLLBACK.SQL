/*
    PASO 7 - VERIFICACION FINAL DE SOLO LECTURA
    ===========================================
    Comprueba que los componentes obligatorios fueron retirados. Los usuarios
    humanos no se consideran error porque el paso 6 es opcional.
*/
USE [T3QA];
GO
SET NOCOUNT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 51670, 'La verificacion debe ser ejecutada por un miembro de sysadmin.', 1;

DECLARE @Problems TABLE (CheckName NVARCHAR(100), Detail NVARCHAR(4000));

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs
           WHERE name LIKE N'ORA[_]%' AND description LIKE N'%Oracle DBMS_JOB%')
    INSERT @Problems VALUES (N'Jobs', N'Aun existen jobs ORA_* creados por la migracion.');

IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map]
               WHERE SqlAgent_Job_Name LIKE N'ORA[_]%')
    INSERT @Problems VALUES (N'Mapeo', N'La tabla de mapeo aun contiene filas ORA_*.');

IF EXISTS (SELECT 1 FROM msdb.sys.procedures
           WHERE name=N'T3_JOB_NEXT_RUN' AND schema_id=SCHEMA_ID(N'dbo'))
    INSERT @Problems VALUES (N'Wrapper', N'Aun existe msdb.dbo.T3_JOB_NEXT_RUN.');

IF EXISTS (SELECT 1 FROM msdb.sys.procedures
           WHERE name=N'T3_ADD_JOB_EXECUTORS' AND schema_id=SCHEMA_ID(N'dbo'))
    INSERT @Problems VALUES (N'Helper de altas', N'Aun existe msdb.dbo.T3_ADD_JOB_EXECUTORS.');

IF EXISTS (SELECT 1 FROM msdb.sys.database_principals WHERE name=N'T3JobExecutors')
    INSERT @Problems VALUES (N'Rol msdb', N'Aun existe msdb.T3JobExecutors.');

IF EXISTS (SELECT 1 FROM sys.database_principals
           WHERE name IN (N'T3BODExecutors', N'T3SqlAgentJobExecutor'))
    INSERT @Problems VALUES (N'Roles T3QA', N'Aun existe un rol de la solucion en T3QA.');

IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NOT NULL
    INSERT @Problems VALUES (N'Login tecnico', N'Aun existe T3_SQLAGENT_OWNER.');

SELECT CheckName, Detail FROM @Problems ORDER BY CheckName;
IF EXISTS (SELECT 1 FROM @Problems)
    THROW 51671, 'Rollback incompleto. Revise el listado mostrado antes de este error.', 1;

PRINT 'VERIFICACION CORRECTA: no se detectaron componentes obligatorios de la solucion.';
PRINT 'EAI_OWNER.JOB_NEXT_RUN permanece restaurado a su version previa.';
GO
