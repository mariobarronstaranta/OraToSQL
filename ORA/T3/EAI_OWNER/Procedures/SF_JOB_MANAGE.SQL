create or replace PROCEDURE           "SF_JOB_MANAGE" 
    ( sAction  VARCHAR2 )
IS
   sChar             VARCHAR2(10) ;
   nStatus           NUMBER       ;
   dtNextRun         DATE         ;
   dtNextXML         DATE         ;
   bBroken           BOOLEAN      ;
   nJobInvoice       NUMBER(08)   ; 
   nJobIntercompany  NUMBER(08)   ; 
   nJobDelivery      NUMBER(08)   ; 
   nJobPayment       NUMBER(08)   ; 
   nJobCustomer      NUMBER(08)   ;
BEGIN
   dtNextRun := SYSDATE   + ( 1 / 2880 ) ;  -- Start on 30 Secound
   sChar     := ';'                      ;
   SELECT
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Invoice'      ) AS Invoice     ,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Intercompany' ) AS Intercompany,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Delivery'     ) AS Delivery    ,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Payment'      ) AS Payment     ,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Customer'     ) AS Customer
          INTO nJobInvoice, nJobIntercompany, nJobDelivery, nJobPayment, nJobCustomer          
       FROM DUAL ;
   IF ( sAction = 'Suspend' ) THEN
      nStatus   := 0    ;
      bBroken   := TRUE ;
      dtNextRun := TO_DATE( '40000101', 'YYYYMMDD' ) ;
   ELSE
      nStatus   := 1     ;
      bBroken   := FALSE ;
   END IF ;
--
   DBMS_JOB.BROKEN( nJobInvoice     , bBroken, dtNextRun ); 
   DBMS_JOB.BROKEN( nJobIntercompany, bBroken, dtNextRun ); 
   DBMS_JOB.BROKEN( nJobDelivery    , bBroken, dtNextRun ); 
   DBMS_JOB.BROKEN( nJobPayment     , bBroken, dtNextRun ); 
   DBMS_JOB.BROKEN( nJobCustomer    , bBroken, dtNextRun ); 
   COMMIT ;    
END ; -- Procedure;