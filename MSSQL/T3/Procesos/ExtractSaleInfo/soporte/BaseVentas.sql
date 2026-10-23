-- Incluido por Extract*.sql en la misma sesion. Conserva multiplicidad y NOT IN.
SET NOCOUNT ON;
DECLARE @Hoy date = CONVERT(date, GETDATE());
IF EXISTS (SELECT 1 FROM EAI.FC__TIME_WINDOW
           WHERE TRY_CONVERT(date, Start_Date, 103) IS NULL
              OR (@Mensual = 1 AND TRY_CONVERT(date, End_Date, 103) IS NULL))
    THROW 54601, 'FC__TIME_WINDOW contiene fechas invalidas (DD/MM/YYYY).', 1;

IF OBJECT_ID('tempdb..#Sale') IS NOT NULL DROP TABLE #Sale;
SELECT B.Ctro, CONVERT(char(10), B.Invc_dt, 23) AS Fecha,
       CASE WHEN PG.Entrega IS NULL OR DATALENGTH(PG.Entrega) = 0 THEN 'Prompt' ELSE 'Presales' END AS Tipo_Docto,
       B.Cliente_SAP,
       LTRIM(RTRIM(REPLACE(ISNULL(MC.Nombre, ''), ',', ' '))) AS Nombre_Cliente,
       T3.FN_CFDI_REFOLEO(B.Doc_Num, 'Venta') AS Referencia_TMD,
       LTRIM(RTRIM(B.Nota_Venta_CFDI)) AS Referencia_SAT,
       B.Nota_Venta_CFDI,
       LTRIM(RTRIM(Inf.Folio_Fiscal)) AS Folio_Fiscal,
       M.Monto_TMD, M.Monto_SAP, M.Monto_T3MX, S.Monto_SAT,
       M.Monto_TMD - M.Monto_SAP AS Dif_TMD_SAP,
       M.Monto_SAP - M.Monto_T3MX AS Dif_SAP_T3MX,
       M.Monto_T3MX - S.Monto_SAT AS Dif_T3MX_SAT,
       (ABS(M.Monto_TMD - M.Monto_SAP) + ABS(M.Monto_SAP - M.Monto_T3MX)
         + ABS(M.Monto_T3MX - S.Monto_SAT))
           * CASE WHEN B.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END AS Diferencia
INTO #Sale
FROM EAI.CFDI_BITACORA B
CROSS JOIN EAI.FC__TIME_WINDOW TW
LEFT JOIN T3.PREVENTA_GENERAL PG ON B.Doc_Num = PG.Factura
LEFT JOIN EAI.CFDI_INFORME Inf ON B.Nota_Venta_CFDI = Inf.Folio_Interno
LEFT JOIN T3.MOV_CLIENTE MC ON B.Cliente_SAP = MC.Cliente_SAP
CROSS APPLY (VALUES (
    ISNULL(B.SF_Amount, 0), ISNULL(B.SAP_Amount, 0),
    ISNULL(B.Valor_Subt, 0) + ISNULL(B.Valor_IVA, 0)
      + ISNULL(B.Envio_Subt, 0) + ISNULL(B.Envio_IVA, 0)
      + ISNULL(B.Credito_Subt, 0) + ISNULL(B.Credito_IVA, 0)
)) M(Monto_TMD, Monto_SAP, Monto_T3MX)
CROSS APPLY (VALUES (CASE
    WHEN B.Doc_Num = B.Nota_Venta_CFDI AND B.Tipo_Vta = 'Dev'
         AND (Inf.Folio_Fiscal IS NULL OR DATALENGTH(Inf.Folio_Fiscal) = 0) THEN M.Monto_T3MX
    WHEN B.Doc_Num = B.Nota_Venta_CFDI AND B.Tipo_Vta = 'Vta'
         AND (Inf.Folio_Fiscal IS NULL OR DATALENGTH(Inf.Folio_Fiscal) = 0)
         AND CASE WHEN Inf.Addenda IS NULL OR DATALENGTH(Inf.Addenda) = 0 THEN 'NO' ELSE Inf.Addenda END <> 'NO'
      THEN ISNULL(B.Valor_Subt, 0) + ISNULL(B.Valor_IVA, 0)
         + ISNULL(B.Envio_Subt, 0) + ISNULL(B.Envio_IVA, 0)
    WHEN B.Doc_Num = B.Nota_Venta_CFDI AND DATALENGTH(Inf.Folio_Fiscal) > 0
      THEN ISNULL(Inf.Valor_Subt, 0) + ISNULL(Inf.Valor_IVA, 0)
    WHEN LEFT(B.Nota_Venta_CFDI, 2) = 'G-' THEN M.Monto_T3MX
    ELSE 0 END)) S(Monto_SAT)
WHERE B.Invc_dt >= CONVERT(date, TW.Start_Date, 103)
  AND ((@Mensual = 0 AND B.Invc_dt < @Hoy)
    OR (@Mensual = 1 AND CONVERT(date, B.Invc_dt) <= TRY_CONVERT(date, TW.End_Date, 103)))
  AND B.Doc_Num NOT IN (SELECT Referencia FROM EAI_OWNER.DOCTOS_CANCELLED);
