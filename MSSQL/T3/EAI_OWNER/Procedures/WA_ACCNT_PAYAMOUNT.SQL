CREATE PROCEDURE EAI_OWNER.WA_ACCNT_PAYAMOUNT
(
      @pDiasIni INT = 0,
      @pDiasFin INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg VARCHAR(300);

    BEGIN TRY

        BEGIN TRAN;

        ---------------------------------------------------------
        -- Actualización Factura desde Nota Crédito
        ---------------------------------------------------------

        ;WITH DocInfo AS
        (
            SELECT
                ClearingDocNumber,
                MAX(CASE WHEN DC_Indicator='H' THEN PaymentAmount END) Nota_PaymentAmount,
                MAX(CASE WHEN DC_Indicator='H' THEN IdocNumber END) Nota_IdocNumber,
                MAX(CASE WHEN DC_Indicator='S' THEN IdocNumber END) Fact_IdocNumber,
                COUNT(*) Cnt,
                MAX(ISNULL(Reversal,' ')) Reversal
            FROM EAI_OWNER.TMP_ACCOUNT_HEADER
            WHERE Created > CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE)
              AND Created < CAST(DATEADD(DAY,-@pDiasFin,GETDATE()) AS DATE)
              AND ClearingDocNumber NOT LIKE '11000%'
              AND DocumentType <> 'BK'
            GROUP BY
                ClearingDocNumber
            HAVING COUNT(*) = 2
        )

        UPDATE F
           SET F.PaymentAmount       = D.Nota_PaymentAmount,
               F.Original_PaymentAmt = D.Nota_PaymentAmount
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER F
        INNER JOIN DocInfo D
           ON F.IdocNumber = D.Fact_IdocNumber
        WHERE D.Reversal=' '
          AND F.PaymentAmount IS NULL;

        ---------------------------------------------------------
        -- Reactivar Nota Crédito
        ---------------------------------------------------------

        UPDATE N
           SET Processed = NULL,
               Status    = NULL
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER N
        INNER JOIN
        (
            SELECT MAX(CASE WHEN DC_Indicator='H'
                            THEN IdocNumber END) Nota_IdocNumber
            FROM EAI_OWNER.TMP_ACCOUNT_HEADER
            WHERE Created > CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE)
              AND Created < CAST(DATEADD(DAY,-@pDiasFin,GETDATE()) AS DATE)
            GROUP BY ClearingDocNumber
            HAVING COUNT(*) = 2
        ) X
            ON X.Nota_IdocNumber = N.IdocNumber;

        ---------------------------------------------------------
        -- Migración a TMP_ACCOUNT_BANK
        ---------------------------------------------------------

        INSERT INTO EAI_OWNER.TMP_ACCOUNT_BANK
        (
            IdocNumber,
            CompanyCode,
            CustomerNumber,
            AccntDocNumber,
            BillingDocument,
            Currency,
            AmountDocCurrency,
            Assignment,
            DC_Indicator,
            ClearingDocNumber,
            ClearingDate,
            PostingDate,
            DocumentType,
            DocumentHeaderText,
            ReferenceDocNumber,
            Fyear,
            Created,
            Processed,
            Reference_CreditMemo,
            PayMethSupplement,
            FiscalYear,
            DueDateProcedure,
            PaymentAmount,
            PaymentMethod,
            Cte_Invoice,
            Cte_CreditMemo,
            Cte_Tax_ID,
            Reversal,
            ResidualTransBelongsTo,
            Status,
            Excluded_Date
        )
        SELECT
            AH.IdocNumber,
            AH.CompanyCode,
            AH.CustomerNumber,
            AH.AccntDocNumber,
            AH.BillingDocument,
            AH.Currency,
            AH.AmountDocCurrency,
            AH.Assignment,
            AH.DC_Indicator,
            AH.ClearingDocNumber,
            AH.ClearingDate,
            AH.PostingDate,
            AH.DocumentType,
            AH.DocumentHeaderText,
            AH.ReferenceDocNumber,
            AH.Fyear,
            AH.Created,
            AH.Processed,
            AH.Reference_CreditMemo,
            AH.PayMethSupplement,
            AH.FiscalYear,
            AH.DueDateProcedure,
            AH.PaymentAmount,
            AH.PaymentMethod,
            AH.Cte_Invoice,
            AH.Cte_CreditMemo,
            AH.Cte_Tax_ID,
            AH.Reversal,
            AH.ResidualTransBelongsTo,
            AH.Status,
            GETDATE()
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER AH
        INNER JOIN EAI_OWNER.MX_HASHTABLE HT
            ON LEFT(AH.ReferenceDocNumber,8)=HT.Target
        WHERE HT.Type='SAP_BANK'
          AND AH.Created >
              CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE);

        ---------------------------------------------------------
        -- Eliminación masiva
        ---------------------------------------------------------

        DELETE AH
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER AH
        INNER JOIN EAI_OWNER.MX_HASHTABLE HT
            ON LEFT(AH.ReferenceDocNumber,8)=HT.Target
        WHERE HT.Type='SAP_BANK'
          AND AH.Created >
              CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE);

        COMMIT;

        ---------------------------------------------------------
        -- Llamada dependiente
        ---------------------------------------------------------

        EXEC EAI_OWNER.WA_ACCNT_REFOLEO
             @pDiasIni,
             @pDiasFin,
             1;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(ERROR_MESSAGE(),250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            NULL,
            GETDATE(),
            NULL,
            @@SPID,
            'Error',
            'WA_ACCNT_COMPLEMENT',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO