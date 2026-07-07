CREATE OR ALTER FUNCTION [EAI_Owner].[GETCONV_COLONIA]
(
    @sMunicipio      VARCHAR(50),
    @sColoniaNombre  VARCHAR(200),
    @sTipoRetorno    VARCHAR(10) = 'Col'
)
RETURNS VARCHAR(30)
AS
BEGIN
    DECLARE @sReturn VARCHAR(30);

    /*
        Migración de Oracle GETCONV_COLONIA a SQL Server.

        Oracle:
        - Inicializa sReturn := '', que en Oracle equivale a NULL.
        - Recorre cursor sin ORDER BY.
        - Si hay varias coincidencias, devuelve el último valor leído.
        - Si no hay coincidencias o el tipo de retorno no es válido, devuelve NULL.

        SQL Server:
        - Se elimina cursor.
        - Se usa TOP (1) con ORDER BY para resultado determinístico.
        - Se conserva NULL como valor de no encontrado.
    */

    SET @sReturn = NULL;

    SELECT TOP (1)
        @sReturn =
            CASE @sTipoRetorno
                WHEN 'Col' THEN CAST(HT.c_Colonia AS VARCHAR(30))
                WHEN 'CP'  THEN CAST(HT.c_CodigoPostal AS VARCHAR(30))
                WHEN 'SAT' THEN CAST(HT.c_CodigoPostal_SAT AS VARCHAR(30))
                ELSE NULL
            END
    FROM [EAI_Owner].[CAT_OFICIAL_COLONIA] HT
    WHERE HT.c_Municipio = @sMunicipio
      AND HT.c_NombreAsentamiento = @sColoniaNombre
    ORDER BY 
        HT.c_Colonia,
        HT.c_CodigoPostal,
        HT.c_CodigoPostal_SAT;

    RETURN @sReturn;
END;
GO