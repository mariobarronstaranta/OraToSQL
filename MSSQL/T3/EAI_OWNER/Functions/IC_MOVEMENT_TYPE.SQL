CREATE OR ALTER FUNCTION [EAI_OWNER].[IC_MOVEMENT_TYPE]
(
    @pClase_Docto        VARCHAR(50),
    @pClave_Contable     DECIMAL(18,0),
    @pDocto_Compensacion VARCHAR(50),
    @pDocumento          VARCHAR(50),
    @pReferencia         VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sReturn VARCHAR(50) = 'No aplica';

    IF @pClase_Docto = 'RV'
       AND @pClave_Contable = 1
       AND @pDocto_Compensacion <> @pDocumento
       AND @pReferencia IS NOT NULL
        SET @sReturn = 'Pago Completo';
    ELSE IF @pClase_Docto = 'CR'
        AND @pClave_Contable = 4
        AND @pDocto_Compensacion <> @pDocumento
        AND @pReferencia IS NOT NULL
        SET @sReturn = 'Pago Parcial';
    ELSE IF @pClase_Docto = 'CR'
        AND @pClave_Contable = 17
        AND @pReferencia IS NOT NULL
        SET @sReturn = 'Pago Restante';

    RETURN @sReturn;
END;
GO
