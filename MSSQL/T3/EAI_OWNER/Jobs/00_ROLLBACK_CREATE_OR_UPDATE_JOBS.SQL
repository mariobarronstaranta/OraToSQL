/*
    Rollback de 01_CREATE_OR_UPDATE_JOBS.SQL.

    Elimina exclusivamente los 37 jobs y schedules declarados por ese script,
    junto con sus filas de mapeo y catalogo. Es seguro volver a ejecutarlo si el
    despliegue original fallo a la mitad.

    IMPORTANTE
    ----------
    01_CREATE_OR_UPDATE_JOBS.SQL tambien actualiza objetos preexistentes que
    tengan los mismos nombres, pero no guarda su definicion anterior. Por ello,
    este rollback puede eliminarlos, pero no puede restaurar su estado previo.

    @DropEmptySupportTables = 1 elimina las dos tablas auxiliares solamente si
    quedan vacias. Cambielo a 0 si esas tablas se desplegaron por separado y se
    desea conservar su estructura.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'T3QA'
BEGIN
    THROW 51020, 'Ejecute este rollback conectado a la base de datos T3QA.', 1;
END;

DECLARE @DropEmptySupportTables BIT = 1;

DECLARE @Targets TABLE
(
    OracleJobNo INT     NOT NULL PRIMARY KEY,
    JobName     SYSNAME NOT NULL UNIQUE,
    ScheduleName SYSNAME NOT NULL UNIQUE
);

INSERT INTO @Targets (OracleJobNo, JobName, ScheduleName)
VALUES
( 42,N'ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY',          N'SCH_ORA_42'),
(103,N'ORA_103_EAI_OWNER_WA_DEPURA_MESSAGE_LOG',       N'SCH_ORA_103'),
(189,N'ORA_189_T3_PROC_T3_OT_DOCTOS_INTERCO',          N'SCH_ORA_189'),
(208,N'ORA_208_EAI_OWNER_PROC_RECEIVE_REFERENCE',      N'SCH_ORA_208'),
(216,N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',          N'SCH_ORA_216'),
(227,N'ORA_227_EAI_OWNER_WA_ERR_INVOICE_AMPERSAND',    N'SCH_ORA_227'),
(229,N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY',   N'SCH_ORA_229'),
(236,N'ORA_236_EAI_OWNER_RECV_PAYMENT',                N'SCH_ORA_236'),
(249,N'ORA_249_T3_PROC_T3_OT_DOCTOS',                  N'SCH_ORA_249'),
(250,N'ORA_250_T3_PROC_CFDI_LIBERACION_PAC',           N'SCH_ORA_250'),
(266,N'ORA_266_T3_WA_CFDI_COBRANZA',                   N'SCH_ORA_266'),
(327,N'ORA_327_T3_PROC_CFDI_LIBERACION_REMISION',      N'SCH_ORA_327'),
(347,N'ORA_347_T3_PROC_CFDI_LIBERACION_NOTA',          N'SCH_ORA_347'),
(468,N'ORA_468_T3_WA_CFDI_COBRANZA_FIX',               N'SCH_ORA_468'),
(471,N'ORA_471_T3_PROC_CFDI_LIBERACION_PAGO',          N'SCH_ORA_471'),
(508,N'ORA_508_T3_PROC_CFDI_LIBERACION_AGR',           N'SCH_ORA_508'),
(550,N'ORA_550_EAI_OWNER_RECV_INVOICE',                N'SCH_ORA_550'),
(568,N'ORA_568_EAI_SF_BITACORA_CFDI',                  N'SCH_ORA_568'),
(569,N'ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN',          N'SCH_ORA_569'),
(589,N'ORA_589_T3_PROC_T3_EOD',                        N'SCH_ORA_589'),
(648,N'ORA_648_EAI_OWNER_RECV_CUSTOMER',               N'SCH_ORA_648'),
(649,N'ORA_649_EAI_OWNER_WA_ERR_CUSTOMER_AMPERSAND',   N'SCH_ORA_649'),
(668,N'ORA_668_T3_PROC_CFDI_PROCESA_PAGO_AGR',         N'SCH_ORA_668'),
(688,N'ORA_688_EAI_OWNER_WA_RUN_STATEMENTS',           N'SCH_ORA_688'),
(729,N'ORA_729_T3_PROC_CFDI_CARTAPORTE_REP',           N'SCH_ORA_729'),
(750,N'ORA_750_EAI_OWNER_SF_JOB_MANAGE',               N'SCH_ORA_750'),
(769,N'ORA_769_EAI_OWNER_WA_ERR_REPLENISH_AMPERSAND',  N'SCH_ORA_769'),
(789,N'ORA_789_T3_WA_V40_REGIMEN',                     N'SCH_ORA_789'),
(809,N'ORA_809_T3_PROC_CFDI_LIBERA_PAGO_CENTRAL',      N'SCH_ORA_809'),
(829,N'ORA_829_EAI_SF_CFDI_VENTA',                     N'SCH_ORA_829'),
(830,N'ORA_830_EAI_SF_CFDI_NOTA_CREDITO',              N'SCH_ORA_830'),
(849,N'ORA_849_EAI_SF_CFDI_OPEN_ITEMS',                N'SCH_ORA_849'),
(869,N'ORA_869_EAI_OWNER_WA_ERR_PRODUCT_AMPERSAND',    N'SCH_ORA_869'),
(889,N'ORA_889_EAI_OWNER_SF_PROC_CENTRAL_INCOBRABLE',  N'SCH_ORA_889'),
(910,N'ORA_910_T3_WA_UPD_SUBDEPOSITOS',                N'SCH_ORA_910'),
(929,N'ORA_929_T3_WA_SET_FECHA_EMISION',               N'SCH_ORA_929'),
(951,N'ORA_951_T3_PROC_T3_BOD',                        N'SCH_ORA_951');

DECLARE
    @JobName SYSNAME,
    @ScheduleName SYSNAME,
    @ScheduleId INT,
    @DeletedJobs INT = 0,
    @DeletedSchedules INT = 0,
    @DeletedMapRows INT = 0,
    @DeletedCatalogRows INT = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    /* sp_delete_job retira tambien pasos, historial y asociaciones. */
    DECLARE JobCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT JobName FROM @Targets ORDER BY OracleJobNo;

    OPEN JobCursor;
    FETCH NEXT FROM JobCursor INTO @JobName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE [name] = @JobName)
        BEGIN
            EXEC msdb.dbo.sp_delete_job
                @job_name = @JobName,
                @delete_unused_schedule = 1;
            SET @DeletedJobs += 1;
            PRINT CONCAT(N'Job eliminado: ', @JobName);
        END;

        FETCH NEXT FROM JobCursor INTO @JobName;
    END;

    CLOSE JobCursor;
    DEALLOCATE JobCursor;

    /*
        Limpia schedules que pudieron crearse antes de que fallara la creacion
        o asociacion del job. Un schedule compartido con otro job se conserva.
    */
    DECLARE ScheduleCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT ScheduleName FROM @Targets ORDER BY OracleJobNo;

    OPEN ScheduleCursor;
    FETCH NEXT FROM ScheduleCursor INTO @ScheduleName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ScheduleId = NULL;

        SELECT @ScheduleId = schedule_id
        FROM msdb.dbo.sysschedules
        WHERE [name] = @ScheduleName;

        IF @ScheduleId IS NOT NULL
           AND NOT EXISTS
           (
               SELECT 1
               FROM msdb.dbo.sysjobschedules
               WHERE schedule_id = @ScheduleId
           )
        BEGIN
            EXEC msdb.dbo.sp_delete_schedule @schedule_id = @ScheduleId;
            SET @DeletedSchedules += 1;
            PRINT CONCAT(N'Schedule huerfano eliminado: ', @ScheduleName);
        END
        ELSE IF @ScheduleId IS NOT NULL
        BEGIN
            PRINT CONCAT(N'Schedule conservado porque aun esta asociado a otro job: ', @ScheduleName);
        END;

        FETCH NEXT FROM ScheduleCursor INTO @ScheduleName;
    END;

    CLOSE ScheduleCursor;
    DEALLOCATE ScheduleCursor;

    IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NOT NULL
    BEGIN
        DELETE M
        FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS M
        INNER JOIN @Targets AS T ON T.OracleJobNo = M.Oracle_Job_No;

        SET @DeletedMapRows = @@ROWCOUNT;
    END;

    IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NOT NULL
    BEGIN
        DELETE C
        FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS C
        INNER JOIN @Targets AS T ON T.OracleJobNo = C.Oracle_Job_No;

        SET @DeletedCatalogRows = @@ROWCOUNT;
    END;

    /* El catalogo no tiene FK; se elimina antes que la tabla puente. */
    IF @DropEmptySupportTables = 1
       AND OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog])
    BEGIN
        DROP TABLE [EAI_OWNER].[Job_Oracle_Migration_Catalog];
        PRINT N'Tabla vacia eliminada: [EAI_OWNER].[Job_Oracle_Migration_Catalog]';
    END;

    IF @DropEmptySupportTables = 1
       AND OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map])
    BEGIN
        DROP TABLE [EAI_OWNER].[Job_Oracle_SQLAgent_Map];
        PRINT N'Tabla vacia eliminada: [EAI_OWNER].[Job_Oracle_SQLAgent_Map]';
    END;

    COMMIT TRANSACTION;

    SELECT
        @DeletedJobs AS Deleted_Jobs,
        @DeletedSchedules AS Deleted_Orphan_Schedules,
        @DeletedMapRows AS Deleted_Map_Rows,
        @DeletedCatalogRows AS Deleted_Catalog_Rows,
        N'ROLLBACK COMPLETADO' AS [Status];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'JobCursor') >= 0 CLOSE JobCursor;
    IF CURSOR_STATUS('local', 'JobCursor') > -3 DEALLOCATE JobCursor;
    IF CURSOR_STATUS('local', 'ScheduleCursor') >= 0 CLOSE ScheduleCursor;
    IF CURSOR_STATUS('local', 'ScheduleCursor') > -3 DEALLOCATE ScheduleCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
