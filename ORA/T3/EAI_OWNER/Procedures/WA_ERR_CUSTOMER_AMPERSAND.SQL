create or replace PROCEDURE             "WA_ERR_CUSTOMER_AMPERSAND" 
   ( pDias           IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrCustomers IS
      SELECT Err.Status, Err.RowID AS Log_Row_ID, Err.Created, Err.Message, Err.Queue_Name,
             XMLTYPE(
                  TO_CLOB(  REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,     1 ), '&', '-amp-' ) ) ) AS XML_Content
         FROM EAI_Owner.MX_EAI_Message_Log Err
         WHERE Err.Created     > TRUNC( SYSDATE - pDias )
           AND Err.Queue_Name  = 'Customer' 
           AND Err.Status      = 'Error'    ;
   nCustomers            NUMBER(04)    ;
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;    
   v_ID                  VARCHAR2(050) ;      
--
BEGIN
   nCustomers := 0 ;
   FOR Cust IN ScrCustomers LOOP
         v_ID := Cust.Log_Row_ID ;
         INSERT INTO EAI_Owner.MX_Receive_Message_Log
            ( Row_ID, Created, Queue_Name, XML_Content )
         VALUES
            ( Cust.Log_Row_ID, SYSDATE, Cust.Queue_Name, Cust.XML_Content ) ;
         UPDATE EAI_Owner.MX_EAI_Message_Log SET Status = 'Reprocess'
            WHERE ROWID = Cust.Log_Row_ID ;  
         nCustomers := nCustomers + 1 ;   
   END LOOP ;
   DBMS_Output.Put_Line( 'Customers -> ' || nCustomers ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA Customer '     , v_ID                 , SYSDATE             , NULL           ,
          'Error'            , 'WA_ERR_CUSTOMER'    , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_CUSTOMER_AMPERSAND ;