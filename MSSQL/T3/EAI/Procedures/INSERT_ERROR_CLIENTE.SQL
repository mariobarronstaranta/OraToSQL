CREATE OR ALTER PROCEDURE dbo.INSERT_ERROR_CLIENTE
(
      @pCliente_V3    VARCHAR(100),
      @pCliente_SAP   VARCHAR(100),
      @pErr_Msg       VARCHAR(500)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        INSERT INTO dbo.CUSTOMERS_T3_ERROR_LOG
        (
            Cust_ID,
            SAP_Number,
            Err_Description,
            [SYSTEM],
            LOG_DATE
        )
        VALUES
        (
            @pCliente_V3,
            @pCliente_SAP,
            @pErr_Msg,
            'XML',
            SYSDATETIME()
        );

    END TRY
    BEGIN CATCH

        INSERT INTO dbo.DEBUG_T3
        (
            Fecha,
            Factura,
            Pedido,
            Cliente_SAP,
            Comentario
        )
        VALUES
        (
            SYSDATETIME(),
            'ErrCliente',
            @pCliente_V3,
            LEFT(@pCliente_SAP,10),
            CONCAT(
                'Error:',
                ERROR_NUMBER(),
                ' Proc:',
                COALESCE(ERROR_PROCEDURE(),'N/A'),
                ' Line:',
                ERROR_LINE(),
                ' Msg:',
                ERROR_MESSAGE()
            )
        );

    END CATCH
END;
GO
