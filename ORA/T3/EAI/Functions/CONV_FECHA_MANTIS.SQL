CREATE OR ALTER FUNCTION EAI.CONV_FECHA_MANTIS
(
    @dtFecha DATETIME
)
RETURNS VARCHAR(14)
AS
BEGIN

    DECLARE @Resultado VARCHAR(14);

    SELECT
        @Resultado =
            CAST(
                Valor_Ref +
                DATEDIFF(SECOND, Referencia, @dtFecha)
            AS VARCHAR(14))
    FROM Z_MANTIS_DATE_REF;

    RETURN @Resultado;

END;
GO