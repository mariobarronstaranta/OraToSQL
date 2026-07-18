create or replace PROCEDURE           SF_PROC_CENTRAL_PAYMENT ( 
    sRow_ID   IN   VARCHAR2,
    nRowNum   IN   NUMBER DEFAULT 1,
    nOutput   IN   NUMBER DEFAULT 0,
    nPID      IN   NUMBER DEFAULT NULL
) IS
   sMsg                    VARCHAR2(500) ;   
   v_ID                    VARCHAR2(030) ;
   sErrorCode              VARCHAR2(020) ;
   sReferenceID            VARCHAR2(030) ;
   sProcesar               VARCHAR2(020) ;
--   
   docIDocNumber                 VARCHAR2(010) ; 
   docCompanyCode                VARCHAR2(100) ; 
   docCustomerNumber             VARCHAR2(100) ;
   docReferenceLog               VARCHAR2(020) ;
   docAccntDocNumber             VARCHAR2(100) ;
   docBillingDocument            VARCHAR2(100) ;
   docCurrency                   VARCHAR2(100) ;
   docAmountDocCurrency          VARCHAR2(100) ;
   docAssignment                 VARCHAR2(100) ;
   docDC_Indicator               VARCHAR2(100) ;
   docClearingDocNumber          VARCHAR2(100) ;
   docClearingDate               VARCHAR2(100) ;
   docClearingSiebelDate         VARCHAR2(100) ;
   docPostingdate                VARCHAR2(100) ;
   docPostingdateDocument        VARCHAR2(100) ;
   docDocumentType               VARCHAR2(100) ;   
   docDocumentHeadertext         VARCHAR2(100) ;
   docReferenceDocNumber         VARCHAR2(100) ;
   docResidualDocNumber          VARCHAR2(100) ;
   docFYear                      VARCHAR2(100) ;
   docReversalFlag               VARCHAR2(100) ;
-- --
   docPaymMethSupplement         VARCHAR2(100) ;
   docFiscalYear                 VARCHAR2(100) ;
   docFiscalYearClearing         VARCHAR2(100) ;
   docDueDateProcedure           VARCHAR2(100) ;
   docPaymentAmount              VARCHAR2(100) ;
   docPaymentMethod              VARCHAR2(100) ;
   docPayment_MessageType        VARCHAR2(100) ;
   numAmountDocCurrency          NUMBER(15,2)  ;
   numPaymentAmount              NUMBER(15,2)  ;
   numOriginalPayment            NUMBER(15,2)  ;
   docIvy_Source                 VARCHAR2(010) ;
   docIvy_Diff                   NUMBER(15,2)  ;   
--
   detAccountingDocumentNumber   VARCHAR2(100) ; 
   detCurrency                   VARCHAR2(100) ; 
   detAmountinDocumentCurrency   VARCHAR2(100) ; 
   detAssignment                 VARCHAR2(100) ; 
   detPostingdate                VARCHAR2(100) ; 
   detDocumentType               VARCHAR2(100) ; 
   detReferenceKeyforLineItem    VARCHAR2(100) ; 
   detHeaderRefDocumentNumber    VARCHAR2(100) ; 
   detItemText                   VARCHAR2(100) ; 
   sIntegration_ID               VARCHAR2(100) ;
   invoiceUsed                   VARCHAR2(100) ;
   creditNoteUsed                VARCHAR2(100) ;   
   invoiceReceived               VARCHAR2(100) ;
   creditNoteReceived            VARCHAR2(100) ;
   invoiceFoundAsPresales        VARCHAR2(100) ;
   creditNFoundAsPresales        VARCHAR2(100) ;
   indexOfComma                  NUMBER(10)    ;
   detItemID                     NUMBER(10)    ;
--
   CURSOR ScrData IS        
      SELECT
            extractValue( XML_Content, '/Payment/Header/Reference/ReferenceID'                   )            AS IDoc_Number           ,        
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/CompanyCode'               )            AS CompanyCode           ,  
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/CustomerNumber'            )            AS CustomerNumber        ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/AccountingDocumentNumber'  )            AS AccntDocNumber        ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/BillingDocument'           )            AS BillingDocument       ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/Currency'                  )            AS Currency              ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/AmountinDocumentCurrency'  )            AS AmountDocCurrency     ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/Assignment'                )            AS Assignment            ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/DebitCreditIndicator'      )            AS DC_Indicator          ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/ClearingDocumentNumber'    )            AS ClearingDocNumber     ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/ClearingDate'              )            AS ClearingDate          ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/Postingdate'               )            AS Postingdate           ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/DocumentType'              )            AS DocumentType          ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/DocumentHeadertext'        )            AS DocumentHeadertext    ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/ReferenceDocumentNumber'   )            AS ReferenceDocNumber    ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/NumbInvoiceTransBelongsto' )            AS ResidualTransBelongsto,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/FYearRelevantInvoice'      )            AS FYear                 ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/ReversalFlag'              )            AS ReversalFlag          ,
--
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/PaymMethSupplement'        )            AS PaymMethSupplement    ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/FiscalYear'                )            AS FiscalYear            ,
            SUBSTR( 
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/ClearingDate' ), 1, 4      )            AS FiscalYearClearing    ,          
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/DueDateProcedure'          )            AS DueDateProcedure      ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/PostingDateDocument'       )            AS PostingDateDocument   ,
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/PaymentAmount'             )            AS PaymentAmount         ,            
            extractValue( XML_Content, '/Payment/Message/ZTMDALLOCPAY/PaymentMethod'             )            AS PaymentMethod         ,
--
            extractValue( XML_Content, '/Invoice/Header/MessageType'                             )            AS Payment_MessageType
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;  
     
--
   CURSOR ScrDetail IS
      SELECT ExtractValue( VALUE( Lista ), '*/AccountingDocumentNumber'   ) AS AccountingDocumentNumber ,
             ExtractValue( VALUE( Lista ), '*/Currency'                   ) AS Currency                 ,
             ExtractValue( VALUE( Lista ), '*/AmountinDocumentCurrency'   ) AS AmountinDocumentCurrency ,
             ExtractValue( VALUE( Lista ), '*/Assignment'                 ) AS Assignment               ,
             ExtractValue( VALUE( Lista ), '*/Postingdate'                ) AS Postingdate              ,
             ExtractValue( VALUE( Lista ), '*/DocumentType'               ) AS DocumentType             ,
             ExtractValue( VALUE( Lista ), '*/ReferenceKeyforLineItem'    ) AS ReferenceKeyforLineItem  ,
             ExtractValue( VALUE( Lista ), '*/HeaderRefDocumentNumber'    ) AS HeaderRefDocumentNumber  ,
             ExtractValue( VALUE( Lista ), '*/ItemText'                   ) AS ItemText
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Payment/Message/ZTMDCENTPAY' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;

   CURSOR SourceAllocDetail IS
      SELECT ExtractValue( VALUE( Lista ), '*/AccountingDocumentNumber'   ) AS AccountingDocumentNumber ,
             ExtractValue( VALUE( Lista ), '*/Currency'                   ) AS Currency                 ,
             ExtractValue( VALUE( Lista ), '*/AmountinDocumentCurrency'   ) AS AmountinDocumentCurrency ,
             ExtractValue( VALUE( Lista ), '*/Assignment'                 ) AS Assignment               ,
             ExtractValue( VALUE( Lista ), '*/Postingdate'                ) AS Postingdate              ,
             ExtractValue( VALUE( Lista ), '*/DocumentType'               ) AS DocumentType             ,
             ExtractValue( VALUE( Lista ), '*/ReferenceKeyforLineItem'    ) AS ReferenceKeyforLineItem  ,
             ExtractValue( VALUE( Lista ), '*/HeaderRefDocumentNumber'    ) AS HeaderRefDocumentNumber  ,
             ExtractValue( VALUE( Lista ), '*/ItemText'                   ) AS ItemText
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Payment/Message/ZTMDALLOCPAY' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
BEGIN
    docFiscalYearClearing := 0 ;
    IF ( nOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'Begin' ) ;
    END IF ; 
    FOR Rec IN ScrData LOOP
        docIDocNumber          := SUBSTR( Rec.IDoc_Number, 7, 10 ) ;
        docReferenceLog        := Rec.AccntDocNumber     ;
        docCompanyCode         := Rec.CompanyCode        ;
        docCustomerNumber      := Rec.CustomerNumber     ;
        docAccntDocNumber      := Rec.AccntDocNumber     ;
        docBillingDocument     := Rec.BillingDocument    ;
        docCurrency            := Rec.Currency           ;
        docAmountDocCurrency   := Rec.AmountDocCurrency  ;
        IF ( INSTR( Rec.AmountDocCurrency, '-' ) > 0 ) THEN
            docAmountDocCurrency := REPLACE( docAmountDocCurrency, '-', '' ) ;
            docAmountDocCurrency := '-' || docAmountDocCurrency ;
        END IF ;
        docAssignment          := Rec.Assignment             ;
        docDC_Indicator        := Rec.DC_Indicator           ;
        docClearingDocNumber   := Rec.ClearingDocNumber      ;
        docClearingDate        := Rec.ClearingDate           ;
        docPostingdate         := Rec.Postingdate            ;
        docDocumentType        := Rec.DocumentType           ;
        docDocumentHeadertext  := Rec.DocumentHeadertext     ;
        docReferenceDocNumber  := Rec.ReferenceDocNumber     ;
        docResidualDocNumber   := Rec.ResidualTransBelongsto ;
        docFYear               := Rec.FYear                  ;
        docReversalFlag        := Rec.ReversalFlag           ;
--
        docPaymMethSupplement  := Rec.PaymMethSupplement     ;
        docFiscalYear          := Rec.FiscalYear             ;
        docDueDateProcedure    := Rec.DueDateProcedure       ;
        docPostingdateDocument := Rec.PostingDateDocument    ;
        docPaymentAmount       := Rec.PaymentAmount          ;
        docPaymentMethod       := Rec.PaymentMethod          ;
        docPayment_MessageType := Rec.Payment_MessageType    ;
--
           docIvy_Source       := 'NO'                       ;
           docIvy_Diff         := 0.00                       ;
        IF ( SUBSTR( docClearingDocNumber, 1, 2 ) = '22' ) THEN
           docIvy_Source       := 'YES'                      ;
        END IF ;       
--
        IF ( INSTR( Rec.PaymentAmount, '-' ) > 0 ) THEN
            docPaymentAmount := REPLACE( docPaymentAmount, '-', '' ) ;
            docPaymentAmount := '-' || docPaymentAmount ;
        END IF ;
        IF ( LENGTH( docClearingDate ) > 4 ) THEN
           docFiscalYearClearing := SUBSTR( docClearingDate, 1, 4 ) ;
        END IF ;
--
        DELETE FROM EAI_Owner.tmp_Account_Header  WHERE IDocNumber  = docIDOCNumber ;
        DELETE FROM EAI_Owner.tmp_Account_Detail  WHERE IDocNumber  = docIDOCNumber ;
 --      
        IF ( nOutput > 0 ) THEN
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'CustomerNumber     => ' || docCustomerNumber     ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'AccntDocNumber     => ' || docAccntDocNumber     ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'BillingDocument    => ' || docBillingDocument    ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'AmountDocCurrency  => ' || docAmountDocCurrency  ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'Assignment         => ' || docAssignment         ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'DC_Indicator       => ' || docDC_Indicator       ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'ClearingDocNumber  => ' || docClearingDocNumber  ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'ClearingDate       => ' || docClearingDate       ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'Postingdate        => ' || docPostingdate        ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'DocumentType       => ' || docDocumentType       ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'DocumentHeadertext => ' || docDocumentHeadertext ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'ReferenceDocNumber => ' || docReferenceDocNumber ) ;
--             
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'PaymMethSupplement => ' || docPaymMethSupplement ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'FiscalYear         => ' || docFiscalYear         ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'FiscalYearClearing => ' || docFiscalYearClearing ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'DueDateProcedure   => ' || docDueDateProcedure   ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'PostingDateDoc     => ' || docPostingdateDocument) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'PaymentAmount      => ' || docPaymentAmount      ) ;
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'PaymentMethod      => ' || docPaymentMethod      ) ;                                          
           INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
              VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'PaymentMethod      => ' || docPaymentMethod      ) ;                                          
        END IF ;
        IF ( LENGTH( docAmountDocCurrency ) > 0 ) THEN
           numAmountDocCurrency := TO_NUMBER( docAmountDocCurrency ) ;
        ELSE
           numAmountDocCurrency := NULL ;
        END IF ;
        IF ( LENGTH( docPaymentAmount ) > 0 ) THEN
           numPaymentAmount := TO_NUMBER( docPaymentAmount ) ;
        ELSE
           numPaymentAmount := NULL ;
        END IF ;
        IF ( LENGTH( docFiscalYearClearing ) > 0 ) THEN
           docFiscalYear := docFiscalYearClearing ;
        END IF ;
        numOriginalPayment := numPaymentAmount ;
        IF    ( docPaymentMethod = 'OP' ) THEN
           IF ( docIvy_Source = 'YES' ) THEN
              IF ( ( NVL( numPaymentAmount, 0 ) > 0 ) AND ( NVL( numAmountDocCurrency, 0) > 0 ) ) THEN
                 docIvy_Diff := numPaymentAmount - numAmountDocCurrency ;
                 IF ( docIvy_Diff <= 5.00 ) THEN
                    numPaymentAmount := numAmountDocCurrency ;
                 ELSE
                    numPaymentAmount := 0 ;
                 END IF ;
              END IF ;
           ELSE
              numPaymentAmount := numAmountDocCurrency ;
           END IF ;   
        ELSIF ( docPaymentMethod = 'FP' ) THEN
           numPaymentAmount := numAmountDocCurrency ;
        END IF ;        
        IF ( LENGTH( docIDocNumber ) > 6 ) THEN 
           INSERT INTO EAI_Owner.tmp_Account_Header (
               IDocNumber            , CompanyCode           , CustomerNumber        , AccntDocNumber        ,
               BillingDocument       , Currency              , AmountDocCurrency     , Assignment            ,
               Created               , PayMethSupplement     , FiscalYear            , ResidualTransBelongsTo,
               DueDateProcedure      , PaymentAmount         , PaymentMethod         , Reversal              ,
               DC_Indicator          , ClearingDocNumber     , ClearingDate          , Postingdate           ,
               Original_PaymentAmt   , PostingDateDocument   ,           
               DocumentType          , DocumentHeadertext    , ReferenceDocNumber    , FYear                  ) 
           VALUES (
               docIDocNumber         , docCompanyCode        , docCustomerNumber     , docAccntDocNumber     ,
               docBillingDocument    , docCurrency           , numAmountDocCurrency  , docAssignment         ,
               SYSDATE               , docPaymMethSupplement , docFiscalYear         , docResidualDocNumber  ,
               docDueDateProcedure   , numPaymentAmount      , docPaymentMethod      , docReversalFlag       ,
               docDC_Indicator       , docClearingDocNumber  , docClearingDate       , docPostingdate        ,
               numOriginalPayment    , docPostingdateDocument,           
               docDocumentType       , docDocumentHeadertext , docReferenceDocNumber , docFYear               ) ;
          sProcesar := 'SI' ;   
       ELSIF ( LENGTH( docPayment_MessageType ) > 5 ) THEN
          IF ( nOutput > 0 ) THEN
             INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'WA -> DebitNote' ) ;
          END IF ;     
          EAI_Owner.SF_PROC_PREINVOICE_IFC( sRow_ID ) ;
       END IF ;   
    END LOOP ;    
    IF ( nOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_PAYMENT', sRow_ID, 'End' ) ;
    END IF ;     
    IF ( LENGTH( docIDocNumber ) > 6 ) THEN 
       UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE        , 
                                                  Reference = docReferenceLog,
                                                  Status    = DECODE( sProcesar, 'SI', 'Processed', 
                                                                                 'ED', 'CheckData',
                                                                                       'Review' )
          WHERE Row_ID = sROW_ID ;    
    END IF ;     
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG 
           ( DIRECTION          , REFERENCE             , CREATED             , MESSAGE        , JOB_PID,
	           STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	           SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID    ) 
        VALUES
           ( 'Job Logging'      , sRow_ID               , SYSDATE             , NULL           , nPID   ,
             'Error'            , 'PROC_CENTRAL_PAYMENT', sMsg                , 'PL/SQL'       ,
             sErrorCode         , NULL                  , NULL                , NULL              ) ;
        COMMIT ;
END SF_PROC_CENTRAL_PAYMENT ;