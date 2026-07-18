/* Rollback operativo: deshabilita los jobs migrados sin borrarlos ni perder historial. */
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map',N'U') IS NULL
BEGIN
    THROW 51030, 'No existe dbo.Job_Oracle_SQLAgent_Map.', 1;
END;

DECLARE @JobId UNIQUEIDENTIFIER,@JobName SYSNAME;
DECLARE DisableCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT j.job_id,j.[name]
FROM dbo.Job_Oracle_SQLAgent_Map AS m
INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id=m.SqlAgent_Job_Id;

OPEN DisableCursor;
FETCH NEXT FROM DisableCursor INTO @JobId,@JobName;
WHILE @@FETCH_STATUS=0
BEGIN
    EXEC msdb.dbo.sp_update_job @job_id=@JobId,@enabled=0;
    PRINT CONCAT('Deshabilitado: ',@JobName);
    FETCH NEXT FROM DisableCursor INTO @JobId,@JobName;
END;
CLOSE DisableCursor;
DEALLOCATE DisableCursor;
GO
