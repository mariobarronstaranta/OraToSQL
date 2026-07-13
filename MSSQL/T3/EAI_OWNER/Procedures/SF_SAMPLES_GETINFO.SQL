CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_SAMPLES_GETINFO]
(
    @pInvoiceRef VARCHAR(50),
    @pCreditRef  VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        SF_SAMPLES_GETINFO
        ==================
        Procedimiento de diagnostico para consultar una factura y,
        opcionalmente por contenido, una nota de credito relacionada.

        Oracle escribe los valores mediante DBMS_OUTPUT. En SQL Server se
        devuelven result sets para que SSMS, una aplicacion o una prueba
        automatizada puedan consultar los mismos datos de forma estructurada.

        Aunque @pCreditRef forma parte obligatoria de la firma, la consulta de
        credito solo se ejecuta cuando su longitud es mayor que cinco, igual
        que en el procedimiento Oracle.
    */

    DECLARE @referenceDate DATE = CONVERT(DATE, GETDATE());

    BEGIN TRY

        DECLARE
            @sInvDoc_Num      VARCHAR(30),
            @sInvCliente      VARCHAR(30),
            @nInvAmount       DECIMAL(13,2),
            @nInvPending      DECIMAL(13,2),
            @nInvPaid         DECIMAL(13,2),

            @sCredDoc_Num     VARCHAR(30),
            @sCredCliente     VARCHAR(30),
            @nCredAmount      DECIMAL(13,2),
            @nCredPending     DECIMAL(13,2),
            @nCredPaid        DECIMAL(13,2),

            @sCustomer_TMD    VARCHAR(30),
            @sCtro            VARCHAR(30),
            @nDistributor     NUMERIC(4,0),
            @sRep_ID          VARCHAR(30),
            @sCustomer_Name   VARCHAR(1024);

        /*
            Paso 1: obtener datos financieros de la factura.
            Las variables se inicializan para no dejar valores indeterminados
            si el procedimiento auxiliar no localiza la referencia.
        */
        SELECT
            @sInvDoc_Num = NULL,
            @sInvCliente = NULL,
            @nInvAmount = 0,
            @nInvPending = 0,
            @nInvPaid = 0;

        EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
            @pInvoiceRef = @pInvoiceRef,
            @rtDoc_Num = @sInvDoc_Num OUTPUT,
            @rtCliente_SAP = @sInvCliente OUTPUT,
            @rtAmount = @nInvAmount OUTPUT,
            @rtPending = @nInvPending OUTPUT,
            @rtPaid = @nInvPaid OUTPUT;

        -- Paso 2: enriquecer la factura con datos del cliente a la fecha actual.
        EXEC [EAI_OWNER].[SF_GET_CUSTOMER_DATA]
            @pCustomer_SAP = @sInvCliente,
            @pDate = @referenceDate,
            @rtCustomer_TMD = @sCustomer_TMD OUTPUT,
            @rtCtro = @sCtro OUTPUT,
            @rtDistributor = @nDistributor OUTPUT,
            @rtRep_ID = @sRep_ID OUTPUT,
            @rtCustomer_Name = @sCustomer_Name OUTPUT;

        SELECT
            Tipo           = 'INVOICE',
            Documento      = @sInvDoc_Num,
            Referencia     = @pInvoiceRef,
            Cliente        = @sInvCliente,
            Amount         = @nInvAmount,
            Pending        = @nInvPending,
            Paid           = @nInvPaid,
            Customer_TMD   = @sCustomer_TMD,
            Centro         = @sCtro,
            Distribuidor   = @nDistributor,
            Rep_ID         = @sRep_ID,
            Customer_Name  = @sCustomer_Name;

        /*
            Oracle evalua LENGTH(NVL(pCreditRef, 'NULL')) > 5. NULL y cadenas
            cortas omiten completamente la consulta de nota de credito.
        */
        IF LEN(COALESCE(@pCreditRef, 'NULL')) > 5
        BEGIN
            SELECT
                @sCredDoc_Num = NULL,
                @sCredCliente = NULL,
                @nCredAmount = 0,
                @nCredPending = 0,
                @nCredPaid = 0;

            EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                @pInvoiceRef = @pCreditRef,
                @rtDoc_Num = @sCredDoc_Num OUTPUT,
                @rtCliente_SAP = @sCredCliente OUTPUT,
                @rtAmount = @nCredAmount OUTPUT,
                @rtPending = @nCredPending OUTPUT,
                @rtPaid = @nCredPaid OUTPUT;

            -- Reutilizar las variables de cliente es seguro: esta llamada las
            -- sobrescribe con los datos del cliente de la nota de credito.
            EXEC [EAI_OWNER].[SF_GET_CUSTOMER_DATA]
                @pCustomer_SAP = @sCredCliente,
                @pDate = @referenceDate,
                @rtCustomer_TMD = @sCustomer_TMD OUTPUT,
                @rtCtro = @sCtro OUTPUT,
                @rtDistributor = @nDistributor OUTPUT,
                @rtRep_ID = @sRep_ID OUTPUT,
                @rtCustomer_Name = @sCustomer_Name OUTPUT;

            SELECT
                Tipo           = 'CREDIT',
                Documento      = @sCredDoc_Num,
                Referencia     = @pCreditRef,
                Cliente        = @sCredCliente,
                Amount         = @nCredAmount,
                Pending        = @nCredPending,
                Paid           = @nCredPaid,
                Customer_TMD   = @sCustomer_TMD,
                Centro         = @sCtro,
                Distribuidor   = @nDistributor,
                Rep_ID         = @sRep_ID,
                Customer_Name  = @sCustomer_Name;
        END

    END TRY
    BEGIN CATCH
        -- El Oracle no oculta errores de sus procedimientos auxiliares. THROW
        -- conserva el numero, mensaje y linea originales de SQL Server.
        THROW;
    END CATCH
END;
GO
