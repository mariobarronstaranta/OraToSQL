create or replace PROCEDURE    "PROC_CFDI_LIBERA_PAGO_CENTRAL" 
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
   nItems          NUMBER(06)    ;
   nUUIDs          NUMBER(06)    ;
--
   CURSOR ScrCentral IS
      SELECT NVL( Vers.VerCFD, EAI_Owner.getConv( 'CFG Settings', 'VersionCFDI' ) ) AS VersionCFD, Agr.* 
         FROM T3.CFDI_Agrupacion_CTRL Agr,
             ( SELECT RFC, MAX( Valor ) AS VerCFD
                  FROM T3.CFDI_RFC_Setting
                  WHERE Parametro = 'VersionCFDI'
                  GROUP BY RFC ) Vers       
         WHERE Agr.Fecha_Pago  >= TO_DATE( '20220101', 'YYYYMMDD' )
           AND Agr.RFC          = Vers.RFC(+)
           AND Agr.Fecha_Envio IS NULL ;
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 614 ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   FOR Doc IN ScrCentral LOOP   
      strID  := Doc.Agrupacion   ;
      nItems := 0 ;
      nUUIDs := 0 ;
      PROC_CFDI_LIBERA_PAGO_CHECK( Doc.Agrupacion, nItems, nUUIDs ) ; 
      IF ( ( nItems > 0 ) AND ( nItems = nUUIDS ) ) THEN
         nProceso1 := nProceso1 + 1 ;
         IF ( Doc.VersionCFD = '4.0' ) THEN
            T3.PROC_V20_GENERAR_PAGO_AGR( Doc.Agrupacion ) ;
         ELSE
            T3.PROC_CFDI_GENERAR_PAGO_AGR( Doc.Agrupacion ) ;
         END IF ;
         IF ( MOD( nProceso1, 10 ) = 0 ) THEN
             COMMIT ;
         END IF ;    
      END IF ;
      IF ( nProceso1 = 1000 ) THEN
          COMMIT ;
          EXIT ;
      END IF ;
   END LOOP ;
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
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_LIBERA_PAGO_CENTRAL' ) ;
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
        ( DIRECTION          , REFERENCE                     , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                    , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                   , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                          , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_LIBERA_PAGO_CENTRAL', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                           , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_LIBERA_PAGO_CENTRAL ;