CREATE OR ALTER FUNCTION EAI_OWNER.GETCONV_MP_CFD
(
    @sValue VARCHAR(30)
)
RETURNS VARCHAR(30)
AS
BEGIN
    DECLARE @sReturn VARCHAR(30);

    SET @sReturn = @sValue;

    SELECT TOP (1)
        @sReturn = CAST(HT.Source AS VARCHAR(30))
    FROM EAI_OWNER.MX_HashTable AS HT
    WHERE HT.[Type] = 'TMD_PAC Accnt Payment Method'
      AND HT.Target = @sValue;

    RETURN @sReturn;
END;
GO