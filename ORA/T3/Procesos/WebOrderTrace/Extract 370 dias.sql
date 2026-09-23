SELECT 'ORD_ID'                 || CHR(44) ||
       'ORD_ORDER_NUM'          || CHR(44) || 
       'ORD_RETAILER_PO'        || CHR(44) || 
       'ORD_CLIENTE'            || CHR(44) || 
       'ORD_FECHA'              || CHR(44) || 
       'ORD_AMOUNT'             || CHR(44) || 
       'ORD_STATUS'             || CHR(44) || 
       'INV_DOC_NUM'            || CHR(44) || 
       'INV_CLIENTE'            || CHR(44) || 
       'INV_FECHA'              || CHR(44) || 
       'INV_DELIVERY_STATUS'    || CHR(44) || 
       'ORD_DELIVERY_STATUS'    || CHR(44) ||
       'ZLOB_REFERENCE'         || CHR(44) ||
       'ORDEN_STATUS'           || CHR(44) ||
       'INV_PLANTA'             || CHR(44) ||
       'INV_FACTURA_SAP'        || CHR(44) ||
       'INV_FECHA_TRN'          || CHR(44) ||
       'INV_PROC_BATMD'         || CHR(44) ||
       'INV_FECHA_CANC'         || CHR(44) ||
       'INV_CARTERA'            || CHR(44) ||
       'ZLOB_FACTURA_SAP'       || CHR(44) ||
       'ZLOB_FECHA_TRN'         || CHR(44) ||
       'ZLOB_PROC_BATMD'        || CHR(44) ||
       'ZLOB_FECHA_CANC'        || CHR(44) ||
       'ZLOB_CARTERA'           || CHR(44) ||
       'CLEARING_STATUS'                   AS ExtractLine
FROM DUAL
UNION ALL
SELECT Info.Ord_ID              || CHR(44) ||
       CHR(39)                  ||
       Info.Ord_Order_Num       || CHR(44) ||
       Info.Ord_Retailer_PO     || CHR(44) ||
       Info.Ord_Cliente         || CHR(44) ||
       Info.Ord_Fecha           || CHR(44) ||
       TO_CHAR( NVL( Info.Ord_Amount, 0 ) )
                                || CHR(44) ||
       Info.Ord_Status          || CHR(44) ||                         
       Info.Inv_Doc_Num         || CHR(44) ||
       Info.Inv_Cliente         || CHR(44) ||
       Info.Inv_Fecha           || CHR(44) ||
       Info.Inv_Delivery_Status || CHR(44) ||
       Info.Ord_Delivery_Status || CHR(44) ||
       Info.ZLOB_Reference      || CHR(44) ||
       Info.Orden_Status        || CHR(44) ||
       Info.Inv_Planta          || CHR(44) ||
       Info.Inv_Factura_SAP     || CHR(44) ||
       Info.Inv_Fecha_Trn       || CHR(44) ||
       Info.Inv_Proc_BATMD      || CHR(44) ||
       Info.Inv_Fecha_Canc      || CHR(44) ||
       Info.Inv_Cartera         || CHR(44) ||
       Info.ZLOB_Factura_SAP    || CHR(44) ||
       Info.ZLOB_Fecha_Trn      || CHR(44) ||
       Info.ZLOB_Proc_BATMD     || CHR(44) ||
       Info.ZLOB_Fecha_Canc     || CHR(44) ||
       Info.ZLOB_CARTERA        || CHR(44) ||
       Info.Clearing_Status                AS ExtractLine
FROM (
       SELECT SF.Ord_ID                                      AS Ord_ID             ,
              SF.Ord_Order_Num                               AS Ord_Order_Num      ,
              SF.Ord_Retailer_PO                             AS Ord_Retailer_PO    ,
              SF.Ord_Cliente                                 AS Ord_Cliente        ,
              SF.Ord_Fecha                                   AS Ord_Fecha          ,
              SF.Ord_Amount                                  AS Ord_Amount         ,
              SF.Ord_Status                                  AS Ord_Status         ,
             SF.Inv_Doc_Num                                 AS Inv_Doc_Num        ,
              SF.Inv_Cliente                                 AS Inv_Cliente        ,
              SF.Inv_Fecha                                   AS Inv_Fecha          ,
              SF.Inv_Delivery_Status                         AS Inv_Delivery_Status,
              SF.Ord_Delivery_Status                         AS Ord_Delivery_Status,
              SF.ZLOB_Reference                              AS ZLOB_Reference     ,
--
              CASE
                  WHEN ( ( SF.Inv_Delivery_Status = 'Delivered'    ) AND ( SF.ZLOB_Reference IS NULL     ) AND ( NVL( Inv.Fecha_Proc_BATMD , SYSDATE + 1 ) < SYSDATE ) AND ( Inv.Fecha_Cancelacion  IS NULL ) ) THEN 'Inv-Procesada'
                  WHEN ( ( SF.Inv_Delivery_Status = 'Unsuccessful' ) AND ( SF.ZLOB_Reference IS NOT NULL ) AND ( NVL( Inv.Fecha_Proc_BATMD , SYSDATE + 1 ) < SYSDATE ) AND ( Inv.Fecha_Cancelacion  IS NULL ) 
                                                                                                           AND ( NVL( ZLob.Fecha_Proc_BATMD, SYSDATE + 1 ) < SYSDATE ) AND ( ZLob.Fecha_Cancelacion IS NULL ) ) THEN 'ZLob-Procesada'
                  WHEN ( ( SF.Ord_Delivery_Status = 'Delivered'    ) AND ( SF.ZLOB_Reference IS NULL     ) AND ( NVL( Inv.Fecha_Proc_BATMD , SYSDATE + 1 ) < SYSDATE ) AND ( Inv.Fecha_Cancelacion  IS NULL ) ) THEN 'Ord-Procesada'
                  WHEN ( ( SF.Ord_Status = 'Rejected by SAP' )                                                                                                                                                ) THEN 'Ord-Cancelada'
                  ELSE
                     ''
              END                                            AS Orden_Status       ,
--
              Inv.Ctro                                       AS Inv_Planta         ,
              Inv.Entrega                                    AS Inv_Factura_SAP    ,
              TO_CHAR( 
              Inv.Fecha_Trn         , 'YYYY-MM-DD HH24:MI' ) AS Inv_Fecha_Trn      ,
              TO_CHAR(
              Inv.Fecha_Proc_BATMD  , 'YYYY-MM-DD HH24:MI' ) AS Inv_Proc_BATMD     ,
              TO_CHAR(
              Inv.Fecha_Cancelacion , 'YYYY-MM-DD HH24:MI' ) AS Inv_Fecha_Canc     ,
              Inv.Cartera                                    AS Inv_Cartera        ,
--
              ZLOB.Entrega                                   AS ZLOB_Factura_SAP   ,
              TO_CHAR(
              ZLOB.Fecha_Trn        , 'YYYY-MM-DD HH24:MI' ) AS ZLOB_Fecha_Trn     ,
              TO_CHAR(
              ZLOB.Fecha_Proc_BATMD , 'YYYY-MM-DD HH24:MI' ) AS ZLOB_Proc_BATMD    ,
              TO_CHAR(
              ZLOB.Fecha_Cancelacion, 'YYYY-MM-DD HH24:MI' ) AS ZLOB_Fecha_Canc    , 
              ZLOB.Cartera                                   AS ZLOB_Cartera       ,
              EAI_OWNER.GET_CLEARING_STATUS( SF.Inv_Doc_Num, SF.ZLOB_Reference, SF.Ord_Amount ) 
                                                             AS Clearing_Status
          FROM (
                SELECT 
                       Ord.Ord_ID                           AS Ord_ID             , 
                       Ord.Ord_Order_Num                    AS Ord_Order_Num      ,
                       Ord.Retailer_PO                      AS Ord_Retailer_PO    ,
                       Ord.Ord_Cliente                      AS Ord_Cliente        ,
                       Ord.Ord_Fecha                        AS Ord_Fecha          ,
                       Ord.Ord_Status                       AS Ord_Status         ,
                       Ord.Ord_Amount                       AS Ord_Amount         ,
                       Inv.Inv_Doc_Num                      AS Inv_Doc_Num        ,
                       Inv.Inv_Cliente                      AS Inv_Cliente        ,
                       Inv.Inv_Fecha                        AS Inv_Fecha          ,
                       Inv.Inv_Delivery_Status              AS Inv_Delivery_Status,
                       Inv.ZLOB_Reference                   AS ZLOB_Reference     , 
-- Evaluar si se ocupa
                       Ord.Ord_Delivery_Status              AS Ord_Delivery_Status,
                       Inv.Inv_ID                           AS Inv_ID             ,
                       Inv.Inv_Status                       AS Inv_Status
                   FROM (
                          SELECT
                                 REPLACE( Ord.Row_Name                      , '"', '' ) AS Ord_ID             ,
                                 REPLACE( Ord.ivydsd__Mobile_Order_Number__c, '"', '' ) AS Ord_Order_Num      ,
                                 REPLACE( Ord.ivydsd__Order_Date__c         , '"', '' ) AS Ord_Fecha          ,
                                 REPLACE( Ord.ivydsd__Order_Status__c       , '"', '' ) AS Ord_Status         ,
                                 REPLACE( Ord.Delivery_Status__c            , '"', '' ) AS Ord_Delivery_Status,
                                 REPLACE( Ord.ivyBAT__SAP_CustomerID__c     , '"', '' ) AS Ord_Cliente        ,
                                 REPLACE( Ord.Retailer_PO_Number__c         , '"', '' ) AS Retailer_PO        ,
                                 TO_NUMBER(
                                 REPLACE( Order_Amount__c                   , '"', '' ) )
                                                                                        AS Ord_Amount                         
                             FROM EAI_Owner.WO_TMP_ORDER Ord
                             WHERE Ord.Row_Name != '"NAME"'
                        ) Ord,
                        (
                          SELECT
                                 REPLACE( Inv.Row_Name                      , '"', '' ) AS Inv_ID             ,
                                 REPLACE( Inv.Mobile_Invoice_Number__c      , '"', '' ) AS Inv_Doc_Num        ,
                                 REPLACE( Inv.SAP_Invoice_Number__c         , '"', '' ) AS Inv_Factura_SAP    ,
                                 REPLACE( Inv.ivydsd__Order__r_Name         , '"', '' ) AS Inv_Order_ID       ,
                                 REPLACE( Inv.ivydsd__Invoice_Date__c       , '"', '' ) AS Inv_Fecha          ,
                                 REPLACE( Inv.ivyBAT__SAP_CustomerID__c     , '"', '' ) AS Inv_Cliente        ,
                                 REPLACE( Inv.ivydsd__Invoice_Status__c     , '"', '' ) AS Inv_Status         ,
                                 REPLACE( Inv.Delivery_Status__c            , '"', '' ) AS Inv_Delivery_Status,
                                 DECODE( Inv.Delivery_Status__c, '"Unsuccessful"',
                                  'L' || REPLACE( SUBSTR( REPLACE( Inv.Row_Name, '"', ''), 7, 20), '-', '' )
                                   , '' )                                               AS ZLOB_Reference     
                             FROM EAI_Owner.WO_TMP_INVOICE Inv
                             WHERE Inv.Row_Name != '"NAME"'
                         ) Inv
                   WHERE Ord.Ord_ID      = Inv.Inv_Order_ID(+)  
               ) SF  ,
               (
                 SELECT PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Clase_Factura, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD, PG.Fecha_Cancelacion,
                        SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Valor_IVA, 0 ) + NVL( PD.Envio_Subt, 0 ) + NVL( PD.Envio_IVA, 0 ) ) AS Importe,
                        MAX( Cart.AccountDocument )                                                                                AS Cartera
                    FROM T3.Preventa_General  PG, T3.Preventa_Detalle PD,
                         (
                           SELECT Asignacion, Referencia, Cargo, AccountDocument, COUNT(*) AS Cnt_Rec
                              FROM EAI.TaO_Cartera_SAP_Ldr
                              GROUP BY Asignacion, Referencia, Cargo, AccountDocument                  
                         )  Cart
                    WHERE PG.Fecha_Factura >= TRUNC( SYSDATE - 370 )
                      AND PG.Factura        = PD.Factura
                      AND PG.Clase_Factura  = 'C005'
                      AND PG.Factura NOT LIKE 'L%'
                      AND PG.Entrega        = Cart.Asignacion(+)
                    GROUP BY PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Clase_Factura, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD, PG.Fecha_Cancelacion           
                 UNION ALL 
                 SELECT PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Tipo_Docto, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD, NULL AS Fecha_Cancelacion,
                        SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Valor_IVA, 0 ) + NVL( PD.Envio_Subt, 0 ) + NVL( PD.Envio_IVA, 0 ) ) AS Importe,
                        MAX( Cart.AccountDocument )                                                                                AS Cartera
                    FROM T3.Factura_General  PG, T3.Factura_Detalle PD,
                         (
                           SELECT Asignacion, Referencia, Cargo, AccountDocument, COUNT(*) AS Cnt_Rec
                              FROM EAI.TaO_Cartera_SAP_Ldr
                              GROUP BY Asignacion, Referencia, Cargo, AccountDocument                  
                         )  Cart
                    WHERE PG.Fecha_Factura >= TRUNC( SYSDATE - 370 )
                      AND PG.Factura        = PD.Factura
                      AND PG.Tipo_Docto     = 'C003'
                      AND PG.Factura  LIKE 'H2%'
                      AND PG.Entrega        = Cart.Asignacion(+)
                    GROUP BY PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Tipo_Docto, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD
               ) Inv ,
               (
                 SELECT PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Clase_Factura, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD, PG.Fecha_Cancelacion,
                        SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Valor_IVA, 0 ) + NVL( PD.Envio_Subt, 0 ) + NVL( PD.Envio_IVA, 0 ) ) AS Importe,
                        MAX( Cart.AccountDocument )                                                                                AS Cartera
                    FROM T3.Preventa_General  PG, T3.Preventa_Detalle PD, 
                         (
                           SELECT Asignacion, Referencia, Cargo, AccountDocument, COUNT(*) AS Cnt_Rec
                              FROM EAI.TaO_Cartera_SAP_Ldr
                              GROUP BY Asignacion, Referencia, Cargo, AccountDocument                  
                         )  Cart
                    WHERE PG.Fecha_Factura >= TRUNC( SYSDATE - 370 )
                      AND PG.Factura        = PD.Factura
                      AND PG.Clase_Factura  = 'C006'
                      AND PG.Factura     LIKE 'L%'
                      AND PG.Entrega        = Cart.Asignacion(+)
                    GROUP BY PG.Factura, PG.Ctro, PG.Fecha_Factura, PG.Fecha_Trn, PG.Clase_Factura, PG.Cliente_SAP, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Proc_BATMD, PG.Fecha_Cancelacion           
               ) ZLOB      
       WHERE SF.Ord_Order_Num  = Inv.Factura(+)        
         AND SF.ZLOB_Reference = ZLOB.Factura(+)     
     ) Info 
    WHERE Info.Inv_Delivery_Status = 'Unsuccessful' ;
