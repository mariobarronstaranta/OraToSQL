/*
    Funcion  : EAI_OWNER.GETCONV
    Objetivo : Obtener una equivalencia de EAI_OWNER.MX_HashTable.

    Guia para desarrolladores JR:
    - @sType identifica el catalogo o grupo de conversiones.
    - @sValue es el valor que se desea traducir.
    - Si existe Type + Source, se devuelve Target.
    - Si no existe, se conserva @sValue. Este fallback es parte del contrato.
    - TOP (1) conserva el comportamiento historico cuando existen duplicados.
      El catalogo debe evitar duplicar una pareja Type + Source.

    Esta version es escalar y mantiene los mismos parametros y tipo de retorno
    que GETCONV. El nombre paralelo permite validarla antes de sustituir callers.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EAI_OWNER].[GETCONV]
(
    @sType  VARCHAR(99),
    @sValue VARCHAR(99)
)
RETURNS VARCHAR(99)
WITH SCHEMABINDING
AS
BEGIN
    -- El valor de entrada es también la respuesta cuando no hay conversión.
    DECLARE @sReturn VARCHAR(99) = @sValue;

    /*
        El índice existente MX_HASHTABLE_IX (Type, Source) permite localizar
        la conversión sin recorrer todo el catálogo.

        No se usa ISNULL/COALESCE sobre Target: si existe una conversión cuyo
        Target es NULL, el procedimiento Oracle devuelve NULL y aquí se debe
        conservar esa misma regla.
    */
    SELECT TOP (1)
        @sReturn = HT.[Target]
    FROM [EAI_OWNER].[MX_HashTable] AS HT
    WHERE HT.[Type] = @sType
      AND HT.[Source] = @sValue;

    RETURN @sReturn;
END;
GO
