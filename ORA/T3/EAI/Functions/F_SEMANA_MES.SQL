CREATE OR ALTER FUNCTION EAI.F_SEMANA_MES
(
    @nSemana INT,
    @nAnio   INT
)
RETURNS INT
AS
BEGIN
    /*
        Funcion que en base a la semana y año
        genera el mes al que pertenece.

        Equivalencia Oracle:
        TO_CHAR(TO_DATE(fecha, 'yyyymmdd'), 'WW')

        En Oracle, 'WW' calcula la semana del año empezando en 1,
        tomando bloques de 7 días desde el 1 de enero.
        Fórmula equivalente:
        ((DAYOFYEAR(fecha) - 1) / 7) + 1
    */

    DECLARE @nMes INT = 0;

    ;WITH Meses AS
    (
        SELECT
            Mes = v.Mes,
            SemanaInicio =
                ((DATEPART(DAYOFYEAR, DATEFROMPARTS(@nAnio, v.Mes, 1)) - 1) / 7) + 1,
            SemanaFin =
                ((DATEPART(DAYOFYEAR, EOMONTH(DATEFROMPARTS(@nAnio, v.Mes, 1))) - 1) / 7) + 1
        FROM
        (
            VALUES
                (1), (2), (3), (4), (5), (6),
                (7), (8), (9), (10), (11), (12)
        ) v(Mes)
    )
    SELECT TOP (1)
        @nMes = Mes
    FROM Meses
    WHERE @nSemana BETWEEN SemanaInicio AND SemanaFin
    ORDER BY Mes;

    RETURN @nMes;
END;
GO