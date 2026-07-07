CREATE OR ALTER FUNCTION dbo.GETNEXTRUN
(
    @nReplication DECIMAL(38,10),
    @dtNextRun    DATETIME2(0),
    @dtNextXML    DATETIME2(0)
)
RETURNS DATETIME2(0)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @dtReturn DATETIME2(0);

    SET @dtReturn =
        CASE
            WHEN @nReplication > 0 THEN @dtNextRun
            ELSE @dtNextXML
        END;

    RETURN @dtReturn;
END;
GO