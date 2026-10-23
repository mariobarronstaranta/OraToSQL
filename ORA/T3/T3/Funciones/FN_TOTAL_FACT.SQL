create or replace FUNCTION    "FN_TOTAL_FACT" ( 
      sFactura       VARCHAR2 )
RETURN NUMBER IS
   nReturn        NUMBER(18,2);  
   sTotal_Factura NUMBER(18,2);
BEGIN
   nReturn := NULL ;
   SELECT SUM( NVL( Valor_Subt  , 0 ) + NVL( Valor_IVA   , 0 ) + 
               NVL( Envio_Subt  , 0 ) + NVL( Envio_IVA   , 0 ) + 
               NVL( Credito_Subt, 0 ) + NVL( Credito_IVA , 0 )  ) INTO sTotal_Factura
       FROM T3.Registro_Fiscal_Detalle 
       Where Factura = sFactura ;       
   nReturn := sTotal_Factura ;
   RETURN nReturn ;
EXCEPTION 
   WHEN NO_DATA_FOUND THEN
      RETURN 0 ;
END FN_TOTAL_FACT ;