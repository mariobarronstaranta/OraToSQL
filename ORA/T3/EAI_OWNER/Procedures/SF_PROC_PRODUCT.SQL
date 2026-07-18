create or replace PROCEDURE           SF_PROC_PRODUCT( sROW_ID VARCHAR2, nROWNUM NUMBER, nOutput NUMBER ) IS
   v_ID                         VARCHAR2(030) ;
   sErrorCode                   VARCHAR2(500) ;
   sMsg                         VARCHAR2(500) ;
   sProcesar                    VARCHAR2(020) ;
   sMaterialNumber              VARCHAR2(050) ;
   sDescription                 VARCHAR2(050) ;
   sPricingGroup                VARCHAR2(050) ;
   sStartDate                   VARCHAR2(050) ;
   sEndDate                     VARCHAR2(050) ;
   sEAN                         VARCHAR2(050) ;
   sBaseUnitMeasure             VARCHAR2(050) ;
   sProductType                 VARCHAR2(050) ;
   sSalesUnitPerPack            VARCHAR2(050) ;
   sProductLine                 VARCHAR2(050) ;
   sFlag                        VARCHAR2(050) ;
   sLineProduct                 VARCHAR2(050) ;
   sDefaultProduct              VARCHAR2(050) ;
   sCigarreteSize               VARCHAR2(050) ;
   sFilterType                  VARCHAR2(050) ;
   sFlavourType                 VARCHAR2(050) ;
   sPackType                    VARCHAR2(050) ;
   sManufacture                 VARCHAR2(050) ;
   sBlendingTobacco             VARCHAR2(050) ;
   sUMV                         VARCHAR2(050) ;
   sPrueba                      VARCHAR2(009) ;
   sStage                       VARCHAR2(050) ; 
   sParentInternalProductName   VARCHAR2(050) ;
   sBATParentBrandName          VARCHAR2(050) ;
   sBATType                     VARCHAR2(050) ;
   sBATClass                    VARCHAR2(050) ;
   sSalesProductFlag            VARCHAR2(050) ;
--   
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/Product/Message/GeneralData/MaterialNumber')           AS MaterialNumber  ,
            extractValue( XML_Content, '/Product/Message/GeneralData/Description')              AS Description     ,
--
            extractValue( XML_Content, '/Product/Message/OrganizationData/PricingGroup')        AS PricingGroup    ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/StartDate')           AS StartDate       ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/EndDate')             AS EndDate         ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/EAN')                 AS EAN             ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/BaseUnitMeasure')     AS BaseUnitMeasure ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/ProductType')         AS ProductType     ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/SalesUnitPerPack')    AS SalesUnitPerPack,
            extractValue( XML_Content, '/Product/Message/OrganizationData/ProductLine')         AS ProductLine     ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/Flag')                AS Flag            ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/LineProduct')         AS LineProduct     ,
            extractValue( XML_Content, '/Product/Message/OrganizationData/DefaultProduct')      AS DefaultProduct  ,
--
            extractValue( XML_Content, '/Product/Message/CharacteristicData/CigarreteSize')     AS CigarreteSize   ,
            extractValue( XML_Content, '/Product/Message/CharacteristicData/FilterType')        AS FilterType      ,
            extractValue( XML_Content, '/Product/Message/CharacteristicData/FlavourType')       AS FlavourType     ,
            extractValue( XML_Content, '/Product/Message/CharacteristicData/PackType')          AS PackType        ,
            extractValue( XML_Content, '/Product/Message/CharacteristicData/Manufacture')       AS Manufacture     ,
            extractValue( XML_Content, '/Product/Message/CharacteristicData/BlendingTobacco')   AS BlendingTobacco
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;    
BEGIN
   sPrueba := 'T' || nROWNUM || ' '  ;
   sPrueba := '' ;
   sStage  := 'Inicio' ;
   FOR Rec IN ScrData LOOP 
      v_ID := Rec.MaterialNumber ;
      sProcesar := 'SI'          ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
      END IF ;
      sMaterialNumber   := TRIM( TO_CHAR( TO_NUMBER( Rec.MaterialNumber ) ) ) ;
--    sMaterialNumber   := TRIM( Rec.MaterialNumber )  ;
      sMaterialNumber   := SUBSTR( sPrueba, 2, 1 ) 
                                   || sMaterialNumber      ;
      sDescription      := sPrueba || Rec.Description      ;
      sStage            := 'Cursor'             ;
      sPricingGroup     := Rec.PricingGroup     ;
      sStartDate        := Rec.StartDate        ;
      sEndDate          := Rec.EndDate          ;
      sEAN              := Rec.EAN              ;
      sBaseUnitMeasure  := Rec.BaseUnitMeasure  ;
      sProductType      := Rec.ProductType      ;
      sSalesUnitPerPack := Rec.SalesUnitPerPack ;
      sProductLine      := Rec.ProductLine      ;
      sFlag             := Rec.Flag             ;
      sLineProduct      := Rec.LineProduct      ;
      sDefaultProduct   := Rec.DefaultProduct   ;
      sCigarreteSize    := Rec.CigarreteSize    ;
      sFilterType       := Rec.FilterType       ;
      sFlavourType      := Rec.FlavourType      ;
      sPackType         := Rec.PackType         ;
      sManufacture      := Rec.Manufacture      ;
      sBlendingTobacco  := Rec.BlendingTobacco  ;
      IF ( sSalesUnitPerPack = 'Infinity' ) THEN
         sSalesUnitPerPack := '0' ;
      END IF ;
   -- Patch For Merchandise Materials
   -- Defect ID : 75605
      IF ( (sPricingGroup is null) or (sPricingGroup = '') ) THEN
         sPricingGroup := '03' ; 
      END IF ;
   -- End of Defect ID : 75605 patch

      sStage            := 'HashTable'          ;
      SELECT
             EAI_Owner.getConv( 'ECC_V3 SKU Filter Type'    , sFilterType      )  AS FilterType      ,
             EAI_Owner.getConv( 'ECC_V3 SKU Price Group'    , sPricingGroup    )  AS PricingGroup    ,
             EAI_Owner.getConv( 'ECC_V3 SKU Pack Type'      , sPackType        )  AS PackType        ,
             EAI_Owner.getConv( 'ECC_V3 SKU Cigarrete Size' , sCigarreteSize   )  AS CigarreteSize   ,
             EAI_Owner.getConv( 'ECC_V3 SKU Blend'          , sBlendingTobacco )  AS BlendingTobacco ,
             EAI_Owner.getConv( 'ECC_V3 SKU Flavour'        , sFlavourType     )  AS FlavourType
             INTO sFilterType     , sPricingGroup, sPackType, sCigarreteSize,
                  sBlendingTobacco, sFlavourType
         FROM DUAL ;
      IF ( ( LENGTH( NVL( sStartDate, '' ) ) = 0 ) OR ( sStartDate IS NULL ) ) THEN
         sStartDate := TO_CHAR( SYSDATE, 'MM/DD/YYYY' ) ;
      END IF ;
      IF ( ( LENGTH( NVL( sEndDate, '' ) ) = 0 ) OR ( sEndDate IS NULL ) ) THEN
         sEndDate := '12/31/4000' ;
      END IF ;
      IF ( sLineProduct IS NULL ) THEN
         IF ( TO_NUMBER( NVL( sSalesUnitPerPack, '0' ) ) <= 25 ) THEN
            sUMV := 'CAJ' ;
         ELSE
            sUMV         := 'PAQ' ;
            sLineProduct := '1'   ;
         END IF ;
      ELSIF ( sLineProduct = '1' ) THEN
         sUMV := 'PAQ' ;
      ELSIF ( sLineProduct = '2' ) THEN
        sUMV         := 'CAJ' ;
        sLineProduct := ''    ;
      END IF ;
      IF ( LENGTH( TRIM( NVL( sProductLine, '' ) ) ) = 0 ) THEN
         sProductLine := 'Cigarrillos' ;
      ELSIF ( sProductLine IS NULL ) THEN
         sProductLine := 'Cigarrillos' ;
      END IF ;
      IF ( UPPER( sProductType ) = 'MERCHANDISE' ) THEN
         sProductLine               := 'Cigarrillos'     ;
         sProductType               := 'Merchandise'     ;
         sDefaultProduct            := 'Brand Family'    ;
         sBATParentBrandName        := 'Brand Family'    ;
         sBATParentBrandName        := 'DEFAULT FAMILY'  ;      
         sParentInternalProductName := ''                ;      
         sBATType                   := 'Interior'        ;
         sBATClass                  := 'Permanente'      ;
--
         sPricingGroup              := ''    ;
         sBaseUnitMeasure           := ''    ;
         sCigarreteSize             := ''    ;
         sFilterType                := ''    ;
         sFlavourType               := ''    ;
         sPackType                  := ''    ;
         sBlendingTobacco           := ''    ;
         sSalesProductFlag          := ''    ;
      ELSE
         sBATParentBrandName        := 'DEFAULT PRODUCT' ;      
         sParentInternalProductName := 'DEFAULT PRODUCT' ;
         sBATClass                  := ''                ;
         sBATType                   := ''                ;
         sSalesProductFlag          := 'Y'               ;
      END IF ;
      IF ( sCigarreteSize = '99' ) THEN
         sCigarreteSize := '' ;
      END IF ;
      IF ( sFilterType = '99' ) THEN
         sFilterType := '' ;
      END IF ;
      IF ( sFlavourType = '99' ) THEN
         sFlavourType := '' ;
      END IF ;
      IF ( sPackType = '99' ) THEN
         sPackType := '' ;
      END IF ;
      IF ( sBlendingTobacco = '99' ) THEN
         sBlendingTobacco := '' ;
      END IF ;
      IF ( nOutput > 0 ) THEN
         DBMS_Output.Put_Line( 'MaterialNumber   =>' || sMaterialNumber   ) ;
         DBMS_Output.Put_Line( 'Description      =>' || sDescription      ) ;
         DBMS_Output.Put_Line( 'PricingGroup     =>' || sPricingGroup     ) ;
         DBMS_Output.Put_Line( 'StartDate        =>' || sStartDate        ) ;
         DBMS_Output.Put_Line( 'EndDate          =>' || sEndDate          ) ;
         DBMS_Output.Put_Line( 'EAN              =>' || sEAN              ) ;
         DBMS_Output.Put_Line( 'BaseUnitMeasure  =>' || sBaseUnitMeasure  ) ;
         DBMS_Output.Put_Line( 'ProductType      =>' || sProductType      ) ;
         DBMS_Output.Put_Line( 'SalesUnitPerPack =>' || sSalesUnitPerPack ) ;
         DBMS_Output.Put_Line( 'ProductLine      =>' || sProductLine      ) ;
         DBMS_Output.Put_Line( 'Flag             =>' || sFlag             ) ;
         DBMS_Output.Put_Line( 'LineProduct      =>' || sLineProduct      ) ;
         DBMS_Output.Put_Line( 'DefaultProduct   =>' || sDefaultProduct   ) ;
         DBMS_Output.Put_Line( 'CigarreteSize    =>' || sCigarreteSize    ) ;
         DBMS_Output.Put_Line( 'FilterType       =>' || sFilterType       ) ;
         DBMS_Output.Put_Line( 'FlavourType      =>' || sFlavourType      ) ;
         DBMS_Output.Put_Line( 'PackType         =>' || sPackType         ) ;
         DBMS_Output.Put_Line( 'Manufacture      =>' || sManufacture      ) ;
         DBMS_Output.Put_Line( 'BlendingTobacco  =>' || sBlendingTobacco  ) ;
         DBMS_Output.Put_Line( 'UnidadMedVenta   =>' || sUMV              ) ;         
      END IF ;      
      sProcesar := 'NO' ;
      SELECT EAI_Owner.getConv( 'CFG Settings', 'Send Product V3' )  INTO  sProcesar
         FROM DUAL ;
      IF ( sProcesar = 'SI' ) THEN
         IF ( nOutput > 0 ) THEN
            DBMS_Output.Put_Line( 'Producto Enviado a T3 =>' || sMaterialNumber ) ;         
         END IF ;
      END IF ;    
   END LOOP ;  
   UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = DECODE( sProcesar, 'SI', 'Processed', 'Review' )
      WHERE Row_ID = sROW_ID ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := sStage || '. ' || SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Error'
         WHERE Row_ID = sROW_ID ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Processing PI'    , v_ID                  , SYSDATE             , NULL           ,
          'Error'            , 'PROC_PRODUCT'        , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_PRODUCT ;