--------------------------------------------------------
--  DDL for Function SEPARADIRECCION
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "T3"."SEPARADIRECCION" (
     sAddr_Name  VARCHAR2,
     sCampo      VARCHAR2 ) RETURN VARCHAR2 
IS
   sReturn    VARCHAR2(100) ;   
   sCalle     VARCHAR2(100) ;   
   sExterno   VARCHAR2(100) ;
   sColonia   VARCHAR2(100) ;   
   nLongitud  NUMBER(2)    ;   
--   
BEGIN
   sCalle   := '' ;
   sExterno := '' ;
   sColonia := '' ;
   nLongitud := INSTR( sAddr_Name, '#' ) ;
   IF ( nLongitud > 0 ) THEN
      sCalle    := SUBSTR( sAddr_Name, 1, nLongitud - 1) ;      
      sReturn   := SUBSTR( sAddr_Name, nLongitud, 100 ) ;
      nLongitud := INSTR( sReturn, '|' ) ;      
      IF ( nLongitud > 0 ) THEN
         sExterno := SUBSTR( sReturn, 1, nLongitud - 1  ) ;
         sColonia := SUBSTR( sReturn, nLongitud + 1, 99 ) ;         
      ELSE
         sExterno := sReturn ;                          -- Sin Colonia
      END IF ;
   ELSE
      sCalle   := sAddr_Name ;      
      sExterno := '' ;
      sColonia := '' ;
   END IF ;
   IF ( sCampo = 'Calle' ) THEN
      sReturn := sCalle   ;
   ELSIF ( sCampo = 'Num' ) THEN
      sReturn := sExterno ;
      IF ( SUBSTR( sReturn, 1, 1 ) = '#' ) THEN
            sReturn := TRIM( SUBSTR( sReturn, 2, 100 ) ) ;
      END IF ;            
   ELSIF ( sCampo = 'Col' ) THEN
      sReturn := sColonia ;
   END IF ;
   sReturn := TRIM( sReturn ) ;
   RETURN sReturn ;
END ;
 

/

  GRANT EXECUTE ON "T3"."SEPARADIRECCION" TO "LEGV3_SUPPORT";
  GRANT EXECUTE ON "T3"."SEPARADIRECCION" TO "INTEGRATION_ROLE";
  GRANT EXECUTE ON "T3"."SEPARADIRECCION" TO "ITX_DEV";
