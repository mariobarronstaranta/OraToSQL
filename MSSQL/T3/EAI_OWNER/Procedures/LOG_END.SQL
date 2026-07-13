CREATE OR ALTER PROCEDURE EAI_OWNER.LOG_END
(
      @nComponent BIGINT
    , @dtBegin    DATETIME2(0)
    , @dtEnd      DATETIME2(0)
    , @nRecords   BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
         WHERE Component = @nComponent;

        INSERT INTO EAI_OWNER.MX_COMPONENT_LOG
        (
              Component
            , PID
            , Starting
            , Ending
            , Processed
        )
        VALUES
        (
              @nComponent
            , NEXT VALUE FOR dbo.ProcessID
            , @dtBegin
            , @dtEnd
            , @nRecords
        );

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH
END;
GO