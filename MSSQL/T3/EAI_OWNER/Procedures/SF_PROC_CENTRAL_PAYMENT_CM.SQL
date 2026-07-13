CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_CM]
(
    @pIDocNum VARCHAR(50)
)
AS
BEGIN

    SET NOCOUNT ON;

    /*
        SF_PROC_CENTRAL_PAYMENT_CM
        ==========================
        Procesa una asignacion de banco central que relaciona:
        - un documento de pago tipo ZV;
        - una factura por ReferenceDocNumber; y
        - una nota de credito por Reference_CreditMemo.

        El procedimiento solo crea la asignacion cuando el importe cabe tanto
        en el saldo pendiente de la factura como en el saldo pendiente de la
        nota de credito. No inserta en T3.Pago porque esa parte esta comentada
        en el fuente Oracle y, por lo tanto, no forma parte de la regla activa.
    */

    DECLARE
        @sMsg                  VARCHAR(500),
        @v_ID                  VARCHAR(30),
        @sErrorCode            VARCHAR(20),
        @sReferenceID          VARCHAR(30),
        @sProcesar             VARCHAR(20),
        @sIDocNum              VARCHAR(20),

        @sReferenceDocNumber   VARCHAR(50),
        @sNCDocNumber          VARCHAR(50),
        @sPago_Integration_ID  VARCHAR(50),
        @sPayment_Num          VARCHAR(50),
        @dtPostingDate         DATE,
        @sCustomerPayer        VARCHAR(50),
        @sIDocNumber           VARCHAR(50),
        @sPayment_Method       VARCHAR(50),

        -- El origen del importe es NUMERIC(18,4); conservar cuatro decimales
        -- evita redondear antes de comparar los saldos pendientes.
        @nAmount              DECIMAL(18,4),
        @sCustomer_TMD        VARCHAR(30),
        @sCtro                VARCHAR(4),
        @nDistributor         INT,
        @sRep_ID              VARCHAR(30),
        @sInvDoc_Num          VARCHAR(30),
        @sInvCustomer         VARCHAR(30),
        @nInvAmount           DECIMAL(15,2),
        @nInvPending          DECIMAL(15,2),
        @sNCDoc_Num           VARCHAR(30),
        @sNCCustomer          VARCHAR(30),
        @nNCAmount            DECIMAL(15,2),
        @nNCPending           DECIMAL(15,2),
        @nPaid               DECIMAL(15,2),
        @nNCPaid             DECIMAL(15,2),
        @sCustomer_Name      VARCHAR(1024);

    BEGIN TRY

        SET @sReferenceID = @pIDocNum;

        -- Los callers Oracle envian normalmente el IDoc rellenado a 16
        -- posiciones. SUBSTR(..., 7, 10) recupera el numero real de 10 digitos.
        SET @sIDocNum = SUBSTRING(@pIDocNum, 7, 10);

        SET @sProcesar =
            [EAI_OWNER].[CHK_BANKCENTRAL_ALLOC](@sIDocNum);

        IF @sProcesar <> 'NO'
        BEGIN

            /*
                ScrData de Oracle.
                LEFT JOIN conserva el encabezado aunque no tenga detalle. Si el
                detalle trae un importe positivo se usa ese valor; en caso
                contrario se usa AmountDocCurrency del encabezado.
            */
            DECLARE CurData CURSOR LOCAL FAST_FORWARD FOR

            SELECT
                CASE
                    WHEN Det.AmountInDocumentCurrency IS NULL
                        THEN COALESCE(Doc.AmountDocCurrency,0)
                    WHEN COALESCE(Det.AmountInDocumentCurrency,0) > 0
                        THEN COALESCE(Det.AmountInDocumentCurrency,0)
                END AS Amount,

                Doc.ReferenceDocNumber,

                SUBSTRING(Doc.ClearingDate,3,2) AS Fiscal_Year,

                Doc.AccntDocNumber,

                -- Estilo 112 valida estrictamente el formato YYYYMMDD.
                CONVERT(DATE, Doc.PostingDate, 112),

                Doc.CustomerNumber,
                Doc.IDocNumber,
                Doc.Reference_CreditMemo

            FROM [EAI_OWNER].[tmp_Account_Header] Doc
            LEFT JOIN [EAI_OWNER].[tmp_Account_Detail] Det
                ON Doc.IDocNumber = Det.IDocNumber
            WHERE Doc.IDocNumber = @sIDocNum
              AND Doc.DocumentType = 'ZV';

            OPEN CurData;

            DECLARE @FiscalYear VARCHAR(10);

            FETCH NEXT FROM CurData INTO
                @nAmount,
                @sReferenceDocNumber,
                @FiscalYear,
                @sPayment_Num,
                @dtPostingDate,
                @sCustomerPayer,
                @sIDocNumber,
                @sNCDocNumber;

            WHILE @@FETCH_STATUS = 0
            BEGIN

                SET @sPago_Integration_ID =
                    @FiscalYear + @sPayment_Num;

                SET @sPayment_Method = 'T';

                /*
                    Reiniciar las salidas es importante: el cursor puede tener
                    varias filas y no debemos reutilizar datos de la anterior.
                */
                SELECT
                    @sInvDoc_Num = NULL,
                    @sInvCustomer = NULL,
                    @nInvAmount = 0,
                    @nInvPending = 0,
                    @nPaid = 0,
                    @sNCDoc_Num = NULL,
                    @sNCCustomer = NULL,
                    @nNCAmount = 0,
                    @nNCPending = 0,
                    @nNCPaid = 0;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @pInvoiceRef = @sReferenceDocNumber,
                    @rtDoc_Num = @sInvDoc_Num OUTPUT,
                    @rtCliente_SAP = @sInvCustomer OUTPUT,
                    @rtAmount = @nInvAmount OUTPUT,
                    @rtPending = @nInvPending OUTPUT,
                    @rtPaid = @nPaid OUTPUT;

                EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                    @pInvoiceRef = @sNCDocNumber,
                    @rtDoc_Num = @sNCDoc_Num OUTPUT,
                    @rtCliente_SAP = @sNCCustomer OUTPUT,
                    @rtAmount = @nNCAmount OUTPUT,
                    @rtPending = @nNCPending OUTPUT,
                    @rtPaid = @nNCPaid OUTPUT;

                IF @nInvAmount > 0
                BEGIN

                    /*
                        La asignacion consume saldo de ambos documentos. Por eso
                        el importe debe caber en factura Y nota de credito.
                    */
                    IF @nInvPending >= @nAmount
                       AND @nAmount <= @nNCPending
                    BEGIN

                        EXEC [EAI_OWNER].[SF_GET_CUSTOMER_DATA]
                            @pCustomer_SAP = @sInvCustomer,
                            @pDate = @dtPostingDate,
                            @rtCustomer_TMD = @sCustomer_TMD OUTPUT,
                            @rtCtro = @sCtro OUTPUT,
                            @rtDistributor = @nDistributor OUTPUT,
                            @rtRep_ID = @sRep_ID OUTPUT,
                            @rtCustomer_Name = @sCustomer_Name OUTPUT;

                        IF LEN(@sCtro) > 2
                        BEGIN

                            -- El centro confirma que el cliente pudo resolverse.
                            INSERT INTO [T3].[Asignacion_Pago]
                            (
                                Pago_ID,
                                Fecha_Trn,
                                Distribuidor,
                                Fecha_Asignacion,
                                Cliente_V3,
                                Asignacion_ID,
                                Nota_Credito,
                                Cliente_SAP,
                                Rep_ID,
                                Factura,
                                Valor_Pago,
                                Ctro
                            )
                            VALUES
                            (
                                @sPago_Integration_ID,
                                GETDATE(),
                                @nDistributor,
                                @dtPostingDate,
                                @sCustomer_TMD,
                                @sPago_Integration_ID,
                                @sNCDoc_Num,
                                @sInvCustomer,
                                @sRep_ID,
                                @sInvDoc_Num,
                                @nAmount,
                                @sCtro
                            );

                            UPDATE [EAI_OWNER].[tmp_Account_Header]
                               SET Processed = GETDATE(),
                                   Status = 'Processed'
                             WHERE IDocNumber = @sIDocNum;

                        END
                        ELSE
                        BEGIN
                            -- La factura y la nota existen, pero el cliente no
                            -- pudo asociarse a un centro operativo valido.
                            UPDATE [EAI_OWNER].[tmp_Account_Header]
                               SET Processed = GETDATE(),
                                   Status = 'Customer Does not exist'
                             WHERE IDocNumber = @sIDocNum;
                        END

                    END
                    ELSE
                    BEGIN
                        -- El importe excede al menos uno de los dos saldos.
                        UPDATE [EAI_OWNER].[tmp_Account_Header]
                           SET Processed = GETDATE(),
                               Status = 'Amount > Pending'
                         WHERE IDocNumber = @sIDocNum;
                    END

                END
                ELSE
                BEGIN
                    -- La referencia principal no corresponde a una factura
                    -- por cobrar; el Oracle la marca como no recibible.
                    UPDATE [EAI_OWNER].[tmp_Account_Header]
                       SET Processed = GETDATE(),
                           Status = 'Not Receivable'
                     WHERE IDocNumber = @sIDocNum;
                END

                FETCH NEXT FROM CurData INTO
                    @nAmount,
                    @sReferenceDocNumber,
                    @FiscalYear,
                    @sPayment_Num,
                    @dtPostingDate,
                    @sCustomerPayer,
                    @sIDocNumber,
                    @sNCDocNumber;

            END

            CLOSE CurData;
            DEALLOCATE CurData;

        END
        ELSE
        BEGIN

            -- CHK_BANKCENTRAL_ALLOC retorna NO cuando detecta que la asignacion
            -- bancaria ya fue procesada por otro IDoc relacionado.
            UPDATE [EAI_OWNER].[tmp_Account_Header]
               SET Processed = GETDATE(),
                   Status = 'Tx-Duplicated'
             WHERE IDocNumber = @sIDocNum;

        END

    END TRY
    BEGIN CATCH

        -- El cursor puede seguir abierto si falla una llamada auxiliar o DML.
        IF CURSOR_STATUS('local', 'CurData') >= 0
            CLOSE CurData;

        IF CURSOR_STATUS('local', 'CurData') >= -1
            DEALLOCATE CurData;

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
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
            'Processing PI',
            @sReferenceID,
            GETDATE(),
            NULL,
            'Error',
            'PROC_CENTRAL_PAYMENT',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO
