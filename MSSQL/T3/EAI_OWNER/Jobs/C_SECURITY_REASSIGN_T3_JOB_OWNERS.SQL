/*
    Reasigna al login tecnico T3_SQLAGENT_OWNER los 37 jobs y schedules
    migrados. Esto cubre SF_JOB_MANAGE, JOB_INTERVAL, JOB_NEXT_DATE y
    JOB_MANAGE.

    Debe ejecutarlo un miembro de sysadmin despues de crear los jobs con
    01_CREATE_OR_UPDATE_JOBS.SQL. El script es idempotente.
*/

USE [msdb];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @OwnerLogin SYSNAME = N'T3_SQLAGENT_OWNER';

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51300, 'Este script debe ser ejecutado por un miembro de sysadmin.', 1;
END;

IF SUSER_ID(@OwnerLogin) IS NULL
BEGIN
    THROW 51301, 'No existe el login T3_SQLAGENT_OWNER.', 1;
END;

IF USER_ID(@OwnerLogin) IS NULL
BEGIN
    THROW 51302, 'No existe el usuario T3_SQLAGENT_OWNER en msdb.', 1;
END;

DECLARE @Targets TABLE
(
    OracleJobNo INT     NOT NULL PRIMARY KEY,
    JobName     SYSNAME NOT NULL UNIQUE,
    ScheduleName SYSNAME NOT NULL UNIQUE,
    JobId       UNIQUEIDENTIFIER NULL,
    ScheduleId  INT NULL
);

INSERT INTO @Targets (OracleJobNo, JobName, ScheduleName)
VALUES
    ( 42, N'ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY',          N'SCH_ORA_42'),
    (103, N'ORA_103_EAI_OWNER_WA_DEPURA_MESSAGE_LOG',       N'SCH_ORA_103'),
    (189, N'ORA_189_T3_PROC_T3_OT_DOCTOS_INTERCO',          N'SCH_ORA_189'),
    (208, N'ORA_208_EAI_OWNER_PROC_RECEIVE_REFERENCE',      N'SCH_ORA_208'),
    (216, N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',        N'SCH_ORA_216'),
    (227, N'ORA_227_EAI_OWNER_WA_ERR_INVOICE_AMPERSAND',    N'SCH_ORA_227'),
    (229, N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY', N'SCH_ORA_229'),
    (236, N'ORA_236_EAI_OWNER_RECV_PAYMENT',              N'SCH_ORA_236'),
    (249, N'ORA_249_T3_PROC_T3_OT_DOCTOS',                  N'SCH_ORA_249'),
    (250, N'ORA_250_T3_PROC_CFDI_LIBERACION_PAC',           N'SCH_ORA_250'),
    (266, N'ORA_266_T3_WA_CFDI_COBRANZA',                   N'SCH_ORA_266'),
    (327, N'ORA_327_T3_PROC_CFDI_LIBERACION_REMISION',      N'SCH_ORA_327'),
    (347, N'ORA_347_T3_PROC_CFDI_LIBERACION_NOTA',          N'SCH_ORA_347'),
    (468, N'ORA_468_T3_WA_CFDI_COBRANZA_FIX',               N'SCH_ORA_468'),
    (471, N'ORA_471_T3_PROC_CFDI_LIBERACION_PAGO',          N'SCH_ORA_471'),
    (508, N'ORA_508_T3_PROC_CFDI_LIBERACION_AGR',           N'SCH_ORA_508'),
    (550, N'ORA_550_EAI_OWNER_RECV_INVOICE',              N'SCH_ORA_550'),
    (568, N'ORA_568_EAI_SF_BITACORA_CFDI',                  N'SCH_ORA_568'),
    (569, N'ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN',          N'SCH_ORA_569'),
    (589, N'ORA_589_T3_PROC_T3_EOD',                        N'SCH_ORA_589'),
    (648, N'ORA_648_EAI_OWNER_RECV_CUSTOMER',               N'SCH_ORA_648'),
    (649, N'ORA_649_EAI_OWNER_WA_ERR_CUSTOMER_AMPERSAND',   N'SCH_ORA_649'),
    (668, N'ORA_668_T3_PROC_CFDI_PROCESA_PAGO_AGR',         N'SCH_ORA_668'),
    (688, N'ORA_688_EAI_OWNER_WA_RUN_STATEMENTS',           N'SCH_ORA_688'),
    (729, N'ORA_729_T3_PROC_CFDI_CARTAPORTE_REP',           N'SCH_ORA_729'),
    (750, N'ORA_750_EAI_OWNER_SF_JOB_MANAGE',               N'SCH_ORA_750'),
    (769, N'ORA_769_EAI_OWNER_WA_ERR_REPLENISH_AMPERSAND',  N'SCH_ORA_769'),
    (789, N'ORA_789_T3_WA_V40_REGIMEN',                     N'SCH_ORA_789'),
    (809, N'ORA_809_T3_PROC_CFDI_LIBERA_PAGO_CENTRAL',      N'SCH_ORA_809'),
    (829, N'ORA_829_EAI_SF_CFDI_VENTA',                     N'SCH_ORA_829'),
    (830, N'ORA_830_EAI_SF_CFDI_NOTA_CREDITO',              N'SCH_ORA_830'),
    (849, N'ORA_849_EAI_SF_CFDI_OPEN_ITEMS',                N'SCH_ORA_849'),
    (869, N'ORA_869_EAI_OWNER_WA_ERR_PRODUCT_AMPERSAND',    N'SCH_ORA_869'),
    (889, N'ORA_889_EAI_OWNER_SF_PROC_CENTRAL_INCOBRABLE',  N'SCH_ORA_889'),
    (910, N'ORA_910_T3_WA_UPD_SUBDEPOSITOS',                N'SCH_ORA_910'),
    (929, N'ORA_929_T3_WA_SET_FECHA_EMISION',               N'SCH_ORA_929'),
    (951, N'ORA_951_T3_PROC_T3_BOD',                        N'SCH_ORA_951');

UPDATE T
SET
    JobId = J.job_id,
    ScheduleId = S.schedule_id
FROM @Targets AS T
LEFT JOIN dbo.sysjobs AS J
    ON J.[name] = T.JobName
LEFT JOIN dbo.sysschedules AS S
    ON S.[name] = T.ScheduleName;

IF EXISTS
(
    SELECT 1
    FROM @Targets
    WHERE JobId IS NULL OR ScheduleId IS NULL
)
BEGIN
    SELECT OracleJobNo, JobName, ScheduleName, JobId, ScheduleId
    FROM @Targets
    WHERE JobId IS NULL OR ScheduleId IS NULL
    ORDER BY OracleJobNo;

    THROW 51303, 'Falta uno o mas jobs o schedules T3; no se realizo ninguna reasignacion.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @Targets AS T
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.sysjobschedules AS JS
        WHERE JS.job_id = T.JobId
          AND JS.schedule_id = T.ScheduleId
    )
)
BEGIN
    THROW 51304, 'Uno o mas schedules no estan asociados con el job T3 esperado.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @Targets AS T
    CROSS APPLY
    (
        SELECT COUNT(*) AS JobCount
        FROM dbo.sysjobschedules AS JS
        WHERE JS.schedule_id = T.ScheduleId
    ) AS C
    WHERE C.JobCount <> 1
)
BEGIN
    THROW 51305, 'Uno o mas schedules T3 no son exclusivos; no se cambia su propietario.', 1;
END;

DECLARE
    @JobId UNIQUEIDENTIFIER,
    @ScheduleId INT,
    @ReturnCode INT;

DECLARE OwnerCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT JobId, ScheduleId
FROM @Targets
ORDER BY OracleJobNo;

BEGIN TRY
    BEGIN TRANSACTION;

        OPEN OwnerCursor;
        FETCH NEXT FROM OwnerCursor INTO @JobId, @ScheduleId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC @ReturnCode = dbo.sp_update_job
                @job_id = @JobId,
                @owner_login_name = @OwnerLogin;

            IF @ReturnCode <> 0
            BEGIN
                THROW 51306, 'No fue posible reasignar uno de los jobs T3.', 1;
            END;

            EXEC @ReturnCode = dbo.sp_update_schedule
                @schedule_id = @ScheduleId,
                @owner_login_name = @OwnerLogin;

            IF @ReturnCode <> 0
            BEGIN
                THROW 51307, 'No fue posible reasignar uno de los schedules T3.', 1;
            END;

            FETCH NEXT FROM OwnerCursor INTO @JobId, @ScheduleId;
        END;

        CLOSE OwnerCursor;
        DEALLOCATE OwnerCursor;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'OwnerCursor') >= 0
        CLOSE OwnerCursor;

    IF CURSOR_STATUS('local', 'OwnerCursor') > -3
        DEALLOCATE OwnerCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

SELECT
    T.OracleJobNo,
    J.[name] AS JobName,
    SUSER_SNAME(J.owner_sid) AS JobOwner,
    S.[name] AS ScheduleName,
    SUSER_SNAME(S.owner_sid) AS ScheduleOwner,
    CASE
        WHEN J.owner_sid = SUSER_SID(@OwnerLogin)
         AND S.owner_sid = SUSER_SID(@OwnerLogin)
            THEN N'OK'
        ELSE N'REVISAR'
    END AS OwnerStatus
FROM @Targets AS T
INNER JOIN dbo.sysjobs AS J
    ON J.job_id = T.JobId
INNER JOIN dbo.sysschedules AS S
    ON S.schedule_id = T.ScheduleId
ORDER BY T.OracleJobNo;
GO
