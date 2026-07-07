CREATE OR ALTER FUNCTION dbo.GET_CLEARING_STATUS
(
    @pInvoice     VARCHAR(50),
    @pCreditNote  VARCHAR(50),
    @pAmount      DECIMAL(15,2)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE 
        @sReturn      VARCHAR(50)  = '',
        @sInvoice     VARCHAR(50),
        @sCreditNote  VARCHAR(50),
        @nAmount      DECIMAL(15,2),
        @nInvoiceAmt  DECIMAL(15,2) = 0,
        @nCreditAmt   DECIMAL(15,2) = 0;

    /*
        Equivalencias Oracle -> SQL Server:
        NVL    -> COALESCE
        DECODE -> CASE
        LENGTH -> LEN
        NUMBER(15,2) -> DECIMAL(15,2)

        Nota:
        Oracle trata '' como NULL.
        SQL Server no. Esta versión conserva la salida como cadena vacía
        cuando no se determina estatus, para respetar la intención del código.
    */

    SET @sInvoice    = COALESCE(@pInvoice, 'NONE');
    SET @sCreditNote = COALESCE(@pCreditNote, 'NONE');

    IF LEN(@sCreditNote) < 3
    BEGIN
        SET @sCreditNote = 'NONE';
    END;

    SET @nAmount = COALESCE(@pAmount, 0);

    /*
        Reemplazo del cursor ScrAllocation.
        En Oracle:
            Amount_Inv = SUM(NVL(Importe, 0))
            Amount_CN  = SUM(DECODE(NVL(Nota_Credito, 'EMPTY'), sCreditNote, NVL(Importe, 0), 0))
    */
    SELECT
        @nInvoiceAmt = COALESCE(SUM(COALESCE(Cobza.Importe, 0)), 0),
        @nCreditAmt  = COALESCE(
                           SUM(
                               CASE 
                                   WHEN COALESCE(Cobza.Nota_Credito, 'EMPTY') = @sCreditNote
                                       THEN COALESCE(Cobza.Importe, 0)
                                   ELSE 0
                               END
                           ), 
                           0
                       )
    FROM T3.CFDI_Cobranza AS Cobza
    WHERE Cobza.Factura = @sInvoice;

    IF (@nAmount > 0 AND @nInvoiceAmt > 0)
    BEGIN
        IF (
               ABS(@nAmount - @nInvoiceAmt) < 0.50
               AND @sCreditNote = 'NONE'
           )
        BEGIN
            SET @sReturn = 'Comp-Ok';
        END
        ELSE IF (
                    ABS(@nAmount - @nInvoiceAmt) < 0.50
                    AND ABS(@nCreditAmt - @nInvoiceAmt) < 0.50
                )
        BEGIN
            SET @sReturn = 'Comp-Inv-ZLOB';
        END
        ELSE IF (@sCreditNote <> 'NONE')
        BEGIN
            /*
                Reemplazo del cursor ScrCreditMemo.
                Valida el total de importe asociado a la nota de crédito,
                independientemente de la factura.
            */
            SELECT
                @nCreditAmt = COALESCE(SUM(COALESCE(Cobza.Importe, 0)), 0)
            FROM T3.CFDI_Cobranza AS Cobza
            WHERE Cobza.Nota_Credito = @sCreditNote;

            IF (
                   ABS(@nAmount - @nInvoiceAmt) < 0.50
                   AND ABS(@nAmount - @nCreditAmt) < 0.50
               )
            BEGIN
                SET @sReturn = 'Inv-Ok-ZLOB-Ok';
            END
            ELSE IF (ABS(@nAmount - @nCreditAmt) < 0.50)
            BEGIN
                SET @sReturn = 'ZLOB-Ok';
            END
            ELSE IF (ABS(@nAmount - @nInvoiceAmt) < 0.50)
            BEGIN
                SET @sReturn = 'Inv-Ok';
            END;
        END;
    END;

    RETURN @sReturn;
END;
GO