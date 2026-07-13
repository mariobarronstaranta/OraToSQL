create or replace PROCEDURE           SF_PROC_CUSTOMER_N( sROW_ID VARCHAR2, nROWNUM NUMBER, nPID NUMBER DEFAULT NULL ) IS
   v_ID        VARCHAR2(030) ;
   sRFC        VARCHAR2(040) ;
   sErrorCode  VARCHAR2(500) ;
   sMsg        VARCHAR2(500) ;
   sProcesar   VARCHAR2(002) ;
   sCtro       VARCHAR2(004) ; 
   sFullName   VARCHAR2(100) ;
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/Customer/Message/GeneralData/CustomerNumber'  ) AS SAPCustomer  ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/V3CustomerNumber') AS V3Customer   ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/PaymentTerms'    ) AS MaxCreditDays,
            extractValue( XML_Content, '/Customer/Message/GeneralData/IntegrationID'   ) AS IntegrationID,
--
            extractValue( XML_Content, '/Customer/Message/GeneralData/Country'         ) AS Country      ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/Region'          ) AS Region       ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/Name1'           ) AS Name1        ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/Name2'           ) AS Name2        ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/Name3'           ) AS Name3        ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/Address'         ) AS Address      ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/City'            ) AS City         ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/District'        ) AS District     ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/PostalCode'      ) AS PostalCode   ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/TaxID'           ) AS TaxID            
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;    
BEGIN
   FOR Rec IN ScrData LOOP 
      v_ID      := Rec.V3Customer ;
      IF ( Rec.V3Customer IS NULL ) THEN
         v_ID   := Rec.SAPCustomer ;
      END IF ;
      sProcesar := 'SI'           ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
      END IF ;
      IF ( LENGTH( NVL( Rec.TaxID, 'NULO' ) ) < 10 ) THEN
         sRFC := 'XAXX010101000' ;
      ELSE
         sRFC := Rec.TaxID ; 
      END IF ;
--
      Rec.Name1     := REPLACE( Rec.Name1   , '-amp-', '&' ) ;
      Rec.Name2     := REPLACE( Rec.Name2   , '-amp-', '&' ) ;
      Rec.Name3     := REPLACE( Rec.Name3   , '-amp-', '&' ) ;
      sRFC          := REPLACE( sRFC        , '-amp-', '&' ) ;
      Rec.Address   := REPLACE( Rec.Address , '-amp-', '&' ) ;
      Rec.District  := REPLACE( Rec.District, '-amp-', '&' ) ;
      Rec.City      := REPLACE( Rec.City    , '-amp-', '&' ) ;
--         
      IF ( sProcesar = 'SI' ) THEN
         sFullName := NVL( Rec.Name1, '' ) || NVL( Rec.Name2, '' ) || NVL( Rec.Name3, '' ) ;
         UPDATE T3.Mov_Cliente SET 
                                   Nombre           = Rec.Name1      ,
                                   Alias            = Rec.Name2      ,
                                   Cliente_SAP      = Rec.SAPCustomer,
                                   RFC              = sRFC           ,
                                   Direccion_1      = Rec.Address    ,
                                   Colonia_1        = Rec.District   ,
                                   Ciudad_1         = Rec.City       ,
                                   Estado_1         = Rec.Region     ,
                                   Pais_1           = Rec.Country    ,
                                   Codigo_Postal_1  = Rec.PostalCode ,
                                   Fecha_Proc_BATMD = NULL           ,
                                   Fecha_Syncr      = SYSDATE        
            WHERE Cliente_V3 = v_ID ;             
         IF SQL%NOTFOUND THEN
            INSERT INTO T3.Mov_Cliente
               ( Cliente_V3    , Nombre         , Clasif_Clte   , Tipo_Mov   , Status_Clte,
                 Alias         , Cliente_SAP    , RFC           , Fecha_Syncr,
                 Regimen_Fiscal, Accion         ,
                 Direccion_1   , Ciudad_1       , Colonia_1     , Estado_1   ,
                 Pais_1        , Codigo_Postal_1,
                 Ctro          , Dist_Venta    , Area_Mgr        )
            VALUES
               ( Rec.V3Customer, sFullName      , 'Cliente'     , 1          , 1          ,
                 sFullName     , Rec.SAPCustomer, sRFC          , SYSDATE    ,
                 '0'           , 'I'            , 
                 Rec.Address   , Rec.City       , Rec.District  , Rec.Region ,
                 Rec.Country   , Rec.PostalCode ,
                 EAI_Owner.getConv( 'CFG Settings', 'T3Default Ctro'        ),
                 EAI_Owner.getConv( 'CFG Settings', 'T3Default DistVenta'   ),
                 EAI_Owner.getConv( 'CFG Settings', 'T3Default AreaManager' ) ) ;
            UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Processed', Reference = v_ID
               WHERE Row_ID = sROW_ID ;
         END IF ;
      END IF ;   
   END LOOP ;  
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Error'
         WHERE Row_ID = sROW_ID ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Receive'          , v_ID                  , SYSDATE             , NULL           ,
          'Error'            , 'TaO Customer Inbound', sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_CUSTOMER_N ;