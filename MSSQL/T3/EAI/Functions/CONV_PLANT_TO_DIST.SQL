CREATE FUNCTION EAI.CONV_PLANT_TO_DIST
(
    @sPlant VARCHAR(10)
)
RETURNS INT
AS
BEGIN
    DECLARE @sReturn VARCHAR(10);
    DECLARE @nReturn INT;

    -- Equivalente a EAI_Owner.getConv
    SELECT @sReturn = [EAI_OWNER].[GETCONV]('T3 Plant to Dist', @sPlant);

    -- Preserva la lógica original del desarrollador Oracle
    IF (@sReturn = @sPlant)
        SET @nReturn = 0;
    ELSE
        SET @nReturn = TRY_CAST(@sReturn AS INT);  -- Mitigación crítica

    RETURN ISNULL(@nReturn, 0);
END;
GO
