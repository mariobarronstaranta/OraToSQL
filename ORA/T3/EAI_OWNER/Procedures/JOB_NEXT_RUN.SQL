create or replace PROCEDURE           "JOB_NEXT_RUN" 
   ( pJOB      NUMBER, 
     pNextRun  DATE ) IS
    bBOOLEAN BOOLEAN ;     
BEGIN
   bBOOLEAN := FALSE ;
   IF ( TO_CHAR( pNextRun, 'YYYY' ) = '4000' ) THEN
      bBOOLEAN := TRUE ;
   END IF ;
   IF ( pJOB IS NOT NULL ) THEN
      DBMS_JOB.Broken( pJOB, bBOOLEAN, pNextRun ) ;
      COMMIT ;
   END IF ;
END;