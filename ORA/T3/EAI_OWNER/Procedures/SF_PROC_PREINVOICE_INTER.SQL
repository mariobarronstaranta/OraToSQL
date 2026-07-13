create or replace PROCEDURE           SF_PROC_PREINVOICE_INTER
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
   sEntregaSAP         VARCHAR2(030) ; 
   sCurrency           VARCHAR2(030) ;
   sCurrencyDoc        VARCHAR2(030) ;
   sCurrencyLocal      VARCHAR2(030) ;
   sRFC                VARCHAR2(030) ;
   sNIF                VARCHAR2(030) ;
   sRate               VARCHAR2(050) ;   
   sPaymentTerms       VARCHAR2(050) ;
   sAssignment         VARCHAR2(050) ;
   sClienteSAP         VARCHAR2(050) ;
   sCteEntregaSAP      VARCHAR2(050) ;
   sCteFacturaSAP      VARCHAR2(050) ;
   sFacturaV3          VARCHAR2(050) ;
   sFechaFactura       VARCHAR2(050) ;
   sFechaVencimiento   VARCHAR2(010) ;
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
   sMaterial           VARCHAR2(050) ; 
   sMatDescription     VARCHAR2(050) ; 
   sPrecioUnitario     VARCHAR2(050) ; 
   sDetValor_Subt      VARCHAR2(050) ; 
   sDetValor_IVA       VARCHAR2(050) ; 
   sDetBonif_Subt      VARCHAR2(050) ;
   sCondZFSIValue      VARCHAR2(050) ;
   sCondZFSISign       VARCHAR2(050) ;
   sPaymentMethod      VARCHAR2(200) ;
   sBankReference      VARCHAR2(200) ;
   sComments           VARCHAR2(500) ;
   sIncoterms          VARCHAR2(200) ;
   sQualifier          VARCHAR2(080) ;
   sLanguage           VARCHAR2(080) ;
   sTextLine           VARCHAR2(4000) ;
   sItemText_ES        VARCHAR2(4000) ;
   sItemText_EN        VARCHAR2(300) ;
   nItems              NUMBER(04)    ;
   nTaxFactor          NUMBER(04)    ;
   itemXML             XMLTYPE       ; 
   itemTextos          XMLTYPE       ;
   sTipoDocV3          VARCHAR2(04)  ;
   sFolioFiscalDoc     VARCHAR2(030) ;
   sStateAux           VARCHAR2(040) ;
   sStateName          VARCHAR2(040) ;
   sSalesDoc_Type      VARCHAR2(030) ;
   sCustomerRep        VARCHAR2(030) ;
--
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/DocumentNumber'  )            AS ReferenceID   ,  
            extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/Currency'        )            AS Currency      ,
            extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/RFC'             )            AS RFC           ,
--          extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/V3DocumentNumber')            AS RFC           ,
            extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/Rate'            )            AS Rate          ,
            extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/PaymentTerms'    )            AS PaymentTerms
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
           TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/InvoicePartner' ) ) ) Lista
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
           TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/HeaderConditions' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;      
--
   CURSOR ScrReferenceData IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier' ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Document'  ) AS RefDocument , 
             ExtractValue( VALUE( Lista ), '*/Date'      ) AS RefDate     ,
             ExtractValue( VALUE( Lista ), '*/Time'      ) AS RefTime
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/ReferenceData' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrHeaderDate IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier' ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Date'      ) AS RefValue
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/Invoice/Message/HeaderDate' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;   
--      
   CURSOR ScrOrganizationData IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier'    ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/Organization' ) AS RefValue
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/OrganizationData' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
   CURSOR ScrSummaryGeneral IS
      SELECT ExtractValue( VALUE( Lista ), '*/Qualifier'    ) AS RefQualifier,
             ExtractValue( VALUE( Lista ), '*/ValueSummary' ) AS RefValue    
      FROM EAI_Owner.MX_Receive_Message_Log Msg,
           TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/SummaryGeneral' ) ) ) Lista
      WHERE Msg.Row_ID = sRow_ID ;
--
    CURSOR ScrHeaderText IS
       SELECT VALUE( Lista ) AS Item_Content
       FROM EAI_Owner.MX_Receive_Message_Log Msg,
            TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/TextIdentification' ) ) ) Lista
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
            TABLE( XMLSequence( Extract ( XML_Content, '/InvoiceIntercompany/Message/ItemData' ) ) ) Lista
       WHERE Msg.Row_ID = sRow_ID ;    
--
   CURSOR ScrItemID IS
      SELECT ExtractValue( VALUE( Lista ), '*/MaterialID'           ) AS RefMaterialID ,
             ExtractValue( VALUE( Lista ), '*/ObjectIdentification' ) AS RefQualifier  ,
             ExtractValue( VALUE( Lista ), '*/ShortText'            ) AS RefDescription,
             ExtractValue( VALUE( Lista ), '*/PartNumber'           ) AS RefPartNumber ,
--
             ExtractValue( VALUE( Lista ), '*/MaterialDescription'  ) AS RefDescriptionAnt
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
   CURSOR ScrItemTaxTerms IS
      SELECT ExtractValue( VALUE( Lista ), '*/TaxConditionValue'     ) AS TaxValueAomunt  ,
             ExtractValue( VALUE( Lista ), '*/TaxConditionType'      ) AS TaxQualifier    ,
             ExtractValue( VALUE( Lista ), '*/TaxConditionIndicator' ) AS TaxConditionType
      FROM DUAL,
           TABLE( XMLSequence( Extract ( itemXML, '/ItemData/ItemTaxTerms' ) ) ) Lista ;
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
BEGIN
   sTipoDocV3 := 'NO' ;  
   sPaymentMethod := '' ;
   sBankReference := '' ;
   sComments      := '' ;
   sIncoterms     := '' ;
   sAssignment    := '' ;
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
         -- WA para Moneda   
         sCurrencyDoc   := EAI_Owner.CURRENCY_TEXT( Rec.Currency, 'Doc'   ) ;
         sCurrencyLocal := EAI_Owner.CURRENCY_TEXT( Rec.Currency, 'Local' ) ;
         sCurrency      := sCurrencyDoc       ;    
         sRFC           := Rec.RFC            ;
         sRate          := Rec.Rate           ;
         sPaymentTerms  := Rec.PaymentTerms   ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_HEADER      WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL      WHERE ReferenceID = sReferenceID ; 
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_CONDITIONS  WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS    WHERE ReferenceID = sReferenceID ;
         DELETE FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND WHERE ReferenceID = sReferenceID ;
      -- Partners
         FOR Scr IN ScrPartners LOOP
             IF    ( Scr.FunctionID = 'AG' ) THEN
                 sClienteSAP    := Scr.PartnerID    ;
             --  sCountry       := Scr.Country      ;
             --  sPartnerName   := Scr.PartnerName  ;
             --  sCity          := Scr.City         ;
             --  sDistrict      := Scr.District     ;
             --  sPostalCode    := Scr.PostalCode   ;
             --  sRegion        := Scr.Region       ;
             --  sAddress       := Scr.Address      ;
--
                 sSold_Customer := Scr.PartnerID    ;
                 sSold_Name     := Scr.PartnerName  ;
                 sSold_Address  := Scr.Address      ;
                 sSold_District := Scr.District     ;
                 sSold_City     := Scr.City         ;
                 sSold_State    := Scr.Region       ;
                 sSold_Country  := Scr.Country      ;
                 sSold_ZipCode  := Scr.PostalCode   ;
             ELSIF ( Scr.FunctionID = 'RE' ) THEN
                 sCteFacturaSAP := Scr.PartnerID    ;
             --
                 sCountry       := Scr.Country      ;
                 sPartnerName   := Scr.PartnerName  ;
                 sCity          := Scr.City         ;
                 sDistrict      := Scr.District     ;
                 sPostalCode    := Scr.PostalCode   ;
                 sRegion        := Scr.Region       ;
                 sAddress       := Scr.Address      ;             
             --    
                 sBill_Customer := Scr.PartnerID    ;
                 sBill_Name     := Scr.PartnerName  ;
                 sBill_Address  := Scr.Address      ;
                 sBill_District := Scr.District     ;
                 sBill_City     := Scr.City         ;
                 sBill_State    := Scr.Region       ;
                 sBill_Country  := Scr.Country      ;
                 sBill_ZipCode  := Scr.PostalCode   ;
             ELSIF ( Scr.FunctionID = 'WE' ) THEN
                 sCteEntregaSAP := Scr.PartnerID ;
                 sShip_Customer := Scr.PartnerID    ;
                 sShip_Name     := Scr.PartnerName  ;
                 sShip_Address  := Scr.Address      ;
                 sShip_District := Scr.District     ;
                 sShip_City     := Scr.City         ;
                 sShip_State    := Scr.Region       ;
                 sShip_Country  := Scr.Country      ;
                 sShip_ZipCode  := Scr.PostalCode   ;
             END IF ;
         END LOOP ;
      -- Reference Data
         FOR Scr IN ScrReferenceData LOOP
            IF    ( Scr.RefQualifier = '001' ) THEN
               sPedidoV3     := Scr.RefDocument ;
            ELSIF ( Scr.RefQualifier = '002' ) THEN
               sPedidoSAP    := Scr.RefDocument ;
            ELSIF ( Scr.RefQualifier = '009' ) THEN
               sFechaFactura := Scr.RefDate     ;
               sHoraFactura  := Scr.RefTime     ;
            ELSIF ( Scr.RefQualifier = '028' ) THEN
               sFechaVencimiento := Scr.RefDate ;
            ELSIF ( Scr.RefQualifier = '017' ) THEN
               sFacturaV3    := Scr.RefDocument ;
            ELSIF ( Scr.RefQualifier = '012' ) THEN
               sEntregaSAP   := Scr.RefDocument ;
            END IF ;
         END LOOP ;
      -- Header Date
         FOR Scr IN ScrHeaderDate LOOP
            IF    ( Scr.RefQualifier = '028' ) THEN
               sFechaVencimiento := Scr.RefValue ;
            END IF ;
         END LOOP ;          
      -- Organization Data
         FOR Scr IN ScrOrganizationData LOOP
            IF    ( Scr.RefQualifier = '008' ) THEN
               sOrgVentas    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '003' ) THEN
               sCompanyCode  := Scr.RefValue ;
               sOrgVentas    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '017' ) THEN   
               sAssignment   := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '015' ) THEN
               IF ( Scr.RefValue = 'Nota de Venta' ) THEN
                  sClaseFactura := 'C005' ;
               ELSIF ( Scr.RefValue = 'Payable' ) THEN
                  sClaseFactura := 'C006' ;
               ELSIF ( Scr.RefValue = 'IV' ) THEN
                  sClaseFactura := 'IV' ;
               ELSIF ( Scr.RefValue = 'ZI01' ) THEN                             -- BAT Billing ( RRB PO )
                  sClaseFactura := 'ZI01' ;
               ELSIF ( Scr.RefValue = 'ZI03' ) THEN                             -- BAT Billing ( RRB NonPO )
                  sClaseFactura := 'ZI03' ;
               ELSIF ( Scr.RefValue = 'ZI06' ) THEN                             -- BAT CR ( RRB PO )  
                  sClaseFactura := 'ZI06' ;
               ELSIF ( Scr.RefValue = 'ZI02' ) THEN                             -- Anulacion ( RRB PO )  
                  sClaseFactura := 'ZI02' ;
               ELSIF ( Scr.RefValue = 'ZI04' ) THEN                             -- Anulacion ( RRB NonPO )  
                  sClaseFactura := 'ZI04' ;
               ELSIF ( Scr.RefValue = 'ZF2' ) THEN
                  sClaseFactura := 'ZF2' ;
               ELSIF ( Scr.RefValue = 'ZL' ) THEN                               -- Factura Activa Fijo
                  sClaseFactura := 'ZL' ;
               ELSIF ( Scr.RefValue = 'IVS' ) THEN                              -- Anulacion de Factura
                  sClaseFactura := 'IVS' ;
               ELSIF ( Scr.RefValue = 'ZIG2' ) THEN                             -- CM Value Interocopany ( Z021 )
                sClaseFactura := 'C021'       ;                      
--              sClaseFactura := 'ZIG2'       ;                      
               ELSIF ( Scr.RefValue = 'ZG'   ) THEN                             -- CM Value Interocopany ( Z022 )
                  sClaseFactura := 'C022'       ;    
--                IF ( SUBSTR( sCteFacturaSAP, 1, 3 ) != 'IC-' ) THEN
                  IF ( sCteFacturaSAP != 'IC-00-MX16' ) THEN
                      sClaseFactura := 'ZG' ;
                  END IF ;                  
--                sClaseFactura := 'ZG'         ;                      
               END IF ;
            END IF ;
         END LOOP ;
      -- Summary General
         FOR Scr IN ScrSummaryGeneral LOOP
            IF    ( Scr.RefQualifier = '005' ) THEN
               sValor_IVA    := Scr.RefValue ;
            ELSIF ( Scr.RefQualifier = '010' ) THEN
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
         --DBMS_OUTPUT.PUT_LINE( 'Before ScrHeaderText' ) ;
         FOR Item IN ScrHeaderText LOOP
            itemTextos := Item.Item_Content ;
            nItems     := nItems + 1        ;
            SELECT   ExtractValue( Item.Item_Content, '/TextIdentification/TextID'    )   AS sQualifier   ,
                     ExtractValue( Item.Item_Content, '/TextIdentification/Language'  )   AS sLanguage
               INTO sQualifier, sLanguage
               FROM DUAL ;
            IF ( sLanguage = 'ES' ) THEN
               FOR TxtLine IN ScrHeaderTextLine LOOP
                  IF    ( sQualifier = 'Z048' ) THEN
--                   sPaymentMethod := sPaymentMethod || TxtLine.TextLine ;
                     sPaymentMethod := SUBSTR( sPaymentMethod || TxtLine.TextLine, 1, 80 ) ;
                  ELSIF ( sQualifier = 'Z024' ) THEN  
--                   sBankReference := sBankReference || TxtLine.TextLine ;
                     sBankReference := SUBSTR( sBankReference || TxtLine.TextLine, 1, 80 ) ;
                  ELSIF ( sQualifier = 'Z021' ) THEN  
--                   sComments      := sComments      || TxtLine.TextLine ;
                     sComments      := SUBSTR( sComments || TxtLine.TextLine, 1, 495 ) ;
                  ELSIF ( sQualifier = 'INCO1' ) THEN  
                     sIncoterms     := sIncoterms     || TxtLine.TextLine ;
                  ELSIF ( sQualifier = 'INCO2' ) THEN  
                     sIncoterms     := sIncoterms || ' ' || TxtLine.TextLine ;
                  END IF ;
                  --DBMS_OUTPUT.PUT_LINE( sQualifier || '->' || TxtLine.TextLine ) ;
               END LOOP ;
            END IF ;   
         END LOOP ;
--         
         -- Workaround for Intercompany Invoicing
         IF ( ( sClaseFactura = 'IV' ) AND ( SUBSTR( sClienteSAP, 1, 8) = 'PC-00-MX' ) ) THEN
            sClaseFactura := 'C020' ;
         END IF ;
         sNIF := sRFC ;
         IF ( sCountry != 'MX' ) THEN
            sRFC := 'XEXX010101000' ;
         END IF ;
--
-- Workaround for Country and State
         sStateAux := sCountry || '-' || sRegion ;  
         SELECT EAI_Owner.GETCONV( 'ECC_T3 Country', sCountry  ) INTO  sCountry
            FROM DUAL ;
         SELECT EAI_Owner.GETCONV( 'ECC_T3 State'  , sStateAux ) INTO  sStateName
            FROM DUAL ;
         IF ( sStateAux != sStateName ) THEN
            sRegion := sStateName ; 
         END IF ;
--      
         IF ( nOutput > 0 ) THEN
             DBMS_Output.Put_Line( 'Document Header' ) ;
             DBMS_Output.Put_Line( 'ReferenceID     => ' || sReferenceID      ) ;
             DBMS_Output.Put_Line( 'FacturaSAP      => ' || sFacturaSAP       ) ;
             DBMS_Output.Put_Line( 'EntregaSAP      => ' || sEntregaSAP       ) ;
             DBMS_Output.Put_Line( 'Currency        => ' || sCurrency         ) ;
             DBMS_Output.Put_Line( 'RFC             => ' || sRFC              ) ;
             DBMS_Output.Put_Line( 'NIF             => ' || sNIF              ) ;
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
             DBMS_Output.Put_Line( 'Comments        => ' || sComments         ) ;
             DBMS_Output.Put_Line( 'Incoterms       => ' || sIncoterms        ) ;
             DBMS_Output.Put_Line( '------------------' ) ;             
--             
             DBMS_Output.Put_Line( 'Assignment      => ' || sAssignment       ) ;
             DBMS_Output.Put_Line( 'FacturaV3       => ' || sFacturaV3        ) ;
             DBMS_Output.Put_Line( 'FechaFactura    => ' || sFechaFactura     ) ;
             DBMS_Output.Put_Line( 'FechaVence      => ' || sFechaVencimiento ) ;
             DBMS_Output.Put_Line( 'HoraFactura     => ' || sHoraFactura      ) ;
             DBMS_Output.Put_Line( 'PedidoSAP       => ' || sPedidoSAP        ) ;
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
                  sDetValor_Subt  := '' ;
                  sPrecioUnitario := '' ;
                  sDetBonif_Subt  := '' ;
                  sDetValor_IVA   := '' ;           
--         
            itemXML := Item.Item_Content ;
            nItems  := nItems + 1        ;
            SELECT   ExtractValue( Item.Item_Content, '/ItemData/ItemNumber'    )   AS NumLinea     ,
                     ExtractValue( Item.Item_Content, '/ItemData/Quantity'      )   AS CantidadVta  ,
                     ExtractValue( Item.Item_Content, '/ItemData/UnitOfMeasure' )   AS UnidadMedVta ,
                     ExtractValue( Item.Item_Content, '/ItemData/Plant'         )   AS Centro
               INTO sNumLinea, sCantidadVta, sUnidadMedVta, sCentro
               FROM DUAL ;
            SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', sUnidadMedVta )  INTO  sUnidadMedVta
               FROM DUAL ;
--          Workaround for UOM in Preventa_Detalle
            IF ( ( sUnidadMedVta = 'CASES' ) AND ( sCteFacturaSAP = 'IC-00-MX16' ) ) THEN
               sUnidadMedVta := SUBSTR( sUnidadMedVta, 1, 3 ) ; 
               sUnidadMedVta := 'CTN' ; 
            END IF ;
--            
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
               IF    ( Scr.ItemCondType = 'ZFSI' ) THEN
                  sCondZFSISign  := Scr.ItemCondSign  ;
                  sCondZFSIValue := Scr.ItemCondValue ;
               END IF ;          
            END LOOP ; 
--           
            FOR Tax IN ScrItemTaxTerms LOOP
               nTaxFactor := 1 ; 
               IF ( Tax.TaxConditionType = '-' ) THEN
                   nTaxFactor := -1 ;
               END IF ;
               IF ( LENGTH( NVL( Tax.TaxQualifier, ' ' ) ) > 1 ) THEN
                  INSERT INTO EAI_Owner.tmp_Document_Detail_Cond                
                     ( ReferenceID, ItemID, Condition, Amount )
                  VALUES
                     ( sReferenceID, sNumLinea, Tax.TaxQualifier, Tax.TaxValueAomunt * nTaxFactor ) ;
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
                  SELECT   ExtractValue( TxtLine.ItemTextLineSegment, '*/TagColumn'    )   AS sTextLine  
                     INTO sTextLine
                     FROM DUAL ;
                  IF    ( sLanguage = 'ES' ) THEN
                     sItemText_ES := sItemText_ES || NVL( sTextLine, '' ) ;
                  ELSIF ( sLanguage = 'EN' ) THEN  
                     sItemText_EN := sItemText_EN || NVL( sTextLine, '' ) ;
                  END IF ;
               END LOOP ;
            END LOOP ;
             IF ( nOutput > 0 ) THEN
               DBMS_Output.Put_Line( 'Item               = ' || sNumLinea        ) ;
               DBMS_Output.Put_Line( 'Cantidad           = ' || sCantidadVta     ) ;
               DBMS_Output.Put_Line( 'Unidad Vta         = ' || sUnidadMedVta    ) ;
               DBMS_Output.Put_Line( 'Status             = ' || sStatusItem      ) ;
               DBMS_Output.Put_Line( 'Centro             = ' || sCentro          ) ;
               DBMS_Output.Put_Line( 'Material           = ' || sMaterial        ) ;
               DBMS_Output.Put_Line( 'Descripcion        = ' || sMatDescription  ) ;
               DBMS_Output.Put_Line( 'Valor Subt         = ' || sDetValor_Subt   ) ;
               DBMS_Output.Put_Line( 'Valor IVA          = ' || sDetValor_IVA    ) ;
               DBMS_Output.Put_Line( 'Bonif Subt         = ' || sDetBonif_Subt   ) ;
               DBMS_Output.Put_Line( 'Precio Unitario    = ' || sPrecioUnitario  ) ;
               DBMS_Output.Put_Line( 'Leyendas ES/EN     = ' || sItemText_ES || '/' || sItemText_EN ) ;
               DBMS_Output.Put_Line( '-----------------------------------------' ) ;
            END IF ; 
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_DETAIL
               ( ReferenceID    , ItemID         , Material       , Plant        ,
                 Cantidad       , UnidadMedida   , Valor_Subt     , Valor_IVA    ,
                 Bonif_Subt     , Status_Producto, MaterialDescripcion           ,
                 PrecioUnitario , Leyenda_EN     , Leyenda_ES                     )
            VALUES
               ( sReferenceID   , sNumLinea      , sMaterial      , sCentro      ,
                 sCantidadVta   , sUnidadMedVta  , sDetValor_Subt , sDetValor_IVA,
                 sDetBonif_Subt , sStatusItem    , sMatDescription,
                 sPrecioUnitario, sItemText_EN   , sItemText_ES                   ) ;
         END LOOP ;  
--       
         IF ( LENGTH( spedidoV3 ) > 30 ) THEN
            sPedidoV3 := SUBSTR( sPedidoV3, 1, 30) ;
         END IF ;
         INSERT INTO EAI_OWNER.TMP_DOCUMENT_HEADER
            ( ReferenceID   , Cust_to_SAP  , Bill_to_SAP   , Ship_to_SAP    ,
              ShippingPoint , DeliveryType , FacturaSAP    , PedidoSAP      , 
              PedidoV3      , Valor_Subt   , Valor_IVA     , DocumentDate   ,
              Moneda        , RFC          , Tipo_Cambio   , CondicionPago  ,
              Pais          , NombreCliente, Ciudad        , Colonia        ,
              CodigoPostal  , Estado       , Direccion     , MetodoPago     ,
              Observaciones , Incoterms    , NIF           , EntregaSAP     ,
              Fecha_Vencimiento            , Created       , Order_Num      ,
              CompanyCode   , OrgVentas    , ReferenciaBancaria              )
         VALUES
            ( sReferenceID  , sClienteSAP  , sCteFacturaSAP, sCteEntregaSAP ,
              sCentro       , sClaseFactura, sFacturaSAP   , sPedidoSAP     ,
              sPedidoV3     , sValor_Subt  , sValor_IVA    , 
              sFechaFactura || ' ' || sHoraFactura,
              sCurrency     , sRFC         , sRate         , sPaymentTerms  ,
              sCountry      , sPartnerName , sCity         , sDistrict      ,
              sPostalCode   , sRegion      , sAddress      , sPaymentMethod ,
              sComments     , sIncoterms   , sNIF          , sEntregaSAP    ,
              sFechaVencimiento            , SYSDATE       , sFacturaV3     ,
              sCompanyCode  , sOrgVentas   , sBankReference                  ) ;
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
      ELSE
         IF ( nOutput > 0 ) THEN
             DBMS_Output.Put_Line( 'NO PROCESADO' ) ;
         END IF ;    
      END IF ;   
   END LOOP ;    
--   
   UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE     , 
                                               Reference = sReferenceID,
                                               Status    = DECODE( sProcesar, 'SI', 'Processed', 
                                                                              'ED', 'CheckData',
                                                                                    'Review' )
      WHERE Row_ID = sROW_ID ;    
--      
   IF ( sClaseFactura = 'IVS' ) THEN
      sProcesar := 'NO' ;
--    EAI_OWNER.WA_SEARCH_INVOICE_CANCEL( sPedidoSAP, sReferenceID, sFolioFiscalDoc ) ;
      UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER  SET  PedidoV3 = sFolioFiscalDoc
         WHERE ReferenceID = sReferenceID ;
   END IF ;
--   
   IF ( sProcesar = 'SI' ) THEN
      IF ( sClaseFactura IN ( 'C020', 'C021', 'C022' ) ) THEN
         EAI_Owner.INVOICE_TO_PREVENTA( sReferenceID, sFolioFiscalDoc ) ;
      ELSE   
         IF ( SUBSTR( sCompanyCode, 1, 2 ) = 'MX' ) THEN 
            EAI_Owner.INVOICE_TO_OTROS( sReferenceID ) ;
         ELSE
            UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, 
                                                        Status    = 'Reject' || sCompanyCode
               WHERE Row_ID = sROW_ID ;             
         END IF ;
      END IF ;
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE              , CREATED             , MESSAGE        , JOB_PID,
	        STATUS             , QUEUE_NAME             , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT            , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sReferenceID           , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'SF_PROC_PREINVOICE_INTER', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                   , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_PREINVOICE_INTER ;