create or replace PROCEDURE    "PROC_CFDI_LIBERACION_PAC" 
    ( pPOD_Release IN VARCHAR2  DEFAULT 'NO' )
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
   sAddenda        VARCHAR2(03)  ;
   dtFechaRollout  DATE          ;
--
   CURSOR ScrPrompt IS
       SELECT 
              FG.Factura, PAC.Fecha_Liberacion, Cte.Cliente_SAP AS Accnt_ID ,
              ABS( TRUNC( SYSDATE ) - FG.Fecha_Factura ) +
              ( NVL( Cte.Dias_Cdto, 0 ) * NVL( Eval.Factor, 1 ) ) +
              NVL( Lib.Dias_Cdto, 0 )                 AS Dias_Cdto          ,
              T3.FN_ADDENDA_PARAM( Cte.RFC, 'VENTA' ) AS Addenda_Venta      ,
              T3.FN_ADDENDA_PARAM( Cte.RFC, 'FASES' ) AS Addenda_Fases      ,
              CteX.Attrib_34                          AS Fecha_Rollout      ,
              FG.Fecha_Factura                        AS Fecha_Documento
       FROM ( 
              SELECT DISTINCT Fecha_Proc_BATMD
                 FROM T3.RF_PROCESOS_LOG
                 WHERE Proceso = 601
                   AND Inicio > TRUNC( SYSDATE - 1 )
              ) Ejec,
            T3.Factura_General           FG  ,
            T3.CFDI_Historia_Docto_PAC   Env ,
            T3.CFDI_Documentos           PAC ,
            T3.Cliente                   Cte ,
            T3.TMD_Email                 CteX,
                          (
                            SELECT RFC, MAX( Valor ) AS Dias_Cdto
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'Libera_Auto'
                                GROUP BY RFC ) Lib,
                          (
                            SELECT RFC, MAX( Valor ) AS Factor
                                FROM T3.CFDI_RFC_Setting
                                WHERE Parametro = 'Bloquea_LibCredito'
                                GROUP BY RFC ) Eval
       WHERE FG.Fecha_Trn        > SYSDATE - 4
         AND FG.Fecha_Proc_BATMD = Ejec.Fecha_Proc_BATMD
         AND FG.Factura          = Env.Nota_Venta
         AND FG.Factura          = Env.Nota_Venta_CFDI
         AND FG.Factura          = PAC.Nota_Venta(+)
         AND PAC.Fecha_Liberacion IS NULL
--       AND FG.Cliente_V3       = Cte.Loc 
         AND FG.Cliente_SAP      = Cte.Cliente_SAP
         AND FG.Fecha_Factura   BETWEEN Cte.Fecha_Ini_Vig and Cte.Fecha_Fin_Vig
         AND FG.Cliente_SAP      = CteX.Cliente_SAP(+)
         AND Cte.RFC             = Lib.RFC(+)
         AND Cte.RFC             = Eval.RFC(+)
         AND FG.Tipo_Docto       = 'C003' 
         AND Cte.RFC           NOT IN ( 'XX-SEM980701STA', 'X-TEX9302097F3' )
         AND FG.Factura     NOT IN (
                    SELECT DISTINCT Referencia FROM T3.RF_Error_Log
                       WHERE Referencia IS NOT NULL
                         AND RUTINA LIKE '%GENERAR_MX06%' ) ;
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 603 ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   IF ( NVL( pPOD_Release, 'NO' ) != 'NO' ) THEN
      nProceso4 := 99 ;
   END IF ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;      
   FOR Doc IN ScrPrompt LOOP   
      strID     := Doc.Factura       ;
      sAddenda  := Doc.Addenda_Venta ;
      IF ( ( sAddenda = 'SI' ) AND ( Doc.Addenda_Fases = 'SI' ) ) THEN
            IF ( INSTR( Doc.Fecha_Rollout, '/' ) > 0 ) THEN
               dtFechaRollout := TO_DATE( Doc.Fecha_Rollout, 'DD/MM/YYYY' ) ;
               IF ( Doc.Fecha_Documento >= dtFechaRollout ) THEN
                  sAddenda := 'SI' ;
               ELSE
                  sAddenda := 'NO' ;               
               END IF ;   
            ELSE
               sAddenda := 'NO' ;               
            END IF ;
      END IF ;      
      IF ( sAddenda = 'NO' ) THEN
        IF ( Doc.Dias_Cdto > 0 ) THEN
         -- PROC_VSF_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
            PROC_V40_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
            nProceso1 := nProceso1 + 1 ;
        ELSIF ( UPPER( NVL( pPOD_Release, 'NO' ) ) != 'NO' ) THEN
            PROC_V40_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
            nProceso1 := nProceso1 + 1 ;
        END IF ;    
      ELSE 
         IF ( UPPER( NVL( pPOD_Release, 'NO' ) ) != 'NO' ) THEN
         -- PROC_VSF_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
            PROC_V40_GENERAR_MX06( Doc.Factura, Doc.Accnt_ID ) ;
            nProceso1 := nProceso1 + 1 ;
         -- DBMS_Output.Put_Line( Doc.Factura ) ;
         END IF ;
      END IF ;
      IF ( MOD( nProceso1, 100 ) = 0 ) THEN
          COMMIT ;
      END IF ;
      IF ( nProceso1 = 1500 ) THEN
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
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_LIBERACION_PAC' ) ;
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
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                     , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_LIBERACION_PAC', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_LIBERACION_PAC ;