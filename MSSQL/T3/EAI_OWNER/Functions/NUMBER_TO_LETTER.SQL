CREATE OR ALTER FUNCTION [EAI_OWNER].[NUMBER_TO_LETTER]
(
    @p_value DECIMAL(38,0)
)
RETURNS VARCHAR(30)
AS
BEGIN
    DECLARE
        @nValue  DECIMAL(38,0) = @p_value,
        @residuo INT,
        @sReturn VARCHAR(30) = '';

    IF ISNULL(@p_value, -1) <= 0
        RETURN NULL;

    WHILE @nValue > 0
    BEGIN
        SET @residuo = CONVERT(INT, (@nValue - 1) % 26) + 1;
        SET @sReturn = CHAR(@residuo + 64) + @sReturn;
        SET @nValue = FLOOR((@nValue - 1) / 26);
    END;

    RETURN @sReturn;
END;
GO
