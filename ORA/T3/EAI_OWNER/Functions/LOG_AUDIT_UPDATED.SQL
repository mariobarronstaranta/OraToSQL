create or replace FUNCTION           "LOG_AUDIT_UPDATED" 
  ( sObjectName  IN VARCHAR2,
    sActionMode  IN VARCHAR2,
    sROWID       IN VARCHAR2,
    sReturnType  IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn              VARCHAR2(2000) ;
   sReferenceKey        VARCHAR2(2000) ;
   sReferenceUpdate     VARCHAR2(2000) ;
   CURSOR ScrPriceList IS
       SELECT * FROM T3.PRICELIST_DETALLE_LOG
          WHERE ROWID = sROWID ;
   CURSOR ScrCDI_Product IS
       SELECT * FROM EAI_OWNER.MX_CFDI_PRODSERV_LOG
          WHERE ROWID = sROWID ;
   CURSOR ScrHashtable IS
       SELECT * FROM EAI_OWNER.MX_HASHTABLE_LOG
          WHERE ROWID = sROWID ;
   CURSOR ScrCFDI_Customer IS
       SELECT * FROM EAI_OWNER.MX_USOCFDI_CLIENTE_LOG
          WHERE ROWID = sROWID ;
   CURSOR ScrHawaCondition IS
       SELECT * FROM EAI_OWNER.MX_CONDITION_HAWA_LOG
          WHERE ROWID = sROWID ;          
   CURSOR ScrOtrosDetalle IS
       SELECT * FROM T3.OTROS_DETALLE_LOG
          WHERE ROWID = sROWID ;          
--   
BEGIN
   sReferenceKey    := '' ;
   sReferenceUpdate := '' ;
   IF ( sObjectName = 'PRICELIST_DETALLE_LOG' ) THEN
      FOR Reg IN ScrPriceList LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Old_PriceListID || '-' || Reg.Old_Matnr || '-' || Reg.Old_Effective ;
          ELSE
             sReferenceKey := Reg.New_PriceListID || '-' || Reg.New_Matnr || '-' || Reg.New_Effective ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_PriceListID, 'Empty' ) != NVL( Reg.New_PriceListID, 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'PLID:'       || NVL( Reg.Old_PriceListID, 'Empty' ) || '->' || NVL( Reg.New_PriceListID, 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Effective  , 'Empty' ) != NVL( Reg.New_Effective  , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Effective:'  || NVL( Reg.Old_Effective  , 'Empty' ) || '->' || NVL( Reg.New_Effective  , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Expiration , 'Empty' ) != NVL( Reg.New_Expiration , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Expiration:' || NVL( Reg.Old_Expiration , 'Empty' ) || '->' || NVL( Reg.New_Expiration  , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_MATNR      , 'Empty' ) != NVL( Reg.New_MATNR      , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SKU:'        || NVL( Reg.Old_MATNR      , 'Empty' ) || '->' || NVL( Reg.New_MATNR       , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Value      , 0       ) != NVL( Reg.New_Value      , 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Price:'      || NVL( Reg.Old_Value      , 0       ) || '->' || NVL( Reg.New_Value       , 0       ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Costo_Envio, 0       ) != NVL( Reg.New_Costo_Envio, 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Route66:'    || NVL( Reg.Old_Costo_Envio, 0       ) || '->' || NVL( Reg.New_Costo_Envio , 0       ) || '. ' ; 
              END IF ;
          END IF ;
      END LOOP ;
   ELSIF ( sObjectName = 'MX_CFDI_PRODSERV_LOG' ) THEN
      FOR Reg IN ScrCDI_Product LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Old_Modulo || '-' || Reg.Old_Material ;
          ELSE
             sReferenceKey := Reg.New_Modulo || '-' || Reg.New_Material ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_Modulo          , 'Empty' ) != NVL( Reg.New_Modulo         , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Module:'     || NVL( Reg.Old_Modulo          , 'Empty' ) || '->' || NVL( Reg.New_Modulo          , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Material        , 'Empty' ) != NVL( Reg.New_Material       , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SKU:'        || NVL( Reg.Old_Material        , 'Empty' ) || '->' || NVL( Reg.New_Material        , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_NombreMaterial  , 'Empty' ) != NVL( Reg.New_NombreMaterial , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Name:'       || NVL( Reg.Old_NombreMaterial  , 'Empty' ) || '->' || NVL( Reg.New_NombreMaterial  , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_UnidadMedida    , 'Empty' ) != NVL( Reg.New_UnidadMedida   , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'UoM:'        || NVL( Reg.Old_UnidadMedida    , 'Empty' ) || '->' || NVL( Reg.New_UnidadMedida    , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_SAT_Clave       , 'Empty' ) != NVL( Reg.New_SAT_Clave      , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SAT ID:'     || NVL( Reg.Old_SAT_Clave       , 'Empty' ) || '->' || NVL( Reg.New_SAT_Clave       , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_SAT_UnidadMedida, 'Empty' ) != NVL( Reg.New_SAT_UnidadMedida, 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SAT UoM:'    || NVL( Reg.Old_SAT_UnidadMedida, 'Empty' ) || '->' || NVL( Reg.New_SAT_UnidadMedida, 'Empty' ) || '. ' ; 
              END IF ;
          END IF ;    
      END LOOP ;    
   ELSIF ( sObjectName = 'MX_HASHTABLE_LOG' ) THEN
      FOR Reg IN ScrHashtable LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Old_Type || '-' || Reg.Old_Source ;
          ELSE
             sReferenceKey := Reg.New_Type || '-' || Reg.New_Source ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_Type            , 'Empty' ) != NVL( Reg.New_Type           , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Type:'       || NVL( Reg.Old_Type            , 'Empty' ) || '->' || NVL( Reg.New_Type            , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Source          , 'Empty' ) != NVL( Reg.New_Source         , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Source:'     || NVL( Reg.Old_Source          , 'Empty' ) || '->' || NVL( Reg.New_Source          , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Target          , 'Empty' ) != NVL( Reg.New_Target         , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Target:'     || NVL( Reg.Old_Target          , 'Empty' ) || '->' || NVL( Reg.New_Target          , 'Empty' ) || '. ' ; 
              END IF ;
          END IF ;    
      END LOOP ;
   ELSIF ( sObjectName = 'MX_USOCFDI_CLIENTE_LOG' ) THEN
      FOR Reg IN ScrCFDI_Customer LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Old_Cliente ;
          ELSE
             sReferenceKey := Reg.New_Cliente ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_Cliente         , 'Empty' ) != NVL( Reg.New_Cliente        , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Customer:'     || NVL( Reg.Old_Cliente         , 'Empty' ) || '->' || NVL( Reg.New_Cliente         , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Uso_Vta         , 'Empty' ) != NVL( Reg.New_Uso_Vta        , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Sale Usage:'   || NVL( Reg.Old_Uso_Vta         , 'Empty' ) || '->' || NVL( Reg.New_Uso_Vta         , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Uso_Dev         , 'Empty' ) != NVL( Reg.New_Uso_Dev        , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Return Usage:' || NVL( Reg.Old_Uso_Dev         , 'Empty' ) || '->' || NVL( Reg.New_Uso_Dev         , 'Empty' ) || '. ' ; 
              END IF ;
          END IF ;    
      END LOOP ;          
   ELSIF ( sObjectName = 'MX_CONDITION_HAWA_LOG' ) THEN
      FOR Reg IN ScrHawaCondition LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Old_LP || '-' || Reg.Old_SKU ;
          ELSE
             sReferenceKey := Reg.New_LP || '-' || Reg.New_SKU ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_LP              , 'Empty' ) != NVL( Reg.New_LP             , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'PriceList:'  || NVL( Reg.Old_LP              , 'Empty' ) || '->' || NVL( Reg.New_LP              , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_SKU             , 'Empty' ) != NVL( Reg.New_SKU            , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SKU:'        || NVL( Reg.Old_SKU             , 'Empty' ) || '->' || NVL( Reg.New_SKU             , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Cond            , 'Empty' ) != NVL( Reg.New_Cond           , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Condition:'  || NVL( Reg.Old_Cond            , 'Empty' ) || '->' || NVL( Reg.New_Cond            , 'Empty' ) || '. ' ; 
              END IF ;
          END IF ;    
      END LOOP ;                
   ELSIF ( sObjectName = 'OTROS_DETALLE_LOG' ) THEN
      FOR Reg IN ScrOtrosDetalle LOOP
          IF ( sActionMode = 'Delete' ) THEN
             sReferenceKey := Reg.Factura || '-' || Reg.Num_Linea ;
          ELSE
             sReferenceKey := Reg.Factura || '-' || Reg.Num_Linea ;
          END IF ;
          IF ( sActionMode = 'Update' ) THEN
              IF ( NVL( Reg.Old_Material           , 'Empty' ) != NVL( Reg.New_Material       , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SKU:'        || NVL( Reg.Old_Material              , 'Empty' ) || '->' || NVL( Reg.New_Material           , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_MaterialDescripcion, 'Empty' ) != NVL( Reg.New_MaterialDescripcion     , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Name:'       || NVL( Reg.Old_MaterialDescripcion   , 'Empty' ) || '->' || NVL( Reg.New_MaterialDescripcion, 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_UnidadMedida       , 'Empty' ) != NVL( Reg.New_UnidadMedida            , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'UoM:'        || NVL( Reg.Old_UnidadMedida          , 'Empty' ) || '->' || NVL( Reg.New_UnidadMedida       , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_SAT_ProdID         , 'Empty' ) != NVL( Reg.New_SAT_ProdID              , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SAT ID:'     || NVL( Reg.Old_SAT_ProdID            , 'Empty' ) || '->' || NVL( Reg.New_SAT_ProdID         , 'Empty' ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_SAT_UM             , 'Empty' ) != NVL( Reg.New_SAT_UM                  , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'SAT UoM:'    || NVL( Reg.Old_SAT_UM                , 'Empty' ) || '->' || NVL( Reg.New_SAT_UM             , 'Empty' ) || '. ' ; 
              END IF ;
--              
              IF ( NVL( Reg.Old_Cantidad           , 0       ) != NVL( Reg.New_Cantidad         , 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Qty:'      || NVL( Reg.Old_Cantidad      , 0       ) || '->' || NVL( Reg.New_Cantidad      , 0       ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_PrecioUnitario     , 0       ) != NVL( Reg.New_PrecioUnitario   , 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Price:'    || NVL( Reg.Old_PrecioUnitario, 0       ) || '->' || NVL( Reg.New_PrecioUnitario, 0       ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Valor_Subt         , 0       ) != NVL( Reg.New_Valor_Subt       , 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Subt:'     || NVL( Reg.Old_Valor_Subt    , 0       ) || '->' || NVL( Reg.New_Valor_Subt    , 0       ) || '. ' ; 
              END IF ;
              IF ( NVL( Reg.Old_Valor_IVA          , 0       ) != NVL( Reg.New_Valor_IVA        , 0       ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Tax:'      || NVL( Reg.Old_Valor_IVA     , 0       ) || '->' || NVL( Reg.New_Valor_IVA     , 0       ) || '. ' ; 
              END IF ;
--              
              IF ( NVL( Reg.Old_Leyenda_EN         , 'Empty' ) != NVL( Reg.New_Leyenda_EN              , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Text Leyend' ; 
              END IF ;
              IF ( NVL( Reg.Old_Leyenda_ES         , 'Empty' ) != NVL( Reg.New_Leyenda_ES              , 'Empty' ) ) THEN
                 sReferenceUpdate := sReferenceUpdate || 'Text Leyend' ; 
              END IF ;
          END IF ;    
      END LOOP ;                
   END IF ;   
   IF ( sReturnType = 'PK' ) THEN
      sReturn := sReferenceKey    ; 
   ELSE
      sReturn := sReferenceUpdate ;
   END IF ;
   RETURN ( sReturn ) ;
--
END LOG_AUDIT_UPDATED ;