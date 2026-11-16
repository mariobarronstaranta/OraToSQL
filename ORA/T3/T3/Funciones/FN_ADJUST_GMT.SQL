create or replace FUNCTION    "FN_ADJUST_GMT" 
   ( p_Time        IN  VARCHAR2,
     p_Hours       IN  NUMBER DEFAULT 0 )
RETURN VARCHAR2 IS
    dtDateOriginal   DATE ;
    dtDateCalculated DATE ;
    sReturn          VARCHAR2(10) ;
BEGIN
   dtDateOriginal   := TO_DATE( TO_CHAR( SYSDATE, 'YYYYMMDD' ) || p_Time, 'YYYYMMDDHH24:MI:SS' ) ;
   dtDateCalculated := dtDateOriginal + ( NVL( p_Hours, 0 ) / 24 ) ;
   
   IF ( TRUNC( dtDateOriginal ) != TRUNC( dtDateCalculated ) ) THEN
       sReturn := p_Time ;
       sReturn := '00:00:01' ;
   ELSE
       sReturn := TO_CHAR( dtDateCalculated, 'HH24:MI:SS' ) ;
   END IF ;
   RETURN sReturn ;
END FN_ADJUST_GMT ;