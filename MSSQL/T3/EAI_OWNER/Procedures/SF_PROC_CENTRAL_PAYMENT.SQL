CREATE PROCEDURE [EAI_Owner].[SF_PROC_CENTRAL_PAYMENT]
(
    @sRow_ID   VARCHAR(50),
    @nRowNum   INT = 1,
    @nOutput   INT = 0,
    @nPID      INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg                    VARCHAR(500),
        @sErrorCode              VARCHAR(20),
        @sReferenceID            VARCHAR(30),
        @sProcesar               VARCHAR(20),

        @docIDocNumber           VARCHAR(10),
        @docCompanyCode          VARCHAR(100),
        @docCustomerNumber       VARCHAR(100),
        @docReferenceLog         VARCHAR(20),
        @docAccntDocNumber       VARCHAR(100),
        @docBillingDocument      VARCHAR(100),
        @docCurrency             VARCHAR(100),
        @docAmountDocCurrency    VARCHAR(100),
        @docAssignment           VARCHAR(100),
        @docDC_Indicator         VARCHAR(100),
        @docClearingDocNumber    VARCHAR(100),
        @docClearingDate         VARCHAR(100),
        @docPostingdate          VARCHAR(100),
        @docPostingdateDocument  VARCHAR(100),
        @docDocumentType         VARCHAR(100),
        @docDocumentHeadertext   VARCHAR(100),
        @docReferenceDocNumber   VARCHAR(100),
        @docResidualDocNumber    VARCHAR(100),
        @docFYear                VARCHAR(100),
        @docReversalFlag         VARCHAR(100),

        @docPaymMethSupplement  VARCHAR(100),
        @docFiscalYear          VARCHAR(100),
        @docFiscalYearClearing  VARCHAR(100) = '0',
        @docDueDateProcedure    VARCHAR(100),
        @docPaymentAmount       VARCHAR(100),
        @docPaymentMethod       VARCHAR(100),
        @docPayment_MessageType VARCHAR(100),

        @numAmountDocCurrency   DECIMAL(15,2),
        @numPaymentAmount       DECIMAL(15,2),
        @numOriginalPayment     DECIMAL(15,2),
        @docIvy_Source          VARCHAR(10),
        @docIvy_Diff            DECIMAL(15,2) = 0.00,

        @XML_Content            XML;

    BEGIN TRY
        BEGIN TRAN;

        IF (@nOutput > 0)
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, 'Begin');
        END;

        SELECT TOP (1)
            @XML_Content = TRY_CAST(XML_Content AS XML)
        FROM [EAI_Owner].[MX_Receive_Message_Log]
        WHERE Row_ID = @sRow_ID;

        IF @XML_Content IS NULL
        BEGIN
            SET @sProcesar = 'ED';

            UPDATE [EAI_Owner].[MX_Receive_Message_Log]
               SET Processed = GETDATE(),
                   Reference = NULL,
                   Status = 'CheckData'
             WHERE Row_ID = @sRow_ID;

            IF (@nOutput > 0)
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, 'XML_Content inválido o vacío');
            END;

            COMMIT;
            RETURN;
        END;

        SELECT
            @docIDocNumber =
                SUBSTRING(
                    @XML_Content.value('(/Payment/Header/Reference/ReferenceID/text())[1]', 'VARCHAR(100)'),
                    7,
                    10
                ),

            @docCompanyCode =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/CompanyCode/text())[1]', 'VARCHAR(100)'),

            @docCustomerNumber =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/CustomerNumber/text())[1]', 'VARCHAR(100)'),

            @docAccntDocNumber =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/AccountingDocumentNumber/text())[1]', 'VARCHAR(100)'),

            @docBillingDocument =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/BillingDocument/text())[1]', 'VARCHAR(100)'),

            @docCurrency =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/Currency/text())[1]', 'VARCHAR(100)'),

            @docAmountDocCurrency =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/AmountinDocumentCurrency/text())[1]', 'VARCHAR(100)'),

            @docAssignment =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/Assignment/text())[1]', 'VARCHAR(100)'),

            @docDC_Indicator =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/DebitCreditIndicator/text())[1]', 'VARCHAR(100)'),

            @docClearingDocNumber =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/ClearingDocumentNumber/text())[1]', 'VARCHAR(100)'),

            @docClearingDate =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/ClearingDate/text())[1]', 'VARCHAR(100)'),

            @docPostingdate =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/Postingdate/text())[1]', 'VARCHAR(100)'),

            @docDocumentType =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/DocumentType/text())[1]', 'VARCHAR(100)'),

            @docDocumentHeadertext =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/DocumentHeadertext/text())[1]', 'VARCHAR(100)'),

            @docReferenceDocNumber =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/ReferenceDocumentNumber/text())[1]', 'VARCHAR(100)'),

            @docResidualDocNumber =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/NumbInvoiceTransBelongsto/text())[1]', 'VARCHAR(100)'),

            @docFYear =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/FYearRelevantInvoice/text())[1]', 'VARCHAR(100)'),

            @docReversalFlag =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/ReversalFlag/text())[1]', 'VARCHAR(100)'),

            @docPaymMethSupplement =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/PaymMethSupplement/text())[1]', 'VARCHAR(100)'),

            @docFiscalYear =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/FiscalYear/text())[1]', 'VARCHAR(100)'),

            @docDueDateProcedure =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/DueDateProcedure/text())[1]', 'VARCHAR(100)'),

            @docPostingdateDocument =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/PostingDateDocument/text())[1]', 'VARCHAR(100)'),

            @docPaymentAmount =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/PaymentAmount/text())[1]', 'VARCHAR(100)'),

            @docPaymentMethod =
                @XML_Content.value('(/Payment/Message/ZTMDALLOCPAY/PaymentMethod/text())[1]', 'VARCHAR(100)'),

            @docPayment_MessageType =
                @XML_Content.value('(/Invoice/Header/MessageType/text())[1]', 'VARCHAR(100)');

        SET @docReferenceLog = @docAccntDocNumber;

        IF (CHARINDEX('-', COALESCE(@docAmountDocCurrency, '')) > 0)
        BEGIN
            SET @docAmountDocCurrency = '-' + REPLACE(@docAmountDocCurrency, '-', '');
        END;

        SET @docIvy_Source = 'NO';
        SET @docIvy_Diff = 0.00;

        IF (SUBSTRING(COALESCE(@docClearingDocNumber, ''), 1, 2) = '22')
        BEGIN
            SET @docIvy_Source = 'YES';
        END;

        IF (CHARINDEX('-', COALESCE(@docPaymentAmount, '')) > 0)
        BEGIN
            SET @docPaymentAmount = '-' + REPLACE(@docPaymentAmount, '-', '');
        END;

        IF (LEN(COALESCE(@docClearingDate, '')) > 4)
        BEGIN
            SET @docFiscalYearClearing = SUBSTRING(@docClearingDate, 1, 4);
        END;

        DELETE FROM [EAI_Owner].[tmp_Account_Header]
        WHERE IDocNumber = @docIDocNumber;

        DELETE FROM [EAI_Owner].[tmp_Account_Detail]
        WHERE IDocNumber = @docIDocNumber;

        IF (@nOutput > 0)
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('CustomerNumber     => ', @docCustomerNumber)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('AccntDocNumber     => ', @docAccntDocNumber)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('BillingDocument    => ', @docBillingDocument)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('AmountDocCurrency  => ', @docAmountDocCurrency)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('Assignment         => ', @docAssignment)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('DC_Indicator       => ', @docDC_Indicator)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('ClearingDocNumber  => ', @docClearingDocNumber)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('ClearingDate       => ', @docClearingDate)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('Postingdate        => ', @docPostingdate)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('DocumentType       => ', @docDocumentType)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('DocumentHeadertext => ', @docDocumentHeadertext)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('ReferenceDocNumber => ', @docReferenceDocNumber)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('PaymMethSupplement => ', @docPaymMethSupplement)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('FiscalYear         => ', @docFiscalYear)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('FiscalYearClearing => ', @docFiscalYearClearing)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('DueDateProcedure   => ', @docDueDateProcedure)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('PostingDateDoc     => ', @docPostingdateDocument)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('PaymentAmount      => ', @docPaymentAmount)),
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, CONCAT('PaymentMethod      => ', @docPaymentMethod));
        END;

        SET @numAmountDocCurrency =
            CASE
                WHEN LEN(COALESCE(@docAmountDocCurrency, '')) > 0
                THEN TRY_CONVERT(DECIMAL(15,2), @docAmountDocCurrency)
                ELSE NULL
            END;

        SET @numPaymentAmount =
            CASE
                WHEN LEN(COALESCE(@docPaymentAmount, '')) > 0
                THEN TRY_CONVERT(DECIMAL(15,2), @docPaymentAmount)
                ELSE NULL
            END;

        IF (LEN(COALESCE(@docFiscalYearClearing, '')) > 0)
        BEGIN
            SET @docFiscalYear = @docFiscalYearClearing;
        END;

        SET @numOriginalPayment = @numPaymentAmount;

        IF (@docPaymentMethod = 'OP')
        BEGIN
            IF (@docIvy_Source = 'YES')
            BEGIN
                IF (COALESCE(@numPaymentAmount, 0) > 0 AND COALESCE(@numAmountDocCurrency, 0) > 0)
                BEGIN
                    SET @docIvy_Diff = @numPaymentAmount - @numAmountDocCurrency;

                    IF (@docIvy_Diff <= 5.00)
                        SET @numPaymentAmount = @numAmountDocCurrency;
                    ELSE
                        SET @numPaymentAmount = 0;
                END;
            END
            ELSE
            BEGIN
                SET @numPaymentAmount = @numAmountDocCurrency;
            END;
        END
        ELSE IF (@docPaymentMethod = 'FP')
        BEGIN
            SET @numPaymentAmount = @numAmountDocCurrency;
        END;

        IF (LEN(COALESCE(@docIDocNumber, '')) > 6)
        BEGIN
            INSERT INTO [EAI_Owner].[tmp_Account_Header]
            (
                IDocNumber,
                CompanyCode,
                CustomerNumber,
                AccntDocNumber,
                BillingDocument,
                Currency,
                AmountDocCurrency,
                Assignment,
                Created,
                PayMethSupplement,
                FiscalYear,
                ResidualTransBelongsTo,
                DueDateProcedure,
                PaymentAmount,
                PaymentMethod,
                Reversal,
                DC_Indicator,
                ClearingDocNumber,
                ClearingDate,
                Postingdate,
                Original_PaymentAmt,
                PostingDateDocument,
                DocumentType,
                DocumentHeadertext,
                ReferenceDocNumber,
                FYear
            )
            VALUES
            (
                @docIDocNumber,
                @docCompanyCode,
                @docCustomerNumber,
                @docAccntDocNumber,
                @docBillingDocument,
                @docCurrency,
                @numAmountDocCurrency,
                @docAssignment,
                GETDATE(),
                @docPaymMethSupplement,
                @docFiscalYear,
                @docResidualDocNumber,
                @docDueDateProcedure,
                @numPaymentAmount,
                @docPaymentMethod,
                @docReversalFlag,
                @docDC_Indicator,
                @docClearingDocNumber,
                @docClearingDate,
                @docPostingdate,
                @numOriginalPayment,
                @docPostingdateDocument,
                @docDocumentType,
                @docDocumentHeadertext,
                @docReferenceDocNumber,
                @docFYear
            );

            SET @sProcesar = 'SI';
        END
        ELSE IF (LEN(COALESCE(@docPayment_MessageType, '')) > 5)
        BEGIN
            IF (@nOutput > 0)
            BEGIN
                INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, 'WA -> DebitNote');
            END;

            EXEC [EAI_Owner].[SF_PROC_PREINVOICE_IFC] @sRow_ID;
        END;

        IF (@nOutput > 0)
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT', @sRow_ID, 'End');
        END;

        IF (LEN(COALESCE(@docIDocNumber, '')) > 6)
        BEGIN
            UPDATE [EAI_Owner].[MX_Receive_Message_Log]
               SET Processed = GETDATE(),
                   Reference = @docReferenceLog,
                   Status =
                        CASE @sProcesar
                            WHEN 'SI' THEN 'Processed'
                            WHEN 'ED' THEN 'CheckData'
                            ELSE 'Review'
                        END
             WHERE Row_ID = @sRow_ID;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        BEGIN TRY
            INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
            (
                DIRECTION,
                REFERENCE,
                CREATED,
                MESSAGE,
                JOB_PID,
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
                'Job Logging',
                @sRow_ID,
                GETDATE(),
                NULL,
                @nPID,
                'Error',
                'PROC_CENTRAL_PAYMENT',
                @sMsg,
                'T-SQL',
                @sErrorCode,
                NULL,
                NULL,
                NULL
            );
        END TRY
        BEGIN CATCH
            -- Si falla también el logging, se relanza el error original del CATCH principal.
        END CATCH;

        THROW;
    END CATCH;
END;
GO