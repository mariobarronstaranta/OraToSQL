CREATE OR ALTER PROCEDURE EAI_OWNER.WA_CIERRE_FLUJOS
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        EXEC EAI_OWNER.Job_Manage
             @sAction = 'Suspend',
             @sType   = 'Todos';

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        DECLARE @ErrorMessage  NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorNumber   INT            = ERROR_NUMBER();
        DECLARE @ErrorSeverity INT            = ERROR_SEVERITY();
        DECLARE @ErrorState    INT            = ERROR_STATE();
        DECLARE @ErrorLine     INT            = ERROR_LINE();
        DECLARE @ErrorProc     SYSNAME        = ISNULL(ERROR_PROCEDURE(), 'EAI_OWNER.WA_CIERRE_FLUJOS');

        RAISERROR(
            'Error en %s. Number: %d, Line: %d, Message: %s',
            @ErrorSeverity,
            @ErrorState,
            @ErrorProc,
            @ErrorNumber,
            @ErrorLine,
            @ErrorMessage
        );
    END CATCH;
END;
GO