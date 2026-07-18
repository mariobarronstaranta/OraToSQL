create or replace PROCEDURE      "PURGE_TEMPORAL_SAP" (
  sPeriod               IN  VARCHAR2,
  sTableName            IN  VARCHAR2 )
IS

   dtFechaIni    DATE   ;
   dtFechaFin    DATE   ;
   nIteracion    NUMBER ;
   nPeriodo      NUMBER ;
   nSecuencia    NUMBER ;
   sPeriodo      VARCHAR2(020) ;
   sEtapa        VARCHAR2(040) ;
   sMsg          VARCHAR2(500) ;
   sErrorCode    VARCHAR2(020) ;    
--
   CURSOR ScrAccount IS
      SELECT Doc.RowID AS Doc_ROWID, Doc.IDocNumber
      FROM EAI_OWNER.TMP_ACCOUNT_HEADER     Doc      
      WHERE TO_CHAR( Doc.Created, 'YYYYMM' ) = sPeriod ;
--
   CURSOR ScrDoctos IS
      SELECT Doc.RowID AS Doc_ROWID, Doc.ReferenceID
      FROM EAI_OWNER.TMP_DOCUMENT_HEADER     Doc      
      WHERE TO_CHAR( Doc.Created, 'YYYYMM' ) = sPeriod ;
--
   CURSOR ScrDoctosNull IS
      SELECT Doc.RowID AS Doc_ROWID, Doc.ReferenceID
      FROM EAI_OWNER.TMP_DOCUMENT_HEADER     Doc      
      WHERE Doc.Created IS NULL
        AND Doc.DeliveryType IS NULL ;
      --AND Doc.DeliveryType  = sPeriod ;
BEGIN
   nIteracion := 000 ;
   DBMS_Output.Put_Line( 'Start ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
   --
   IF ( UPPER( sTableName ) = 'ACCOUNTING' ) THEN 
      sEtapa := 'TMP_ACCOUNT_HEADER' ;
      FOR Doc IN ScrAccount LOOP
         nIteracion := nIteracion + 1 ;
         DELETE FROM EAI_OWNER.TMP_ACCOUNT_HEADER
           WHERE ROWID = Doc.Doc_ROWID ;
         IF ( MOD( nIteracion, 20000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      DBMS_Output.Put_Line( 'Records' || TO_CHAR( nIteracion, '999,999,999' ) ) ;
      DBMS_Output.Put_Line( 'End ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
      COMMIT ;
   ELSIF ( UPPER( sTableName ) = 'DOCUMENT' ) THEN 
      sEtapa := 'TMP_DOCUMENT_HEADER' ;
      FOR Doc IN ScrDoctos LOOP
         nIteracion := nIteracion + 1 ;
         --DELETE FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS
         --   WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND
            WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL
            WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS
            WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_HEADER
           WHERE ROWID = Doc.Doc_ROWID ;
         IF ( MOD( nIteracion, 10000 ) = 0 ) THEN
            COMMIT ;
            --DBMS_Output.Put_Line( nIteracion || '=>' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
         END IF ;
      END LOOP ;
      DBMS_Output.Put_Line( 'Records' || TO_CHAR( nIteracion, '999,999,999' ) ) ;
      DBMS_Output.Put_Line( 'End ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
      COMMIT ;
   ELSIF ( UPPER( sTableName ) = 'DOCUMENT-NULL' ) THEN 
      sEtapa := 'TMP_DOCUMENT_HEADER' ;
      FOR Doc IN ScrDoctosNull LOOP
         nIteracion := nIteracion + 1 ;
         --DELETE FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS
         --   WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND
            WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL
            WHERE ReferenceID = Doc.ReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_HEADER
           WHERE ROWID = Doc.Doc_ROWID ;
         IF ( MOD( nIteracion, 20000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      DBMS_Output.Put_Line( 'Records' || TO_CHAR( nIteracion, '999,999,999' ) ) ;
      DBMS_Output.Put_Line( 'End ' || TO_CHAR( SYSDATE, 'HH24:MI:SS' ) ) ;
      COMMIT ;
   END IF ;   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME        , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT       , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Purge'            , NULL              , SYSDATE             , NULL           ,
          'Error'            , sEtapa            , sMsg                , 'Purge'        ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;    
END ;