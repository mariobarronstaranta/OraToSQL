CREATE OR ALTER FUNCTION [EAI_OWNER].[GET_CLEARING_STATUS]
(
    @pInvoice    VARCHAR(50),
    @pCreditNote VARCHAR(50),
    @pAmount     DECIMAL(15,2)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE
        @sReturn     VARCHAR(50) = '',
        @sInvoice    VARCHAR(50) = ISNULL(@pInvoice, 'NONE'),
        @sCreditNote VARCHAR(50) = ISNULL(@pCreditNote, 'NONE'),
        @nAmount     DECIMAL(15,2) = ISNULL(@pAmount, 0),
        @nInvoiceAmt DECIMAL(15,2) = 0,
        @nCreditAmt  DECIMAL(15,2) = 0;

    IF LEN(@sCreditNote) < 3
        SET @sCreditNote = 'NONE';

    SELECT
        @nInvoiceAmt = ISNULL(SUM(ISNULL(Cobza.Importe, 0)), 0),
        @nCreditAmt = ISNULL(SUM(CASE
                                    WHEN ISNULL(Cobza.Nota_Credito, 'EMPTY') = @sCreditNote
                                        THEN ISNULL(Cobza.Importe, 0)
                                    ELSE 0
                                 END), 0)
    FROM [T3].[CFDI_Cobranza] AS Cobza
    WHERE Cobza.Factura = @sInvoice;

    IF @nAmount > 0 AND @nInvoiceAmt > 0
    BEGIN
        IF ABS(@nAmount - @nInvoiceAmt) < 0.50 AND @sCreditNote = 'NONE'
            SET @sReturn = 'Comp-Ok';
        ELSE IF ABS(@nAmount - @nInvoiceAmt) < 0.50
             AND ABS(@nCreditAmt - @nInvoiceAmt) < 0.50
            SET @sReturn = 'Comp-Inv-ZLOB';
        ELSE IF @sCreditNote <> 'NONE'
        BEGIN
            SELECT
                @nCreditAmt = ISNULL(SUM(ISNULL(Cobza.Importe, 0)), 0)
            FROM [T3].[CFDI_Cobranza] AS Cobza
            WHERE Cobza.Nota_Credito = @sCreditNote;

            IF ABS(@nAmount - @nInvoiceAmt) < 0.50
               AND ABS(@nAmount - @nCreditAmt) < 0.50
                SET @sReturn = 'Inv-Ok-ZLOB-Ok';
            ELSE IF ABS(@nAmount - @nCreditAmt) < 0.50
                SET @sReturn = 'ZLOB-Ok';
            ELSE IF ABS(@nAmount - @nInvoiceAmt) < 0.50
                SET @sReturn = 'Inv-Ok';
        END;
    END;

    RETURN @sReturn;
END;
GO
