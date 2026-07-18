create or replace PROCEDURE           SF_PROC_CENTRAL_PAYMENT_ZV
   ( pIDocNum  IN   VARCHAR2,
     pOutput   IN   NUMBER DEFAULT 0 )
IS
   sMsg                    VARCHAR2(500) ;   
   v_ID                    VARCHAR2(030) ;
   sErrorCode              VARCHAR2(020) ;
   sReferenceID            VARCHAR2(030) ;
   sProcesar               VARCHAR2(020) ;
   sIDocNum                VARCHAR2(020) ;
--   
   sReferenceDocNumber     VARCHAR2(050) ;  
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
   nAbsolute               NUMBER(15,2)  ;
   nPaid                   NUMBER(15,2)  ;
   sCustomer_Name          VARCHAR2(1024);
--
   CURSOR ScrData IS
                    SELECT 
                           NVL( Doc.PaymentAmount, 0 )                           AS Amount             ,
                           Doc.ReferenceDocNumber                                AS ReferenceDocNumber ,    
--                         SUBSTR( Doc.PostingDate , 3, 2 )                      AS Fiscal_Year        ,
                           SUBSTR( Doc.ClearingDate, 3, 2 )                      AS Fiscal_Year        ,
--                         Doc.AccntDocNumber                                    AS Payment_Num        ,
                           Doc.ClearingDocNumber                                 AS Payment_Num        ,
--                         TO_DATE( Doc.PostingDate, 'YYYYMMDD' )                AS Posting_Date       ,
                           TO_DATE( Doc.ClearingDate, 'YYYYMMDD' )               AS Posting_Date       ,
--                         Doc.PostingDate                                       AS Fecha              ,
--                           SUBSTR( Doc.PostingDate, 5, 2 ) || '/' ||
--                           SUBSTR( Doc.PostingDate, 7, 2 ) || '/' ||
--                           SUBSTR( Doc.PostingDate, 1, 4 )                       AS PostingDate_Char   ,
                           SUBSTR( Doc.ClearingDate, 5, 2 ) || '/' ||
                           SUBSTR( Doc.ClearingDate, 7, 2 ) || '/' ||
                           SUBSTR( Doc.ClearingDate, 1, 4 )                      AS PostingDate_Char   ,
                           Doc.CustomerNumber                                    AS Customer_Payer     ,
                           Doc.IDocNumber                                        AS IDocNumber         ,
                           EAI_Owner.GetConv( 'ECC_T3 PaymentMethod', Doc.PayMethSupplement  )
                                                                                 AS Payment_Method     ,
                           EAI_Owner.GetConv( 'ECC_T3 PaymentMethod', 
                               NVL( Cte.Payment_Method, Doc.PayMethSupplement ) )
                                                                                 AS Def_Payment_Method                                                                            
                    FROM EAI_Owner.tmp_Account_Header Doc,
                         EAI_Owner.Client             Cte
                    WHERE Doc.IDocNumber               = sIDocNum
                      AND Doc.PayMethSupplement       IS NOT NULL
                    --AND Doc.Assignment              IS NOT NULL
                      AND Doc.PayMethSupplement       != 'Z9'
                      AND Doc.CustomerNumber           = Cte.Cliente_SAP(+)
                      AND NVL( Doc.PaymentAmount, 0 )  > 0 ;
--
BEGIN
   sReferenceID := pIDocNum ;
   sIDocNum     := SUBSTR( pIDocNum, 7, 10 ) ;
   sProcesar    := 'YES'    ;
   IF ( pOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Begin' ) ;
   END IF ;
   sProcesar    := EAI_Owner.SF_PAYMENT_ALLOC( sIDocNum ) ;
   IF ( sProcesar != 'NO' ) THEN    
      IF ( pOutput > 0 ) THEN
         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
            VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Before ScrData' ) ;
      END IF ;
      FOR Rec IN ScrData LOOP 
         nAmount              := Rec.Amount               ;
         sReferenceDocNumber  := Rec.ReferenceDocNumber   ;
         sPayment_Num         := Rec.Payment_Num          ;
         sPago_Integration_ID := Rec.Fiscal_Year || sPayment_Num ;
         dtPostingDate        := Rec.Posting_Date         ;
         sCustomerPayer       := Rec.Customer_Payer       ;
         sIDocNumber          := Rec.IDocNumber           ;
         sPayment_Method      := Rec.Payment_Method       ;
--
         IF ( pOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, sReferenceDocNumber ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'SF_GET_INVOICE_DATA' ) ;
         END IF ;
         EAI_OWNER.SF_GET_INVOICE_DATA( sReferenceDocNumber, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid ) ;
         IF ( nInvAmount > 0 ) THEN
            nAbsolute := ABS( nAmount - nInvPending ) ;
            IF ( ( nAmount > nInvPending ) AND ( nAbsolute < 0.05 ) ) THEN
               nAmount := nInvPending ;
            END IF ;
            IF ( ( nAmount <= nInvPending ) AND ( nAmount > 0 ) ) THEN
               IF ( pOutput > 0 ) THEN
                  INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                     VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, sInvCustomer ) ;
                  INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                     VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'SF_GET_CUSTOMER_DATA' ) ;
               END IF ;
               EAI_OWNER.SF_GET_CUSTOMER_DATA( sInvCustomer, dtPostingDate, sCustomer_TMD, sCtro, nDistributor, sRep_ID, sCustomer_Name ) ;  
               IF ( LENGTH( sCtro ) > 2 ) THEN
                  INSERT INTO T3.Pago 
                    ( Pago_ID              , Fecha_Trn   , Distribuidor, Fecha_Pago     , Cliente_V3  , 
                      Cliente_SAP          , Rep_ID      , Tipo_Pago   , Metodo_Pago    , Valor_Pago  ,
                      Ctro                                                                             )
                  VALUES
                     ( sPago_Integration_ID, SYSDATE     , nDistributor, dtPostingDate   , sCustomer_TMD,
                       sInvCustomer        , sRep_ID     , 'Payment'   , sPayment_Method , nAmount      ,
                       sCtro                                                                           ) ;
                  INSERT INTO T3.Asignacion_Pago 
                    ( Pago_ID              , Fecha_Trn   , Distribuidor, Fecha_Asignacion, Cliente_V3  , 
                      Asignacion_ID        ,
                      Cliente_SAP          , Rep_ID      , Factura     , Valor_Pago      , Ctro         )
                  VALUES
                     ( sPago_Integration_ID, SYSDATE     , nDistributor, dtPostingDate  , sCustomer_TMD,
                       sPago_Integration_ID,
                       sInvCustomer        , sRep_ID     , sInvDoc_Num , nAmount        , sCtro         ) ;                       
                  IF ( pOutput > 0 ) THEN
                     INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                        VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Processed' ) ;
                  END IF ; 
                  UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Processed'
                      WHERE IDocNumber = sIDocNum ;                       
               ELSE
         -- Assignment greather than Pending
                  IF ( pOutput > 0 ) THEN
                     INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                        VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Customer does not exist' ) ;
                  END IF ; 
                  UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Customer Invalid'
                     WHERE IDocNumber = sIDocNum ;               
               END IF ;          
            ELSE
         -- Assignment greather than Pending
               IF ( pOutput > 0 ) THEN
                  INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                     VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Amount > Pending' ) ;
               END IF ; 
               IF ( nAmount > 0 ) THEN
                  UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Amount > Pending'
                     WHERE IDocNumber = sIDocNum ;            
               ELSE
                  UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Discarded'
                     WHERE IDocNumber = sIDocNum ;            
               END IF ;
            END IF ;
         ELSE
         -- Not Receivable Document
               IF ( pOutput > 0 ) THEN
                  INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                     VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Document is not Receivable' ) ;
               END IF ; 
               UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Not Receivable'
                  WHERE IDocNumber = sIDocNum ;         
         END IF ;
      END LOOP ;
   ELSE   
      IF ( pOutput > 0 ) THEN
         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
           VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'Tx-Duplicated' ) ;
      END IF ; 
      UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Tx-Duplicated'
        WHERE IDocNumber = sIDocNum ;
   END IF ;       
   IF ( pOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT_ZV', sReferenceID, 'End' ) ;
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
END SF_PROC_CENTRAL_PAYMENT_ZV ;