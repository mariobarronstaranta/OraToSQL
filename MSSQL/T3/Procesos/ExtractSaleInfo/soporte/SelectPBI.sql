SELECT Ctro AS PLANT, Fecha AS INVOICE_DATE, Tipo_Docto AS DOCUMENT_TYPE,
       Cliente_SAP AS CUSTOMER, Referencia_TMD AS SFDC_REFERENCE,
       Referencia_TMD AS SAP_ORDER, Referencia_SAT AS PAC_ORDER_NUMBER,
       CONVERT(decimal(28,2), Monto_TMD) AS SF_SALES_AMOUNT,
       CONVERT(decimal(28,2), Monto_SAP) AS SAP_SALES_AMOUNT,
       CONVERT(decimal(28,2), Monto_T3MX) AS T3_SALES_AMOUNT,
       CONVERT(decimal(28,2), Monto_SAT) AS PAC_SALES_AMOUNT,
       Folio_Fiscal AS PAC_FISCAL_UUID,
       CONVERT(decimal(28,2), Dif_TMD_SAP) AS TMD_VS_SAP,
       CONVERT(decimal(28,2), Dif_SAP_T3MX) AS SAP_VS_T3MX,
       CONVERT(decimal(28,2), Dif_T3MX_SAT) AS T3MX_VS_SAT,
       CONVERT(decimal(28,2), Diferencia) AS DIFERENCIA,
       Nombre_Cliente AS NOMBRE_CLIENTE
FROM #Sale;
DROP TABLE #Sale;
