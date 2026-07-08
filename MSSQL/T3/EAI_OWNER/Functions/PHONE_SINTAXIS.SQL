CREATE OR ALTER FUNCTION [EAI_OWNER].[PHONE_SINTAXIS]
(
    @pPhoneNumber VARCHAR(50),
    @pPhoneType   VARCHAR(10)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE
        @sReturn      VARCHAR(50) = NULL,
        @sPhoneNumber VARCHAR(50),
        @nLength      INT;

    SET @sPhoneNumber = LTRIM(RTRIM(@pPhoneNumber));
    SET @sPhoneNumber = REPLACE(@sPhoneNumber, '+52', '');
    SET @nLength = LEN(@sPhoneNumber);

    IF @pPhoneType = 'P'
    BEGIN
        IF @nLength < 10
            SET @sReturn = '9999999999';
        ELSE IF @nLength = 10
            SET @sReturn = @sPhoneNumber;
        ELSE
            SET @sReturn = SUBSTRING(@sPhoneNumber, 1, 10);
    END
    ELSE IF @pPhoneType = 'F'
    BEGIN
        IF @pPhoneNumber IS NULL OR @nLength = 0
            SET @sReturn = '';
        ELSE IF @nLength < 10
            SET @sReturn = '9999999999';
        ELSE IF @nLength = 10
            SET @sReturn = @sPhoneNumber;
        ELSE
            SET @sReturn = SUBSTRING(@sPhoneNumber, 1, 10);
    END;

    IF @sReturn = '9999999999'
        SET @sReturn = '';

    RETURN @sReturn;
END;
GO
