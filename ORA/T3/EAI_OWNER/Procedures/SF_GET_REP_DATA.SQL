create or replace PROCEDURE           SF_GET_REP_DATA
   ( pInvoiceRef   IN   VARCHAR2,
     pCustomerRef  IN   VARCHAR2,
     rtRepName     OUT  VARCHAR2,
     rtRFC         OUT  VARCHAR2,
     rtLicencia    OUT  VARCHAR2,
     rtPlacas      OUT  VARCHAR2,
     rtModelo      OUT  VARCHAR2,
     rtPesoMax     OUT  NUMBER )
IS
   sInvoiceRef         VARCHAR2(500) ;
   sMsg                VARCHAR2(500) ;
   sErrorCode          VARCHAR2(500) ;
   v_ID                VARCHAR2(030) ;
   sDoc_Num            VARCHAR2(050) ;
   sCliente_SAP        VARCHAR2(050) ;
   sRow_ID             VARCHAR2(050) ;
   sDocType            VARCHAR2(030) ;
   sStatus_CD          VARCHAR2(030) ;
   dtFecha_Proc_BATMD  DATE          ;
   dtFechaCancelacion  DATE          ;
   sRepName            VARCHAR2(060) ;
--
   CURSOR ScrPromptSales IS
       SELECT Van.Name, 
          --  Van.Resource_Name, 
              NVL( Rep.Nombre, Van.Resource_Name )                 AS Resource_Name,
              Rep.RFC                                              AS RFC          ,
              NVL( Rep.Licencia, '12345678' )                      AS Licencia     ,
              REPLACE( NVL( Rep.Placas  , 'PLACAS'   ), '-', '' )  AS Placas       ,
              NVL( Rep.Modelo  , '2020'     )                      AS Modelo       ,
              NVL( Rep.Peso_Maximo_Nom, 3000 )                     AS Peso_Maximo
          FROM EAI_Owner.VANS_VIGENTES Van,
               EAI_Owner.Cat_Reps      Rep
          WHERE Van.NAME LIKE 'VAN%'
            AND VAN.Stock_Partner_Resource = Rep.Cliente_SAP
            AND Van.NAME LIKE '%' || sDoc_Num ;
BEGIN
   v_ID         := pInvoiceRef ;
   sInvoiceRef  := pInvoiceRef ;
   IF ( SUBSTR( sInvoiceRef, 6, 1 ) = '-' ) THEN
      sDocType  := 'Prompt'    ;
      sDoc_Num  := SUBSTR( sInvoiceRef, 2, 4 ) ;
   ELSE
      sDocType  := 'Pre'       ;
   END IF ;
   
   sCliente_SAP := NULL        ;
   sRow_ID      := NULL        ;
   sStatus_CD   := NULL        ;
   rtRepName    := ''          ;
   rtRFC        := ''          ;
   rtLicencia   := ''          ;
   rtPlacas     := ''          ;
   rtModelo     := ''          ;
   rtPesoMax    := 00          ;
--
   IF ( sDocType = 'Prompt' ) THEN
      FOR Doc IN ScrPromptSales LOOP
         rtRepName     := Doc.Resource_Name ;
         rtRFC         := Doc.RFC           ;
         rtLicencia    := Doc.Licencia      ;
         rtPlacas      := Doc.Placas        ;
         rtModelo      := Doc.Modelo        ;
         rtPesoMax     := Doc.Peso_Maximo   ;
      END LOOP ;
   END IF ;
--   DBMS_Output.Put_Line( 'Type : ' || sDocType ) ;
--   DBMS_Output.Put_Line( 'Terr : ' || sDoc_Num ) ;
EXCEPTION
   WHEN OTHERS THEN
      sRepName    := NULL ;
      sErrorCode  := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE         , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME        , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT       , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Getting Info'     , v_ID              , SYSDATE             , NULL           ,
          'Error'            , 'GET_REP_DATA'    , sMsg                , 'XML'          ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;
END SF_GET_REP_DATA ;