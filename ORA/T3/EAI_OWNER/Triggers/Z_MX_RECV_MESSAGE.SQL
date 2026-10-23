create or replace TRIGGER "EAI_OWNER"."Z_MX_RECV_MESSAGE" 
BEFORE INSERT ON MX_RECEIVE_MESSAGE_LOG
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW



DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION ;
--  
   sMsg                VARCHAR2(500) ; 
   sErrorCode          VARCHAR2(020) ;  
   sDOCNUM             VARCHAR2(020) ;
   bInsertStage        BOOLEAN       ;   
   nCount              NUMBER(3)     ;
   v_Message           CLOB          ;
BEGIN
   SELECT extractValue( :NEW.XML_Content, '*/Header/Reference/ReferenceID' )  INTO sDOCNUM
      FROM DUAL ;
   :NEW.DOCNUM := sDOCNUM ;   
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID           , CREATED             , MESSAGE        ,
          REFERENCE          ,
	        STATUS             , QUEUE_NAME   , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT  , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Receive'          , :NEW.ROW_ID  , SYSDATE             , NULL           ,
          :NEW.DOCNUM        ,
          'Error'            , 'Message'    , sMsg                , 'Trigger'      ,
          sErrorCode         , NULL         , NULL                , NULL            ) ;
      COMMIT ;    
END ;
