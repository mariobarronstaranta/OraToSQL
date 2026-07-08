create or replace FUNCTION           WA_DN_SKU
  ( pDebitNote IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(50)   ;
BEGIN
   sReturn := '8800114' ;
   IF    ( SUBSTR( pDebitNote, 1, 3 ) = 'CHP'  ) THEN
      sReturn := '8800111' ;
   ELSIF ( SUBSTR( pDebitNote, 1, 3 ) = 'CHD'  ) THEN
      sReturn := '8800112' ;      
   ELSIF ( SUBSTR( pDebitNote, 1, 2 ) = 'KP'   ) THEN
      sReturn := '8800113' ;      
   ELSIF ( SUBSTR( pDebitNote, 1, 4 ) = 'FNAJ' ) THEN
      sReturn := '8800116' ;      
   ELSIF ( SUBSTR( pDebitNote, 1, 4 ) = 'FPAJ' ) THEN
      sReturn := '8800116' ;      
   END IF ;   
   RETURN sReturn    ;
--
END WA_DN_SKU ;