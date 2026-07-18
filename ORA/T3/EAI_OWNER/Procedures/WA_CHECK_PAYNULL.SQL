create or replace PROCEDURE           "WA_CHECK_PAYNULL" 
   ( pDays              IN NUMBER   DEFAULT 0,
     pSequence          IN NUMBER   DEFAULT 0 )
   AS
--
   sReference            VARCHAR2(030) ;
   sReferenceInv         VARCHAR2(030) ;
   sReferenceCM          VARCHAR2(030) ;
   sReferenceRFC         VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
      SELECT Info.ClearingDocNumber, Info.IDocNumber, Info.ReferenceDocNumber
         FROM EAI_Owner.Z_CHECK_PAYAMT_NULL Info ;
--
   CURSOR ScrPayments IS
      SELECT Pay.IDocNumber, Pay.ClearingDocNumber, Cte.RFC, Cte.Nombre, 
             NVL( Cte.Metodo_Pago, '-' )                                              AS Metodo_Pago, 
             EAI_Owner.getConv( 'V3_ECC PaymentMethod', NVL( Cte.Metodo_Pago, '-' ) ) AS PayMethod
         FROM EAI_Owner.Z_CHECK_PAYAMT_NULL Pay, T3.Mov_Cliente Cte
         WHERE NVL( Pay.Doc_Pending, 0 ) = NVL( Pay.Doc_Amount, 0 )
           AND NVL( Pay.Doc_Amount , 0 ) > 0
           AND Pay.Cliente_SAP           = Cte.Cliente_SAP ;         
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(08)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
   rsDoc_Num             VARCHAR2(030) ;
   rsCliente_SAP         VARCHAR2(010) ;
   rnAmount              NUMBER(15,2)  ;
   rnPending             NUMBER(15,2)  ;
   rnPaid                NUMBER(15,2)  ;
BEGIN
--
   DBMS_Output.Put_Line( 'Inicio -> ' || TO_CHAR( SYSDATE, 'HH:MI:SS' ) ) ;
   EXECUTE IMMEDIATE ( 'TRUNCATE TABLE EAI_OWNER.Z_CHECK_PAYAMT_NULL' ) ;    
   INSERT INTO EAI_OWNER.Z_CHECK_PAYAMT_NULL 
      ( ClearingDocNumber, IDocNumber, ReferenceDocNumber, DC_Indicator, Pay_Amount )
      SELECT Info.ClearingDocNumber, Info.IDocNumber, Info.ReferenceDocNumber, Info.Max_DC, Info.DocAmount
         FROM (
                SELECT ClearingDocNumber                           AS ClearingDocNumber ,
                       MAX( IdocNumber )                           AS IdocNumber        ,
                       MAX( ReferenceDocNumber )                   AS ReferenceDocNumber,
                       MAX( DC_Indicator )                         AS Max_DC            ,
                       MAX( AmountDocCurrency )                    AS DocAmount         ,
                       SUM( 1 )                                    AS Registros         ,
                       SUM( DECODE( PaymentAmount, NULL, 1, 0 ) )  AS PayAmt_NULL       ,
                       SUM( DECODE( Processed    , NULL, 0, 1 ) )  AS Procesados       
                   FROM EAI_Owner.tmp_Account_Header Cred      
                   WHERE Created            > TRUNC( SYSDATE - NVL( pDays, 0 ) )
                      AND ClearingDocNumber IS NOT NULL
                  GROUP BY ClearingDocNumber ) Info
        WHERE Info.Registros   = 1
          AND Info.PayAmt_Null = 1
          AND Info.Procesados  = 0 ;
   COMMIT ;       
   nPedidos := 0 ;
   FOR Doc IN ScrDocuments LOOP
      nPedidos   := nPedidos + 1        ;
      EAI_Owner.SF_GET_INVOICE_DATA( Doc.ReferenceDocNumber, rsDoc_Num, rsCliente_SAP, rnAmount, rnPending, rnPaid ) ;
      UPDATE EAI_OWNER.Z_CHECK_PAYAMT_NULL SET Doc_Amount  = rnAmount     ,
                                               Doc_Pending = rnPending    ,
                                               Cliente_SAP = rsCliente_SAP
         WHERE ClearingDocNumber = Doc.ClearingDocNumber ;
   END LOOP ;
   IF ( NVL( pSequence, 100) >= 100 ) THEN
      FOR Pay IN ScrPayments LOOP
         IF( Pay.Metodo_Pago != Pay.PayMethod ) THEN
            UPDATE EAI_Owner.tmp_Account_Header SET PaymentAmount = AmountDocCurrency,
                                                    PaymentMethod = Pay.PayMethod
               WHERE IDocNumber = Pay.IDocNumber ;                                                 
         END IF ;      
      END LOOP ;
   END IF ;   
   DBMS_Output.Put_Line( 'Fin -> ' || TO_CHAR( SYSDATE, 'HH:MI:SS' ) ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                 , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_CHECK_PAYNULL'   , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_CHECK_PAYNULL ;