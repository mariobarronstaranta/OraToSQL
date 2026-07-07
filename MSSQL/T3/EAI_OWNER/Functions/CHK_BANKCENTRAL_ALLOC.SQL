CREATE FUNCTION EAI_Owner.CHK_BANKCENTRAL_ALLOC
(
    @pIdocNumber VARCHAR(99)
)
RETURNS VARCHAR(4)
AS
BEGIN
    DECLARE @sReturn         VARCHAR(4)  = 'YES';
    DECLARE @sAccntDocNumber VARCHAR(99);
    DECLARE @sFiscalYear     VARCHAR(4);
    DECLARE @nBaseCount      INT;

    /*
        Oracle original:
        SELECT Doc.AccntDocNumber, SUBSTR(Doc.ClearingDate, 1, 4)
        INTO sAccntDocNumber, sFiscalYear
        FROM EAI_Owner.tmp_Account_Header Doc
        WHERE Doc.IDocNumber LIKE '%' || pIdocNumber;

        En Oracle:
        - 0 filas  => NO_DATA_FOUND => RETURN 'NO'
        - >1 fila  => TOO_MANY_ROWS => RETURN 'NO'

        En SQL Server se valida explícitamente para conservar esa lógica.
    */

    SELECT
        @nBaseCount = COUNT(*)
    FROM EAI_Owner.tmp_Account_Header AS Doc
    WHERE Doc.IDocNumber LIKE CONCAT('%', @pIdocNumber);

    IF ISNULL(@nBaseCount, 0) <> 1
        RETURN 'NO';

    SELECT
        @sAccntDocNumber = Doc.AccntDocNumber,
        @sFiscalYear     = SUBSTRING(Doc.ClearingDate, 1, 4)
    FROM EAI_Owner.tmp_Account_Header AS Doc
    WHERE Doc.IDocNumber LIKE CONCAT('%', @pIdocNumber);

    /*
        Si no se pudo obtener información base válida,
        se replica el comportamiento defensivo del EXCEPTION => 'NO'.
    */
    IF @sAccntDocNumber IS NULL OR @sFiscalYear IS NULL
        RETURN 'NO';

    /*
        Cursor Oracle sustituido por EXISTS:
        Si existe una asignación relacionada ya procesada, retorna NO.
    */
    IF EXISTS
    (
        SELECT 1
        FROM EAI_Owner.tmp_Account_Header AS Doc
        WHERE Doc.AccntDocNumber = @sAccntDocNumber
          AND SUBSTRING(Doc.ClearingDate, 1, 4) = @sFiscalYear
          AND Doc.DocumentType = 'ZV'
          AND Doc.DocumentHeaderText = 'B001 - Bank Itemization'
          AND Doc.IDocNumber NOT LIKE CONCAT('%', @pIdocNumber)
          AND Doc.Processed IS NOT NULL
    )
    BEGIN
        SET @sReturn = 'NO';
    END;

    RETURN @sReturn;
END;
GO