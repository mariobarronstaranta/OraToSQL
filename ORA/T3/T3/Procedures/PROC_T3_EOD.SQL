create or replace PROCEDURE    "PROC_T3_EOD" 
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
--
   CURSOR ScrCredit_Generic IS
       SELECT FG.Factura, FG.Ctro, FG.Fecha_Factura
          FROM T3.Preventa_General FG, T3.Cliente Cte
          WHERE FG.Fecha_Trn          > SYSDATE - 4
            AND FG.Fecha_Proc_BATMD  IS NOT NULL
            AND FG.Fecha_Proc_BATMD   < SYSDATE
            AND FG.Clase_Factura     IN ( 'C006', 'C025' )
            AND FG.Fecha_Cancelacion IS NULL
            AND FG.Cliente_SAP        = Cte.Cliente_SAP
            AND FG.Fecha_Factura     BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
            AND Cte.RFC               = 'XAXX010101000'
            AND FG.Factura NOT IN ( SELECT HDP.Nota_Venta FROM T3.CFDI_Historia_Docto_PAC HDP WHERE HDP.Nota_Venta = FG.Factura )
            AND FG.Factura NOT IN ( SELECT CFD.Nota_Venta FROM T3.CFDI_Documentos CFD WHERE CFD.Nota_Venta = FG.Factura ) ;           
--
   CURSOR ScrEntregas_Facturas IS
        SELECT PG.Factura, PG.Fecha_Factura, PG.Fecha_Proc_BATMD, PG.Clase_Factura, PG.Fecha_Trn, 
               Ent.ReferenceID, Ent.Created
           FROM T3.Preventa_General PG,
                (
                  SELECT ReferenceID, DeliveryType, Order_Num, Created 
                     FROM EAI_Owner.tmp_Document_Header
                     WHERE Created    > SYSDATE - 7
                       AND Order_Num IS NOT NULL
                 ) Ent
           WHERE PG.Fecha_Trn       > SYSDATE - 7
             AND PG.Clase_Factura  IN ( 'C005', 'C006' )
             AND PG.Fecha_Factura   < TRUNC( SYSDATE )
             AND PG.Fecha_Cancelacion IS NULL
             AND PG.Factura       NOT IN ( SELECT Entr.Factura FROM T3.Entrega Entr WHERE Entr.Factura = PG.Factura )
             AND PG.Factura         = Ent.Order_Num  ;             
--
   CURSOR ScrTransactionSeq IS             
          SELECT Factura, Ctro, Fecha_Factura_T3, Paso.RFC_Cliente
             FROM T3.CFDI_Documento_Paso     Paso
             WHERE Paso.Fecha_Proc_BATMD >= TRUNC( SYSDATE - 1 )
               AND Paso.VoidDoc          IS NULL
               AND LENGTH( Paso.Factura ) > 13
               AND Paso.Tipo_Docto      NOT IN ( 'Z024', 'C024' )
               AND INSTR( Paso.Factura, '-' ) = 0
               AND Paso.Factura NOT IN ( SELECT Nota_Venta FROM T3.CFDI_Historia_Docto_PAC WHERE Nota_Venta = Paso.Factura ) ;              
BEGIN
   SELECT
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Intercompany' ) AS Intercompany,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Delivery'     ) AS Delivery    ,
          EAI_Owner.getConv( 'CFG Settings', 'T3In-Job Customer'     ) AS Customer
          INTO nJobIntercompany, nJobDelivery, nJobCustomer          
       FROM DUAL ;
--   
   nProceso  := 834 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
--      
   v_ID := 'Suspend Jobs' ;
   EAI_OWNER.SF_JOB_MANAGE( 'Suspend' ) ;
   
--
   v_ID := 'PROC_T3_SF_MOV_CLIENTE';
   T3.PROC_T3_SF_MOV_CLIENTE(1);
   COMMIT;   
--   
   v_ID := 'Collection' ;
   EAI_OWNER.WA_ACCNT_PAYAMOUNT( 1, -1 );  
   EAI_OWNER.SF_PROC_CENTRAL_EXECUTE ( 2, TO_CHAR( SYSDATE, 'YYYY' ), NULL, 0 ) ;
   COMMIT ;
--
   v_ID := 'Unsuccessful' ;      
   T3.PROC_T3_EOD_NOTDELV( nPID ) ;
   COMMIT ;
--
   v_ID := 'ConfirmSF' ;         
   T3.PROC_T3_EOD_CONF( nPID, 0, 0 ) ;
   COMMIT ;
--   
   v_ID := 'Deliveries' ;
--   FOR Doc IN ScrEntregas_Facturas LOOP
--      EAI_OWNER.INVOICE_TO_ENTREGA( Doc.ReferenceID, 0 ) ;
--   END LOOP ;   
   COMMIT ;
--   
   v_ID := 'Presales Docs' ;
   T3.PROC_T3_DQC_PRESALES( TRUNC( SYSDATE - 1 ), 'UNBLOCK' ) ;
   T3.PROC_T3_DQC_PRESALES( TRUNC( SYSDATE - 0 ), 'BLOCK'   ) ;
   COMMIT ;
   T3.PROC_T3_LIB_PRESALES( TRUNC( SYSDATE - 0 ), 'AUTO'    ) ;
   COMMIT ;
--   
   v_ID := 'PROC_T3_LANZA_REP' ;
   T3.PKG_T3.PROC_T3_LANZA_REP( NULL ) ;
   COMMIT ;
--
   v_ID := 'Release POD' ;
   T3.PROC_CFDI_LIBERACION_PAC( 'SI' ) ;
   COMMIT ;
--
   v_ID := 'PROC_CFDI_PROCESAR_AGRUPADO' ;
   T3.PROC_CFDI_PROCESAR_AGRUPADO( NULL ) ;
   COMMIT ;
--
   IF ( sExecAddenda = 'YES' ) THEN
      T3.PROC_CFDI_LIBERACION_PAC( 'SI' ) ;
      COMMIT ;
   END IF ;
--
   v_ID := 'Folios Duplicados' ;
   nAgrupacion := 0 ;
   FOR Scr IN ScrAgrupacion LOOP
      nAgrupacion := nAgrupacion + 1 ;
      IF ( ( nAgrupacion = 1 ) AND ( Scr.Fin IS NOT NULL ) ) THEN
          INSERT INTO T3.CFDI_Historia_Docto_PAC
           ( Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI  )
          SELECT Factura, Ctro, Fecha_Factura_T3, Factura
             FROM T3.CFDI_Documento_Paso     Paso
             WHERE Paso.Fecha_Proc_BATMD >= TRUNC( SYSDATE - 1 )
               AND Paso.RFC_Cliente       = 'XAXX010101000' 
               AND Paso.VoidDoc          IS NULL
               AND LENGTH( Paso.Factura ) < 13
               AND Paso.Tipo_Docto      NOT IN ( 'Z024', 'C024' )
               AND INSTR( Paso.Factura, '-' ) > 0
               AND SUBSTR( Paso.Factura, 1, 5 ) IN ( SELECT Serie FROM T3.CFDI_EXCLUIR_SERIE )
               AND Paso.Factura NOT IN ( SELECT Nota_Venta FROM T3.CFDI_Historia_Docto_PAC WHERE Nota_Venta = Paso.Factura ) ;        
      END IF ;
   END LOOP ;   
--
   COMMIT ;
   FOR Dev IN ScrCredit_Generic LOOP
      INSERT INTO T3.CFDI_Historia_Docto_PAC
          ( Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI )
      VALUES
          ( Dev.Factura, Dev.Ctro, Dev.Fecha_Factura, Dev.Factura ) ;
      PROC_V40_GENERAR_MX06( Dev.Factura, NULL ) ;        
   END LOOP ;
   COMMIT ;
--
   FOR TSErr IN ScrTransactionSeq LOOP
      INSERT INTO T3.CFDI_Historia_Docto_PAC
          ( Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI )
      VALUES
          ( TSErr.Factura, TSErr.Ctro, TSErr.Fecha_Factura_T3, TSErr.Factura ) ;
      PROC_V40_GENERAR_MX06( TSErr.Factura, NULL ) ;        
   END LOOP ;
   COMMIT ;
--
   T3.WA_MOVE_TO_DIST( 1, 'MX2J' ) ;
   T3.WA_MOVE_TO_DIST( 1, 'MX4H' ) ;
   T3.WA_MOVE_TO_DIST( 1, 'MX1H' ) ;
--
   T3.PROC_CFDI_LIBERACION_NOTA;
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
          'Error'            , 'PROC_T3_EOD'       , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;
      COMMIT ;       
END PROC_T3_EOD ;