CREATE OR ALTER FUNCTION [EAI_OWNER].[IC_CHECK_DOCUMENT]
(
    @pSociedad  VARCHAR(50),
    @pEjercicio VARCHAR(50),
    @pDocumento VARCHAR(50),
    @pPreventa  VARCHAR(50),
    @pOtros     VARCHAR(50)
)
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @sReturn VARCHAR(100) = 'Ok';

    /*
        Migración de Oracle a SQL Server:
        - Se elimina el cursor ScrClaseDocto.
        - La lógica original sólo necesita saber si existen clases AB o SA.
        - El parámetro @pOtros se conserva por compatibilidad, aunque no se usa
          en la función Oracle original.
    */

    IF EXISTS
    (
        SELECT 1
        FROM [EAI_OWNER].[IC_Cobranza] AS IC
        WHERE IC.Sociedad           = @pSociedad
          AND IC.Ejercicio_Fiscal   = @pEjercicio
          AND IC.Docto_Compensacion = @pDocumento
          AND IC.Clase_Docto        = 'AB'
    )
    BEGIN
        SET @sReturn = 'Error';
    END
    ELSE IF LEN(COALESCE(@pPreventa, '')) > 0
        AND EXISTS
        (
            SELECT 1
            FROM [EAI_OWNER].[IC_Cobranza] AS IC
            WHERE IC.Sociedad           = @pSociedad
              AND IC.Ejercicio_Fiscal   = @pEjercicio
              AND IC.Docto_Compensacion = @pDocumento
              AND IC.Clase_Docto        = 'SA'
        )
    BEGIN
        SET @sReturn = 'Error';
    END;

    RETURN @sReturn;
END;
GO