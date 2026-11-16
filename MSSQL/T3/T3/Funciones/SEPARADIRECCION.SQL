USE [T3QA]
GO
/****** Object:  UserDefinedFunction [T3].[SEPARADIRECCION]    Script Date: 11/12/2026 10:10:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   FUNCTION [T3].[SEPARADIRECCION]
(
    @sAddr_Name VARCHAR(300),
    @sCampo VARCHAR(20)
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @sReturn VARCHAR(100);
    DECLARE @sCalle VARCHAR(100);
    DECLARE @sExterno VARCHAR(100);
    DECLARE @sColonia VARCHAR(100);
    DECLARE @nLongitud INT;

    SET @sAddr_Name = NULLIF(@sAddr_Name, '');
    SET @sCampo = NULLIF(@sCampo, '');
    SET @sCalle = '';
    SET @sExterno = '';
    SET @sColonia = '';
    SET @nLongitud = CHARINDEX('#', COALESCE(@sAddr_Name, ''));

    IF @nLongitud > 0
    BEGIN
        SET @sCalle = SUBSTRING(@sAddr_Name, 1, @nLongitud - 1);
        SET @sReturn = SUBSTRING(@sAddr_Name, @nLongitud, 100);
        SET @nLongitud = CHARINDEX('|', COALESCE(@sReturn, ''));

        IF @nLongitud > 0
        BEGIN
            SET @sExterno = SUBSTRING(@sReturn, 1, @nLongitud - 1);
            SET @sColonia = SUBSTRING(@sReturn, @nLongitud + 1, 99);
        END
        ELSE
        BEGIN
            SET @sExterno = @sReturn;
        END;
    END
    ELSE
    BEGIN
        SET @sCalle = @sAddr_Name;
        SET @sExterno = '';
        SET @sColonia = '';
    END;

    IF @sCampo = 'Calle'
        SET @sReturn = @sCalle;
    ELSE IF @sCampo = 'Num'
    BEGIN
        SET @sReturn = @sExterno;
        IF SUBSTRING(COALESCE(@sReturn, ''), 1, 1) = '#'
            SET @sReturn = LTRIM(RTRIM(SUBSTRING(@sReturn, 2, 100)));
    END
    ELSE IF @sCampo = 'Col'
        SET @sReturn = @sColonia;

    SET @sReturn = LTRIM(RTRIM(@sReturn));
    RETURN @sReturn;
END;
