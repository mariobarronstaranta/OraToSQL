create or replace PROCEDURE           INVOICE_TO_OTROS
   ( sInvoiceID   IN   VARCHAR2)
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   sAccnt_ID       VARCHAR2(030) ;
   sProcesar       VARCHAR2(002) ;
   sFacturaV3      VARCHAR2(020) ;
   nBonif_Subt     NUMBER(22,7 ) ;
   nBonif_IVA      NUMBER(22,7 ) ;
   nBonif_Porc     NUMBER(22,7 ) ;
   sUbicacion      VARCHAR2(04)  ;
   sHora_Factura   VARCHAR2(10)  ;
   nPrecioUnitario NUMBER(22,7 ) ;
   sMetodoDePago   VARCHAR2(060) ; 
   sNumCtaPago     VARCHAR2(060) ;
--
   CURSOR ScrValida IS
      SELECT 
          CASE
             WHEN ( Fecha_Proc_BATMD IS NULL ) THEN 'SI'
             ELSE 'NO'
          END      
           AS Procesar   
   FROM T3.Otros_General
   WHERE Factura = sFacturaV3 ;
--
   CURSOR ScrGeneral IS
      SELECT 
             Head.FacturaSAP                             AS Factura            ,
             Head.ShippingPoint                          AS Centro             ,
             Head.ReferenceID                            AS FacturaSAP         ,
             Head.PedidoSAP                              AS PedidoSAP          ,
             Head.CompanyCode                            AS Sociedad           ,
             Head.DeliveryType                           AS Clase_Factura      ,
--           Head.RFC                                    AS RFC                ,
             DECODE( Head.RFC, NULL,
                DECODE( Head.Pais, 'MX', 'XAXX010101000', 
                               'MEXICO', 'XAXX010101000', 'XEXX010101000' ),
                Head.RFC )                               AS RFC                ,
             Head.NIF                                    AS NIF                ,                
             Head.Moneda                                 AS Moneda             ,
             Head.Tipo_Cambio                            AS TipoCambio         ,
             Head.CondicionPago                          AS CondicionPagoxConv ,
             0                                           AS CondicionPAgo      ,
             Head.Valor_Subt                             AS Valor_Subt         ,
             Head.Valor_IVA                              AS Valor_IVA          ,
             TO_DATE( SUBSTR( Head.DocumentDate, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Factura      ,
             SYSDATE                                     AS Fecha_Trn          , 
             NULL                                        AS Fecha_Proc_BATMD   ,
             NULL                                        AS Fecha_Cancelacion  ,
             Head.Cust_to_SAP                            AS Cliente_SAP        ,
             Head.Bill_to_SAP                            AS Clte_Factura_SAP   , 
             Head.NombreCliente                          AS Nombre             ,
             Head.Direccion                              AS Direccion          ,
             Head.Colonia                                AS Colonia            ,
             Head.Ciudad                                 AS Ciudad             ,
             Head.Estado                                 AS Estado             ,             
--           Head.Pais                                   AS Pais               ,
             EAI_Owner.GETCONV( 'ECC_T3 Country', 
                 Head.Pais )                             AS Pais               ,
             Head.CodigoPostal                           AS CodigoPostal       ,
--           Head.MetodoPago                             AS MetodoPago         ,
--           Head.ReferenciaBancaria                     AS ReferenciaBancaria ,
             NVL( Head.MetodoPago, 'No identificado' ) 
                                                         AS MetodoPago         ,
             NVL( Head.ReferenciaBancaria, 'No identificado' ) 
                                                         AS ReferenciaBancaria ,
             Head.Observaciones                          AS Observaciones      ,
--           Head.Incoterms                              AS Incoterms          ,
             DECODE( Head.Pais, 'MX', '', 
                            'MEXICO', '', Head.Incoterms )
                                                         AS Incoterms          ,
             SUBSTR( Head.DocumentDate, 10, 2 ) || ':' ||
             SUBSTR( Head.DocumentDate, 12, 2 ) || ':' ||
             SUBSTR( Head.DocumentDate, 14, 2 )          AS Hora_Factura       ,
             TO_CHAR( SYSDATE, 'HH24:MI:SS' )            AS Hora_Default  
      FROM EAI_Owner.Tmp_Document_Header  Head
      WHERE Head.ReferenceID = sInvoiceID 
        AND NVL( Head.DeliveryType, 'NULO' ) NOT IN ( 'ZI02', 'ZI04',  'IVS' ) ;
--
   CURSOR ScrDetalle IS
      SELECT 
             Head.FacturaSAP                             AS Factura            ,
             Det.ItemID                                  AS Num_Linea          ,
             Det.Material                                AS Material           ,
             Det.Cantidad                                AS Cantidad           ,
             Det.UnidadMedida                            AS UnidadMedida       ,
             Det.Valor_Subt                              AS Valor_Subt         ,
             Det.Valor_IVA                               AS Valor_IVA          ,
             Det.MaterialDescripcion                     AS MaterialDescripcion,
             Det.PrecioUnitario                          AS PrecioUnitario     ,
             Det.Leyenda_ES                              AS Leyenda_ES         ,
             Det.Leyenda_EN                              AS Leyenda_EN
      FROM EAI_Owner.Tmp_Document_Header Head,
           EAI_Owner.Tmp_Document_Detail Det
      WHERE Head.ReferenceID = sInvoiceID
        AND Head.ReferenceID = Det.ReferenceID ;
--
   CURSOR ScrCondiciones IS
      SELECT
             Head.FacturaSAP                             AS Factura            ,
             Det.ItemID                                  AS Num_Linea          ,
             Det.Condition                               AS Condicion          ,
             Det.TotalCondition                          AS Total_Condicion    ,
             Det.TotalAmount                             AS Total_Monto        ,
             Det.Currency                                AS Moneda             ,
             Det.ConditionText                           AS Condicion_Texto    ,
             Det.UnitPrice                               AS Precio             ,
             Det.ConditionID                             AS Condicion_ID       ,
             Det.UnitMeasure                             AS Unidad_Medida      ,
             Det.Quantity                                AS Cantidad
      FROM EAI_Owner.Tmp_Document_Header     Head,
           EAI_Owner.Tmp_Document_Conditions Det
      WHERE Head.ReferenceID = sInvoiceID
        AND Head.ReferenceID = Det.ReferenceID ;
BEGIN
   v_ID      := sInvoiceID ;
   sProcesar := 'NO'       ;
   FOR Doc IN ScrGeneral LOOP
      sFacturaV3 := Doc.Factura ;
      OPEN ScrValida ;
      FETCH ScrValida INTO sProcesar ;
      IF ( ScrValida%NOTFOUND ) THEN
         sProcesar := 'SI' ;
      END IF ;
      CLOSE ScrValida ;
      IF ( sProcesar = 'SI' ) THEN
         DELETE FROM T3.Otros_General     WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.Otros_Detalle     WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.Otros_Condiciones WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.RF_Complemento    WHERE Factura = sFacturaV3 ;
         IF ( Doc.Hora_Factura = '::' ) THEN
            sHora_Factura := Doc.Hora_Default ;
         ELSE
            sHora_Factura := Doc.Hora_Factura ;
         END IF ;
         INSERT INTO T3.RF_Complemento 
            ( Factura, Hora_Factura, Sociedad, Dias_Pago )
         VALUES
            ( Doc.Factura, sHora_Factura, Doc.Sociedad, Doc.CondicionPago ) ; 
         INSERT INTO T3.Otros_General
            ( Factura                , FacturaSAP             , PedidoSAP              , Sociedad               ,
              Clase_Factura          , Cliente_SAP            , Clte_Factura_SAP       , NIF                    ,
              RFC                    , Moneda                 , TipoCambio             , CondicionPago          ,
              Valor_Subt             , Valor_IVA              , Fecha_Factura          , Fecha_TRN              ,
              Fecha_Proc_BATMD       , Fecha_Cancelacion      , Nombre                 , Direccion              ,
              Colonia                , Ciudad                 , Estado                 , Pais                   ,
              Incoterms              ,
              CodigoPostal           , MetodoPago             , ReferenciaBancaria     , Observaciones           )
         VALUES
            ( Doc.Factura            , Doc.FacturaSAP         , Doc.PedidoSAP          , Doc.Sociedad           ,
              Doc.Clase_Factura      , Doc.Cliente_SAP        , Doc.Clte_Factura_SAP   , Doc.NIF                ,
              Doc.RFC                , Doc.Moneda             , Doc.TipoCambio         , Doc.CondicionPago      ,
              Doc.Valor_Subt         , Doc.Valor_IVA          , Doc.Fecha_Factura      , Doc.Fecha_TRN          ,
              Doc.Fecha_Proc_BATMD   , Doc.Fecha_Cancelacion  , Doc.Nombre             , Doc.Direccion          ,
              Doc.Colonia            , Doc.Ciudad             , Doc.Estado             , Doc.Pais               ,
              Doc.Incoterms          ,
              Doc.CodigoPostal       , Doc.MetodoPago         , Doc.ReferenciaBancaria , Doc.Observaciones       ) ;
         IF ( TRIM( UPPER( Doc.ReferenciaBancaria ) ) = 'CCE' ) THEN
            SELECT EAI_Owner.getConv( 'TMD_PAC Payment Method', 'Import/Export' )            AS MetodoPago,
                   EAI_Owner.getConv( 'TMD_PAC Payment Method', 'Import/Export Ref Banco' )  AS NumCtaPago
               INTO sMetodoDePago, sNumCtaPago      
               FROM DUAL ;     
            UPDATE T3.Otros_General SET MetodoPago         = sMetodoDePago,
                                        ReferenciaBancaria = sNumCtaPago  ,
                                        Incoterms          = ''           ,
                                        Complemento_CE     = TRIM( UPPER( Doc.ReferenciaBancaria ) )
               WHERE Factura = Doc.Factura ;       
         END IF ;      
--              
         FOR Itm IN ScrDetalle LOOP
            nPrecioUnitario := Itm.Valor_Subt / Itm.Cantidad ;
            INSERT INTO T3.Otros_Detalle 
               ( Factura                  , Num_Linea                , Material                 , MaterialDescripcion      ,
                 Cantidad                 , UnidadMedida             , PrecioUnitario           , Valor_Subt               ,
                 Valor_IVA                , Leyenda_EN               , Leyenda_ES                                           )
            VALUES
               ( Itm.Factura              , Itm.Num_Linea            , Itm.Material             , Itm.MaterialDescripcion  ,
                 Itm.Cantidad             , Itm.UnidadMedida         , nPrecioUnitario          , Itm.Valor_Subt           ,
                 Itm.Valor_IVA            , Itm.Leyenda_EN           , Itm.Leyenda_ES                                       ) ;
         END LOOP ;  
--
        FOR Cnd IN ScrCondiciones LOOP
           INSERT INTO T3.Otros_Condiciones 
              ( Factura             , Num_Linea           , Condicion           , Total_Condicion     ,
                Total_Monto         , Moneda              , Condicion_Texto     , Precio              ,
                Condicion_ID        , Unidad_Medida       , Cantidad                                   ) 
           VALUES     
              ( Cnd.Factura         , Cnd.Num_Linea       , Cnd.Condicion       , Cnd.Total_Condicion ,
                Cnd.Total_Monto     , Cnd.Moneda          , Cnd.Condicion_Texto , Cnd.Precio          ,
                Cnd.Condicion_ID    , Cnd.Unidad_Medida   , Cnd.Cantidad                               ) ;
        END LOOP ;
--
         UPDATE EAI_Owner.Tmp_Document_Header  SET  Procesado = SYSDATE 
            WHERE ReferenceID = sInvoiceID ;
      END IF ;
   END LOOP ;
   EAI_OWNER.INVOICE_TO_OTROS_V33( sInvoiceID ) ;
   EAI_OWNER.INVOICE_TO_OTROS_RETENTION( sInvoiceID ) ;
   EAI_OWNER.INVOICE_TO_OTROS_PARTNERS( sInvoiceID ) ;
--
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Sending to T3'    , v_ID           , SYSDATE             , NULL           ,
          'Error'            , 'Invoice to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_TO_OTROS ;