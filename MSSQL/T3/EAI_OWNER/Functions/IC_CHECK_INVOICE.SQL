CREATE OR ALTER FUNCTION [EAI_OWNER].[IC_CHECK_INVOICE]
(
    @pFactura     VARCHAR(100),
    @pFechaDocto  DATETIME2(0),
    @pDocumento   VARCHAR(100)
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @nReturn BIGINT;

    /*
        Migración de Oracle Function: IC_CHECK_INVOICE

        Lógica original:
        - Abría cursor sobre EAI_Owner.IC_PARCIAL
        - Filtraba por Factura = pFactura
        - Sumaba 1 por cada registro encontrado
        - Retornaba el conteo

        Mejora aplicada:
        - Se elimina cursor.
        - Se reemplaza por COUNT_BIG(*), operación set-based.
        - Se conservan parámetros de entrada aunque pFechaDocto y pDocumento
          no sean usados en la lógica original.
    */

    SELECT @nReturn = COUNT_BIG(1)
    FROM [EAI_OWNER].[IC_PARCIAL] AS IP
    WHERE IP.[Factura] = @pFactura;

    RETURN @nReturn;
END;
GO