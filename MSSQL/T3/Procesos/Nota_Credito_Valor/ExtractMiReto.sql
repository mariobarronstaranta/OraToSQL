-- Reporte MiReto. Solo consulta; no modifica las propuestas.
-- Conserva las uniones, el filtro de area y el orden del proceso Oracle.
-- Los importes se exportan con dos decimales y punto decimal.
SET NOCOUNT ON;

SELECT Line_Exported AS Line_Exported_to_CSV
FROM (
    SELECT 0 AS Row_ID, CAST('00' AS varchar(100)) AS Row_Key,
           CAST('"Sold to Party";"Item Number";"Plant (Item)";"Material";"Billing Date";"Item Pricing Condition Amount 1";"Item Pricing Condition Amount 2";"Total";"Area"' AS varchar(2000)) AS Line_Exported
    UNION ALL
    SELECT 1,
           CONCAT(Head.FACTURA, RIGHT('00000' + COALESCE(CONVERT(varchar(5), Det.NUM_LINEA), ''), 5)),
           CONCAT(
               '"', REPLACE(Head.CLIENTE_SAP, '"', '""'), '";',
               CONVERT(varchar(20), Det.NUM_LINEA), ';',
               '"', REPLACE(MC.CTRO, '"', '""'), '";',
               Det.MATERIAL, ';',
               '"', CONVERT(char(10), COALESCE(Head.FECHA_FACTURA, GETDATE()), 103), '";',
               CONVERT(varchar(40), CAST(Det.VALOR_SUBT AS decimal(16,2))), ';',
               CONVERT(varchar(40), CAST(Det.VALOR_IVA AS decimal(16,2))), ';',
               CONVERT(varchar(40), CAST(Det.VALOR_SUBT + Det.VALOR_IVA AS decimal(16,2))), ';',
               '"', REPLACE(Head.AREA_SOLICITANTE, '"', '""'), '"')
    FROM T3.X_PROPUESTA_NDC AS Head
    INNER JOIN T3.X_PROPUESTA_DETALLE AS Det ON Head.FACTURA = Det.FACTURA
    INNER JOIN T3.MOV_CLIENTE AS MC ON Head.CLIENTE_SAP = MC.CLIENTE_SAP
    WHERE Head.AREA_SOLICITANTE IN ('MiReto')
) AS Info
ORDER BY Info.Row_ID, Info.Row_Key;

