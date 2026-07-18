create or replace PROCEDURE           "WA_ASIGNACION_PAGO_INSERT" 
   ( pLevel   IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrFacturas IS
      SELECT Asig.RowID                                                    AS A_ROWID    ,
             RFD.Factura                                                   AS Factura    ,
             RF.Cliente_SAP                                                AS Cliente_SAP,
             Cte.RFC                                                       AS RFC        ,
             SUM( NVL( RFD.Valor_Subt  , 0 ) + NVL( RFD.Valor_IVA  , 0 ) 
                + NVL( RFD.Envio_Subt  , 0 ) + NVL( RFD.Envio_IVA  , 0 ) 
                + NVL( RFD.Credito_Subt, 0 ) + NVL( RFD.Credito_IVA, 0 ) ) AS Importe
         FROM EAI_Owner.XP_Asignacion_Pago  Asig,
              T3.Registro_Fiscal            RF  ,
              T3.Registro_Fiscal_Detalle    RFD ,
              T3.Cliente                    Cte
         WHERE Asig.Factura      = RF.Factura
           AND RF.Factura        = RFD.Factura
           AND RF.Cliente_SAP    = Cte.Cliente_SAP
           AND RF.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
         GROUP BY Asig.RowID, RFD.Factura, RF.Cliente_SAP, Cte.RFC ;
--
   CURSOR ScrFactPend IS
      SELECT DISTINCT Factura
         FROM EAI_Owner.XP_Asignacion_Pago ;
--
   CURSOR ScrDuplicidad IS
      SELECT Asig.Factura, Asig.Importe, AP.Fecha_Trn, AP.Fecha_Proc_BATMD, asig.clearing_document
         FROM EAI_Owner.XP_Asignacion_Pago Asig,
              T3.Asignacion_Pago           AP
         WHERE Asig.Factura      = AP.Factura
           AND Asig.Importe      = AP.Valor_Pago 
           AND substr(Asig.fecha_asignacion,3,2)||Asig.clearing_document = AP.asignacion_id ; 
            
--
   CURSOR ScrLiberacion IS
      SELECT 
             SUBSTR( Asig.Fecha_Asignacion, 3, 2 ) ||
             Asig.Clearing_Document       AS Pago_ID         , 
             SYSDATE                      AS Fecha_Trn       , 
             Asig.Factura                 AS Factura         , 
             NULL                         AS Nota_Credito    , 
             RF.Distribuidor              AS Distribuidor    ,
             RF.Ctro                      AS Ctro            ,
             RF.Cliente_V3                AS Cliente_V3      , 
             RF.Cliente_SAP               AS Cliente_SAP     , 
             'CENTRAL'                    AS Rep_ID          , 
             'PAYMENT'                    AS Tipo_Pago       ,
             CASE
                 WHEN Asig.Via_Pago IS NULL THEN 'T'
                 WHEN Asig.Via_Pago  = '01' THEN 'E'
                 WHEN Asig.Via_Pago  = '02' THEN 'D'
                 WHEN Asig.Via_Pago  = '03' THEN 'T'
                 ELSE 
                   'D'
             END                          AS Metodo_Pago     ,
             TO_DATE( Asig.Fecha_Asignacion, 'YYYYMMDD' )   
                                          AS Fecha_Asignacion, 
             Asig.Importe                 AS Valor_Pago      ,
             Asig.ROWID                   AS Asig_ROWID
         FROM EAI_Owner.XP_Asignacion_Pago Asig,
              T3.Registro_Fiscal           RF
        WHERE NVL( Asig.Duplicada, ' ' )     != 'X'
           AND ( ( Asig.Status_Asignacion        IS NULL )
              OR ( ( Asig.Status_Asignacion = 'Documento ya liberado' )
               AND ( Asig.Fact_RFC          = 'XAXX010101000'         ) ) )
           AND Asig.Factura                   = RF.Factura
           AND NVL( Asig.Importe       , 0 )  > 0
           AND NVL( Asig.Fact_Pendiente, 0 ) >= Asig.Importe ; 
--
   CURSOR ScrStatus_Asig IS
        SELECT 
               Asig.ROWID           AS Asigna_ROWID       ,
               Asig.Factura         AS Asigna_Factura     ,
               Asig.Importe         AS Importe            ,      
               Asig.Fact_RFC        AS RFC_Factura        ,
               Asig.Fact_Pendiente  AS Factura_Pendiente  ,
               Asig.Duplicada       AS Duplicada          ,
               CASE 
                   WHEN ( ( NVL( Asig.Importe       , 0 )  > 0            ) 
                      AND ( NVL( Asig.Fact_Pendiente, 0 ) >= Asig.Importe ) )             THEN 'Ok'
                   ELSE
                      'Revisar Asignacion'
               END   AS Status_Asignacion
            FROM EAI_Owner.XP_Asignacion_Pago Asig,
                 T3.Registro_Fiscal           RF  
            WHERE Asig.Factura              = RF.Factura(+) ;
--
   CURSOR ScrStatus_AsigDup IS
     SELECT 
         Asig.Factura         AS Asigna_Factura     ,
         Asig.Importe         AS Importe            ,
         Asig.Fact_RFC        AS RFC_Factura        ,
         Asig.Fact_Pendiente  AS Factura_Pendiente  ,
         TO_CHAR( Asig.Duplicidad )
                              AS Duplicada          ,
         'Duplicidad de Asignacion ( ' || TO_CHAR( Asig.Duplicidad ) || ' )'
                              AS Status_Asignacion
     FROM (  
            SELECT 
                   Factura                AS Factura       ,
                   SUM( Importe        )  AS Importe       , 
                   COUNT(*)               AS Duplicidad    ,
                   MAX( Fact_RFC       )  AS Fact_RFC      ,                   
                   MAX( Fact_Pendiente )  AS Fact_Pendiente
               FROM EAI_Owner.XP_Asignacion_Pago
               GROUP BY Factura
               HAVING COUNT(*) > 1
           ) Asig ;
--
   CURSOR ScrStatus_FactExc IS
      SELECT 
         Asig.Factura         AS Asigna_Factura     ,
         Asig.Importe         AS Importe            ,
         Asig.Fact_RFC        AS RFC_Factura        ,
         Asig.Fact_Pendiente  AS Factura_Pendiente  ,
         TO_CHAR( Asig.Duplicidad )
                              AS Duplicada          ,
         NULL                 AS Fecha_Liberacion   ,
         'Asignacion Excedente'
                              AS Status_Asignacion
     FROM (  
            SELECT 
                   Factura                AS Factura       ,
                   SUM( Importe        )  AS Importe       , 
                   COUNT(*)               AS Duplicidad    ,
                   MAX( Fact_RFC       )  AS Fact_RFC      ,
                   MAX( Fact_Pendiente )  AS Fact_Pendiente,
                   MAX( 0              )  AS Cred_Pendiente
               FROM EAI_Owner.XP_Asignacion_Pago
               GROUP BY Factura 
               HAVING COUNT(*) > 1
                  AND SUM( Importe ) > MAX( Fact_Pendiente ) 
           ) Asig ;
--
   CURSOR ScrPagoDuplicated IS
       SELECT XAP.Factura, XAP.Clearing_Document, XAP.ROWID AS XAP_ROWID
          FROM EAI_Owner.XP_Asignacion_Pago XAP, 
               T3.Asignacion_Pago           AP
          WHERE SUBSTR( XAP.Fecha_Asignacion, 3, 2 ) || XAP.Clearing_Document = AP.Pago_ID ;
--   
   sErrorCode            VARCHAR2(0030) ;      
   sMsg                  VARCHAR2(0300) ;
   nPedidos              NUMBER(03)     ;
   nPID                  NUMBER(08)     ;
   nProceso              NUMBER(08)     ;
   sReference            VARCHAR2(0050) ;
   sStepPLSQL            VARCHAR2(0050) ;
   sStatement            VARCHAR2(2000) ;
   nSQL_Rows             NUMBER(08)     ;
   sInvDoc_Num           VARCHAR2(030)  ; 
   sInvCustomer          VARCHAR2(030)  ;
   nInvAmount            NUMBER(15,2)   ;
   nInvPending           NUMBER(15,2)   ;
   nPaid                 NUMBER(15,2)   ;
   sNCDoc_Num            VARCHAR2(030)  ; 
   sNCCustomer           VARCHAR2(030)  ;
   nNCAmount             NUMBER(15,2)   ;
   nNCPending            NUMBER(15,2)   ;
   nNCPaid               NUMBER(15,2)   ;
BEGIN
   
   IF ( NVL( pLevel, 0 ) <= 10 ) THEN
      sStepPLSQL := 'ScrFacturas' ;
      DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
      FOR Doc IN ScrFacturas LOOP
         sReference := Doc.Factura ;
         UPDATE EAI_Owner.XP_Asignacion_Pago SET Fact_Importe = Doc.Importe    ,
                                                 Fact_RFC     = Doc.RFC        ,
                                                 Cliente_SAP  = Doc.Cliente_SAP
            WHERE Factura = Doc.Factura ;
      END LOOP ;
   END IF ;   
   
   IF ( NVL( pLevel, 0 ) <= 100 ) THEN
      sStepPLSQL := 'ScrFactPend' ;
      DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
      FOR Doc IN ScrFactPend LOOP
         sReference := Doc.Factura ;
         EAI_OWNER.SF_GET_INVOICE_DATA( sReference, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid ) ;
         UPDATE EAI_Owner.XP_Asignacion_Pago SET Fact_Pendiente = nInvPending
            WHERE Factura = Doc.Factura ;
      END LOOP ;     
   END IF ;
   sStepPLSQL := 'ScrDuplicidad' ;
   DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
   FOR Doc IN ScrDuplicidad LOOP
      sReference := Doc.Factura ;
      UPDATE EAI_Owner.XP_Asignacion_Pago SET Duplicada = 'X', Status_Asignacion = 'Asignacion ya aplicada'
         WHERE Factura      = Doc.Factura
           AND Importe      = Doc.Importe 
           And Clearing_Document = Doc.Clearing_Document;         
   END LOOP ;
--
-- Inconsistencias
   sStepPLSQL := 'Revisando Inconsistencias' ;
   sStepPLSQL := 'ScrStatus_Asig' ;
   DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
   FOR Doc IN ScrStatus_Asig LOOP
      IF ( Doc.Status_Asignacion != 'Ok' ) THEN
         UPDATE EAI_Owner.XP_Asignacion_Pago SET Status_Asignacion = Doc.Status_Asignacion
            WHERE ROWID = Doc.Asigna_ROWID ;        
      END IF ;
   END LOOP ;
   sStepPLSQL := 'ScrStatus_AsigDup' ;
   DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
   FOR Doc IN ScrStatus_AsigDup LOOP
         UPDATE EAI_Owner.XP_Asignacion_Pago SET Status_Asignacion = Doc.Status_Asignacion
            WHERE Factura      = Doc.Asigna_Factura ;
   END LOOP ;
   sStepPLSQL := 'ScrStatus_FactExc' ;
   DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
   FOR Doc IN ScrStatus_FactExc LOOP
         UPDATE EAI_Owner.X_Asignacion_Pago SET Status_Asignacion = Doc.Status_Asignacion
            WHERE Factura = Doc.Asigna_Factura ;
   END LOOP ;
--
   sStepPLSQL := 'ScrPagoDuplicated' ;
   DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
   FOR Doc IN ScrPagoDuplicated LOOP
         UPDATE EAI_Owner.X_Asignacion_Pago SET Duplicada = 'X', Status_Asignacion = 'Clearing ya procesado'
            WHERE Factura = Doc.Factura ;
   END LOOP ;
--
   sStepPLSQL := 'Revisando si necesita INSERTAR' ;
   IF ( NVL( pLevel, 0 ) >= 1000 ) THEN
      sStepPLSQL := 'ScrLiberacion' ;
      DBMS_OUTPUT.PUT_LINE( sStepPLSQL ) ;
      FOR Doc IN ScrLiberacion LOOP
         INSERT INTO T3.Pago
          ( Pago_ID     , Fecha_Trn    , Distribuidor   , Fecha_Pago          , Cliente_V3     , Cliente_SAP    , 
            Rep_ID      , Tipo_Pago    , Metodo_Pago    , Valor_Pago          , Ctro                             )
         VALUES
          ( Doc.Pago_ID, Doc.Fecha_Trn , Doc.Distribuidor, Doc.Fecha_Asignacion, Doc.Cliente_V3, Doc.Cliente_SAP,
            Doc.Rep_ID , Doc.Tipo_Pago , Doc.Metodo_Pago , Doc.Valor_Pago      , Doc.Ctro                        ) ;         
         INSERT INTO T3.Asignacion_Pago
          ( Pago_ID    , Asignacion_ID , Fecha_Trn      , Factura    , Nota_Credito        , Distribuidor    , 
            Ctro       , Cliente_V3    , Cliente_SAP    , Rep_ID     , Fecha_Asignacion    , Valor_Pago        )
         VALUES 
          ( Doc.Pago_ID, Doc.Pago_ID   , Doc.Fecha_Trn  , Doc.Factura, Doc.Nota_Credito    , Doc.Distribuidor, 
            Doc.Ctro   , Doc.Cliente_V3, Doc.Cliente_SAP, Doc.Rep_ID , Doc.Fecha_Asignacion, Doc.Valor_Pago    ) ;
         UPDATE EAI_Owner.XP_Asignacion_Pago SET Status = 'Insertada ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' )
            WHERE ROWID = Doc.Asig_ROWID ;
      END LOOP ;   
   END IF ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Workaround'       , sReference                 , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ASIGNACION_PAGO_INSERT', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_ASIGNACION_PAGO_INSERT' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || sReference ) ;
      DBMS_Output.Put_Line( 'Secuencia     : ' || sStepPLSQL ) ;      
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;          
      COMMIT ;   
END WA_ASIGNACION_PAGO_INSERT ;