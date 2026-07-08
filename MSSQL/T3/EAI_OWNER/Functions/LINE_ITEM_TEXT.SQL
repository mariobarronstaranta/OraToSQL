CREATE OR ALTER FUNCTION [EAI_OWNER].[LINE_ITEM_TEXT]
(
    @pLineItem VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE
        @sReturn   VARCHAR(50),
        @sLineItem VARCHAR(50) = LTRIM(RTRIM(ISNULL(@pLineItem, '0'))),
        @nLength   INT;

    SET @nLength = CHARINDEX('/', @sLineItem);

    IF @nLength = 0
        SET @sReturn = @sLineItem;
    ELSE
        SET @sReturn = SUBSTRING(@sLineItem, @nLength + 1, 10);

    RETURN @sReturn;
END;
GO
