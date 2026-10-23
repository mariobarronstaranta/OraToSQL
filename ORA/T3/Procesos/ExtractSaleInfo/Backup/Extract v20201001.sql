SELECT 'PLANT,INVOICE_DATE,DOCUMENT_TYPE,SAP_CUSTOMER,SFDC_REFERENCE,SAP_ORDER_NUMBER,PAC_ORDER_NUMBER,SAP_SALES_AMOUNT,T3_SALES_AMOUNT,PAC_SALES_AMOUNT,PAC_FISCAL_UUID,TERRITORY' AS LINE_CONTENT
   FROM DUAL
UNION ALL   
SELECT 
       DECODE( B.Cliente_SAP, NVL( WACC.Cliente_SAP, B.Clte_Factura_SAP ), B.Ctro, 'MXAD' )
                                                    || ',' ||
       TO_CHAR( B.Invc_dt, 'YYYY-MM-DD' )           || ',' ||
       DECODE( B.Created_By, '1-80QF', 'Presales', 'Prompt' )
                                                    || ',' ||
       NVL( WACC.Cliente_SAP, B.Clte_Factura_SAP )  || ',' ||
       TRIM( B.Doc_Num )                            || ',' ||
       TRIM( B.Doc_Num )                            || ',' ||
       TRIM( B.Nota_Venta_CFDI )                    || ',' ||
       TRIM( TO_CHAR( 
          DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) *
             ( B.Valor_Subt + B.Valor_IVA +
               B.Envio_Subt + B.Envio_IVA )
       , '999999999.99' ) )                         || ',' ||
       TRIM( TO_CHAR( 
          DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) *
             ( B.Valor_Subt + B.Valor_IVA +
               B.Envio_Subt + B.Envio_IVA )                 
       , '999999999.99' ) )                         || ',' ||
       CASE
           WHEN ( B.Doc_Num = B.Nota_Venta_CFDI            ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
--         WHEN ( 'G-' || B.Doc_Num = B.Nota_Venta_CFDI    ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
           WHEN ( SUBSTR( B.Nota_Venta_CFDI, 1, 2 ) = 'G-' ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) * ( B.Valor_Subt + B.Valor_IVA + B.Envio_Subt + B.Envio_IVA ) ) )
           ELSE
               '0' 
       END                                          || ',' ||
       TRIM( I.Folio_Fiscal )                       || ',' ||
       TRIM( B.Terr )                               AS LINE_CONTENT
FROM EAI.CFDI_Bitacora B, T3.Preventa_General PG, EAI.CFDI_Informe I, EAI.FC__TIME_WINDOW TW,
     (
                  SELECT  
                        TRIM( REPLACE( CC.Mobile_Invoice_Number__C   , '"', '' ) ) AS Factura      ,
                        REPLACE( CC.SAP_Invoice_Number__C      , '"', '' ) AS Entrega      ,
                        REPLACE( 
                        REPLACE( CC.ivydsd__Invoice_Date__C    , '"', '' ) 
                        , '-', '' )                                        AS Fecha_Factura,
                        REPLACE( CC.Ivydsd__Invoice_Amount__C  , '"', '' ) AS Importe      ,
                        REPLACE( CC.ivybat__SAP_CustomerId__c  , '"', '' ) AS Cliente_SAP  
                     FROM EAI.Z_WACC_INVOICE CC
                     WHERE CC.ROW_ID NOT LIKE '%Id%'
                  UNION ALL  
                  SELECT  
                        TRIM( REPLACE( CC.Sales_Return_Invoice_Key__C, '"', '' ) ) AS Factura      ,
                        REPLACE( CC.SAP_Document_Number__c     , '"', '' ) AS Entrega      ,
                        REPLACE( 
                        REPLACE( CC.Return_Invoice_Date__C     , '"', '' ) 
                        , '-', '' )                                        AS Fecha_Factura,
                        REPLACE( CC.Total_Amount__C            , '"', '' ) AS Importe      ,
                        REPLACE( CC.ivybat__SAP_CustomerId__c  , '"', '' ) AS Cliente_SAP  
                     FROM EAI.Z_WACC_CREDITNOTE CC
                     WHERE CC.ROW_ID NOT LIKE '%Id%'     
     ) WACC
WHERE TRUNC( B.Invc_dt ) >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )
  AND TRUNC( B.Invc_dt )  < TRUNC( SYSDATE )
  AND B.Doc_Num           = PG.Factura(+)
  AND B.Nota_Venta_CFDI   = I.Folio_Interno(+) 
  AND B.Doc_Num           = WACC.Factura(+)    
  AND B.Invc_dt          >= TO_DATE( '21/09/2020', 'DD/MM/YYYY' )
UNION ALL
SELECT Info.Distributor || ',' || Info.Doc_Date_Str || ',Prompt,' || LPAD( Info.Customer, 10, '0' ) || ',' || Info.Doc_Num_Ref2 || ',' || Info.Doc_Num_Ref2 || ',,' || Info.Amount || ',,,,'
FROM (
       SELECT SAP.Doc_Date, SAP.Distributor, SAP.Doc_Num_R3, SAP.Doc_Num_Ref2, SAP.Customer, SAP.Doc_Status, SAP.Doc_NetAmt + SAP.Doc_TaxAmt AS Amount,
              TO_CHAR( TO_DATE( SAP.Doc_Date, 'YYYYMMDD' ), 'YYYY-MM-DD' ) AS Doc_Date_Str,
              CASE
                  WHEN FG.Fecha_Proc_BATMD IS NOT NULL THEN FG.Fecha_Proc_BATMD
                  WHEN PG.Fecha_Proc_BATMD IS NOT NULL THEN PG.Fecha_Proc_BATMD
                  ELSE
                  NULL
              END                   AS Fecha_Proces_T3   ,    
              CASE
                  WHEN FG.Entrega IS NOT NULL THEN 'Prompt'
                  WHEN PG.Entrega IS NOT NULL THEN 'Presale'
                  ELSE
                  NULL
              END                   AS Tipo_Documento  
       FROM EAI.T3R_Sales_Docs_Old  SAP,
            T3.Factura_General      FG ,
            T3.Preventa_General     PG ,
            EAI.FC__Time_Window     TW
       WHERE SAP.Doc_Date    >= TO_CHAR( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ), 'YYYYMMDD' )
         AND SAP.Doc_Date    >= '20200921'
         AND SAP.Doc_Num_R3  = FG.Entrega(+)
         AND SAP.Doc_Num_R3  = PG.Entrega(+)
         AND SAP.Doc_Status  = 'C'
         AND SAP.Customer NOT IN ( SELECT Target FROM EAI_Owner.MX_hashTable 
                                                 WHERE Type = 'CifrasControl'
                                                   AND Source = 'Discarding Customer' )
     ) Info
WHERE Info.Tipo_Documento IS NULL ;
