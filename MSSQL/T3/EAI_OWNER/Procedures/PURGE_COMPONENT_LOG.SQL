CREATE OR ALTER PROCEDURE [EAI_OWNER].[PURGE_COMPONENT_LOG]
(
    @sStatus  VARCHAR(50),
    @dtBegin  DATETIME,
    @dtEnd    DATETIME,
    @sLogging VARCHAR(10)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg       VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @sStage     VARCHAR(40) = 'MX_COMPONENT_LOG',
        @sPeriod    VARCHAR(100),
        @nSequence  BIGINT,
        @nRecords   INT,
        @dtStarting DATETIME = GETDATE(),
        @nDays      INT;

    /*
        Developer notes
        ---------------
        Oracle original:
            - Calcula una etiqueta de periodo segun el rango recibido.
            - Si sStatus = 'All', purga todo MX_Component_Log entre dtBegin/dtEnd.
            - Si sStatus <> 'All', purga solo registros no procesados
              (Processed = 0) dentro del mismo rango.
            - Si sLogging = 'Yes', registra la purga en MX_PURGE_LEGDB_LOG.
            - En error, hace ROLLBACK, registra en MX_EAI_MESSAGE_LOG y termina
              sin relanzar la excepcion.

        Traduccion SQL Server:
            - TRUNC(dtEnd) - TRUNC(dtBegin) se replica con DATEDIFF sobre DATE.
            - TO_CHAR(..., 'DD.MM') se replica con estilo 104 y LEFT(5).
            - TO_CHAR(..., 'HH24:MI') se replica con estilo 108 y LEFT(5).
            - SQL%ROWCOUNT se replica con @@ROWCOUNT inmediatamente despues
              del DELETE.
    */

    SET @nDays = DATEDIFF(DAY, CAST(@dtBegin AS DATE), CAST(@dtEnd AS DATE));

    IF @nDays >= 2
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

            IF @sStatus = 'All'
            BEGIN
                DELETE FROM [EAI_OWNER].[MX_COMPONENT_LOG]
                WHERE [Starting] BETWEEN @dtBegin AND @dtEnd;

                SET @nRecords = @@ROWCOUNT;
                SET @sPeriod = 'Purge : [ ' + @sPeriod + ' ]';
            END
            ELSE
            BEGIN
                DELETE FROM [EAI_OWNER].[MX_COMPONENT_LOG]
                WHERE [Starting] BETWEEN @dtBegin AND @dtEnd
                  AND [Processed] = 0;

                SET @nRecords = @@ROWCOUNT;
                SET @sPeriod = 'None Processed : [ ' + @sPeriod + ' ]';
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
