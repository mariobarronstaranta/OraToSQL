create or replace PROCEDURE    "PROC_CFDI_LIBERACION_PAGO" 
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(030) ;
   nRetGenTxt      NUMBER(06)    ;
--   
   strID           VARCHAR2(050) ;
   dtInicio        DATE          ;
   nPID            NUMBER(08)    ;
   nProceso        NUMBER(08)    ;
   nProceso1       NUMBER(08)    ;
   nProceso2       NUMBER(08)    ;
   nProceso3       NUMBER(08)    ;
   nProceso4       NUMBER(08)    ;
   sOrder_Num      VARCHAR2(30)  ;
   sCadenaOriginal VARCHAR2(60)  ;
   sSelloDigital   VARCHAR2(60)  ;
--
   CURSOR ScrPrompt IS
     SELECT  /*+ Index( Cobza CFDI_COBRANZA_IX2 ) Index (cobza CFDI_COBRANZA_IX2)*/
             Cobza.Asignacion_ID, Cobza.Importe, Cobza.Saldo_Anterior, Cobza.Numero_Pago, Cobza.Factura, Cobza.Accnt_ID,
             Cobza.RFC, Cobza.Fecha_Proc_BATMD, Cobza.Fecha_Proceso, Cobza.Via_Pago, Cobza.Fecha_Factura, Cobza.Fecha_Asignacion, 
             CFD.Status, CFD.Metodo_Pago, Cobza.Fecha_Pago, Cobza.Cliente_SAP,
             NVL( Vers.VerCFD, EAI_Owner.getConv( 'CFG Settings', 'VersionCFDI' ) ) AS VersionCFD
        FROM T3.CFDI_Cobranza   Cobza,
             T3.CFDI_Documentos CFD  ,
             ( SELECT RFC, MAX( Valor ) AS VerCFD
                  FROM T3.CFDI_RFC_Setting
                  WHERE Parametro = 'VersionCFDI'
                  GROUP BY RFC ) Vers             
       WHERE NVL( TO_CHAR( Cobza.Fecha_Envio, 'YYYYMMDD' ), 'null' ) = 'null'
         AND Cobza.Via_Pago    = '01'
         AND Cobza.UUID_Venta IS NOT NULL
         AND Cobza.Created_By != 'INTERFACE'
         AND Cobza.Nota_Venta  = CFD.Nota_Venta
         AND Cobza.Fecha_Pago >= TO_DATE( '20200921', 'YYYYMMDD' ) 
         AND CFD.Metodo_Pago  != 'PUE'
         AND Cobza.RFC         = Vers.RFC(+)
         AND NVL( Cobza.Status, 'EMPTY' ) != 'PendienteT3'
         AND NVL( Cobza.Status, 'EMPTY' ) != 'Canc Pago'
         AND T3.FN_VALIDA_RFC( Cobza.RFC ) > 0
         AND Cobza.Asignacion_ID NOT IN (
                    SELECT DISTINCT Referencia FROM T3.RF_Error_Log
                       WHERE Referencia IS NOT NULL
                         AND RUTINA LIKE '%GENERAR_PAGO%' ) ;
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 613 ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   FOR Doc IN ScrPrompt LOOP   
      strID     := Doc.Factura   ;
      nProceso1 := nProceso1 + 1 ;
--    PROC_CFDI_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
--    PROC_V33_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
--      T3.PROC_CFDI_GENERAR_PAGO( Doc.Asignacion_ID, Doc.Accnt_ID, 0 ) ;
      IF ( Doc.VersionCFD = '4.0' ) THEN
         T3.PROC_V20_GENERAR_PAGO( Doc.Asignacion_ID, Doc.Cliente_SAP, 0 ) ;      
      ELSE
         T3.PROC_CFDI_GENERAR_PAGO( Doc.Asignacion_ID, Doc.Cliente_SAP, 0 ) ;      
      END IF ;
      IF ( MOD( nProceso1, 50 ) = 0 ) THEN
          COMMIT ;
      END IF ;
      IF ( nProceso1 = 500 ) THEN
          COMMIT ;
          EXIT ;
      END IF ;
   END LOOP ;
--   IF ( nProceso1 > 0 ) THEN
--      nPID := SEQ_CFD.Nextval ;   
--      INSERT INTO T3.RF_PROCESOS_LOG 
--         ( PID , Proceso , Fecha_Proc_BATMD, Inicio  , Fin    , Proceso_1, Proceso_2, Proceso_3, Proceso_4 )
--      VALUES 
--         ( nPID, nProceso, NULL, dtInicio, SYSDATE, nProceso1, nProceso2, nProceso3, nProceso4 ) ;   
--   END IF ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;         
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_LIBERACION_PAGO' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
--      INSERT INTO T3.RF_ERROR_LOG 
--         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
--      VALUES
--         ( SYSDATE, 'PROC_CFDI_LIBERACION_PAC', strID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                      , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_LIBERACION_PAGO', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_LIBERACION_PAGO ;