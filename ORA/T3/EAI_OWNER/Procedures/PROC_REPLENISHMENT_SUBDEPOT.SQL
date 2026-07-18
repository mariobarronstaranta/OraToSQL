create or replace PROCEDURE           PROC_REPLENISHMENT_SUBDEPOT
   ( sReferenceID   IN   VARCHAR2 )
IS
   sMsg              VARCHAR2(500) ;   
   v_ID              VARCHAR2(050) ;
   sErrorCode        VARCHAR2(020) ;
--   
   CURSOR ScrEnablePrint IS
       SELECT MAX( Info.Cust_to_SAP ) AS Cust_to_SAP
          FROM (
                 SELECT Head.PedidoV3                  AS Ubicacion  ,
                        SUBSTR( Head.PedidoV3, 15, 4 ) AS Territorio ,
                        Head.Cust_to_SAP               AS Cust_to_SAP
                    FROM EAI_Owner.Tmp_Document_Header  Head
                    WHERE Head.ReferenceID = sReferenceID 
                      AND DeliveryType     = 'Receive Other'
                ) Info, EAI_Owner.MX_PRINT_DELIVERY Send
          WHERE Info.Cust_to_SAP = Send.Cust_to_SAP ;
BEGIN
   FOR Doc IN ScrEnablePrint LOOP
      IF ( Doc.Cust_to_SAP IS NOT NULL ) THEN
         T3.DELIVERY_TO_SUBDEPOT( sReferenceID, 0 ) ;
      END IF ;   
--    EAI_OWNER.PROC_REPLENISHMENT_FILLRATE( sReferenceID ) ;
   END LOOP ;       
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE                    , CREATED             , MESSAGE        ,
          STATUS              , QUEUE_NAME                   , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT                  , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Stamp CFD Subdepot', sReferenceID                 , SYSDATE             , NULL           ,
          'Error'             , 'PROC_REPLENISHMENT_SUBDEPOT', sMsg                , 'XML'          ,
          sErrorCode          , NULL                         , NULL                , NULL            ) ;
      COMMIT ;
END PROC_REPLENISHMENT_SUBDEPOT ;