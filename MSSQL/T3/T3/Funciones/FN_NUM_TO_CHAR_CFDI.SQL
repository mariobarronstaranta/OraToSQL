USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_NUM_TO_CHAR_CFDI]    Script Date: 11/11/2026 2:38:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[FN_NUM_TO_CHAR_CFDI]
(
    @pValue DECIMAL(38, 10),
    @pDecimals INT = 0
)
RETURNS VARCHAR(200)
AS
BEGIN
    DECLARE @rParameter VARCHAR(200);
    DECLARE @sMask VARCHAR(30);
    DECLARE @nDecimals INT;

    SET @sMask = '99999999999990';
    SET @nDecimals = @pDecimals;

    IF ISNULL(@pValue, 0) <> ROUND(ISNULL(@pValue, 0), 0, 1)
    BEGIN
        SET @nDecimals = 2;
        IF @nDecimals < ISNULL(@pDecimals, 0)
            SET @nDecimals = @pDecimals;
    END;

    IF ISNULL(@nDecimals, 0) > 0
        SET @sMask = @sMask + '.' + REPLICATE('9', @nDecimals);

    SET @rParameter = LTRIM(RTRIM(STR(ISNULL(@pValue, 0), 30, ISNULL(@nDecimals, 0))));

    RETURN @rParameter;
END;
