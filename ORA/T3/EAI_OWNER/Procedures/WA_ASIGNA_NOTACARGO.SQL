create or replace PROCEDURE           "WA_ASIGNA_NOTACARGO" 
   ( pLevel    IN NUMBER   DEFAULT 0,
     pDays     IN NUMBER   DEFAULT 0,
     nSequence IN NUMBER   DEFAULT 0 )
   AS
--
   nAplicaciones         NUMBER(06)     ;
   CURSOR ScrFacturas IS
      SELECT Asig.RowID                                                    AS A_ROWID,
             RFD.Factura                                                   AS Factura,
             Cte.RFC                                                       AS RFC    ,
             SUM( NVL( RFD.Valor_Subt  , 0 ) + NVL( RFD.Valor_IVA  , 0 ) 
                + NVL( RFD.Envio_Subt  , 0 ) + NVL( RFD.Envio_IVA  , 0 ) 
                + NVL( RFD.Credito_Subt, 0 ) + NVL( RFD.Credito_IVA, 0 ) ) AS Importe
         FROM EAI_Owner.X_Aplica_NotaCargo  Asig,
              T3.Registro_Fiscal             RF  ,
              T3.Registro_Fiscal_Detalle     RFD ,
              T3.Cliente                     Cte
         WHERE Asig.Factura      = RF.Factura
           AND RF.Factura        = RFD.Factura
           AND RF.Cliente_SAP    = Cte.Cliente_SAP
           AND RF.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
         GROUP BY Asig.RowID, RFD.Factura, Cte.RFC ;
--
   CURSOR ScrNotas IS
      SELECT Asig.RowID                                                    AS A_ROWID,
             RFD.Factura                                                   AS Factura,
             Cte.RFC                                                       AS RFC    ,
             SUM( NVL( RFD.Valor_Subt  , 0 ) + NVL( RFD.Valor_IVA  , 0 ) 
                + NVL( RFD.Envio_Subt  , 0 ) + NVL( RFD.Envio_IVA  , 0 ) 
                + NVL( RFD.Credito_Subt, 0 ) + NVL( RFD.Credito_IVA, 0 ) ) AS Importe
         FROM EAI_Owner.X_Aplica_NotaCargo  Asig,
              T3.Registro_Fiscal             RF  ,
              T3.Registro_Fiscal_Detalle     RFD ,
              T3.Cliente                     Cte
         WHERE Asig.Nota_Credito = RF.Factura
           AND RF.Factura        = RFD.Factura
           AND RF.Cliente_SAP    = Cte.Cliente_SAP
           AND RF.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
         GROUP BY Asig.RowID, RFD.Factura, Cte.RFC ;
--
   CURSOR ScrFactPend IS
      SELECT DISTINCT Factura
         FROM EAI_Owner.X_Aplica_NotaCargo ;
--
   CURSOR ScrCredPend IS
      SELECT DISTINCT Nota_Credito
         FROM EAI_Owner.X_Aplica_NotaCargo ;
--
   CURSOR ScrDuplicidad IS
      SELECT Asig.Factura, Asig.Nota_Credito, Asig.Importe, AP.Fecha_Trn, AP.Fecha_Proc_BATMD
         FROM EAI_Owner.X_Aplica_NotaCargo Asig,
              T3.Asignacion_Pago            AP
         WHERE Asig.Factura      = AP.Factura
           AND Asig.Nota_Credito = AP.Nota_Credito
           AND Asig.Importe      = AP.Valor_Pago ;   
--
   CURSOR ScrLiberacion IS
      SELECT 
             TO_CHAR( SYSDATE, 'YYDDDHH24')
               || LPAD( NVL( nSequence, 0 ) + ROWNUM, 5, '0' )  AS Pago_ID         , 
             SYSDATE                      AS Fecha_Trn       , 
--           Asig.Factura                 AS Factura         , 
             'INCOBRABLE'                 AS Factura         ,
             Asig.Nota_Credito            AS Nota_Credito    , 
             RF.Distribuidor              AS Distribuidor    ,
             RF.Ctro                      AS Ctro            ,
             RF.Cliente_V3                AS Cliente_V3      , 
             RF.Cliente_SAP               AS Cliente_SAP     , 
             'CENTRAL'                    AS Rep_ID          , 
             TRUNC( SYSDATE - NVL( pDays, 0 ) )             
                                          AS Fecha_Asignacion, 
             Asig.Importe                 AS Valor_Pago      ,
             Asig.ROWID                   AS Asig_ROWID
         FROM EAI_Owner.X_Aplica_NotaCargo Asig,
              T3.Registro_Fiscal            RF
        WHERE NVL( Asig.Duplicada, ' ' )     != 'X'
           AND ( ( Asig.Status_Asignacion        IS NULL )
              OR ( ( Asig.Status_Asignacion = 'Documento ya liberado' )
                ) )
           AND Asig.Nota_Credito              = RF.Factura
           AND NVL( Asig.Importe       , 0 )  > 0
           AND NVL( Asig.Cred_Pendiente, 0 ) >= Asig.Importe ;  
--
   CURSOR ScrLiberacionFact IS
      SELECT 
             TO_CHAR( SYSDATE, 'YYDDDHH24')
               || LPAD( NVL( nSequence, 0 ) + nAplicaciones + ROWNUM, 5, '0' )  AS Pago_ID         , 
             SYSDATE                      AS Fecha_Trn       , 
             Asig.Factura                 AS Factura         , 
             'PAYMENT'                    AS Tipo_Pago       ,
             'I'                          AS Metodo_Pago     ,
             Asig.Nota_Credito            AS Nota_Credito    , 
             RF.Distribuidor              AS Distribuidor    ,
             RF.Ctro                      AS Ctro            ,
             RF.Cliente_V3                AS Cliente_V3      , 
             RF.Cliente_SAP               AS Cliente_SAP     , 
             'CENTRAL'                    AS Rep_ID          , 
             TRUNC( SYSDATE - NVL( pDays, 0 ) )             
                                          AS Fecha_Asignacion, 
             Asig.Importe                 AS Valor_Pago      ,
             Asig.ROWID                   AS Asig_ROWID
         FROM EAI_Owner.X_Aplica_NotaCargo Asig,
              T3.Registro_Fiscal            RF
        WHERE NVL( Asig.Duplicada, ' ' )     != 'X'
           AND ( ( Asig.Status_Asignacion        IS NULL )
              OR ( ( Asig.Status_Asignacion = 'Documento ya liberado' )
                ) )
           AND Asig.Factura                   = RF.Factura
           AND NVL( Asig.Importe       , 0 )  > 0
           AND NVL( Asig.Fact_Pendiente, 0 ) >= Asig.Importe ;  
--
   CURSOR ScrStatus_Asig IS
        SELECT 
               Asig.ROWID           AS Asigna_ROWID       ,
               Asig.Nota_Credito    AS Asigna_Nota_Credito,
               Asig.Factura         AS Asigna_Factura     ,
               Asig.Importe         AS Importe            ,      
               Asig.Fact_RFC        AS RFC_Factura        ,
               Asig.Cred_RFC        AS RFC_Nota_Credito   ,
               Asig.Fact_Pendiente  AS Factura_Pendiente  ,
               Asig.Cred_Pendiente  AS NotaCred_Pendiente ,
               Asig.Duplicada       AS Duplicada          ,
               CFD.Fecha_Liberacion AS Fecha_Liberacion   ,
               CASE 
                   WHEN ( CFD.Fecha_Liberacion IS NOT NULL )                              THEN 'Documento ya liberado'
                   WHEN ( ( NVL( Asig.Importe       , 0 )  > 0            ) 
                      AND ( NVL( Asig.Cred_Pendiente, 0 ) >= Asig.Importe ) )             THEN 'Ok'
                   ELSE
                      'Revisar Asignacion'
               END   AS Status_Asignacion
            FROM EAI_Owner.X_Aplica_NotaCargo Asig,
                 T3.CFDI_Documentos            CFD
            WHERE Asig.Nota_Credito         = CFD.Nota_Venta(+) 
              AND Asig.Nota_Credito        IS NOT NULL ;
--
   CURSOR ScrStatus_AsigDup IS
     SELECT 
         Asig.Nota_Credito    AS Asigna_Nota_Credito,
         Asig.Factura         AS Asigna_Factura     ,
         Asig.Importe         AS Importe            ,
         Asig.Fact_RFC        AS RFC_Factura        ,
         Asig.Cred_RFC        AS RFC_Nota_Credito   ,
         Asig.Fact_Pendiente  AS Factura_Pendiente  ,
         Asig.Cred_Pendiente  AS NotaCred_Pendiente ,
         TO_CHAR( Asig.Duplicidad )
                              AS Duplicada          ,
         CFD.Fecha_Liberacion AS Fecha_Liberacion   ,
         'Duplicidad de Asignacion ( ' || TO_CHAR( Asig.Duplicidad ) || ' )'
                              AS Status_Asignacion
     FROM (  
            SELECT Nota_Credito           AS Nota_Credito  ,
                   Factura                AS Factura       ,
                   SUM( Importe        )  AS Importe       , 
                   COUNT(*)               AS Duplicidad    ,
                   MAX( Fact_RFC       )  AS Fact_RFC      ,
                   MAX( Cred_RFC       )  AS Cred_RFC      ,
                   MAX( Fact_Pendiente )  AS Fact_Pendiente,
                   MAX( Cred_Pendiente )  AS Cred_Pendiente
               FROM EAI_Owner.X_Aplica_NotaCargo
               GROUP BY Nota_Credito, Factura
               HAVING COUNT(*) > 1
           ) Asig,
           T3.CFDI_Documentos CFD
     WHERE Asig.Nota_Credito = CFD.Nota_Venta(+) ;
--
   CURSOR ScrStatus_CredExc IS
      SELECT 
         Asig.Nota_Credito    AS Asigna_Nota_Credito,
         Asig.Factura         AS Asigna_Factura     ,
         Asig.Importe         AS Importe            ,
         Asig.Fact_RFC        AS RFC_Factura        ,
         Asig.Cred_RFC        AS RFC_Nota_Credito   ,
         Asig.Fact_Pendiente  AS Factura_Pendiente  ,
         Asig.Cred_Pendiente  AS NotaCred_Pendiente ,
         TO_CHAR( Asig.Duplicidad )
                              AS Duplicada          ,
         CFD.Fecha_Liberacion AS Fecha_Liberacion   ,
         'Asignacion Excedente'
                              AS Status_Asignacion
     FROM (  
            SELECT Nota_Credito           AS Nota_Credito  ,
                   NULL                   AS Factura       ,
                   SUM( Importe        )  AS Importe       , 
                   COUNT(*)               AS Duplicidad    ,
                   MAX( Fact_RFC       )  AS Fact_RFC      ,
                   MAX( Cred_RFC       )  AS Cred_RFC      ,
                   MAX( 0              )  AS Fact_Pendiente,
                   MAX( Cred_Pendiente )  AS Cred_Pendiente
               FROM EAI_Owner.X_Aplica_NotaCargo
               GROUP BY Nota_Credito 
               HAVING COUNT(*) > 1
                  AND SUM( Importe ) > MAX( Cred_Pendiente ) 
           ) Asig,
           T3.CFDI_Documentos CFD
     WHERE Asig.Nota_Credito = CFD.Nota_Venta(+) ;
--
   CURSOR ScrStatus_FactExc IS
      SELECT 
         Asig.Nota_Credito    AS Asigna_Nota_Credito,
         Asig.Factura         AS Asigna_Factura     ,
         Asig.Importe         AS Importe            ,
         Asig.Fact_RFC        AS RFC_Factura        ,
         Asig.Cred_RFC        AS RFC_Nota_Credito   ,
         Asig.Fact_Pendiente  AS Factura_Pendiente  ,
         Asig.Cred_Pendiente  AS NotaCred_Pendiente ,
         TO_CHAR( Asig.Duplicidad )
                              AS Duplicada          ,
         NULL                 AS Fecha_Liberacion   ,
         'Asignacion Excedente'
                              AS Status_Asignacion
     FROM (  
            SELECT ''                     AS Nota_Credito  ,
                   Factura                AS Factura       ,
                   SUM( Importe        )  AS Importe       , 
                   COUNT(*)               AS Duplicidad    ,
                   MAX( Fact_RFC       )  AS Fact_RFC      ,
                   MAX( Cred_RFC       )  AS Cred_RFC      ,
                   MAX( Fact_Pendiente )  AS Fact_Pendiente,
                   MAX( 0              )  AS Cred_Pendiente
               FROM EAI_Owner.X_Aplica_NotaCargo
               GROUP BY Factura 
               HAVING COUNT(*) > 1
                  AND SUM( Importe ) > MAX( Fact_Pendiente ) 
           ) Asig ;
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
   sStepPLSQL := 'ScrFacturas' ;
   IF ( NVL( pLevel, 0 ) <= 10 ) THEN
      FOR Doc IN ScrFacturas LOOP
         sReference := Doc.Factura ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Fact_Importe = Doc.Importe,
                                                  Fact_RFC     = Doc.RFC
            WHERE Factura = Doc.Factura ;
      END LOOP ;
      sStepPLSQL := 'ScrNotas' ;
      FOR Doc IN ScrNotas LOOP
         sReference := Doc.Factura ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Cred_Importe = Doc.Importe,
                                                  Cred_RFC     = Doc.RFC
            WHERE Nota_Credito = Doc.Factura ;
      END LOOP ;
   END IF ;   
   IF ( NVL( pLevel, 0 ) <= 100 ) THEN
      sStepPLSQL := 'ScrFactPend' ;
      FOR Doc IN ScrFactPend LOOP
         sReference := Doc.Factura ;
         EAI_OWNER.SF_GET_INVOICE_DATA( sReference, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid ) ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Fact_Pendiente = nInvPending
            WHERE Factura = Doc.Factura ;
      END LOOP ;   
      sStepPLSQL := 'ScrCredPend' ;
      FOR Doc IN ScrCredPend LOOP
         sReference := Doc.Nota_Credito ;
         EAI_OWNER.SF_GET_CREDIT_DATA( sReference, sNCDoc_Num, sNCCustomer, nNCAmount , nNCPending, nNCPaid  ) ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Cred_Importe   = nNCAmount ,
                                                  Cred_Pendiente = nNCPending
            WHERE Nota_Credito = Doc.Nota_Credito ;
      END LOOP ;   
   END IF ;
   sStepPLSQL := 'ScrDuplicidad' ;
   FOR Doc IN ScrDuplicidad LOOP
      sReference := Doc.Factura ;
      UPDATE EAI_Owner.X_Aplica_NotaCargo SET Duplicada = 'X', Status_Asignacion = 'Asignacion ya aplicada'
         WHERE Factura      = Doc.Factura
           AND Nota_Credito = Doc.Nota_Credito
           AND Importe      = Doc.Importe ;         
   END LOOP ;
--
-- Inconsistencias
   sStepPLSQL := 'ScrStatus_Asig' ;
   FOR Doc IN ScrStatus_Asig LOOP
      IF ( Doc.Status_Asignacion != 'Ok' ) THEN
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status_Asignacion = Doc.Status_Asignacion
            WHERE ROWID = Doc.Asigna_ROWID ;        
      END IF ;
   END LOOP ;
   sStepPLSQL := 'ScrStatus_AsigDup' ;
   FOR Doc IN ScrStatus_AsigDup LOOP
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status_Asignacion = Doc.Status_Asignacion
            WHERE Nota_Credito = Doc.Asigna_Nota_Credito 
              AND Factura      = Doc.Asigna_Factura ;
   END LOOP ;
   sStepPLSQL := 'ScrStatus_CredExc' ;
   FOR Doc IN ScrStatus_CredExc LOOP
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status_Asignacion = Doc.Status_Asignacion
            WHERE Nota_Credito = Doc.Asigna_Nota_Credito ;
   END LOOP ;
   sStepPLSQL := 'ScrStatus_FactExc' ;
   FOR Doc IN ScrStatus_FactExc LOOP
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status_Asignacion = Doc.Status_Asignacion
            WHERE Factura = Doc.Asigna_Factura ;
   END LOOP ;
--
   IF ( NVL( pLevel, 0 ) >= 1000 ) THEN
      sStepPLSQL := 'ScrLiberacion' ;
      nAplicaciones := 0 ;
      FOR Doc IN ScrLiberacion LOOP
         nAplicaciones := nAplicaciones + 1 ;
         INSERT INTO T3.Asignacion_Pago
          ( Pago_ID    , Asignacion_ID , Fecha_Trn      , Factura    , Nota_Credito        , Distribuidor    , 
            Ctro       , Cliente_V3    , Cliente_SAP    , Rep_ID     , Fecha_Asignacion    , Valor_Pago        )
         VALUES 
          ( Doc.Pago_ID, Doc.Pago_ID   , Doc.Fecha_Trn  , Doc.Factura, Doc.Nota_Credito    , Doc.Distribuidor, 
            Doc.Ctro   , Doc.Cliente_V3, Doc.Cliente_SAP, Doc.Rep_ID , Doc.Fecha_Asignacion, Doc.Valor_Pago    ) ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status = 'Insertada ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' )
            WHERE ROWID = Doc.Asig_ROWID ;
      END LOOP ;       
--
      FOR Doc IN ScrLiberacionFact LOOP
         INSERT INTO T3.Pago
          ( Pago_ID     , Fecha_Trn    , Distribuidor   , Fecha_Pago          , Cliente_V3     , Cliente_SAP    , 
            Rep_ID      , Tipo_Pago    , Metodo_Pago    , Valor_Pago          , Ctro                             )
         VALUES
          ( Doc.Pago_ID, Doc.Fecha_Trn , Doc.Distribuidor, Doc.Fecha_Asignacion, Doc.Cliente_V3, Doc.Cliente_SAP,
            Doc.Rep_ID , Doc.Tipo_Pago , Doc.Metodo_Pago , Doc.Valor_Pago      , Doc.Ctro                        ) ;  
--
         INSERT INTO T3.Asignacion_Pago
          ( Pago_ID    , Asignacion_ID , Fecha_Trn      , Factura    , Nota_Credito        , Distribuidor    , 
            Ctro       , Cliente_V3    , Cliente_SAP    , Rep_ID     , Fecha_Asignacion    , Valor_Pago        )
         VALUES 
          ( Doc.Pago_ID, Doc.Pago_ID   , Doc.Fecha_Trn  , Doc.Factura, Doc.Nota_Credito    , Doc.Distribuidor, 
            Doc.Ctro   , Doc.Cliente_V3, Doc.Cliente_SAP, Doc.Rep_ID , Doc.Fecha_Asignacion, Doc.Valor_Pago    ) ;
         UPDATE EAI_Owner.X_Aplica_NotaCargo SET Status = 'Insertada ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' )
            WHERE ROWID = Doc.Asig_ROWID ;
      END LOOP ;   
   END IF ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE       , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Workaround'       , sReference                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ASIGNACION_NOTACARGO'      , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'WA_ASIGNA_INCOBRABLE' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || sReference ) ;
      DBMS_Output.Put_Line( 'Secuencia     : ' || sStepPLSQL ) ;      
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;               
      COMMIT ;   
END WA_ASIGNA_NOTACARGO ;