CREATE OR ALTER FUNCTION [EAI_OWNER].[GETCONV]
(
    @sType  VARCHAR(99),
    @sValue VARCHAR(99)
)
RETURNS VARCHAR(99)
AS
BEGIN
    DECLARE @sReturn VARCHAR(99);

    /*
        GETCONV
        Determinar la tabla de conversión entre V3/T3 y TaO.

        Comportamiento Oracle original:
        - Inicializa el retorno con sValue.
        - Busca en EAI_OWNER.MX_HashTable por Type + Source.
        - Si encuentra coincidencia, retorna Target.
        - Si no encuentra coincidencia, retorna el valor original.
    */

    SET @sReturn = @sValue;

    SELECT TOP (1)
        @sReturn = HT.[Target]
    FROM [EAI_OWNER].[MX_HashTable] AS HT
    WHERE HT.[Type] = @sType
      AND HT.[Source] = @sValue;

    RETURN @sReturn;
END;
GO