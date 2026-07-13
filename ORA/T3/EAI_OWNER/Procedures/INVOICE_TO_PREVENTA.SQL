create or replace PROCEDURE           INVOICE_TO_PREVENTA
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
   nDet_Bonif      NUMBER(22,7 ) ;
   nDet_BonifIVA   NUMBER(22,7 ) ;
   nCantidad_Vta   NUMBER(22,7 ) ;
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
   FROM T3.Preventa_General
   WHERE Factura = sFacturaV3 ;
--
   CURSOR ScrGeneral IS
      SELECT 
             Head.FacturaSAP                             AS Factura            ,
             SUBSTR( Head.FacturaSAP, 1, 3 )             AS Prefijo            ,
             Head.ShippingPoint                          AS Centro             ,
             Head.ReferenceID                            AS Entrega            ,
             TO_DATE( SUBSTR( Head.DocumentDate, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Factura      ,
             TO_DATE( SUBSTR( Head.Fecha_Vencimiento, 1, 8 )
              , 'YYYYMMDD' )                             AS Fecha_Pago         ,              
             DECODE( Head.DeliveryType, 'C004', 'C006',
                     Head.DeliveryType )                 AS Clase_Factura      ,
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
             UPPER( Head.PedidoV3 )                      AS Referencia         ,
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
             Head.CompanyCode                            AS CompanyCode        ,
             NVL( Lib.LiberaAuto, 'TBC' )                AS LiberaAuto
      FROM EAI_Owner.Tmp_Document_Header  Head,
          (
            SELECT Source AS Cliente_SAP, NVL( Target, 'NO' ) AS LiberaAuto
               FROM EAI_Owner.MX_HashTable
               WHERE TYPE = 'PDV A51'
           ) Lib      
      WHERE Head.ReferenceID = sInvoiceID
        AND Head.Cust_to_SAP = Lib.Cliente_SAP(+) ;
--
   CURSOR ScrDetalle IS
      SELECT Factura, Prefijo, Num_Linea, Material,
             Unidad_Med_Vta, Status_Prod,
             MAX( Tasa_IEPS    )  AS Tasa_IEPS   ,
             SUM( Cantidad_Vta )  AS Cantidad_Vta,
             SUM( Valor_Subt   )  AS Valor_Subt  ,
             SUM( Valor_IVA    )  AS Valor_IVA   ,
             SUM( Valor_ISSA   )  AS Valor_ISSA  ,
             SUM( Bonif_Subt   )  AS Bonif_Subt  ,
             SUM( Bonif_Vol    )  AS Bonif_Vol   ,
             SUM( Envio_Subt   )  AS Envio_Subt
      FROM (
         SELECT 
             Head.FacturaSAP                             AS Factura            ,
             SUBSTR( Head.FacturaSAP, 1, 3 )             AS Prefijo            ,
             Det.ItemID                                  AS Num_Linea          ,
--           Det.Material                                AS Material           ,
             TRIM( TO_NUMBER( Det.Material ) )           AS Material           ,
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
--           NVL( Mat.Tasa_IEPS , 0 )                    AS Tasa_IEPS          ,
             0                                           AS Tasa_IEPS          ,
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
      IF ( Doc.Clase_Factura IN ( 'C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031' ) ) THEN
         nFactorDiv := 100 ;
      ELSE
         nFactorDiv :=   1 ;
      END IF ;
--
      IF    ( Doc.Clase_Factura IN ( 'C020', 'C021', 'C022' ) ) THEN
         EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;
      ELSIF ( Doc.Clase_Factura IN ( 'C005', 'C006' ) ) THEN   
--         EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;         
         sFacturaV3 := Doc.Referencia ;
         SELECT REPLACE( sFacturaV3, '-O-', '-' ) INTO sFacturaV3 
            FROM DUAL ;
      ELSIF ( Doc.Clase_Factura IN ( 'C019' ) ) THEN   
         sRF_Comp := 'SI' ;
--       EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;     
         sFacturaV3 := Doc.Referencia ;   
      ELSIF ( Doc.Clase_Factura IN ( 'C0FX' ) ) THEN   
         sRF_Comp := 'SI' ;
--       EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;         
         sFacturaV3 := Doc.Referencia ;   
      ELSIF ( Doc.Clase_Factura IN ( 'C025' ) ) THEN   
         sRF_Comp := 'SI' ;
--       EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;         
         sFacturaV3 := Doc.Referencia ;   
      ELSIF ( Doc.Clase_Factura IN ( 'C030', 'C031' ) ) THEN   
         sRF_Comp := 'SI' ;
         EAI_Owner.WA_FOLIO_FACTURA( Doc.Factura, Doc.Centro, Doc.Clase_Factura, Doc.Fecha_Factura, 0, sFacturaV3 ) ;         
      ELSE
         sFacturaV3 := Doc.Factura ;
      END IF ;
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
         IF ( Doc.Clase_Factura IN ( 'C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031' ) ) THEN
            nFact_Subt  := nFact_Subt - nFact_IVA ; 
         END IF ;
         DELETE FROM T3.Preventa_General     WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.Preventa_Detalle     WHERE Factura = sFacturaV3 ;
         DELETE FROM T3.Preventa_Condiciones WHERE Factura = sFacturaV3 ;
--         
         IF ( Doc.CompanyCode = 'MX10' ) THEN
            sRF_Comp := 'SI' ; 
         END IF ;
--         
         IF ( sRF_Comp = 'SI' ) THEN
            DELETE FROM T3.RF_Complemento WHERE Factura = sFacturaV3 ;
            INSERT INTO T3.RF_Complemento ( Factura, Hora_Factura, Sociedad, Dias_Pago )
               VALUES ( sFacturaV3, TO_CHAR( SYSDATE, 'HH24:MI:SS'), Doc.CompanyCode, Doc.Fecha_Pago - Doc.Fecha_Factura ) ;
         END IF ;
         INSERT INTO T3.Preventa_General
            ( Factura            , Prefijo          , Centro              , Entrega                , 
              Fecha_Factura      , Ubicacion        , Clte_Factura_SAP    ,
              Fecha_TRN          , Clase_Factura    , Cliente_SAP         , Cliente_Pagador_SAP    , 
              Pedido             , Fecha_Est_Ent    , Valor_Subt          , Valor_IVA              ,
              Status_Contable    , Referencia       , Valor_ISSA          , Ctro                   ,
              Bonif_Subt         , Bonif_IVA        , Bonif_Porc          , Bonif_Vol               )
         VALUES
            ( sFacturaV3         , Doc.Prefijo      , Doc.Centro          , Doc.Entrega            , 
              Doc.Fecha_Factura  , sUbicacion       , Doc.Clte_Factura_SAP,
              SYSDATE            , Doc.Clase_Factura, Doc.Cliente_SAP     , Doc.Cliente_Pagador_SAP, 
              Doc.Pedido         , Doc.Fecha_Est_Ent, nFact_Subt          , nFact_IVA              ,
              Doc.Status_Contable, Doc.Referencia   , Doc.Valor_ISSA      , Doc.Ctro               ,
              nBonif_Subt        , nBonif_IVA       , nBonif_Porc         , 0                       ) ;
--        
         INSERT INTO T3.Preventa_Condiciones
             ( Factura, Num_Linea, Condicion, Importe )    
          SELECT sFacturaV3                    AS Factura  ,
                 ItemID                        AS Num_Linea,
                 Condition                     AS Condicion,
                 Amount                        AS Importe
             FROM EAI_Owner.tmp_Document_Detail_Cond
             WHERE ReferenceID = sInvoiceID ;
--   
         FOR Itm IN ScrDetalle LOOP
            nCantidad_Vta  := Itm.Cantidad_Vta ;
            nDet_Subt      := ROUND( NVL( Itm.Valor_Subt, 0 ) / nFactorDiv, 2 ) ;
            nDet_IVA       := ROUND( NVL( Itm.Valor_IVA , 0 ) / nFactorDiv, 2 ) ;
            nDet_Bonif     := ROUND( NVL( Itm.Bonif_Subt, 0 ) / nFactorDiv, 2 ) ;    
            nDet_Bonif     := ROUND( ( nDet_Bonif * ( 100 + Itm.Tasa_IEPS ) ) / 100, 2 ) ;     
            nDet_EnvioSubt := ROUND( NVL( Itm.Envio_Subt, 0 ) / nFactorDiv, 2 ) ;
            IF ( NVL( Itm.Valor_Subt, 0 ) = 0 ) THEN            
               nItmTasa_IVA := 0 ;
            ELSE
               nItmTasa_IVA := ROUND( NVL( Itm.Valor_IVA , 0 ) * 100
                        / NVL( Itm.Valor_Subt, 0 ) ) ;
            END IF ;
            nDet_BonifIVA  := ROUND( nDet_Bonif * nItmTasa_IVA / 100, 2 ) ;
            IF ( Itm.Valor_Subt > 0 ) THEN
               nBonif_Porc := ROUND( ( Itm.Bonif_Subt * 100 ) / Itm.Valor_Subt, 2 ) ; 
            ELSE
               nBonif_Porc := 0 ;
            END IF ;
--
            IF ( nDet_EnvioSubt > 0 ) THEN
               nDet_EnvioIVA  := ROUND( nDet_EnvioSubt * nItmTasa_IVA / 100, 2 ) ;
            ELSE
               nDet_EnvioIVA := 0 ;
            END IF ;
            nDet_Subt := nDet_Subt - nDet_EnvioSubt ;
            IF ( Doc.Clase_Factura IN ( 'C005', 'C006' ) ) THEN
               nDet_IVA  := nDet_IVA  - nDet_EnvioIVA  ;
            END IF ;   
            IF ( ( Doc.LiberaAuto != 'TBC' ) AND ( nDet_IVA > 0 ) )  THEN
               nDet_IVA := ROUND( nDet_Subt * 0.16, 2 ) ;
            END IF ;
--            
            sMaterial   := Itm.Material ;
            sMaterial   := TRIM( RTRIM( LTRIM( Itm.Material ) ) ) ;
--          sMaterial   := TRIM( TO_CHAR( TO_NUMBER( sMaterial ) ) ) ;
            sUnidad_Med_Vta := Itm.Unidad_Med_Vta ;
            SELECT EAI_Owner.GETCONV( 'ECC_V3 UOM', sUnidad_Med_Vta )  INTO  sUnidad_Med_Vta
               FROM DUAL ;
-- Workaround for                
            IF ( Doc.Clase_Factura IN ( 'C030', 'C031' ) ) THEN      
               EAI_Owner.WA_Cantidad_UMV( sMaterial, Itm.Cantidad_Vta, Itm.Unidad_Med_Vta, nCantidad_Vta, sUnidad_Med_Vta ) ;
            END IF ;       
            IF ( Doc.Clase_Factura IN ( 'C025', 'C019' ) ) THEN        
               nDet_IVA := ROUND( nDet_Subt * nItmTasa_IVA / 100, 2 );
            -- nDet_IVA := nDet_IVA ;
            END IF ;   
            IF ( nBonif_Porc > 100 ) THEN
               nBonif_Porc := 100 ;
            END IF ;
            INSERT INTO T3.Preventa_Detalle 
               ( Factura         , Prefijo           , Num_Linea     , Material      , 
                 Cantidad_Vta    , Unidad_Med_Vta    , Referencia_Pedido,
                 Status_Prod     , Valor_Subt        , Valor_IVA     , Valor_ISSA    ,
                 Envio_Subt      , Envio_IVA         ,
                 Bonif_Subt      , Bonif_IVA         , Bonif_Porc    , Bonif_Vol      )
            VALUES
               ( sFacturaV3      , Itm.Prefijo       , Itm.Num_Linea , sMaterial     , 
                 nCantidad_Vta   , sUnidad_Med_Vta   , Itm.Cantidad_Vta,
                 Itm.Status_Prod , nDet_Subt         , nDet_IVA      , Itm.Valor_ISSA,
                 nDet_EnvioSubt  , nDet_EnvioIVA     ,
                 nDet_Bonif      , nDet_BonifIVA     , nBonif_Porc   , Itm.Bonif_Vol  ) ;
         END LOOP ;
      END IF ;
   END LOOP ;
--
   UPDATE T3.Preventa_General PG SET ( Bonif_Subt, Bonif_IVA, Valor_Subt, Valor_IVA ) = 
      ( SELECT SUM( NVL( PD.Bonif_Subt, 0 )                           ) AS Bonif_Subt,
               SUM( NVL( PD.Bonif_IVA , 0 )                           ) AS Bonif_IVA ,
               SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Envio_Subt, 0 ) ) AS Valor_Subt,
               SUM( NVL( PD.Valor_IVA , 0 ) + NVL( PD.Envio_IVA , 0 ) ) AS Valor_IVA
        FROM T3.Preventa_Detalle PD
           WHERE PD.Factura = PG.Factura )
       WHERE PG.Factura = sFacturaV3 ;   
   EAI_OWNER.INVOICE_TO_ENTREGA_PO( sInvoiceID, 0 ) ;       
   UPDATE EAI_Owner.Tmp_Document_Header  SET  Procesado = SYSDATE 
      WHERE ReferenceID = sInvoiceID ;
   pFolioFiscal := sFacturaV3 ;
   T3.DELIVERY_WA_OXXO( sFacturaV3, 1, 0 ) ;
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
END INVOICE_TO_PREVENTA ;