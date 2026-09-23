/*
    Funcion  : EAI_OWNER.FN_GET_TAX_ISSUE_OPTIMIZADO
    Objetivo : Obtener el ajuste de IVA registrado para una factura.

    Guia para desarrolladores JR:
    - La información se consulta en T3.NDC_ISSUE_IVA.
    - Cuando no existe la factura, el resultado es 0.00.
    - Si Diferencia es NULL, también se devuelve 0.00.
    - La tabla histórica permite duplicados. Por compatibilidad no se agrega
      TOP, ORDER BY, SUM o MAX, porque cualquiera de ellos cambiaría la regla
      de la función original y del cursor Oracle.
    - El índice NDC_ISSUE_IVA_FACTURA_IX evita recorrer toda la tabla para
      localizar una factura.

    La versión es paralela: no reemplaza FN_GET_TAX_ISSUE ni modifica callers.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EAI_OWNER].[FN_GET_TAX_ISSUE_OPTIMIZADO]
(
    @P_FACTURA VARCHAR(50)
)
RETURNS DECIMAL(6,2)
WITH SCHEMABINDING
AS
BEGIN
    -- Valor por defecto cuando no existe una incidencia para la factura.
    DECLARE @nAjuste DECIMAL(6,2) = CONVERT(DECIMAL(6,2), 0);

    /*
        La asignación se conserva sin TOP ni ORDER BY. Si hay duplicados, el
        resultado no es determinista, igual que en la implementación original.
        El problema de duplicados debe corregirse en los datos y en el proceso
        WA_DIF_IVA_SAP_T3, no ocultarse dentro de esta función.
    */
    SELECT
        @nAjuste = ISNULL(I.Diferencia, CONVERT(DECIMAL(6,2), 0))
    FROM [T3].[NDC_ISSUE_IVA] AS I
    WHERE I.Factura = @P_FACTURA;

    RETURN @nAjuste;
END;
GO
