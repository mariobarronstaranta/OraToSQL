create or replace PROCEDURE           INVOICE_FIX_TAX
   ( sInvoiceID   IN   VARCHAR2 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   nItems          NUMBER(4)     ;
--
   CURSOR ScrValida IS
      SELECT Clase_Factura
         FROM T3.Preventa_General
         WHERE Factura = sInvoiceID ;
--
   CURSOR ScrItems IS
       SELECT Info.*
          FROM (
                 SELECT Factura, Num_Linea, Material, Cantidad_Vta, Valor_Subt, Valor_IVA,
                     ROUND( Valor_IVA * 100 / Valor_Subt, 0 ) AS Tasa,
                     ROUND( Valor_Subt * ROUND( Valor_IVA * 100 / Valor_Subt, 0 ) / 100, 2 ) AS calculo_IVA
                     FROM T3.Preventa_Detalle
                     WHERE Factura = sInvoiceID
                ) Info   
          WHERE Info.Valor_IVA != Info.calculo_IVA ;
BEGIN
   v_ID      := sInvoiceID ;
   nItems    := 0          ;
   FOR Doc IN ScrValida LOOP
      IF ( Doc.Clase_Factura IN ( 'C020', 'C021', 'C022', 'C025' ) ) THEN
         FOR Item IN ScrItems LOOP
            nItems := nItems + 1 ;
            UPDATE T3.Preventa_Detalle  SET  Valor_IVA = Item.calculo_IVA
               WHERE Factura   = Item.Factura
                 AND Num_Linea = Item.Num_Linea ;
         END LOOP ;
      END IF ;
   END LOOP ;   
   IF ( nItems > 0 ) THEN
      UPDATE T3.Preventa_General PG SET ( Valor_Subt, Valor_IVA ) = 
         ( SELECT SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Envio_Subt, 0 ) ) AS Valor_Subt,
                  SUM( NVL( PD.Valor_IVA , 0 ) + NVL( PD.Envio_IVA , 0 ) ) AS Valor_IVA
           FROM T3.Preventa_Detalle PD
              WHERE PD.Factura = PG.Factura )
          WHERE PG.Factura = sInvoiceID ;     
   END IF ;
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
        ( 'INVOICE_FIX_TAX'  , v_ID           , SYSDATE             , NULL           ,
          'Error'            , 'Invoice to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_FIX_TAX ;