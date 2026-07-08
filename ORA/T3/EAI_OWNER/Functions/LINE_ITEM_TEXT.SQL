create or replace FUNCTION             "LINE_ITEM_TEXT" 
  ( pLineItem IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(50)   ;
   sPhoneNumber VARCHAR2(50)   ;
   nLength      NUMBER(04)     ;
   sLineItem    VARCHAR2(50)   ;
--    
BEGIN
   sLineItem := TRIM( NVL( pLineItem, '0' ) ) ;
   nLength   := INSTR( sLineItem, '/' ) ;
--   
   IF ( nLength = 0 ) THEN
     sReturn := sLineItem ; 
   ELSE  
     sReturn := SUBSTR( sLineItem, nLength + 1, 10 ) ;
   END IF ;
   RETURN sReturn    ;
--
END LINE_ITEM_TEXT ;
 