CREATE OR ALTER PROCEDURE [EAI_OWNER].[JOB_NEXT_RUN]
(
    @pJOB     INT,
    @pNextRun DATETIME2(0)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Broken           BIT = 0,
        @SqlAgentJobId    UNIQUEIDENTIFIER,
        @SqlAgentJobName  SYSNAME,
        @ScheduleId       INT,
        @ActiveStartDate  INT,
        @ActiveStartTime  INT,
        @Enabled          BIT,
        @ReturnCode       INT;

    /*
        Developer notes
        ---------------
        Oracle original:

            bBOOLEAN := FALSE;
            IF TO_CHAR(pNextRun, 'YYYY') = '4000' THEN
                bBOOLEAN := TRUE;
            END IF;

            IF (pJOB IS NOT NULL) THEN
                DBMS_JOB.Broken(pJOB, bBOOLEAN, pNextRun);
                COMMIT;
            END IF;

        Objetivo funcional:
            - Si pNextRun cae en anio 4000, marcar el job como "broken".
            - En Oracle "broken" equivale a que DBMS_JOB no vuelva a ejecutarlo.
            - Si no cae en anio 4000, reactivar el job y mover su proxima base
              de ejecucion a pNextRun.

        Traduccion SQL Server:
            - msdb.dbo.T3_JOB_NEXT_RUN encapsula sp_update_job y
              sp_update_schedule bajo el login tecnico T3_SQLAGENT_OWNER.
            - No se cambian freq_type, freq_interval ni subday settings; esas
              reglas pertenecen a JOB_INTERVAL y al schedule ya migrado.

        Dependencia:
            EAI_OWNER.Job_Oracle_SQLAgent_Map debe mapear el numero DBMS_JOB.Job al
            job_id y schedule_id de SQL Server Agent.
    */

    IF @pNextRun IS NOT NULL
       AND DATEPART(YEAR, @pNextRun) = 4000
    BEGIN
        SET @Broken = 1;
    END;

    -- Oracle no hace nada cuando pJOB es NULL.
    IF @pJOB IS NULL
        RETURN 0;

    BEGIN TRY
        IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
            THROW 51000, 'No existe EAI_OWNER.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        SELECT
            @SqlAgentJobId   = M.SqlAgent_Job_Id,
            @SqlAgentJobName = M.SqlAgent_Job_Name,
            @ScheduleId      = M.Schedule_Id
        FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS M
        WHERE M.Oracle_Job_No = @pJOB
          AND M.Is_Active = 1;

        IF @SqlAgentJobId IS NULL OR @ScheduleId IS NULL
            THROW 51001, 'No existe mapeo activo con job y schedule para el pJOB recibido.', 1;

        IF @pNextRun IS NOT NULL
        BEGIN
            SET @ActiveStartDate = CONVERT(INT, CONVERT(CHAR(8), CAST(@pNextRun AS DATE), 112));
            SET @ActiveStartTime =
                  DATEPART(HOUR, @pNextRun) * 10000
                + DATEPART(MINUTE, @pNextRun) * 100
                + DATEPART(SECOND, @pNextRun);
        END;

        SET @Enabled = CASE WHEN @Broken = 1 THEN 0 ELSE 1 END;

        BEGIN TRANSACTION;

            /*
                El wrapper de msdb valida existencia, asociacion, exclusividad,
                lista permitida y propietario antes de modificar SQL Agent.
                El caller solo requiere EXECUTE sobre este modulo controlado.
            */
            EXEC @ReturnCode = msdb.dbo.T3_JOB_NEXT_RUN
                @JobId = @SqlAgentJobId,
                @ScheduleId = @ScheduleId,
                @Enabled = @Enabled,
                @ActiveDate = @ActiveStartDate,
                @ActiveTime = @ActiveStartTime;

            IF @ReturnCode <> 0
                THROW 51006, 'El wrapper msdb.dbo.T3_JOB_NEXT_RUN no pudo actualizar el job y su schedule.', 1;

            UPDATE [EAI_OWNER].[Job_Oracle_SQLAgent_Map]
               SET Last_Update_Date = SYSDATETIME(),
                   Last_Update_User = SUSER_SNAME()
             WHERE Oracle_Job_No = @pJOB
               AND Is_Active = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
