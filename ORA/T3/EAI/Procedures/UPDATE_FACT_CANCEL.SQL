create or replace PROCEDURE       "UPDATE_FACT_CANCEL" 
   ( t_Factura IN VARCHAR2 ) IS
   CURSOR ScrDoc IS
      SELECT Factura, Clase_Factura
         FROM T3.Preventa_General
         WHERE Factura = t_Factura ;
BEGIN
   FOR Doc IN ScrDoc LOOP
      UPDATE T3.Preventa_General SET Anulada           = 'S',
                                     Fecha_Cancelacion = SYSDATE
         WHERE Factura            = Doc.Factura
           AND Fecha_Cancelacion IS NULL ;
      IF ( Doc.Clase_Factura IN ( 'C019', 'C0FX', 'C020', 'C021', 'C022' ) ) THEN
         T3.PROC_CFDI_INSERTAR_CANCEL( Doc.Factura ) ;
      END IF ;
   END LOOP ;     
   INSERT INTO DEBUG_T3 ( Fecha, Factura, Pedido, Cliente_SAP, Comentario )
         VALUES ( SYSDATE, t_Factura, 'UpdFactCanc', NULL, 'Cancelacion' ) ;   
END Update_Fact_Cancel ;
 