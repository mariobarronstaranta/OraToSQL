CREATE OR ALTER FUNCTION EAI_OWNER.GET_T3_ENABLE_EXECUTE
(
    @sDefaultValue VARCHAR(3)
)
RETURNS VARCHAR(3)
AS
BEGIN
    DECLARE @sReturn      VARCHAR(3) = @sDefaultValue;
    DECLARE @nCompT3In    INT = 0;
    DECLARE @nCompRunning INT = 0;
    DECLARE @nJobsT3In    INT = 0;
    DECLARE @nJobsRunning INT = 0;

    /*
        Componentes T3:
        Oracle:
            SUM(1) AS CompT3In
            SUM(DECODE(Status, 1, 0, 1)) AS CompRunning

        Interpretación conservada:
            Status = 1  => no cuenta como running
            Status <> 1 o NULL => cuenta como running
    */
    SELECT
        @nCompT3In =
            COALESCE(COUNT(1), 0),
        @nCompRunning =
            COALESCE(SUM(
                CASE
                    WHEN COALESCE(Status, 0) = 1 THEN 0
                    ELSE 1
                END
            ), 0)
    FROM EAI_OWNER.MX_Components
    WHERE Component BETWEEN 300 AND 312;

    /*
        Jobs Oracle:
            USER_JOBS.What LIKE '%RECV_TO_SEND_V3%'
            DECODE(TO_CHAR(UJ.Next_Date, 'YYYY'), '4000', 0, 1)

        Equivalente SQL Server propuesto:
            - Buscar RECV_TO_SEND_V3 en el nombre del job o en el comando del job step.
            - Considerar "running/programado" si el job está habilitado y tiene próxima ejecución.
    */
    ;WITH JobInfo AS
    (
        SELECT
            j.job_id,
            MAX(
                CASE
                    WHEN j.enabled = 1
                         AND COALESCE(sjs.next_run_date, 0) <> 0
                    THEN 1
                    ELSE 0
                END
            ) AS IsRunnable
        FROM msdb.dbo.sysjobs j
        INNER JOIN msdb.dbo.sysjobsteps js
            ON js.job_id = j.job_id
        LEFT JOIN msdb.dbo.sysjobschedules sjs
            ON sjs.job_id = j.job_id
        WHERE
            js.command LIKE '%RECV_TO_SEND_V3%'
            OR j.name LIKE '%RECV_TO_SEND_V3%'
        GROUP BY
            j.job_id
    )
    SELECT
        @nJobsT3In =
            COALESCE(COUNT(1), 0),
        @nJobsRunning =
            COALESCE(SUM(IsRunnable), 0)
    FROM JobInfo;

    /*
        Lógica original preservada:

        IF nJobsT3In = 0:
            IF nCompT3In = 0 => YES
            ELSE IF nCompRunning > 0 => NO

        ELSE:
            IF nJobsRunning > 0 => NO

        Nota:
        El Oracle tiene una condición redundante dentro del ELSE:
            IF (nJobsT3In = 0)
        Esa condición nunca será verdadera dentro del ELSE.
    */
    IF (@nJobsT3In = 0)
    BEGIN
        IF (@nCompT3In = 0)
        BEGIN
            SET @sReturn = 'YES';
        END
        ELSE IF (@nCompRunning > 0)
        BEGIN
            SET @sReturn = 'NO';
        END
    END
    ELSE
    BEGIN
        IF (@nJobsRunning > 0)
        BEGIN
            SET @sReturn = 'NO';
        END
    END;

    RETURN @sReturn;
END;
GO