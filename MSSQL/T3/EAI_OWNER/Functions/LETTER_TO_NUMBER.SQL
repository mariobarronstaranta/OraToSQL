CREATE OR ALTER FUNCTION [EAI_OWNER].[LETTER_TO_NUMBER]
(
    @p_value VARCHAR(30)
)
RETURNS DECIMAL(38,0)
AS
BEGIN
    DECLARE
        @nReturn DECIMAL(38,0) = 0,
        @i       INT = 1,
        @len     INT,
        @char    CHAR(1);

    IF ISNULL(@p_value, '-') = '-'
        RETURN 0;

    SET @p_value = UPPER(@p_value);
    SET @len = LEN(@p_value);

    IF @len > 15
        RETURN 0;

    WHILE @i <= @len
    BEGIN
        SET @char = SUBSTRING(@p_value, @i, 1);

        IF @char < 'A' OR @char > 'Z'
            RETURN 0;

        SET @nReturn = (@nReturn * 26) + (ASCII(@char) - 64);
        SET @i += 1;
    END;

    RETURN @nReturn;
END;
GO
