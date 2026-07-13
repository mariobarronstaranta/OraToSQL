CREATE OR ALTER FUNCTION EAI_OWNER.CURRENCY_TEXT
(
    @pCurrency VARCHAR(50),
    @pType     VARCHAR(10) = 'Doc'
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sReturn    VARCHAR(50);
    DECLARE @nLength    INT;
    DECLARE @sCurrency  VARCHAR(50);
    DECLARE @sCurrDoc   VARCHAR(50);
    DECLARE @sCurrLocal VARCHAR(50);

    /*
        Oracle:
            sCurrency := TRIM(NVL(pCurrency, '0'));

        Consideración:
            En Oracle, '' se trata como NULL.
            En SQL Server, '' no es NULL.
            Por eso se usa NULLIF para preservar el comportamiento.
    */
    SET @sCurrency = TRIM(COALESCE(NULLIF(@pCurrency, ''), '0'));

    /*
        Oracle:
            nLength := INSTR(sCurrency, '/');

        SQL Server:
            CHARINDEX devuelve 0 si no encuentra el carácter.
    */
    SET @nLength = CHARINDEX('/', @sCurrency);

    IF (@nLength = 0)
    BEGIN
        SET @sCurrDoc   = @sCurrency;
        SET @sCurrLocal = @sCurrency;
    END
    ELSE
    BEGIN
        SET @sCurrDoc   = SUBSTRING(@sCurrency, 1, @nLength - 1);

        /*
            Oracle:
                SUBSTR(sCurrency, nLength + 1, 10)

            Se preserva longitud 10 para mantener compatibilidad funcional.
        */
        SET @sCurrLocal = SUBSTRING(@sCurrency, @nLength + 1, 10);
    END;

    IF (UPPER(@pType) = 'DOC')
    BEGIN
        SET @sReturn = @sCurrDoc;
    END
    ELSE
    BEGIN
        SET @sReturn = @sCurrLocal;
    END;

    RETURN @sReturn;
END;
GO