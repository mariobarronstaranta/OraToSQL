CREATE OR ALTER PROCEDURE EAI.INSERT_ERR_CLIENTE
(
      @Cliente_V3      VARCHAR(255)
    , @Cliente_SAP     VARCHAR(255)
    , @Distribuidora   VARCHAR(255)
    , @Err_Msg         VARCHAR(500)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF NOT EXISTS
        (
            SELECT 1
            FROM EAI.CUSTOMERS_T3_ERROR_LOG
            WHERE CUST_ID = @Cliente_V3
              --AND CTRO = @Distribuidora
              AND RTRIM(ERR_DESCRIPTION) = RTRIM(@Err_Msg)
        )
        BEGIN

            INSERT INTO EAI.CUSTOMERS_T3_ERROR_LOG
            (
                  Cust_ID
                , SAP_Number
                , Ctro
                , Err_Description
                , [SYSTEM]
                , LOG_DATE
            )
            VALUES
            (
                  @Cliente_V3
                , @Cliente_SAP
                , @Distribuidora
                , @Err_Msg
                , 'XML'
                , SYSDATETIME()
            );

        END
        ELSE
        BEGIN

            UPDATE EAI.CUSTOMERS_T3_ERROR_LOG
               SET LOG_DATE = SYSDATETIME(),
                   CTRO     = @Distribuidora
             WHERE CUST_ID = @Cliente_V3
               --AND CTRO = @Distribuidora
               AND RTRIM(ERR_DESCRIPTION) = RTRIM(@Err_Msg);

        END

    END TRY
    BEGIN CATCH

        DECLARE @sMsg VARCHAR(250);

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE()
            ,250);

        BEGIN TRY

            INSERT INTO EAI.DEBUG_T3
            (
                  Fecha
                , Factura
                , Pedido
                , Cliente_SAP
                , Comentario
            )
            VALUES
            (
                  SYSDATETIME()
                , 'ErrCliente'
                , @Cliente_V3
                , LEFT(@Cliente_SAP,10)
                , @sMsg
            );

        END TRY
        BEGIN CATCH
            -- Evita que falle el logging
        END CATCH;

    END CATCH
END
GO
