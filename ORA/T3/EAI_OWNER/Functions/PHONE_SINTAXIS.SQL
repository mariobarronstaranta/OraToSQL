create or replace FUNCTION             "PHONE_SINTAXIS" 
  ( pPhoneNumber    IN VARCHAR2,
    pPhoneType      IN VARCHAR2  )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(50)   ;
   sPhoneNumber VARCHAR2(50)   ;
   nLength      NUMBER(04)     ;
--    
BEGIN
   sPhoneNumber := TRIM( pPhoneNumber )   ;
   sPhoneNumber := REPLACE( sPhoneNumber, '+52', '' ) ;
   nLength      := LENGTH( sPhoneNumber ) ;
--   
   IF    ( pPhoneType = 'P' ) THEN
      IF    ( nLength < 10 ) THEN                                               -- Numero NO valido
         sReturn := '9999999999' ;        
      ELSIF ( nLength = 10 ) THEN                                               -- LADA + Numero
         sReturn := sPhoneNumber ;
      ELSE                                                                      -- Mas de 13 caracteres 
         sReturn := sPhoneNumber ;                                              -- Revisar si dejamos el valor que tenga
         sReturn := '9999999999' ;        
         sReturn := SUBSTR( sPhoneNumber, 1, 10 ) ;
      END IF ;
   ELSIF ( pPhoneType = 'F' ) THEN
      IF ( ( pPhoneNumber IS NULL ) OR ( nLength = 0 ) ) THEN
         sReturn := '' ;
      ELSE
      -- Mismas validaciones para Fax      
         IF    ( nLength < 10 ) THEN                                               -- Numero NO valido
            sReturn := '9999999999' ;        
         ELSIF ( nLength = 10 ) THEN                                               -- LADA + Numero
            sReturn := sPhoneNumber ;
         ELSE                                                                      -- Mas de 13 caracteres 
            sReturn := sPhoneNumber ;                                              -- Revisar si dejamos el valor que tenga
            sReturn := '9999999999' ;        
            sReturn := SUBSTR( sPhoneNumber, 1, 10 ) ;
         END IF ;
      END IF ;
   ELSE
      sReturn := '' ;
   END IF ;
   IF ( sReturn = '9999999999' ) THEN                                           -- TaO en caso de 9999999999 enviar VACIO
      sReturn := '' ;
   END IF ;
   RETURN sReturn    ;
--
END PHONE_SINTAXIS ;
 