create or replace PROCEDURE             "JOB_NEXT_DATE" 
   ( P_JOB NUMBER, v_Fecha_Exec IN CHAR ) IS
--
   CURSOR JOB_1 IS
      SELECT JOB FROM USER_JOBS;

BEGIN
   IF ( P_JOB IS NOT NULL ) THEN
      DBMS_JOB.NEXT_DATE( P_JOB, TO_DATE( v_Fecha_Exec, 'dd/mm/yyyy hh24:mi:ss' ) ) ;
   END IF ;
   COMMIT ;
END;

 
 