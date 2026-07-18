create or replace PROCEDURE           SF_PROC_PREINVOICE_IFC
   ( sRow_ID   IN   VARCHAR2,
     nRowNum   IN   NUMBER DEFAULT 1,
     nOutput   IN   NUMBER DEFAULT 0,
     nPID      IN   NUMBER DEFAULT NULL )
IS
   sMsg                VARCHAR2(500) ;   
   v_ID                VARCHAR2(030) ;
   sErrorCode          VARCHAR2(020) ;
   sReferenceID        VARCHAR2(030) ;
   sProcesar           VARCHAR2(020) ;
   sFacturaSAP         VARCHAR2(030) ;
   sCurrency           VARCHAR2(030) ;
   sRFC                VARCHAR2(030) ;
   sRate               VARCHAR2(050) ;   
   sPaymentTerms       VARCHAR2(050) ;
   sClienteSAP         VARCHAR2(050) ;
   sCteEntregaSAP      VARCHAR2(050) ;
   sCteFacturaSAP      VARCHAR2(050) ;
   sCtePagadorSAP      VARCHAR2(050) ;
   sFacturaV3          VARCHAR2(050) ;
   sFechaFactura       VARCHAR2(050) ;
   sFechaVencimiento   VARCHAR2(050) ;
   sHoraFactura        VARCHAR2(050) ;
   sPedidoSAP          VARCHAR2(050) ;
   sPedidoV3           VARCHAR2(050) ;   
   sCountry            VARCHAR2(080) ;
   sPartnerName        VARCHAR2(080) ;
   sCity               VARCHAR2(080) ;
   sDistrict           VARCHAR2(080) ;
   sPostalCode         VARCHAR2(080) ;
   sRegion             VARCHAR2(080) ;
   sAddress            VARCHAR2(080) ;   
   sDOC_TYPE           VARCHAR2(020) ;
--   
   sNumLinea           VARCHAR2(050) ;
   sOrgVentas          VARCHAR2(050) ;
   sClaseFactura       VARCHAR2(050) ;
   sCompanyCode        VARCHAR2(050) ;
   sValor_Subt         VARCHAR2(050) ;
   sValor_IVA          VARCHAR2(050) ;   
   sCantidadVta        VARCHAR2(050) ; 
   sUnidadMedVta       VARCHAR2(050) ;
   sStatusItem         VARCHAR2(050) ;   
   sCentro             VARCHAR2(050) ; 
   sMaterialUOM        VARCHAR2(050) ;
   sMaterial           VARCHAR2(050) ; 
   sMatDescription     VARCHAR2(050) ; 
   sPrecioUnitario     VARCHAR2(050) ; 
   sDetValor_Subt      VARCHAR2(050) ; 
   sDetValor_IVA       VARCHAR2(050) ; 
   sDetBonif_Subt      VARCHAR2(050) ;
   sCondZFSIValue      VARCHAR2(050) ;
   sCondZFSISign       VARCHAR2(050) ;
   sCondZFSKValue      VARCHAR2(050) ;
   sCondZFSKSign       VARCHAR2(050) ;
   sCondZT21Value      VARCHAR2(050) ;
   sCondZT21Sign       VARCHAR2(050) ;
   sCondZPROValue      VARCHAR2(050) ;
   sCondZEXSValue      VARCHAR2(050) ;
   sCondZEXCValue      VARCHAR2(050) ;
   sCondZEXOValue      VARCHAR2(050) ;
   sPaymentMethod      VARCHAR2(200) ;
   sBankReference      VARCHAR2(200) ;
   sQualifier          VARCHAR2(080) ;
   sLanguage           VARCHAR2(080) ;
   sTextLine           VARCHAR2(080) ;
   sItemText_ES        VARCHAR2(080) ;
   sItemText_EN        VARCHAR2(080) ;
   nItems              NUMBER(04)    ;
   itemXML             XMLTYPE       ; 
   itemTextos          XMLTYPE       ;
   sTipoDocV3          VARCHAR2(04)  ;
   sFolioFiscalDoc     VARCHAR2(030) ;
   sSalesDoc_Type      VARCHAR2(030) ;
   sCustomerRep        VARCHAR2(030) ;
   nA51                NUMBER(4)     ;
--
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/DocumentNumber'  )            AS ReferenceID   ,  
            extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/Currency'        )            AS Currency      ,
--          extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/RFC'             )            AS RFC           ,
            extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/V3DocumentNumber')            AS RFC           ,
            extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/Rate'            )            AS Rate          ,
            extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/PaymentTerms'    )            AS PaymentTerms
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;       
--
   CURSOR ScrPartners IS
      SELECT ExtractValue( VALUE( Lista ), '*/Function'   ) AS FunctionID ,
             ExtractValue( VALUE( Lista ), '*/PartnerID'  ) AS PartnerID  ,
             ExtractValue( VALUE( Lista ), '*/Country'    ) AS Country    ,
             ExtractValue( VALUE( Lista ), '*/Name'       ) AS PartnerName,
             ExtractValue( VALUE( Lista ), '*/City'       ) AS City       ,
             ExtractValue( VALUE( Lista ), '*/District'   ) AS District   ,
             ExtractValue( VALUE( Lista ), '*/PostalCode' ) AS PostalCode ,
             ExtractValue( VALUE( Lista ), '*/Region'     ) AS Region     ,
             ExtractValue( VALUE( Lista ), '*/Address'    ) AS Address    
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/InvoicePartner' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrConditions IS
      SELECT ExtractValue( VALUE( Lista ), '*/Indicator'     ) AS CondIndicator,
             ExtractValue( VALUE( Lista ), '*/Total'         ) AS Total        ,
             ExtractValue( VALUE( Lista ), '*/Amount'        ) AS Amount       ,
             ExtractValue( VALUE( Lista ), '*/Currency'      ) AS Currency     ,
             ExtractValue( VALUE( Lista ), '*/ConditionText' ) AS ConditionText,
             ExtractValue( VALUE( Lista ), '*/UnitPrice'     ) AS UnitPrice    ,
             ExtractValue( VALUE( Lista ), '*/ConditionID'   ) AS ConditionID  ,
             ExtractValue( VALUE( Lista ), '*/UOM'           ) AS UOM          ,
             ExtractValue( VALUE( Lista ), '*/Quantity'      ) AS Quantity    
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/HeaderConditions' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;      
--
   CURSOR ScrReferenceData IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier' ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Document'  ) AS RefDocument , 
             ExtractValue( VALUE( Lista ), '*/Date'      ) AS RefDate     ,
             ExtractValue( VALUE( Lista ), '*/Time'      ) AS RefTime
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/ReferenceData' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrHeaderDate IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier' ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Date'      ) AS RefDate     
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/HeaderDate' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrOrganizationData IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier'    ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Organization' ) AS RefValue
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/OrganizationData' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrSummaryGeneral IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier'    ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/ValueSummary' ) AS RefValue    
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/SummaryGeneral' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
    CURSOR ScrHeaderText IS
       SELECT VALUE( Lista ) AS Item_Content
       FROM EAI_Owner.MX_Receive_Message_Log Msg,
            TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/TextIdentification' ) ) ) Lista
       WHERE Msg.Row_ID = sRow_ID ;    
--
   CURSOR ScrHeaderTextLine IS
      SELECT ExtractValue( VALUE( Lista ), '*/TextLine'   ) AS TextLine ,
             ExtractValue( VALUE( Lista ), '*/TagColumn'  ) AS TextTag    
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemTextos, '/TextIdentification/TextHeader' ) ) ) Lista ;
--
-- Cursores sobre Items
--
    CURSOR ScrItemData IS
       SELECT VALUE( Lista ) AS Item_Content
       FROM EAI_Owner.MX_Receive_Message_Log Msg,
            TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/ItemData' ) ) ) Lista
       WHERE Msg.Row_ID = sRow_ID ;    
--
   CURSOR ScrItemID IS
      SELECT ExtractValue( VALUE( Lista ), '*/MaterialID'           ) AS RefMaterialID ,
             ExtractValue( VALUE( Lista ), '*/ObjectIdentification' ) AS RefQualifier  ,
             ExtractValue( VALUE( Lista ), '*/MaterialDescription'  ) AS RefDescription,
             ExtractValue( VALUE( Lista ), '*/PartNumber'           ) AS RefPartNumber
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemID' ) ) ) Lista ;
--
   CURSOR ScrItemTerms IS
      SELECT ExtractValue( VALUE( Lista ), '*/ValueAmount'   ) AS RefValueAomunt  ,
             ExtractValue( VALUE( Lista ), '*/Qualifier'     ) AS RefQualifier    ,
             ExtractValue( VALUE( Lista ), '*/TotalLineItem' ) AS RefTotalLineItem,
             ExtractValue( VALUE( Lista ), '*/PriceItem'     ) AS RefPriceItem    
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemTerms' ) ) ) Lista ;
--
   CURSOR ScrItemConditionTerms IS
      SELECT 
             ExtractValue( VALUE( Lista ), '*/TermConditionIndicator' ) AS ItemCondSign ,
             ExtractValue( VALUE( Lista ), '*/TermConditionType'      ) AS ItemCondType ,
             ExtractValue( VALUE( Lista ), '*/TermConditionValue'     ) AS ItemCondValue    
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemTermsCondition' ) ) ) Lista ;
--
   CURSOR ScrItemTaxs IS
      SELECT ExtractValue( VALUE( Lista ), '*/ValueTax'      ) AS RefValueTax ,
             ExtractValue( VALUE( Lista ), '*/VATIndicator'  ) AS RefQualifier    
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemTaxes' ) ) ) Lista ;
--
   CURSOR ScrItemTexts IS
      SELECT VALUE( Lista ) AS ItemTextSegment
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemTextHeader' ) ) ) Lista ;
--
   CURSOR ScrItemTextLine IS
      SELECT 
--             ExtractValue( VALUE( Textos ), '*/TextLine'   ) AS TextLine ,
--             ExtractValue( VALUE( Textos ), '*/TagColumn'  ) AS TextTag  ,
             VALUE( Textos ) AS ItemTextLineSegment
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemTextos, '/ItemTextHeader/ItemTextDetail' ) ) ) Textos ;
--
   CURSOR ScrMaterialUOM IS
     SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', sUnidadMedVta ) AS UOM_Fact   ,
            SKU.UM                                           AS UOM_SKU    , 
            NVL( SKU.CIG_X_CLL, 0 )                          AS CIG_X_CLL  ,
            DECODE( NVL( SKU.CIG_X_CLL, 0 ), 0, 1,
                    SKU.CIG_X_PAQ/SKU.CIG_X_CLL  )           AS CASE_PACK  , 
            DECODE( NVL( SKU.CIG_X_CLL, 0 ), 0, 1,
                    SKU.CIG_X_CT/SKU.CIG_X_CLL )             AS MASTER_CASE
        FROM T3.MATERIAL SKU
        WHERE SKU.MATERIAL = sMaterialUOM ;  
--
   CURSOR ScrA51 IS
       SELECT CFG.Source AS Cliente_SAP
       FROM EAI_Owner.MX_Hashtable CFG
       WHERE CFG.Type   = 'PDV A51'
         AND CFG.Source = sClienteSAP ;
BEGIN
   sTipoDocV3 := 'NO' ;
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Begin' ) ;   
   END IF ;
   FOR Rec IN ScrData LOOP 
      v_ID         := Rec.ReferenceID ;
      sReferenceID := Rec.ReferenceID ;
      sFacturaSAP  := Rec.ReferenceID ;
      sProcesar    := 'SI'            ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
      END IF ;
      IF ( sProcesar = 'SI' ) THEN
         sCurrency      := Rec.Currency       ;    
         sRFC           := Rec.RFC            ;
         sRate          := Rec.Rate           ;
         sPaymentTerms  := Rec.PaymentTerms   ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_HEADER     WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL     WHERE ReferenceID = sReferenceID ; 
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_CONDITIONS WHERE ReferenceID = sReferenceID ;
      -- Partners
         FOR Scr IN ScrPartners LOOP
             IF    ( Scr.FunctionID = 'AG' ) THEN
                 sClienteSAP    := Scr.PartnerID    ;
                 sCountry       := Scr.Country      ;
                 sPartnerName   := Scr.PartnerName  ;
                 sCity          := Scr.City         ;
                 sDistrict      := Scr.District     ;
                 sPostalCode    := Scr.PostalCode   ;
                 sRegion        := Scr.Region       ;
                 sAddress       := Scr.Address      ;
             ELSIF ( Scr.FunctionID = 'RSA' ) THEN
                 sCteFacturaSAP := Scr.PartnerID ;
             ELSIF ( Scr.FunctionID = 'RE' ) THEN
                 sCtePagadorSAP := Scr.PartnerID ;
                 sCteFacturaSAP := Scr.PartnerID ;
             ELSIF ( Scr.FunctionID = 'WE' ) THEN
                 sCteEntregaSAP := Scr.PartnerID ;
             END IF ;
         END LOOP ;
      -- Header Date
         FOR Scr IN ScrHeaderDate LOOP
            IF    ( Scr.RefQualifier = '028' ) THEN
               sFechaVencimiento := Scr.RefDate ;
            END IF ;
         END LOOP ;
      -- Reference Data
         FOR Scr IN ScrReferenceData LOOP
            IF    ( Scr.RefQualifier = '001' ) THEN
               sPedidoV3     := UPPER( Scr.RefDocument ) ;
            ELSIF ( Scr.RefQualifier = '002' ) THEN
               sPedidoSAP    := Scr.RefDocument ;
            ELSIF ( Scr.RefQualifier = '009' ) THEN
               sFechaFactura := Scr.RefDate     ;
               sHoraFactura  := Scr.RefTime     ;
            ELSIF ( Scr.RefQualifier = '017' ) THEN
               sFacturaV3    := Scr.RefDocument ;
            END IF ;
         END LOOP ;
      -- Organization Data
         FOR Scr IN ScrOrganizationData LOOP
            IF    ( Scr.RefQualifier = '008' ) THEN
               sOrgVentas    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '003' ) THEN
               sCompanyCode  := Scr.RefValue ;
               sOrgVentas    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '015' ) THEN
               IF ( Scr.RefValue = 'Nota de Venta' ) THEN
                  sClaseFactura := 'C005' ;
               ELSIF ( Scr.RefValue = 'Payable' ) THEN
                  sClaseFactura := 'C004' ;
               ELSIF ( Scr.RefValue = 'PROFORMA' ) THEN                         -- Devolucion Presales
                  sClaseFactura := 'C006'       ;    
                  sFacturaV3    := sReferenceID ;
               ELSIF ( Scr.RefValue = 'ZIG2' ) THEN                             -- CM Value Interocopany ( Z022 )
                  sClaseFactura := 'C022'       ;    
                  sFacturaV3    := sReferenceID ;
               ELSIF ( Scr.RefValue = 'ZB1E' ) THEN                             -- Rebates ( Z019 )
                  sClaseFactura := 'C019'       ;    
                  sFacturaV3    := sReferenceID ;
               ELSIF ( Scr.RefValue = 'ZG'   ) THEN                             -- Charolas ( Z024 )
                  sClaseFactura := 'C025'       ;    
                  sFacturaV3    := sReferenceID ;
                  IF ( SUBSTR( sClienteSAP, 1, 3 ) = '009' ) THEN
                     sClaseFactura := 'C031' ;
                  END IF ;
               ELSIF ( Scr.RefValue = 'ZL'   ) THEN                             -- Fee ( Z0FX )
                  sClaseFactura := 'C0FX'       ;    
                  sFacturaV3    := sReferenceID ;
                  IF ( SUBSTR( sClienteSAP, 1, 3 ) = '009' ) THEN
                     sClaseFactura := 'C030' ;
                  END IF ;
               END IF ;
            END IF ;
         END LOOP ;
      -- Summary General
         FOR Scr IN ScrSummaryGeneral LOOP
            IF    ( Scr.RefQualifier = '005' ) THEN
               sValor_IVA    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '011' ) THEN
               sValor_Subt   := Scr.RefValue ;
            END IF ;
         END LOOP ;
      -- Conditions        
         nItems := 0 ;
         FOR Scr IN ScrConditions LOOP
            nItems := nItems + 1 ;
            IF ( nOutput > 0 ) THEN
               IF ( nItems = 1 ) THEN
                  DBMS_Output.Put_Line( 'Document Conditions' ) ;
               END IF ;
               DBMS_Output.Put_Line( 'Linea => ' || nItems || ',' || Scr.CondIndicator || ','
                  || Scr.Total || ',' || Scr.Amount || ',' || Scr.Currency || ',' || Scr.ConditionText 
                  || ',' || Scr.UnitPrice || ',' || Scr.ConditionID || ',' || Scr.UOM || ',' || Scr.Quantity ) ;       
            END IF ;
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_CONDITIONS 
               ( ReferenceID    , ItemID       , Condition        , TotalCondition,
                 TotalAmount    , Currency     , ConditionText    , UnitPrice     ,
                 ConditionID    , UnitMeasure  , Quantity                          )        
            VALUES
               ( sReferenceID   , nItems       , Scr.CondIndicator, Scr.Total     ,
                 Scr.Amount     , Scr.Currency , Scr.ConditionText, Scr.UnitPrice ,
                 Scr.ConditionID, Scr.UOM      , Scr.Quantity                      ) ;
         END LOOP ;
--
         nItems := 0 ;
         FOR Item IN ScrHeaderText LOOP
            itemTextos := Item.Item_Content ;
            nItems     := nItems + 1        ;
            SELECT   ExtractValue( Item.Item_Content, '/TextIdentification/TextID'    )   AS sQualifier   ,
                     ExtractValue( Item.Item_Content, '/TextIdentification/Language'  )   AS sLanguage
               INTO sQualifier, sLanguage
               FROM DUAL ;
            FOR TxtLine IN ScrHeaderTextLine LOOP
               IF    ( sQualifier = 'Z024' ) THEN
                  sPaymentMethod := sPaymentMethod || TxtLine.TextLine ;
               ELSIF ( sQualifier = 'Z048' ) THEN  
                  sBankReference := sBankReference || TxtLine.TextLine ;
               END IF ;
            END LOOP ;
         END LOOP ;
--      
         IF ( nOutput > 0 ) THEN
             DBMS_Output.Put_Line( 'Document Header' ) ;
             DBMS_Output.Put_Line( 'ReferenceID     => ' || sReferenceID      ) ;
             DBMS_Output.Put_Line( 'FacturaSAP      => ' || sFacturaSAP       ) ;
             DBMS_Output.Put_Line( 'Currency        => ' || sCurrency         ) ;
             DBMS_Output.Put_Line( 'RFC             => ' || sRFC              ) ;
             DBMS_Output.Put_Line( 'Rate            => ' || sRate             ) ;
             DBMS_Output.Put_Line( 'PaymentTerms    => ' || sPaymentTerms     ) ;
             DBMS_Output.Put_Line( 'ClienteSAP      => ' || sClienteSAP       ) ;
             DBMS_Output.Put_Line( 'CteFacturaSAP   => ' || sCteFacturaSAP    ) ;
             DBMS_Output.Put_Line( 'CteEntregaSAP   => ' || sCteEntregaSAP    ) ;
             DBMS_Output.Put_Line( '------------------' ) ;
             DBMS_Output.Put_Line( 'Country         => ' || sCountry          ) ;
             DBMS_Output.Put_Line( 'PartnerName     => ' || sPartnerName      ) ;
             DBMS_Output.Put_Line( 'City            => ' || sCity             ) ;
             DBMS_Output.Put_Line( 'District        => ' || sDistrict         ) ;
             DBMS_Output.Put_Line( 'PostalCode      => ' || sPostalCode       ) ;
             DBMS_Output.Put_Line( 'Region          => ' || sRegion           ) ;
             DBMS_Output.Put_Line( 'Address         => ' || sAddress          ) ;
             DBMS_Output.Put_Line( 'PaymentMethod   => ' || sPaymentMethod    ) ;
             DBMS_Output.Put_Line( 'BankReference   => ' || sBankReference    ) ;
             DBMS_Output.Put_Line( '------------------' ) ;             
--             
             DBMS_Output.Put_Line( 'FacturaV3       => ' || sFacturaV3        ) ;
             DBMS_Output.Put_Line( 'FechaFactura    => ' || sFechaFactura     ) ;
             DBMS_Output.Put_Line( 'HoraFactura     => ' || sHoraFactura      ) ;
             DBMS_Output.Put_Line( 'PedidoSAP       => ' || sPedidoSAP        ) ;
             DBMS_Output.Put_Line( 'FechaFactura    => ' || sFechaVencimiento ) ;
             DBMS_Output.Put_Line( 'PedidoV3        => ' || sPedidoV3         ) ;
             DBMS_Output.Put_Line( 'OrgVentas       => ' || sOrgVentas        ) ;
             DBMS_Output.Put_Line( 'ClaseFactura    => ' || sClaseFactura     ) ;
             DBMS_Output.Put_Line( 'CompanyCode     => ' || sCompanyCode      ) ;
             DBMS_Output.Put_Line( 'ValorSubt       => ' || sValor_Subt       ) ;
             DBMS_Output.Put_Line( 'ValorIVA        => ' || sValor_IVA        ) ;
             DBMS_Output.Put_Line( '----------------------------------' ) ;
         END IF ;
--
--       Detalle de Documento
--
         nItems := 0 ;
         FOR Item IN ScrItemData LOOP
--
            sNumLinea       := '' ;
            sCantidadVta    := '' ;
            sUnidadMedVta   := '' ;
            sCentro         := '' ;
            sMaterial       := '' ;
            sMatDescription := '' ;
            sDetValor_Subt  := '' ;
            sPrecioUnitario := '' ;
            sDetBonif_Subt  := '' ;
            sDetValor_IVA   := '' ;
            sItemText_ES    := '' ;
            sItemText_EN    := '' ;
            sCondZFSIValue  := '' ;
            sCondZFSISign   := '' ;   
            sCondZFSKValue  := '' ;
            sCondZFSKSign   := '' ;            
            sCondZT21Value  := '' ;
            sCondZT21Sign   := '' ;
            sCondZPROValue  := '' ;
            sCondZEXSValue  := '' ;
            sCondZEXCValue  := '' ;
            sCondZEXOValue  := '' ;
--         
            itemXML := Item.Item_Content ;
            nItems  := nItems + 1        ;
            SELECT   ExtractValue( Item.Item_Content, '/ItemData/ItemNumber'    )   AS NumLinea     ,
                     ExtractValue( Item.Item_Content, '/ItemData/Quantity'      )   AS CantidadVta  ,
                     ExtractValue( Item.Item_Content, '/ItemData/UnitOfMeasure' )   AS UnidadMedVta ,
                     ExtractValue( Item.Item_Content, '/ItemData/Plant'         )   AS Centro
               INTO sNumLinea, sCantidadVta, sUnidadMedVta, sCentro
               FROM DUAL ;
            SELECT EAI_Owner.LINE_ITEM_TEXT( sNumLinea )  INTO  sNumLinea
               FROM DUAL ;
         --      
            IF ( TO_NUMBER( sNumLinea ) > 9999 ) THEN
               sNumLinea := nItems ;
            END IF ;
            FOR Scr IN ScrItemID LOOP
               IF ( Scr.RefQualifier = '002' ) THEN
                  sMaterial       := Scr.RefMaterialID  ;
                  sMatDescription := Scr.RefDescription ;
               END IF ;          
            END LOOP ;
            FOR Scr IN ScrItemTerms LOOP
               IF    ( Scr.RefQualifier = '003' ) THEN
                  sDetValor_Subt  := Scr.RefValueAomunt ;
                  sPrecioUnitario := Scr.RefPriceItem   ;
               ELSIF ( Scr.RefQualifier = '007' ) THEN
                  sDetBonif_Subt := Scr.RefValueAomunt ;
               END IF ;          
            END LOOP ; 
--
            FOR Scr IN ScrItemConditionTerms LOOP
               IF    ( Scr.ItemCondType IN ( 'ZFSI', 'ZDN3' ) ) THEN
                  sCondZFSISign  := Scr.ItemCondSign  ;
                  sCondZFSIValue := Scr.ItemCondValue ;
               ELSIF  ( Scr.ItemCondType = 'ZFSK' ) THEN
                  sCondZFSKSign  := Scr.ItemCondSign  ;
                  sCondZFSKValue := Scr.ItemCondValue ;
               ELSIF ( Scr.ItemCondType = 'ZT21' ) THEN
                  sCondZT21Sign  := Scr.ItemCondSign  ;
                  sCondZT21Value := Scr.ItemCondValue ;
               ELSIF ( Scr.ItemCondType = 'ZDNV' ) THEN
                  sDetBonif_Subt := Scr.ItemCondValue ;    
               ELSIF ( Scr.ItemCondType = 'ZPR0' ) THEN
                  sCondZPROValue := Scr.ItemCondValue ;           
               ELSIF ( Scr.ItemCondType = 'ZEXS' ) THEN
                  sCondZEXSValue := Scr.ItemCondValue ;     
               ELSIF ( Scr.ItemCondType IN ( 'ZEXC', 'ZEXJ' ) ) THEN
                  sCondZEXCValue := Scr.ItemCondValue ;     
               ELSIF ( Scr.ItemCondType = 'ZEXO' ) THEN
                  sCondZEXOValue := Scr.ItemCondValue ;                       
               END IF ;          
            END LOOP ; 
--            
            FOR Scr IN ScrItemTaxs LOOP
--             IF    ( Scr.RefQualifier = 'MWST' ) THEN
                  sDetValor_IVA  := Scr.RefValueTax ;
--             END IF ;          
            END LOOP ;
            sQualifier   := '' ;
            sLanguage    := '' ;
            sItemText_ES := '' ;
            sItemText_EN := '' ;
            FOR TxtItem IN ScrItemTexts LOOP
               itemTextos := TxtItem.ItemTextSegment ;
               SELECT   ExtractValue( itemTextos, '/ItemTextHeader/TextID'    )   AS ItemTextID     ,
                        ExtractValue( itemTextos, '/ItemTextHeader/Language'  )   AS ItemTextLang
                  INTO sQualifier, sLanguage
                  FROM DUAL ;
               FOR TxtLine IN ScrItemTextLine LOOP
                  SELECT   ExtractValue( TxtLine.ItemTextLineSegment, '*/TextLine'    )   AS sTextLine   
                     INTO sTextLine
                     FROM DUAL ;
                  IF    ( sLanguage = 'ES' ) THEN
                     sItemText_ES := sItemText_ES || sTextLine ;
                  ELSIF ( sLanguage = 'EN' ) THEN  
                     sItemText_EN := sItemText_EN || sTextLine ;
                  END IF ;
               END LOOP ;
            END LOOP ;
            IF ( sMaterial = 'R031' ) THEN
               sMaterial := '8800111' ;
            ELSIF ( sMaterial = 'R902' ) THEN
               sMaterial := '8800111' ;
            END IF ;
     -- Workaround for Debit Note    
            IF ( sMaterial IN ( '88000001', '99000001' ) ) THEN
               sTipoDocV3     := 'DN'        ;              -- Debit Note
               sPartnerName   := sFacturaV3  ;
               sFacturaV3     := sClienteSAP ;
               sClienteSAP    := LPAD( sPartnerName, 10, '0' ) ;
               sPartnerName   := 'DebitNote' ;
               sBankReference := TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ;
            END IF ;
     -- Workaround for UOMs
            sMaterialUOM := SUBSTR( sMaterial, 11, 8 ) ;
            FOR SKU IN ScrMaterialUOM LOOP
               IF ( SKU.UOM_Fact != SKU.UOM_SKU ) THEN
                  sUnidadMedVta := SKU.UOM_SKU ;
                  IF    ( SKU.UOM_Fact = 'PAQ' ) THEN
                       sCantidadVta  := sCantidadVta * SKU.CASE_PACK ;
                  ELSIF ( SKU.UOM_Fact = 'CASES' ) THEN
                       sCantidadVta  := sCantidadVta * SKU.MASTER_CASE ;
                  ELSE
                     sUnidadMedVta := SKU.UOM_Fact ;
                  END IF ;                  
               END IF ;
            END LOOP ;
     --       
            IF ( nOutput > 0 ) THEN            
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Item           = ' || sNumLinea       ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Cantidad       = ' || sCantidadVta    ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Unidad Vta     = ' || sUnidadMedVta   ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Centro         = ' || sCentro         ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Material       = ' || sMaterial       ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Descripcion    = ' || sMatDescription ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Valor Subt     = ' || sDetValor_Subt  ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Valor IVA      = ' || sDetValor_IVA   ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Envio Subt     = ' || sCondZFSIValue  ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Credito Subt   = ' || sCondZFSKValue  ) ;                  
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Valor IEPS     = ' || sCondZT21Value  ) ;
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Bonif Subt     = ' || sDetBonif_Subt  ) ;
            END IF ;   
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_DETAIL
               ( ReferenceID    , ItemID         , Material       , Plant        ,
                 Cantidad       , UnidadMedida   , Valor_Subt     , Valor_IVA    ,
                 Bonif_Subt     , Status_Producto, MaterialDescripcion           ,
                 Envio_Subt     , Valor_IEPS     , Credito_Subt   ,
                 ZPRO_Valor     , ZEXS_Valor     , ZEXC_Valor     , ZEXO_Valor   ,
                 PrecioUnitario , Leyenda_EN     , Leyenda_ES                     )
            VALUES
               ( sReferenceID   , sNumLinea      , sMaterial      , sCentro      ,
                 sCantidadVta   , sUnidadMedVta  , sDetValor_Subt , sDetValor_IVA, 
                 sDetBonif_Subt , sStatusItem    , sMatDescription,
                 sCondZFSIValue , sCondZT21Value , sCondZFSKValue ,
                 sCondZPROValue , sCondZEXSValue , sCondZEXCValue , sCondZEXOValue,
                 sPrecioUnitario, sItemText_EN   , sItemText_ES                   ) ;
         END LOOP ;   
--        
         INSERT INTO EAI_OWNER.TMP_DOCUMENT_HEADER
            ( ReferenceID   , Cust_to_SAP  , Bill_to_SAP   , Ship_to_SAP    ,
              ShippingPoint , DeliveryType , FacturaSAP    , PedidoSAP      , 
              PedidoV3      , Valor_Subt   , Valor_IVA     , DocumentDate   ,
              Moneda        , RFC          , Tipo_Cambio   , CondicionPago  ,
              Pais          , NombreCliente, Ciudad        , Colonia        ,
              CodigoPostal  , Estado       , Direccion     , MetodoPago     ,
              Fecha_Vencimiento            , Created       ,
              CompanyCode   , OrgVentas    , ReferenciaBancaria              )
         VALUES
            ( sReferenceID  , sClienteSAP  , sCteFacturaSAP, sCteEntregaSAP ,
              sCentro       , sClaseFactura, sFacturaV3    , sPedidoSAP     ,
              sPedidoV3     , sValor_Subt  , sValor_IVA    , 
              sFechaFactura || ' ' || sHoraFactura,
              sCurrency     , sRFC         , sRate         , sPaymentTerms  ,
              sCountry      , sPartnerName , sCity         , sDistrict      ,
              sPostalCode   , sRegion      , sAddress      , sPaymentMethod ,
              sFechaVencimiento            , SYSDATE       ,
              sCompanyCode  , sOrgVentas   , sBankReference                  ) ;
      ELSE
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'NO Procesado' ) ;   
         END IF ;    
      END IF ;   
   END LOOP ;   

   nA51 := 0 ;
   FOR Cte IN ScrA51 LOOP
      nA51      := nA51 + 1 ;
      sDOC_TYPE := 'PR'     ;
   END LOOP ;
   IF ( nA51 = 0 ) THEN
      SELECT EAI_OWNER.FN_GET_DOC_TYPE( sPedidoV3 ) INTO sDOC_TYPE
         FROM DUAL ; 
   END IF ;      
--   
   IF ( sDOC_TYPE = 'VD' ) THEN
      sProcesar     := 'VD'   ;
      sClaseFactura := 'C003' ;
   END IF ;
   IF ( sPartnerName = 'DebitNote' ) THEN
      sProcesar     := 'SI' ;
   END IF ;
   IF ( SUBSTR( sCompanyCode, 1, 2 ) != 'MX' ) THEN 
      sProcesar := 'DI'   ;
   END IF ;
   -- Nota de Credito
   IF ( sClaseFactura = 'Discard' ) THEN
      sProcesar := 'CN'   ;
--      UPDATE EAI_Owner.MX_PRESALES_DOCS SET CreditNote = sReferenceID, CreditNote_1180 = SYSDATE
--         WHERE Order_Num = sPedidoV3 ;
   END IF ;
--   
   UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE     , 
                                               Reference = sReferenceID,
                                               Status    = DECODE( sProcesar, 'SI', 'Processed', 
                                                                              'VD', 'Processed',
                                                                              'NA', 'NotApply' ,
                                                                              'ED', 'CheckData',
                                                                              'CN', 'ConfirmCN',
                                                                              'DI', 'Reject' || sCompanyCode,
                                                                                    'Review' )
      WHERE Row_ID = sROW_ID ;
   IF ( nOutput > 0 ) THEN   
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'Procesar      -> ' || sProcesar      ) ;   
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'ClaseFactura  -> ' || sClaseFactura  ) ;   
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'SalesDoc_Type -> ' || sSalesDoc_Type ) ;   
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'PedidoV3      -> ' || sPedidoV3      ) ;
   END IF ;   
   IF ( sProcesar = 'SI' ) THEN   
      IF ( sTipoDocV3 = 'DN' ) THEN                                    -- Debit Note a V3 
         sPedidoV3 := REPLACE( sPedidoV3, ' ', '_' ) ;
         UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET PedidoV3 = sPedidoV3
            WHERE ReferenceID = sReferenceID ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'DEBITNOTE_TO_IFC( ' || sReferenceID || ' )' ) ;   
         END IF ;
         EAI_OWNER.DEBITNOTE_TO_IFC( sReferenceID ) ;
      ELSE                                                   -- Enviar a Preventa
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'INVOICE_TO_PREVENTA( ' || sReferenceID || ' )' ) ;   
         END IF ;
         EAI_OWNER.INVOICE_TO_PREVENTA( sReferenceID, sFolioFiscalDoc ) ;
      END IF ;
   ELSIF ( sProcesar = 'VD' ) THEN
      IF ( nOutput > 0 ) THEN
         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
            VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'INVOICE_TO_FACTURA( ' || sReferenceID || ' )' ) ;   
      END IF ;
      EAI_OWNER.INVOICE_TO_FACTURA( sReferenceID, sFolioFiscalDoc ) ;  
   END IF ;
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'SF_PROC_PREINVOICE_IFC', sRow_ID, 'End' ) ;   
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        , JOB_PID,
	        STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sReferenceID         , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_PREINVOICE_IFC', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_PREINVOICE_IFC ;
--