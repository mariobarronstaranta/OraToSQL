create or replace PROCEDURE           "WA_ACCNT_COMPLEMENT" 
   ( pDias           IN NUMBER   DEFAULT 0 )
   AS
--
   sReference            VARCHAR2(030) ;
   sReferenceInv         VARCHAR2(030) ;
   sReferenceCM          VARCHAR2(030) ;
   sReferenceRFC         VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
      SELECT IDocNumber,
             BillingDocument AS BillingDocument_Original, 
             NVL( BillingDocument, ReferenceDocNumber ) AS BillingDocument, Assignment, ReferenceDocNumber, 
             DC_Indicator, Cte_Invoice, Cte_CreditMemo, Cte_Tax_ID,
             EAI_Owner.get_4428_Reference( Assignment                                 ) AS Ref_Assignment,
             EAI_Owner.get_4428_Reference( NVL( BillingDocument, ReferenceDocNumber ) ) AS Ref_Billing   
         FROM EAI_Owner.tmp_Account_Header
         WHERE TRUNC( Created )    = TRUNC( SYSDATE - pDias )
           AND Cte_Tax_ID         IS NULL
           AND DocumentType       != 'BK' ;
           --AND ClearingDocNumber NOT LIKE '11000%' ;
--
   CURSOR ScrHistorico IS
      SELECT RF.Cliente_SAP, RF.Fecha_Factura, Cte.RFC
         FROM T3.Registro_Fiscal    RF ,
              T3.Cliente            Cte
         WHERE RF.Factura = sReference
           AND RF.Cliente_SAP = Cte.Cliente_SAP
           AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig ;
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
      sReference := Doc.Ref_Assignment ;
      IF    ( Doc.Ref_Assignment != Doc.Assignment   ) THEN
         sReference := Doc.Ref_Assignment ;
      ELSIF ( Doc.Ref_Billing != Doc.BillingDocument ) THEN
         sReference := Doc.Ref_Billing    ;
      ELSIF ( Doc.BillingDocument_Original IS NULL ) THEN
         sReference := Doc.Ref_Billing    ;
      ELSE
         sReference := Doc.Assignment     ; 
      END IF ;
      nPedidos := nPedidos + 1 ;   
      FOR Hist IN ScrHistorico LOOP
         sReferenceInv := '' ;
         sReferenceCM  := '' ;
         sReferenceRFC := Hist.RFC ;
         IF ( Doc.DC_Indicator = 'S' ) THEN
             sReferenceInv := sReference ;
         ELSE
             sReferenceCM  := sReference ;
         END IF ;
         UPDATE EAI_Owner.tmp_Account_Header SET Cte_Invoice    = sReferenceInv,
                                                 Cte_CreditMemo = sReferenceCM ,
                                                 Cte_Tax_ID     = sReferenceRFC
            WHERE IdocNumber = Doc.IDocNumber ;
      END LOOP ;
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
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
          'Error'            , 'WA_ACCNT_COMPLEMENT', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ACCNT_COMPLEMENT ;