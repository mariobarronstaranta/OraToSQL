/* Ejecutar en la base de datos de la aplicacion despues de 01_CREATE_OR_UPDATE_JOBS.SQL. */
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Job_Oracle_Migration_Catalog', N'U') IS NULL
BEGIN
    THROW 51010, 'Falta ejecutar 01_CREATE_OR_UPDATE_JOBS.SQL.', 1;
END;

SELECT
    c.Oracle_Job_No,
    CONCAT(QUOTENAME(c.Required_Schema),N'.',QUOTENAME(c.Required_Procedure)) AS Required_Object,
    CASE WHEN OBJECT_ID(QUOTENAME(c.Required_Schema)+N'.'+QUOTENAME(c.Required_Procedure),N'P') IS NULL
         THEN N'MISSING' ELSE N'OK' END AS Dependency_Status,
    c.Oracle_Broken,
    j.[name] AS SqlAgent_Job_Name,
    j.[enabled] AS SqlAgent_Enabled,
    s.[name] AS Schedule_Name,
    s.[enabled] AS Schedule_Enabled,
    js.[database_name] AS Step_Database,
    js.[command] AS Step_Command,
    c.Original_Interval,
    CASE
      WHEN j.job_id IS NULL THEN N'JOB_MISSING'
      WHEN s.schedule_id IS NULL THEN N'SCHEDULE_MISSING'
      WHEN js.step_id IS NULL THEN N'STEP_MISSING'
      WHEN js.[database_name]<>DB_NAME() THEN N'WRONG_DATABASE'
      WHEN js.[command]<>c.Step_Command THEN N'WRONG_COMMAND'
      WHEN j.[enabled]<>0 THEN N'UNEXPECTEDLY_ENABLED'
      ELSE N'OK'
    END AS Deployment_Status
FROM dbo.Job_Oracle_Migration_Catalog AS c
LEFT JOIN dbo.Job_Oracle_SQLAgent_Map AS m
  ON m.Oracle_Job_No=c.Oracle_Job_No
LEFT JOIN msdb.dbo.sysjobs AS j
  ON j.job_id=m.SqlAgent_Job_Id
LEFT JOIN msdb.dbo.sysjobsteps AS js
  ON js.job_id=j.job_id AND js.step_id=1
LEFT JOIN msdb.dbo.sysschedules AS s
  ON s.schedule_id=m.Schedule_Id
ORDER BY c.Oracle_Job_No;

SELECT
    COUNT(*) AS Total_Oracle_Jobs,
    SUM(CASE WHEN c.Oracle_Broken=0 THEN 1 ELSE 0 END) AS Originally_Active,
    SUM(CASE WHEN c.Oracle_Broken=1 THEN 1 ELSE 0 END) AS Originally_Broken,
    SUM(CASE WHEN OBJECT_ID(QUOTENAME(c.Required_Schema)+N'.'+QUOTENAME(c.Required_Procedure),N'P') IS NULL THEN 1 ELSE 0 END) AS Missing_Dependencies,
    SUM(CASE WHEN j.job_id IS NULL THEN 1 ELSE 0 END) AS Missing_Agent_Jobs,
    SUM(CASE WHEN j.[enabled]=1 THEN 1 ELSE 0 END) AS Currently_Enabled
FROM dbo.Job_Oracle_Migration_Catalog AS c
LEFT JOIN dbo.Job_Oracle_SQLAgent_Map AS m ON m.Oracle_Job_No=c.Oracle_Job_No
LEFT JOIN msdb.dbo.sysjobs AS j ON j.job_id=m.SqlAgent_Job_Id;

/*
    Dependencias de segundo nivel encontradas dentro de los procedimientos T3.
    Se validan por el nombre exacto que utiliza el codigo migrado. Un archivo con
    sufijo _Migrado no satisface una llamada a [T3].[DELIVERY_CLEAR].
*/
DECLARE @RuntimeDependencies TABLE
(
    Object_Name NVARCHAR(517) NOT NULL,
    Expected_Type VARCHAR(20) NOT NULL,
    Used_By SYSNAME NOT NULL
);

INSERT INTO @RuntimeDependencies VALUES
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

SELECT
    Object_Name,
    Expected_Type,
    Used_By,
    CASE
      WHEN Expected_Type='PROCEDURE' AND OBJECT_ID(Object_Name,N'P') IS NOT NULL THEN N'OK'
      WHEN Expected_Type='FUNCTION' AND
           (OBJECT_ID(Object_Name,N'FN') IS NOT NULL OR OBJECT_ID(Object_Name,N'IF') IS NOT NULL OR OBJECT_ID(Object_Name,N'TF') IS NOT NULL) THEN N'OK'
      WHEN Expected_Type='SEQUENCE' AND OBJECT_ID(Object_Name,N'SO') IS NOT NULL THEN N'OK'
      WHEN Expected_Type='TABLE/VIEW' AND
           (OBJECT_ID(Object_Name,N'U') IS NOT NULL OR OBJECT_ID(Object_Name,N'V') IS NOT NULL) THEN N'OK'
      ELSE N'MISSING'
    END AS Dependency_Status
FROM @RuntimeDependencies
ORDER BY Object_Name;

/* Detecta la llamada Oracle de package que no es valida como equivalente T-SQL. */
SELECT
    Module_Name,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(Module_Name,N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
         THEN N'INVALID_PACKAGE_REFERENCE' ELSE N'OK' END AS Reference_Status,
    N'Reemplazar por EXEC [T3].[PROC_T3_LANZA_REP] ...' AS Required_Action
FROM (VALUES (N'[T3].[PROC_T3_EOD]'),(N'[T3].[PROC_T3_BOD]')) AS m(Module_Name);
GO
