/*
    Migracion de los 37 registros USER_JOBS exportados el 17-jul-2026.

    SEGURIDAD DE DESPLIEGUE
    ----------------------
    - Ejecute este archivo conectado a la base de datos de la aplicacion T3.
    - No lo ejecute en master, model, msdb ni tempdb.
    - Todos los jobs se crean DESHABILITADOS, incluso los activos en Oracle.
    - Cambie @JobOwner por un login estable administrado por el DBA.
    - Cada job recibe un schedule exclusivo porque JOB_INTERVAL puede modificarlo.

    SQL Server no tiene PACKAGE. Las llamadas RECV_TO_SEND_V3.* se dirigen a los
    procedimientos publicos sin prefijo que ya existen en [EAI_OWNER].
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    THROW 51000, 'Ejecute este script en la base de datos de la aplicacion T3.', 1;
END;

DECLARE @TargetDatabase SYSNAME = DB_NAME();
DECLARE @JobOwner SYSNAME = N'sa'; -- Ajustar conforme a la politica del ambiente.

IF SUSER_ID(@JobOwner) IS NULL
BEGIN
    THROW 51001, 'El login configurado en @JobOwner no existe.', 1;
END;

IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Job_Oracle_SQLAgent_Map
    (
        Oracle_Job_No       INT              NOT NULL PRIMARY KEY,
        SqlAgent_Job_Id     UNIQUEIDENTIFIER NOT NULL,
        SqlAgent_Job_Name   SYSNAME          NULL,
        Schedule_Id         INT              NOT NULL,
        Original_Interval   VARCHAR(4000)    NULL,
        Last_Interval       VARCHAR(4000)    NULL,
        Last_Update_Date    DATETIME2(0)     NULL,
        Last_Update_User    SYSNAME          NULL,
        Is_Active           BIT              NOT NULL DEFAULT (1)
    );
END;

/* Catalogo auditable de la conversion; no sustituye las tablas de msdb. */
IF OBJECT_ID(N'dbo.Job_Oracle_Migration_Catalog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Job_Oracle_Migration_Catalog
    (
        Oracle_Job_No       INT            NOT NULL PRIMARY KEY,
        Required_Schema     SYSNAME        NOT NULL,
        Required_Procedure  SYSNAME        NOT NULL,
        Step_Command        NVARCHAR(MAX)  NOT NULL,
        Oracle_Broken       BIT            NOT NULL,
        Original_Interval   VARCHAR(4000)  NOT NULL,
        Converted_Subday_Type     INT      NOT NULL,
        Converted_Subday_Interval INT      NOT NULL,
        Converted_Start_Time      INT      NOT NULL,
        Migration_Date      DATETIME2(0)   NOT NULL,
        Migration_User      SYSNAME        NOT NULL
    );
END;

DECLARE @Jobs TABLE
(
    OracleJobNo       INT            NOT NULL PRIMARY KEY,
    RequiredSchema    SYSNAME        NOT NULL,
    RequiredProcedure SYSNAME        NOT NULL,
    StepCommand       NVARCHAR(MAX)  NOT NULL,
    OracleBroken      CHAR(1)        NOT NULL,
    OriginalInterval  VARCHAR(4000)  NOT NULL,
    SubdayType        INT            NOT NULL,
    SubdayInterval    INT            NOT NULL,
    StartTime         INT            NOT NULL
);

/*
    SubdayType de SQL Agent: 1=una vez al dia, 4=minutos, 8=horas.
    StartTime usa HHMMSS. Los TRUNC(SYSDATE+1)+fraccion se convierten a hora fija.
*/
INSERT INTO @Jobs VALUES
( 42,N'EAI_OWNER',N'WA_ERR_INTERCOMPANY',       N'EXEC [EAI_OWNER].[WA_ERR_INTERCOMPANY] 2;',                    'N','SYSDATE + 10/1440',               4,10,      0),
(103,N'EAI_OWNER',N'WA_DEPURA_MESSAGE_LOG',     N'EXEC [EAI_OWNER].[WA_DEPURA_MESSAGE_LOG] 2, 0;',              'N','TRUNC( SYSDATE + 1 ) + 5/24',     1, 0, 50000),
(189,N'T3',       N'PROC_T3_OT_DOCTOS_INTERCO', N'EXEC [T3].[PROC_T3_OT_DOCTOS_INTERCO];',                     'N','SYSDATE + 30/1440',               4,30,      0),
(208,N'EAI_OWNER',N'PROC_RECEIVE_REFERENCE',    N'EXEC [EAI_OWNER].[PROC_RECEIVE_REFERENCE];',                  'N','SYSDATE + 10/1440',               4,10,      0),
(216,N'EAI_OWNER',N'RECV_REPLENISHMENT',        N'EXEC [EAI_OWNER].[RECV_REPLENISHMENT];',                      'Y','SYSDATE + 5/1440',                4, 5,      0),
(227,N'EAI_OWNER',N'WA_ERR_INVOICE_AMPERSAND',  N'EXEC [EAI_OWNER].[WA_ERR_INVOICE_AMPERSAND] 1;',              'N','SYSDATE + 10/1440',               4,10,      0),
(229,N'EAI_OWNER',N'RECV_INVOICE_INTERCOMPANY', N'EXEC [EAI_OWNER].[RECV_INVOICE_INTERCOMPANY];',               'Y','SYSDATE + 10/1440',               4,10,      0),
(236,N'EAI_OWNER',N'RECV_PAYMENT',              N'EXEC [EAI_OWNER].[RECV_PAYMENT];',                            'Y','SYSDATE + 10/1440',               4,10,      0),
(249,N'T3',       N'PROC_T3_OT_DOCTOS',          N'EXEC [T3].[PROC_T3_OT_DOCTOS];',                              'N','SYSDATE + 30/1440',               4,30,      0),
(250,N'T3',       N'PROC_CFDI_LIBERACION_PAC',   N'EXEC [T3].[PROC_CFDI_LIBERACION_PAC];',                       'N','SYSDATE + 10/1440',               4,10,      0),
(266,N'T3',       N'WA_CFDI_COBRANZA',           N'EXEC [T3].[WA_CFDI_COBRANZA] 2;',                             'N','TRUNC( SYSDATE + 1 ) + 5/24',     1, 0, 50000),
(327,N'T3',       N'PROC_CFDI_LIBERACION_REMISION',N'EXEC [T3].[PROC_CFDI_LIBERACION_REMISION];',                'N','SYSDATE + 10/1440',               4,10,      0),
(347,N'T3',       N'PROC_CFDI_LIBERACION_NOTA',  N'EXEC [T3].[PROC_CFDI_LIBERACION_NOTA];',                      'N','TRUNC( SYSDATE + 1 ) + 1420/1440',1, 0,234000),
(468,N'T3',       N'WA_CFDI_COBRANZA_FIX',       N'EXEC [T3].[WA_CFDI_COBRANZA_FIX];',                           'N','SYSDATE + 2/24',                  8, 2,      0),
(471,N'T3',       N'PROC_CFDI_LIBERACION_PAGO',  N'EXEC [T3].[PROC_CFDI_LIBERACION_PAGO];',                      'N','SYSDATE + 10/1440',               4,10,      0),
(508,N'T3',       N'PROC_CFDI_LIBERACION_AGR',   N'EXEC [T3].[PROC_CFDI_LIBERACION_AGR];',                       'N','SYSDATE + 1/24',                  8, 1,      0),
(550,N'EAI_OWNER',N'RECV_INVOICE',              N'EXEC [EAI_OWNER].[RECV_INVOICE];',                            'Y','SYSDATE + 10/1440',               4,10,      0),
(568,N'EAI',      N'SF_BITACORA_CFDI',           N'EXEC [EAI].[SF_BITACORA_CFDI] 0;',                            'N','TRUNC( SYSDATE + 1 ) + 160/1440', 1, 0, 24000),
(569,N'EAI',      N'SF_BITACORA_CFDI_RESUMEN',   N'EXEC [EAI].[SF_BITACORA_CFDI_RESUMEN] NULL, NULL;',           'N','TRUNC( SYSDATE + 1 ) + 160/1440', 1, 0, 24000),
(589,N'T3',       N'PROC_T3_EOD',                 N'EXEC [T3].[PROC_T3_EOD];',                                   'N','TRUNC( SYSDATE + 1 ) + 90/1440',  1, 0, 13000),
(648,N'EAI_OWNER',N'RECV_CUSTOMER',               N'EXEC [EAI_OWNER].[RECV_CUSTOMER];',                           'Y','SYSDATE + 10/1440',               4,10,      0),
(649,N'EAI_OWNER',N'WA_ERR_CUSTOMER_AMPERSAND',   N'EXEC [EAI_OWNER].[WA_ERR_CUSTOMER_AMPERSAND] 2;',             'N','SYSDATE + 6/24',                  8, 6,      0),
(668,N'T3',       N'PROC_CFDI_PROCESA_PAGO_AGR',  N'EXEC [T3].[PROC_CFDI_PROCESA_PAGO_AGR] 4;',                   'N','TRUNC( SYSDATE + 1 ) + 5/24',     1, 0, 50000),
(688,N'EAI_OWNER',N'WA_RUN_STATEMENTS',           N'EXEC [EAI_OWNER].[WA_RUN_STATEMENTS] 0;',                     'N','TRUNC( SYSDATE + 1 ) + 15/1440',  1, 0,  1500),
(729,N'T3',       N'PROC_CFDI_CARTAPORTE_REP',    N'EXEC [T3].[PROC_CFDI_CARTAPORTE_REP] 1;',                     'N','TRUNC( SYSDATE + 1 ) + 5/24',     1, 0, 50000),
(750,N'EAI_OWNER',N'SF_JOB_MANAGE',               N'EXEC [EAI_OWNER].[SF_JOB_MANAGE] N''Resume'';',               'N','TRUNC( SYSDATE + 1 ) + 7/24',     1, 0, 70000),
(769,N'EAI_OWNER',N'WA_ERR_REPLENISH_AMPERSAND',  N'EXEC [EAI_OWNER].[WA_ERR_REPLENISH_AMPERSAND] 2;',            'N','SYSDATE + 10/1440',               4,10,      0),
(789,N'T3',       N'WA_V40_REGIMEN',              N'EXEC [T3].[WA_V40_REGIMEN];',                                'N','SYSDATE + 720/1440',              8,12,      0),
(809,N'T3',       N'PROC_CFDI_LIBERA_PAGO_CENTRAL',N'EXEC [T3].[PROC_CFDI_LIBERA_PAGO_CENTRAL];',                 'N','SYSDATE + 120/1440',              8, 2,      0),
(829,N'EAI',      N'SF_CFDI_VENTA',               N'EXEC [EAI].[SF_CFDI_VENTA] 0;',                               'N','TRUNC( SYSDATE + 1 ) + 330/1440', 1, 0, 53000),
(830,N'EAI',      N'SF_CFDI_NOTA_CREDITO',        N'EXEC [EAI].[SF_CFDI_NOTA_CREDITO] 0;',                        'N','TRUNC( SYSDATE + 1 ) + 330/1440', 1, 0, 53000),
(849,N'EAI',      N'SF_CFDI_OPEN_ITEMS',          N'EXEC [EAI].[SF_CFDI_OPEN_ITEMS] 0;',                          'N','TRUNC( SYSDATE + 1 ) + 5/24',     1, 0, 50000),
(869,N'EAI_OWNER',N'WA_ERR_PRODUCT_AMPERSAND',    N'EXEC [EAI_OWNER].[WA_ERR_PRODUCT_AMPERSAND] 1;',              'N','SYSDATE + 30/1440',               4,30,      0),
(889,N'EAI_OWNER',N'SF_PROC_CENTRAL_INCOBRABLE', N'EXEC [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE] 5, NULL, 1, 11;','N','TRUNC( SYSDATE + 1 ) + 21/24',    1, 0,210000),
(910,N'T3',       N'WA_UPD_SUBDEPOSITOS',         N'EXEC [T3].[WA_UPD_SUBDEPOSITOS] NULL;',                       'N','SYSDATE + 1/24',                  8, 1,      0),
(929,N'T3',       N'WA_SET_FECHA_EMISION',        N'EXEC [T3].[WA_SET_FECHA_EMISION] 120, 10000;',                'N','TRUNC( SYSDATE + 1 ) + 8/24',     1, 0, 80000),
(951,N'T3',       N'PROC_T3_BOD',                  N'EXEC [T3].[PROC_T3_BOD] N''NO'';',                            'N','TRUNC( SYSDATE + 1 ) + 455/1440', 1, 0, 73500);

DECLARE
    @OracleJobNo INT,
    @RequiredSchema SYSNAME,
    @RequiredProcedure SYSNAME,
    @StepCommand NVARCHAR(MAX),
    @OracleBroken CHAR(1),
    @OriginalInterval VARCHAR(4000),
    @SubdayType INT,
    @SubdayInterval INT,
    @StartTime INT,
    @JobName SYSNAME,
    @ScheduleName SYSNAME,
    @JobId UNIQUEIDENTIFIER,
    @ScheduleId INT,
    @Description NVARCHAR(512),
    @RequiredObject NVARCHAR(517),
    @ActiveStartDate INT = CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112));

DECLARE JobCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT OracleJobNo, RequiredSchema, RequiredProcedure, StepCommand,
       OracleBroken, OriginalInterval, SubdayType, SubdayInterval, StartTime
FROM @Jobs ORDER BY OracleJobNo;

OPEN JobCursor;
FETCH NEXT FROM JobCursor INTO @OracleJobNo,@RequiredSchema,@RequiredProcedure,
    @StepCommand,@OracleBroken,@OriginalInterval,@SubdayType,@SubdayInterval,@StartTime;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @JobName = CONCAT(N'ORA_', @OracleJobNo, N'_', @RequiredSchema, N'_', @RequiredProcedure);
    SET @ScheduleName = CONCAT(N'SCH_ORA_', @OracleJobNo);
    SET @RequiredObject = QUOTENAME(@RequiredSchema) + N'.' + QUOTENAME(@RequiredProcedure);
    SET @Description = CONCAT(
        N'Migrado de Oracle DBMS_JOB ', @OracleJobNo,
        N'. Estado Oracle: ', CASE @OracleBroken WHEN 'Y' THEN N'BROKEN' ELSE N'ACTIVO' END,
        N'. Intervalo: ', @OriginalInterval,
        N'. Dependencia al desplegar: ',
        CASE WHEN OBJECT_ID(@RequiredObject, N'P') IS NULL THEN N'NO ENCONTRADA' ELSE N'ENCONTRADA' END,
        N'. Se crea deshabilitado para validacion.'
    );

    SET @JobId = NULL;
    SELECT @JobId = job_id
    FROM msdb.dbo.sysjobs
    WHERE [name] = @JobName;

    IF @JobId IS NULL
    BEGIN
        EXEC msdb.dbo.sp_add_job
            @job_name = @JobName,
            @enabled = 0,
            @description = @Description,
            @owner_login_name = @JobOwner,
            @job_id = @JobId OUTPUT;
    END
    ELSE
    BEGIN
        EXEC msdb.dbo.sp_update_job
            @job_id = @JobId,
            @enabled = 0,
            @description = @Description,
            @owner_login_name = @JobOwner;
    END;

    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobsteps WHERE job_id=@JobId AND step_id=1)
        EXEC msdb.dbo.sp_update_jobstep
            @job_id=@JobId, @step_id=1, @step_name=N'Ejecutar procedimiento migrado',
            @subsystem=N'TSQL', @command=@StepCommand, @database_name=@TargetDatabase,
            @on_success_action=1, @on_fail_action=2;
    ELSE
        EXEC msdb.dbo.sp_add_jobstep
            @job_id=@JobId, @step_name=N'Ejecutar procedimiento migrado',
            @subsystem=N'TSQL', @command=@StepCommand, @database_name=@TargetDatabase,
            @on_success_action=1, @on_fail_action=2;

    SET @ScheduleId = NULL;
    SELECT @ScheduleId = schedule_id
    FROM msdb.dbo.sysschedules
    WHERE [name] = @ScheduleName;

    IF @ScheduleId IS NULL
    BEGIN
        EXEC msdb.dbo.sp_add_schedule
            @schedule_name=@ScheduleName, @enabled=1,
            @freq_type=4, @freq_interval=1,
            @freq_subday_type=@SubdayType, @freq_subday_interval=@SubdayInterval,
            @active_start_date=@ActiveStartDate, @active_start_time=@StartTime,
            @active_end_time=235959, @schedule_id=@ScheduleId OUTPUT;
    END
    ELSE
    BEGIN
        EXEC msdb.dbo.sp_update_schedule
            @schedule_id=@ScheduleId, @enabled=1,
            @freq_type=4, @freq_interval=1,
            @freq_subday_type=@SubdayType, @freq_subday_interval=@SubdayInterval,
            @active_start_date=@ActiveStartDate, @active_start_time=@StartTime,
            @active_end_time=235959;
    END;

    IF NOT EXISTS
       (SELECT 1 FROM msdb.dbo.sysjobschedules WHERE job_id=@JobId AND schedule_id=@ScheduleId)
        EXEC msdb.dbo.sp_attach_schedule @job_id=@JobId, @schedule_id=@ScheduleId;

    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobservers WHERE job_id=@JobId)
        EXEC msdb.dbo.sp_add_jobserver @job_id=@JobId, @server_name=N'(LOCAL)';

    MERGE dbo.Job_Oracle_SQLAgent_Map AS target
    USING (SELECT @OracleJobNo AS Oracle_Job_No) AS source
       ON target.Oracle_Job_No=source.Oracle_Job_No
    WHEN MATCHED THEN UPDATE SET
        SqlAgent_Job_Id=@JobId, SqlAgent_Job_Name=@JobName, Schedule_Id=@ScheduleId,
        Original_Interval=@OriginalInterval, Last_Interval=@OriginalInterval,
        Last_Update_Date=SYSDATETIME(), Last_Update_User=SUSER_SNAME(),
        Is_Active=CASE @OracleBroken WHEN 'N' THEN 1 ELSE 0 END
    WHEN NOT MATCHED THEN INSERT
       (Oracle_Job_No,SqlAgent_Job_Id,SqlAgent_Job_Name,Schedule_Id,
        Original_Interval,Last_Interval,Last_Update_Date,Last_Update_User,Is_Active)
    VALUES
       (@OracleJobNo,@JobId,@JobName,@ScheduleId,@OriginalInterval,@OriginalInterval,
        SYSDATETIME(),SUSER_SNAME(),CASE @OracleBroken WHEN 'N' THEN 1 ELSE 0 END);

    MERGE dbo.Job_Oracle_Migration_Catalog AS target
    USING (SELECT @OracleJobNo AS Oracle_Job_No) AS source
       ON target.Oracle_Job_No=source.Oracle_Job_No
    WHEN MATCHED THEN UPDATE SET
        Required_Schema=@RequiredSchema, Required_Procedure=@RequiredProcedure,
        Step_Command=@StepCommand, Oracle_Broken=CASE @OracleBroken WHEN 'Y' THEN 1 ELSE 0 END,
        Original_Interval=@OriginalInterval, Converted_Subday_Type=@SubdayType,
        Converted_Subday_Interval=@SubdayInterval, Converted_Start_Time=@StartTime,
        Migration_Date=SYSDATETIME(), Migration_User=SUSER_SNAME()
    WHEN NOT MATCHED THEN INSERT
       (Oracle_Job_No,Required_Schema,Required_Procedure,Step_Command,Oracle_Broken,
        Original_Interval,Converted_Subday_Type,Converted_Subday_Interval,
        Converted_Start_Time,Migration_Date,Migration_User)
    VALUES
       (@OracleJobNo,@RequiredSchema,@RequiredProcedure,@StepCommand,
        CASE @OracleBroken WHEN 'Y' THEN 1 ELSE 0 END,@OriginalInterval,
        @SubdayType,@SubdayInterval,@StartTime,SYSDATETIME(),SUSER_SNAME());

    PRINT CONCAT('Preparado y deshabilitado: ', @JobName);

    FETCH NEXT FROM JobCursor INTO @OracleJobNo,@RequiredSchema,@RequiredProcedure,
        @StepCommand,@OracleBroken,@OriginalInterval,@SubdayType,@SubdayInterval,@StartTime;
END;

CLOSE JobCursor;
DEALLOCATE JobCursor;
GO
