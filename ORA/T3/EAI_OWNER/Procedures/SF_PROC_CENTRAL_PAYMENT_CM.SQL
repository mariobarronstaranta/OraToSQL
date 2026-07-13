create or replace PROCEDURE           SF_PROC_CENTRAL_PAYMENT_CM
   ( pIDocNum  IN   VARCHAR2 )
IS
   sMsg                    VARCHAR2(500) ;   
   v_ID                    VARCHAR2(030) ;
   sErrorCode              VARCHAR2(020) ;
   sReferenceID            VARCHAR2(030) ;
   sProcesar               VARCHAR2(020) ;
   sIDocNum                VARCHAR2(020) ;
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
                           CASE
                              WHEN Det.AmountInDocumentCurrency IS NULL           THEN NVL( Doc.AmountDocCurrency       , 0 )
                              WHEN ( NVL( Det.AmountInDocumentCurrency, 0 ) > 0 ) THEN NVL( Det.AmountInDocumentCurrency, 0 )
                           END                                                   AS Amount             ,
                           Doc.ReferenceDocNumber                                AS ReferenceDocNumber ,    
--                         SUBSTR( Doc.PostingDate , 3, 2 )                      AS Fiscal_Year        ,
                           SUBSTR( Doc.ClearingDate, 3, 2 )                      AS Fiscal_Year        ,
                           Doc.AccntDocNumber                                    AS Payment_Num        ,
                           TO_DATE( Doc.PostingDate, 'YYYYMMDD' )                AS Posting_Date       ,
--                         Doc.PostingDate                                       AS Fecha              ,
                           SUBSTR( Doc.PostingDate, 5, 2 ) || '/' ||
                           SUBSTR( Doc.PostingDate, 7, 2 ) || '/' ||
                           SUBSTR( Doc.PostingDate, 1, 4 )                       AS PostingDate_Char   ,
                           Doc.CustomerNumber                                    AS Customer_Payer     ,
                           Doc.IDocNumber                                        AS IDocNumber         ,
                           Doc.Reference_CreditMemo                              AS CM_Reference
                    FROM EAI_Owner.tmp_Account_Header Doc,
                         EAI_Owner.tmp_Account_Detail Det
                    WHERE Doc.IDocNumber    = sIDocNum
                    --AND Doc.Processed    IS NULL
                      AND Doc.IDocNumber    = Det.IDocNumber(+) 
                      AND Doc.DocumentType  = 'ZV' ;
--
BEGIN
   sReferenceID := pIDocNum ;
   sIDocNum     := SUBSTR( pIDocNum, 7, 10 ) ;
   sProcesar    := 'YES'    ;
      DBMS_Output.Put_Line( 'sIDocNum: ' || sIDocNum ) ;
   sProcesar    := EAI_Owner.CHK_BANKCENTRAL_ALLOC( sIDocNum ) ;
   
   DBMS_Output.Put_Line( 'sProcesar: ' || sProcesar ) ;
   
   IF ( sProcesar != 'NO' ) THEN    
      FOR Rec IN ScrData LOOP 
         nAmount              := Rec.Amount               ;
         sReferenceDocNumber  := Rec.ReferenceDocNumber   ;
         sNCDocNumber         := Rec.CM_Reference;
         sPayment_Num         := Rec.Payment_Num          ;
         sPago_Integration_ID := Rec.Fiscal_Year || sPayment_Num ;
         dtPostingDate        := Rec.Posting_Date         ;
         sCustomerPayer       := Rec.Customer_Payer       ;
         sIDocNumber          := Rec.IDocNumber           ;
         sPayment_Method      := 'T'                      ;
--
         EAI_OWNER.SF_GET_INVOICE_DATA( sReferenceDocNumber, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid  ) ;
         
         DBMS_Output.Put_Line( 'sReferenceDocNumber: ' || sReferenceDocNumber ) ;
         DBMS_Output.Put_Line( 'sInvDoc_Num: ' || sInvDoc_Num ) ;
         DBMS_Output.Put_Line( 'sInvCustomer: ' || sInvCustomer ) ;
         DBMS_Output.Put_Line( 'nInvAmount: ' || nInvAmount ) ;
         DBMS_Output.Put_Line( 'nInvPending: ' || nInvPending ) ;

         EAI_OWNER.SF_GET_CREDIT_DATA( sNCDocNumber, sNCDoc_Num, sNCCustomer, nNCAmount , nNCPending, nNCPaid  ) ;
         
         DBMS_Output.Put_Line( 'sNCDocNumber: ' || sNCDocNumber ) ;
         DBMS_Output.Put_Line( 'sNCDoc_Num: ' || sNCDoc_Num ) ;
         DBMS_Output.Put_Line( 'sNCCustomer: ' || sNCCustomer ) ;
         DBMS_Output.Put_Line( 'nNCAmount: ' || nNCAmount ) ;
         DBMS_Output.Put_Line( 'nNCPending: ' || nNCPending ) ;
         
         IF ( nInvAmount > 0 ) THEN
  
                 DBMS_Output.Put_Line( 'nInvPending: ' || nInvPending ) ;
                 DBMS_Output.Put_Line( 'nAmount: ' || nAmount ) ;
                 DBMS_Output.Put_Line( 'nNCPending: ' || nNCPending ) ;
       
            IF ( nInvPending >= nAmount AND nAmount <= nNCPending ) THEN
               EAI_OWNER.SF_GET_CUSTOMER_DATA( sInvCustomer, dtPostingDate, sCustomer_TMD, sCtro, nDistributor, sRep_ID, sCustomer_Name ) ;
                 
               DBMS_Output.Put_Line( 'sCtro: ' || sCtro ) ;
               IF ( LENGTH( sCtro ) > 2 ) THEN
--                  INSERT INTO T3.Pago 
--                    ( Pago_ID              , Fecha_Trn   , Distribuidor, Fecha_Pago     , Cliente_V3  , 
--                      Cliente_SAP          , Rep_ID      , Tipo_Pago   , Metodo_Pago    , Valor_Pago  ,
--                      Ctro                                                                             )
--                  VALUES
--                     ( sPago_Integration_ID, SYSDATE     , nDistributor, dtPostingDate   , sCustomer_TMD,
--                       sInvCustomer        , sRep_ID     , 'Payment'   , sPayment_Method , nAmount      ,
--                       sCtro                                                                           ) ;
                  INSERT INTO T3.Asignacion_Pago 
                    ( Pago_ID              , Fecha_Trn   , Distribuidor, Fecha_Asignacion, Cliente_V3  , 
                      Asignacion_ID        , Nota_Credito,
                      Cliente_SAP          , Rep_ID      , Factura     , Valor_Pago      , Ctro         )
                  VALUES
                     ( sPago_Integration_ID, SYSDATE     , nDistributor, dtPostingDate   , sCustomer_TMD,
                       sPago_Integration_ID, sNCDoc_Num  ,
                       sInvCustomer        , sRep_ID     , sInvDoc_Num , nAmount       , sCtro        ) ;    
                                          
                  UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Processed'
                      WHERE IDocNumber = sIDocNum ;                       
                ELSE
         -- Assignment greather than Pending
                UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Customer Does not exist'
                  WHERE IDocNumber = sIDocNum ;               
                END IF ;          
            ELSE
         -- Assignment greather than Pending
               UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Amount > Pending'
                  WHERE IDocNumber = sIDocNum ;            
            END IF ;
         ELSE
         -- Not Receivable Document
               UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Not Receivable'
                  WHERE IDocNumber = sIDocNum ;         
         END IF ;
      END LOOP ;
   ELSE   
      UPDATE EAI_Owner.tmp_Account_Header SET Processed = SYSDATE, Status = 'Tx-Duplicated'
        WHERE IDocNumber = sIDocNum ;
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
END SF_PROC_CENTRAL_PAYMENT_CM ;