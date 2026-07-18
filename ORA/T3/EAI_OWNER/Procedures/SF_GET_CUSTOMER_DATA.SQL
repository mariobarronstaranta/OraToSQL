create or replace PROCEDURE           SF_GET_CUSTOMER_DATA
   ( pCustomer_SAP   IN   VARCHAR2,
     pDate           IN   DATE    ,
     rtCustomer_TMD  OUT  VARCHAR2,
     rtCtro          OUT  VARCHAR2,
     rtDistributor   OUT  NUMBER  ,
     rtRep_ID        OUT  VARCHAR2, 
     rtCustomer_Name OUT  VARCHAR2 )
IS
   sCustomerRef        VARCHAR2(500) ;
   dtDateRef           DATE          ;
   sMsg                VARCHAR2(500) ;
   sErrorCode          VARCHAR2(500) ;
   v_ID                VARCHAR2(015) ;
   sCustomer_TMD       VARCHAR2(020) ;
   sCtro               VARCHAR2(020) ;
   nDistributor        NUMBER(04)    ;
   sRep_ID             VARCHAR2(020) ;
   sDoc_Type           VARCHAR2(020) ;
   sCustomer_Name      VARCHAR2(1024) ;
--
   CURSOR ScrHistory IS
      SELECT  Cliente_V3                      AS Customer_TMD,
              Ctro                            AS Ctro        ,
              EAI.CONV_PLANT_TO_DIST( Ctro )  AS Distributor ,
              'CENTRAL'                       AS Rep_ID      ,
              Nombre                          AS Nombre
         FROM T3.Cliente 
         WHERE Cliente_SAP = pCustomer_SAP
           AND dtDateRef   BETWEEN fecha_Ini_Vig AND Fecha_Fin_Vig ;
--
   CURSOR ScrLastView IS
      SELECT  Cliente_V3                      AS Customer_TMD,
              Ctro                            AS Ctro        ,
              EAI.CONV_PLANT_TO_DIST( Ctro )  AS Distributor ,
              'CENTRAL'                       AS Rep_ID      ,
              Nombre                          AS Nombre
         FROM T3.Mov_Cliente 
         WHERE Cliente_SAP = pCustomer_SAP ;
BEGIN
   v_ID           := pCustomer_SAP ;
   dtDateRef      := NVL( pDate, TRUNC( SYSDATE ) ) ;
   sCustomer_TMD  := ''            ;
   sCtro          := ''            ;
   nDistributor   := 00            ;
   sRep_ID        := ''            ;
   sDoc_Type      := 'None'        ;
   sCustomer_Name := ''            ;
--
   FOR Doc IN ScrHistory LOOP
      sCustomer_TMD  := Doc.Customer_TMD ;
      sCtro          := Doc.Ctro         ;
      nDistributor   := Doc.Distributor  ;
      sRep_ID        := Doc.Rep_ID       ;
      sDoc_Type      := 'History'        ;
      sCustomer_Name := Doc.Nombre       ;
   END LOOP ;
   IF ( sDoc_Type = 'None' ) THEN
      FOR Doc IN ScrLastView LOOP
         sCustomer_TMD  := Doc.Customer_TMD ;
         sCtro          := Doc.Ctro         ;
         nDistributor   := Doc.Distributor  ;
         sRep_ID        := Doc.Rep_ID       ;
         sDoc_Type      := 'History'        ;
         sCustomer_Name := Doc.Nombre       ;
      END LOOP ;
   END IF ;
   rtCustomer_TMD  := sCustomer_TMD  ;
   rtCtro          := sCtro          ;
   rtDistributor   := nDistributor   ;
   rtRep_ID        := sRep_ID        ;
   rtCustomer_Name := sCustomer_Name ;
EXCEPTION
   WHEN OTHERS THEN
      rtCustomer_TMD := '' ;
      rtCtro         := '' ;
      rtDistributor  := 00 ;
      rtRep_ID       := '' ;
      sErrorCode  := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE          , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Getting Info'     , v_ID               , SYSDATE             , NULL           ,
          'Error'            , 'GET_CUSTOMER_DATA', sMsg                , 'XML'          ,
          sErrorCode         , NULL               , NULL                , NULL            ) ;
      COMMIT ;
END SF_GET_CUSTOMER_DATA ;