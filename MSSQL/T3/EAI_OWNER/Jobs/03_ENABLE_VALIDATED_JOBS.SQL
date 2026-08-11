/*
    Habilita los jobs que estaban activos en Oracle.

    FLUJO ESPERADO
    --------------
    1. Ejecutar 01_CREATE_OR_UPDATE_JOBS.SQL para crear los jobs deshabilitados.
    2. Ejecutar 02_VALIDATE_JOBS.SQL y corregir todo hasta obtener PASS.
    3. Cambiar @ConfirmEnable a 1 y ejecutar este archivo como AT85233588.

    Este script habilita exactamente 32 jobs. Los cinco jobs marcados BROKEN en
    Oracle permanecen deshabilitados. La operacion es transaccional: si falla la
    habilitacion de un job, se deshacen las habilitaciones realizadas en este lote.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDatabase SYSNAME = N'T3QA';
DECLARE @ExpectedOwner SYSNAME = N'AT85233588';
DECLARE @ConfirmEnable BIT = 0; -- Cambiar manualmente a 1 durante la ventana autorizada.

/* Primera barrera: evita habilitar jobs desde una base o una cuenta incorrecta. */
IF DB_NAME() <> @TargetDatabase
BEGIN
    THROW 51020, 'Ejecute 03_ENABLE_VALIDATED_JOBS.SQL conectado a la base de datos T3QA.', 1;
END;

IF SUSER_ID(@ExpectedOwner) IS NULL OR SUSER_SID() <> SUSER_SID(@ExpectedOwner)
BEGIN
    THROW 51021, 'Ejecute este archivo con el login SQL AT85233588.', 1;
END;

/*
    Un usuario que no es sysadmin necesita pertenecer a un rol de SQL Server
    Agent en msdb para modificar y habilitar sus propios jobs.
*/
IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
   AND NOT EXISTS
   (
       SELECT 1
       FROM msdb.sys.database_role_members AS drm
       INNER JOIN msdb.sys.database_principals AS role_principal
           ON role_principal.principal_id = drm.role_principal_id
       INNER JOIN msdb.sys.database_principals AS member_principal
           ON member_principal.principal_id = drm.member_principal_id
       WHERE member_principal.[sid] = SUSER_SID()
         AND role_principal.[name] IN
             (N'SQLAgentUserRole', N'SQLAgentReaderRole', N'SQLAgentOperatorRole')
   )
BEGIN
    THROW 51022, 'AT85233588 necesita pertenecer a un rol de SQL Server Agent en msdb.', 1;
END;

IF @ConfirmEnable <> 1
BEGIN
    THROW 51023, 'Activacion cancelada. Cambie @ConfirmEnable a 1 durante la ventana autorizada.', 1;
END;

IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
   OR OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NULL
BEGIN
    THROW 51024, 'Faltan las tablas de control. Ejecute primero 01_CREATE_OR_UPDATE_JOBS.SQL.', 1;
END;

/*
    La lista independiente evita confiar ciegamente en un catalogo incompleto.
    OracleBroken=1 identifica los cinco jobs que NO deben habilitarse.
*/
DECLARE @ExpectedJobs TABLE
(
    OracleJobNo  INT     NOT NULL PRIMARY KEY,
    OracleBroken BIT     NOT NULL,
    JobName      SYSNAME NOT NULL UNIQUE,
    ScheduleName SYSNAME NOT NULL UNIQUE
);

INSERT INTO @ExpectedJobs (OracleJobNo, OracleBroken, JobName, ScheduleName)
VALUES
( 42,0,N'ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY',          N'SCH_ORA_42'),
(103,0,N'ORA_103_EAI_OWNER_WA_DEPURA_MESSAGE_LOG',       N'SCH_ORA_103'),
(189,0,N'ORA_189_T3_PROC_T3_OT_DOCTOS_INTERCO',          N'SCH_ORA_189'),
(208,0,N'ORA_208_EAI_OWNER_PROC_RECEIVE_REFERENCE',      N'SCH_ORA_208'),
(216,1,N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT',          N'SCH_ORA_216'),
(227,0,N'ORA_227_EAI_OWNER_WA_ERR_INVOICE_AMPERSAND',    N'SCH_ORA_227'),
(229,1,N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY',   N'SCH_ORA_229'),
(236,1,N'ORA_236_EAI_OWNER_RECV_PAYMENT',                N'SCH_ORA_236'),
(249,0,N'ORA_249_T3_PROC_T3_OT_DOCTOS',                  N'SCH_ORA_249'),
(250,0,N'ORA_250_T3_PROC_CFDI_LIBERACION_PAC',           N'SCH_ORA_250'),
(266,0,N'ORA_266_T3_WA_CFDI_COBRANZA',                   N'SCH_ORA_266'),
(327,0,N'ORA_327_T3_PROC_CFDI_LIBERACION_REMISION',      N'SCH_ORA_327'),
(347,0,N'ORA_347_T3_PROC_CFDI_LIBERACION_NOTA',          N'SCH_ORA_347'),
(468,0,N'ORA_468_T3_WA_CFDI_COBRANZA_FIX',               N'SCH_ORA_468'),
(471,0,N'ORA_471_T3_PROC_CFDI_LIBERACION_PAGO',          N'SCH_ORA_471'),
(508,0,N'ORA_508_T3_PROC_CFDI_LIBERACION_AGR',           N'SCH_ORA_508'),
(550,1,N'ORA_550_EAI_OWNER_RECV_INVOICE',                N'SCH_ORA_550'),
(568,0,N'ORA_568_EAI_SF_BITACORA_CFDI',                  N'SCH_ORA_568'),
(569,0,N'ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN',          N'SCH_ORA_569'),
(589,0,N'ORA_589_T3_PROC_T3_EOD',                        N'SCH_ORA_589'),
(648,1,N'ORA_648_EAI_OWNER_RECV_CUSTOMER',               N'SCH_ORA_648'),
(649,0,N'ORA_649_EAI_OWNER_WA_ERR_CUSTOMER_AMPERSAND',   N'SCH_ORA_649'),
(668,0,N'ORA_668_T3_PROC_CFDI_PROCESA_PAGO_AGR',         N'SCH_ORA_668'),
(688,0,N'ORA_688_EAI_OWNER_WA_RUN_STATEMENTS',           N'SCH_ORA_688'),
(729,0,N'ORA_729_T3_PROC_CFDI_CARTAPORTE_REP',           N'SCH_ORA_729'),
(750,0,N'ORA_750_EAI_OWNER_SF_JOB_MANAGE',               N'SCH_ORA_750'),
(769,0,N'ORA_769_EAI_OWNER_WA_ERR_REPLENISH_AMPERSAND',  N'SCH_ORA_769'),
(789,0,N'ORA_789_T3_WA_V40_REGIMEN',                     N'SCH_ORA_789'),
(809,0,N'ORA_809_T3_PROC_CFDI_LIBERA_PAGO_CENTRAL',      N'SCH_ORA_809'),
(829,0,N'ORA_829_EAI_SF_CFDI_VENTA',                     N'SCH_ORA_829'),
(830,0,N'ORA_830_EAI_SF_CFDI_NOTA_CREDITO',              N'SCH_ORA_830'),
(849,0,N'ORA_849_EAI_SF_CFDI_OPEN_ITEMS',                N'SCH_ORA_849'),
(869,0,N'ORA_869_EAI_OWNER_WA_ERR_PRODUCT_AMPERSAND',    N'SCH_ORA_869'),
(889,0,N'ORA_889_EAI_OWNER_SF_PROC_CENTRAL_INCOBRABLE',  N'SCH_ORA_889'),
(910,0,N'ORA_910_T3_WA_UPD_SUBDEPOSITOS',                N'SCH_ORA_910'),
(929,0,N'ORA_929_T3_WA_SET_FECHA_EMISION',               N'SCH_ORA_929'),
(951,0,N'ORA_951_T3_PROC_T3_BOD',                        N'SCH_ORA_951');

IF (SELECT COUNT(*) FROM @ExpectedJobs) <> 37
   OR (SELECT COUNT(*) FROM @ExpectedJobs WHERE OracleBroken = 0) <> 32
   OR (SELECT COUNT(*) FROM @ExpectedJobs WHERE OracleBroken = 1) <> 5
BEGIN
    THROW 51025, 'La lista interna debe contener 37 jobs: 32 activos y 5 BROKEN.', 1;
END;

/*
    Segunda barrera: repite las comprobaciones criticas de 02. Esto protege la
    activacion si alguien cambio un job despues de haber ejecutado el validador.
    Si falla, 02 indica en columnas separadas cual configuracion debe corregirse.
*/
IF EXISTS
(
    SELECT 1
    FROM @ExpectedJobs AS e
    LEFT JOIN [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS c
        ON c.Oracle_Job_No = e.OracleJobNo
    LEFT JOIN [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS m
        ON m.Oracle_Job_No = e.OracleJobNo
    LEFT JOIN msdb.dbo.sysjobs AS j
        ON j.[name] = e.JobName
    LEFT JOIN msdb.dbo.sysjobsteps AS js
        ON js.job_id = j.job_id AND js.step_id = 1
    LEFT JOIN msdb.dbo.sysschedules AS s
        ON s.[name] = e.ScheduleName
    WHERE c.Oracle_Job_No IS NULL
       OR c.Oracle_Broken <> e.OracleBroken
       OR OBJECT_ID(QUOTENAME(c.Required_Schema) + N'.' + QUOTENAME(c.Required_Procedure), N'P') IS NULL
       OR ISNULL(HAS_PERMS_BY_NAME(
              QUOTENAME(c.Required_Schema) + N'.' + QUOTENAME(c.Required_Procedure),
              N'OBJECT', N'EXECUTE'), 0) <> 1
       OR m.Oracle_Job_No IS NULL
       OR ISNULL(m.SqlAgent_Job_Name, N'') <> e.JobName
       OR j.job_id IS NULL
       OR m.SqlAgent_Job_Id <> j.job_id
       OR j.owner_sid <> SUSER_SID(@ExpectedOwner)
       /* Los cinco BROKEN deben continuar deshabilitados. Los otros 32 pueden
          estar deshabilitados o ya habilitados si el script se vuelve a correr. */
       OR (e.OracleBroken = 1 AND j.[enabled] <> 0)
       OR js.step_id IS NULL
       OR ISNULL(js.subsystem, N'') <> N'TSQL'
       OR ISNULL(js.database_name, N'') <> @TargetDatabase
       OR ISNULL(js.command, N'') <> c.Step_Command
       OR js.on_success_action <> 1
       OR js.on_fail_action <> 2
       OR s.schedule_id IS NULL
       OR m.Schedule_Id <> s.schedule_id
       OR s.[enabled] <> 1
       OR s.freq_type <> 4
       OR s.freq_interval <> 1
       OR s.freq_subday_type <> c.Converted_Subday_Type
       OR s.freq_subday_interval <> c.Converted_Subday_Interval
       OR s.active_start_time <> c.Converted_Start_Time
       OR s.active_end_time <> 235959
       OR NOT EXISTS
          (SELECT 1 FROM msdb.dbo.sysjobservers AS srv WHERE srv.job_id = j.job_id)
       OR NOT EXISTS
          (
              SELECT 1
              FROM msdb.dbo.sysjobschedules AS job_schedule
              WHERE job_schedule.job_id = j.job_id
                AND job_schedule.schedule_id = s.schedule_id
          )
)
BEGIN
    THROW 51026, 'La configuracion no coincide con lo esperado. Ejecute 02_VALIDATE_JOBS.SQL y corrija todos los estados distintos de OK.', 1;
END;

/*
    Dependencias internas conocidas. Aunque el procedimiento principal exista,
    cualquiera de estos faltantes provocaria un error durante la ejecucion.
*/
IF OBJECT_ID(N'[T3].[DELIVERY_CLEAR]', N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_V40_GENERAR_MX06_CM]', N'P') IS NULL
   OR (OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]', N'FN') IS NULL
       AND OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]', N'IF') IS NULL
       AND OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]', N'TF') IS NULL)
   OR (OBJECT_ID(N'[T3].[FN_VALIDA_RFC]', N'FN') IS NULL
       AND OBJECT_ID(N'[T3].[FN_VALIDA_RFC]', N'IF') IS NULL
       AND OBJECT_ID(N'[T3].[FN_VALIDA_RFC]', N'TF') IS NULL)
   OR OBJECT_ID(N'[T3].[PROC_CFDI_GENERAR_PAGO]', N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_CFDI_GENERAR_PAGO_AGR]', N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_T3_LANZA_REP]', N'P') IS NULL
   OR OBJECT_ID(N'[T3].[SEQ_CFD]', N'SO') IS NULL
   OR OBJECT_ID(N'[T3].[SEQ_PAGO_CENTRAL_AGR]', N'SO') IS NULL
   OR (OBJECT_ID(N'[T3].[FACTURA_GENERAL]', N'U') IS NULL
       AND OBJECT_ID(N'[T3].[FACTURA_GENERAL]', N'V') IS NULL)
BEGIN
    THROW 51027, 'Faltan dependencias T3 de segundo nivel. Revise el resultado 3 de 02_VALIDATE_JOBS.SQL.', 1;
END;

/*
    Estas dos definiciones migradas no deben conservar una llamada con formato
    Oracle package.procedure. NULL tampoco es aceptable: significa que el modulo
    falta o que AT85233588 no tiene permiso VIEW DEFINITION para revisarlo.
*/
IF OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_EOD]', N'P')) IS NULL
   OR OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_BOD]', N'P')) IS NULL
   OR OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_EOD]', N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_BOD]', N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
BEGIN
    THROW 51028, 'PROC_T3_EOD o PROC_T3_BOD falta, no es visible o conserva una referencia Oracle invalida. Revise 02_VALIDATE_JOBS.SQL.', 1;
END;

DECLARE
    @JobId UNIQUEIDENTIFIER,
    @JobName SYSNAME,
    @CurrentlyEnabled BIT,
    @EnabledNow INT = 0,
    @AlreadyEnabled INT = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE EnableCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT j.job_id, j.[name], j.[enabled]
        FROM @ExpectedJobs AS e
        INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
        WHERE e.OracleBroken = 0
        ORDER BY e.OracleJobNo;

    OPEN EnableCursor;
    FETCH NEXT FROM EnableCursor INTO @JobId, @JobName, @CurrentlyEnabled;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @CurrentlyEnabled = 0
        BEGIN
            EXEC msdb.dbo.sp_update_job @job_id = @JobId, @enabled = 1;
            SET @EnabledNow += 1;
            PRINT CONCAT(N'Habilitado: ', @JobName);
        END
        ELSE
        BEGIN
            SET @AlreadyEnabled += 1;
            PRINT CONCAT(N'Ya estaba habilitado: ', @JobName);
        END;

        FETCH NEXT FROM EnableCursor INTO @JobId, @JobName, @CurrentlyEnabled;
    END;

    CLOSE EnableCursor;
    DEALLOCATE EnableCursor;

    /* Verificacion posterior: 32 habilitados y cinco BROKEN deshabilitados. */
    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedJobs AS e
        INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
        WHERE (e.OracleBroken = 0 AND j.[enabled] <> 1)
           OR (e.OracleBroken = 1 AND j.[enabled] <> 0)
    )
    BEGIN
        THROW 51029, 'El estado final de uno o mas jobs no coincide con el estado Oracle esperado.', 1;
    END;

    COMMIT TRANSACTION;

    SELECT
        @EnabledNow AS Enabled_Now,
        @AlreadyEnabled AS Already_Enabled,
        5 AS Kept_Disabled_Broken,
        N'ACTIVACION COMPLETADA' AS [Status];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'EnableCursor') >= 0 CLOSE EnableCursor;
    IF CURSOR_STATUS('local', 'EnableCursor') > -3 DEALLOCATE EnableCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
