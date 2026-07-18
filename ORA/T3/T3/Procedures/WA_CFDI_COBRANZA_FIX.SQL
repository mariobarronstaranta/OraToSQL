create or replace PROCEDURE    "WA_CFDI_COBRANZA_FIX" 
   ( pDays     IN  NUMBER DEFAULT 1 )
IS
   sMsg         VARCHAR2(0500) ;
   sErrorCode   VARCHAR2(0030) ; 
   sFactura     VARCHAR2(0020) ;
   nDoctos      NUMBER(08)     ;
   sEtapa       VARCHAR2(0020) ;
   dtInicio     DATE           ;
--
   strID        VARCHAR2(050) ;
   sAccnt_ID    VARCHAR2(050) ;
   sClienteSAP  VARCHAR2(010) ;
   nPID         NUMBER(08)    ;
   nProceso     NUMBER(08)    ;
   nProceso1    NUMBER(08)    ;
   nProceso2    NUMBER(08)    ;
   nProceso3    NUMBER(08)    ;
--
   sDoc_Num     VARCHAR2(030) ;
   sCliente_SAP VARCHAR2(030) ;
   nAmount      NUMBER(15,2 ) ;
   nPending     NUMBER(15,2 ) ;
   nPaid        NUMBER(15,2 ) ;
--   
   CURSOR ScrCursorPendiente IS
      SELECT Asignacion_ID, Factura 
         FROM T3.CFDI_Cobranza Cobza
         WHERE Fecha_Proceso             > TO_DATE('20200921', 'YYYYMMDD' )
         --AND Status                   IS NOT NULL
         --AND Status                    = 'PendienteT3'
           AND NVL( Saldo_Anterior, 0 )  = 0 ;
--
   CURSOR ScrCursor IS
       SELECT Cobza.Asignacion_ID, 
              Cobza.Factura, Cobza.Fecha_Factura,
              Cobza.Nota_Venta, Cobza.UUID_Venta, HDP.Nota_Venta_CFDI       
          FROM T3.CFDI_Cobranza             Cobza,
               T3.CFDI_Historia_Docto_PAC   HDP
          WHERE Cobza.Nota_Venta IS NULL
            AND Cobza.Factura     = HDP.Nota_Venta ;
--
   CURSOR ScrUUID IS
       SELECT Cobza.Asignacion_ID, 
              Cobza.Factura, Cobza.Fecha_Factura,
              Cobza.Nota_Venta, Cobza.UUID_Venta, CFD.Folio_Fiscal, CFD.Status
          FROM T3.CFDI_Cobranza             Cobza,
               T3.CFDI_Documentos           CFD
          WHERE Cobza.Nota_Venta   IS NOT NULL
            AND Cobza.UUID_Venta   IS NULL
            AND Cobza.Nota_Venta    = CFD.Nota_Venta
            AND CFD.Folio_Fiscal   IS NOT NULL ;            
--
BEGIN
   nProceso  := 886 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 0 ;
   FOR Exec IN ScrCursor LOOP
      nProceso1 := nProceso1 + 1 ;
      UPDATE T3.CFDI_Cobranza SET Nota_Venta = Exec.Nota_Venta_CFDI
         WHERE Asignacion_ID = Exec.Asignacion_ID ;
   END LOOP ;
   COMMIT ;
--
   nProceso2 := 0 ;
   FOR Exec IN ScrUUID LOOP
      nProceso2 := nProceso2 + 1 ;
      UPDATE T3.CFDI_Cobranza SET UUID_Venta = Exec.Folio_Fiscal
         WHERE Asignacion_ID = Exec.Asignacion_ID ;
   END LOOP ;
   COMMIT ;
--
   nProceso3 := 0 ;
   FOR Doc IN ScrCursorPendiente LOOP
      nProceso3 := nProceso3 + 1 ;
      EAI_OWNER.SF_GET_INVOICE_DATA( Doc.Factura, sDoc_Num, sCliente_SAP, nAmount, nPending, nPaid ) ;
      IF ( nAmount > 0 ) THEN
         UPDATE T3.CFDI_Cobranza SET Saldo_Anterior = nAmount, Status = NULL
            WHERE Asignacion_ID = Doc.Asignacion_ID ;
      END IF ;      
   END LOOP ;
   COMMIT ;
--
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = 0
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
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_CFDI_COBRANZA_FIX' ) ;
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
        ( DIRECTION          , REFERENCE             , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , strID                 , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_CFDI_COBRANZA_FIX', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END WA_CFDI_COBRANZA_FIX ;