create or replace PROCEDURE           "WA_ACCNT_REFOLEO" 
   ( pDiasIni           IN NUMBER   DEFAULT 0,
     pDiasFin           IN NUMBER   DEFAULT 0,
     pClearStatus       IN NUMBER   DEFAULT 0 )
   AS
--
   sReference            VARCHAR2(030) ;
   sReferenceInv         VARCHAR2(030) ;
   sReferenceCM          VARCHAR2(030) ;
   sReferenceRFC         VARCHAR2(030) ;
--
   CURSOR ScrDocuments IS
         SELECT Info.*, RF.Cliente_SAP
            FROM (
                   SELECT Acc.IdocNumber, Acc.CustomerNumber, Acc.ClearingDocNumber, Acc.ClearingDate, Acc.DC_Indicator,
                          Acc.ReferenceDocNumber, Acc.Created, Acc.Processed, Acc.Status,
                          T3.FN_CFDI_REFOLEO( Acc.ReferenceDocNumber, 'DOI' ) AS CFDI_Refoleo
                          FROM EAI_Owner.tmp_Account_Header Acc
                          WHERE Acc.Created  > TRUNC( SYSDATE - pDiasIni )
                            AND Acc.Created  < TRUNC( SYSDATE - pDiasFin )
                          --AND Acc.Assignment IS NOT NULL
                            AND Acc.ClearingDocNumber NOT LIKE '11000%'
                            AND Acc.DocumentType != 'BK'
                 ) Info, T3.Registro_Fiscal RF              
            WHERE Info.ReferenceDocNumber != Info.CFDI_Refoleo     
              AND Info.CFDI_Refoleo        = RF.Factura(+) ;
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
      sReference := Doc.IdocNumber ;
      IF ( Doc.CustomerNumber = Doc.Cliente_SAP ) THEN
         nPedidos   := nPedidos + 1        ;   
         UPDATE EAI_Owner.tmp_Account_Header SET ReferenceDocNumber = Doc.CFDI_Refoleo
            WHERE IdocNumber = Doc.IdocNumber ;
         IF ( NVL( pClearStatus, 0 ) > 0 ) THEN   
            UPDATE EAI_Owner.tmp_Account_Header SET Processed = NULL,
                                                    Status    = NULL
               WHERE IdocNumber = Doc.IdocNumber ;
         END IF ;
         INSERT INTO T3.CFDI_REFOLEO_LOG 
            ( IDocNumber, Created, ReferenceDocNumber, NewReferenceDocNumber )
         VALUES
            ( Doc.IdocNumber, SYSDATE, Doc.ReferenceDocNumber, Doc.CFDI_Refoleo ) ;
      END IF ;   
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
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                 , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ACCNT_REFOLEO'   , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ACCNT_REFOLEO ;