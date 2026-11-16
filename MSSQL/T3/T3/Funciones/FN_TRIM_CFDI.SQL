USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_TRIM_CFDI]    Script Date: 11/11/2026 2:37:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[FN_TRIM_CFDI]
(
    @p_Name VARCHAR(200)
)
RETURNS VARCHAR(200)
AS
BEGIN
    DECLARE @p_Parameter VARCHAR(200);

    SET @p_Parameter = NULLIF(LTRIM(RTRIM(COALESCE(@p_Name, ''))), '');
    SET @p_Parameter = REPLACE(@p_Parameter, '|', '/');
    SET @p_Parameter = REPLACE(@p_Parameter, '+', '');
    SET @p_Parameter = REPLACE(@p_Parameter, CHAR(13), '');
    SET @p_Parameter = REPLACE(@p_Parameter, CHAR(10), '');

    WHILE CHARINDEX('  ', ISNULL(@p_Parameter, '')) > 0
    BEGIN
       SET @p_Parameter = replace(ISNULL(@p_Parameter, ''),'  ',' ');
    END;

    RETURN NULLIF(@p_Parameter, '');
END;
