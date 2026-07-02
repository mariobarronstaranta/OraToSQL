create or replace PROCEDURE       "INSERT_EAI_MESSAGE_LOG" (
   v_DIRECTION             IN VARCHAR2, 
	 v_ID                    IN VARCHAR2, 
	 v_MESSAGE               IN LONG    , 
	 v_STATUS                IN VARCHAR2, 
	 v_QUEUE_NAME            IN VARCHAR2, 
	 v_SIEBEL_ERROR_MESSAGE  IN VARCHAR2, 
	 v_SOURCE                IN VARCHAR2, 
	 v_SIEBEL_ERROR_CODE     IN VARCHAR2, 
	 v_RETRY_COUNT           IN NUMBER  , 
	 v_SEQUENCE              IN NUMBER  , 
   v_PARENT_ROW_ID         IN VARCHAR2,
   v_REFERENCE             IN VARCHAR2
   )
IS
   sMsg       VARCHAR2(500) ;   
-- sXML       SYS.XMLTYPE   ;
BEGIN
--
-- v_Message
-- sXML := XMLTYPE( v_Message ) ;   
--   
-- sXML := XMLTYPE( v_Message, NULL, 0, TRUE, NULL ) ;   
--
   INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
     ( DIRECTION          , ID           , CREATED               , MESSAGE        ,
       REFERENCE          ,
	     STATUS             , QUEUE_NAME   , SIEBEL_ERROR_MESSAGE  , SOURCE         , 
	     SIEBEL_ERROR_CODE  , RETRY_COUNT  , SEQUENCE              , PARENT_ROW_ID   )
   VALUES 
     ( v_DIRECTION        , v_ID         , SYSDATE               , v_MESSAGE      ,
       v_REFERENCE        ,
       v_STATUS           , v_QUEUE_NAME , v_SIEBEL_ERROR_MESSAGE, v_SOURCE ,
       v_SIEBEL_ERROR_CODE, v_RETRY_COUNT, v_SEQUENCE            , v_PARENT_ROW_ID ) ;
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
        ( v_DIRECTION        , v_ID         , SYSDATE               , sMsg           ,
          v_REFERENCE        ,
          v_STATUS           , v_QUEUE_NAME , NULL                  , 'PL/SQL'       ,
          v_SIEBEL_ERROR_CODE, v_RETRY_COUNT, v_SEQUENCE            , v_PARENT_ROW_ID ) ;
      COMMIT ;
END Insert_EAI_Message_Log ;

 
 