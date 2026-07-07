CREATE OR ALTER FUNCTION dbo.FN_GET_TAX_ISSUE
(
    @P_FACTURA VARCHAR(50)
)
RETURNS DECIMAL(6,2)
AS
BEGIN
    DECLARE @nAjuste DECIMAL(6,2);

    SET @nAjuste = 0;

    /*
        Equivalente funcional al cursor Oracle:

        FOR Doc IN ScrDocto LOOP
            nAjuste := Doc.Diferencia;
        END LOOP;

        Nota:
        Si existe más de una fila para la misma Factura, SQL Server,
        igual que Oracle sin ORDER BY, no garantiza un resultado determinístico.
    */
    SELECT 
        @nAjuste = CAST(COALESCE(Diferencia, 0) AS DECIMAL(6,2))
    FROM T3.NDC_ISSUE_IVA
    WHERE Factura = @P_FACTURA;

    RETURN @nAjuste;
END;
GO