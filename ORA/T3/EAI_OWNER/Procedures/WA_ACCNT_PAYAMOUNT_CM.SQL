create or replace PROCEDURE           "WA_ACCNT_PAYAMOUNT_CM" 
   ( pDiasIni           IN NUMBER   DEFAULT 0,
     pDiasFin           IN NUMBER   DEFAULT 0 )
   AS
--
   sClearingDocument     VARCHAR2(20)  ;
   sClearingDocumentUpd  VARCHAR2(20)  ;
   nDocumentos           NUMBER(04)    ;
--
   CURSOR ScrDocuments IS
    SELECT 
           Info.ClearingDocument                                                   AS ClearingDocument  ,
           Info.ClearingDate                                                       AS ClearingDate      ,
           Info.PaymentAmount                                                      AS PaymentAmount     ,
           Info.Fact_DocReference                                                  AS Fact_DocReference ,
           Info.Nota_DocReference                                                  AS Nota_DocReference ,
           Info.Fact_IDocNumber                                                    AS Fact_IDocNumber   ,
           Info.Nota_IDocNumber                                                    AS Nota_IDocNumber
         FROM (
                SELECT 
                       Info.ClearingDocument                                       AS ClearingDocument  ,
                       Info.ClearingDate                                           AS ClearingDate      ,
                       Info.PaymentAmount                                          AS PaymentAmount     ,
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
                              NVL( Acc.PaymentAmount, 0 )                                 AS PaymentAmount     ,
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
                            AND Acc.PayMethSupplement = 'Z9'
                     ) Info
                GROUP BY Info.ClearingDocument, Info.ClearingDate, Info.PaymentAmount
                HAVING ( COUNT( Info.ClearingDocument ) = 2 ) 
                   AND ( MAX( Info.Nota_Reference ) IS NOT NULL ) 
                ) Info
         WHERE Info.Fact_DocReference  IS NOT NULL
           AND Info.Nota_DocReference  IS NOT NULL
           AND Info.Fact_Status        IS NULL
           AND Info.Nota_Status        IS NULL
           AND Info.Reversal            = ' ' 
         ORDER BY Info.ClearingDocument, Info.Nota_DocReference ;
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
   sClearingDocument := 'Initial' ;
   FOR Doc IN ScrDocuments LOOP
      IF ( sClearingDocument != Doc.ClearingDocument ) THEN
          sClearingDocument := Doc.ClearingDocument ; 
           SELECT COUNT( AP.Pago_ID ) INTO nDocumentos
              FROM T3.Asignacion_Pago AP
              WHERE AP.Asignacion_ID LIKE sClearingDocument || '%' ;
           IF ( NVL( nDocumentos, 0 ) = 0 ) THEN
              nDocumentos := 0 ;
           END IF ;
      END IF ;
--      
      nPedidos             := nPedidos    + 1 ;
      nDocumentos          := nDocumentos + 1 ;
      sClearingDocumentUpd := sClearingDocument || EAI_Owner.FN_CONV_DOCTO_LETRA( nDocumentos ) ;
      DBMS_Output.Put_Line( 'Referencia -> ' || sClearingDocumentUpd ) ;
--      
      UPDATE EAI_Owner.tmp_Account_Header SET ClearingDocNumber = sClearingDocumentUpd WHERE IdocNumber = Doc.Fact_IDocNumber ;
      UPDATE EAI_Owner.tmp_Account_Header SET ClearingDocNumber = sClearingDocumentUpd WHERE IdocNumber = Doc.Nota_IDocNumber ;
   END LOOP ;
--
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   DBMS_Output.Put_Line( 'Fin -> ' || TO_CHAR( SYSDATE, 'HH:MI:SS' ) ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE              , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME             , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT            , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                   , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ACCNT_PAYAMOUNT_CM', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                   , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ACCNT_PAYAMOUNT_CM ;