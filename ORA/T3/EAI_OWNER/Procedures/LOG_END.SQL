create or replace PROCEDURE             "LOG_END" 
( nComponent IN NUMBER,
  dtBegin    IN DATE  ,
  dtEnd      IN DATE  ,
  nRecords   IN NUMBER
) AS
BEGIN
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   INSERT INTO EAI_OWNER.MX_COMPONENT_LOG 
      ( Component, PID, Starting, Ending, Processed )
   VALUES ( nComponent, ProcessID.NextVal, dtBegin, dtEnd, nRecords ) ;
   COMMIT ;
END LOG_END ;

 
 