USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_VALIDA_RFC]    Script Date: 10/27/2026 5:13:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[FN_VALIDA_RFC]
(
    @sRFC VARCHAR(50)
)
RETURNS DECIMAL(2, 0)
AS
BEGIN
    DECLARE @nReturn DECIMAL(2, 0);
    DECLARE @sFunction VARCHAR(15);
    DECLARE @nIndex INT;
    DECLARE @nDigits INT;
    DECLARE @nChars INT;
    DECLARE @nCharX INT;
    DECLARE @sChar CHAR(1);

    IF @sRFC IS NULL
        RETURN 0;

    SET @nReturn = 0;
    SET @sFunction = LTRIM(RTRIM(@sRFC));
    SET @nIndex = 0;
    SET @nDigits = 0;
    SET @nChars = 0;
    SET @nCharX = 0;

    WHILE 1 = 1
    BEGIN
        SET @nIndex = @nIndex + 1;

        IF @nIndex > LEN(ISNULL(@sFunction, ''))
        BEGIN
            SET @nIndex = @nIndex - 1;
            BREAK;
        END;

        SET @sChar = SUBSTRING(@sFunction, @nIndex, 1);

        IF CHARINDEX(@sChar, '0123456789') > 0
            SET @nDigits = @nDigits + 1;

        IF CHARINDEX(UPPER(@sChar), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') > 0
            SET @nChars = @nChars + 1;

        IF CHARINDEX(UPPER(@sChar), 'X') > 0
            SET @nCharX = @nCharX + 1;
    END;

    IF @nDigits >= 6 AND @nChars >= 3 AND @nIndex IN (12, 13)
        SET @nReturn = 1;

    IF @nCharX >= 3
        SET @nReturn = -1;

    RETURN @nReturn;
END;
