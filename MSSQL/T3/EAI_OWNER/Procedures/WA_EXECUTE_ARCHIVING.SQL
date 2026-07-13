CREATE OR ALTER PROCEDURE dbo.WA_EXECUTE_ARCHIVING
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedTransaction BIT = 0;

    BEGIN TRY

        IF @@TRANCOUNT = 0
        BEGIN
            SET @StartedTransaction = 1;
            BEGIN TRANSACTION;
        END;

        EXEC [T3].[ARCHIVING_T3]
             @pFechaInicial = DATEFROMPARTS(2019, 1, 1),
             @pFechaFinal   = DATEFROMPARTS(2020, 12, 31),
             @pParametro    = 16;

        IF @StartedTransaction = 1
        BEGIN
            COMMIT TRANSACTION;
        END;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0 AND @StartedTransaction = 1
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrorNumber    INT           = ERROR_NUMBER();
        DECLARE @ErrorSeverity  INT           = ERROR_SEVERITY();
        DECLARE @ErrorState     INT           = ERROR_STATE();
        DECLARE @ErrorProcedure NVARCHAR(128) = COALESCE(ERROR_PROCEDURE(), N'WA_EXECUTE_ARCHIVING');
        DECLARE @ErrorLine      INT           = ERROR_LINE();
        DECLARE @ErrorMessage   NVARCHAR(4000) = ERROR_MESSAGE();

        /*
            Opcional:
            Insertar aquí en una tabla estándar de logging si existe, por ejemplo:

            INSERT INTO dbo.Log_Errores
            (
                Procedimiento,
                ErrorNumber,
                ErrorSeverity,
                ErrorState,
                ErrorLine,
                ErrorMessage,
                FechaError
            )
            VALUES
            (
                @ErrorProcedure,
                @ErrorNumber,
                @ErrorSeverity,
                @ErrorState,
                @ErrorLine,
                @ErrorMessage,
                SYSDATETIME()
            );
        */

        THROW;

    END CATCH;
END;
GO