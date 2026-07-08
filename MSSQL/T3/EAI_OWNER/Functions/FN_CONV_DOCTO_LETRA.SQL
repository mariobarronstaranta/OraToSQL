CREATE OR ALTER FUNCTION EAI_OWNER.FN_CONV_DOCTO_LETRA
(
    @pDoctos NUMERIC(18, 0)
)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @sDocType  VARCHAR(10);
    DECLARE @nEntero   INT;
    DECLARE @nResiduo  INT;
    DECLARE @nBase     INT;
    DECLARE @nCharBase INT;

    SET @nCharBase = 64;
    SET @nBase     = 26;

    IF ISNULL(@pDoctos, 0) = 0
        RETURN '0';

    /*
        Equivalente a:
        nEntero  := TRUNC(pDoctos / nBase)
        nResiduo := MOD(pDoctos, nBase)
    */
    SET @nEntero  = FLOOR(@pDoctos / @nBase);
    SET @nResiduo = CAST(@pDoctos AS INT) % @nBase;

    IF (@pDoctos > 0 AND @nResiduo = 0)
    BEGIN
        SET @nEntero  = @nEntero - 1;
        SET @nResiduo = @nBase;
    END;

    IF (@nEntero >= 1)
        SET @sDocType = CHAR(@nCharBase + @nEntero);
    ELSE
        SET @sDocType = '';

    SET @sDocType = @sDocType + CHAR(@nCharBase + @nResiduo);

    RETURN @sDocType;
END;
GO