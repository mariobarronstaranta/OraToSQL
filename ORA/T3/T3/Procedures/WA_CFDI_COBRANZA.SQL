create or replace PROCEDURE    "WA_CFDI_COBRANZA" 
   ( pDays     IN  NUMBER DEFAULT 1 )
IS
   sMsg        VARCHAR2(0500) ;
   sErrorCode  VARCHAR2(0030) ; 
   sFactura    VARCHAR2(0020) ;
   nDoctos     NUMBER(08)     ;
   sEtapa      VARCHAR2(0020) ;
   dtInicio    DATE           ;
--
   strID       VARCHAR2(050) ;
   sAccnt_ID   VARCHAR2(050) ;
   sClienteSAP VARCHAR2(010) ;
   nPID        NUMBER(08)    ;
   nProceso    NUMBER(08)    ;
   nProceso1   NUMBER(08)    ;
--   
   CURSOR ScrCursor IS
       SELECT DISTINCT Fecha_Proc_BATMD 
          FROM T3.Asignacion_Pago 
          WHERE Fecha_Trn        >  SYSDATE - NVL( pDays, 1 )
            AND Fecha_Proc_BATMD IS NOT NULL
            AND Fecha_Proc_BATMD <  SYSDATE
          MINUS
          SELECT DISTINCT Fecha_Proc_BATMD 
          FROM T3.CFDI_Cobranza ;
--
BEGIN
   nProceso  := 885 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 0 ;
   FOR Exec IN ScrCursor LOOP
      nProceso1 := nProceso1 + 1 ;
      strID := TO_CHAR( Exec.Fecha_Proc_BATMD, 'YYYYMMDD HH24:MI:SS' ) ;
      --T3.PROC_CFDI_PROCESAR_PAGOS( Exec.Fecha_Proc_BATMD ) ;
      COMMIT ;
   END LOOP ;
-- T3.PROC_CFDI_COBZA_PID( pDays ) ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = 0,
                                                 Proceso_3 =         0, Proceso_4 = 0
       WHERE PID = nPID  ;            
   COMMIT ;   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_CFDI_COBRANZA' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
--      INSERT INTO T3.RF_ERROR_LOG 
--         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
--      VALUES
--         ( SYSDATE, 'WA_CFDI_COBRANZA', strID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID               , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_CFDI_COBRANZA'  , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;
      COMMIT ;
END WA_CFDI_COBRANZA ;