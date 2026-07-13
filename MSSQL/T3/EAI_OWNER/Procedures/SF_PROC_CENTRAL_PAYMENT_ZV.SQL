CREATE  PROCEDURE EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV
(
    @pIDocNum VARCHAR(50),
    @pOutput  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg NVARCHAR(500),
        @sErrorCode VARCHAR(20),
        @sReferenceID VARCHAR(30),
        @sProcesar VARCHAR(20),
        @sIDocNum VARCHAR(20),

        @sReferenceDocNumber VARCHAR(50),
        @sPago_Integration_ID VARCHAR(50),
        @sPayment_Num VARCHAR(50),
        @dtPostingDate DATETIME,
        @sCustomerPayer VARCHAR(50),
        @sIDocNumber VARCHAR(50),
        @sPayment_Method VARCHAR(50),

        @nAmount DECIMAL(18,2),
        @sCustomer_TMD VARCHAR(30),
        @sCtro VARCHAR(4),
        @nDistributor INT,
        @sRep_ID VARCHAR(30),
        @sInvDoc_Num VARCHAR(30),
        @sInvCustomer VARCHAR(30),
        @nInvAmount DECIMAL(18,2),
        @nInvPending DECIMAL(18,2),
        @nAbsolute DECIMAL(18,2),
        @nPaid DECIMAL(18,2),
        @sCustomer_Name VARCHAR(1024);

    BEGIN TRY

        SET @sReferenceID = @pIDocNum;
        SET @sIDocNum     = SUBSTRING(@pIDocNum,7,10);

        IF @pOutput > 0
        BEGIN
            INSERT INTO EAI_Owner.Trace_EAI_Owner
            VALUES(GETDATE(),
                   'SF_PROC_CENTRAL_PAYMENT_ZV',
                   @sReferenceID,
                   'Begin');
        END

        SET @sProcesar = EAI_Owner.SF_PAYMENT_ALLOC(@sIDocNum);

        IF @sProcesar <> 'NO'
        BEGIN

            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR

            SELECT
                COALESCE(Doc.PaymentAmount,0),
                Doc.ReferenceDocNumber,
                SUBSTRING(Doc.ClearingDate,3,2),
                Doc.ClearingDocNumber,
                CONVERT(DATETIME,Doc.ClearingDate,112),
                Doc.CustomerNumber,
                Doc.IDocNumber,
                EAI_Owner.GetConv(
                    'ECC_T3 PaymentMethod',
                    Doc.PayMethSupplement
                )
            FROM EAI_Owner.tmp_Account_Header Doc
            LEFT JOIN EAI_Owner.Client Cte
                ON Doc.CustomerNumber = Cte.Cliente_SAP
            WHERE Doc.IDocNumber=@sIDocNum
              AND Doc.PayMethSupplement IS NOT NULL
              AND Doc.PayMethSupplement<>'Z9'
              AND COALESCE(Doc.PaymentAmount,0)>0;

            DECLARE @FiscalYear VARCHAR(10);

            OPEN cur;

            FETCH NEXT FROM cur INTO
                @nAmount,
                @sReferenceDocNumber,
                @FiscalYear,
                @sPayment_Num,
                @dtPostingDate,
                @sCustomerPayer,
                @sIDocNumber,
                @sPayment_Method;

            WHILE @@FETCH_STATUS = 0
            BEGIN

                SET @sPago_Integration_ID =
                    @FiscalYear + @sPayment_Num;

                EXEC EAI_Owner.SF_GET_INVOICE_DATA
                    @sReferenceDocNumber,
                    @sInvDoc_Num OUTPUT,
                    @sInvCustomer OUTPUT,
                    @nInvAmount OUTPUT,
                    @nInvPending OUTPUT,
                    @nPaid OUTPUT;

                IF @nInvAmount > 0
                BEGIN

                    SET @nAbsolute =
                        ABS(@nAmount - @nInvPending);

                    IF @nAmount > @nInvPending
                       AND @nAbsolute < 0.05
                    BEGIN
                        SET @nAmount = @nInvPending;
                    END

                    IF @nAmount <= @nInvPending
                       AND @nAmount > 0
                    BEGIN

                        EXEC EAI_Owner.SF_GET_CUSTOMER_DATA
                            @sInvCustomer,
                            @dtPostingDate,
                            @sCustomer_TMD OUTPUT,
                            @sCtro OUTPUT,
                            @nDistributor OUTPUT,
                            @sRep_ID OUTPUT,
                            @sCustomer_Name OUTPUT;

                        IF LEN(@sCtro) > 2
                        BEGIN

                            INSERT INTO T3.Pago
                            (
                                Pago_ID,
                                Fecha_Trn,
                                Distribuidor,
                                Fecha_Pago,
                                Cliente_V3,
                                Cliente_SAP,
                                Rep_ID,
                                Tipo_Pago,
                                Metodo_Pago,
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
                                @sInvCustomer,
                                @sRep_ID,
                                'Payment',
                                @sPayment_Method,
                                @nAmount,
                                @sCtro
                            );

                            INSERT INTO T3.Asignacion_Pago
                            (
                                Pago_ID,
                                Fecha_Trn,
                                Distribuidor,
                                Fecha_Asignacion,
                                Cliente_V3,
                                Asignacion_ID,
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
                                @sInvCustomer,
                                @sRep_ID,
                                @sInvDoc_Num,
                                @nAmount,
                                @sCtro
                            );

                            UPDATE EAI_Owner.tmp_Account_Header
                               SET Processed = GETDATE(),
                                   Status='Processed'
                             WHERE IDocNumber=@sIDocNum;
                        END
                        ELSE
                        BEGIN
                            UPDATE EAI_Owner.tmp_Account_Header
                               SET Processed=GETDATE(),
                                   Status='Customer Invalid'
                             WHERE IDocNumber=@sIDocNum;
                        END
                    END
                    ELSE
                    BEGIN
                        UPDATE EAI_Owner.tmp_Account_Header
                           SET Processed=GETDATE(),
                               Status=
                               CASE
                                   WHEN @nAmount>0
                                   THEN 'Amount > Pending'
                                   ELSE 'Discarded'
                               END
                         WHERE IDocNumber=@sIDocNum;
                    END
                END
                ELSE
                BEGIN
                    UPDATE EAI_Owner.tmp_Account_Header
                       SET Processed=GETDATE(),
                           Status='Not Receivable'
                     WHERE IDocNumber=@sIDocNum;
                END

                FETCH NEXT FROM cur INTO
                    @nAmount,
                    @sReferenceDocNumber,
                    @FiscalYear,
                    @sPayment_Num,
                    @dtPostingDate,
                    @sCustomerPayer,
                    @sIDocNumber,
                    @sPayment_Method;
            END

            CLOSE cur;
            DEALLOCATE cur;
        END
        ELSE
        BEGIN

            UPDATE EAI_Owner.tmp_Account_Header
               SET Processed=GETDATE(),
                   Status='Tx-Duplicated'
             WHERE IDocNumber=@sIDocNum;

        END

    END TRY
    BEGIN CATCH

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Processing PI',
            @sReferenceID,
            GETDATE(),
            'Error',
            'PROC_CENTRAL_PAYMENT',
            ERROR_MESSAGE(),
            'TSQL',
            CAST(ERROR_NUMBER() AS VARCHAR(20))
        );

        THROW;

    END CATCH
END
GO