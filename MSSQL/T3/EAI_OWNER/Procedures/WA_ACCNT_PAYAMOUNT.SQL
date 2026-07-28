/*
    Procedure : EAI_OWNER.WA_ACCNT_PAYAMOUNT
    Objetivo  : Completar el importe de pago de una factura usando su nota de
                crédito asociada y aislar operaciones bancarias configuradas.
    Integridad: Factura y nota se seleccionan con exactamente los mismos filtros;
                la migración a TMP_ACCOUNT_BANK y el DELETE se confirman juntos.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.WA_ACCNT_PAYAMOUNT
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

        -- La tabla temporal materializa una sola vez los pares elegibles. Así la
        -- factura y la nota reciben cambios bajo exactamente las mismas reglas.
        SELECT
            ClearingDocNumber,
            ClearingDate,
            MAX(CASE WHEN DC_Indicator='H' THEN PaymentAmount END) AS Nota_PaymentAmount,
            MAX(CASE WHEN DC_Indicator='H' THEN IdocNumber END) AS Nota_IdocNumber,
            MAX(CASE WHEN DC_Indicator='S' THEN IdocNumber END) AS Fact_IdocNumber,
            MAX(CASE WHEN DC_Indicator='H' THEN ReferenceDocNumber END) AS Nota_Reference,
            MAX(CASE WHEN DC_Indicator='H' THEN Status END) AS Nota_Status,
            MAX(CASE WHEN DC_Indicator='S' THEN PaymentAmount END) AS Fact_PaymentAmount,
            MAX(ISNULL(Reversal,' ')) AS Reversal
        INTO #EligiblePayAmount
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER
        WHERE Created > CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE)
          AND Created < CAST(DATEADD(DAY,-@pDiasFin,GETDATE()) AS DATE)
          AND ClearingDocNumber NOT LIKE '11000%'
          AND DocumentType <> 'BK'
        GROUP BY ClearingDocNumber, ClearingDate
        HAVING COUNT(ClearingDocNumber) = 2
           AND MAX(CASE WHEN DC_Indicator='H' THEN ReferenceDocNumber END) IS NOT NULL;

        DELETE FROM #EligiblePayAmount
        WHERE Nota_Status IS NULL
           OR Nota_Status = 'Processed'
           OR Fact_PaymentAmount IS NOT NULL
           OR Reversal <> ' ';

        UPDATE F
           SET F.PaymentAmount       = D.Nota_PaymentAmount,
               -- Oracle evalúa PaymentAmount con el valor anterior de la fila.
               F.Original_PaymentAmt = F.PaymentAmount
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER F
        INNER JOIN #EligiblePayAmount D
           ON F.IdocNumber = D.Fact_IdocNumber
        WHERE F.PaymentAmount IS NULL;

        ---------------------------------------------------------
        -- Reactivar Nota Crédito
        ---------------------------------------------------------

        UPDATE N
           SET Processed = NULL,
               Status    = NULL
        FROM EAI_OWNER.TMP_ACCOUNT_HEADER N
        INNER JOIN #EligiblePayAmount X
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
            NULL,
            'Error',
            'WA_ACCNT_COMPLEMENT',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra la incidencia sin propagarla al proceso invocador.

    END CATCH

END
GO
