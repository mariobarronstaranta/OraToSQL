CREATE OR ALTER FUNCTION [T3].[FN_GET_PAY_REFERENCE_NEW]
(
    @P_ASIGNEMNT_ID VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sPaymentID     VARCHAR(50);
    DECLARE @sResult        VARCHAR(50);
    DECLARE @nCandidateRows INT;

    SET @sPaymentID = @P_ASIGNEMNT_ID;

    /*
        Migración de lógica Oracle:

        Oracle:
            sPaymentID := P_ASIGNEMNT_ID;

            Cursor:
                SELECT TRIM(TO_CHAR(Agrupacion))
                FROM T3.CFDI_Agrupacion_Pago
                WHERE Asignacion_ID = sPaymentID

                UNION

                SELECT Nota_Credito
                FROM T3.CFDI_Cobranza
                WHERE Asignacion_ID = sPaymentID
                  AND Via_Pago = 'CM'
                  AND Nota_Credito IS NOT NULL;

            FOR Doc IN ScrAggregated LOOP
                sPaymentID := Doc.Agrupacion;
            END LOOP;

        Nota:
            En Oracle, si el cursor devuelve varias filas, el resultado final depende
            del último registro iterado. Como no existe ORDER BY, el resultado no es
            formalmente determinístico.

        Decisión SQL Server:
            Usar MAX(Agrupacion) para obtener un resultado estable y repetible.
    */

    SELECT
        @nCandidateRows = COUNT(1),
        @sResult = MAX(C.Agrupacion)
    FROM
    (
        SELECT
            LTRIM(RTRIM(CONVERT(VARCHAR(50), A.Agrupacion))) AS Agrupacion
        FROM [T3].[CFDI_Agrupacion_Pago] A
        WHERE A.Asignacion_ID = @sPaymentID

        UNION

        SELECT
            LTRIM(RTRIM(CONVERT(VARCHAR(50), C.Nota_Credito))) AS Agrupacion
        FROM [T3].[CFDI_Cobranza] C
        WHERE C.Asignacion_ID = @sPaymentID
          AND C.Via_Pago = 'CM'
          AND C.Nota_Credito IS NOT NULL
    ) C;

    IF @nCandidateRows > 0
    BEGIN
        SET @sPaymentID = @sResult;
    END;

    RETURN @sPaymentID;
END;
GO