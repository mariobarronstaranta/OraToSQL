create or replace PROCEDURE             "PURGE_MESSAGE_LOG" 
( sDirection   IN  VARCHAR2,
  sStatus      IN  VARCHAR2,
  dtBegin      IN  DATE    ,
  dtEnd        IN  DATE    , 
  sLogging     IN  VARCHAR2 ) 
IS
   sMsg          VARCHAR2(500) ;
   sErrorCode    VARCHAR2(020) ; 
   sStage        VARCHAR2(040) ;
   sPeriod       VARCHAR2(040) ;   
   nSequence     NUMBER(8)     ;
   nRecords      NUMBER(8)     ;
   dtStarting    DATE          ;
   nDays         NUMBER(5)     ;
BEGIN
   dtStarting := SYSDATE ;
   sStage     := 'MX_EAI_MESSAGE_LOG' ;
   nDays      := TRUNC( dtEnd ) - TRUNC( dtBegin ) ;
   IF ( nDays >= 1 ) THEN
      sPeriod := TO_CHAR( dtBegin, 'DD.MM' ) || ' to ' ;
      sPeriod := sPeriod || TO_CHAR( dtEnd, 'DD.MM' ) ;
   ELSE
      sPeriod := TO_CHAR( dtBegin, 'HH24:MI' ) || ' - ' ;
      sPeriod := sPeriod || TO_CHAR( dtEnd, 'HH24:MI' ) ;
   END IF ;  
  
   IF ( sDirection = 'Both' ) THEN
      IF ( sStatus = 'Both' ) THEN
         DELETE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE TRUNC( Created ) BETWEEN dtBegin AND dtEnd   ;
         sPeriod := 'Purge : [ ' || sPeriod || ' ]' ;
      ELSE
         DELETE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE TRUNC( Created ) BETWEEN dtBegin AND dtEnd
              AND Status = sStatus ;
         sPeriod := sStatus || ' : [ ' || sPeriod || ' ]' ;      
      END IF ;
   ELSE
      IF ( sStatus = 'Both' ) THEN
         DELETE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE TRUNC( Created ) BETWEEN dtBegin AND dtEnd   
              AND Direction = sDirection ;
         sPeriod := sDirection || ' : [ ' || sPeriod || ' ]' ;              
      ELSE
         DELETE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE TRUNC( Created ) BETWEEN dtBegin AND dtEnd
              AND Direction = sDirection 
              AND Status    = sStatus ;
         sPeriod := sDirection || '/'  || sStatus ||
                    ' : [ ' || sPeriod || ' ]' ;              
      END IF ;
   END IF ;
   nRecords := SQL%ROWCOUNT ;
--
   IF ( sLogging = 'Yes' ) THEN
      SELECT Seq_Purge_LEGDB.NEXTVAL INTO nSequence   FROM  DUAL ;
      INSERT INTO EAI_OWNER.MX_PURGE_LEGDB_LOG
         ( PID, Time_Window, Process, Starting, Ending, Records )
      VALUES
         ( nSequence, sStage, sPeriod, dtStarting, SYSDATE, nRecords ) ;
   END IF ;         
   COMMIT ;

   --1) PURGE_MESSAGE_LOG 19/Marzo/2010
   dbms_stats.gather_table_stats (ownname=>'EAI_OWNER',tabname=>'MX_EAI_MESSAGE_LOG',method_opt=>'FOR ALL COLUMNS  SIZE AUTO',granularity=>'ALL',cascade=>TRUE,degree=>dbms_stats.default_degree);   


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
  
END PURGE_MESSAGE_LOG;