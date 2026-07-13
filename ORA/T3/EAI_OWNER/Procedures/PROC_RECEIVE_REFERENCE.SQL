create or replace PROCEDURE           PROC_RECEIVE_REFERENCE( 
    sQUEUE_NAME IN VARCHAR2  DEFAULT 'All', 
    nLog        IN NUMBER    DEFAULT 0      ) IS
   v_ID              VARCHAR2(050) ;
   sErrorCode        VARCHAR2(500) ;
   sMsg              VARCHAR2(500) ;
   sPOrderNumber     VARCHAR2(500) ;
   sRow_ID           VARCHAR2(050) ;
   v_Regs            NUMBER ;
   v_SubRegs         NUMBER ;
-- Define Variables
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;      
--   
   CURSOR ScrPRODUCT IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/Product/Message/GeneralData/MaterialNumber')                      AS MaterialNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Product' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--               
   CURSOR ScrPRICE IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/PriceMaster/Message/PriceHeader/MaterialNumber')                  AS MaterialNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Price Master' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--   
   CURSOR ScrCUSTOMER IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/Customer/Message/GeneralData/V3CustomerNumber')                   AS CustomerNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Customer' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--   
   CURSOR ScrCREDIT IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/V3CustomerNumber')             AS CustomerNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Customer' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--   
   CURSOR ScrINVOICE IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/Invoice/Message/InvoiceHeader/DocumentNumber')                    AS DocumentNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Invoice' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--   
   CURSOR ScrINTERCO IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/InvoiceIntercompany/Message/InvoiceHeader/DocumentNumber')        AS DocumentNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'Invoice-Intercompany' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--
   CURSOR ScrORDER IS
        SELECT ROWID AS RL_RowID,
               extractValue( XML_Content, '/OrderAcknowledge/Message/ReferenceData/DocumentNumber')           AS DocumentNumber  
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Queue_Name = 'OrderAcknowledge' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--
   CURSOR ScrREPLENISH_DOC IS
        SELECT ROWID AS RL_RowID, Msg.Row_ID
        FROM EAI_Owner.MX_Receive_Message_Log Msg
        WHERE Queue_Name = 'VanReplenishment' 
          AND DocNum     LIKE '000%' 
          AND Reference  IS NULL     ;
--
   CURSOR ScrREPLENISH IS
        SELECT VALUE( Lista ) AS Item_Content
        FROM EAI_Owner.MX_Receive_Message_Log Msg,
             TABLE( XMLSequence( Extract ( XML_Content, '/VanReplenishment/Message/DeliveryHeader/DeliveryLineItem' ) ) ) Lista
        WHERE Row_ID = sRow_ID ;
BEGIN
   nProceso  := 852 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
--
   IF ( nLog > 0 ) THEN
      DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Product', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrPRODUCT LOOP 
         v_ID := Rec.MaterialNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Product', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Price Master', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrPRICE LOOP 
         v_ID := Rec.MaterialNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Price Master', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Customer', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrCUSTOMER LOOP 
         v_ID := Rec.CustomerNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         IF ( ( LENGTH( v_ID ) = 0 ) OR ( v_ID IS NULL ) ) THEN
            UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE  ,
                                                        Status    = 'Discard',
                                                        Reference = 'NULL'
               WHERE RowID = Rec.RL_RowID ;             
         END IF ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Customer', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Customer Credit', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrCREDIT LOOP 
         v_ID := Rec.CustomerNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
         IF ( ( LENGTH( v_ID ) = 0 ) OR ( v_ID IS NULL ) ) THEN
            UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE  ,
                                                        Status    = 'Discard',
                                                        Reference = 'NULL'
               WHERE RowID = Rec.RL_RowID ;             
         END IF ;
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Customer Credit', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Invoice', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrINVOICE LOOP 
         v_ID := Rec.DocumentNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Invoice', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Invoice-Intercompany', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrINTERCO LOOP 
         v_ID := Rec.DocumentNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Invoice Intercompany', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Order', 'All' ) ) THEN
      v_Regs := 0 ;
      FOR Rec IN ScrORDER LOOP 
         v_ID := Rec.DocumentNumber ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = v_ID
            WHERE RowID = Rec.RL_RowID ;
         v_Regs := v_Regs + 1 ;   
      END LOOP ; 
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Order', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;
--   
   IF ( sQUEUE_NAME IN ( 'Replenishment', 'All' ) ) THEN
         v_Regs := 0 ;
      FOR Doc IN ScrREPLENISH_Doc LOOP    
         v_Regs  := v_Regs + 1 ;
         sRow_ID := Doc.Row_ID ;
         FOR Rec IN ScrREPLENISH LOOP 
              v_SubRegs := 0 ;
               FOR SrcLineRef IN (
                   SELECT 
                          ExtractValue( VALUE( Listing ), '*/Qualifier' )             AS Qualifier          ,
                          ExtractValue( VALUE( Listing ), '*/PurchaseOrderNumber' )   AS PurchaseOrderNumber   
                   FROM -- EAI_Owner.MX_Receive_Message_Log Msg,
                   TABLE ( XMLSequence( Extract ( Rec.Item_Content, '/DeliveryLineItem/DeliveryLineReference' ) ) ) Listing
               )
               LOOP
                   IF ( SrcLineRef.Qualifier = '001' ) THEN
                       sPOrderNumber := SrcLineRef.PurchaseOrderNumber ;
                   ELSIF ( SrcLineRef.Qualifier = '999' ) THEN
                       sPOrderNumber := SrcLineRef.PurchaseOrderNumber ;
                   END IF ;
                   v_SubRegs := v_SubRegs + 1 ;
                   IF ( v_SubRegs = 1 ) THEN
                      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = sPOrderNumber
                          WHERE Row_ID = sRow_ID AND Reference IS NULL ;
                   END IF ;
               END LOOP;         
         END LOOP ;    
      END LOOP ;
      IF ( nLog > 0 ) THEN
         DBMS_OUTPUT.PUT_LINE( RPAD( 'Replenishment', 30, ' ' ) || ' -> ' || v_Regs ) ;
      END IF ;
      nProceso4 := nProceso4 + v_Regs ;
   END IF ;   
--
   IF ( nLog > 0 ) THEN
      DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   END IF ;
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;   
   COMMIT ;      
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                      , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME              , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT             , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                    , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_RECEIVE_REFERENCE', sMsg                , 'XML'          ,
          sErrorCode         , NULL                    , NULL                , NULL            ) ;
      COMMIT ;
END PROC_RECEIVE_REFERENCE ;