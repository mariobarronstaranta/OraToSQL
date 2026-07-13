create or replace PROCEDURE           "PURGE_RECEIVE_LOG" (
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
   -- LEGDB_ACCOUNT_CREATE
   --
      sStage := 'MX_RECEIVE_MESSAGE_LOG' ;
      SELECT Seq_Purge_LEGDB.NEXTVAL INTO nSequence   FROM  DUAL ;
      INSERT INTO EAI_OWNER.MX_PURGE_LEGDB_LOG
         ( PID, Time_Window, Process, Starting, Ending )
      VALUES
         ( nSequence , sPeriod , sStage , SYSDATE      , NULL        ) ;
      DELETE FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE TRUNC( Created ) BETWEEN dtStarting AND dtEnding ;
      nRecords := SQL%ROWCOUNT ;
      UPDATE EAI_OWNER.MX_PURGE_LEGDB_LOG SET Ending = SYSDATE, Records = nRecords
         WHERE PID = nSequence  ;
	    COMMIT ;
   END LOOP ;
   COMMIT ;

   dbms_stats.gather_table_stats (ownname=>'EAI_OWNER',tabname=>'MX_RECEIVE_MESSAGE_LOG',method_opt=>'FOR ALL COLUMNS  SIZE AUTO',granularity=>'ALL',cascade=>TRUE,degree=>dbms_stats.default_degree);
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
          'Error'            , sStage            , sMsg                , 'Purge'        ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;    
END ;