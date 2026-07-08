CREATE OR ALTER FUNCTION EAI_OWNER.FN_GET_PAY_REFERENCE
(
    @P_ASIGNEMNT_ID VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sPaymentID VARCHAR(50);

    SET @sPaymentID = @P_ASIGNEMNT_ID;

    /*
        Migración de Oracle:
        - VARCHAR2      -> VARCHAR
        - %TYPE         -> tipo explícito VARCHAR(50)
        - TO_CHAR       -> CONVERT(VARCHAR(50), ...)
        - TRIM          -> TRIM(...)
        - Cursor LOOP   -> SELECT TOP (1)
        - UNION         -> se conserva para eliminar duplicados

        Nota:
        La función Oracle sobrescribe sPaymentID por cada fila del cursor.
        Como no existe ORDER BY en Oracle, el resultado puede ser no determinístico
        cuando hay más de una fila. En esta versión se define orden explícito.
    */

    ;WITH Referencias AS
    (
        SELECT
            TRIM(CONVERT(VARCHAR(50), Agrupacion)) AS Agrupacion,
            1 AS Prioridad
        FROM T3.CFDI_Agrupacion_Pago
        WHERE Asignacion_ID = @sPaymentID

        UNION

        SELECT
            TRIM(CONVERT(VARCHAR(50), Nota_Credito)) AS Agrupacion,
            2 AS Prioridad
        FROM T3.CFDI_Cobranza
        WHERE Asignacion_ID = @sPaymentID
          AND Via_Pago = 'CM'
          AND Nota_Credito IS NOT NULL
    )
    SELECT TOP (1)
        @sPaymentID = Agrupacion
    FROM Referencias
    WHERE Agrupacion IS NOT NULL
    ORDER BY 
        Prioridad ASC,
        Agrupacion DESC;

    RETURN @sPaymentID;
END;
GO