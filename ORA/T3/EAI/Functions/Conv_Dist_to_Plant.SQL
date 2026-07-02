CREATE FUNCTION dbo.Conv_Dist_to_Plant
(
    @sDist VARCHAR(10)
)
RETURNS VARCHAR(4)
AS
BEGIN
    DECLARE @sReturn     VARCHAR(4);
    DECLARE @sReturnRet  VARCHAR(10);

    SELECT @sReturnRet = dbo.getConv('T3 Dist to Plant', @sDist);

    IF (@sReturnRet = @sDist)
        SET @sReturn = '    ';  -- cuatro espacios
    ELSE
        SET @sReturn = @sReturnRet;

    RETURN @sReturn;
END;
GO
