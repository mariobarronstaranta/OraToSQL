/*
    Crea en msdb el procedimiento controlado que permite actualizar solamente
    los cinco jobs administrados por EAI_OWNER.SF_JOB_MANAGE.

    Prerrequisitos
    -------------
    1. Ejecutar primero A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL.
    2. Ejecutar este archivo como sysadmin.
    3. Los cinco jobs y sus schedules deben existir y quedar posteriormente a
       nombre de T3_SQLAGENT_OWNER.

    Seguridad
    ---------
    - El procedimiento se ejecuta como el usuario msdb T3_SQLAGENT_OWNER.
    - La lista permitida es cerrada: jobs Oracle 216, 229, 236, 550 y 648.
    - Se valida la pareja exacta job/schedule, su asociacion y propietario.
    - El procedimiento no permite cambiar frecuencia, comandos ni propietario.
    - Este archivo no concede EXECUTE a usuarios finales; ese permiso se debe
      entregar posteriormente mediante un rol controlado de msdb.
*/

USE [msdb];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51200, 'Este script debe ser ejecutado por un miembro de sysadmin.', 1;
END;

IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NULL
BEGIN
    THROW 51201, 'No existe el login T3_SQLAGENT_OWNER. Ejecute primero el script A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL.', 1;
END;

IF USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
BEGIN
    THROW 51202, 'No existe el usuario T3_SQLAGENT_OWNER en msdb. Ejecute primero el script A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL.', 1;
END;

IF
(
    SELECT [sid]
    FROM sys.database_principals
    WHERE [name] = N'T3_SQLAGENT_OWNER'
) <> SUSER_SID(N'T3_SQLAGENT_OWNER')
BEGIN
    THROW 51203, 'El usuario msdb.T3_SQLAGENT_OWNER no corresponde al login del servidor.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS DRM
    INNER JOIN sys.database_principals AS R
        ON R.principal_id = DRM.role_principal_id
    INNER JOIN sys.database_principals AS M
        ON M.principal_id = DRM.member_principal_id
    WHERE R.[name] = N'SQLAgentUserRole'
      AND M.[name] = N'T3_SQLAGENT_OWNER'
)
BEGIN
    THROW 51204, 'T3_SQLAGENT_OWNER no pertenece a msdb.SQLAgentUserRole.', 1;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[T3_JOB_NEXT_RUN]
    @JobId          UNIQUEIDENTIFIER,
    @ScheduleId     INT,
    @Enabled        BIT,
    @ActiveDate     INT = NULL,
    @ActiveTime     INT = NULL
WITH EXECUTE AS N'T3_SQLAGENT_OWNER'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ExpectedJobName      SYSNAME,
        @ExpectedScheduleName SYSNAME,
        @ReturnCode           INT;

    DECLARE @AllowedJobs TABLE
    (
        JobName      SYSNAME NOT NULL,
        ScheduleName SYSNAME NOT NULL,
        PRIMARY KEY (JobName, ScheduleName)
    );

    INSERT INTO @AllowedJobs (JobName, ScheduleName)
    VALUES
        (N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',        N'SCH_ORA_216'),
        (N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY', N'SCH_ORA_229'),
        (N'ORA_236_EAI_OWNER_RECV_PAYMENT',              N'SCH_ORA_236'),
        (N'ORA_550_EAI_OWNER_RECV_INVOICE',              N'SCH_ORA_550'),
        (N'ORA_648_EAI_OWNER_RECV_CUSTOMER',             N'SCH_ORA_648');

    IF @JobId IS NULL OR @ScheduleId IS NULL OR @Enabled IS NULL
    BEGIN
        THROW 51210, 'JobId, ScheduleId y Enabled son obligatorios.', 1;
    END;

    IF (@ActiveDate IS NULL AND @ActiveTime IS NOT NULL)
       OR (@ActiveDate IS NOT NULL AND @ActiveTime IS NULL)
    BEGIN
        THROW 51211, 'ActiveDate y ActiveTime deben recibirse juntos o ambos deben ser NULL.', 1;
    END;

    IF @ActiveDate IS NOT NULL
       AND
       (
           LEN(CONVERT(VARCHAR(20), @ActiveDate)) <> 8
           OR TRY_CONVERT(DATE, CONVERT(CHAR(8), @ActiveDate), 112) IS NULL
       )
    BEGIN
        THROW 51212, 'ActiveDate no contiene una fecha valida en formato YYYYMMDD.', 1;
    END;

    IF @ActiveTime IS NOT NULL
       AND
       (
           @ActiveTime < 0
           OR @ActiveTime > 235959
           OR ((@ActiveTime / 100) % 100) > 59
           OR (@ActiveTime % 100) > 59
       )
    BEGIN
        THROW 51213, 'ActiveTime no contiene una hora valida en formato HHMMSS.', 1;
    END;

    SELECT
        @ExpectedJobName = J.[name],
        @ExpectedScheduleName = S.[name]
    FROM dbo.sysjobs AS J
    INNER JOIN dbo.sysjobschedules AS JS
        ON JS.job_id = J.job_id
    INNER JOIN dbo.sysschedules AS S
        ON S.schedule_id = JS.schedule_id
    INNER JOIN @AllowedJobs AS A
        ON A.JobName = J.[name]
       AND A.ScheduleName = S.[name]
    WHERE J.job_id = @JobId
      AND S.schedule_id = @ScheduleId;

    IF @ExpectedJobName IS NULL OR @ExpectedScheduleName IS NULL
    BEGIN
        THROW 51214, 'La pareja job/schedule no esta autorizada para administracion T3.', 1;
    END;

    IF
    (
        SELECT COUNT(*)
        FROM dbo.sysjobschedules
        WHERE schedule_id = @ScheduleId
    ) <> 1
    BEGIN
        THROW 51219, 'El schedule T3 no es exclusivo del job autorizado.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.sysjobs
        WHERE job_id = @JobId
          AND owner_sid = SUSER_SID(N'T3_SQLAGENT_OWNER')
    )
    BEGIN
        THROW 51215, 'El job autorizado no pertenece a T3_SQLAGENT_OWNER.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.sysschedules
        WHERE schedule_id = @ScheduleId
          AND owner_sid = SUSER_SID(N'T3_SQLAGENT_OWNER')
    )
    BEGIN
        THROW 51216, 'El schedule autorizado no pertenece a T3_SQLAGENT_OWNER.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

            EXEC @ReturnCode = dbo.sp_update_job
                @job_id = @JobId,
                @enabled = @Enabled;

            IF @ReturnCode <> 0
            BEGIN
                THROW 51217, 'sp_update_job no pudo actualizar el estado del job T3.', 1;
            END;

            IF @ActiveDate IS NOT NULL
            BEGIN
                EXEC @ReturnCode = dbo.sp_update_schedule
                    @schedule_id = @ScheduleId,
                    @active_start_date = @ActiveDate,
                    @active_start_time = @ActiveTime;

                IF @ReturnCode <> 0
                BEGIN
                    THROW 51218, 'sp_update_schedule no pudo actualizar la fecha/hora del schedule T3.', 1;
                END;
            END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

/* Verificacion del contexto configurado y de la lista de objetos permitidos. */
SELECT
    P.[name] AS Procedure_Name,
    USER_NAME(M.execute_as_principal_id) AS Execute_As_User,
    CASE WHEN HAS_PERMS_BY_NAME(N'dbo.T3_JOB_NEXT_RUN', N'OBJECT', N'EXECUTE') = 1
         THEN N'VISIBLE PARA EL EJECUTOR ACTUAL'
         ELSE N'NO VISIBLE PARA EL EJECUTOR ACTUAL'
    END AS Deployment_Verification
FROM sys.procedures AS P
INNER JOIN sys.sql_modules AS M
    ON M.object_id = P.object_id
WHERE P.object_id = OBJECT_ID(N'dbo.T3_JOB_NEXT_RUN', N'P');

SELECT
    A.Oracle_Job_No,
    A.Job_Name,
    S.[name] AS Schedule_Name,
    SUSER_SNAME(J.owner_sid) AS Job_Owner,
    SUSER_SNAME(S.owner_sid) AS Schedule_Owner,
    CASE WHEN JS.job_id IS NULL THEN N'NO ASOCIADO' ELSE N'ASOCIADO' END AS Association_Status
FROM
(
    VALUES
        (216, N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',        N'SCH_ORA_216'),
        (229, N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY', N'SCH_ORA_229'),
        (236, N'ORA_236_EAI_OWNER_RECV_PAYMENT',              N'SCH_ORA_236'),
        (550, N'ORA_550_EAI_OWNER_RECV_INVOICE',              N'SCH_ORA_550'),
        (648, N'ORA_648_EAI_OWNER_RECV_CUSTOMER',             N'SCH_ORA_648')
) AS A(Oracle_Job_No, Job_Name, Schedule_Name)
LEFT JOIN dbo.sysjobs AS J
    ON J.[name] = A.Job_Name
LEFT JOIN dbo.sysschedules AS S
    ON S.[name] = A.Schedule_Name
LEFT JOIN dbo.sysjobschedules AS JS
    ON JS.job_id = J.job_id
   AND JS.schedule_id = S.schedule_id
ORDER BY A.Oracle_Job_No;
GO
