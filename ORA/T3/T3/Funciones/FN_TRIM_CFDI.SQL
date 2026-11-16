create or replace FUNCTION    "FN_TRIM_CFDI" 
   ( p_Name        IN  VARCHAR2 )
RETURN VARCHAR2
IS
--
-- Variables
    v_Position          NUMBER(3,0)   ;
    p_Parameter         VARCHAR2(200) ;
BEGIN
   p_Parameter := TRIM( NVL( p_Name, '' ) ) ;
--   
   p_Parameter := REPLACE( p_Parameter,    '|', '/' ) ;
   p_Parameter := REPLACE( p_Parameter,    '+',  '' ) ;
   p_Parameter := REPLACE( p_Parameter, CHR(13), '' ) ;
   p_Parameter := REPLACE( p_Parameter, CHR(10), '' ) ;
--   p_Parameter := REPLACE( p_Parameter, CHR(39), '' ) ;
--   p_Parameter := REPLACE( p_Parameter, CHR(34), '' ) ;
   WHILE INSTR( P_Parameter, '  ' ) > 0
   LOOP
      p_Parameter := REPLACE( p_Parameter, '  ', ' ' ) ;
   END LOOP ;
   RETURN p_Parameter ;
END FN_TRIM_CFDI ;