CREATE OR ALTER FUNCTION EAI_Owner.FN_GET_UP_PAY_AMOUNT2
(
    @P_IDOC_NUMBER VARCHAR(50)
)
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE
        @sDocType             VARCHAR(10),
        @nPayAmount           DECIMAL(15,2),
        @sResidualDoc         VARCHAR(10),
        @sFiscalYear          VARCHAR(10),
        @sPaymentMethod       VARCHAR(10),
        @sDC_Indicator        VARCHAR(10),
        @sClearingDate        DATETIME,
        @sBillingDocument     VARCHAR(20),
        @sClearingDocument    VARCHAR(20),
        @nRecords             INT,
        @nInitialAmount       DECIMAL(15,2),
        @nResidualAmount      DECIMAL(15,2),
        @nPaymentAmount       DECIMAL(15,2),
        @nAmountDoc           DECIMAL(15,2);

    SET @nPayAmount      = 0;
    SET @nInitialAmount  = 0;
    SET @nResidualAmount = 0;
    SET @nPaymentAmount  = 0;
    SET @nAmountDoc      = 0;

    /*
        Equivalente al cursor ScrAccounting.

        IMPORTANTE:
        En Oracle el cursor no tiene ORDER BY. Si existen múltiples registros para
        el mismo IdocNumber, el último registro leído sobrescribe las variables.
        Este SELECT conserva el comportamiento de asignación variable en SQL Server,
        pero el resultado seguirá siendo no determinístico si IdocNumber no es único.
    */
    SELECT
        @sResidualDoc       = COALESCE(ResidualTransBelongsTo, 'EMPTY'),
        @sFiscalYear        = FiscalYear,
        @sPaymentMethod     = PaymentMethod,
        @sDC_Indicator      = DC_Indicator,
        @sBillingDocument   = BillingDocument,
        @sClearingDate      = TRY_CONVERT(DATETIME, ClearingDate),
        @nInitialAmount     = COALESCE(AmountDocCurrency, 0),
        @nPaymentAmount     = COALESCE(PaymentAmount, 0),
        @nAmountDoc         = COALESCE(AmountDocCurrency, 0),
        @sClearingDocument  = ClearingDocNumber
    FROM EAI_Owner.tmp_Account_Header
    WHERE IdocNumber = @P_IDOC_NUMBER;

    IF (@sClearingDocument IS NULL)
    BEGIN
        SET @nPayAmount = 0;
    END
    ELSE IF (LEN(@sClearingDocument) < 5)
    BEGIN
        SET @nPayAmount = 0;
    END
    ELSE IF (@sDC_Indicator = 'H')
    BEGIN
        -- Credit Movement
        SET @nPayAmount = 0;
    END
    ELSE IF (SUBSTRING(@sClearingDocument, 1, 2) = '22')
    BEGIN
        -- Direct Payment
        SET @nPayAmount = COALESCE(@nPaymentAmount, 0);
    END
    ELSE IF (SUBSTRING(@sClearingDocument, 1, 2) IN ('20', '21'))
    BEGIN
        -- Central Collection

        IF (@sPaymentMethod IN ('UP', 'OP') AND @sDC_Indicator = 'S')
        BEGIN
            /*
                Equivalente a ScrResidualDoc:
                - Ordena por PostingDate.
                - Si hay más de un registro, toma diferencia entre penúltimo y último AmountDocCurrency.
                - Si sólo hay un registro, usa PaymentAmount cuando sea válido.
            */

            ;WITH ResidualDocs AS
            (
                SELECT
                    AccntDocNumber,
                    COALESCE(AmountDocCurrency, 0) AS AmountDocCurrency,
                    COALESCE(PaymentAmount, 0)     AS PaymentAmount,
                    PostingDate,
                    ROW_NUMBER() OVER
                    (
                        ORDER BY PostingDate ASC, AccntDocNumber ASC
                    ) AS rn_asc,
                    ROW_NUMBER() OVER
                    (
                        ORDER BY PostingDate DESC, AccntDocNumber DESC
                    ) AS rn_desc,
                    COUNT(*) OVER () AS total_rows
                FROM EAI_Owner.tmp_Account_Header
                WHERE BillingDocument = @sBillingDocument
                  AND ClearingDate IS NULL
                  AND PostingDate <= @sClearingDate
            )
            SELECT
                @nRecords =
                    MAX(total_rows),
                @nInitialAmount =
                    MAX(CASE WHEN rn_desc = 2 THEN AmountDocCurrency END),
                @nResidualAmount =
                    MAX(CASE WHEN rn_desc = 1 THEN AmountDocCurrency END)
            FROM ResidualDocs;

            SET @nRecords = COALESCE(@nRecords, 0);

            IF (@nRecords > 1)
            BEGIN
                SET @nPayAmount = COALESCE(@nInitialAmount, 0) - COALESCE(@nResidualAmount, 0);
            END
            ELSE IF (COALESCE(@nPaymentAmount, 0) > 0 AND COALESCE(@nPaymentAmount, 0) <= COALESCE(@nAmountDoc, 0))
            BEGIN
                SET @nPayAmount = COALESCE(@nPaymentAmount, 0);
            END
        END
        ELSE IF (@sPaymentMethod = 'OPA' AND @sDC_Indicator = 'S')
        BEGIN
            /*
                Equivalente a ScrConfirmOP_Doc:
                - Oracle toma el primer registro ordenado por AccntDocNumber.
                - Sólo calcula si existe exactamente un registro.
            */

            SELECT
                @nRecords = COUNT(*)
            FROM EAI_Owner.tmp_Account_Header
            WHERE BillingDocument = @sBillingDocument
              AND PostingDate = @sClearingDate;

            IF (@nRecords = 1)
            BEGIN
                SELECT TOP (1)
                    @nResidualAmount = COALESCE(AmountDocCurrency, 0)
                FROM EAI_Owner.tmp_Account_Header
                WHERE BillingDocument = @sBillingDocument
                  AND PostingDate = @sClearingDate
                ORDER BY AccntDocNumber ASC;

                SET @nPayAmount = COALESCE(@nInitialAmount, 0) - COALESCE(@nResidualAmount, 0);
            END
        END
        ELSE IF (@sPaymentMethod = 'FP')
        BEGIN
            SET @nPayAmount = COALESCE(@nPaymentAmount, 0);
        END
    END

    RETURN COALESCE(@nPayAmount, 0);
END;
GO