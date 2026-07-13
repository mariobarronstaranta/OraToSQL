create or replace PROCEDURE           "WA_RUN_STATEMENTS" 
   ( pLevel   IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrStatements IS
       SELECT Execution_Step, Execution_Statement
          FROM EAI_OWNER.WA_Statements 
          WHERE Execution_Step >= NVL( pLevel, 0 )
          ORDER BY Execution_Step ;
--   
   sErrorCode            VARCHAR2(0030) ;      
   sMsg                  VARCHAR2(0300) ;
   nPedidos              NUMBER(03)     ;
   nPID                  NUMBER(08)     ;
   nProceso              NUMBER(08)     ;
   sReference            VARCHAR2(0050) ;
   sStatement            VARCHAR2(2000) ;
   nSQL_Rows             NUMBER(08)     ;
BEGIN
   nProceso  := 831 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
--
   nPedidos := 0 ;
   FOR Exec IN ScrStatements LOOP
      sReference := 'Step-' || LPAD( Exec.Execution_Step, 4, '0' ) ;
      sStatement := Exec.Execution_Statement ;
      EXECUTE IMMEDIATE ( sStatement ) ;
      nSQL_Rows := SQL%ROWCOUNT ;
      INSERT INTO EAI_OWNER.WA_Logs ( Execution_Date, Execution_Step, Execution_Records )
         VALUES ( SYSDATE, Exec.Execution_Step, nSQL_Rows ) ;
      COMMIT ;   
   END LOOP ;
   COMMIT ; 
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0       ,
                                                 Proceso_3 = 0, Proceso_4 = nPedidos
      WHERE PID = nPID  ;      
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE       , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sReference                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_RUN_STATEMENTS'       , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;   
END WA_RUN_STATEMENTS ;