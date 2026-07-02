create or replace PROCEDURE     CC_STOCK_SAP IS
    v_ID              VARCHAR2(050) ;       
    sMsg              VARCHAR2(500) ;   
    sErrorCode        VARCHAR2(020) ;
    nProceso          NUMBER(08)    ;
    nPID              NUMBER(08)    ;
    nProceso4         NUMBER(08)    ;
BEGIN
   nProceso  := 721 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;
 -- EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.REPORTE_STOCK_TAO' ) ;
    UPDATE EAI.T3R_REPORTE_STOCK_TaO SET Ubicacion = SUBSTR( Partner_Name, 15, 4 ) ;
    nProceso4 := SQL%ROWCOUNT ;
    COMMIT ;
--  Rep Dummy ( Free of Charge )
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_4 = nProceso4
       WHERE PID = nPID  ; 
   COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                 , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME         , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT        , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'CifrasControl'    , v_ID               , SYSDATE             , NULL           , nPID,
            'Error'            , 'CC_STOCK_SAP'     , sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL               , NULL                , NULL             ) ;
        COMMIT ;   
END CC_STOCK_SAP ;