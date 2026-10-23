SET NOCOUNT ON;
-- INVC_DT es varchar en el DDL migrado. Se conserva la comparacion ISO textual.
SELECT Inv.Doc_Num AS Doc_Num, Inv.Proof_of_Delivery__C AS Proof_of_Delivery
FROM EAI_OWNER.FACTURAS_B Inv
INNER JOIN EAI_OWNER.CLIENT Cte ON Inv.Cte_SAP = Cte.Cliente_SAP
WHERE DATALENGTH(Inv.Proof_of_Delivery__C) > 0
  AND Cte.RFC = 'SEM980701STA'
  AND Inv.Invc_dt >= CONVERT(char(10), DATEADD(day, -10, GETDATE()), 23);
