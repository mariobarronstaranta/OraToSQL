create or replace PROCEDURE       "INSERT_RECEIVE_MESSAGE" (
	 v_MESSAGE               IN LONG    , 
	 v_QUEUE_NAME            IN VARCHAR2 
   )
IS
   sMsg                   VARCHAR2(500) ;   
   sRow_ID                VARCHAR2(032) ;
   sXML                   SYS.XMLTYPE   ;
   sQueueNameReplicate    VARCHAR2(500) ;
BEGIN
--
-- 
   sXML := XMLTYPE( v_Message ) ;   
   sQueueNameReplicate := v_QUEUE_NAME ;
   IF   ( sQueueNameReplicate = 'Customer ERP No' ) THEN
      sQueueNameReplicate := 'Customer ERP No for T3' ;
   ELSIF ( sQueueNameReplicate = 'Product Master' ) THEN
      sQueueNameReplicate := 'Product Master for T3' ;
   END IF ;
--   
-- sXML := XMLTYPE( v_Message, NULL, 0, TRUE, NULL ) ;   
--
   sRow_ID := TO_CHAR( SYSTIMESTAMP, 'YYYYMMDDHH24MISSFFFF' ) ;
   INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
     ( ROW_ID  , CREATED, XML_CONTENT, QUEUE_NAME, STATUS )
   VALUES 
     ( sRow_ID , SYSDATE, sXML, v_QUEUE_NAME, 'Received' ) ;
   IF ( sQueueNameReplicate != v_QUEUE_NAME ) THEN
        sRow_ID := TO_CHAR( SYSTIMESTAMP, 'YYYYMMDDHH24MISSFFFF' ) ;
        INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
          ( ROW_ID  , CREATED, XML_CONTENT, QUEUE_NAME, STATUS )
        VALUES 
          ( sRow_ID , SYSDATE, sXML, sQueueNameReplicate, 'Received' ) ;
   END IF ;
   COMMIT ;   
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID           , CREATED               , MESSAGE        ,
          REFERENCE          ,
	        STATUS             , QUEUE_NAME   , SIEBEL_ERROR_MESSAGE  , SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT  , SEQUENCE              , PARENT_ROW_ID   )
      VALUES 
        ( 'Receive'          , NULL         , SYSDATE               , v_Message      ,
          NULL               ,
          'Error'            , v_QUEUE_NAME , sMsg                  , 'PL/SQL'       ,
          NULL               , NULL         , NULL                 , NULL             ) ;
      COMMIT ;
END INSERT_RECEIVE_MESSAGE ;
 