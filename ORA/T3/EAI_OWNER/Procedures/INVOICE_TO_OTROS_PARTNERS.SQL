create or replace PROCEDURE           INVOICE_TO_OTROS_PARTNERS
   ( sInvoiceID   IN   VARCHAR2)
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   nItems          NUMBER(06)    ;
   nUpdated        NUMBER(06)    ;
--
   CURSOR ScrData IS
       SELECT PF.ReferenceID, PF.Sold_to_Customer, PF.Bill_to_Customer
       FROM EAI_owner.tmp_Document_Partners PF
       WHERE PF.ReferenceID = sInvoiceID ;
BEGIN
   v_ID      := sInvoiceID ;
   nItems    := 0 ;
   nUpdated  := 0 ;
   FOR Doc IN ScrData LOOP
      nItems := nItems + 1 ;
      IF ( ( Doc.Sold_to_Customer = 'PC-00-CR08' ) AND ( Doc.Bill_to_Customer = 'IC-00-CR10' ) ) THEN
         UPDATE EAI_owner.tmp_Document_Partners SET Sold_to_Name     = Bill_to_Name     ,
                                                    Sold_to_Address  = Bill_to_Address  ,
                                                    Sold_to_District = Bill_to_District ,
                                                    Sold_to_City     = Bill_to_City     ,
                                                    Sold_to_State    = Bill_to_State    ,
                                                    Sold_to_Country  = Bill_to_Country  ,
                                                    Sold_to_Zipcode  = Bill_to_ZipCode
          WHERE ReferenceID = Doc.ReferenceID ;                                          
      END IF ;
   END LOOP ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Sending to T3 V33', v_ID           , SYSDATE             , NULL           ,
          'Error'            , 'Invoice to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_TO_OTROS_PARTNERS ;