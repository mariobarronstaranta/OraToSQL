create or replace PROCEDURE     "SF_CFDI_VENTA"
      ( nEtapa IN NUMBER DEFAULT 0  )
IS
  nDist               NUMBER(3)     ;
  sCtro               VARCHAR2(4)   ;
  sTerr               VARCHAR2(4)   ;
  sFecha              VARCHAR2(8)   ; 
  dtFecha             DATE     ;     
  sError              VARCHAR2(250) ;
  sResp               VARCHAR2(30)  ;
  sFactura            VARCHAR2(20)  ;
  sNULL               VARCHAR2(10)  ;
  sMsg                VARCHAR2(500) ;
  nItems              NUMBER(10)    ;
--
   v_ID                 VARCHAR2(050) ;
   sErrorCode           VARCHAR2(020) ;
   dtInicio             DATE          ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;  
--
    CURSOR ScrPrompt IS
       SELECT Vta.Ctro, Vta.Fecha_Venta, Vta.Nota_Venta, CFD.Metodo_Pago
          FROM EAI.CFDI_UUID_VENTA Vta, T3.CFDI_Documentos CFD
          WHERE Vta.Nota_Venta = CFD.Nota_Venta(+)
          ORDER BY Vta.Fecha_Venta, Vta.Ctro, Vta.Nota_Venta ;
--
    CURSOR ScrCobza IS
       SELECT 
              Cobza.Factura                                              AS Factura       ,
              SUM( Importe    )                                          AS Importe       ,
              SUM( Efectivo   )                                          AS Efectivo      ,
              SUM( Agrupado   )                                          AS Agrupado      ,
              SUM( Aplica_NC  )                                          AS Aplica_NC     ,
              SUM( Incobrable )                                          AS Incobrable    ,
              SUM( Efectivo  * Timbrado )                                AS Efectivo_UUID ,
              SUM( Agrupado  * Timbrado )                                AS Agrupado_UUID ,
              SUM( Aplica_NC * Timbrado )                                AS Aplica_NC_UUID,
              SUM( Importe   * Timbrado )                                AS Importe_UUID
          FROM (
                 SELECT 
                        Cobza.Factura                                    AS Factura      ,
                        Cobza.Asignacion_ID                              AS Asignacion_ID,
                        Cobza.Importe                                    AS Importe      ,
                        Cobza.Via_Pago                                   AS Via_Pago     ,
                        Cobza.Nota_Credito                               AS Nota_Credito ,
                        DECODE( Cobza.Via_Pago, '01', Cobza.Importe, 0 ) AS Efectivo     ,
                        DECODE( Cobza.Via_Pago, '02', Cobza.Importe, 
                                                '03', Cobza.Importe, 
                                                0 )                      AS Agrupado     ,
                        DECODE( Cobza.Via_Pago, 'CM', Cobza.Importe, 0 ) AS Aplica_NC    ,
                        DECODE( Cobza.Via_Pago, 'AI', Cobza.Importe, 0 ) AS Incobrable   ,
                        DECODE( Pago.Folio_Fiscal, NULL, 0, 1 ) +          
                        DECODE( Agr.Folio_Fiscal , NULL, 0, 1 ) +
                        DECODE( Nota.Folio_Fiscal, NULL, 0, 1 ) 
                                                                         AS Timbrado
                 FROM T3.CFDI_Cobranza          Cobza,
                      T3.CFDI_Documentos        Pago ,
                      T3.CFDI_Agrupacion_Pago   AgrP ,
                      T3.CFDI_Documentos        Agr  , 
                      T3.CFDI_Documentos        Nota
                 WHERE Cobza.Factura              = sFactura
                   AND Cobza.Asignacion_ID        = Pago.Nota_Venta(+)
                   AND Cobza.Asignacion_ID        = AgrP.Asignacion_ID(+)
                   AND TO_CHAR( AgrP.Agrupacion ) = Agr.Nota_Venta(+)
                   AND Cobza.Nota_Credito         = Nota.Nota_Venta(+) ) Cobza
      GROUP BY Cobza.Factura ;    
BEGIN
-- Inicio
   dtInicio  := SYSDATE ;
   nProceso  := 921 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, dtInicio ) ;   
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   sNULL     := '     ' ;
   v_ID      := 'CEDIS.Clean' ;
   v_ID := 'CFDI_UUID_VENTA' ;
   IF ( NVL( nEtapa, 0 )  <= 000 ) THEN
      DELETE FROM EAI.CFDI_UUID_VENTA ;
      INSERT INTO EAI.CFDI_UUID_VENTA
         ( Ctro, Fecha_Venta, Nota_Venta, RFC, Cliente_SAP, Importe_Vta, Saldo_SAP )  
          SELECT 
                 Info.Ctro                               AS Ctro       ,
                 Info.Fecha_Venta                        AS Fecha_Venta,
                 Info.Nota_Venta                         AS Nota_Venta ,
                 Info.RFC                                AS RFC        ,
                 Info.Cliente_SAP                        AS Cliente_SAP,
                 Info.Importe_Vta                        AS Importe_Vta,
                 Info.Saldo_SAP                          AS Saldo_SAP              
             FROM (
                    SELECT 
                           Doc.Ctro                      AS Ctro       ,
                           Doc.Invc_dt                   AS Fecha_Venta,
                           Doc.Doc_Num                   AS Nota_Venta ,
                           Doc.RFC                       AS RFC        ,
                           Doc.Cliente_SAP               AS Cliente_SAP,
                           NVL( Doc.Valor_Subt  , 0 ) +
                           NVL( Doc.Envio_Subt  , 0 ) +
                           NVL( Doc.Credito_Subt, 0 ) + 
                           NVL( Doc.Valor_IVA   , 0 ) +
                           NVL( Doc.Envio_IVA   , 0 ) +
                           NVL( Doc.Credito_IVA , 0 )    AS Importe_Vta,
                           NVL( DOI.Saldo_SAP   , 0 )    AS Saldo_SAP
                       FROM EAI.CFDI_Bitacora  Doc,
                           ( SELECT 
                                    SAP.Referencia                 AS Nota_Venta ,
                                    MAX( SAP.Cliente )             AS Cliente_SAP,
                                    MIN( SAP.Fecha_Doc )           AS Fecha_Doc  ,
                                    SUM( NVL( SAP.Monto, 0 ) )     AS Saldo_SAP
                                FROM EAI.T3R_Cartera_SAP_OLD  SAP
                                GROUP BY SAP.Referencia ) DOI
                       WHERE Doc.Tipo_Vta    = 'Vta'
                         AND Doc.RFC        != 'XAXX010101000'
                         AND Doc.Doc_Num     = DOI.Nota_Venta(+) ) Info ;
      COMMIT ;   
   END IF ;
--
   v_ID := 'ScrPrompt' ;
   IF ( NVL( nEtapa, 0 ) <= 010 ) THEN
      sFecha := '010' ;
      FOR Doc IN ScrPrompt LOOP
         sFactura := Doc.Nota_Venta ;
         FOR Cobza IN ScrCobza LOOP
            UPDATE EAI.CFDI_UUID_VENTA SET
                                           Importe        = Cobza.Importe       ,
                                           Efectivo       = Cobza.Efectivo      ,
                                           Agrupado       = Cobza.Agrupado      ,
                                           Aplica_NC      = Cobza.Aplica_NC     ,
                                           Incobrable     = Cobza.Incobrable    ,
                                           Efectivo_UUID  = Cobza.Efectivo_UUID ,
                                           Agrupado_UUID  = Cobza.Agrupado_UUID ,
                                           Aplica_NC_UUID = Cobza.Aplica_NC_UUID,
                                           Importe_UUID   = Cobza.Importe_UUID  ,
                                           Metodo_Pago    = Doc.Metodo_Pago
               WHERE Nota_Venta = sFactura ;
         END LOOP ;
         nProceso1 := nProceso1 + 1 ;  
         IF ( MOD( nProceso1, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;
   COMMIT ;
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;   
   COMMIT ;          
EXCEPTION
   WHEN OTHERS THEN
      COMMIT ;
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE                , CREATED             , MESSAGE        , JOB_PID,          
          STATUS              , QUEUE_NAME               , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT              , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'       , v_ID                     , SYSDATE             , NULL           , nPID   , 
          'Error'             , 'SF_CFDI_VENTA'          , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                     , NULL                , NULL            ) ;
      COMMIT ; 
      DBMS_Output.Put_LINE( '----------------------------------' ) ;
      DBMS_Output.Put_LINE( '**** Error en SF_CFDI_VENTA *****'  ) ;
      DBMS_Output.Put_LINE( sMsg ) ;      
END ;