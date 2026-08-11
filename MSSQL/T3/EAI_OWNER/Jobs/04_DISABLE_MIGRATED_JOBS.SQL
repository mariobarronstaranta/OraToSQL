/*
    Rollback operativo de los jobs migrados desde Oracle.

    Deshabilita los jobs para impedir ejecuciones futuras, pero NO los elimina,
    NO borra su historial y NO detiene una ejecucion que ya este en curso.
    Para eliminar completamente los objetos use 00_ROLLBACK_CREATE_OR_UPDATE_JOBS.SQL.

    Este archivo busca los 37 nombres esperados directamente en msdb. No depende
    de las tablas de mapeo, porque esas tablas pueden haber quedado incompletas si
    01_CREATE_OR_UPDATE_JOBS.SQL fallo durante su ejecucion.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDatabase SYSNAME = N'T3QA';
DECLARE @ExpectedOwner SYSNAME = N'AT85233588';
DECLARE @ConfirmDisable BIT = 0; -- Cambiar manualmente a 1 cuando se autorice detener la programacion.

IF DB_NAME() <> @TargetDatabase
BEGIN
    THROW 51030, 'Ejecute 04_DISABLE_MIGRATED_JOBS.SQL conectado a la base de datos T3QA.', 1;
END;

IF SUSER_ID(@ExpectedOwner) IS NULL
BEGIN
    THROW 51031, 'No existe el login SQL AT85233588 en esta instancia.', 1;
END;

/* AT85233588 puede modificar sus propios jobs; un sysadmin puede intervenir en una contingencia. */
IF SUSER_SID() <> SUSER_SID(@ExpectedOwner)
   AND IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51032, 'Ejecute este archivo como AT85233588 o como un miembro de sysadmin.', 1;
END;

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
    THROW 51033, 'AT85233588 necesita pertenecer a un rol de SQL Server Agent en msdb.', 1;
END;

/* Esta confirmacion evita deshabilitar los jobs por ejecutar el archivo accidentalmente. */
IF @ConfirmDisable <> 1
BEGIN
    THROW 51034, 'Deshabilitacion cancelada. Cambie @ConfirmDisable a 1 durante la ventana autorizada.', 1;
END;

DECLARE @ExpectedJobs TABLE
(
    OracleJobNo INT     NOT NULL PRIMARY KEY,
    JobName     SYSNAME NOT NULL UNIQUE
);

INSERT INTO @ExpectedJobs (OracleJobNo, JobName)
VALUES
( 42,N'ORA_42_EAI_OWNER_WA_ERR_INTERCOMPANY'),
(103,N'ORA_103_EAI_OWNER_WA_DEPURA_MESSAGE_LOG'),
(189,N'ORA_189_T3_PROC_T3_OT_DOCTOS_INTERCO'),
(208,N'ORA_208_EAI_OWNER_PROC_RECEIVE_REFERENCE'),
(216,N'ORA_216_EAI_OWNER_RECV_REPLENISHMENT'),
(227,N'ORA_227_EAI_OWNER_WA_ERR_INVOICE_AMPERSAND'),
(229,N'ORA_229_EAI_OWNER_RECV_INVOICE_INTERCOMPANY'),
(236,N'ORA_236_EAI_OWNER_RECV_PAYMENT'),
(249,N'ORA_249_T3_PROC_T3_OT_DOCTOS'),
(250,N'ORA_250_T3_PROC_CFDI_LIBERACION_PAC'),
(266,N'ORA_266_T3_WA_CFDI_COBRANZA'),
(327,N'ORA_327_T3_PROC_CFDI_LIBERACION_REMISION'),
(347,N'ORA_347_T3_PROC_CFDI_LIBERACION_NOTA'),
(468,N'ORA_468_T3_WA_CFDI_COBRANZA_FIX'),
(471,N'ORA_471_T3_PROC_CFDI_LIBERACION_PAGO'),
(508,N'ORA_508_T3_PROC_CFDI_LIBERACION_AGR'),
(550,N'ORA_550_EAI_OWNER_RECV_INVOICE'),
(568,N'ORA_568_EAI_SF_BITACORA_CFDI'),
(569,N'ORA_569_EAI_SF_BITACORA_CFDI_RESUMEN'),
(589,N'ORA_589_T3_PROC_T3_EOD'),
(648,N'ORA_648_EAI_OWNER_RECV_CUSTOMER'),
(649,N'ORA_649_EAI_OWNER_WA_ERR_CUSTOMER_AMPERSAND'),
(668,N'ORA_668_T3_PROC_CFDI_PROCESA_PAGO_AGR'),
(688,N'ORA_688_EAI_OWNER_WA_RUN_STATEMENTS'),
(729,N'ORA_729_T3_PROC_CFDI_CARTAPORTE_REP'),
(750,N'ORA_750_EAI_OWNER_SF_JOB_MANAGE'),
(769,N'ORA_769_EAI_OWNER_WA_ERR_REPLENISH_AMPERSAND'),
(789,N'ORA_789_T3_WA_V40_REGIMEN'),
(809,N'ORA_809_T3_PROC_CFDI_LIBERA_PAGO_CENTRAL'),
(829,N'ORA_829_EAI_SF_CFDI_VENTA'),
(830,N'ORA_830_EAI_SF_CFDI_NOTA_CREDITO'),
(849,N'ORA_849_EAI_SF_CFDI_OPEN_ITEMS'),
(869,N'ORA_869_EAI_OWNER_WA_ERR_PRODUCT_AMPERSAND'),
(889,N'ORA_889_EAI_OWNER_SF_PROC_CENTRAL_INCOBRABLE'),
(910,N'ORA_910_T3_WA_UPD_SUBDEPOSITOS'),
(929,N'ORA_929_T3_WA_SET_FECHA_EMISION'),
(951,N'ORA_951_T3_PROC_T3_BOD');

IF (SELECT COUNT(*) FROM @ExpectedJobs) <> 37
BEGIN
    THROW 51035, 'La lista interna de rollback operativo debe contener exactamente 37 jobs.', 1;
END;

/*
    No se modifica un job con el nombre esperado si pertenece a otro login.
    Eso puede indicar una colision de nombres o un despliegue anterior realizado
    con otro propietario; un DBA debe revisar el caso antes de continuar.
*/
IF EXISTS
(
    SELECT 1
    FROM @ExpectedJobs AS e
    INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
    WHERE j.owner_sid <> SUSER_SID(@ExpectedOwner)
)
BEGIN
    SELECT
        e.OracleJobNo AS Oracle_Job_No,
        e.JobName,
        SUSER_SNAME(j.owner_sid) AS Actual_Owner,
        @ExpectedOwner AS Expected_Owner
    FROM @ExpectedJobs AS e
    INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
    WHERE j.owner_sid <> SUSER_SID(@ExpectedOwner)
    ORDER BY e.OracleJobNo;

    THROW 51036, 'Hay jobs con propietario distinto de AT85233588. No se modifico ningun job.', 1;
END;

DECLARE
    @JobId UNIQUEIDENTIFIER,
    @JobName SYSNAME,
    @CurrentlyEnabled BIT,
    @DisabledNow INT = 0,
    @AlreadyDisabled INT = 0,
    @MissingJobs INT = 0;

SELECT @MissingJobs = COUNT(*)
FROM @ExpectedJobs AS e
LEFT JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
WHERE j.job_id IS NULL;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE DisableCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT j.job_id, j.[name], j.[enabled]
        FROM @ExpectedJobs AS e
        INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
        ORDER BY e.OracleJobNo;

    OPEN DisableCursor;
    FETCH NEXT FROM DisableCursor INTO @JobId, @JobName, @CurrentlyEnabled;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @CurrentlyEnabled = 1
        BEGIN
            EXEC msdb.dbo.sp_update_job @job_id = @JobId, @enabled = 0;
            SET @DisabledNow += 1;
            PRINT CONCAT(N'Deshabilitado: ', @JobName);
        END
        ELSE
        BEGIN
            SET @AlreadyDisabled += 1;
            PRINT CONCAT(N'Ya estaba deshabilitado: ', @JobName);
        END;

        FETCH NEXT FROM DisableCursor INTO @JobId, @JobName, @CurrentlyEnabled;
    END;

    CLOSE DisableCursor;
    DEALLOCATE DisableCursor;

    /* Si algun job encontrado sigue activo, toda la operacion se revierte. */
    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedJobs AS e
        INNER JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
        WHERE j.[enabled] <> 0
    )
    BEGIN
        THROW 51037, 'Uno o mas jobs encontrados continuan habilitados.', 1;
    END;

    COMMIT TRANSACTION;

    /*
        Los jobs MISSING no son un error operativo: pueden corresponder a una
        instalacion parcial. Se reportan para que el developer conozca el alcance.
    */
    SELECT
        @DisabledNow AS Disabled_Now,
        @AlreadyDisabled AS Already_Disabled,
        @MissingJobs AS Missing_Jobs,
        CASE WHEN @MissingJobs = 0
             THEN N'DESHABILITACION COMPLETADA'
             ELSE N'DESHABILITACION COMPLETADA; HAY JOBS QUE NO EXISTIAN'
        END AS [Status];

    SELECT
        e.OracleJobNo AS Oracle_Job_No,
        e.JobName,
        CASE
            WHEN j.job_id IS NULL THEN N'MISSING'
            WHEN j.[enabled] = 0 THEN N'DISABLED'
            ELSE N'STILL_ENABLED'
        END AS Job_Status
    FROM @ExpectedJobs AS e
    LEFT JOIN msdb.dbo.sysjobs AS j ON j.[name] = e.JobName
    ORDER BY e.OracleJobNo;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'DisableCursor') >= 0 CLOSE DisableCursor;
    IF CURSOR_STATUS('local', 'DisableCursor') > -3 DEALLOCATE DisableCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
