CREATE OR ALTER PROCEDURE EAI_OWNER.PURGE_ACCOUNT_HEADER
(
      @dtStartingPurge DATE
    , @dtEndingPurge   DATE
    , @nDiasIntervalo  INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @dtStarting DATE
        , @dtEnding DATE
        , @nIteracion INT
        , @nPeriod INT
        , @nSequence BIGINT
        , @nRecords INT
        , @sPeriod VARCHAR(20)
        , @sStage VARCHAR(40)
        , @sMsg VARCHAR(500)
        , @sErrorCode VARCHAR(20);

    BEGIN TRY

        SET @nPeriod = COALESCE(@nDiasIntervalo, 7);
        SET @nIteracion = 0;
        SET @dtStarting = DATEADD(DAY,-@nPeriod,@dtStartingPurge);

        WHILE (1 = 1)
        BEGIN

            SET @dtStarting = DATEADD(DAY,@nPeriod,@dtStarting);

            IF (@dtStarting > @dtEndingPurge)
                BREAK;

            SET @dtEnding = DATEADD(DAY,@nPeriod,@dtStarting);

            IF (@dtEnding > @dtEndingPurge)
                SET @dtEnding = @dtEndingPurge;

            SET @nIteracion += 1;

            SET @sPeriod =
                CONVERT(VARCHAR(8),@dtStarting,112)
                + '-'
                + CONVERT(VARCHAR(8),@dtEnding,112);

            SET @sStage = 'ACCOUNT_HEADER';

            SET @nSequence =
                NEXT VALUE FOR dbo.Seq_Purge_LEGDB;

            INSERT INTO EAI_OWNER.MX_PURGE_LEGDB_LOG
            (
                  PID
                , Time_Window
                , Process
                , Starting
                , Ending
            )
            VALUES
            (
                  @nSequence
                , @sPeriod
                , @sStage
                , GETDATE()
                , NULL
            );

            DELETE FROM EAI_OWNER.TMP_ACCOUNT_HEADER
            WHERE Created >= @dtStarting
              AND Created < DATEADD(DAY,1,@dtEnding);

            SET @nRecords = @@ROWCOUNT;

            UPDATE EAI_OWNER.MX_PURGE_LEGDB_LOG
               SET Ending  = GETDATE(),
                   Records = @nRecords
             WHERE PID = @nSequence;

            COMMIT TRANSACTION;
        END;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
              DIRECTION
            , ID
            , CREATED
            , MESSAGE
            , STATUS
            , QUEUE_NAME
            , SIEBEL_ERROR_MESSAGE
            , SOURCE
            , SIEBEL_ERROR_CODE
            , RETRY_COUNT
            , SEQUENCE
            , PARENT_ROW_ID
        )
        VALUES
        (
              'Purge'
            , NULL
            , GETDATE()
            , NULL
            , 'Error'
            , 'Account_Header'
            , @sMsg
            , 'Purge'
            , @sErrorCode
            , NULL
            , NULL
            , NULL
        );

    END CATCH
END;
GO