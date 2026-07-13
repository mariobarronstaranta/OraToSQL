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
        @ScheduleJobCount INT,
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
            - sp_update_job @enabled = 0/1 sustituye DBMS_JOB.BROKEN.
            - sp_update_schedule active_start_date/time aproxima pNextRun.
            - No se cambian freq_type, freq_interval ni subday settings; esas
              reglas pertenecen a JOB_INTERVAL y al schedule ya migrado.

        Dependencia:
            dbo.Job_Oracle_SQLAgent_Map debe mapear el numero DBMS_JOB.Job al
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
        IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
            THROW 51000, 'No existe dbo.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        SELECT
            @SqlAgentJobId   = M.SqlAgent_Job_Id,
            @SqlAgentJobName = M.SqlAgent_Job_Name,
            @ScheduleId      = M.Schedule_Id
        FROM dbo.Job_Oracle_SQLAgent_Map AS M
        WHERE M.Oracle_Job_No = @pJOB
          AND M.Is_Active = 1;

        IF @SqlAgentJobId IS NULL OR @ScheduleId IS NULL
            THROW 51001, 'No existe mapeo activo con job y schedule para el pJOB recibido.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobs AS J
            WHERE J.job_id = @SqlAgentJobId
        )
            THROW 51002, 'El SqlAgent_Job_Id mapeado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysschedules AS S
            WHERE S.schedule_id = @ScheduleId
        )
            THROW 51003, 'El Schedule_Id mapeado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobschedules AS JS
            WHERE JS.job_id = @SqlAgentJobId
              AND JS.schedule_id = @ScheduleId
        )
            THROW 51004, 'El Schedule_Id mapeado no esta asociado al job en SQL Server Agent.', 1;

        /*
            DBMS_JOB tiene NEXT_DATE por job. SQL Server permite compartir un
            schedule entre jobs; moverlo compartido afectaria otros procesos.
        */
        SELECT @ScheduleJobCount = COUNT(*)
        FROM msdb.dbo.sysjobschedules AS JS
        WHERE JS.schedule_id = @ScheduleId;

        IF @ScheduleJobCount > 1
            THROW 51005, 'El schedule esta asociado a mas de un job; no se actualiza para evitar afectar otros procesos.', 1;

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

            EXEC @ReturnCode = msdb.dbo.sp_update_job
                @job_id = @SqlAgentJobId,
                @enabled = @Enabled;

            IF @ReturnCode <> 0
                THROW 51006, 'Error al actualizar el estado enabled del job en SQL Server Agent.', 1;

            /*
                Se actualiza fecha/hora base aunque el job quede deshabilitado.
                Esto conserva el pNextRun enviado por Oracle y evita perder la
                intencion del caller si luego alguien reactiva el job.
            */
            IF @pNextRun IS NOT NULL
            BEGIN
                EXEC @ReturnCode = msdb.dbo.sp_update_schedule
                    @schedule_id = @ScheduleId,
                    @active_start_date = @ActiveStartDate,
                    @active_start_time = @ActiveStartTime;

                IF @ReturnCode <> 0
                    THROW 51007, 'Error al actualizar active_start_date/time del schedule.', 1;
            END;

            UPDATE dbo.Job_Oracle_SQLAgent_Map
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
