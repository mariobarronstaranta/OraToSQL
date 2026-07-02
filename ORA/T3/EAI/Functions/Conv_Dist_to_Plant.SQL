create or replace FUNCTION     "CONV_DIST_TO_PLANT" 
   ( sDist VARCHAR2 )  RETURN  VARCHAR2
IS
   sReturn     VARCHAR2(04) ;
   sReturnRet  VARCHAR2(10) ;
BEGIN
   SELECT EAI_Owner.getConv( 'T3 Dist to Plant', sDist ) AS ConvCode
      INTO sReturnRet
      FROM DUAL ;
   IF ( sReturnRet = sDist ) THEN
      sReturn := '    '     ;
   ELSE
      sReturn := sReturnRet ;
   END IF ;    
   RETURN sReturn ;
END Conv_Dist_to_Plant ;