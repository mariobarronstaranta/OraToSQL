SELECT 'PLANT,INVOICE_DATE,DOCUMENT_TYPE,SAP_CUSTOMER,SFDC_REFERENCE,SAP_ORDER_NUMBER,PAC_ORDER_NUMBER,SAP_SALES_AMOUNT,T3_SALES_AMOUNT,PAC_SALES_AMOUNT,PAC_FISCAL_UUID,TERRITORY' AS LINE_CONTENT
   FROM DUAL
UNION ALL   
SELECT B.Ctro                                       || ',' ||
       TO_CHAR( B.Invc_dt, 'YYYY-MM-DD' )           || ',' ||
       DECODE( B.Created_By, '1-80QF', 'Presales', 'Prompt' )
                                                    || ',' ||
       B.Cliente_SAP                                || ',' ||
       TRIM( B.Doc_Num )                            || ',' ||
       B.Factura_SAP                                || ',' ||
       TRIM( B.Nota_Venta_CFDI )                    || ',' ||
       TRIM( TO_CHAR( 
          DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) *
             ( B.Valor_Subt + B.Valor_IVA +
               B.Envio_Subt + B.Envio_IVA )
       , '999999999.99' ) )                         || ',' ||
       TRIM( TO_CHAR( 
          DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) *
             ( B.Valor_Subt + B.Valor_IVA +
               B.Envio_Subt + B.Envio_IVA )                 
       , '999999999.99' ) )                         || ',' ||
       CASE
           WHEN ( B.Doc_Num = B.Nota_Venta_CFDI         ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
           WHEN ( 'G-' || B.Doc_Num = B.Nota_Venta_CFDI ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
           ELSE
               '0' 
       END                                          || ',' ||
       TRIM( I.Folio_Fiscal )                       || ',' ||
       TRIM( B.Terr )                               AS LINE_CONTENT
FROM EAI.CFDI_Bitacora B, T3.Preventa_General PG, EAI.CFDI_Informe I, EAI.FC__TIME_WINDOW TW
WHERE TRUNC( B.Invc_dt ) >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )
  AND TRUNC( B.Invc_dt )  < TRUNC( SYSDATE )
  AND B.Doc_Num           = PG.Factura(+)
  AND B.Nota_Venta_CFDI   = I.Folio_Interno(+) ;