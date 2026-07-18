create or replace PROCEDURE           "WA_ACCNT_PAYAMOUNT" 
   ( pDiasIni           IN NUMBER   DEFAULT 0,
     pDiasFin           IN NUMBER   DEFAULT 0 )
   AS
--
   sReference            VARCHAR2(030) ;
   sReferenceInv         VARCHAR2(030) ;
   sReferenceCM          VARCHAR2(030) ;
   sReferenceRFC         VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
      SELECT Info.*
         FROM (
                SELECT 
                       Info.ClearingDocument                                       AS ClearingDocument  ,
                       Info.ClearingDate                                           AS ClearingDate      ,
                       COUNT( Info.ClearingDocument )                              AS Count_Items       ,
                       MAX( Info.Reversal )                                        AS Reversal          ,
--
                       MAX( Info.Fact_DocReference  )                              AS Fact_DocReference ,
                       MAX( Info.Nota_DocReference  )                              AS Nota_DocReference ,
                       MIN( Info.Tax_ID             )                              AS Tax_ID            ,
--
                       MAX( Info.Fact_Reference     )                              AS Fact_Reference    ,
                       MAX( Info.Fact_PaymentAmount )                              AS Fact_PaymentAmount,
                       MAX( Info.Fact_PMS           )                              AS Fact_PMS          ,
                       MAX( Info.Fact_PayMethod     )                              AS Fact_PayMethod    ,
                       MAX( Info.Fact_Processed     )                              AS Fact_Processed    ,
                       MAX( Info.Fact_Status        )                              AS Fact_Status       ,
                       MAX( Info.Fact_IdocNumber    )                              AS Fact_IdocNumber   ,
--
                       MAX( Info.Nota_Reference     )                              AS Nota_Reference    ,
                       MAX( Info.Nota_PaymentAmount )                              AS Nota_PaymentAmount,
                       MAX( Info.Nota_PMS           )                              AS Nota_PMS          ,
                       MAX( Info.Nota_PayMethod     )                              AS Nota_PayMethod    ,
                       MAX( Info.Nota_Processed     )                              AS Nota_Processed    ,
                       MAX( Info.Nota_Status        )                              AS Nota_Status       ,
                       MAX( Info.Nota_IdocNumber    )                              AS Nota_IdocNumber   
                FROM (
                       SELECT 
                              Acc.ClearingDocNumber                                       AS ClearingDocument  ,
                              Acc.ClearingDate                                            AS ClearingDate      ,
                              Acc.Cte_Tax_ID                                              AS Tax_ID            ,
                              NVL( Acc.Reversal, ' ' )                                    AS Reversal          ,
--
                              DECODE( Acc.DC_Indicator, 'S', Acc.ReferenceDocNumber, '' ) AS Fact_Reference    ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.PaymentAmount     , '' ) AS Fact_PaymentAmount,
                              DECODE( Acc.DC_Indicator, 'S', Acc.PayMethSupplement , '' ) AS Fact_PMS          ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.PaymentMethod     , '' ) AS Fact_PayMethod    ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.Processed         , '' ) AS Fact_Processed    ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.Status            , '' ) AS Fact_Status       ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.IdocNumber        , '' ) AS Fact_IdocNumber   ,
                              DECODE( Acc.DC_Indicator, 'S', Acc.Cte_Invoice       , '' ) AS Fact_DocReference ,
--
                              DECODE( Acc.DC_Indicator, 'H', Acc.ReferenceDocNumber, '' ) AS Nota_Reference    ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.PaymentAmount     , '' ) AS Nota_PaymentAmount,
                              DECODE( Acc.DC_Indicator, 'H', Acc.PayMethSupplement , '' ) AS Nota_PMS          ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.PaymentMethod     , '' ) AS Nota_PayMethod    ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.Processed         , '' ) AS Nota_Processed    ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.Status            , '' ) AS Nota_Status       ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.IdocNumber        , '' ) AS Nota_IdocNumber   ,
                              DECODE( Acc.DC_Indicator, 'H', Acc.Cte_CreditMemo    , '' ) AS Nota_DocReference    
                          FROM EAI_Owner.tmp_Account_Header Acc
                          WHERE Acc.Created  > TRUNC( SYSDATE - pDiasIni )
                            AND Acc.Created  < TRUNC( SYSDATE - pDiasFin )
                          --AND Acc.Assignment IS NOT NULL
                            AND Acc.ClearingDocNumber NOT LIKE '11000%'
                            AND Acc.DocumentType != 'BK'
--                          AND Acc.ClearingDocNumber = '2104836350'
                     ) Info
                GROUP BY Info.ClearingDocument, Info.ClearingDate
                HAVING ( COUNT( Info.ClearingDocument ) = 2 ) 
                   AND ( MAX( Info.Nota_Reference ) IS NOT NULL ) 
                ) Info
         WHERE Info.Nota_Status        != 'Processed'       
           AND Info.Fact_PaymentAmount IS NULL
           AND Info.Reversal            = ' ' ;
--
   CURSOR Scr_WA_CN_ALLOC IS
       SELECT AH.*
          FROM EAI_Owner.tmp_Account_Header AH,
               EAI_OWNER.MX_HashTable       HT
          WHERE Created                              > TRUNC( SYSDATE - pDiasIni )
            AND HT.TYPE                              = 'SAP_BANK'
            AND SUBSTR( AH.ReferenceDocNumber, 1, 8) = HT.Target ;
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(08)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
BEGIN
--
   DBMS_Output.Put_Line( 'Inicio -> ' || TO_CHAR( SYSDATE, 'HH:MI:SS' ) ) ;
   nPedidos := 0 ;
   FOR Doc IN ScrDocuments LOOP
      sReference := Doc.Nota_IdocNumber ;
      nPedidos   := nPedidos + 1        ;   
      UPDATE EAI_Owner.tmp_Account_Header SET PaymentAmount = Doc.Nota_PaymentAmount, Original_PaymentAmt = PaymentAmount
        WHERE IdocNumber = Doc.Fact_IdocNumber ;
      UPDATE EAI_Owner.tmp_Account_Header SET Processed = NULL,
                                              Status    = NULL
        WHERE IdocNumber = Doc.Nota_IdocNumber ;
   END LOOP ;
--
   FOR Doc IN Scr_WA_CN_ALLOC LOOP
      INSERT INTO EAI_OWNER.TMP_ACCOUNT_BANK
         ( IdocNumber              , CompanyCode           , CustomerNumber        , AccntDocNumber       , Billingdocument    , Currency                  , 
           AmountDocCurrency       , Assignment            , DC_Indicator          , ClearingDocNumber    , Clearingdate       , Postingdate               , 
           DocumentType            , DocumentHeaderText    , ReferenceDocNumber    , Fyear                , Created            , Processed                 , 
           Reference_CreditMemo    , PayMethSupplement     , FiscalYear            , DueDateProcedure     , PaymentAmount      , 
           PaymentMethod           , Cte_Invoice           , Cte_Creditmemo        , Cte_Tax_ID           , Reversal           , Residualtransbelongsto    , 
           Status                  , Excluded_Date          )
     VALUES 
         ( Doc.IdocNumber          , Doc.CompanyCode       , Doc.CustomerNumber    , Doc.AccntDocNumber   , Doc.Billingdocument, Doc.Currency              , 
           Doc.AmountDocCurrency   , Doc.Assignment        , Doc.DC_Indicator      , Doc.ClearingDocNumber, Doc.Clearingdate   , Doc.Postingdate           , 
           Doc.DocumentType        , Doc.DocumentHeaderText, Doc.ReferenceDocNumber, Doc.Fyear            , Doc.Created        , Doc.Processed             , 
           Doc.Reference_CreditMemo, Doc.PayMethSupplement , Doc.FiscalYear        , Doc.DueDateProcedure , Doc.Paymentamount  , 
           Doc.PaymentMethod       , Doc.Cte_Invoice       , Doc.Cte_Creditmemo    , Doc.Cte_Tax_ID       , Doc.Reversal       , Doc.Residualtransbelongsto, 
           Doc.Status              , SYSDATE                ) ;
      DELETE EAI_Owner.tmp_Account_Header
         WHERE IdocNumber = Doc.IdocNumber ;
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   DBMS_Output.Put_Line( 'Fin -> ' || TO_CHAR( SYSDATE, 'HH:MI:SS' ) ) ;
   COMMIT ; 
   EAI_OWNER.WA_ACCNT_REFOLEO( pDiasIni, pDiasFin, 1 ) ;
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
          'Error'            , 'WA_ACCNT_COMPLEMENT', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ACCNT_PAYAMOUNT ;