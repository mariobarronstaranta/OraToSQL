create or replace PROCEDURE     CCEA_DATA_SALE
IS
    v_ID                VARCHAR2(050) ;       
    sMsg                VARCHAR2(500) ;   
    sErrorCode          VARCHAR2(020) ;
    nPID                NUMBER(08)    ;
    nProceso            NUMBER(08)    ;
    nProceso3           NUMBER(08)    ;
    nProceso4           NUMBER(08)    ;
 --
BEGIN
    nProceso  := 702 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;

    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.CC_DATA_SALE' ) ;
      INSERT INTO EAI.CC_DATA_SALE (
          PLANT              , INVOICE_DATE       , DOCUMENT_TYPE      , SAP_CUSTOMER       ,
          SFDC_REFERENCE     , SAP_ORDER_NUMBER   , PAC_ORDER_NUMBER   , SAP_SALES_AMOUNT   ,
          T3_SALES_AMOUNT    , PAC_SALES_AMOUNT   , PAC_FISCAL_UUID    , TERRITORY          )
      SELECT 
             B.Ctro                                             AS PLANT              ,
             TO_CHAR( B.Invc_dt, 'YYYY-MM-DD' )                 AS INVOICE_DATE       ,
             DECODE( PG.Entrega, NULL, 'Prompt', 'Presales' )   AS DOCUMENT_TYPE      ,
             B.Cliente_SAP                                      AS SAP_CUSTOMER       ,
             TRIM( B.Doc_Num )                                  AS SFDC_REFERENCE     ,
             TRIM( B.Doc_Num )                                  AS SAP_ORDER_NUM      ,
             TRIM( B.Nota_Venta_CFDI )                          AS PAC_ORDER_NUM      ,
             TRIM( TO_CHAR( 
                DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) *
                   ( B.Valor_Subt + B.Valor_IVA +
                     NVL( B.Credito_Subt, 0 ) + NVL( B.Credito_IVA, 0 ) +
                     B.Envio_Subt + B.Envio_IVA )
             , '999999999.99' ) )                               AS SAP_SALES_AMOUNT   ,
             TRIM( TO_CHAR( 
                DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) *
                   ( B.Valor_Subt + B.Valor_IVA +
                     NVL( B.Credito_Subt, 0 ) + NVL( B.Credito_IVA, 0 ) +
                     B.Envio_Subt + B.Envio_IVA )                 
             , '999999999.99' ) )                               AS T3_AMOUNT          ,
             CASE
                 WHEN ( B.Doc_Num = B.Nota_Venta_CFDI            ) AND ( I.Folio_Fiscal IS NOT NULL ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
--               WHEN ( 'G-' || B.Doc_Num = B.Nota_Venta_CFDI    ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1, -1 ) * ( I.Valor_Subt + I.Valor_IVA ) ) )
                 WHEN ( SUBSTR( B.Nota_Venta_CFDI, 1, 2 ) = 'G-' ) THEN TRIM( TO_CHAR( DECODE( B.Tipo_Vta, 'Vta', 1,  1 ) * ( B.Valor_Subt + B.Valor_IVA + B.Envio_Subt + B.Envio_IVA + NVL( B.Credito_Subt, 0 ) + NVL( B.Credito_IVA, 0 ) ) ) )
                 ELSE
                     '0' 
             END                                               AS PAC_SALES_AMOUNT  ,
             TRIM( I.Folio_Fiscal )                            AS PAC_FISCAL_UUID   ,
             '0000'                                            AS TERRITORY
      FROM EAI.CFDI_Bitacora B, T3.Preventa_General PG, EAI.CFDI_Informe I, EAI.FC__TIME_WINDOW TW
      WHERE TRUNC( B.Invc_dt ) >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )
        AND TRUNC( B.Invc_dt )  < TRUNC( SYSDATE )
        AND B.Doc_Num           = PG.Factura(+)
        AND B.Nota_Venta_CFDI   = I.Folio_Interno(+) 
        AND B.Invc_dt          >= TO_DATE( '21/09/2020', 'DD/MM/YYYY' )
        AND B.Doc_Num         NOT LIKE 'CONEC%' 
        AND B.Doc_Num         NOT LIKE 'DESC-%' ;
          nProceso4 := SQL%ROWCOUNT ;
      COMMIT ;
      INSERT INTO EAI.CC_DATA_SALE (
          PLANT              , INVOICE_DATE       , DOCUMENT_TYPE      , SAP_CUSTOMER       ,
          SFDC_REFERENCE     , SAP_ORDER_NUMBER   , PAC_ORDER_NUMBER   , SAP_SALES_AMOUNT   ,
          T3_SALES_AMOUNT    , PAC_SALES_AMOUNT   , PAC_FISCAL_UUID    , TERRITORY           )
      SELECT Info.Distributor                                   AS PLANT              ,
             Info.Doc_Date_Str                                  AS INVOICE_DATE       ,
             'Prompt'                                           AS DOCUMENT_TYPE      ,
             LPAD( Info.Customer, 10, '0' )                     AS SAP_CUSTOMER       ,
             Info.Doc_Num_Ref2                                  AS SFDC_REFERENCE     ,
             Info.Doc_Num_Ref2                                  AS SAP_ORDER_NUM      ,
             ''                                                 AS PAC_ORDER_NUM      ,
             Info.Amount                                        AS SAP_SALES_AMOUNT   ,
             '0'                                                AS T3_SALES_AMOUNT    ,
             '0'                                                AS PAC_SALES_AMOUNT   ,
             ''                                                 AS PAC_FISCAL_UUID    ,
             '0000'                                             AS TERRITORY
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
          nProceso3 := SQL%ROWCOUNT ;
--
    UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
       WHERE Component = nProceso ;
    UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_3 = nProceso3,
                                                  Proceso_2 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;          
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                 , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , v_ID               , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'CCEA_DATA_SALE'   , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL               , NULL                , NULL            ) ;
        COMMIT ;   
END CCEA_DATA_SALE ;