create or replace PROCEDURE EXECUTE_TRUNCATE
   ( pTableName IN   VARCHAR2 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(050) ;
   sOwner          VARCHAR2(050) ;
   sDoIt           VARCHAR2(005) ;
   sDot            NUMBER(03)    ;
--
   CURSOR ScrEnabled IS
      SELECT Table_Name 
         FROM EAI_Owner.EAI_TRUNC_TABLE
         WHERE UPPER( Table_Name ) = UPPER( v_ID ) ;
BEGIN
   sDoIt  := 'NO'                ;
   v_ID   := UPPER( pTableName ) ;
   sDot   := INSTR( v_ID, '.' )  ;
   sOwner := SUBSTR( v_ID, 1, sDot - 1 ) ;
   FOR Tab IN ScrEnabled LOOP
      sDoIt := 'YES' ;
   END LOOP ;
   IF ( sDoIt = 'YES' ) THEN
      EXECUTE IMMEDIATE ( 'TRUNCATE TABLE ' || v_ID ) ;
      INSERT INTO EAI_OWNER.EAI_TRUNC_LOG 
         ( TABLE_NAME, EXECUTED, USER_SCHEMA, USER_ID, IP_ADDRESS, TERMINAL )
      VALUES
         ( v_ID, SYSDATE, USER    , SYS_CONTEXT( 'USERENV' , 'OS_USER'    )
                                  , SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' )
                                  , SYS_CONTEXT( 'USERENV' , 'HOST'       ) ) ;
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE         , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME        , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT       , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'TRUNCATE'         , v_ID              , SYSDATE             , NULL           ,
          'Error'            , 'EXECUTE_TRUNCATE', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;
END EXECUTE_TRUNCATE ;
 