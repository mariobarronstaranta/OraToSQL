SELECT B.Ctro                                       AS Plant             ,
       TO_CHAR( B.Invc_dt, 'YYYY-MM-DD' )           AS Invoice_Date      ,
       DECODE( B.Created_By, '1-80QF', 'Presales', 'Prompt' )
                                                    AS Document_Type     ,
       B.Cliente_SAP                                AS SAP_Customer      ,
       B.Doc_Num                                    AS SFDC_Reference    ,
       NVL( PG.Referencia, B.Doc_Num )              AS SAP_Order_Number  ,
       B.Nota_Venta_CFDI                            AS PAC_Order_Number  ,
       DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) *
       ( B.Valor_Subt + B.Valor_IVA +
       B.Envio_Subt + B.Envio_IVA )                 AS SAP_Sales_Amount ,
       DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) *
       ( B.Valor_Subt + B.Valor_IVA +
       B.Envio_Subt + B.Envio_IVA )                 AS T3_Sales_Amount   ,
       DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) *
       CASE
           WHEN ( B.Doc_Num = B.Nota_Venta_CFDI         ) THEN ( I.Valor_Subt + I.Valor_IVA )
           WHEN ( 'G-' || B.Doc_Num = B.Nota_Venta_CFDI ) THEN ( I.Valor_Subt + I.Valor_IVA )
           ELSE
               0
       END                                          AS PAC_Sales_Amount  ,
       I.Folio_Fiscal                               AS PAC_Fiscal_UUID   ,
       B.Terr                                       AS Territory
FROM EAI.CFDI_Bitacora B, T3.Preventa_General PG, EAI.CFDI_Informe I
WHERE TRUNC( B.Invc_dt ) >= TO_DATE( '20191201', 'YYYYMMDD' )
  AND TRUNC( B.Invc_dt ) <= TO_DATE( '20191211', 'YYYYMMDD' )
  AND B.Doc_Num             = PG.Factura(+)
  AND B.Nota_Venta_CFDI     = I.Folio_Interno(+) ;