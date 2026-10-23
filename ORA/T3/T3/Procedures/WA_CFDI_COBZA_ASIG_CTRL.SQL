create or replace PROCEDURE    "WA_CFDI_COBZA_ASIG_CTRL" 
   ( pDays     IN  NUMBER DEFAULT 1,
     pOutput   IN  NUMBER DEFAULT 0 )
IS
   sMsg        VARCHAR2(0500) ;
   sErrorCode  VARCHAR2(0030) ; 
   sFactura    VARCHAR2(0020) ;
   nDoctos     NUMBER(08)     ;
   sEtapa      VARCHAR2(0020) ;
   dtInicio    DATE           ;
--
   sRFC        VARCHAR2(040) ;
   sAsignacion VARCHAR2(040) ;
   sVia_Pago   VARCHAR2(040) ;
   nCntPagos   NUMBER(6)     ;
--
   strID       VARCHAR2(050) ;
   sAccnt_ID   VARCHAR2(050) ;
   sClienteSAP VARCHAR2(010) ;
   nPID        NUMBER(08)    ;
   nProceso    NUMBER(08)    ;
   nProceso1   NUMBER(08)    ;
   nProceso2   NUMBER(08)    ;
   nProceso3   NUMBER(08)    ;
--   
   CURSOR ScrCursor IS
      SELECT Cobza.RFC, Cobza.Asignacion_Central, Cobza.Via_Pago, COUNT(*) AS CntPagos
         FROM T3.CFDI_Cobranza Cobza,
              (
                SELECT RFC, Asignacion_Central , COUNT( DISTINCT Via_Pago ) 
                   FROM T3.CFDI_Cobranza
                  WHERE Fecha_Proceso       > SYSDATE - pDays
                    AND RFC                != 'XAXX010101000'
                    AND Asignacion_Central IS NOT NULL
                    AND Via_Pago           != 'CM'
                    AND Fecha_Envio        IS NULL
                  GROUP BY RFC, Asignacion_Central
                  HAVING COUNT( DISTINCT Via_Pago ) > 1
              ) Dup
         WHERE Cobza.Fecha_Proceso       > SYSDATE - pDays
           AND Cobza.Asignacion_Central IS NOT NULL
           AND Cobza.Via_Pago           != 'CM'
           AND Cobza.Fecha_Envio        IS NULL
           AND Cobza.RFC                 = Dup.RFC
           AND Cobza.Asignacion_Central  = Dup.Asignacion_Central
           AND LENGTH( Cobza.Asignacion_Central ) > 8
         GROUP BY Cobza.RFC, Cobza.Asignacion_Central, Via_Pago
         ORDER BY Cobza.Asignacion_Central, CntPagos DESC, Via_Pago ;
--
   CURSOR ScrPagos IS
      SELECT Cobza.RowID          AS Cobza_ROWID  ,
             Cobza.Via_Pago       AS Via_Pago     ,
             Cobza.Fecha_Envio    AS Fecha_Envio
         FROM T3.CFDI_Cobranza Cobza
         WHERE Cobza.Fecha_Proceso > SYSDATE - pDays
           AND Cobza.Asignacion_Central = sAsignacion
           AND Cobza.RFC = sRFC ;   
--
BEGIN
   nProceso  := 889 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1   := 0 ;
   nProceso2   := 0 ;
   nProceso3   := 0 ;
   sRFC        := 'Initial' ;
   sAsignacion := 'Initial' ;
   sVia_Pago   := 'Initial' ;
   nCntPagos   := 00        ;
   FOR Exec IN ScrCursor LOOP
      nProceso1 := nProceso1 + 1 ;
      IF ( ( sRFC      != Exec.RFC      ) OR ( sAsignacion != Exec.Asignacion_Central ) ) THEN
          sRFC        := Exec.RFC                ;
          sAsignacion := Exec.Asignacion_Central ;
          sVia_Pago   := Exec.Via_Pago           ;
          nCntPagos   := Exec.CntPagos           ;
      ELSE
         IF ( ( sRFC = Exec.RFC ) AND ( sAsignacion = Exec.Asignacion_Central ) ) THEN
            IF ( nCntPagos > Exec.CntPagos ) THEN
               nProceso2 := nProceso2 + 1 ;
               IF ( NVL( pOutput, 0 ) > 0 ) THEN
                  DBMS_Output.Put_Line( 'Execute WA : ' || sVia_Pago || ' / ' || nCntPagos ) ;
               END IF ;   
               FOR Pagos IN ScrPagos LOOP
                  IF ( Pagos.Via_Pago != sVia_Pago ) THEN
                     nProceso3 := nProceso3 + 1 ;
                     IF ( Pagos.Fecha_Envio IS NULL ) THEN      
                         UPDATE T3.CFDI_Cobranza Cobza SET Cobza.Fecha_Envio = SYSDATE
                            WHERE Cobza.ROWID = Pagos.Cobza_ROWID ;
                         IF ( NVL( pOutput, 0 ) > 0 ) THEN   
                            DBMS_Output.Put_Line( 'ROWID : ' || Pagos.Cobza_ROWID ) ;   
                         END IF ;   
                     END IF ;
                  END IF ;
               END LOOP ;
            END IF ;  
         END IF ;
      END IF ;
      COMMIT ;
   END LOOP ;
-- T3.PROC_CFDI_COBZA_PID( pDays ) ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = 0
       WHERE PID = nPID  ;            
   COMMIT ;   
   IF ( NVL( pOutput, 0 ) > 0 ) THEN
      DBMS_Output.Put_Line( 'Registros       : ' || nProceso1 ) ;
      DBMS_Output.Put_Line( 'Inconsistencias : ' || nProceso2 ) ;
      DBMS_Output.Put_Line( 'Pagos           : ' || nProceso3 ) ;
   END IF ;   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_CFDI_COBZA_ASIG_CTRL' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || strID ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME               , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT              , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                    , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_CFDI_COBZA_ASIG_CTRL', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                     , NULL                , NULL            ) ;
      COMMIT ;
END WA_CFDI_COBZA_ASIG_CTRL ;