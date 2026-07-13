CREATE OR ALTER PROCEDURE [EAI_OWNER].[JOB_REFRESH]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        Developer notes
        ---------------
        Oracle original:

            TRUNCATE TABLE EAI_OWNER.INTERNAL_JOBS;

            FOR Jobs IN (SELECT ... FROM USER_JOBS) LOOP
                INSERT INTO EAI_OWNER.INTERNAL_JOBS (...)
                VALUES (Jobs....);
            END LOOP;

        Objetivo funcional:
            Reconstruir EAI_OWNER.INTERNAL_JOBS como una fotografia local de
            USER_JOBS, para que otros procesos sigan consultando una estructura
            parecida a Oracle aunque la calendarizacion viva en SQL Server Agent.

        Traduccion SQL Server:
            - USER_JOBS se aproxima con msdb.dbo.sysjobs, sysjobsteps,
              sysjobschedules, sysschedules, sysjobactivity y sysjobhistory.
            - dbo.Job_Oracle_SQLAgent_Map conserva el numero Oracle JOBNO y el
              schedule principal migrado.
            - LAST_DATE se toma de la ultima ejecucion exitosa, porque en
              Oracle USER_JOBS.LAST_DATE representa la ultima ejecucion correcta.
            - THIS_DATE se toma de sysjobactivity cuando el job esta corriendo.
            - NEXT_DATE se toma de sysjobschedules.next_run_date/time.
            - TOTAL_TIME se normaliza a segundos; SQL Agent guarda run_duration
              en formato HHMMSS empaquetado.
    */

    BEGIN TRY
        IF OBJECT_ID(N'[EAI_OWNER].[INTERNAL_JOBS]', N'U') IS NULL
            THROW 51000, 'No existe la tabla EAI_OWNER.INTERNAL_JOBS.', 1;

        IF OBJECT_ID(N'dbo.Job_Oracle_SQLAgent_Map', N'U') IS NULL
            THROW 51001, 'No existe dbo.Job_Oracle_SQLAgent_Map para mapear DBMS_JOB a SQL Server Agent.', 1;

        BEGIN TRANSACTION;

            TRUNCATE TABLE [EAI_OWNER].[INTERNAL_JOBS];

            ;WITH CurrentAgentSession AS
            (
                SELECT MAX(session_id) AS session_id
                FROM msdb.dbo.syssessions
            ),
            RunningJobs AS
            (
                SELECT
                    Activity.job_id,
                    Activity.start_execution_date AS this_date
                FROM msdb.dbo.sysjobactivity AS Activity
                INNER JOIN CurrentAgentSession AS CurrentSession
                    ON CurrentSession.session_id = Activity.session_id
                WHERE Activity.start_execution_date IS NOT NULL
                  AND Activity.stop_execution_date IS NULL
            ),
            JobHistory AS
            (
                SELECT
                    History.job_id,
                    History.instance_id,
                    History.run_date,
                    History.run_time,
                    History.run_duration,
                    History.run_status,
                    CASE
                        WHEN History.run_date > 0
                        THEN msdb.dbo.agent_datetime(History.run_date, History.run_time)
                        ELSE NULL
                    END AS run_datetime,
                    ((History.run_duration / 10000) * 3600)
                    + (((History.run_duration % 10000) / 100) * 60)
                    + (History.run_duration % 100) AS run_duration_seconds
                FROM msdb.dbo.sysjobhistory AS History
                WHERE History.step_id = 0
            ),
            LastSuccessfulRun AS
            (
                SELECT
                    Source.job_id,
                    Source.instance_id,
                    Source.run_datetime AS last_date,
                    Source.run_duration_seconds AS total_time,
                    ROW_NUMBER() OVER
                    (
                        PARTITION BY Source.job_id
                        ORDER BY Source.instance_id DESC
                    ) AS rn
                FROM JobHistory AS Source
                WHERE Source.run_status = 1
            ),
            LastSuccessfulInstance AS
            (
                SELECT
                    job_id,
                    MAX(instance_id) AS last_success_instance_id
                FROM JobHistory
                WHERE run_status = 1
                GROUP BY job_id
            ),
            FailureCount AS
            (
                SELECT
                    History.job_id,
                    COUNT(*) AS failures
                FROM JobHistory AS History
                LEFT JOIN LastSuccessfulInstance AS LastSuccess
                    ON LastSuccess.job_id = History.job_id
                WHERE History.run_status = 0
                  AND History.instance_id > ISNULL(LastSuccess.last_success_instance_id, 0)
                GROUP BY History.job_id
            ),
            NextRun AS
            (
                SELECT
                    JobSchedule.job_id,
                    JobSchedule.schedule_id,
                    CASE
                        WHEN JobSchedule.next_run_date > 0
                        THEN msdb.dbo.agent_datetime(JobSchedule.next_run_date, JobSchedule.next_run_time)
                        ELSE NULL
                    END AS next_date
                FROM msdb.dbo.sysjobschedules AS JobSchedule
            ),
            FirstJobStep AS
            (
                SELECT
                    Step.job_id,
                    Step.command,
                    ROW_NUMBER() OVER
                    (
                        PARTITION BY Step.job_id
                        ORDER BY Step.step_id
                    ) AS rn
                FROM msdb.dbo.sysjobsteps AS Step
            ),
            ScheduleDefinition AS
            (
                SELECT
                    Schedule.schedule_id,
                    CONCAT(
                        'freq_type=', Schedule.freq_type,
                        ';freq_interval=', Schedule.freq_interval,
                        ';freq_subday_type=', Schedule.freq_subday_type,
                        ';freq_subday_interval=', Schedule.freq_subday_interval,
                        ';freq_relative_interval=', Schedule.freq_relative_interval,
                        ';freq_recurrence_factor=', Schedule.freq_recurrence_factor,
                        ';active_start_date=', Schedule.active_start_date,
                        ';active_start_time=', Schedule.active_start_time,
                        ';active_end_date=', Schedule.active_end_date,
                        ';active_end_time=', Schedule.active_end_time
                    ) AS schedule_definition
                FROM msdb.dbo.sysschedules AS Schedule
            )
            INSERT INTO [EAI_OWNER].[INTERNAL_JOBS]
            (
                JOBNO,
                LOG_USER,
                PRIV_USER,
                SCHEMA_USER,
                LAST_DATE,
                LAST_SEC,
                THIS_DATE,
                THIS_SEC,
                NEXT_DATE,
                NEXT_SEC,
                TOTAL_TIME,
                BROKEN,
                INTERVAL_JOB,
                FAILURES,
                WHAT,
                NLS_ENV,
                INSTANCE_JOB
            )
            SELECT
                Map.Oracle_Job_No AS JOBNO,
                SUSER_SNAME(Job.owner_sid) AS LOG_USER,
                SUSER_SNAME(Job.owner_sid) AS PRIV_USER,
                'EAI_OWNER' AS SCHEMA_USER,

                LastRun.last_date AS LAST_DATE,
                CASE
                    WHEN LastRun.last_date IS NOT NULL
                    THEN CONVERT(CHAR(8), LastRun.last_date, 108)
                    ELSE NULL
                END AS LAST_SEC,

                Running.this_date AS THIS_DATE,
                CASE
                    WHEN Running.this_date IS NOT NULL
                    THEN CONVERT(CHAR(8), Running.this_date, 108)
                    ELSE NULL
                END AS THIS_SEC,

                NextRun.next_date AS NEXT_DATE,
                CASE
                    WHEN NextRun.next_date IS NOT NULL
                    THEN CONVERT(CHAR(8), NextRun.next_date, 108)
                    ELSE NULL
                END AS NEXT_SEC,

                LastRun.total_time AS TOTAL_TIME,

                CASE
                    WHEN Job.enabled = 1 THEN 'N'
                    ELSE 'Y'
                END AS BROKEN,

                LEFT
                (
                    COALESCE
                    (
                        Map.Last_Interval,
                        Map.Original_Interval,
                        ScheduleDef.schedule_definition,
                        'NO_SCHEDULE'
                    ),
                    4000
                ) AS INTERVAL_JOB,

                ISNULL(Failures.failures, 0) AS FAILURES,
                LEFT(COALESCE(FirstStep.command, Job.name), 4000) AS WHAT,

                LEFT
                (
                    CONCAT
                    (
                        'LANGUAGE=', @@LANGUAGE,
                        ';COLLATION=', CONVERT(VARCHAR(128), DATABASEPROPERTYEX(DB_NAME(), 'Collation')),
                        ';DATEFIRST=', CONVERT(VARCHAR(10), @@DATEFIRST)
                    ),
                    4000
                ) AS NLS_ENV,

                LEFT(CONVERT(VARCHAR(128), @@SERVERNAME), 128) AS INSTANCE_JOB
            FROM dbo.Job_Oracle_SQLAgent_Map AS Map
            INNER JOIN msdb.dbo.sysjobs AS Job
                ON Job.job_id = Map.SqlAgent_Job_Id
            LEFT JOIN LastSuccessfulRun AS LastRun
                ON LastRun.job_id = Job.job_id
               AND LastRun.rn = 1
            LEFT JOIN RunningJobs AS Running
                ON Running.job_id = Job.job_id
            LEFT JOIN NextRun
                ON NextRun.job_id = Job.job_id
               AND NextRun.schedule_id = Map.Schedule_Id
            LEFT JOIN FirstJobStep AS FirstStep
                ON FirstStep.job_id = Job.job_id
               AND FirstStep.rn = 1
            LEFT JOIN ScheduleDefinition AS ScheduleDef
                ON ScheduleDef.schedule_id = Map.Schedule_Id
            LEFT JOIN FailureCount AS Failures
                ON Failures.job_id = Job.job_id
            WHERE Map.Is_Active = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
