CREATE OR ALTER FUNCTION [EAI_OWNER].[GETNAMESPACE]
(
    @sType VARCHAR(100)
)
RETURNS VARCHAR(1000)
AS
BEGIN
    DECLARE @sReturn VARCHAR(1000);

    /*
        Oracle:
            sReturn := '';
        En Oracle, cadena vacía '' equivale a NULL.
        Por eso en SQL Server se deja @sReturn como NULL para preservar comportamiento.
    */

    SELECT 
        @sReturn = HT.[Reference]
    FROM [EAI_OWNER].[MX_Hash_NameSpace] AS HT
    WHERE HT.[Interface] = @sType;

    RETURN @sReturn;
END;
GO