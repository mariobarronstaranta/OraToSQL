create or replace PROCEDURE  WA_SEARCH_INVOICE_CANCEL
  ( sSAPOrder     IN  VARCHAR2,
    sSAPInvoice   IN  VARCHAR2,
    sFolioFiscal  OUT VARCHAR2  )
   IS
   CURSOR ScrDoctos IS
      SELECT 'PG' AS Docto, PG.Factura, PG.Entrega, PG.Pedido, PG.Referencia, PG.Fecha_Cancelacion, PG.Fecha_Proc_BATMD
      FROM (
             SELECT PG.Factura, PG.Pedido
             FROM T3.Preventa_General PG
             WHERE PG.Factura LIKE 'FPIN%'
             UNION
             SELECT PG.Factura, PG.Pedido
             FROM T3.Preventa_General PG
             WHERE PG.Factura LIKE 'FNIN%'
           ) Doc,
           T3.Preventa_General PG
      WHERE Doc.Pedido  = sSAPOrder
        AND Doc.Factura = PG.Factura ;
--        
   sRow_ID   VARCHAR2(50) ;         
   sRowID    VARCHAR2(50) ;         
BEGIN
   FOR Vta IN ScrDoctos LOOP
      sFolioFiscal := Vta.Factura ;
      IF ( Vta.Fecha_Cancelacion IS NULL ) THEN
         IF ( Vta.Docto = 'PG' ) THEN
            EAI.UPDATE_FACT_CANCEL( sFolioFiscal ) ;
         END IF ;
      END IF ;
   END LOOP ;   
   COMMIT ;      
END WA_SEARCH_INVOICE_CANCEL ;