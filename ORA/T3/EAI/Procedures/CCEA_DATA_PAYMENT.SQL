create or replace PROCEDURE     CCEA_DATA_PAYMENT
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
    nProceso  := 731 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;
    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.CC_DATA_PAYMENT' ) ;
      INSERT INTO EAI.CC_DATA_PAYMENT (
         PLANT                   , TERRITORY               , STOCK_PARTNER           , SFCD_CUSTOMER           ,
         SAP_CUSTOMER            , CUSTOMER_NAME           , TAX_ID                  , CUSTOMER_PAYMENT_METHOD ,
         CUSTOMER_PAYMENT_TYPE   , REPORT_DATE             , DOCUMENT_TYPE           , 
         INVOICE_DATE            , SFDC_REFERENCE          , PAC_REFERENCE           , DOCUMENT_TAX_ID         ,
         INVOICE_UUID            , INVOICE_DUE_DATE        , INVOICE_AMOUNT          , INVOICE_PREVIOUS_BALANCE,
         PAYMENT_METHOD          , PAYMENT_DATE            , PAYMENT_ID              , ASSIGNMENT_ID           ,
         PAYMENT_NUMBER          , COLLECTION_FOR_CASH     , COLLECTION_FOR_CREDIT   , CREDITMEMO_RELATED      ,
         CREDITMEMO              , CREDITMEMO_ALLOCATED    , INVOICE_NEW_BALANCE     , INVOICE_PAYMENT_METHOD  ,
         PAYMENT_FISCAL_ID       , PAYMENT_RELEASE         , PAYMENT_FISCAL_UUID      )
      SELECT 
             NVL( Cobza.Ctro, Pay.Ctro )                                               AS PLANT                   ,
             SUBSTR( CS.Territorio_Delivery, 17, 4 )                                   AS TERRITORY               ,
             SB.Stock_Partner                                                          AS STOCK_PARTNER           ,
             TRIM( MC.Cliente_V3 )                                                     AS SFCD_CUSTOMER           ,
             MC.Cliente_SAP                                                            AS SAP_CUSTOMER            ,
             TRIM( T3.FN_TRIM_CIFRAS( MC.Nombre ) )                                    AS CUSTOMER_NAME           ,
             TRIM( MC.RFC )                                                            AS TAX_ID                  ,
             TRIM( EAI_Owner.getConv( 'CifrasControl Payment Type', MC.Metodo_Pago ) ) AS CUSTOMER_PAYMENT_METHOD ,
             TRIM( EAI_Owner.getConv( 'TMD_Cifras Payment Type', CS.Forma_Pago )     ) AS CUSTOMER_PAYMENT_TYPE   ,
             TO_CHAR( SYSDATE, 'YYYY-MM-DD' )                                          AS REPORT_DATE             ,
             CASE
                WHEN NVL( Cobza.Status, 'Invoice' ) = 'CONFIRMADO'        THEN 'Invoice'
                WHEN NVL( Cobza.Status, 'Invoice' ) = 'DN - Penalizacion' THEN 'Invoice'
                WHEN NVL( Cobza.Status, 'Invoice' ) = 'Debit Note'        THEN 'Debit Note'
                ELSE
                   'Invoice'
             END                                                                      AS DOCUMENT_TYPE            ,
             TO_CHAR( Cobza.Fecha_Factura, 'YYYY-MM-DD' )                             AS INVOICE_DATE             ,
             TRIM( Cobza.Factura    )                                                 AS SFDC_REFERENCE           ,
             TRIM( Cobza.Nota_Venta )                                                 AS PAC_REFERENCE            ,
             TRIM( Cobza.RFC        )                                                 AS DOCUMENT_TAX_ID          ,
             TRIM( Cobza.UUID_Venta )                                                 AS INVOICE_UUID             ,
             TO_CHAR( Cobza.Fecha_Factura + NVL( Cobza.Dias_Cdto, 0), 'YYYY-MM-DD' )           
                                                                                      AS INVOICE_DUE_DT           ,
             TRIM( TO_CHAR( Cobza.Importe_Factura, '999999999.99' ) )                 AS INVOICE_AMOUNT           ,
             TRIM( TO_CHAR( Cobza.Saldo_Anterior , '999999999.99' ) )                 AS INVOICE_PREVIOUS_BALANCE ,
--
             TRIM( EAI_Owner.getConv( 'TMD_Cifras', Cobza.Via_Pago ) )                AS PAYMENT_METHOD           ,
             TO_CHAR( Cobza.Fecha_Asignacion, 'YYYY-MM-DD' )                          AS PAYMENT_DATE             ,
             TRIM( Cobza.Pago_ID       )                                              AS PAYMENT_ID               ,
             TRIM( Cobza.Asignacion_ID )                                              AS ASSIGNMENT_ID            ,
             TRIM( Cobza.Numero_Pago   )                                              AS PAYMENT_NUMBER           ,
             DECODE( TRUNC( Cobza.Fecha_Asignacion ), TRUNC( Cobza.Fecha_Factura ), TRIM( TO_CHAR( Cobza.Importe, '999999999.99' ) ), '0' )
                                                                                      AS COLLECTION_FOR_CASH      ,
             DECODE( TRUNC( Cobza.Fecha_Asignacion ), TRUNC( Cobza.Fecha_Factura ), '0', TRIM( TO_CHAR( Cobza.Importe, '999999999.99' ) ) )
                                                                                      AS COLLECTION_FOR_CREDIT    ,
             TRIM( Cobza.Nota_Credito )                                               AS CREDITMEMO_RELATED       ,
             TO_CHAR( RF.Fecha_Factura, 'YYYY-MM-DD' )                                AS CREDITMEMO               ,
             DECODE( Cobza.Nota_Credito, NULL, '',
                TRIM( TO_CHAR( Cobza.Importe, '999999999.99' ) ) )                    AS CREDITMEMO_ALLOCATED     ,
             TRIM( TO_CHAR( Cobza.Saldo_Anterior - Cobza.Importe, '999999999.99' ) )  AS INVOICE_NEW_BALANCE      ,
             TRIM( Inv.Metodo_Pago )                                                  AS INVOICE_PAYMENT_METHOD   ,
             TRIM( EAI_OWNER.FN_GET_PAY_REFERENCE( Cobza.Asignacion_ID ) )            AS PAYMENT_FISCAL_ID        ,
             CASE
                 WHEN Pay.Fecha_Liberacion IS NOT NULL THEN TO_CHAR( Pay.Fecha_Liberacion, 'YYYY-MM-DD' )
                 ELSE
                   ''
             END                                                                      AS PAYMENT_RELEASE          ,
             TRIM( NVL( Pay.Folio_Fiscal, '' ) )                                      AS PAYMENT_FISCAL_UUID
      FROM T3.CFDI_Cobranza    Cobza,
           T3.Mov_Cliente      MC   ,
           ( SELECT DISTINCT Territorio, Stock_Partner 
                FROM SiebelETL.Vans_Vigentes@V3  )   SB,
           EAI.Cliente_Siebel  CS   ,
           T3.CFDI_Documentos  Inv  ,
           T3.Registro_Fiscal  RF   ,
           T3.CFDI_Documentos  Pay  
      WHERE NVL(TO_CHAR(Cobza.FECHA_ENVIO,'YYYYMMDD'), 'null' ) LIKE '202%'
        AND TRUNC( Cobza.Fecha_Proceso )      >= TO_DATE( EAI_Owner.getConv( 'TMD_Cifras', 'Fecha Pago' ), 'YYYYMMDD' )
        AND Cobza.Cliente_SAP                  = MC.Cliente_SAP
        AND MC.Cliente_V3                      = CS.Cliente_V3(+)
        AND CS.Territorio_Delivery             = SB.Territorio(+)
        AND Cobza.Nota_Venta                   = Inv.Nota_Venta(+) 
        AND Cobza.Nota_Credito                 = RF.Factura(+)
        AND ( ( NVL( Cobza.RFC, 'XAXX010101000' ) != 'XAXX010101000' )
           OR ( NVL( MC.RFC   , 'XAXX010101000' ) != 'XAXX010101000' ) ) 
        AND EAI_OWNER.FN_GET_PAY_REFERENCE( Cobza.Asignacion_ID ) = Pay.Nota_Venta(+) ;
     nProceso4 := SQL%ROWCOUNT ;
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
          ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , v_ID                  , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'CCEA_DATA_PAYMENT'   , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL                  , NULL                , NULL            ) ;
        COMMIT ;   
END CCEA_DATA_PAYMENT ;