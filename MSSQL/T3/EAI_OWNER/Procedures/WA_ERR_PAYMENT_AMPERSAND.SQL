CREATE OR ALTER PROCEDURE dbo.WA_ERR_PAYMENT_AMPERSAND
(
      @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg VARCHAR(300),
        @nPedidos INT = 0;

    BEGIN TRY

        BEGIN TRAN;

        ;WITH Errores AS
        (
            SELECT
                ROW_NUMBER() OVER
                (
                    ORDER BY Created
                ) AS Seq,

                PK_ID,                 -- Sustituir por la PK real
                Queue_Name,
                Created,

                REPLACE(SUBSTRING(Message,1,3900),'&','y') AS Fase1,
                REPLACE(SUBSTRING(Message,3901,3900),'&','y') AS Fase2,
                REPLACE(SUBSTRING(Message,7801,3900),'&','y') AS Fase3,
                REPLACE(SUBSTRING(Message,11701,3900),'&','y') AS Fase4,
                REPLACE(SUBSTRING(Message,15601,3900),'&','y') AS Fase5,

                CAST(SUBSTRING(Message,1,2000) AS VARCHAR(2000)) AS Msg,

                CHARINDEX(
                    '</DocumentType>',
                    SUBSTRING(Message,1,2000)
                ) AS CloseDocType
            FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE Queue_Name='Payment'
            AND Direction='Receive'
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created > DATEADD(DAY,-@pDias,CAST(GETDATE() AS DATE))
        ),
        Datos AS
        (
            SELECT
                FORMAT(GETDATE(),'yyyyMMddHHmmss')
                + RIGHT('00000000'+CAST(Seq AS VARCHAR(8)),8)
                AS Row_ID,

                PK_ID,
                Queue_Name,
                GETDATE() AS Created,

                CONCAT
                (
                    Fase1,
                    Fase2,
                    Fase3,
                    Fase4,
                    Fase5
                ) AS XML_Content,

                CASE
                    WHEN CloseDocType > 0
                    THEN SUBSTRING(Msg,CloseDocType-2,2)
                    ELSE '  '
                END AS DocumentType
            FROM Errores
        )

        INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
        (
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        )
        SELECT
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        FROM Datos
        WHERE DocumentType IN ('ZV','CR');

        SET @nPedidos = @@ROWCOUNT;

        UPDATE L
        SET Status='Reprocess'
        FROM EAI_OWNER.MX_EAI_MESSAGE_LOG L
        INNER JOIN Datos D
            ON L.PK_ID = D.PK_ID
        WHERE D.DocumentType IN ('ZV','CR');

        COMMIT;

        PRINT 'Documentos -> '
            + CAST(@nPedidos AS VARCHAR(20));

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR);

        SET @sMsg =
            LEFT(ERROR_MESSAGE(),250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
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
            'WA Payment',
            NULL,
            GETDATE(),
            NULL,
            'Error',
            'WA_ERR_PAYMENT',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;
    END CATCH
END
GO