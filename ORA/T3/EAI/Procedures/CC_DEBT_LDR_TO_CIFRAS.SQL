create or replace PROCEDURE     "CC_DEBT_LDR_TO_CIFRAS"
IS 
   nCont_Apl       NUMBER(02)    ;
   sTipoDocto      VARCHAR2(02)  ;
   sTipo_Doc       VARCHAR2(02)  ;
   sCliente        VARCHAR2(20)  ;
   sReferencia     VARCHAR2(20)  ;
   sFecha          VARCHAR2(08)  ;
   sMsg            VARCHAR2(250) ;          
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(015) ;
   nProceso        NUMBER(08)    ;
   nPID            NUMBER(08)    ;
--
   CURSOR ScrAplicacion IS   
      SELECT ROWID, Cliente, Referencia, Fecha_Doc, Tipo_Doc, Dias_Cdto,
             DECODE( Cargo, 'S', Monto, Monto * -1 )    AS Monto
         FROM EAI.T3R_CARTERA_SAP_LDR
         WHERE Tipo_Doc = sTipoDocto ;
--
BEGIN
   nProceso  := 711 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ; 
   EAI.Trace_PLSQL( 'CarteraSAP', 'Inicio' ) ;
   UPDATE EAI.CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'Preparacion Cartera SAP' ;
   UPDATE EAI.CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'REPORTE DE CARTERA' ;
   UPDATE EAI.CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'AUTO-UPLOAD CARTERA' ;
   EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.T3R_CARTERA_SAP_OLD' ) ;
   COMMIT ;   
--
-- Procesando Documentos Padres
--
   v_ID := 'FROM Ldr to CC' ;
   INSERT INTO EAI.T3R_CARTERA_SAP_OLD
     ( Cliente, Fecha_Doc, Tipo_Doc, Monto, Asignacion, Referencia )
      SELECT Ldr.Cliente, Ldr.Fecha_Doc, Ldr.Tipo_Doc, 
             DECODE( Ldr.Cargo, 'S', Ldr.Monto, Ldr.Monto * -1 )    AS Monto,
             Ldr.Asignacion                          AS Asignacion ,
             CASE
                 WHEN ( PG.Factura IS NOT NULL ) THEN   PG.Factura
                 WHEN ( FG.Factura IS NOT NULL ) THEN   FG.Factura
                 ELSE
                    Ldr.Referencia
             END                                      AS Referencia_V3
         FROM 
              (
                SELECT 
--                     Cliente,
                       NVL( Branch_Number, Cliente )           AS Cliente,
                       Tipo_Doc, Asignacion, Fecha_Doc, Referencia, Cargo, AccountDocument,
                       Monto                                   AS Monto_Str,
                       TO_NUMBER( TRIM( NVL( Monto, '0' ) ) )  AS Monto
                FROM EAI.TAO_CARTERA_SAP_LDR              
              )                        Ldr,
              T3.Preventa_General      PG ,
              T3.Factura_General       FG
         WHERE Ldr.Asignacion  = PG.Entrega(+)     
           AND Ldr.Referencia  = FG.Factura(+) ;
--
   UPDATE EAI.T3R_Cartera_SAP_Old SET Tipo_Doc = 'ZM'
     WHERE Referencia LIKE '%CSC%' ;
   UPDATE EAI.T3R_Cartera_SAP_Old SET Tipo_Doc = 'ZM'
     WHERE Referencia LIKE 'ZM%' ;
   UPDATE EAI.T3R_Cartera_SAP_Old SET Tipo_Doc = 'Z4'
     WHERE Referencia LIKE 'Z4%' ;
--
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE
       WHERE PID = nPID  ;       
   COMMIT ;
--
   UPDATE EAI.CONTROL_REPORTE  SET  FIN = SYSDATE
      WHERE REPORTE = 'Preparacion Cartera SAP' ;
   UPDATE EAI.CONTROL_REPORTE  SET  FIN = SYSDATE
      WHERE REPORTE = 'REPORTE DE CARTERA' ;
   UPDATE EAI.CONTROL_REPORTE  SET  FIN = SYSDATE
      WHERE REPORTE = 'AUTO-UPLOAD CARTERA' ;
   COMMIT ;
   EAI.Trace_PLSQL( 'CarteraSAP', 'Termino' ) ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                , CREATED             , MESSAGE        , JOB_PID ,
          STATUS             , QUEUE_NAME               , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT              , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'CifrasControl'    , v_ID                     , SYSDATE             , NULL           , nPID    ,
          'Error'            , 'CC_DEBT_LDR_TO_CIFRAS'  , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                     , NULL                , NULL            ) ;
      COMMIT ;
END CC_DEBT_LDR_TO_CIFRAS;