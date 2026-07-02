CREATE OR ALTER PROCEDURE dbo.WA_ENABLE_REMISION_OBD
(
    @sCustomerSAP VARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sCustomer VARCHAR(20),
        @sMsg NVARCHAR(500);

    BEGIN TRY

        ------------------------------------------------------------------
        -- Equivalente Oracle LPAD
        ------------------------------------------------------------------
        SET @sCustomer =
            RIGHT(REPLICATE('0',10) + @sCustomerSAP,10);

        BEGIN TRANSACTION;

        ------------------------------------------------------------------
        -- Verificar existencia
        ------------------------------------------------------------------
        IF NOT EXISTS
        (
            SELECT 1
            FROM EAI_Owner.dbo.MX_Hashtable
            WHERE [Type] = 'Genera Remision'
              AND [Source] = @sCustomer
        )
        BEGIN

            --------------------------------------------------------------
            -- Alta configuración
            --------------------------------------------------------------
            INSERT INTO EAI_Owner.dbo.MX_Hashtable
            (
                [Type],
                [Source],
                Target
            )
            VALUES
            (
                'Genera Remision',
                @sCustomer,
                'OBD'
            );

            --------------------------------------------------------------
            -- Auditoría
            --------------------------------------------------------------
            INSERT INTO EAI_Owner.dbo.WA_Logging
            (
                Fecha,
                Usuario,
                Usuario_Red,
                IP,
                Terminal,
                Documento,
                Comentario
            )
            VALUES
            (
                GETDATE(),
                SUSER_SNAME(),
                ORIGINAL_LOGIN(),
                CAST(CONNECTIONPROPERTY('client_net_address') AS VARCHAR(50)),
                HOST_NAME(),
                @sCustomer,
                'WA_ENABLING_OBD'
            );

        END

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sMsg =
            LEFT(
                CONCAT(
                    'ERROR SQL SERVER ',
                    ERROR_NUMBER(),
                    ' ',
                    ERROR_MESSAGE()
                ),
                480
            );

        ------------------------------------------------------------------
        -- Recomendado: registrar error
        ------------------------------------------------------------------
        PRINT '************* Mensaje *******************';
        PRINT '*** Error en WA_ENABLE_REMISION_OBD ***';
        PRINT @sMsg;

        THROW;

    END CATCH
END
GO