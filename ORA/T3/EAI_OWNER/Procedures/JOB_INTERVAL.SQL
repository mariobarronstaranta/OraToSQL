create or replace PROCEDURE             "JOB_INTERVAL" 
    ( pJobNo     NUMBER,
      pInterval  VARCHAR2 )
IS
BEGIN
   DBMS_JOB.Interval( pJobNo, pInterval );
   COMMIT ;   
END ; -- Procedure;
 