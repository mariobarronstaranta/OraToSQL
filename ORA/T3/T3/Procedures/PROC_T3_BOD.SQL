create or replace PROCEDURE    "PROC_T3_BOD" 
( sExecAddenda   IN VARCHAR2 DEFAULT 'YES' ) IS
   v_ID                 VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;      
   sMsg                 VARCHAR2(300) ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;             
   nJobIntercompany     NUMBER(08)    ;
   nJobDelivery         NUMBER(08)    ;
   nJobCustomer         NUMBER(08)    ;
   dtNextRun            DATE          ;
   nAgrupacion          NUMBER(03)    ;
--
   CURSOR ScrAgrupacion IS
      SELECT Inicio, Fin
         FROM T3.RF_Procesos_Log
         WHERE Proceso = '602'
           AND Inicio  > TO_DATE( TO_CHAR( SYSDATE, 'YYYYMMDD' ) || ' 01:00:00', 'YYYYMMDD HH24:MI:SS' ) ;                 
BEGIN
   SELECT
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Intercompany' ) AS Intercompany,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Delivery'     ) AS Delivery    ,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Customer'     ) AS Customer
          INTO nJobIntercompany, nJobDelivery, nJobCustomer          
       FROM DUAL ;
--   
   nProceso  := 835 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
--      
   v_ID := 'Suspend Jobs' ;
   EAI_OWNER.SF_JOB_MANAGE( 'Suspend' ) ;
--   
   v_ID := 'PROC_T3_LANZA_REP' ;
   T3.PKG_T3.PROC_T3_LANZA_REP( NULL ) ;
   COMMIT ;
--
   v_ID := 'Release POD' ;
   T3.PROC_CFDI_LIBERACION_PAC( 'SI' ) ;
   COMMIT ;
--
   v_ID := 'Resume Intercompany' ;
   EAI_OWNER.SF_JOB_MANAGE_EOD( 'Resume' ) ;
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0
       WHERE PID = nPID  ;         
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_T3_BOD'       , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;
      COMMIT ;       
END PROC_T3_BOD ;