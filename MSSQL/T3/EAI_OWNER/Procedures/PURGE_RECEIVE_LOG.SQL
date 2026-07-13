CREATE OR ALTER PROCEDURE [EAI_OWNER].[PURGE_RECEIVE_LOG]
(
    @dtStartingPurge DATE,
    @dtEndingPurge   DATE,
    @nDiasIntervalo  INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @dtStarting DATE,
        @dtEnding   DATE,
        @nIteracion INT,
        @nPeriod    INT,
        @nSequence  BIGINT,
        @nRecords   INT,
        @sPeriod    VARCHAR(20),
        @sStage     VARCHAR(40),
        @sMsg       VARCHAR(500),
        @sErrorCode VARCHAR(20);

    /*
        Developer notes
        ---------------
        Oracle original purga EAI_OWNER.MX_RECEIVE_MESSAGE_LOG por ventanas:
            nPeriod    := NVL(nDiasIntervalo, 7)
            dtStarting := dtStartingPurge - nPeriod
            LOOP
                dtStarting := dtStarting + nPeriod
                dtEnding   := MIN(dtStarting + nPeriod, dtEndingPurge)
                DELETE WHERE TRUNC(Created) BETWEEN dtStarting AND dtEnding
                COMMIT
            END LOOP

        Reglas conservadas:
            - Default de intervalo: 7 dias.
            - Cada ventana registra inicio/fin en MX_PURGE_LEGDB_LOG.
            - Records corresponde al DELETE de MX_RECEIVE_MESSAGE_LOG.
            - Cada ventana hace commit independiente.
            - Al final se actualizan estadisticas, equivalente a
              dbms_stats.gather_table_stats.
            - En error se hace rollback, se registra en MX_EAI_MESSAGE_LOG y no
              se relanza la excepcion, igual que Oracle.
    */

    BEGIN TRY
        SET @nPeriod = ISNULL(@nDiasIntervalo, 7);

        IF @nPeriod <= 0
            THROW 51000, 'nDiasIntervalo debe ser mayor a cero.', 1;

        SET @nIteracion = 0;
        SET @dtStarting = DATEADD(DAY, -@nPeriod, @dtStartingPurge);
        SET @sStage = 'MX_RECEIVE_MESSAGE_LOG';

        WHILE 1 = 1
        BEGIN
            SET @dtStarting = DATEADD(DAY, @nPeriod, @dtStarting);

            IF @dtStarting > @dtEndingPurge
                BREAK;

            SET @dtEnding = DATEADD(DAY, @nPeriod, @dtStarting);

            IF @dtEnding > @dtEndingPurge
                SET @dtEnding = @dtEndingPurge;

            SET @nIteracion += 1;
            SET @dtStarting = CAST(@dtStarting AS DATE);
            SET @dtEnding = CAST(@dtEnding AS DATE);
            SET @sPeriod = CONVERT(CHAR(8), @dtStarting, 112) + '-' + CONVERT(CHAR(8), @dtEnding, 112);

            BEGIN TRANSACTION;

                SET @nSequence = NEXT VALUE FOR [EAI_OWNER].[Seq_Purge_LEGDB];

                INSERT INTO [EAI_OWNER].[MX_PURGE_LEGDB_LOG]
                (
                    PID,
                    Time_Window,
                    Process,
                    Starting,
                    Ending
                )
                VALUES
                (
                    @nSequence,
                    @sPeriod,
                    @sStage,
                    GETDATE(),
                    NULL
                );

                DELETE FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                WHERE CAST(Created AS DATE) BETWEEN @dtStarting AND @dtEnding;

                SET @nRecords = @@ROWCOUNT;

                UPDATE [EAI_OWNER].[MX_PURGE_LEGDB_LOG]
                   SET Ending = GETDATE(),
                       Records = @nRecords
                 WHERE PID = @nSequence;

            COMMIT TRANSACTION;
        END;

        UPDATE STATISTICS [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG];
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
