create or replace PROCEDURE  "WA_TSEQ_HIST" 
   AS
--
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;    
   v_ID                  VARCHAR2(050) ;    
--
BEGIN
   v_ID := TO_CHAR( SYSDATE, 'YYYYMMDDHH24MISS' ) ;
   INSERT INTO EAI_Owner.Transaction_Sequence_Hist 
        ( Insert_Hist, ID, Name      , Resource_R      , Transaction_Type, 
          Sequence_Number, Rule_Rugex, LastModifiedDate, Extract_dt       )
   SELECT SYSDATE,     ID, Name      , Resource_R      , Transaction_Type, 
          Sequence_Number, Rule_Rugex, LastModifiedDate, Extract_dt
      FROM EAI_Owner.Transaction_Sequence
      WHERE Name != 'NAME' ;   
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE            , CREATED             , MESSAGE        ,
          STATUS              , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA Transaction Seq', v_ID                 , SYSDATE             , NULL           ,
          'Error'             , 'WA_TSEQ_HIST'       , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_TSEQ_HIST ;