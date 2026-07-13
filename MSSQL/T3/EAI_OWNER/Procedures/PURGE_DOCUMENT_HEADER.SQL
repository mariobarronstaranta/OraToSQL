CREATE OR ALTER PROCEDURE [EAI_OWNER].[PURGE_DOCUMENT_HEADER]
(
    @sPrefix         VARCHAR(50),
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
        Oracle original purga por ventanas de N dias:
            nPeriod    := NVL(nDiasIntervalo, 7)
            dtStarting := dtStartingPurge - nPeriod
            LOOP
                dtStarting := dtStarting + nPeriod
                dtEnding   := MIN(dtStarting + nPeriod, dtEndingPurge)
                TRUNC(dtStarting/dtEnding)
                ...
            END LOOP

        Reglas conservadas:
            - Se borran primero hijos:
                tmp_Document_Detail
                tmp_Document_Detail_Cond
                tmp_Document_Partners
              y al final tmp_Document_Header.
            - La seleccion de headers usa:
                DocumentDate LIKE sPrefix || '%'
                TRUNC(Created) BETWEEN dtStarting AND dtEnding
            - Procesado IS NOT NULL sigue comentado, como en Oracle.
            - Records en MX_PURGE_LEGDB_LOG corresponde solo al DELETE de
              tmp_Document_Header, porque Oracle usa SQL%ROWCOUNT despues de
              ese DELETE.
            - Cada ventana hace COMMIT independiente.
            - En error se registra MX_EAI_MESSAGE_LOG y no se relanza.
    */

    BEGIN TRY
        SET @nPeriod = ISNULL(@nDiasIntervalo, 7);

        IF @nPeriod <= 0
            THROW 51000, 'nDiasIntervalo debe ser mayor a cero.', 1;

        SET @nIteracion = 0;
        SET @dtStarting = DATEADD(DAY, -@nPeriod, @dtStartingPurge);

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
            SET @sStage = 'DOCUMENT_HEADER';

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

                IF OBJECT_ID('tempdb..#HeadersToPurge') IS NOT NULL
                    DROP TABLE #HeadersToPurge;

                SELECT DISTINCT
                    Header.ReferenceID
                INTO #HeadersToPurge
                FROM [EAI_OWNER].[tmp_Document_Header] AS Header
                WHERE Header.DocumentDate LIKE @sPrefix + '%'
                  -- AND Header.Procesado IS NOT NULL
                  AND CAST(Header.Created AS DATE) BETWEEN @dtStarting AND @dtEnding;

                DELETE Detail
                FROM [EAI_OWNER].[tmp_Document_Detail] AS Detail
                INNER JOIN #HeadersToPurge AS Purge
                    ON Purge.ReferenceID = Detail.ReferenceID;

                DELETE DetailCond
                FROM [EAI_OWNER].[tmp_Document_Detail_Cond] AS DetailCond
                INNER JOIN #HeadersToPurge AS Purge
                    ON Purge.ReferenceID = DetailCond.ReferenceID;

                DELETE Partners
                FROM [EAI_OWNER].[tmp_Document_Partners] AS Partners
                INNER JOIN #HeadersToPurge AS Purge
                    ON Purge.ReferenceID = Partners.ReferenceID;

                DELETE Header
                FROM [EAI_OWNER].[tmp_Document_Header] AS Header
                INNER JOIN #HeadersToPurge AS Purge
                    ON Purge.ReferenceID = Header.ReferenceID;

                SET @nRecords = @@ROWCOUNT;

                UPDATE [EAI_OWNER].[MX_PURGE_LEGDB_LOG]
                   SET Ending = GETDATE(),
                       Records = @nRecords
                 WHERE PID = @nSequence;

            COMMIT TRANSACTION;
        END;
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
            'Document_Header',
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
