create or replace FUNCTION           "GET_T3_ENABLE_EXECUTE" 
  ( sDefaultValue  IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn        VARCHAR2(03) ;
   nCompT3In      NUMBER(03)   ;
   nCompRunning   NUMBER(03)   ;
   nJobsT3In      NUMBER(03)   ;
   nJobsRunning   NUMBER(03)   ;   
--   
BEGIN
   sReturn := sDefaultValue ;
   SELECT SUM( NVL( CompT3In   , 0 ) )  AS CompT3In   ,
          SUM( NVL( CompRunning, 0 ) )  AS CompRunning,
          SUM( NVL( JobsT3In   , 0 ) )  AS JobsT3In   ,
          SUM( NVL( JobsRunning, 0 ) )  AS JobsRunning
          INTO nCompT3In, nCompRunning, nJobsT3In, nJobsRunning
   FROM (
          SELECT SUM( 1 )                                                       AS CompT3In   ,
                 SUM( DECODE( Status, 1, 0, 1 ) )                               AS CompRunning,
                 SUM( 0 )                                                       AS JobsT3In   ,
                 0                                                              AS JobsRunning
          FROM EAI_Owner.MX_Components
          WHERE Component BETWEEN  300  AND  312
          UNION ALL
          SELECT 0                                                              AS CompT3In   ,
                 0                                                              AS CompRunning,
                 SUM( 1 )                                                       AS JobsT3In   ,
                 SUM( DECODE( TO_CHAR( UJ.Next_Date, 'YYYY' ), '4000', 0, 1 ) ) AS JobsRunning
          FROM User_Jobs UJ
          WHERE UJ.What LIKE '%RECV_TO_SEND_V3%'
        ) Info ;    
--
   IF ( nJobsT3In = 0 ) THEN
       IF ( nCompT3In = 0 ) THEN
          sReturn := 'YES' ; 
       ELSIF ( nCompRunning > 0 ) THEN
          sReturn := 'NO'  ; 
       END IF ;
   ELSE
       IF ( nJobsT3In = 0 ) THEN
          sReturn := 'YES' ; 
       ELSIF ( nJobsRunning > 0 ) THEN
          sReturn := 'NO'  ; 
       END IF ;
   END IF ;
--
   RETURN sReturn    ;
--
EXCEPTION
   WHEN OTHERS THEN
      RETURN ( sDefaultValue ) ;
END ;