create or replace PROCEDURE             "LOG_START" 
( nComponent IN NUMBER
) AS
BEGIN
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 2, Last_Run = SYSDATE
      WHERE Component = nComponent ;
   COMMIT ;      
END LOG_START ;

 
 