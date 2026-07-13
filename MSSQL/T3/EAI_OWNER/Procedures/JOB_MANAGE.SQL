CREATE OR ALTER PROCEDURE [EAI_OWNER].[JOB_MANAGE]
(
    @sAction VARCHAR(20),
    @sType   VARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sChar              VARCHAR(10) = ';',
        @nStatus            INT,
        @bEnabled           BIT,
        @dtNextRun          DATETIME2(0),
        @dtNextXML          DATETIME2(0),
        @dtJobNextRun       DATETIME2(0),
        @OracleJobNo        INT,
        @SqlAgentJobId      UNIQUEIDENTIFIER,
        @SqlAgentJobName    SYSNAME,
        @ScheduleId         INT,
        @ScheduleJobCount   INT,
        @What               NVARCHAR(MAX),
        @Replicated         INT,
        @ActiveStartDate    INT,
        @ActiveStartTime    INT,
        @ReturnCode         INT;

    /*
        Developer notes
        ---------------
        Oracle JOB_MANAGE usaba USER_JOBS y DBMS_JOB.BROKEN para suspender o
        reactivar grupos de jobs. Al reactivar, calculaba el siguiente arranque:

            dtNextRun = SYSDATE + 30 segundos
            dtNextXML = dtNextRun + 2 minutos
            getNextRun(Replicated, dtNextRun, dtNextXML)

        En esta migracion:
        - dbo.Job_Oracle_SQLAgent_Map conserva la relacion DBMS_JOB.Job -> SQL Agent.
        - msdb.dbo.sp_update_job sustituye DBMS_JOB.BROKEN para enabled/disabled.
        - msdb.dbo.sp_update_schedule ajusta active_start_date/time al reactivar.
        - EAI_OWNER.GETNEXTRUN conserva la regla de desfase para jobs no replicados.
    */

    SET @dtNextRun = DATEADD(SECOND, 30, SYSDATETIME());
    SET @dtNextXML = DATEADD(MINUTE, 2, @dtNextRun);

    IF @sAction = 'Suspend'
    BEGIN
        SET @nStatus = 0;
        SET @bEnabled = 0;
    END
    ELSE
    BEGIN
        SET @nStatus = 1;
        SET @bEnabled = 1;
    END;

    BEGIN TRY
        IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
            THROW 51000, 'No existe dbo.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        DECLARE @Jobs TABLE
        (
            OracleJobNo     INT NOT NULL PRIMARY KEY,
            SqlAgentJobId   UNIQUEIDENTIFIER NOT NULL,
            SqlAgentJobName SYSNAME NULL,
            ScheduleId      INT NOT NULL,
            What            NVARCHAR(MAX) NOT NULL,
            Replicated      INT NOT NULL
        );

        /*
            USER_JOBS.What se aproxima con el comando del primer step del job.
            Si el step incluye prefijos como EXEC o schema, la comparacion de
            MX_Components mantiene la regla original y puede requerir ajuste de
            los datos migrados, no de esta rutina.
        */
        INSERT INTO @Jobs
        (
            OracleJobNo,
            SqlAgentJobId,
            SqlAgentJobName,
            ScheduleId,
            What,
            Replicated
        )
        SELECT
            Map.Oracle_Job_No,
            Map.SqlAgent_Job_Id,
            COALESCE(Map.SqlAgent_Job_Name, Job.name),
            Map.Schedule_Id,
            UPPER(COALESCE(Step.command, Job.name)),
            CHARINDEX('.REP_', UPPER(COALESCE(Step.command, Job.name)))
        FROM dbo.Job_Oracle_SQLAgent_Map AS Map
        INNER JOIN msdb.dbo.sysjobs AS Job
            ON Job.job_id = Map.SqlAgent_Job_Id
        INNER JOIN msdb.dbo.sysjobsteps AS Step
            ON Step.job_id = Job.job_id
           AND Step.step_id = 1
        WHERE Map.Is_Active = 1
          AND
          (
                (
                    @sType = 'Todos'
                    AND
                    (
                           UPPER(COALESCE(Step.command, Job.name)) LIKE 'GEN_REPLICATION%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE 'GEN_OUTBOUND_XML%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE 'SEND_STAGE_T3%'
                    )
                )
             OR (
                    @sType = 'Entregas'
                    AND UPPER(COALESCE(Step.command, Job.name)) LIKE '%DELIVERY_CONFIRMATION%'
                )
             OR (
                    @sType = 'HandHeld'
                    AND
                    (
                           UPPER(COALESCE(Step.command, Job.name)) LIKE '%PAYMENT%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%PAYMENT_ALLOCATION%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%DELIVERY_CONFIRMATION%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%CREDIT_NOTE%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%INVOICE%'
                    )
                    AND CHARINDEX('RECV_INVOICE', UPPER(COALESCE(Step.command, Job.name))) = 0
                    AND CHARINDEX('RECV_PAYMENT', UPPER(COALESCE(Step.command, Job.name))) = 0
                )
             OR (
                    @sType = 'Clientes'
                    AND UPPER(COALESCE(Step.command, Job.name)) LIKE '%CUSTOMER%'
                )
             OR (
                    @sType = 'Cadenas'
                    AND UPPER(COALESCE(Step.command, Job.name)) LIKE '%ACCOUNT%'
                )
             OR (
                    @sType = 'MovtosProd'
                    AND
                    (
                           UPPER(COALESCE(Step.command, Job.name)) LIKE '%PRODUCT_MOVEMENT%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%INTERNAL_ORDER%'
                    )
                )
             OR (
                    @sType = 'Pedidos'
                    AND
                    (
                           UPPER(COALESCE(Step.command, Job.name)) LIKE '%RMA_ORDER%'
                        OR UPPER(COALESCE(Step.command, Job.name)) LIKE '%SALES_ORDER%'
                    )
                )
             OR (
                    @sType = 'Depositos'
                    AND UPPER(COALESCE(Step.command, Job.name)) LIKE '%BANK_DEPOSIT%'
                )
          );

        DECLARE cur_jobs CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                OracleJobNo,
                SqlAgentJobId,
                SqlAgentJobName,
                ScheduleId,
                What,
                Replicated
            FROM @Jobs
            ORDER BY SqlAgentJobName;

        OPEN cur_jobs;

        FETCH NEXT FROM cur_jobs
        INTO @OracleJobNo, @SqlAgentJobId, @SqlAgentJobName, @ScheduleId, @What, @Replicated;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM msdb.dbo.sysschedules AS S
                WHERE S.schedule_id = @ScheduleId
            )
                THROW 51001, 'El Schedule_Id mapeado no existe en SQL Server Agent.', 1;

            SELECT @ScheduleJobCount = COUNT(*)
            FROM msdb.dbo.sysjobschedules AS JS
            WHERE JS.schedule_id = @ScheduleId;

            IF NOT EXISTS
            (
                SELECT 1
                FROM msdb.dbo.sysjobschedules AS JS
                WHERE JS.job_id = @SqlAgentJobId
                  AND JS.schedule_id = @ScheduleId
            )
                THROW 51002, 'El Schedule_Id mapeado no esta asociado al job en SQL Server Agent.', 1;

            IF @ScheduleJobCount > 1
                THROW 51003, 'El schedule esta asociado a mas de un job; no se actualiza para evitar afectar otros procesos.', 1;

            SET @dtJobNextRun = [EAI_OWNER].[GETNEXTRUN](@Replicated, @dtNextRun, @dtNextXML);
            SET @ActiveStartDate = CONVERT(INT, CONVERT(CHAR(8), CAST(@dtJobNextRun AS DATE), 112));
            SET @ActiveStartTime =
                  DATEPART(HOUR, @dtJobNextRun) * 10000
                + DATEPART(MINUTE, @dtJobNextRun) * 100
                + DATEPART(SECOND, @dtJobNextRun);

            BEGIN TRANSACTION;

                EXEC @ReturnCode = msdb.dbo.sp_update_job
                    @job_id = @SqlAgentJobId,
                    @enabled = @bEnabled;

                IF @ReturnCode <> 0
                    THROW 51004, 'Error al actualizar el estado del job en SQL Server Agent.', 1;

                IF @bEnabled = 1
                BEGIN
                    EXEC @ReturnCode = msdb.dbo.sp_update_schedule
                        @schedule_id = @ScheduleId,
                        @enabled = 1,
                        @active_start_date = @ActiveStartDate,
                        @active_start_time = @ActiveStartTime;

                    IF @ReturnCode <> 0
                        THROW 51005, 'Error al actualizar el siguiente arranque del schedule.', 1;
                END;

                UPDATE C
                   SET C.Status = @nStatus
                FROM [EAI_OWNER].[MX_Components] AS C
                WHERE UPPER(C.Name) + @sChar = @What;

                UPDATE dbo.Job_Oracle_SQLAgent_Map
                   SET Last_Update_Date = SYSDATETIME(),
                       Last_Update_User = SUSER_SNAME()
                 WHERE Oracle_Job_No = @OracleJobNo;

            COMMIT TRANSACTION;

            FETCH NEXT FROM cur_jobs
            INTO @OracleJobNo, @SqlAgentJobId, @SqlAgentJobName, @ScheduleId, @What, @Replicated;
        END;

        CLOSE cur_jobs;
        DEALLOCATE cur_jobs;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_jobs') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'cur_jobs') > -1
                CLOSE cur_jobs;
            DEALLOCATE cur_jobs;
        END;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
