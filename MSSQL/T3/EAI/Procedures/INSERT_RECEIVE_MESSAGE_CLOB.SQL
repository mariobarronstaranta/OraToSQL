CREATE PROCEDURE EAI.INSERT_RECEIVE_MESSAGE_CLOB
(
      @v_MESSAGE     VARCHAR(MAX),
      @v_QUEUE_NAME  VARCHAR(500)
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @sMsg                VARCHAR(500);
    DECLARE @sRow_ID             VARCHAR(32);
    DECLARE @sXML                XML;
    DECLARE @sQueueNameReplicate VARCHAR(500);

    BEGIN TRY

        ------------------------------------------------------------------
        -- Validación XML
        ------------------------------------------------------------------

        SET @sXML = CAST(@v_MESSAGE AS XML);

        SET @sQueueNameReplicate = @v_QUEUE_NAME;

        IF @sQueueNameReplicate = 'Customer ERP No'
            SET @sQueueNameReplicate = 'Customer ERP No for T3';

        ELSE IF @sQueueNameReplicate = 'Product Master'
            SET @sQueueNameReplicate = 'Product Master for T3';

        ------------------------------------------------------------------
        -- Inserción principal
        ------------------------------------------------------------------

        SET @sRow_ID =
            REPLACE(CONVERT(VARCHAR(23),SYSDATETIME(),121),'-','')
            + REPLACE(CONVERT(VARCHAR(12),SYSDATETIME(),114),':','');

        INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
        (
            ROW_ID,
            CREATED,
            XML_CONTENT,
            QUEUE_NAME,
            STATUS
        )
        VALUES
        (
            LEFT(@sRow_ID,32),
            GETDATE(),
            @sXML,
            @v_QUEUE_NAME,
            'Received'
        );

        ------------------------------------------------------------------
        -- Replica T3
        ------------------------------------------------------------------

        IF (@sQueueNameReplicate <> @v_QUEUE_NAME)
        BEGIN

            SET @sRow_ID =
                REPLACE(CONVERT(VARCHAR(23),SYSDATETIME(),121),'-','')
                + REPLACE(CONVERT(VARCHAR(12),SYSDATETIME(),114),':','');

            INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
            (
                ROW_ID,
                CREATED,
                XML_CONTENT,
                QUEUE_NAME,
                STATUS
            )
            VALUES
            (
                LEFT(@sRow_ID,32),
                GETDATE(),
                @sXML,
                @sQueueNameReplicate,
                'Received'
            );

        END

    END TRY
    BEGIN CATCH

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-'
                + ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            'TSQL',
            NULL,
            NULL,
            NULL,
            NULL
        );

    END CATCH

END
GO
