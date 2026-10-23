SELECT 'PLANT,INVOICE_DATE,DOCUMENT_TYPE,CUSTOMER,SFDC_REFERENCE,SAP_ORDER,PAC_ORDER_NUMBER,SF_SALES_AMOUNT,SAP_SALES_AMOUNT,T3_SALES_AMOUNT,PAC_SALES_AMOUNT,PAC_FISCAL_UUID,' ||
       'TMD_VS_SAP,SAP_VS_T3MX,T3MX_VS_SAT,DIFERENCIA,NOMBRE_CLIENTE'  AS LINE_CONTENT
          FROM DUAL
UNION ALL
SELECT Info.Ctro                                                                    || ',' ||
       Info.Fecha                                                                   || ',' ||
       Info.Tipo_Docto                                                              || ',' ||
       Info.Cliente_SAP                                                             || ',' ||
       Info.Referencia_TMD                                                          || ',' ||
       Info.Referencia_SAP                                                          || ',' ||
       Info.Referencia_SAT                                                          || ',' ||
       TRIM( TO_CHAR( Info.Importe_TMD    , '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Importe_SAP    , '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Importe_T3MX   , '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Importe_SAT    , '999999990.99' ) )                      || ',' ||
       Info.Folio_Fiscal                                                            || ',' ||       
       TRIM( TO_CHAR( Info.Dif_TMD_vs_SAP , '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Dif_SAP_vs_T3MX, '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Dif_T3MX_vs_SAT, '999999990.99' ) )                      || ',' ||
       TRIM( TO_CHAR( Info.Diferencia     , '999999990.99' ) )                      || ',' ||   
       Info.Nombre_Cliente                                                          
                                                                                           AS LINE_CONTENT
   FROM (
         SELECT Comp.Ctro                                                           AS Ctro           ,
                Comp.Fecha                                                          AS Fecha          ,
                Comp.Tipo_Docto                                                     AS Tipo_Docto     ,
                Comp.Cliente_SAP                                                    AS Cliente_SAP    ,
                TRIM( REPLACE( NVL( MC.Nombre, '' ), ',', ' ' ) )                   AS Nombre_Cliente ,
                Comp.Referencia_TMD                                                 AS Referencia_TMD ,
                Comp.Referencia_SAP                                                 AS Referencia_SAP ,
                Comp.Referencia_SAT                                                 AS Referencia_SAT ,
                Comp.Folio_Fiscal                                                   AS Folio_Fiscal   ,
                Comp.Monto_TMD                                                      AS Importe_TMD    ,
                Comp.Monto_SAP                                                      AS Importe_SAP    ,
                Comp.Monto_T3MX                                                     AS Importe_T3MX   ,
                Comp.Monto_SAT                                                      AS Importe_SAT    ,
                Comp.Monto_TMD  - Comp.Monto_SAP                                    AS Dif_TMD_vs_SAP ,
                Comp.Monto_SAP  - Comp.Monto_T3MX                                   AS Dif_SAP_vs_T3MX,
                Comp.Monto_T3MX - Comp.Monto_SAT                                    AS Dif_T3MX_vs_SAT,
                ( ABS( Comp.Monto_TMD  - Comp.Monto_SAP  ) +
                  ABS( Comp.Monto_SAP  - Comp.Monto_T3MX ) +
                  ABS( Comp.Monto_T3MX - Comp.Monto_SAT  ) ) * Comp.Factor          AS Diferencia
            FROM (
                   SELECT 
                          Bita.Ctro                                                 AS Ctro           ,
                          TO_CHAR( Bita.Invc_dt, 'YYYY-MM-DD' )                     AS Fecha          ,
                          DECODE( PG.Entrega, NULL, 'Prompt', 'Presales' )          AS Tipo_Docto     ,
                          Bita.Cliente_SAP                                          AS Cliente_SAP    ,
                          DECODE( Bita.Tipo_Vta, 'Vta', 1, -1 )                     AS Factor         ,
                          T3.FN_CFDI_REFOLEO( Bita.Doc_Num, 'Venta' )               AS Referencia_TMD ,
                          T3.FN_CFDI_REFOLEO( Bita.Doc_Num, 'Venta' )               AS Referencia_SAP ,
                          TRIM( Bita.Nota_Venta_CFDI )                              AS Referencia_SAT ,
                          TRIM( Inf.Folio_Fiscal )                                  AS Folio_Fiscal   ,
                          NVL( Bita.SF_Amount   , 0 )                               AS Monto_TMD      ,
                          NVL( Bita.SAP_Amount  , 0 )                               AS Monto_SAP      ,
                          NVL( Bita.Valor_Subt  , 0 ) + NVL( Bita.Valor_IVA  , 0 ) +
                          NVL( Bita.Envio_Subt  , 0 ) + NVL( Bita.Envio_IVA  , 0 ) +
                          NVL( Bita.Credito_Subt, 0 ) + NVL( Bita.Credito_IVA, 0 )   AS Monto_T3MX    ,
                          CASE
                             WHEN ( Bita.Doc_Num = Bita.Nota_Venta_CFDI ) AND ( Bita.Tipo_Vta = 'Dev' ) AND ( Inf.Folio_Fiscal IS NULL ) THEN ( NVL( Bita.Valor_Subt, 0 ) + NVL( Bita.Valor_IVA, 0 ) + NVL( Bita.Envio_Subt, 0 ) + NVL( Bita.Envio_IVA, 0 ) + NVL( Bita.Credito_Subt, 0 ) + NVL( Bita.Credito_IVA, 0 ) ) 
                             WHEN ( Bita.Doc_Num = Bita.Nota_Venta_CFDI ) AND ( Bita.Tipo_Vta = 'Vta' ) AND ( Inf.Folio_Fiscal IS NULL ) 
                                                                                              AND ( NVL( Inf.Addenda, 'NO' ) != 'NO' )   THEN ( NVL( Bita.Valor_Subt, 0 ) + NVL( Bita.Valor_IVA, 0 ) + NVL( Bita.Envio_Subt, 0 ) + NVL( Bita.Envio_IVA, 0 ) )
                             WHEN ( Bita.Doc_Num = Bita.Nota_Venta_CFDI ) AND ( Inf.Folio_Fiscal IS NOT NULL )                           THEN ( NVL( Inf.Valor_Subt , 0 ) + NVL( Inf.Valor_IVA , 0 ) ) 
                             WHEN ( SUBSTR( Bita.Nota_Venta_CFDI, 1, 2 ) = 'G-' )                                                        THEN ( NVL( Bita.Valor_Subt, 0 ) + NVL( Bita.Valor_IVA, 0 ) + NVL( Bita.Envio_Subt, 0 ) + NVL( Bita.Envio_IVA, 0 ) + NVL( Bita.Credito_Subt, 0 ) + NVL( Bita.Credito_IVA, 0 ) )
                             ELSE
                                0 
                          END                                                        AS Monto_SAT
                      FROM EAI.CFDI_Bitacora    Bita, 
                           T3.Preventa_General  PG  , 
                           EAI.CFDI_Informe     Inf , 
                           EAI.FC__TIME_WINDOW  TW
                      WHERE TRUNC( Bita.Invc_dt ) >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )
                      --AND TRUNC( Bita.Invc_dt ) <= TO_DATE( TW.End_Date, 'DD/MM/YYYY' )
                        AND TRUNC( Bita.Invc_dt )  < TRUNC( SYSDATE )
                        AND Bita.Doc_Num           = PG.Factura(+)
                        AND Bita.Nota_Venta_CFDI   = Inf.Folio_Interno(+) 
                        AND Bita.Doc_Num         NOT IN ( SELECT Referencia FROM EAI_Owner.Doctos_Cancelled  )
                 ) Comp,
                 T3.Mov_Cliente  MC
            WHERE Comp.Cliente_SAP = MC.Cliente_SAP(+)     
        ) Info ;