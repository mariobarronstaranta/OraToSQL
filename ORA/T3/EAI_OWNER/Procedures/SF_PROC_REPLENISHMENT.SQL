create or replace PROCEDURE           SF_PROC_REPLENISHMENT
   ( sRow_ID   IN   VARCHAR2,
     nRowNum   IN   NUMBER DEFAULT 1,
     nOutput   IN   NUMBER DEFAULT 0,
     nPID      IN   NUMBER DEFAULT NULL )
IS
   sMsg              VARCHAR2(500) ;   
   v_ID              VARCHAR2(050) ;
   sErrorCode        VARCHAR2(020) ;
   sProcesar         VARCHAR2(002) ;
   sLineDebug        VARCHAR2(999) ;
--   
   sReferenceID      VARCHAR2(050) ;
   sShippingPoint    VARCHAR2(050) ;
   sDeliveryType     VARCHAR2(050) ;
   sDeliveryNumber   VARCHAR2(020) ;
   sDeliveryDate     VARCHAR2(020) ;
   sCustomerAG       VARCHAR2(050) ;
   sCustomerWE       VARCHAR2(050) ;
   sCustomerSB       VARCHAR2(050) ;
   sCteFacturaSAP    VARCHAR2(050) ;
   nItems            NUMBER(04)    ;
   sMaterial         VARCHAR2(050) ;
   sPlant            VARCHAR2(050) ; 
   sStorageLocation  VARCHAR2(050) ;
   sActualQuantity   VARCHAR2(050) ;
   sSalesUnit        VARCHAR2(050) ;
   sVanName          VARCHAR2(050) ;
   sUMVSAP           VARCHAR2(050) ;
   sQuantityUMV      VARCHAR2(050) ;
   sPOrderNumber     VARCHAR2(050) ;
   sQualifier        VARCHAR2(050) ;
   sPurchaseOrder    VARCHAR2(050) ;
   sDocReference     VARCHAR2(050) ;
   sMaterialName     VARCHAR2(500) ; 
   sEmp_Row_ID       VARCHAR2(050) ;
   sOrder_Num        VARCHAR2(050) ;   
   sOrgVentas        VARCHAR2(010) ;
   sGRID             VARCHAR2(080) ;
   nCounter          NUMBER(04)    ;
   nCasePack         NUMBER(04)    ;
   nVolDetail        NUMBER(14)    ;
   sCountry          VARCHAR2(080) ;
   sPartnerName      VARCHAR2(080) ;
   sCity             VARCHAR2(080) ;
   sDistrict         VARCHAR2(080) ;
   sPostalCode       VARCHAR2(080) ;
   sRegion           VARCHAR2(080) ;
   sAddress          VARCHAR2(080) ;
   sDocNum           VARCHAR2(080) ;
--
   sSold_Customer      VARCHAR2(010) ;
   sSold_Name          VARCHAR2(080) ;
   sSold_Address       VARCHAR2(080) ;
   sSold_District      VARCHAR2(080) ;
   sSold_City          VARCHAR2(080) ;
   sSold_State         VARCHAR2(080) ;
   sSold_Country       VARCHAR2(080) ;
   sSold_ZipCode       VARCHAR2(080) ;
   sBill_Customer      VARCHAR2(010) ;
   sBill_Name          VARCHAR2(080) ;
   sBill_Address       VARCHAR2(080) ;
   sBill_District      VARCHAR2(080) ;
   sBill_City          VARCHAR2(080) ;
   sBill_State         VARCHAR2(080) ;
   sBill_Country       VARCHAR2(080) ;
   sBill_ZipCode       VARCHAR2(080) ;
   sShip_Customer      VARCHAR2(010) ;
   sShip_Name          VARCHAR2(080) ;
   sShip_Address       VARCHAR2(080) ;
   sShip_District      VARCHAR2(080) ;
   sShip_City          VARCHAR2(080) ;
   sShip_State         VARCHAR2(080) ;
   sShip_Country       VARCHAR2(080) ;
   sShip_ZipCode       VARCHAR2(080) ;
   sOBD                VARCHAR2(080) ;
--   
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/VanReplenishment/Header/Reference/ReferenceID')              AS ReferenceIDOC    ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryNumber')     AS ReferenceID      ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/ShippingPoint')      AS ShippingPoint    ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryType')       AS DeliveryType     ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryNumber')     AS DeliveryNumber   ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/SalesOrganization')  AS SalesOrganization,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/GRID')               AS GRID             ,
            extractValue( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryDate')       AS DeliveryDate            
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;       
--
   CURSOR ScrPartners IS
      SELECT ExtractValue( VALUE( Lista ), '*/PartnerFunction'   ) AS PartnerFunction,
             ExtractValue( VALUE( Lista ), '*/PartnerNumber'     ) AS PartnerNumber  ,
             ExtractValue( VALUE( Lista ), '*/PartnerCountry'    ) AS Country        ,
             ExtractValue( VALUE( Lista ), '*/PartnerName'       ) AS PartnerName    ,
             ExtractValue( VALUE( Lista ), '*/PartnerCity'       ) AS City           ,
             ExtractValue( VALUE( Lista ), '*/PartnerDistrict'   ) AS District       ,
             ExtractValue( VALUE( Lista ), '*/PartnerPostalCode' ) AS PostalCode     ,
             ExtractValue( VALUE( Lista ), '*/PartnerRegion'     ) AS Region         ,
             ExtractValue( VALUE( Lista ), '*/PartnerAddress'    ) AS Address                 
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/VanReplenishment/Message/DeliveryHeader/PartnerInfo' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
    CURSOR ScrItems IS
       SELECT VALUE( Lista ) AS Item_Content
       FROM EAI_Owner.MX_Receive_Message_Log Msg,
            TABLE( XMLSequence( Extract ( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryLineItem' ) ) ) Lista
       WHERE Msg.Row_ID = sRow_ID ;    
--
    CURSOR ScrMaterial IS
     SELECT SKU.UM, SKU.CIG_X_CLL, SKU.CIG_X_PAQ/SKU.CIG_X_CLL AS CASE_PACK
        FROM T3.MATERIAL SKU
        WHERE SKU.MATERIAL= sMaterial ;
--
    CURSOR ScrTepic IS
        SELECT NVL( Factor_KG, 0 ) AS Factor_KG
           FROM T3.CFDI_PRODSERV
           WHERE Material = sMaterial ;         
--
BEGIN
   sCountry       := '' ;
   sPartnerName   := '' ;
   sCity          := '' ;
   sDistrict      := '' ;
   sPostalCode    := '' ;
   sRegion        := '' ;
   sAddress       := '' ;
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'Begin' ) ;
   END IF ;   
   FOR Rec IN ScrData LOOP 
      v_ID         := Rec.ReferenceID   ;
      sReferenceID := V_ID              ;
      sProcesar    := 'SI'              ;
      sDocNum      := Rec.ReferenceIDOC ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
         IF ( Rec.ReferenceIDOC IS NOT NULL ) THEN
            sProcesar    := 'SI' ;
            v_ID         := Rec.ReferenceIDOC ;
            sReferenceID := V_ID ;
         END IF ;
      END IF ;
      IF ( sDeliveryType = 'Stock Discard' ) THEN
         sProcesar := 'SD' ;
      END IF ;      
      IF ( sProcesar = 'SI' ) THEN
         sShippingPoint   := Rec.ShippingPoint     ;
         sDeliveryType    := Rec.DeliveryType      ;
         sDeliveryNumber  := Rec.DeliveryNumber    ;
         sDeliveryDate    := Rec.DeliveryDate      ;
         sOrgVentas       := Rec.SalesOrganization ;
         sGRID            := Rec.GRID              ;
         IF ( LENGTH( NVL( sDeliveryDate, ' ' ) ) < 5 ) THEN
            sDeliveryDate := TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ;
         END IF ; 
         IF ( sDeliveryType = 'BAT LEFT ON BOARD DI' ) THEN
            sDeliveryType := 'Stock Transfer' ;
         END IF ;         
         FOR SubRec IN ScrPartners LOOP
            IF    ( SubRec.PartnerFunction = 'AG' ) THEN
                 sCustomerAG    := SubRec.PartnerNumber    ;
                 sCountry       := Subrec.Country          ;
                 sPartnerName   := subRec.PartnerName      ;
                 sCity          := SubRec.City             ;
                 sDistrict      := SubRec.District         ;
                 sPostalCode    := SubRec.PostalCode       ;
                 sRegion        := SubRec.Region           ;
                 sAddress       := SubRec.Address          ;
                 
                 sSold_Customer := SubRec.PartnerNumber    ;
                 sSold_Name     := SubRec.PartnerName      ;
                 sSold_Address  := SubRec.Address          ;
                 sSold_District := SubRec.District         ;
                 sSold_City     := SubRec.City             ;
                 sSold_State    := SubRec.Region           ;
                 sSold_Country  := SubRec.Country          ;
                 sSold_ZipCode  := subRec.PostalCode       ;
                 ELSIF ( SubRec.PartnerFunction = 'RE' ) THEN
                 sCteFacturaSAP := SubRec.PartnerNumber    ;
                 sBill_Customer := SubRec.PartnerNumber    ;
                 sBill_Name     := SubRec.PartnerName      ;
                 sBill_Address  := subRec.Address          ;
                 sBill_District := SubRec.District         ;
                 sBill_City     := SubRec.City             ;
                 sBill_State    := SubRec.Region           ;
                 sBill_Country  := SubRec.Country          ;
                 sBill_ZipCode  := SubRec.PostalCode       ;
            ELSIF ( SubRec.PartnerFunction = 'WE' ) THEN
                 sCustomerWE    := SubRec.PartnerNumber    ;
                 sShip_Customer := SubRec.PartnerNumber    ;
                 sShip_Name     := subRec.PartnerName      ;
                 sShip_Address  := SubRec.Address          ;
                 sShip_District := SubRec.District         ;
                 sShip_City     := SubRec.City             ;
                 sShip_State    := SubRec.Region           ;
                 sShip_Country  := SubRec.Country          ;
                 sShip_ZipCode  := SubRec.PostalCode       ;
            ELSIF ( SubRec.PartnerFunction = 'SB' ) THEN
                 sCustomerSB := SubRec.PartnerNumber ;
            END IF ;
         END LOOP ;
--
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_HEADER     WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL     WHERE ReferenceID = sReferenceID ; 
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_CONDITIONS WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS   WHERE ReferenceID = sReferenceID ;
         INSERT INTO EAI_OWNER.TMP_DOCUMENT_HEADER
           ( ReferenceID    , ShippingPoint , DeliveryType       , Cust_to_SAP, Ship_to_SAP, Storage_SAP, PedidoV3,
             Pais           , NombreCliente , Ciudad             , Colonia    , Created           ,
             CodigoPostal   , Estado        , Direccion          , OrgVentas  , ReferenciaBancaria,            
             FacturaSAP     , DocumentDate  , MetodoPago         , Rep_ROWID  , Incoterms )
         VALUES
            ( sReferenceID  , sShippingPoint, sDeliveryType      , sCustomerAG, sCustomerWE, sCustomerSB, sVanName, 
              sCountry      , sPartnerName  , sCity              , sDistrict  , SYSDATE           ,
              sPostalCode   , sRegion       , sAddress           , sOrgVentas , sGRID             ,      
              sDeliveryNumber, sDeliveryDate, 'Van Replenishment', sCustomerSB, sDocNum   ) ;
         sOBD := 'Check OBD' ; 
         IF ( sDeliveryType = 'Receive Other' ) THEN     
            sOBD := T3.FN_EVAL_REMISION_OBD( '', '', sCustomerAG ) ;   
            IF ( sOBD = 'YES' ) THEN
               sProcesar     := 'SI' ;
            END IF ;
         END IF ;    
         INSERT INTO EAI_OWNER.TMP_DOCUMENT_PARTNERS
            ( ReferenceID             ,
              Sold_to_Customer        , Sold_to_Name            , Sold_to_Address         , Sold_to_District        ,
              Sold_to_City            , Sold_to_State           , Sold_to_Country         , Sold_to_ZipCode         ,
              Bill_to_Customer        , Bill_to_Name            , Bill_to_Address         , Bill_to_District        ,
              Bill_to_City            , Bill_to_State           , Bill_to_Country         , Bill_to_ZipCode         ,
              Ship_to_Customer        , Ship_to_Name            , Ship_to_Address         , Ship_to_District        ,
              Ship_to_City            , Ship_to_State           , Ship_to_Country         , Ship_to_ZipCode          )
         VALUES
            ( sReferenceID  ,
              sSold_Customer          , sSold_Name              , sSold_Address           , sSold_District          ,
              sSold_City              , sSold_State             , sSold_Country           , sSold_ZipCode           ,
              sBill_Customer          , sBill_Name              , sBill_Address           , sBill_District          ,
              sBill_City              , sBill_State             , sBill_Country           , sBill_ZipCode           ,
              sShip_Customer          , sShip_Name              , sShip_Address           , sShip_District          ,
              sShip_City              , sShip_State             , sShip_Country           , sShip_ZipCode            ) ;     
--
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'ReferenceID   -> ' || sReferenceID    ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'Shippingpoint -> ' || sShippingPoint  ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'DeliveryType  -> ' || sDeliveryType   ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'CustomerAG    -> ' || sCustomerAG     ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'CustomerWE    -> ' || sCustomerWE     ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'CustomerSB    -> ' || sCustomerSB     ) ;
         END IF ;   
-- 
         nItems     := 0 ;
         nVolDetail := 0 ;
         FOR Item IN ScrItems LOOP
            nItems := nItems + 1 ;
         -- It's required to make the segment E1EDL41 (DeliveryLineReference) optional 
         -- Begin
            FOR SrcLineRef IN (
                SELECT ExtractValue( VALUE( Listing ), '*/Qualifier' )             AS Qualifier          ,
                       ExtractValue( VALUE( Listing ), '*/PurchaseOrderNumber' )   AS PurchaseOrderNumber   
                FROM -- EAI_Owner.MX_Receive_Message_Log Msg,
                TABLE ( XMLSequence( Extract ( Item.Item_Content, '/DeliveryLineItem/DeliveryLineReference' ) ) ) Listing
            )
            LOOP
                IF ( SrcLineRef.Qualifier = '001' ) THEN
                    sPOrderNumber := SrcLineRef.PurchaseOrderNumber ;
                ELSIF ( SrcLineRef.Qualifier = '999' ) THEN
                    sPOrderNumber := SrcLineRef.PurchaseOrderNumber ;
                END IF ;
            END LOOP;
         -- 
            SELECT   
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/MaterialNumber'  )   AS Material       ,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/Plant'           )   AS Plant          ,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/StorageLocation' )   AS StorageLocation,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/ActualQuantity'  )   AS ActualQuantity ,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/SalesUnit'       )   AS SalesUnit      ,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/DeliveryLineReference/PurchaseOrderNumber' )
                                                                                             AS PurchaseOrder  ,
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/MaterialName'    )   AS MaterialName   ,                                                                                             
                    ExtractValue( Item.Item_Content, '/DeliveryLineItem/DocumentReference' ) AS DocumentReference                                                                                             
                INTO sMaterial, sPlant, sStorageLocation, sActualQuantity, sSalesUnit, sPurchaseOrder, sMaterialName, sDocReference
                FROM DUAL ;
--
-- Workaround para Return Defective
            sPurchaseOrder := REPLACE( sPurchaseOrder, '-D', '' ) ;
--
            SELECT EAI_Owner.getConv( 'ECC_V3 UOM', sSalesUnit ) 
                   INTO sSalesUnit 
               FROM DUAL ;
            sQuantityUMV := sActualQuantity ;  
            IF ( sShippingPoint = 'MX05' ) THEN 
               FOR MX05 IN ScrTepic LOOP
                  IF ( MX05.Factor_KG > 0 ) THEN
                     sQuantityUMV := sQuantityUMV * MX05.Factor_KG ;
                     sSalesUnit   := 'KG' ;
                  END IF ;
               END LOOP ;
            END IF ;                 
            FOR SKU IN ScrMaterial LOOP
            -- Same Sales Unit Measure ( Assortment )
               IF ( sSalesUnit = SKU.UM ) THEN
                  sUMVSAP      := SKU.UM      ;
                  sQuantityUMV := sActualQuantity ;
            -- Assortment by Outer and Sales Unit Measure in Pack   
               ELSIF ( ( sSalesUnit = 'PAQ' ) AND ( SKU.UM = 'CAJ' ) ) THEN
                  sUMVSAP         := sSalesUnit || '(Conv [*' || SKU.CASE_PACK || '])' ;
                  sQuantityUMV    := TRIM( TO_CHAR( TO_NUMBER( sActualQuantity ) * SKU.CASE_PACK ) ) ;
                  sSalesUnit      := SKU.UM ;
            -- Assortment by Pack and Sales Unit Measure in Outer
               ELSIF ( ( sSalesUnit = 'CAJ' ) AND ( SKU.UM = 'PAQ' ) ) THEN
                    SELECT MAX( NVL( Cig_x_PAQ, 0 ) / NVL( Cig_X_CLL, 1 ) ) AS CAJ_x_PAQ  INTO nCasePack
                       FROM T3.MATERIAL
                       WHERE Material = sMaterial ;
                    IF ( ( nCasePack IS NULL ) OR ( NVL( nCasePack, 0 ) = 0 ) ) THEN
                       nCasePack :=  1 ;
                    END IF ;
                    sUMVSAP         := sSalesUnit || '(Conv [/' || nCasePack || '])' ;
                    sQuantityUMV    := TRIM( TO_CHAR( TO_NUMBER( sActualQuantity ) / nCasePack ) ) ;
                    sSalesUnit      := SKU.UM ;
               ELSE       -- Non convertion
                  sUMVSAP      := 'SAP->' || sSalesUnit ;
                  sQuantityUMV := sActualQuantity ;               
               END IF ;
            END LOOP ;   
            IF ( nOutput > 0 ) THEN
               sLineDebug := 'Items => ' || nItems || ',' || sMaterial || ',' 
                             || sPlant || '-' || sStorageLocation || ' : ' || TO_CHAR( sActualQuantity, '999,999' ) || ' '
                             || sUMVSAP || ' ==> ' || TO_CHAR( sQuantityUMV, '999,999' ) || ' ' || sSalesUnit ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, sLineDebug ) ;
            END IF ;   
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_DETAIL
               ( ReferenceID, ItemID, Material, Plant, StorageLocation, Cantidad, UnidadMedida, MaterialDescripcion, Status_Producto )
            VALUES
               ( sReferenceID, nItems, sMaterial, sPlant, sStorageLocation, sQuantityUMV, sSalesUnit , NVL( sPOrderNumber, sMaterialName), sActualQuantity ) ;
            nVolDetail := nVolDetail + TO_NUMBER( NVL( sQuantityUMV, '0' ) ) ;
            UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET PedidoSAP = sDocReference
               WHERE ReferenceID = sReferenceID ;
            IF ( nOutput > 0 ) THEN
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'Order Reference -> ' || sPOrderNumber ) ;
            END IF ;   
         END LOOP ; 
         UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET Order_Num = sPOrderNumber 
            WHERE ReferenceID = sReferenceID ;
      ELSE
         sProcesar := 'ED' ;
      END IF ;
--
      IF ( SUBSTR( UPPER( sPOrderNumber ) , 1, 4 ) = 'CORR' ) THEN
         sProcesar := 'AJ' ;
      END IF ;          
--      
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = sPOrderNumber,
                                                  Processed = SYSDATE      , 
                                                  Status    = DECODE( sProcesar, 'SI', 'Processed' , 
                                                                                 'ED', 'CheckData' ,
                                                                                 'SD', 'Discard'   ,
                                                                                 'DD', 'Duplicated',
                                                                                 'NC', 'NotCollect',
                                                                                 'AJ', 'Adjust SAP',
                                                                                 'TR', 'Processed' ,
                                                                                       'Review' )
         WHERE Row_ID = sROW_ID ;    
      IF ( nVolDetail = 0 ) THEN
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'Discarding Non Volume' ) ;
         END IF ;   
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = sPOrderNumber || '-00',
                                                     Processed = SYSDATE               , 
                                                     Status    = 'Discard-00'
            WHERE Row_ID = sROW_ID ;          
         UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET Order_Num = Order_Num || '-00'
            WHERE ReferenceID = sReferenceID ;
         sProcesar := '00' ;
      END IF ;      
      IF ( sDeliveryType = 'Transportation' ) THEN
          sProcesar := 'RG' ;
      END IF ;
--
      IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'sProcesar -> ' || sProcesar ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'sDeliveryType -> ' || sDeliveryType ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'sOBD -> ' || sOBD ) ;
      END IF ;
--    sProcesar := 'SII' ;
      IF ( sProcesar = 'SI' ) THEN
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'PROC_REPLENISHMENT_SUBDEPOT -> ' || sReferenceID ) ;
         END IF ;   
         EAI_OWNER.PROC_REPLENISHMENT_SUBDEPOT( sReferenceID ) ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'INVOICE_TO_ENTREGA -> ' || sReferenceID ) ;
         END IF ;            
         EAI_OWNER.INVOICE_TO_ENTREGA( sReferenceID, nOutput, 'NOBILL' ) ;
         IF ( sOBD = 'YES' ) THEN
            T3.DELIVERY_IDOC_TO_REMISION( sReferenceID, 1, 0 ) ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'DELIVERY_IDOC_TO_REMISION (OBD) -> ' || sReferenceID ) ;
         END IF ;
      ELSIF ( sDeliveryType = 'Transportation' ) THEN
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'DELIVERY_IDOC_TO_REMSION -> ' || sReferenceID ) ;
         END IF ;   
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = sReferenceID   ,
                                                     Processed = SYSDATE        ,
                                                     Status    = 'Processed'
             WHERE Row_ID = sROW_ID ;     
         T3.DELIVERY_IDOC_TO_REMISION( sReferenceID, 1, 0 ) ;               
      END IF ;
   END LOOP ; 
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_REPLENISHMENT', sRow_ID, 'End' ) ;
   END IF ;   
--
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE                , CREATED             , MESSAGE        , JOB_PID,
          STATUS              , QUEUE_NAME               , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT              , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Processing PI'     , sRow_ID                  , SYSDATE             , NULL           , nPID   ,
          'Error'             , 'SF_PROC_REPLENISHMENT'     , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                     , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_REPLENISHMENT ;