CREATE OR ALTER PROCEDURE [EAI_OWNER].[LOG_START]
(
    @nComponent INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET [Status]  = 2,
               [Last_Run] = SYSDATETIME()
         WHERE [Component] = @nComponent;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO