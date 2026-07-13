create or replace PROCEDURE             "PURGE_COMPONENT_LOG" 
( sStatus      IN  VARCHAR2,
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
   nDays         NUMBER(3)     ;
BEGIN
   dtStarting := SYSDATE ;
   sStage     := 'MX_COMPONENT_LOG' ;
   nDays      := TRUNC( dtEnd ) - TRUNC( dtBegin ) ;
   IF ( nDays >= 2 ) THEN
      sPeriod := TO_CHAR( dtBegin, 'DD.MM' ) || ' to ' ;
      sPeriod := sPeriod || TO_CHAR( dtEnd, 'DD.MM' ) ;
   ELSE
      sPeriod := TO_CHAR( dtBegin, 'HH24:MI' ) || ' - ' ;
      sPeriod := sPeriod || TO_CHAR( dtEnd, 'HH24:MI' ) ;
   END IF ;  
  
   IF ( sStatus = 'All' ) THEN
      DELETE FROM EAI_OWNER.MX_Component_Log
         WHERE Starting BETWEEN dtBegin AND dtEnd   ;
      sPeriod := 'Purge : [ ' || sPeriod || ' ]' ;
   ELSE
      DELETE FROM EAI_OWNER.MX_Component_Log
         WHERE Starting BETWEEN dtBegin AND dtEnd
           AND Processed = 0 ;
      sPeriod := 'None Processed : [ ' || sPeriod || ' ]' ;      
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
END PURGE_COMPONENT_LOG;

 
 