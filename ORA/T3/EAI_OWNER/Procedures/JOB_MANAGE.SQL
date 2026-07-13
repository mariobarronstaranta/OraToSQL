create or replace PROCEDURE             "JOB_MANAGE" 
    ( sAction  VARCHAR2,
      sType    VARCHAR2 )
IS
   sChar       VARCHAR2(10) ;
   nStatus     NUMBER       ;
   dtNextRun   DATE         ;
   dtNextXML   DATE         ;
   bBroken     BOOLEAN      ;
--   
   CURSOR JobTodos IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE 'GEN_REPLICATION%'
            OR UPPER( What ) LIKE 'GEN_OUTBOUND_XML%' 
            OR UPPER( What ) LIKE 'SEND_STAGE_T3%' ; 
--
   CURSOR JobEntregas IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%DELIVERY_CONFIRMATION%' ;
--
   CURSOR JobHandHeld IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%PAYMENT%'
            OR UPPER( What ) LIKE '%PAYMENT_ALLOCATION%'
            OR UPPER( What ) LIKE '%DELIVERY_CONFIRMATION%' 
            OR UPPER( What ) LIKE '%CREDIT_NOTE%' 
            OR UPPER( What ) LIKE '%INVOICE%' ;
--
   CURSOR JobClientes IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%CUSTOMER%' ;
--
   CURSOR JobCadenas IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%ACCOUNT%' ;
--         
   CURSOR JobMovtosProd IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
    --  WHERE UPPER( What ) LIKE '%INTERNAL_ORDER%' ;
        WHERE UPPER( What ) LIKE '%PRODUCT_MOVEMENT%'
           OR UPPER( What ) LIKE '%INTERNAL_ORDER%' ;
--         
   CURSOR JobPedidos IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%RMA_ORDER%'    
            OR UPPER( What ) LIKE '%SALES_ORDER%' ;
--
   CURSOR JobDepositos IS
      SELECT Job                             AS Job       , 
             INSTR( UPPER( What ), '.REP_' ) AS Replicated,
             UPPER( What )                   AS What
         FROM User_Jobs
         WHERE UPPER( What ) LIKE '%BANK_DEPOSIT%' ;
BEGIN
   dtNextRun := SYSDATE   + ( 1 / 2880 ) ;  -- Start on 30 Secound
   dtNextXML := dtNextRun + ( 4 / 2880 ) ;  -- After  2 Minutos for Replication
   sChar     := ';'                      ;
   IF ( sAction = 'Suspend' ) THEN
      nStatus   := 0    ;
      bBroken   := TRUE ;
      dtNextRun := TO_DATE( '40000101', 'YYYYMMDD' ) ;
      dtNextXML := TO_DATE( '40000101', 'YYYYMMDD' ) ;
   ELSE
      nStatus   := 1     ;
      bBroken   := FALSE ;
   END IF ;
--
   IF ( sType = 'Todos' ) THEN
      FOR Jobs IN JobTodos LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'Entregas' ) THEN      
      FOR Jobs IN JobEntregas LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;                  
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'HandHeld' ) THEN      
      FOR Jobs IN JobHandHeld LOOP
         IF ( ( INSTR( Jobs.What, 'RECV_INVOICE' ) = 0 ) AND ( INSTR( Jobs.What, 'RECV_PAYMENT' ) = 0 ) ) THEN
            DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
            COMMIT ;         
            UPDATE EAI_OWNER.MX_Components SET Status = nStatus
              WHERE UPPER( Name ) || sChar = Jobs.What ;
         END IF ;     
      END LOOP ;
   ELSIF ( sType = 'Clientes' ) THEN      
      FOR Jobs IN JobClientes LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'Cadenas' ) THEN      
      FOR Jobs IN JobCadenas LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'MovtosProd' ) THEN      
      FOR Jobs IN JobMovtosProd LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'Pedidos' ) THEN      
      FOR Jobs IN JobPedidos LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   ELSIF ( sType = 'Depositos' ) THEN      
      FOR Jobs IN JobDepositos LOOP
         DBMS_JOB.BROKEN( Jobs.Job, bBroken, 
                  getNextRun( Jobs.Replicated, dtNextRun, dtNextXML ) ); 
         COMMIT ;         
         UPDATE EAI_OWNER.MX_Components SET Status = nStatus
           WHERE UPPER( Name ) || sChar = Jobs.What ;
      END LOOP ;
   END IF ;               
   COMMIT ;    
END ; -- Procedure;
 