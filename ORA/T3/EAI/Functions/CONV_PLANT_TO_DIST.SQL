create or replace FUNCTION     "CONV_PLANT_TO_DIST" 
   ( sPlant IN VARCHAR2 )  RETURN  NUMBER
IS
   nReturn    NUMBER(4) ;
   sReturn    VARCHAR2(10) ;
BEGIN
   SELECT EAI_Owner.getConv( 'T3 Plant to Dist', sPlant ) AS ConvCode
      INTO sReturn
      FROM DUAL ;
--
   IF ( sReturn = sPlant ) THEN
      nReturn := 0       ;
   ELSE
      nReturn := sReturn ;
   END IF ;    
   RETURN nReturn ;
END ;