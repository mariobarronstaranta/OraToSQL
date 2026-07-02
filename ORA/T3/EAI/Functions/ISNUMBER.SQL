create or replace FUNCTION       "ISNUMBER" ( sValue varchar2)
RETURN VARCHAR2 IS
BEGIN
   IF ( sValue IS NULL ) THEN
      RETURN 'F' ;
   END IF ;
   FOR Aux IN 1..LENGTH( sValue ) LOOP
      IF NOT( ( ASCII( SUBSTR( sValue, Aux, 1 ) ) >= 48 ) AND ( ASCII( SUBSTR( sValue, Aux, 1 ) ) <= 57 ) ) THEN
         RETURN 'F' ;
      END IF ;
   END LOOP ;
   RETURN 'T' ;
END ;

 
 