create or replace PROCEDURE    "PROC_CFDI_LIBERACION_AGR" 
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(030) ;
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
       SELECT Info.*
          FROM (
                 SELECT Agr.Nota_Venta_CFDI, Agr.Fecha_Registro,
                        DECODE( CFD.Fecha_Liberacion, NULL, 'INSERT', TO_CHAR( CFD.Fecha_Liberacion, 'YYYYMMDD' ) ) AS Enviar
                    FROM T3.CFDI_Agrupado Agr, T3.CFDI_Documentos CFD
                    WHERE Agr.Fecha_Registro  > SYSDATE - 35
                      AND Agr.Nota_Venta_CFDI = CFD.Nota_Venta(+) ) Info
          WHERE Info.Enviar = 'INSERT'           
            AND Info.Nota_Venta_CFDI NOT IN ( SELECT DISTINCT Referencia FROM T3.RF_Error_Log
                                                  WHERE Referencia IS NOT NULL
                                                    AND RUTINA LIKE '%GENERAR_AGR%' ) ;
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 615 ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   FOR Doc IN ScrPrompt LOOP   
      strID     := Doc.Nota_Venta_CFDI ;
      nProceso1 := nProceso1 + 1 ;
--    PROC_CFDI_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
      PROC_V40_GENERAR_AGR( Doc.Nota_Venta_CFDI ) ;
      IF ( MOD( nProceso1, 100 ) = 0 ) THEN
          COMMIT ;
      END IF ;
      IF ( nProceso1 = 800 ) THEN
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
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_LIBERACION_AGR' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      INSERT INTO T3.RF_ERROR_LOG 
         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
      VALUES
         ( SYSDATE, 'PROC_CFDI_LIBERACION_AGR', strID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                     , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_LIBERACION_AGR', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_LIBERACION_AGR ;