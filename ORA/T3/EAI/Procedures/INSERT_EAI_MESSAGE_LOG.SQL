CREATE PROCEDURE dbo.INSERT_EAI_MESSAGE_LOG
(
      @v_DIRECTION            VARCHAR(255)
    , @v_ID                   VARCHAR(255)
    , @v_MESSAGE              VARCHAR(MAX)
    , @v_STATUS               VARCHAR(255)
    , @v_QUEUE_NAME           VARCHAR(255)
    , @v_SIEBEL_ERROR_MESSAGE VARCHAR(4000)
    , @v_SOURCE               VARCHAR(255)
    , @v_SIEBEL_ERROR_CODE    VARCHAR(255)
    , @v_RETRY_COUNT          NUMERIC(18,0)
    , @v_SEQUENCE             NUMERIC(18,0)
    , @v_PARENT_ROW_ID        VARCHAR(255)
    , @v_REFERENCE            VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        INSERT INTO EAI_OWNER.dbo.MX_EAI_MESSAGE_LOG
        (
              DIRECTION
            , ID
            , CREATED
            , MESSAGE
            , REFERENCE
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
              @v_DIRECTION
            , @v_ID
            , GETDATE()
            , @v_MESSAGE
            , @v_REFERENCE
            , @v_STATUS
            , @v_QUEUE_NAME
            , @v_SIEBEL_ERROR_MESSAGE
            , @v_SOURCE
            , @v_SIEBEL_ERROR_CODE
            , @v_RETRY_COUNT
            , @v_SEQUENCE
            , @v_PARENT_ROW_ID
        );

    END TRY
    BEGIN CATCH

        DECLARE @sMsg VARCHAR(250);

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-'
                + ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.dbo.MX_EAI_MESSAGE_LOG
        (
              DIRECTION
            , ID
            , CREATED
            , MESSAGE
            , REFERENCE
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
              @v_DIRECTION
            , @v_ID
            , GETDATE()
            , @sMsg
            , @v_REFERENCE
            , @v_STATUS
            , @v_QUEUE_NAME
            , NULL
            , 'T-SQL'
            , @v_SIEBEL_ERROR_CODE
            , @v_RETRY_COUNT
            , @v_SEQUENCE
            , @v_PARENT_ROW_ID
        );

    END CATCH
END;
GO
