CREATE OR ALTER FUNCTION [EAI_OWNER].[GET_T3_ENABLE_EXECUTE]
(
    @sDefaultValue VARCHAR(3)
)
RETURNS VARCHAR(3)
AS
BEGIN
    DECLARE
        @sReturn      VARCHAR(3) = @sDefaultValue,
        @nCompT3In    INT = 0,
        @nCompRunning INT = 0,
        @nJobsT3In    INT = 0,
        @nJobsRunning INT = 0;

    SELECT
        @nCompT3In = ISNULL(COUNT(1), 0),
        @nCompRunning = ISNULL(SUM(CASE WHEN ISNULL(Status, 0) = 1 THEN 0 ELSE 1 END), 0)
    FROM [EAI_OWNER].[MX_Components]
    WHERE Component BETWEEN 300 AND 312;

    SELECT
        @nJobsT3In = ISNULL(COUNT(DISTINCT j.job_id), 0),
        @nJobsRunning = ISNULL(SUM(CASE
                                      WHEN j.enabled = 1 AND ISNULL(sjs.next_run_date, 0) <> 0 THEN 1
                                      ELSE 0
                                   END), 0)
    FROM [msdb].[dbo].[sysjobs] AS j
    INNER JOIN [msdb].[dbo].[sysjobsteps] AS js
        ON js.job_id = j.job_id
    LEFT JOIN [msdb].[dbo].[sysjobschedules] AS sjs
        ON sjs.job_id = j.job_id
    WHERE js.command LIKE '%RECV_TO_SEND_V3%'
       OR j.name LIKE '%RECV_TO_SEND_V3%';

    IF @nJobsT3In = 0
    BEGIN
        IF @nCompT3In = 0
            SET @sReturn = 'YES';
        ELSE IF @nCompRunning > 0
            SET @sReturn = 'NO';
    END
    ELSE
    BEGIN
        IF @nJobsRunning > 0
            SET @sReturn = 'NO';
    END;

    RETURN @sReturn;
END;
GO
