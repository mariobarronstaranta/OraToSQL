CREATE OR ALTER FUNCTION dbo.GET_4428_REFERENCE
(
    @pAssignment VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @sReturn VARCHAR(50);

    SET @sReturn = @pAssignment;

    /*
        GET_4428_REFERENCE
        Determina la Referencia / Asignación para TaO.

        Regla funcional:
        1. Buscar primero en documentos Prompt.
        2. Si no existe en Prompt, buscar en Presales.
        3. Si no existe coincidencia, devolver el valor original recibido.

        Nota:
        La versión Oracle usa cursores con UNION sin ORDER BY.
        Esta versión agrega prioridad explícita para hacer el resultado determinístico.
    */

    ;WITH CandidateReferences AS
    (
        -- Prompt: prioridad más alta
        SELECT
            CAST(FG.Factura AS VARCHAR(50)) AS Factura,
            FG.Cliente_SAP,
            FG.Fecha_Proc_BATMD AS FechaDocumento,
            1 AS GrupoPrioridad,
            1 AS ReglaPrioridad
        FROM T3.Factura_General AS FG
        WHERE FG.Factura = @pAssignment

        UNION ALL

        SELECT
            CAST(RF.Factura AS VARCHAR(50)) AS Factura,
            RF.Cliente_SAP,
            RF.Fecha_Factura AS FechaDocumento,
            1 AS GrupoPrioridad,
            2 AS ReglaPrioridad
        FROM T3.Registro_Fiscal AS RF
        WHERE RF.Entrega = @pAssignment

        UNION ALL

        -- Presales: sólo aplica si no hay Prompt.
        SELECT
            CAST(PG.Factura AS VARCHAR(50)) AS Factura,
            PG.Cliente_SAP,
            PG.Fecha_Proc_BATMD AS FechaDocumento,
            2 AS GrupoPrioridad,
            1 AS ReglaPrioridad
        FROM T3.Preventa_General AS PG
        WHERE PG.Factura = @pAssignment

        UNION ALL

        SELECT
            CAST(PG.Factura AS VARCHAR(50)) AS Factura,
            PG.Cliente_SAP,
            PG.Fecha_Proc_BATMD AS FechaDocumento,
            2 AS GrupoPrioridad,
            2 AS ReglaPrioridad
        FROM T3.Preventa_General AS PG
        WHERE PG.Entrega = @pAssignment

        UNION ALL

        SELECT
            CAST(PG.Factura AS VARCHAR(50)) AS Factura,
            PG.Cliente_SAP,
            PG.Fecha_Proc_BATMD AS FechaDocumento,
            2 AS GrupoPrioridad,
            3 AS ReglaPrioridad
        FROM T3.Preventa_General AS PG
        WHERE PG.Referencia = @pAssignment
    )
    SELECT TOP (1)
        @sReturn = CR.Factura
    FROM CandidateReferences AS CR
    WHERE CR.Factura IS NOT NULL
    ORDER BY
        CR.GrupoPrioridad ASC,
        CR.ReglaPrioridad ASC,
        CR.FechaDocumento DESC,
        CR.Factura DESC;

    RETURN @sReturn;
END;
GO