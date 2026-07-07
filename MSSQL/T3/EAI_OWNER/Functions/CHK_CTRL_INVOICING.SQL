CREATE OR ALTER FUNCTION EAI_OWNER.CHK_CTRL_INVOICING
(
    @pSAP_Customer   VARCHAR(50),
    @pDocumentDate   VARCHAR(8),
    @pDC_Indicator   VARCHAR(1) = 'S'
)
RETURNS INT
AS
BEGIN
    DECLARE @nReturn INT = 0;
    DECLARE @DocumentDate DATE;

    /*
        Oracle:
            TO_DATE(pDocumentDate, 'YYYYMMDD')

        SQL Server:
            TRY_CONVERT(date, @pDocumentDate, 112)

        Si la fecha es inválida, TRY_CONVERT devuelve NULL.
        Esto replica el comportamiento del EXCEPTION WHEN OTHERS RETURN 0.
    */
    SET @DocumentDate = TRY_CONVERT(DATE, @pDocumentDate, 112);

    IF @DocumentDate IS NULL
        RETURN 0;

    /*
        Regla de negocio:
        Si el indicador es 'H', retorna 0 aunque exista vigencia.

        Se usa COLLATE Latin1_General_BIN2 para preservar comparación exacta,
        evitando que una collation case-insensitive trate 'h' como 'H'.
    */
    IF @pDC_Indicator COLLATE Latin1_General_BIN2 = 'H'
        RETURN 0;

    /*
        El cursor Oracle solo necesitaba detectar existencia.
        EXISTS es más eficiente y preserva el resultado final.
    */
    IF EXISTS
    (
        SELECT 1
        FROM EAI_OWNER.WA_VENTA_CENTRALIZADA VC
        WHERE VC.Cliente_SAP = @pSAP_Customer
          AND @DocumentDate BETWEEN VC.Fecha_Ini_Vig AND VC.Fecha_Fin_Vig
    )
    BEGIN
        SET @nReturn = 1;
    END;

    RETURN @nReturn;
END;
GO