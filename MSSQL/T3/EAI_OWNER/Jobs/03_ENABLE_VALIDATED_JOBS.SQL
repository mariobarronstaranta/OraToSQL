/*
    Habilita solamente jobs que estaban activos en Oracle y cuya dependencia existe.
    El despliegue exige confirmacion manual para evitar una activacion accidental.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ConfirmEnable BIT = 0;       -- Cambiar a 1 durante la ventana de corte.
DECLARE @AllowPartialEnable BIT = 0;  -- Mantener 0 para exigir todas las dependencias.

IF @ConfirmEnable<>1
BEGIN
    THROW 51020, 'Activacion cancelada. Cambie @ConfirmEnable a 1 durante la ventana autorizada.', 1;
END;

IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map',N'U') IS NULL
   OR OBJECT_ID(N'dbo.Job_Oracle_Migration_Catalog',N'U') IS NULL
BEGIN
    THROW 51021, 'No existe el catalogo de migracion de jobs.', 1;
END;

/* No habilitar jobs mientras falten dependencias conocidas de segundo nivel. */
IF OBJECT_ID(N'[T3].[DELIVERY_CLEAR]',N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_V40_GENERAR_MX06_CM]',N'P') IS NULL
   OR (OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]',N'FN') IS NULL
       AND OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]',N'IF') IS NULL
       AND OBJECT_ID(N'[T3].[FN_ADDENDA_PARAM]',N'TF') IS NULL)
   OR (OBJECT_ID(N'[T3].[FN_VALIDA_RFC]',N'FN') IS NULL
       AND OBJECT_ID(N'[T3].[FN_VALIDA_RFC]',N'IF') IS NULL
       AND OBJECT_ID(N'[T3].[FN_VALIDA_RFC]',N'TF') IS NULL)
   OR OBJECT_ID(N'[T3].[PROC_CFDI_GENERAR_PAGO]',N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_CFDI_GENERAR_PAGO_AGR]',N'P') IS NULL
   OR OBJECT_ID(N'[T3].[PROC_T3_LANZA_REP]',N'P') IS NULL
   OR OBJECT_ID(N'[T3].[SEQ_CFD]',N'SO') IS NULL
   OR OBJECT_ID(N'[T3].[SEQ_PAGO_CENTRAL_AGR]',N'SO') IS NULL
   OR (OBJECT_ID(N'[T3].[FACTURA_GENERAL]',N'U') IS NULL
       AND OBJECT_ID(N'[T3].[FACTURA_GENERAL]',N'V') IS NULL)
   OR OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_EOD]',N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'[T3].[PROC_T3_BOD]',N'P')) LIKE N'%PKG_T3%PROC_T3_LANZA_REP%'
BEGIN
    THROW 51023, 'Faltan dependencias T3 de segundo nivel. Revise la ultima consulta de 02_VALIDATE_JOBS.SQL.', 1;
END;

IF @AllowPartialEnable=0 AND EXISTS
(
    SELECT 1
    FROM dbo.Job_Oracle_Migration_Catalog
    WHERE Oracle_Broken=0
      AND OBJECT_ID(QUOTENAME(Required_Schema)+N'.'+QUOTENAME(Required_Procedure),N'P') IS NULL
)
BEGIN
    THROW 51022, 'Hay jobs activos en Oracle con procedimientos MSSQL faltantes. Revise 02_VALIDATE_JOBS.SQL.', 1;
END;

DECLARE @JobId UNIQUEIDENTIFIER, @JobName SYSNAME;
DECLARE EnableCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT j.job_id,j.[name]
FROM dbo.Job_Oracle_Migration_Catalog AS c
INNER JOIN dbo.Job_Oracle_SQLAgent_Map AS m ON m.Oracle_Job_No=c.Oracle_Job_No
INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id=m.SqlAgent_Job_Id
INNER JOIN msdb.dbo.sysjobsteps AS js ON js.job_id=j.job_id AND js.step_id=1
WHERE c.Oracle_Broken=0
  AND OBJECT_ID(QUOTENAME(c.Required_Schema)+N'.'+QUOTENAME(c.Required_Procedure),N'P') IS NOT NULL
  AND js.[database_name]=DB_NAME()
  AND js.[command]=c.Step_Command;

OPEN EnableCursor;
FETCH NEXT FROM EnableCursor INTO @JobId,@JobName;
WHILE @@FETCH_STATUS=0
BEGIN
    EXEC msdb.dbo.sp_update_job @job_id=@JobId,@enabled=1;
    PRINT CONCAT('Habilitado: ',@JobName);
    FETCH NEXT FROM EnableCursor INTO @JobId,@JobName;
END;
CLOSE EnableCursor;
DEALLOCATE EnableCursor;

/* Los cinco jobs BROKEN en Oracle permanecen deshabilitados deliberadamente. */
GO
