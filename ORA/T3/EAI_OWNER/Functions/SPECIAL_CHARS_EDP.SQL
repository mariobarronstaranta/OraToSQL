create or replace FUNCTION             "SPECIAL_CHARS_EDP" 
  ( pSTRING     IN VARCHAR2 )
RETURN VARCHAR IS
   sSTRING      VARCHAR2(1000)  ;
BEGIN
   sSTRING := pSTRING ;
   sSTRING := REPLACE( sSTRING, 'ñ', 'n' ) ;
   sSTRING := REPLACE( sSTRING, 'Ñ', 'N' ) ;
--  
   sSTRING := REPLACE( sSTRING, 'á', 'a' ) ;
   sSTRING := REPLACE( sSTRING, 'Á', 'A' ) ;
   sSTRING := REPLACE( sSTRING, 'é', 'e' ) ;
   sSTRING := REPLACE( sSTRING, 'É', 'E' ) ;
   sSTRING := REPLACE( sSTRING, 'í', 'i' ) ;
   sSTRING := REPLACE( sSTRING, 'Í', 'I' ) ;
   sSTRING := REPLACE( sSTRING, 'ó', 'o' ) ;
   sSTRING := REPLACE( sSTRING, 'Ó', 'O' ) ;
   sSTRING := REPLACE( sSTRING, 'ú', 'u' ) ;
   sSTRING := REPLACE( sSTRING, 'Ú', 'U' ) ;
--
   sSTRING := REPLACE( sSTRING, '"', CHR(39) ) ;
   sSTRING := REPLACE( sSTRING, ';', ' ' ) ;
--
   sSTRING := REPLACE( sSTRING, '|', ' ' ) ;
   sSTRING := REPLACE( sSTRING, '°', 'o' ) ;
   sSTRING := REPLACE( sSTRING, 'º', 'o' ) ;   
--
   sSTRING := REPLACE( sSTRING, 'ª', 'a' ) ;
   sSTRING := REPLACE( sSTRING, 'Ò', 'O' ) ;
   sSTRING := REPLACE( sSTRING, 'À', 'A' ) ;   
   sSTRING := REPLACE( sSTRING, '&', ' ' ) ;   
   RETURN sSTRING     ;
--
END SPECIAL_CHARS_EDP ;