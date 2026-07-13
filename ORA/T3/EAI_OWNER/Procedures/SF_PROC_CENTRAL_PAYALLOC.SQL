create or replace PROCEDURE           SF_PROC_CENTRAL_PAYALLOC
   ( pIDocNumber         IN   VARCHAR2,
     pClearingDocNumber  IN   VARCHAR2,
     pClearingDate       IN   VARCHAR2,
   --pFiscalYear         IN   VARCHAR2,
     pPostingDate        IN   DATE   DEFAULT TRUNC( SYSDATE ) ,
     pOutPut             IN   NUMBER DEFAULT 0 )
IS
   sMsg                    VARCHAR2(500) ;   
   v_ID                    VARCHAR2(030) ;
   sErrorCode              VARCHAR2(020) ;
   sReferenceID            VARCHAR2(030) ;
   sProcesar               VARCHAR2(020) ;
   sIDocNum                VARCHAR2(020) ;
   nRecords                NUMBER(04)    ;
   sInvReference           VARCHAR2(050) ;
   sCMReference            VARCHAR2(050) ;
   nPaymentAmount          NUMBER(18,2)  ;
   nCNPaymentAmount        NUMBER(18,2)  ;
   nInvPaymentAmount       NUMBER(18,2)  ;
   nStep                   NUMBER(06)    ;
   nAbsolute               NUMBER(15,4)  ;
--   
   sReferenceDocNumber     VARCHAR2(050) ;
   sNCDocNumber            VARCHAR2(050) ;  
   sPago_Integration_ID    VARCHAR2(050) ;  
   sPayment_Num            VARCHAR2(050) ;  
   sPostingDate            VARCHAR2(050) ;  
   dtPostingDate           DATE          ;
   sCustomerPayer          VARCHAR2(050) ;
   sIDocNumber             VARCHAR2(050) ;
   sPayment_Method         VARCHAR2(050) ;
--   
   nAmount                 NUMBER        ;
   sCustomer_TMD           VARCHAR2(030) ;
   sCtro                   VARCHAR2(004) ;
   nDistributor            NUMBER(04)    ;
   sRep_ID                 VARCHAR2(030) ;
   sInvDoc_Num             VARCHAR2(030) ; 
   sInvCustomer            VARCHAR2(030) ;
   nInvAmount              NUMBER(15,2)  ;
   nInvPending             NUMBER(15,2)  ;
   sNCDoc_Num              VARCHAR2(030) ; 
   sNCCustomer             VARCHAR2(030) ;
   nNCAmount               NUMBER(15,2)  ;
   nNCPending              NUMBER(15,2)  ; 
   nPaid                   NUMBER(15,2)  ;
   nNCPaid                 NUMBER(15,2)  ; 
   sCustomer_Name          VARCHAR2(1024);
--
   CURSOR ScrData IS
      SELECT 
            IDoc.DocumentType                       AS Inv_DocumentType , 
            IDoc.BillingDoc                         AS Inv_BillingDoc   ,
            IDoc.ReferenceDoc                       AS Inv_ReferenceDoc ,
            IDoc.PMS                                AS Inv_PMS          ,
            IDoc.PaymentAmt                         AS Inv_PaymentAmt   ,
            IDoc.PaymentMethod                      AS Inv_PaymentMethod,
            Cred.DocumentType                       AS CM_DocumentType  , 
            Cred.BillingDoc                         AS CM_BillingDoc    ,
            NVL( Cred.ReferenceDoc, '' )            AS CM_ReferenceDoc  ,
            Cred.PMS                                AS CM_PMS           ,
            Cred.PaymentAmt                         AS CM_PaymentAmt    ,
            Cred.PaymentMethod                      AS CM_PaymentMethod
         FROM (
                SELECT IDoc.DocumentType                  AS DocumentType ,
                       IDoc.ClearingDocNumber             AS ClearingDoc  ,
                       IDoc.Assignment                    AS BillingDoc   ,
                       IDoc.ReferenceDocNumber            AS ReferenceDoc ,
                       IDoc.PayMethSupplement             AS PMS          ,
                       NVL( IDoc.PaymentAmount, 0 )       AS PaymentAmt   ,
                       IDoc.PaymentMethod                 AS PaymentMethod
                   FROM EAI_Owner.tmp_Account_Header IDoc
                   WHERE IDoc.ClearingDocNumber = pClearingDocNumber
                   --AND IDoc.FiscalYear        = pFiscalYear
                     AND IDoc.ClearingDate      = pClearingDate
                     AND IDoc.DC_Indicator      = 'S'
                     AND IDoc.PaymentAmount    IS NOT NULL
                   --AND IDoc.Assignment       IS NOT NULL
               ) IDoc,      
               (
                SELECT Cred.DocumentType                  AS DocumentType ,
                       Cred.ClearingDocNumber             AS ClearingDoc  ,
                       Cred.Assignment                    AS BillingDoc   ,
                       Cred.ReferenceDocNumber            AS ReferenceDoc ,
                       Cred.PayMethSupplement             AS PMS          ,
                       NVL( Cred.PaymentAmount, 0 )       AS PaymentAmt   ,
                       Cred.PaymentMethod                 AS PaymentMethod
                   FROM EAI_Owner.tmp_Account_Header Cred
                   WHERE Cred.ClearingDocNumber = pClearingDocNumber
                   --AND Cred.FiscalYear        = pFiscalYear
                     AND Cred.ClearingDate      = pClearingDate
                     AND Cred.DC_Indicator      = 'H'
                     AND Cred.PaymentAmount    IS NOT NULL
                   --AND Cred.Assignment       IS NOT NULL  
               ) Cred 
               WHERE IDoc.ClearingDoc = Cred.ClearingDoc(+) ;
BEGIN
   sProcesar     := 'YES'        ;
   nRecords      := 0000         ;
   sReferenceID  := pIDocNumber  ;
   nNCAmount     := 0            ;
   nNCPending    := 0            ;
   dtPostingDate := pPostingDate ;
   nStep         := 0            ;
   IF ( pOutput > 0 ) THEN
      nStep := nStep + 1 ;
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Begin' ) ;
   END IF ;   
   IF ( sProcesar != 'NO' ) THEN    
      FOR Rec IN ScrData LOOP 
         nRecords := nRecords + 1 ;
         sInvReference     := Rec.Inv_ReferenceDoc ;
         sCMReference      := Rec.CM_ReferenceDoc  ;
         nPaymentAmount    := Rec.Inv_PaymentAmt   ;
         nInvPaymentAmount := Rec.Inv_PaymentAmt   ;
         nCNPaymentAmount  := Rec.CM_PaymentAmt    ;
         IF ( nCNPaymentAmount < nPaymentAmount ) THEN
            nPaymentAmount := nCNPaymentAmount ; 
         END IF ;
         IF ( pOutput > 0 ) THEN
            nStep := nStep + 1 ; 
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'InvReference   : ' || sInvReference     ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'CMReference    : ' || sCMReference      ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Invoice Amount : ' || nInvPaymentAmount ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Credit Amount  : ' || nCNPaymentAmount  ) ;
         END IF ;
      END LOOP ;
      IF ( nRecords = 1 ) THEN
         EAI_OWNER.SF_GET_INVOICE_DATA( sInvReference, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid ) ;
         IF ( pOutPut > 0 ) THEN
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Invoice Information'                 ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Reference : ' || sInvReference       ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Invoice   : ' || sInvDoc_Num         ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Customer  : ' || sInvCustomer        ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Amount    : ' || nInvAmount          ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Pending   : ' || nInvPending         ) ;
         END IF ;
         IF ( LENGTH( sCMReference ) > 1 ) THEN
            EAI_OWNER.SF_GET_CREDIT_DATA( sCMReference, sNCDoc_Num, sNCCustomer, nNCAmount , nNCPending, nNCPaid ) ;
            IF ( pOutPut > 0 ) THEN
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Credit Note Information'      ) ;
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Reference : ' || sCMReference ) ;
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'CreditNote: ' || sNCDoc_Num   ) ;
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Customer  : ' || sNCCustomer  ) ;
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Amount    : ' || nNCAmount    ) ;
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Pending   : ' || nNCPending   ) ;
            END IF ;
         END IF ;
         EAI_OWNER.SF_GET_CUSTOMER_DATA( sInvCustomer, dtPostingDate, sCustomer_TMD, sCtro, nDistributor, sRep_ID, sCustomer_Name ) ;
         IF ( pOutPut > 0 ) THEN
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Customer Information'      ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Customer_TMD : ' || sCustomer_TMD ) ;
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Ctro         : ' || sCtro         ) ;
         END IF ;
         IF ( nInvAmount > 0 ) THEN
            IF ( nInvPending >= nPaymentAmount ) THEN
            -- Checking Credit note
               IF ( nNCAmount = 0 ) THEN
                  IF ( LENGTH( sCMReference ) > 2 ) THEN
        -- Credit Note does not exist
                     IF ( pOutPut > 0 ) THEN
                        nStep := nStep + 1 ;
                        INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                           VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Credit Note NOT Found' ) ;
                     END IF ;      
                     UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'CN NOT Found'
                        WHERE IDocNumber = pIDocNumber ;   
                  ELSE
        --          
        -- Payment Collection
        --                   
                     nRecords := nRecords + 0 ;
        --           EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV ( LPAD( pIDocNumber, 16, '0' ) ) ;
                  END IF ;
               ELSE
                  nAbsolute := ABS( nNCPending - nPaymentAmount ) ;
                  IF ( ( ( nNCPending >= nPaymentAmount ) OR ( nAbsolute < 0.05 ) ) AND ( nPaymentAmount > 0 ) ) THEN
        --          
        -- Credit Allocation
        --           
                   --sPago_Integration_ID := SUBSTR( pFiscalYear  , 3, 2 ) || pClearingDocNumber ;       
                     sPago_Integration_ID := SUBSTR( pClearingDate, 3, 2 ) || pClearingDocNumber ;       
                     INSERT INTO T3.Asignacion_Pago 
                       ( Pago_ID              , Fecha_Trn   , Distribuidor, Fecha_Asignacion, Cliente_V3  , 
                         Asignacion_ID        , Nota_Credito,
                         Cliente_SAP          , Rep_ID      , Factura     , Valor_Pago      , Ctro         )
                     VALUES
                        ( sPago_Integration_ID, SYSDATE     , nDistributor, dtPostingDate   , sCustomer_TMD,
                          sPago_Integration_ID, sNCDoc_Num  ,
                          sInvCustomer        , 'CENTRAL'   , sInvDoc_Num , nPaymentAmount  , sCtro        ) ;                                  
                     nRecords := nRecords + 0 ;
                     IF ( pOutPut > 0 ) THEN
                        nStep := nStep + 1 ;
                        INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                           VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Processed' ) ;
                     END IF ;      
                     UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Processed'
                        WHERE ClearingDocNumber = pClearingDocNumber
                          AND ClearingDate      = pClearingDate     ;
--                        AND FiscalYear        = pFiscalYear  ;
                  ELSE
        -- Payement higher than credit note pending
                     IF ( pOutPut > 0 ) THEN
                        nStep := nStep + 1 ;
                        INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                           VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Payement higher than credit note pending' ) ;
                     END IF ;      
                     UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'CN exceeded'
                        WHERE IDocNumber = pIDocNumber ;   
                  END IF ;                        
               END IF ;
            ELSE
        -- Payment higher than invoice pending
               IF ( pOutPut > 0 ) THEN
                  nStep := nStep + 1 ;
                  INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                     VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Payment higher than invoice pending' ) ;
               END IF ;      
               UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Payment exceeded'
                  WHERE IDocNumber = pIDocNumber ;                       
            END IF ;
         ELSE
        -- Invoice does not exist
            IF ( pOutPut > 0 ) THEN
               nStep := nStep + 1 ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Invoice does not exist' ) ;
            END IF ;      
            UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Inv NOT Found'
               WHERE IDocNumber = pIDocNumber ;           
         END IF ;
      ELSE
        -- More than two items on Clearing Document
         IF ( pOutPut > 0 ) THEN
            nStep := nStep + 1 ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'More than two items on Clearing Document' ) ;
         END IF ;      
         UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Tx-MoreItems'
           WHERE IDocNumber = pIDocNumber ; 
      END IF ;
   ELSE   
      IF ( pOutput > 0 ) THEN
         nStep := nStep + 1 ;
         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
            VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'Tx-Discarded' ) ;
      END IF ;   
      UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Tx-Discarded'
        WHERE IDocNumber = pIDocNumber ;
   END IF ;       
   IF ( pOutput > 0 ) THEN
      nStep := nStep + 1 ;
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYALLOC', pIDocNumber, LPAD( nStep, 4 ) || 'End' ) ;
   END IF ;   
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE             , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Processing PI'    , sReferenceID          , SYSDATE             , NULL           ,
          'Error'            , 'PROC_CENTRAL_PAYMENT', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_CENTRAL_PAYALLOC ;