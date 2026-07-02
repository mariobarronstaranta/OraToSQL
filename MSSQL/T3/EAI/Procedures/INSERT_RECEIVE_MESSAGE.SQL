CREATE PROCEDURE dbo.INSERT_RECEIVE_MESSAGE
(
      @v_MESSAGE     VARCHAR(MAX),
      @v_QUEUE_NAME  VARCHAR(500)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sMsg NVARCHAR(500);
    DECLARE @sRow_ID VARCHAR(32);
    DECLARE @sXML XML;
    DECLARE @sQueueNameReplicate VARCHAR(500);

    BEGIN TRY

        BEGIN TRAN;

        -- Conversión XML
        SET @sXML = TRY_CAST(@v_MESSAGE AS XML);

        SET @sQueueNameReplicate = @v_QUEUE_NAME;

        IF (@sQueueNameReplicate = 'Customer ERP No')
            SET @sQueueNameReplicate = 'Customer ERP No for T3';

        ELSE IF (@sQueueNameReplicate = 'Product Master')
            SET @sQueueNameReplicate = 'Product Master for T3';

        -- Generación de ID equivalente Oracle
        SET @sRow_ID =
            FORMAT(SYSDATETIME(),'yyyyMMddHHmmssffff');

        INSERT INTO EAI_OWNER.dbo.MX_RECEIVE_MESSAGE_LOG
        (
            ROW_ID,
            CREATED,
            XML_CONTENT,
            QUEUE_NAME,
            STATUS
        )
        VALUES
        (
            @sRow_ID,
            GETDATE(),
            @sXML,
            @v_QUEUE_NAME,
            'Received'
        );

        IF (@sQueueNameReplicate <> @v_QUEUE_NAME)
        BEGIN

            SET @sRow_ID =
                FORMAT(SYSDATETIME(),'yyyyMMddHHmmssffff');

            INSERT INTO EAI_OWNER.dbo.MX_RECEIVE_MESSAGE_LOG
            (
                ROW_ID,
                CREATED,
                XML_CONTENT,
                QUEUE_NAME,
                STATUS
            )
            VALUES
            (
                @sRow_ID,
                GETDATE(),
                @sXML,
                @sQueueNameReplicate,
                'Received'
            );
        END

        COMMIT TRAN;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.dbo.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
            CREATED,
            MESSAGE,
            REFERENCE,
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
            'Receive',
            NULL,
            GETDATE(),
            @v_MESSAGE,
            NULL,
            'Error',
            @v_QUEUE_NAME,
            @sMsg,
            'T-SQL',
            NULL,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END;
GO
