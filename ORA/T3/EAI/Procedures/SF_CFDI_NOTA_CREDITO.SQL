create or replace PROCEDURE     "SF_CFDI_NOTA_CREDITO"
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
       SELECT Ctro, Fecha_Venta, Nota_Venta
          FROM EAI.CFDI_UUID_NOTA_CREDITO 
          ORDER BY Fecha_Venta, Ctro, Nota_Venta ;
--
    CURSOR ScrCobza IS
                 SELECT 
                        COUNT( Cobza.Asignacion_ID   )  AS Aplicaciones    ,
                        SUM( NVL( Cobza.Importe, 0 ) )  AS Importe_Aplicado,
                        MAX( Cobza.Fecha_Asignacion  )  AS Fecha_Asignacion,
                        SUM( DECODE( Cobza.Via_Pago, 'AI', Cobza.Importe, 0 ) )
                                                        AS Incobrable
                    FROM T3.CFDI_Cobranza Cobza
                    WHERE Cobza.Nota_Credito = sFactura ;
BEGIN
-- Inicio
   dtInicio  := SYSDATE ;
   nProceso  := 922 ;
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
      DELETE FROM EAI.CFDI_UUID_NOTA_CREDITO ;
      INSERT INTO EAI.CFDI_UUID_NOTA_CREDITO
         ( Ctro, Fecha_Venta, Nota_Venta, RFC, Cliente_SAP, Importe_Vta, Saldo_SAP, Folio_Fiscal )  
      SELECT 
             Nota.Ctro                                     AS Ctro         ,
             Nota.Fecha_Venta                              AS Fecha_Venta  ,
             Nota.Nota_Venta                               AS Nota_Venta   ,
             Nota.RFC                                      AS RFC          ,
             Nota.Cliente_SAP                              AS Cliente_SAP  ,
             Nota.Importe_Venta                            AS Importe_Venta,
             ABS( NVL( DOI.Saldo_SAP, 0 ) )                AS Saldo_SAP    ,
             CFD.Folio_Fiscal                              AS Folio_Fiscal
         FROM (
                SELECT
                       Nota.Ctro                           AS Ctro         ,
                       Nota.Fecha_Venta                    AS Fecha_Venta  ,
                       Nota.Nota_Venta                     AS Nota_Venta   ,
                       Nota.Cliente_SAP                    AS Cliente_SAP  ,
                       Nota.RFC                            AS RFC          ,
                       SUM( Nota.Importe_Item )            AS Importe_Venta
                   FROM (
                          SELECT  
                                  FG.Ctro                  AS Ctro         ,
                                  FG.Fecha_Factura         AS Fecha_Venta  ,
                                  FG.Factura               AS Nota_Venta   ,
                                  FD.Material              AS Material     ,
                                  FG.Cliente_SAP           AS Cliente_SAP  ,
                                  Cte.RFC                  AS RFC          ,
                                  NVL( FD.Valor_Subt, 0 ) +
                                  NVL( FD.Valor_IVA , 0 ) +
                                  NVL( FD.Envio_Subt, 0 ) +
                                  NVL( FD.Envio_IVA , 0 )   AS Importe_Item
                             FROM T3.Factura_General FG ,
                                  T3.Factura_Detalle FD ,
                                  T3.Cliente         Cte
                             WHERE FG.Fecha_Factura  >= TO_DATE( '20230101', 'YYYYMMDD' )
                               AND FG.Tipo_Docto      = 'C004'
                               AND FG.Factura         = FD.Factura
                               AND FG.Cliente_SAP     = Cte.Cliente_SAP
                               AND FG.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                               AND Cte.RFC           != 'XAXX010101000'
                            UNION ALL
                          SELECT  
                                  FG.Ctro                  AS Ctro         ,
                                  FG.Fecha_Factura         AS Fecha_Venta  ,
                                  FG.Factura               AS Nota_Venta   ,
                                  FD.Material              AS Material     ,
                                  FG.Cliente_SAP           AS Cliente_SAP  ,
                                  Cte.RFC                  AS RFC          ,
                                  NVL( FD.Valor_Subt, 0 ) +
                                  NVL( FD.Valor_IVA , 0 ) +
                                  NVL( FD.Envio_Subt, 0 ) +
                                  NVL( FD.Envio_IVA , 0 )   AS Importe_Item
                             FROM T3.Preventa_General FG ,
                                  T3.Preventa_Detalle FD ,
                                  T3.Cliente          Cte
                             WHERE FG.Fecha_Factura     >= TO_DATE( '20230101', 'YYYYMMDD' )
                               AND FG.Clase_Factura     IN ( 'C006', 'C019', 'C025' )
                               AND FG.Fecha_Proc_BATMD  IS NOT NULL
                               AND FG.Fecha_Cancelacion IS NULL
                               AND FG.Factura            = FD.Factura
                               AND FG.Cliente_SAP        = Cte.Cliente_SAP
                               AND FG.Fecha_Factura     BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                               AND Cte.RFC              != 'XAXX010101000'
                        ) Nota
                    GROUP BY Nota.Ctro, Nota.Fecha_Venta, Nota.Nota_Venta, Nota.Cliente_SAP, Nota.RFC
             ) Nota,
             ( SELECT 
                      SAP.Referencia                 AS Nota_Venta ,
                      MAX( SAP.Cliente )             AS Cliente_SAP,
                      MIN( SAP.Fecha_Doc )           AS Fecha_Doc  ,
                      SUM( NVL( SAP.Monto, 0 ) )     AS Saldo_SAP
                   FROM EAI.T3R_Cartera_SAP_OLD  SAP
                   GROUP BY SAP.Referencia ) DOI,
             T3.CFDI_Documentos CFD      
      WHERE Nota.Nota_Venta = DOI.Nota_Venta(+)      
        AND Nota.Nota_Venta = CFD.Nota_Venta(+) ;
      COMMIT ;   
   END IF ;
--
   v_ID := 'ScrPrompt' ;
   IF ( NVL( nEtapa, 0 ) <= 010 ) THEN
      sFecha := '010' ;
      FOR Doc IN ScrPrompt LOOP
         sFactura := Doc.Nota_Venta ;
         FOR Cobza IN ScrCobza LOOP
            UPDATE EAI.CFDI_UUID_NOTA_CREDITO SET
                                                  Aplica_NC        = Cobza.Aplicaciones    ,
                                                  Importe_NC       = Cobza.Importe_Aplicado,
                                                  Fecha_Aplicacion = Cobza.Fecha_Asignacion,
                                                  Incobrable       = Cobza.Incobrable
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
          'Error'             , 'SF_CFDI_NOTA_CREDITO'   , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                     , NULL                , NULL            ) ;
      COMMIT ; 
      DBMS_Output.Put_LINE( '-----------------------------------' ) ;
      DBMS_Output.Put_LINE( '** Error en SF_CFDI_NOTA_CREDITO **'  ) ;
      DBMS_Output.Put_LINE( sMsg ) ;      
END ;