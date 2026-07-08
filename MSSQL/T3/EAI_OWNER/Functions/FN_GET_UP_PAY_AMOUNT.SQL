CREATE OR ALTER FUNCTION EAI_OWNER.FN_GET_UP_PAY_AMOUNT
(
    @P_IDOC_NUMBER VARCHAR(50)
)
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE
        @sDocType           VARCHAR(10),
        @nPayAmount         DECIMAL(15,2),
        @sResidualDoc       VARCHAR(10),
        @sFiscalYear        VARCHAR(10),
        @sPaymentMethod     VARCHAR(10),
        @sDC_Indicator      VARCHAR(10),
        @sClearingDate      DATETIME2(0),
        @sBillingDocument   VARCHAR(20),
        @sClearingDocument  VARCHAR(20),
        @nRecords           INT,
        @nInitialAmount     DECIMAL(15,2),
        @nResidualAmount    DECIMAL(15,2),
        @nPaymentAmount     DECIMAL(15,2),
        @nAmountDoc         DECIMAL(15,2);

    SET @nPayAmount      = 0;
    SET @nInitialAmount  = 0;
    SET @nResidualAmount = 0;

    /*
        Equivalente al cursor ScrAccounting.
        El Oracle original no tenía ORDER BY; si existen varias filas para el IDOC,
        el resultado era no determinístico. Aquí se estabiliza tomando la más reciente.
    */
    SELECT TOP (1)
        @sClearingDocument = AccntDocNumber,
        @nInitialAmount    = COALESCE(AmountDocCurrency, 0),
        @sClearingDocument = ClearingDocNumber,
        @sDC_Indicator     = DC_Indicator,
        @sResidualDoc      = COALESCE(ResidualTransBelongsTo, 'EMPTY'),
        @nPaymentAmount    = COALESCE(PaymentAmount, 0),
        @sFiscalYear       = FiscalYear,
        @sPaymentMethod    = PaymentMethod,
        @sClearingDate     = ClearingDate,
        @sBillingDocument  = BillingDocument,
        @nAmountDoc        = COALESCE(AmountDocCurrency, 0)
    FROM EAI_OWNER.tmp_Account_Header
    WHERE IdocNumber = @P_IDOC_NUMBER
    ORDER BY 
        PostingDate DESC,
        AccntDocNumber DESC;

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
        SET @nPayAmount = 0;
    END
    ELSE IF (SUBSTRING(@sClearingDocument, 1, 2) = '22')
    BEGIN
        -- Direct Payment
        SET @nPayAmount = COALESCE(@nPaymentAmount, 0);
    END
    ELSE IF (SUBSTRING(@sClearingDocument, 1, 2) IN ('20', '21'))
    BEGIN
        -- Central Collection / Under Payment
        IF (@sPaymentMethod IN ('UP', 'OP') AND @sDC_Indicator = 'S')
        BEGIN
            /*
                Equivalente a ScrResidualDoc:
                Oracle recorre por PostingDate y termina usando:
                - nInitialAmount  = penúltimo AmountDocCurrency
                - nResidualAmount = último AmountDocCurrency
                Resultado: penúltimo - último
            */
            ;WITH ResidualDocs AS
            (
                SELECT
                    AccntDocNumber,
                    COALESCE(AmountDocCurrency, 0) AS AmountDocCurrency,
                    COALESCE(PaymentAmount, 0)     AS PaymentAmount,
                    ROW_NUMBER() OVER
                    (
                        ORDER BY PostingDate DESC, AccntDocNumber DESC
                    ) AS rn_desc,
                    COUNT(*) OVER () AS total_rows
                FROM EAI_OWNER.tmp_Account_Header
                WHERE BillingDocument = @sBillingDocument
                  AND ClearingDate IS NULL
                  AND PostingDate <= @sClearingDate
            )
            SELECT
                @nRecords =
                    MAX(total_rows),
                @nResidualAmount =
                    MAX(CASE WHEN rn_desc = 1 THEN AmountDocCurrency END),
                @nInitialAmount =
                    MAX(CASE WHEN rn_desc = 2 THEN AmountDocCurrency END)
            FROM ResidualDocs
            WHERE rn_desc IN (1, 2);

            SET @nRecords = COALESCE(@nRecords, 0);

            IF (@nRecords > 1)
            BEGIN
                SET @nPayAmount = COALESCE(@nInitialAmount, 0) - COALESCE(@nResidualAmount, 0);
            END
            ELSE IF (COALESCE(@nPaymentAmount, 0) > 0 
                 AND COALESCE(@nPaymentAmount, 0) <= COALESCE(@nAmountDoc, 0))
            BEGIN
                SET @nPayAmount = COALESCE(@nPaymentAmount, 0);
            END
        END
        ELSE IF (@sPaymentMethod = 'OPA' AND @sDC_Indicator = 'S')
        BEGIN
            /*
                Equivalente a ScrConfirmOP_Doc:
                Toma el primer documento ordenado por AccntDocNumber.
            */
            SET @nRecords = 0;
            SET @nResidualAmount = 0;

            SELECT TOP (1)
                @nRecords = 1,
                @nResidualAmount = COALESCE(AmountDocCurrency, 0)
            FROM EAI_OWNER.tmp_Account_Header
            WHERE BillingDocument = @sBillingDocument
              AND PostingDate = @sClearingDate
            ORDER BY AccntDocNumber;

            IF (@nRecords = 1)
            BEGIN
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