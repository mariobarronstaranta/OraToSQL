CREATE OR ALTER PROCEDURE [EAI_OWNER].[JOB_NEXT_DATE]
(
    @P_JOB         INT,
    @v_Fecha_Exec CHAR(19)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @FechaExec       DATETIME2(0),
        @SqlAgentJobId   UNIQUEIDENTIFIER,
        @SqlAgentJobName SYSNAME,
        @ScheduleId      INT,
        @ScheduleJobCount INT,
        @ActiveStartDate INT,
        @ActiveStartTime INT,
        @ReturnCode      INT;

    /*
        Developer notes
        ---------------
        Oracle original:

            IF (P_JOB IS NOT NULL) THEN
                DBMS_JOB.NEXT_DATE(
                    P_JOB,
                    TO_DATE(v_Fecha_Exec, 'dd/mm/yyyy hh24:mi:ss')
                );
            END IF;
            COMMIT;

        Objetivo funcional:
            Mover la proxima ejecucion del job a la fecha/hora indicada.

        Diferencia importante en SQL Server:
            SQL Server Agent no tiene un campo NEXT_DATE editable como DBMS_JOB.
            El proximo arranque se deriva del schedule. Por eso esta migracion
            actualiza active_start_date y active_start_time del schedule mapeado,
            pero NO cambia freq_type ni freq_interval. Cambiar freq_type a One
            Time destruiria la recurrencia original del job.

        Dependencia de migracion:
            dbo.Job_Oracle_SQLAgent_Map debe mapear:
                Oracle_Job_No   -> DBMS_JOB.Job
                SqlAgent_Job_Id -> msdb.dbo.sysjobs.job_id
                Schedule_Id     -> msdb.dbo.sysschedules.schedule_id
    */

    IF @P_JOB IS NULL
        RETURN 0;

    BEGIN TRY
        IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
            THROW 51000, 'No existe dbo.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        /*
            Oracle esperaba exactamente dd/mm/yyyy hh24:mi:ss.
            TRY_CONVERT con estilo 103 interpreta dd/mm/yyyy; al recibir CHAR(19)
            conserva la hora cuando viene en formato 24 horas.
        */
        SET @FechaExec = TRY_CONVERT(DATETIME2(0), @v_Fecha_Exec, 103);

        IF @FechaExec IS NULL
            THROW 51001, 'Formato de fecha invalido. Use dd/mm/yyyy hh24:mi:ss.', 1;

        SELECT
            @SqlAgentJobId   = M.SqlAgent_Job_Id,
            @SqlAgentJobName = M.SqlAgent_Job_Name,
            @ScheduleId      = M.Schedule_Id
        FROM dbo.Job_Oracle_SQLAgent_Map AS M
        WHERE M.Oracle_Job_No = @P_JOB
          AND M.Is_Active = 1;

        IF @SqlAgentJobId IS NULL OR @ScheduleId IS NULL
            THROW 51002, 'No existe mapeo activo con job y schedule para el P_JOB recibido.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobs AS J
            WHERE J.job_id = @SqlAgentJobId
        )
            THROW 51003, 'El SqlAgent_Job_Id registrado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysschedules AS S
            WHERE S.schedule_id = @ScheduleId
        )
            THROW 51004, 'El Schedule_Id registrado no existe en SQL Server Agent.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobschedules AS JS
            WHERE JS.job_id = @SqlAgentJobId
              AND JS.schedule_id = @ScheduleId
        )
            THROW 51005, 'El Schedule_Id no esta asociado al SqlAgent_Job_Id registrado.', 1;

        /*
            En Oracle cada DBMS_JOB tiene su propio NEXT_DATE. En SQL Server un
            schedule puede ser compartido por varios jobs. Si se compartiera,
            moverlo afectaria procesos ajenos; por eso se bloquea el cambio.
        */
        SELECT @ScheduleJobCount = COUNT(*)
        FROM msdb.dbo.sysjobschedules AS JS
        WHERE JS.schedule_id = @ScheduleId;

        IF @ScheduleJobCount > 1
            THROW 51006, 'El schedule esta asociado a mas de un job; no se actualiza para evitar afectar otros procesos.', 1;

        SET @ActiveStartDate = CONVERT(INT, CONVERT(CHAR(8), CAST(@FechaExec AS DATE), 112));
        SET @ActiveStartTime =
              DATEPART(HOUR, @FechaExec) * 10000
            + DATEPART(MINUTE, @FechaExec) * 100
            + DATEPART(SECOND, @FechaExec);

        BEGIN TRANSACTION;

            /*
                No se fuerza @enabled ni @freq_type. Esta rutina solo mueve la
                fecha/hora base del schedule, equivalente practico a NEXT_DATE.
            */
            EXEC @ReturnCode = msdb.dbo.sp_update_schedule
                @schedule_id       = @ScheduleId,
                @active_start_date = @ActiveStartDate,
                @active_start_time = @ActiveStartTime;

            IF @ReturnCode <> 0
                THROW 51007, 'Error al actualizar active_start_date/time del schedule.', 1;

            UPDATE dbo.Job_Oracle_SQLAgent_Map
               SET Last_Update_Date = SYSDATETIME(),
                   Last_Update_User = SUSER_SNAME()
             WHERE Oracle_Job_No = @P_JOB
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
