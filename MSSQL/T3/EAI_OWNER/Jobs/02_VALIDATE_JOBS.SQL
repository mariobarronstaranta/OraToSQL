/*
    Valida el despliegue realizado por 01_CREATE_OR_UPDATE_JOBS.SQL.

    Este archivo es de solo lectura: no crea, modifica, habilita ni ejecuta jobs.
    Debe ejecutarse como AT85233588 para comprobar los permisos reales con los
    que SQL Server Agent ejecutara los pasos T-SQL.

    COMO LEER EL RESULTADO
    ---------------------
    - Deployment_Status = OK: el job coincide con la configuracion esperada.
    - Cualquier otro valor indica exactamente el primer problema encontrado.
    - Al final se genera el error 51019 si existe al menos un problema critico.
      Esto evita continuar accidentalmente con 03_ENABLE_VALIDATED_JOBS.SQL.
*/
SET NOCOUNT ON;

DECLARE @TargetDatabase SYSNAME = N'T3QA';
DECLARE @ExpectedOwner SYSNAME = N'AT85233588';

/*
    DB_NAME() devuelve la base a la que esta conectada la ventana de SSMS.
    La validacion se detiene aqui para no consultar objetos de otra base.
*/
IF DB_NAME() <> @TargetDatabase
BEGIN
    THROW 51010, 'Ejecute 02_VALIDATE_JOBS.SQL conectado a la base de datos T3QA.', 1;
END;

IF SUSER_ID(@ExpectedOwner) IS NULL
BEGIN
    THROW 51011, 'No existe el login SQL AT85233588 en esta instancia.', 1;
END;

/*
    HAS_PERMS_BY_NAME valida los permisos del usuario que ejecuta la consulta.
    Por eso se exige ejecutar este archivo con el mismo login propietario de
    los jobs y no con una cuenta sysadmin, que siempre devolveria permiso.
*/
IF SUSER_SID() <> SUSER_SID(@ExpectedOwner)
BEGIN
    THROW 51012, 'Ejecute esta validacion con el login SQL AT85233588.', 1;
END;

IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
   OR OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NULL
BEGIN
    THROW 51013, 'Faltan las tablas de control. Ejecute primero 01_CREATE_OR_UPDATE_JOBS.SQL.', 1;
END;

/*
    Esta lista es independiente de las tablas creadas por el instalador.
    Si el instalador fallo a la mitad, un LEFT JOIN permite mostrar los jobs
    faltantes. Si se consultara solamente el catalogo, esos jobs no aparecerian.
*/
DECLARE @ExpectedJobs TABLE
(
    OracleJobNo  INT     NOT NULL PRIMARY KEY,
    JobName      SYSNAME NOT NULL UNIQUE,
    ScheduleName SYSNAME NOT NULL UNIQUE
);

INSERT INTO @ExpectedJobs (OracleJobNo, JobName, ScheduleName)
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

/*
    Se guarda el diagnostico en una tabla para usar exactamente las mismas
    reglas en el detalle, el resumen y la decision final PASS/FAIL.
*/
DECLARE @JobValidation TABLE
(
    Oracle_Job_No              INT            NOT NULL PRIMARY KEY,
    Expected_Job_Name          SYSNAME        NOT NULL,
    Required_Object            NVARCHAR(517)  NULL,
    Catalog_Status             VARCHAR(32)    NOT NULL,
    Dependency_Status          VARCHAR(32)    NOT NULL,
    Execute_Permission_Status  VARCHAR(32)    NOT NULL,
    Map_Status                 VARCHAR(32)    NOT NULL,
    Actual_Owner               SYSNAME        NULL,
    Job_Status                 VARCHAR(32)    NOT NULL,
    Step_Status                VARCHAR(32)    NOT NULL,
    Schedule_Status            VARCHAR(32)    NOT NULL,
    Deployment_Status          VARCHAR(32)    NOT NULL
);

INSERT INTO @JobValidation
(
    Oracle_Job_No, Expected_Job_Name, Required_Object, Catalog_Status,
    Dependency_Status, Execute_Permission_Status, Map_Status, Actual_Owner,
    Job_Status, Step_Status, Schedule_Status, Deployment_Status
)
SELECT
    e.OracleJobNo,
    e.JobName,
    status.RequiredObject,
    status.CatalogStatus,
    status.DependencyStatus,
    status.PermissionStatus,
    status.MapStatus,
    SUSER_SNAME(j.owner_sid),
    status.JobStatus,
    status.StepStatus,
    status.ScheduleStatus,
    CASE
        WHEN status.CatalogStatus <> 'OK' THEN status.CatalogStatus
        WHEN status.DependencyStatus <> 'OK' THEN status.DependencyStatus
        WHEN status.PermissionStatus <> 'OK' THEN status.PermissionStatus
        WHEN status.MapStatus <> 'OK' THEN status.MapStatus
        WHEN status.JobStatus <> 'OK' THEN status.JobStatus
        WHEN status.StepStatus <> 'OK' THEN status.StepStatus
        WHEN status.ScheduleStatus <> 'OK' THEN status.ScheduleStatus
        ELSE 'OK'
    END
FROM @ExpectedJobs AS e
LEFT JOIN [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS c
    ON c.Oracle_Job_No = e.OracleJobNo
LEFT JOIN [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS m
    ON m.Oracle_Job_No = e.OracleJobNo
/*
    Los objetos de msdb se buscan por el nombre esperado, no solamente por el
    ID del mapeo. Asi tambien se detecta un mapeo que apunta al job equivocado.
*/
LEFT JOIN msdb.dbo.sysjobs AS j
    ON j.[name] = e.JobName
LEFT JOIN msdb.dbo.sysjobsteps AS js
    ON js.job_id = j.job_id AND js.step_id = 1
LEFT JOIN msdb.dbo.sysschedules AS s
    ON s.[name] = e.ScheduleName
CROSS APPLY
(
    SELECT
        CASE
            WHEN c.Oracle_Job_No IS NULL THEN NULL
            ELSE QUOTENAME(c.Required_Schema) + N'.' + QUOTENAME(c.Required_Procedure)
        END AS RequiredObject
) AS object_name
CROSS APPLY
(
    SELECT
        CASE WHEN c.Oracle_Job_No IS NULL THEN 'CATALOG_MISSING' ELSE 'OK' END AS CatalogStatus,
        CASE
            WHEN c.Oracle_Job_No IS NULL THEN 'NOT_CHECKED'
            WHEN OBJECT_ID(object_name.RequiredObject, N'P') IS NULL THEN 'DEPENDENCY_MISSING'
            ELSE 'OK'
        END AS DependencyStatus,
        CASE
            WHEN c.Oracle_Job_No IS NULL OR OBJECT_ID(object_name.RequiredObject, N'P') IS NULL THEN 'NOT_CHECKED'
            /* HAS_PERMS_BY_NAME puede devolver NULL; NULL tambien significa que no se pudo comprobar el permiso. */
            WHEN ISNULL(HAS_PERMS_BY_NAME(object_name.RequiredObject, N'OBJECT', N'EXECUTE'), 0) <> 1
                THEN 'EXECUTE_PERMISSION_MISSING'
            ELSE 'OK'
        END AS PermissionStatus,
        CASE
            WHEN m.Oracle_Job_No IS NULL THEN 'MAP_MISSING'
            WHEN ISNULL(m.SqlAgent_Job_Name, N'') <> e.JobName THEN 'WRONG_JOB_NAME_IN_MAP'
            WHEN j.job_id IS NOT NULL AND m.SqlAgent_Job_Id <> j.job_id THEN 'WRONG_JOB_ID_IN_MAP'
            WHEN s.schedule_id IS NOT NULL AND m.Schedule_Id <> s.schedule_id THEN 'WRONG_SCHEDULE_ID_IN_MAP'
            WHEN m.Is_Active <> 1 THEN 'MAP_NOT_ACTIVE'
            ELSE 'OK'
        END AS MapStatus,
        CASE
            WHEN j.job_id IS NULL THEN 'JOB_MISSING'
            WHEN j.owner_sid <> SUSER_SID(@ExpectedOwner) THEN 'WRONG_JOB_OWNER'
            WHEN j.[enabled] <> 0 THEN 'JOB_NOT_DISABLED'
            WHEN NOT EXISTS
                 (SELECT 1 FROM msdb.dbo.sysjobservers AS srv WHERE srv.job_id = j.job_id)
                 THEN 'JOBSERVER_MISSING'
            ELSE 'OK'
        END AS JobStatus,
        CASE
            WHEN j.job_id IS NULL THEN 'NOT_CHECKED'
            WHEN js.step_id IS NULL THEN 'STEP_MISSING'
            WHEN ISNULL(js.subsystem, N'') <> N'TSQL' THEN 'WRONG_STEP_SUBSYSTEM'
            WHEN ISNULL(js.database_name, N'') <> @TargetDatabase THEN 'WRONG_STEP_DATABASE'
            WHEN c.Oracle_Job_No IS NULL THEN 'NOT_CHECKED'
            WHEN ISNULL(js.command, N'') <> c.Step_Command THEN 'WRONG_STEP_COMMAND'
            WHEN js.on_success_action <> 1 OR js.on_fail_action <> 2 THEN 'WRONG_STEP_ACTIONS'
            ELSE 'OK'
        END AS StepStatus,
        CASE
            WHEN s.schedule_id IS NULL THEN 'SCHEDULE_MISSING'
            WHEN c.Oracle_Job_No IS NULL THEN 'NOT_CHECKED'
            WHEN s.[enabled] <> 1 THEN 'SCHEDULE_DISABLED'
            WHEN s.freq_type <> 4 OR s.freq_interval <> 1 THEN 'WRONG_DAILY_FREQUENCY'
            WHEN s.freq_subday_type <> c.Converted_Subday_Type
              OR s.freq_subday_interval <> c.Converted_Subday_Interval
              OR s.active_start_time <> c.Converted_Start_Time
              OR s.active_end_time <> 235959 THEN 'WRONG_SCHEDULE_CONFIG'
            WHEN j.job_id IS NULL THEN 'NOT_CHECKED'
            WHEN NOT EXISTS
                 (
                     SELECT 1
                     FROM msdb.dbo.sysjobschedules AS job_schedule
                     WHERE job_schedule.job_id = j.job_id
                       AND job_schedule.schedule_id = s.schedule_id
                 ) THEN 'SCHEDULE_NOT_ATTACHED'
            ELSE 'OK'
        END AS ScheduleStatus
) AS status;

/* Resultado 1: detalle de cada uno de los 37 jobs esperados. */
SELECT
    Oracle_Job_No,
    Expected_Job_Name,
    Required_Object,
    Catalog_Status,
    Dependency_Status,
    Execute_Permission_Status,
    Map_Status,
    Actual_Owner,
    Job_Status,
    Step_Status,
    Schedule_Status,
    Deployment_Status
FROM @JobValidation
ORDER BY Oracle_Job_No;

/* Resultado 2: resumen rapido. Ready_Jobs debe ser igual a Expected_Jobs. */
SELECT
    COUNT(*) AS Expected_Jobs,
    SUM(CASE WHEN Catalog_Status = 'OK' THEN 1 ELSE 0 END) AS Catalog_Rows,
    SUM(CASE WHEN Dependency_Status = 'OK' THEN 1 ELSE 0 END) AS Existing_Procedures,
    SUM(CASE WHEN Execute_Permission_Status = 'OK' THEN 1 ELSE 0 END) AS Executable_Procedures,
    SUM(CASE WHEN Job_Status = 'OK' THEN 1 ELSE 0 END) AS Valid_Jobs,
    SUM(CASE WHEN Step_Status = 'OK' THEN 1 ELSE 0 END) AS Valid_Steps,
    SUM(CASE WHEN Schedule_Status = 'OK' THEN 1 ELSE 0 END) AS Valid_Schedules,
    SUM(CASE WHEN Deployment_Status = 'OK' THEN 1 ELSE 0 END) AS Ready_Jobs
FROM @JobValidation;

/*
    Dependencias de segundo nivel: son objetos llamados dentro de los
    procedimientos principales. El job puede existir aunque uno de estos
    objetos falte, pero fallaria cuando intentara ejecutarse.
*/
DECLARE @RuntimeDependencies TABLE
(
    Object_Name  NVARCHAR(517) NOT NULL,
    Expected_Type VARCHAR(20)  NOT NULL,
    Used_By      SYSNAME       NOT NULL
);

INSERT INTO @RuntimeDependencies (Object_Name, Expected_Type, Used_By)
VALUES
(N'[T3].[DELIVERY_CLEAR]',              'PROCEDURE', N'PROC_CFDI_LIBERACION_REMISION'),
(N'[T3].[PROC_V40_GENERAR_MX06_CM]',    'PROCEDURE', N'PROC_CFDI_LIBERACION_NOTA'),
(N'[T3].[FN_ADDENDA_PARAM]',            'FUNCTION',  N'PROC_CFDI_LIBERACION_PAC'),
(N'[T3].[FN_VALIDA_RFC]',               'FUNCTION',  N'PROC_CFDI_LIBERACION_PAGO'),
(N'[T3].[PROC_CFDI_GENERAR_PAGO]',      'PROCEDURE', N'PROC_CFDI_LIBERACION_PAGO'),
(N'[T3].[PROC_CFDI_GENERAR_PAGO_AGR]',  'PROCEDURE', N'PROC_CFDI_LIBERA_PAGO_CENTRAL'),
(N'[T3].[PROC_T3_LANZA_REP]',           'PROCEDURE', N'PROC_T3_EOD/PROC_T3_BOD'),
(N'[T3].[SEQ_CFD]',                      'SEQUENCE',  N'PROC_CFDI_PROCESA_PAGO_AGR'),
(N'[T3].[SEQ_PAGO_CENTRAL_AGR]',        'SEQUENCE',  N'PROC_CFDI_PROCESA_PAGO_AGR'),
(N'[T3].[FACTURA_GENERAL]',              'TABLE/VIEW',N'PROC_CFDI_LIBERACION_PAC');

DECLARE @RuntimeValidation TABLE
(
    Object_Name NVARCHAR(517) NOT NULL,
    Expected_Type VARCHAR(20) NOT NULL,
    Used_By SYSNAME NOT NULL,
    Dependency_Status VARCHAR(16) NOT NULL
);

INSERT INTO @RuntimeValidation
SELECT
    Object_Name,
    Expected_Type,
    Used_By,
    CASE
        WHEN Expected_Type = 'PROCEDURE' AND OBJECT_ID(Object_Name, N'P') IS NOT NULL THEN 'OK'
        WHEN Expected_Type = 'FUNCTION'
         AND (OBJECT_ID(Object_Name, N'FN') IS NOT NULL
           OR OBJECT_ID(Object_Name, N'IF') IS NOT NULL
           OR OBJECT_ID(Object_Name, N'TF') IS NOT NULL) THEN 'OK'
        WHEN Expected_Type = 'SEQUENCE' AND OBJECT_ID(Object_Name, N'SO') IS NOT NULL THEN 'OK'
        WHEN Expected_Type = 'TABLE/VIEW'
         AND (OBJECT_ID(Object_Name, N'U') IS NOT NULL
           OR OBJECT_ID(Object_Name, N'V') IS NOT NULL) THEN 'OK'
        ELSE 'MISSING'
    END
FROM @RuntimeDependencies;

/* Resultado 3: objetos internos requeridos durante la ejecucion. */
SELECT Object_Name, Expected_Type, Used_By, Dependency_Status
FROM @RuntimeValidation
ORDER BY Object_Name;

/*
    SQL Server no admite la sintaxis Oracle T3.PKG_T3.PROC_T3_LANZA_REP.
    OBJECT_DEFINITION devuelve NULL tanto si falta el modulo como si el usuario
    no tiene VIEW DEFINITION; esos casos se reportan por separado y nunca como OK.
*/
DECLARE @ModuleReferenceValidation TABLE
(
    Module_Name NVARCHAR(517) NOT NULL,
    Reference_Status VARCHAR(32) NOT NULL,
    Required_Action NVARCHAR(200) NOT NULL
);

INSERT INTO @ModuleReferenceValidation
SELECT
    Module_Name,
    CASE
        WHEN OBJECT_ID(Module_Name, N'P') IS NULL THEN 'MODULE_MISSING'
        WHEN OBJECT_DEFINITION(OBJECT_ID(Module_Name, N'P')) IS NULL THEN 'DEFINITION_NOT_VISIBLE'
        WHEN OBJECT_DEFINITION(OBJECT_ID(Module_Name, N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
            THEN 'INVALID_PACKAGE_REFERENCE'
        ELSE 'OK'
    END,
    N'Reemplazar la llamada Oracle por EXEC [T3].[PROC_T3_LANZA_REP] ...'
FROM (VALUES (N'[T3].[PROC_T3_EOD]'), (N'[T3].[PROC_T3_BOD]')) AS modules(Module_Name);

/* Resultado 4: revision especial de las dos referencias de package. */
SELECT Module_Name, Reference_Status, Required_Action
FROM @ModuleReferenceValidation
ORDER BY Module_Name;

/*
    Resultado final consumible por una persona o por una herramienta automatica.
    El THROW es intencional: un resultado visual con errores no debe interpretarse
    como una validacion exitosa solo porque el archivo termino de ejecutarse.
*/
IF EXISTS (SELECT 1 FROM @JobValidation WHERE Deployment_Status <> 'OK')
   OR EXISTS (SELECT 1 FROM @RuntimeValidation WHERE Dependency_Status <> 'OK')
   OR EXISTS (SELECT 1 FROM @ModuleReferenceValidation WHERE Reference_Status <> 'OK')
BEGIN
    SELECT N'FAIL' AS Validation_Result,
           N'Revise las filas cuyo estado sea diferente de OK. No ejecute 03_ENABLE_VALIDATED_JOBS.SQL.' AS Next_Action;

    THROW 51019, 'La validacion de jobs encontro errores. Revise los resultados anteriores.', 1;
END;

SELECT N'PASS' AS Validation_Result,
       N'Los 37 jobs estan listos para la revision previa a su habilitacion.' AS Next_Action;
GO
