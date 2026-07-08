CREATE OR ALTER FUNCTION EAI_OWNER.CHK_ZLOB_DOCUMENT
(
    @pReferenceID VARCHAR(99)
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @sReturn VARCHAR(20) = 'Ok';

    /*
        Migración de Oracle:
        - Cursor ScrDocument -> CTE / EXISTS
        - Cursor ScrReverse  -> EXISTS / NOT EXISTS
        - BOOLEAN            -> lógica booleana en predicados
        - Outer join (+)     -> LEFT JOIN
        - LENGTH             -> DATALENGTH para no perder espacios finales en VARCHAR
    */

    IF EXISTS
    (
        SELECT 1
        FROM T3.Preventa_General PG
        LEFT JOIN T3.CFDI_Documentos CFD
            ON CFD.Nota_Venta = PG.Factura
        INNER JOIN EAI_Owner.tmp_Document_Header Doc
            ON Doc.ReferenceID = PG.Entrega
        WHERE PG.Factura = @pReferenceID

          -- Equivalente funcional de LENGTH(sReferenceReverse) > 5.
          -- Se usa DATALENGTH para evitar que LEN ignore espacios finales.
          AND DATALENGTH(COALESCE(CONVERT(VARCHAR(99), Doc.MetodoPago), '')) > 5

          -- Condiciones del documento original
          AND PG.Fecha_Cancelacion IS NOT NULL
          AND PG.Fecha_Proc_BATMD  IS NOT NULL
          AND CFD.Fecha_Liberacion IS NULL

          -- Debe existir al menos un documento reversa.
          AND EXISTS
          (
              SELECT 1
              FROM T3.Preventa_General PG_REV
              LEFT JOIN T3.CFDI_Documentos CFD_REV
                  ON CFD_REV.Nota_Venta = PG_REV.Factura
              INNER JOIN EAI_Owner.tmp_Document_Header Doc_REV
                  ON Doc_REV.ReferenceID = PG_REV.Entrega
              WHERE PG_REV.Factura = Doc.MetodoPago
          )

          -- Todas las filas de reversa deben cumplir las condiciones.
          -- Replica el comportamiento de los AND acumulativos del cursor Oracle.
          AND NOT EXISTS
          (
              SELECT 1
              FROM T3.Preventa_General PG_REV
              LEFT JOIN T3.CFDI_Documentos CFD_REV
                  ON CFD_REV.Nota_Venta = PG_REV.Factura
              INNER JOIN EAI_Owner.tmp_Document_Header Doc_REV
                  ON Doc_REV.ReferenceID = PG_REV.Entrega
              WHERE PG_REV.Factura = Doc.MetodoPago
                AND
                (
                       PG_REV.Fecha_Cancelacion IS NULL
                    OR PG_REV.Fecha_Proc_BATMD  IS NULL
                    OR CFD_REV.Fecha_Liberacion IS NOT NULL
                )
          )
    )
    BEGIN
        SET @sReturn = 'Discard';
    END;

    RETURN @sReturn;
END;
GO