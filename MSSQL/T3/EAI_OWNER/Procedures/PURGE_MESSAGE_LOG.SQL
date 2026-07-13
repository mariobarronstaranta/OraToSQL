CREATE OR ALTER PROCEDURE [EAI_OWNER].[PURGE_MESSAGE_LOG]
(
    @sDirection VARCHAR(50),
    @sStatus    VARCHAR(50),
    @dtBegin    DATETIME,
    @dtEnd      DATETIME,
    @sLogging   VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg       VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @sStage     VARCHAR(40) = 'MX_EAI_MESSAGE_LOG',
        @sPeriod    VARCHAR(100),
        @nSequence  BIGINT,
        @nRecords   INT,
        @dtStarting DATETIME = GETDATE(),
        @nDays      INT;

    /*
        Developer notes
        ---------------
        Oracle original:
            - Calcula una etiqueta de periodo.
            - Purga EAI_OWNER.MX_EAI_MESSAGE_LOG por Created, Direction y Status.
            - Usa 'Both' como comodin para Direction y Status.
            - Si sLogging = 'Yes', registra en MX_PURGE_LEGDB_LOG.
            - Despues del COMMIT ejecuta dbms_stats.gather_table_stats.
            - En error hace ROLLBACK, registra en MX_EAI_MESSAGE_LOG y no relanza.

        Traduccion SQL Server:
            - TRUNC(Created) BETWEEN dtBegin AND dtEnd se implementa comparando
              CAST(Created AS DATE) contra CAST(@dtBegin/@dtEnd AS DATE).
            - SQL%ROWCOUNT se toma con @@ROWCOUNT inmediatamente despues del DELETE.
            - dbms_stats.gather_table_stats se aproxima con UPDATE STATISTICS.
    */

    SET @nDays = DATEDIFF(DAY, CAST(@dtBegin AS DATE), CAST(@dtEnd AS DATE));

    IF @nDays >= 1
    BEGIN
        SET @sPeriod =
              LEFT(CONVERT(CHAR(10), @dtBegin, 104), 5)
            + ' to '
            + LEFT(CONVERT(CHAR(10), @dtEnd, 104), 5);
    END
    ELSE
    BEGIN
        SET @sPeriod =
              LEFT(CONVERT(CHAR(8), @dtBegin, 108), 5)
            + ' - '
            + LEFT(CONVERT(CHAR(8), @dtEnd, 108), 5);
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

            IF @sDirection = 'Both'
            BEGIN
                IF @sStatus = 'Both'
                BEGIN
                    DELETE FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                    WHERE CAST(Created AS DATE) BETWEEN CAST(@dtBegin AS DATE) AND CAST(@dtEnd AS DATE);

                    SET @nRecords = @@ROWCOUNT;
                    SET @sPeriod = 'Purge : [ ' + @sPeriod + ' ]';
                END
                ELSE
                BEGIN
                    DELETE FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                    WHERE CAST(Created AS DATE) BETWEEN CAST(@dtBegin AS DATE) AND CAST(@dtEnd AS DATE)
                      AND Status = @sStatus;

                    SET @nRecords = @@ROWCOUNT;
                    SET @sPeriod = @sStatus + ' : [ ' + @sPeriod + ' ]';
                END;
            END
            ELSE
            BEGIN
                IF @sStatus = 'Both'
                BEGIN
                    DELETE FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                    WHERE CAST(Created AS DATE) BETWEEN CAST(@dtBegin AS DATE) AND CAST(@dtEnd AS DATE)
                      AND Direction = @sDirection;

                    SET @nRecords = @@ROWCOUNT;
                    SET @sPeriod = @sDirection + ' : [ ' + @sPeriod + ' ]';
                END
                ELSE
                BEGIN
                    DELETE FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                    WHERE CAST(Created AS DATE) BETWEEN CAST(@dtBegin AS DATE) AND CAST(@dtEnd AS DATE)
                      AND Direction = @sDirection
                      AND Status = @sStatus;

                    SET @nRecords = @@ROWCOUNT;
                    SET @sPeriod = @sDirection + '/' + @sStatus + ' : [ ' + @sPeriod + ' ]';
                END;
            END;

            IF @sLogging = 'Yes'
            BEGIN
                SET @nSequence = NEXT VALUE FOR [EAI_OWNER].[Seq_Purge_LEGDB];

                INSERT INTO [EAI_OWNER].[MX_PURGE_LEGDB_LOG]
                (
                    PID,
                    Time_Window,
                    Process,
                    Starting,
                    Ending,
                    Records
                )
                VALUES
                (
                    @nSequence,
                    @sStage,
                    @sPeriod,
                    @dtStarting,
                    GETDATE(),
                    @nRecords
                );
            END;

        COMMIT TRANSACTION;

        /*
            Equivalente de dbms_stats.gather_table_stats.
            Se ejecuta despues del commit como en Oracle.
        */
        UPDATE STATISTICS [EAI_OWNER].[MX_EAI_MESSAGE_LOG];
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = 'SQL-' + CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(20), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            ID,
            CREATED,
            MESSAGE,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Purge',
            NULL,
            GETDATE(),
            NULL,
            'Error',
            @sStage,
            @sMsg,
            'Purge',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Se conserva el comportamiento Oracle: registrar el error y no relanzar.
    END CATCH;
END;
GO
