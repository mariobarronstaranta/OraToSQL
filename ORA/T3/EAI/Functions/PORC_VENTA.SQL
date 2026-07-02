create or replace FUNCTION       "PORC_VENTA" (
     nValor1  NUMBER  ,     -- Dividendo
     nValor2  NUMBER  ,     -- Divisor
     nValor3  NUMBER        -- Numero de Decimales
   )
RETURN NUMBER IS
  nReturn NUMBER ;
BEGIN
   IF ( NVL( nValor2, 0 ) = 0 ) THEN
      nReturn := 0 ;                                      -- Divisior  CERO
   ELSIF ( NVL( nValor1, 0 ) = 0 ) THEN
      nReturn := 0 ;                                      -- Dividendo CERO
   ELSIF ( nValor1 < 0 ) THEN
--    nReturn := 0 ;                                      -- Dividendo Negativo
      nReturn := ROUND( nValor1 / nValor2, nValor3 ) ;
   ELSIF ( nValor2 < 0 ) THEN
--    nReturn := 0 ;                                      -- Dividendo Negativo
      nReturn := ROUND( nValor1 / nValor2, nValor3 ) ;      
   ELSIF ( nValor1 > 0 ) AND ( nValor2 > 0 ) THEN
      nReturn := ROUND( nValor1 / nValor2, nValor3 ) ;    -- Ok
   END IF ;
   RETURN nReturn ;
END ;

 
 