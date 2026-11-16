USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[FN_ADJUST_GMT]    Script Date: 11/11/2026 2:37:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[FN_ADJUST_GMT]
(
    @p_Time VARCHAR(8),
    @p_Hours DECIMAL(38, 10) = 0
)
RETURNS VARCHAR(8)
AS
BEGIN
    DECLARE @sReturn VARCHAR(8);
    DECLARE @dtDateOriginal DATETIME2(0);
    DECLARE @dtDateCalculated DATETIME2(0);

    SET @p_Time = NULLIF(@p_Time, '');
    SET @dtDateOriginal = CONVERT(DATETIME2(0), CONCAT(CONVERT(CHAR(10), CAST(SYSDATETIME() AS DATE), 120), ' ', @p_Time), 120);
    SET @dtDateCalculated = DATEADD(SECOND, CONVERT(INT, ROUND(COALESCE(@p_Hours, 0) * 3600, 0)), @dtDateOriginal);

    IF CONVERT(DATE, @dtDateOriginal) <> CONVERT(DATE, @dtDateCalculated)
    BEGIN
        SET @sReturn = @p_Time;
        SET @sReturn = '00:00:01';
    END
    ELSE
    BEGIN
        SET @sReturn = CONVERT(CHAR(8), @dtDateCalculated, 108);
    END;

    RETURN @sReturn;
END;
