create or replace PROCEDURE           INVOICE_TO_FACTURA
   ( sInvoiceID   IN   VARCHAR2 ,
     pFolioFiscal OUT  VARCHAR2 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   sAccnt_ID       VARCHAR2(030) ;
   sProcesar       VARCHAR2(002) ;
   sFacturaV3      VARCHAR2(030) ;
   nBonif_Subt     NUMBER(22,7 ) ;
   nBonif_IVA      NUMBER(22,7 ) ;
   nBonif_Porc     NUMBER(22,7 ) ;
   sUbicacion      VARCHAR2(04)  ;
   sMaterial       VARCHAR2(18)  ;
   nFact_Subt      NUMBER(22,7 ) ;
   nFact_IVA       NUMBER(22,7 ) ;
   nDet_Subt       NUMBER(22,7 ) ;
   nDet_IVA        NUMBER(22,7 ) ;
   nDet_EnvioSubt  NUMBER(22,7 ) ;
   nDet_EnvioIVA   NUMBER(22,7 ) ;
   nDet_CrediSubt  NUMBER(22,7 ) ;
   nDet_CrediIVA   NUMBER(22,7 ) ;
   nDet_Bonif      NUMBER(22,7 ) ;
   nDet_BonifIVA   NUMBER(22,7 ) ;
   nCantidad_Vta   NUMBER(22,7 ) ;
   nDet_PrecioUnit NUMBER(22,7 ) ;
   nDet_ValorTot   NUMBER(22,7 ) ;
   sRF_Comp        VARCHAR2(04)  ;
   nDias           NUMBER(4)     ;
   nFactorDiv      NUMBER(4)     ;
   sUnidad_Med_Vta VARCHAR2(10)  ;
   nItmTasa_IVA    NUMBER(22,7 ) ;
--
   CURSOR ScrValida IS
      SELECT 
          CASE
             WHEN ( Fecha_Proc_BATMD IS NULL ) THEN 'SI'
             WHEN ( Fecha_Proc_BATMD  > TO_DATE( '29990101', 'YYYYMMDD' ) ) THEN 'SI'
             ELSE 'NO'
          END      
           AS Procesar   
   FROM T3.Factura_General
   WHERE Factura = sFacturaV3 ;
--
   CURSOR ScrGeneral IS
      SELECT 
             Head.FacturaSAP                             AS Factura            ,
             SUBSTR( Head.FacturaSAP, 1, 3 )             AS Prefijo            ,
             Head.ShippingPoint                          AS Centro             ,
             EAI.CONV_PLANT_TO_DIST(Head.ShippingPoint)  AS Distribuidor       ,  
             Head.ReferenceID                            AS Entrega            ,
             TO_DATE( SUBSTR( Head.DocumentDate, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Factura      ,
             TO_DATE( SUBSTR( Head.Fecha_Vencimiento, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Pago         ,
             DECODE( Head.DeliveryType, 'C005', 'C003',
                                        'C006', 'C004',
                                         Head.DeliveryType )                           
                                                         AS Clase_Factura      ,
             EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP)
                                                         AS Cliente_V3         ,
             Head.Cust_to_SAP                            AS Cliente_SAP        ,
             Head.Cust_to_SAP                            AS Cliente_Pagador_SAP,
             NVL( Head.Bill_to_SAP, Head.Cust_to_SAP )   AS Clte_Factura_SAP   ,
             'NULL'                                      AS Ubicacion          ,
             Head.PedidoSAP                              AS Pedido             ,
             TO_DATE( SUBSTR( Head.DocumentDate, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Est_Ent      ,
             NVL( Head.Valor_Subt, 0 )                   AS Valor_Subt         ,
             NVL( Head.Valor_IVA , 0 )                   AS Valor_IVA          ,
             '11'                                        AS Status_Contable    ,
             Head.PedidoV3                               AS Referencia         ,
             0                                           AS Valor_ISSA         ,
             Head.ShippingPoint                          AS Ctro               ,
--           ROUND( NVL( Head.Valor_IVA , 0 ) * 100
--                / NVL( Head.Valor_Subt, 0 ) )          AS Tasa_IVA           ,
             CASE
                WHEN NVL( Head.Valor_Subt, 0 ) = 0 THEN 0
                ELSE
                   ROUND( NVL( Head.Valor_IVA , 0 ) * 100
                        / NVL( Head.Valor_Subt, 0 ) )                
             END                                         AS Tasa_IVA           ,
             SUBSTR( Head.DocumentDate, 10, 2 ) || ':' ||
             SUBSTR( Head.DocumentDate, 12, 2 ) || ':' ||
             SUBSTR( Head.DocumentDate, 14, 2 )          AS Hora_Factura       ,
             Head.CompanyCode                            AS CompanyCode
      FROM EAI_Owner.Tmp_Document_Header  Head
      WHERE Head.ReferenceID = sInvoiceID ;
--
   CURSOR ScrDetalle IS
      SELECT Factura, Prefijo, Num_Linea, Material,
             Unidad_Med_Vta, Status_Prod,
             MAX( Tasa_IEPS      )  AS Tasa_IEPS   ,
             SUM( Cantidad_Vta   )  AS Cantidad_Vta,
             SUM( Valor_Subt     )  AS Valor_Subt  ,
             SUM( Valor_IVA      )  AS Valor_IVA   ,
             SUM( Valor_ISSA     )  AS Valor_ISSA  ,
             SUM( Bonif_Subt     )  AS Bonif_Subt  ,
             SUM( Bonif_Vol      )  AS Bonif_Vol   ,
             SUM( Envio_Subt     )  AS Envio_Subt  ,
             SUM( Credito_Subt   )  AS Credito_Subt
      FROM (
         SELECT 
             Head.FacturaSAP                             AS Factura            ,
             SUBSTR( Head.FacturaSAP, 1, 3 )             AS Prefijo            ,
             Det.ItemID                                  AS Num_Linea          ,
--           Det.Material                                AS Material           ,
             TRIM( TO_NUMBER( Det.Material ) )           AS Material           ,
--           NVL( Mat.Tasa_IEPS, 0 )                     AS Tasa_IEPS          ,
             0                                           AS Tasa_IEPS          ,  -- En SF NO Aplica
--           Det.Cantidad                                AS Cantidad_Vta       ,
             CASE
               WHEN ( Head.DeliveryType = 'C019' ) THEN 1
               ELSE
                  Det.Cantidad
             END                                         AS Cantidad_Vta       ,  
             NVL( Det.UnidadMedida, 'UA' )               AS Unidad_Med_Vta     ,
             CASE
                 WHEN ( Det.Status_Producto = 'MALO' ) THEN 'Q'
                 ELSE
                   ' '
             END                                         AS Status_Prod        ,
             NVL( Det.Valor_Subt, 0 )                    AS Valor_Subt         ,
             NVL( Det.Valor_IVA , 0 )                    AS Valor_IVA          ,
             0                                           AS Valor_ISSA         ,
             NVL( Det.Bonif_Subt, 0 )                    AS Bonif_Subt         ,
             0                                           AS Bonif_Vol          ,
             NVL( Det.Envio_Subt, 0 )                    AS Envio_Subt         , 
             NVL( Det.Credito_Subt, 0 )                  AS Credito_Subt       ,
--           ROUND( NVL( Det.Valor_IVA , 0 ) * 100
--                / NVL( Det.Valor_Subt, 0 ) )           AS Tasa_IVA
             CASE
                WHEN NVL( Det.Valor_Subt, 0 ) = 0 THEN 0
                ELSE
                   ROUND( NVL( Det.Valor_IVA , 0 ) * 100
                        / ( NVL( Det.Valor_Subt, 0 ) * NVL( Det.Envio_Subt, 0 ) ) )          
             END                                         AS Tasa_IVA
         FROM EAI_Owner.Tmp_Document_Header Head,
              EAI_Owner.Tmp_Document_Detail Det ,
              T3.Material                   Mat
         WHERE Head.ReferenceID = sInvoiceID
           AND Head.ReferenceID = Det.ReferenceID
           AND TRIM( TO_NUMBER( Det.Material ) ) = Mat.Material(+) 
      )
      GROUP BY Factura, Prefijo, Num_Linea, Material,
               Unidad_Med_Vta, Status_Prod ;
BEGIN
   v_ID      := sInvoiceID ;
   sProcesar := 'NO'       ;
   sRF_Comp  := 'NO'       ;
   FOR Doc IN ScrGeneral LOOP
      IF ( Doc.Clase_Factura IN ( 'C005', 'C006', 'C003', 'C004' ) ) THEN
         nFactorDiv := 100 ;
      ELSE
         nFactorDiv :=   1 ;
      END IF ;
      sFacturaV3 := Doc.Referencia ;
--
      OPEN ScrValida ;
      FETCH ScrValida INTO sProcesar ;
      IF ( ScrValida%NOTFOUND ) THEN
         sProcesar := 'SI' ;
      END IF ;
      CLOSE ScrValida ;
      IF ( sProcesar = 'SI' ) THEN
       IF ( ( sUbicacion IS NULL ) OR ( LENGTH( sUbicacion ) = 0 ) ) THEN
            sUbicacion := 'TBD' ;
         END IF ;
         SELECT SUM( NVL( Bonif_Subt, 0 ) / nFactorDiv ) INTO nBonif_Subt
            FROM EAI_Owner.Tmp_Document_Detail Det
            WHERE Det.ReferenceID = sInvoiceID ;         
         nBonif_IVA  := ROUND( nBonif_Subt * Doc.Tasa_IVA / 100, 2 ) ;
         IF ( Doc.Valor_Subt > 0 ) THEN
            nBonif_Porc := ROUND( ( nBonif_Porc * 100 ) / Doc.Valor_Subt, 2 ) ; 
         ELSE
            nBonif_Porc := 0 ;
         END IF ;
         nFact_Subt  := ROUND( NVL( Doc.Valor_Subt, 0 ) / nFactorDiv, 2 ) ;
         nFact_IVA   := ROUND( NVL( Doc.Valor_IVA , 0 ) / nFactorDiv, 2 ) ;
         IF ( Doc.Clase_Factura IN ( 'C003', 'C004', 'C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031' ) ) THEN
            nFact_Subt  := nFact_Subt - nFact_IVA ; 
         END IF ;
         DELETE FROM T3.Factura_General     WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.Factura_Detalle     WHERE Factura = sFacturaV3 ;
--         
         IF ( Doc.CompanyCode = 'MX10' ) THEN
            sRF_Comp := 'SI' ; 
         END IF ;
--         
--        IF ( sRF_Comp = 'SI' ) THEN
            DELETE FROM T3.RF_Complemento WHERE Factura = sFacturaV3 ;
            INSERT INTO T3.RF_Complemento 
               ( Factura     , Hora_Factura, Anio_Aprob, Folio_Aprob, Order_Num    , Rep_ID     , X_DelRep_Invloc, 
                 Volumen     , Sociedad    , Cadena_Original        , Sello_Digital, Dias_Pago )
            VALUES 
               ( sFacturaV3  , TO_CHAR( SYSDATE, 'HH24:MI:SS'), 'Error', 'Error', '', 'U00000000', '', 
                 NULL, 'MX06', 'CFDI - Documento', 'CFDI - Documento', Doc.Fecha_Pago - Doc.Fecha_Factura ) ;               
--       END IF ;
         INSERT INTO T3.Factura_General
            ( Factura            , Entrega          , Distribuidor    , Cliente_V3             ,
              Fecha_Factura      , Ubicacion        , Fecha_Pago      , Row_ID                 ,
              Fecha_TRN          , Tipo_Docto       , Cliente_SAP     , Clte_Factura_SAP       , 
              Pedido             , Valor_Subt       , Valor_IVA       ,
              Referencia         , Valor_ISSA       , Ctro            ,
              Bonif_Subt         , Bonif_IVA        , Bonif_Porc      , Bonif_Vol               )
         VALUES
            ( sFacturaV3         , Doc.Entrega      , Doc.Distribuidor, Doc.Cliente_V3         ,
              Doc.Fecha_Factura  , sUbicacion       , Doc.Fecha_Pago  , Doc.Entrega            ,
              SYSDATE            , Doc.Clase_Factura, Doc.Cliente_SAP , Doc.Clte_Factura_SAP   , 
              Doc.Pedido         , nFact_Subt       , nFact_IVA       ,
              Doc.Referencia     , Doc.Valor_ISSA   , Doc.Ctro        ,
              nBonif_Subt        , nBonif_IVA       , nBonif_Porc     , 0                       ) ;
--   
         FOR Itm IN ScrDetalle LOOP
            nCantidad_Vta  := Itm.Cantidad_Vta ;
            nDet_Subt      := ROUND( NVL( Itm.Valor_Subt, 0 ) / nFactorDiv, 2 ) ;
            nDet_IVA       := ROUND( NVL( Itm.Valor_IVA , 0 ) / nFactorDiv, 2 ) ;
            nDet_Bonif     := ROUND( NVL( Itm.Bonif_Subt, 0 ) / nFactorDiv, 2 ) ;     
            nDet_Bonif     := ROUND( ( nDet_Bonif * ( 100 + Itm.Tasa_IEPS ) ) / 100, 2 ) ;    
            nDet_EnvioSubt := ROUND( NVL( Itm.Envio_Subt  , 0 ) / nFactorDiv, 2 ) ;
            nDet_CrediSubt := ROUND( NVL( Itm.Credito_Subt, 0 ) / nFactorDiv, 2 ) ;
            IF ( NVL( Itm.Valor_Subt, 0 ) = 0 ) THEN            
               nItmTasa_IVA := 0 ;
            ELSE
               nItmTasa_IVA := ROUND( NVL( Itm.Valor_IVA , 0 ) * 100
                        / NVL( Itm.Valor_Subt, 0 ) ) ;
            END IF ;
            nDet_BonifIVA  := ROUND( nDet_Bonif * nItmTasa_IVA / 100, 2 ) ;
            IF ( Itm.Valor_Subt > 0 ) THEN
               nBonif_Porc := ROUND( ( Itm.Bonif_Subt * 100 ) / ( Itm.Bonif_Subt + Itm.Valor_Subt ), 2 ) ; 
            ELSE
               nBonif_Porc := 0 ;
            END IF ;
--
            IF ( nDet_EnvioSubt > 0 ) THEN
               nDet_EnvioIVA  := ROUND( nDet_EnvioSubt * nItmTasa_IVA / 100, 2 ) ;
            ELSE
               nDet_EnvioIVA := 0 ;
            END IF ;

            IF ( nDet_CrediSubt > 0 ) THEN
               nDet_CrediIVA  := ROUND( nDet_CrediSubt * nItmTasa_IVA / 100, 2 ) ;
            ELSE
               nDet_CrediIVA := 0 ;
            END IF ;
            nDet_Subt := nDet_Subt - nDet_EnvioSubt - nDet_CrediSubt ;
            IF ( Doc.Clase_Factura IN ( 'C005', 'C006', 'C003', 'C004' ) ) THEN
               nDet_IVA  := nDet_IVA - nDet_EnvioIVA - nDet_CrediIVA ;
            END IF ;   
--            
            sMaterial       := Itm.Material ;
            sMaterial       := TRIM( RTRIM( LTRIM( Itm.Material ) ) ) ;
--          sMaterial       := TRIM( TO_CHAR( TO_NUMBER( sMaterial ) ) ) ;
            sUnidad_Med_Vta := Itm.Unidad_Med_Vta ;
            SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', sUnidad_Med_Vta )  INTO  sUnidad_Med_Vta
               FROM DUAL ;
-- Workaround for                
            IF ( Doc.Clase_Factura IN ( 'C030', 'C031' ) ) THEN      
               EAI_Owner.WA_Cantidad_UMV( sMaterial, Itm.Cantidad_Vta, Itm.Unidad_Med_Vta, nCantidad_Vta, sUnidad_Med_Vta ) ;
            END IF ;       
            IF ( Doc.Clase_Factura IN ( 'C025', 'C019' ) ) THEN        
               nDet_IVA := ROUND( nDet_Subt * nItmTasa_IVA / 100, 2 );
            END IF ;   
            nDet_ValorTot     := ( NVL( nDet_Subt, 0 ) + NVL( nDet_IVA   , 0 ) ) ;
            nDet_PrecioUnit   := ROUND( ( NVL( nDet_Subt, 0 ) + NVL( nDet_Bonif, 0 ) ) / NVL( nCantidad_Vta, 1 ), 2 ) ;  
            nDet_PrecioUnit   := ROUND( ( NVL( nDet_Subt, 0 ) ) / NVL( nCantidad_Vta, 1 ), 2 ) ;  
            INSERT INTO T3.Factura_Detalle 
               ( Factura         , Num_Linea         , Material       , 
                 Cantidad_Vta    , Unidad_Med_Vta    , 
                 Status_Prod     , Valor_Subt        , Valor_IVA      , Valor_ISSA    ,
                 Envio_Subt      , Envio_IVA         , Precio_Unit    , Valor_Tot     ,
                 Credito_Subt    , Credito_IVA       ,
                 Bonif_Subt      , Bonif_IVA         , Bonif_Porc     , Bonif_Vol      )
            VALUES
               ( sFacturaV3      , Itm.Num_Linea     , sMaterial      , 
                 nCantidad_Vta   , sUnidad_Med_Vta   , 
                 Itm.Status_Prod , nDet_Subt         , nDet_IVA       , Itm.Valor_ISSA,
                 nDet_EnvioSubt  , nDet_EnvioIVA     , nDet_PrecioUnit, nDet_ValorTot ,
                 nDet_CrediSubt  , nDet_CrediIVA     ,
                 nDet_Bonif      , nDet_BonifIVA     , nBonif_Porc    , Itm.Bonif_Vol  ) ;
         END LOOP ;
      END IF ;
   END LOOP ;
--
   UPDATE T3.Factura_General PG SET ( Bonif_Subt, Bonif_IVA, Valor_Subt, Valor_IVA, Envio_Subt, Envio_IVA, Credito_Subt, Credito_IVA ) = 
      ( SELECT SUM( NVL( PD.Bonif_Subt  , 0 )  ) AS Bonif_Subt  ,
               SUM( NVL( PD.Bonif_IVA   , 0 )  ) AS Bonif_IVA   ,
               SUM( NVL( PD.Valor_Subt  , 0 )  ) AS Valor_Subt  ,
               SUM( NVL( PD.Valor_IVA   , 0 )  ) AS Valor_IVA   ,
               SUM( NVL( PD.Envio_Subt  , 0 )  ) AS Envio_Subt  ,
               SUM( NVL( PD.Envio_IVA   , 0 )  ) AS Envio_IVA   ,
               SUM( NVL( PD.Credito_Subt, 0 )  ) AS Credito_Subt,
               SUM( NVL( PD.Credito_IVA , 0 )  ) AS Credito_IVA                              
        FROM T3.Factura_Detalle PD
           WHERE PD.Factura = PG.Factura )
       WHERE PG.Factura = sFacturaV3 ;   
   UPDATE EAI_Owner.Tmp_Document_Header  SET  Procesado = SYSDATE
      WHERE ReferenceID = sInvoiceID ;
   EAI_OWNER.INVOICE_TO_ENTREGA_PO( sInvoiceID, 0 ) ;      
   pFolioFiscal := sFacturaV3 ;
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
END INVOICE_TO_FACTURA ;