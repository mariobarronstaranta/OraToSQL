create or replace FUNCTION      "FN_VALIDA_RFC" 
   ( sRFC   VARCHAR2 )  RETURN  NUMBER
IS
   nReturn    NUMBER(1);
   sFunction  VARCHAR2(15) ;
   nIndex     NUMBER(2) ;
   nDigits    NUMBER(2) ;
   nChars     NUMBER(2) ;
   nCharX     NUMBER(2) ;
BEGIN
   IF sRFC IS NULL THEN
      RETURN ( 0 ) ;
   END IF ;
   nReturn   := 0 ;
   sFunction := TRIM( sRFC ) ;
   nIndex    := 0 ;
   nDigits   := 0 ;
   nChars    := 0 ;
   nCharX    := 0 ;
   LOOP
      nIndex := nIndex + 1 ;
	  IF ( nIndex > LENGTH( sFunction ) ) THEN
         nIndex := nIndex - 1 ;
	     EXIT ;
	  END IF ;	  
	  IF ( INSTR( '0123456789', SUBSTR( sFunction, nIndex, 1 ) ) > 0 ) THEN
         nDigits := nDigits + 1 ;	  
      END IF ;	  	  
      IF ( INSTR( 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', UPPER( SUBSTR( sFunction, nIndex, 1 ) ) ) > 0 ) THEN
	     nChars := nChars + 1 ;
      END IF ;	   	  
      IF ( INSTR( 'X', UPPER( SUBSTR( sFunction, nIndex, 1 ) ) ) > 0 ) THEN
	     nCharX := nCharX + 1 ;
      END IF ;	   	  
   END LOOP ;
   IF ( nDigits >= 6 ) AND ( nChars >= 3 ) AND ( nIndex IN ( 12, 13 ) ) THEN
      nReturn := 1 ;    
   END IF ; 
   IF ( nCharX >= 3 ) THEN
      nReturn := -1 ;    
   END IF ;
   RETURN ( nReturn ) ;
END FN_VALIDA_RFC ;