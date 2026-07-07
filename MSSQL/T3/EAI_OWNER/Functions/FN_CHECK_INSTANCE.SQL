CREATE OR ALTER FUNCTION EAI_OWNER.FN_CHECK_INSTANCE
(
    @pInstanceName VARCHAR(300)
)
RETURNS VARCHAR(3)
AS
BEGIN
    DECLARE @sReturn VARCHAR(3) = 'NO';

    /*
        Migración de Oracle FN_CHECK_INSTANCE a SQL Server.

        Lógica original:
        - Buscar en EAI_Owner.MX_HashTable las configuraciones:
            Type = 'CFG Settings'
            Source LIKE 'Instance%'
        - Validar si pInstanceName existe dentro de los Target configurados.
        - Retornar 'YES' o 'NO'.

        Mejora aplicada:
        - Se elimina cursor.
        - Se elimina concatenación manual con '*'.
        - Se valida coincidencia exacta contra Target.
        - Se controla NULL de entrada.
    */

    IF @pInstanceName IS NULL OR LTRIM(RTRIM(@pInstanceName)) = ''
    BEGIN
        RETURN @sReturn;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM EAI_OWNER.MX_HashTable AS HT
        WHERE HT.[Type] = 'CFG Settings'
          AND HT.[Source] LIKE 'Instance%'
          AND LTRIM(RTRIM(HT.[Target])) = LTRIM(RTRIM(@pInstanceName))
    )
    BEGIN
        SET @sReturn = 'YES';
    END;

    RETURN @sReturn;
END;
GO