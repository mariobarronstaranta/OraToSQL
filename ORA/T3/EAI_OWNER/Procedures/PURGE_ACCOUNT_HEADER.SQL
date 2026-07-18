create or replace PROCEDURE             "PURGE_ACCOUNT_HEADER" (
  dtStartingPurge       IN  DATE,
  dtEndingPurge         IN  DATE,
  nDiasIntervalo        IN  NUMBER )
IS
   dtStarting    DATE   ;
   dtEnding      DATE   ;
   nIteracion    NUMBER ;
   nPeriod       NUMBER ;
   nSequence     NUMBER ;
   nRecords      NUMBER(8) ;
   sPeriod       VARCHAR2(020) ;
   sStage        VARCHAR2(040) ;
   sMsg          VARCHAR2(500) ;
   sErrorCode    VARCHAR2(020) ; 
BEGIN
   nPeriod    := NVL( nDiasIntervalo, 007 ) ;
   nIteracion := 000 ;
   dtStarting := dtStartingPurge    - nPeriod  ;
   LOOP
      dtStarting := dtStarting + nPeriod  ;
      IF ( dtStarting > dtEndingPurge    ) THEN
         EXIT ;
      END IF ;
      dtEnding   := dtStarting + nPeriod  ;
      IF ( dtEnding   > dtEndingPurge    ) THEN
         dtEnding   := dtEndingPurge    ;
      END IF ;
      nIteracion := nIteracion + 1 ;
      dtStarting := TRUNC( dtStarting ) ;
      dtEnding   := TRUNC( dtEnding   ) ;
      sPeriod    :=  TO_CHAR( dtStarting, 'YYYYMMDD' ) || '-' ||
                     TO_CHAR( dtEnding  , 'YYYYMMDD' )   ;
   --
   -- DOCUMENT_HEADER
   --
      sStage := 'ACCOUNT_HEADER' ;
      SELECT Seq_Purge_LEGDB.NEXTVAL INTO nSequence   FROM  DUAL ;
      INSERT INTO EAI_OWNER.MX_PURGE_LEGDB_LOG
         ( PID, Time_Window, Process, Starting, Ending )
      VALUES
         ( nSequence , sPeriod , sStage , SYSDATE      , NULL        ) ;
      DELETE FROM EAI_OWNER.tmp_Account_Header
         WHERE Created IS NOT NULL
           AND TRUNC( Created ) BETWEEN dtStarting AND dtEnding  ;
      nRecords := SQL%ROWCOUNT ;
      UPDATE EAI_OWNER.MX_PURGE_LEGDB_LOG SET Ending = SYSDATE, Records = nRecords
         WHERE PID = nSequence  ;
	    COMMIT ;        
   END LOOP ;
   COMMIT ;

   --2) PURGE_LEGDB_OUTBOUND 19/marzo/2010

-- dbms_stats.gather_table_stats (ownname=>'EAI_OWNER',tabname=>'TMP_ACCOUNT_HEADER',method_opt=>'FOR ALL COLUMNS  SIZE AUTO',granularity=>'ALL',cascade=>TRUE,degree=>dbms_stats.default_degree);


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
          'Error'            , 'Account_Header'  , sMsg                , 'Purge'        ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;    
END ;