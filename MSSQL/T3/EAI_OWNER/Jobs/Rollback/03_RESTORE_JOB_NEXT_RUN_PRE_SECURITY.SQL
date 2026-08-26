/*
    PASO 3 DEL ROLLBACK TOTAL
    =========================
    Restaura EAI_OWNER.JOB_NEXT_RUN a la version anterior al endurecimiento
    de seguridad. Esa version llama directamente a los procedimientos de
    SQL Server Agent.

    IMPORTANTE:
      - Debe ejecutarse ANTES de eliminar msdb.dbo.T3_JOB_NEXT_RUN.
      - Esta restauracion evita que JOB_NEXT_RUN quede apuntando a un wrapper
        que ya no existira.
      - La version restaurada puede requerir permisos elevados para ejecutarse;
        ese era precisamente el comportamiento previo al cambio de seguridad.
*/
USE [T3QA];
GO

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

    -- Anio 4000 representa el estado BROKEN usado por el codigo Oracle.
    IF @pNextRun IS NOT NULL AND DATEPART(YEAR, @pNextRun) = 4000
        SET @Broken = 1;

    -- El procedimiento Oracle no realiza ninguna accion si el job es NULL.
    IF @pJOB IS NULL RETURN 0;

    BEGIN TRY
        IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
            THROW 51000, 'No existe EAI_OWNER.Job_Oracle_SQLAgent_Map.', 1;

        SELECT
            @SqlAgentJobId   = M.SqlAgent_Job_Id,
            @SqlAgentJobName = M.SqlAgent_Job_Name,
            @ScheduleId      = M.Schedule_Id
        FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS M
        WHERE M.Oracle_Job_No = @pJOB AND M.Is_Active = 1;

        IF @SqlAgentJobId IS NULL OR @ScheduleId IS NULL
            THROW 51001, 'No existe mapeo activo para el pJOB recibido.', 1;

        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE job_id = @SqlAgentJobId)
            THROW 51002, 'El job mapeado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE schedule_id = @ScheduleId)
            THROW 51003, 'El schedule mapeado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS
        (
            SELECT 1 FROM msdb.dbo.sysjobschedules
            WHERE job_id = @SqlAgentJobId AND schedule_id = @ScheduleId
        )
            THROW 51004, 'El schedule no esta asociado al job mapeado.', 1;

        -- Un schedule compartido no se modifica para no afectar otros jobs.
        SELECT @ScheduleJobCount = COUNT(*)
        FROM msdb.dbo.sysjobschedules
        WHERE schedule_id = @ScheduleId;

        IF @ScheduleJobCount > 1
            THROW 51005, 'El schedule esta asociado a mas de un job.', 1;

        IF @pNextRun IS NOT NULL
        BEGIN
            SET @ActiveStartDate = CONVERT(INT, CONVERT(CHAR(8), CAST(@pNextRun AS DATE), 112));
            SET @ActiveStartTime = DATEPART(HOUR, @pNextRun) * 10000
                                 + DATEPART(MINUTE, @pNextRun) * 100
                                 + DATEPART(SECOND, @pNextRun);
        END;

        SET @Enabled = CASE WHEN @Broken = 1 THEN 0 ELSE 1 END;

        BEGIN TRANSACTION;

            -- Comportamiento previo: llamada directa a los SP internos de msdb.
            EXEC @ReturnCode = msdb.dbo.sp_update_job
                @job_id = @SqlAgentJobId,
                @enabled = @Enabled;

            IF @ReturnCode <> 0
                THROW 51006, 'Error al actualizar el estado del job.', 1;

            IF @pNextRun IS NOT NULL
            BEGIN
                EXEC @ReturnCode = msdb.dbo.sp_update_schedule
                    @schedule_id = @ScheduleId,
                    @active_start_date = @ActiveStartDate,
                    @active_start_time = @ActiveStartTime;

                IF @ReturnCode <> 0
                    THROW 51007, 'Error al actualizar el schedule.', 1;
            END;

            UPDATE [EAI_OWNER].[Job_Oracle_SQLAgent_Map]
               SET Last_Update_Date = SYSDATETIME(),
                   Last_Update_User = SUSER_SNAME()
             WHERE Oracle_Job_No = @pJOB AND Is_Active = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT 'Paso 3 completado: EAI_OWNER.JOB_NEXT_RUN fue restaurado a su version previa.';
GO
