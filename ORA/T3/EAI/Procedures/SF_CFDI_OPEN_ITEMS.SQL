create or replace PROCEDURE     "SF_CFDI_OPEN_ITEMS"
      ( nEtapa IN NUMBER DEFAULT 0  )
IS
   nDist               NUMBER(3)     ;
   sCtro               VARCHAR2(4)   ;
   dtFecha             DATE          ;     
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
   nImporte_Aplicado    NUMBER(16,2)  ;
   nImporte_Timbrado    NUMBER(16,2)  ;
--
    CURSOR ScrVenta IS
       SELECT Vta.Ctro, Vta.Fecha_Venta, Vta.Nota_Venta, CFD.Metodo_Pago
          FROM EAI.CFDI_OPEN_ITEMS Vta, T3.CFDI_Documentos CFD
          WHERE Vta.Tipo_Docto = 'Vta'
            AND Vta.Nota_Venta = CFD.Nota_Venta(+)
          ORDER BY Vta.Fecha_Venta, Vta.Ctro, Vta.Nota_Venta ;  
--
    CURSOR ScrDevolucion IS
       SELECT Ctro, Fecha_Venta, Nota_Venta
          FROM EAI.CFDI_OPEN_ITEMS
          WHERE Tipo_Docto = 'Dev'
          ORDER BY Fecha_Venta, Ctro, Nota_Venta ;
--
    CURSOR ScrHistorico IS
     SELECT 
            Vta.Ctro                                       AS Ctro            ,
            Vta.Fecha_Venta                                AS Fecha_Venta     ,
            Vta.Clase_Factura                              AS Clase_Factura   ,
            Vta.Nota_Venta                                 AS Nota_Venta      ,
            Vta.Cliente_SAP                                AS Cliente_SAP     ,
            Vta.RFC                                        AS RFC             ,
            Vta.Importe_Venta                              AS Importe_Venta   ,
            DOI.Last_Updated                               AS Last_Updated
        FROM (
                SELECT
                       Nota.Ctro                           AS Ctro         ,
                       Nota.Fecha_Venta                    AS Fecha_Venta  ,
                       Nota.Clase_Factura                  AS Clase_Factura,
                       Nota.Nota_Venta                     AS Nota_Venta   ,
                       Nota.Cliente_SAP                    AS Cliente_SAP  ,
                       Nota.RFC                            AS RFC          ,
                       SUM( Nota.Importe_Item )            AS Importe_Venta
                   FROM (
                          SELECT  
                                  FG.Ctro                    AS Ctro         ,
                                  FG.Fecha_Factura           AS Fecha_Venta  ,
                                  FG.Tipo_Docto              AS Clase_Factura,
                                  FG.Factura                 AS Nota_Venta   ,
                                  FD.Material                AS Material     ,
                                  FG.Cliente_SAP             AS Cliente_SAP  ,
                                  Cte.RFC                    AS RFC          ,
                                  NVL( FD.Valor_Subt  , 0 ) +
                                  NVL( FD.Valor_IVA   , 0 ) +
                                  NVL( FD.Credito_Subt, 0 ) +
                                  NVL( FD.Credito_IVA , 0 ) +
                                  NVL( FD.Envio_Subt  , 0 ) +
                                  NVL( FD.Envio_IVA   , 0 )   AS Importe_Item
                             FROM T3.Factura_General FG ,
                                  T3.Factura_Detalle FD ,
                                  T3.Cliente         Cte
                             WHERE FG.Fecha_Factura  >= TO_DATE( '20230101', 'YYYYMMDD' )
                               AND FG.Tipo_Docto     IN ( 'C003', 'C004' )
                               AND FG.Factura         = FD.Factura
                               AND FG.Cliente_SAP     = Cte.Cliente_SAP
                               AND FG.Fecha_Factura  BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                          UNION ALL
                          SELECT  
                                  FG.Ctro                    AS Ctro         ,
                                  FG.Fecha_Factura           AS Fecha_Venta  ,
                                  FG.Clase_Factura           AS Clase_Factura,
                                  FG.Factura                 AS Nota_Venta   ,
                                  FD.Material                AS Material     ,
                                  FG.Cliente_SAP             AS Cliente_SAP  ,
                                  Cte.RFC                    AS RFC          ,
                                  NVL( FD.Valor_Subt  , 0 ) +
                                  NVL( FD.Valor_IVA   , 0 ) +
                                  NVL( FD.Credito_Subt, 0 ) +
                                  NVL( FD.Credito_IVA , 0 ) +
                                  NVL( FD.Envio_Subt  , 0 ) +
                                  NVL( FD.Envio_IVA   , 0 )   AS Importe_Item
                             FROM T3.Preventa_General FG ,
                                  T3.Preventa_Detalle FD ,
                                  T3.Cliente          Cte
                             WHERE FG.Fecha_Factura     >= TO_DATE( '20230101', 'YYYYMMDD' )
                               AND FG.Clase_Factura     IN ( 'C005', 'C006', 'C019', 'C025' )
                               AND FG.Fecha_Proc_BATMD  IS NOT NULL
                               AND FG.Fecha_Cancelacion IS NULL
                               AND FG.Factura            = FD.Factura
                               AND FG.Cliente_SAP        = Cte.Cliente_SAP
                               AND FG.Fecha_Factura     BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                        ) Nota
                    GROUP BY Nota.Ctro, Nota.Fecha_Venta, Nota.Clase_Factura, Nota.Nota_Venta, Nota.Cliente_SAP, Nota.RFC  ) Vta,
                  EAI.CFDI_OPEN_ITEMS  DOI
          WHERE Vta.Nota_Venta = DOI.Nota_Venta(+)       ;    
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
                       ( SELECT CAP.Agrupacion                          AS Agrupacion, 
                                CAP.Fecha_Pago                          AS Fecha_Pago, 
                                CAP.Asignacion_Id                       AS Asignacion_Id
                         FROM T3.CFDI_Agrupacion_Pago CAP, T3.CFDI_Agrupacion_Ctrl CAC
                         WHERE CAP.Agrupacion = CAC.Agrupacion
                         AND NVL(CAC.Importe,0) != 0) AgrP ,   
                      T3.CFDI_Documentos        Agr  , 
                      T3.CFDI_Documentos        Nota
                 WHERE Cobza.Factura              = sFactura
                   AND Cobza.Asignacion_ID        = Pago.Nota_Venta(+)
                   AND Cobza.Asignacion_ID        = AgrP.Asignacion_ID(+)
                   AND TO_CHAR( AgrP.Agrupacion ) = Agr.Nota_Venta(+)
                   AND Cobza.Nota_Credito         = Nota.Nota_Venta(+) ) Cobza
      GROUP BY Cobza.Factura ;    
--
    CURSOR ScrCreditMemo IS
                 SELECT 
                        COUNT( Cobza.Asignacion_ID   )  AS Aplicaciones    ,
                        SUM( NVL( Cobza.Importe, 0 ) * DECODE( Cobza.Via_Pago, 'CM', 1, 0 ) )  
                                                        AS Importe_Aplicado,
                        SUM( NVL( Cobza.Importe, 0 ) * DECODE( Cobza.Via_Pago, 'AI', 1, 0 ) )  
                                                        AS Incobrable      ,
                        MAX( Cobza.Fecha_Asignacion  )  AS Fecha_Asignacion
                    FROM T3.CFDI_Cobranza Cobza
                    WHERE Cobza.Nota_Credito = sFactura ;      
--
    CURSOR ScrImporteVenta IS
                      SELECT FG.Factura                            AS Nota_Venta,
                             FG.Ctro                               AS Ctro      ,
                             MC.RFC                                AS RFC       ,
                             SUM(
                                  NVL( FD.Valor_Subt  , 0 ) +
                                  NVL( FD.Valor_IVA   , 0 ) +
                                  NVL( FD.Envio_Subt  , 0 ) +
                                  NVL( FD.Envio_IVA   , 0 ) +
                                  NVL( FD.Credito_Subt, 0 ) +
                                  NVL( FD.Credito_IVA , 0 ) )     AS Importe_Vta
                              FROM EAI.CFDI_OPEN_ITEMS        DOI,
                                   T3.Registro_Fiscal         FG ,
                                   T3.Registro_Fiscal_Detalle FD ,
                                   T3.Mov_Cliente             MC
                              WHERE DOI.Nota_Venta = FG.Factura
                                AND FG.Factura     = FD.Factura
                                AND FG.Cliente_SAP = MC.Cliente_SAP(+)
                         GROUP BY FG.Factura, FG.Ctro, MC.RFC ;    
--
    CURSOR ScrImporteDebitNote IS
       SELECT DOI.Nota_Venta    AS Nota_Venta    ,
              DN.Total_Amt      AS Importe       ,
              DN.Document_Date  AS Fecha_Docto   ,
              DN.Created        AS Fecha_Creacion,
              MC.RFC            AS RFC           ,
              MC.Ctro           AS Ctro          
          FROM EAI.CFDI_Open_Items DOI,
               T3.DEBIT_NOTE_IFC   DN ,
               T3.Mov_Cliente      MC
          WHERE DOI.Nota_Venta = DN.Debit_Note 
            AND DN.Cust_to_SAP = MC.Cliente_SAP ;
--
    CURSOR ScrFiscal IS
        SELECT DOI.Nota_Venta, DOI.RFC, HDP.Nota_Venta_CFDI, CFD.Fecha_Liberacion, CFD.Folio_Fiscal, CFD.Metodo_Pago
           FROM EAI.CFDI_OPEN_ITEMS          DOI,
                T3.CFDI_Historia_Docto_PAC   HDP,
                T3.CFDI_Documentos           CFD
           WHERE DOI.Nota_Venta      = HDP.Nota_Venta
             AND HDP.Nota_Venta_CFDI = CFD.Nota_Venta(+) ;    
--
    CURSOR ScrUUID_Creditos IS
        SELECT DOI.Nota_Venta                              AS Nota_Venta      , 
               NVL( HDP.Nota_Venta_CFDI, DOI.Nota_Venta  ) AS Nota_Venta_CFDI ,
               CFD.Fecha_Liberacion                        AS Fecha_Liberacion,
               DECODE( CFD.Folio_Fiscal, NULL, 0, 1 )      AS Timbrado
           FROM EAI.CFDI_OPEN_ITEMS        DOI,
                T3.CFDI_Historia_Docto_PAC HDP,
                T3.CFDI_Documentos         CFD
           WHERE DOI.Tipo_Docto = 'Dev'
             AND DOI.Nota_Venta = HDP.Nota_Venta(+)
             AND NVL( HDP.Nota_Venta_CFDI, DOI.Nota_Venta  ) = CFD.Nota_Venta ;
--
    CURSOR ScrClte_Factura_SAP IS
        SELECT DOI.ROWID AS DOI_ROWID, DOI.Nota_Venta, PG.Clte_Factura_SAP 
           FROM EAI.CFDI_OPEN_ITEMS DOI,
                T3.Preventa_General PG
           WHERE DOI.Nota_Venta       = PG.Factura   
             AND PG.Clte_Factura_SAP IS NOT NULL
             AND PG.Cliente_SAP      != PG.Clte_Factura_SAP  
        UNION ALL
        SELECT DOI.ROWID AS DOI_ROWID, DOI.Nota_Venta, FG.Clte_Factura_SAP 
           FROM EAI.CFDI_OPEN_ITEMS DOI,
                T3.Factura_General  FG
           WHERE DOI.Nota_Venta       = FG.Factura     
             AND FG.Clte_Factura_SAP IS NOT NULL
             AND FG.Cliente_SAP      != FG.Clte_Factura_SAP ;
BEGIN
-- Inicio
   dtInicio  := SYSDATE ;
   nProceso  := 923 ;
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
   v_ID      := 'CFDI_OPEN_ITEMS' ;
   IF ( NVL( nEtapa, 0 )  <= 000 ) THEN
      DELETE FROM EAI.CFDI_OPEN_ITEMS ;
      INSERT INTO EAI.CFDI_OPEN_ITEMS 
         ( Nota_Venta, Cliente_SAP, Fecha_Venta, Tipo_Docto, Saldo_SAP, Last_Updated )  
              SELECT
                     DOI.Nota_Venta                                AS Nota_Venta  ,
--                   DOI.Asignacion                                AS Asignacion  ,
                     DOI.Cliente_SAP                               AS Cliente_SAP ,
                     TO_DATE( DOI.Fecha_Doc, 'YYYYMMDD' )          AS Fecha_Venta ,
                     CASE
                         WHEN ( DOI.Tipo_Docto IN ( 'C003', 'C005'                 ) ) THEN 'Vta'
                         WHEN ( DOI.Tipo_Docto IN ( 'C004', 'C006', 'C019', 'C025' ) ) THEN 'Dev'
                         ELSE
                             DECODE( DOI.Saldo_SAP, ABS( DOI.Saldo_SAP ), 'Vta', 'Dev' )
                     END                                           AS Tipo_Docto  ,
               --    ABS( DOI.Saldo_SAP )                          AS Saldo_SAP   ,
                     CASE
                         WHEN ( DOI.Tipo_Docto IN ( 'C003', 'C005'                 ) ) THEN DOI.Saldo_SAP                          
                         ELSE
                              ABS( DOI.Saldo_SAP )
                     END                                           AS Saldo_SAP   ,
                     SYSDATE                                       AS Last_Updated
                         FROM (
                                SELECT 
                                    SAP.Referencia                 AS Nota_Venta ,
                                    NVL( RF.Tipo_Docto, 'NULL' )   AS Tipo_Docto ,
                                    MAX( SAP.Asignacion )          AS Asignacion ,
                                    MAX( SAP.Cliente )             AS Cliente_SAP,
                                    MIN( SAP.Fecha_Doc )           AS Fecha_Doc  ,
                                    SUM( NVL( SAP.Monto, 0 ) )     AS Saldo_SAP
                                FROM (
                                       SELECT SAP.Cliente                             AS Cliente   ,
                                              NVL( Conv.Docto_T3MX, SAP.Referencia )  AS Referencia,
                                              SAP.Fecha_Doc                           AS Fecha_Doc ,
                                              SAP.Tipo_Doc                            AS Tipo_Doc  ,
                                              SAP.Monto                               AS Monto     ,
                                              SAP.Asignacion                          AS Asignacion
                                          FROM EAI.T3R_Cartera_SAP_OLD  SAP , 
                                               ( SELECT Docto_SAP, Docto_T3MX FROM T3.CFDI_Refoleo WHERE Tipo_Registro = 'DOI' ) Conv
                                          WHERE SAP.Referencia = Conv.Docto_SAP(+)                                
                                     )                        SAP,
                                     T3.Registro_Fiscal       RF
                                WHERE SAP.Referencia = RF.Factura(+)     
                                  AND SAP.Referencia NOT IN ( SELECT Factura FROM T3.Otros_General )
                                GROUP BY SAP.Referencia, NVL( RF.Tipo_Docto, 'NULL' ) ) DOI ;
      nProceso1 := SQL%ROWCOUNT ;                          
      COMMIT ;   
   END IF ;

--
   v_ID := 'Historico' ;
   IF ( NVL( nEtapa, 0 ) <= 010 ) THEN
      FOR Doc IN ScrHistorico LOOP
         sFactura := Doc.Nota_Venta ;
         IF ( Doc.Last_Updated IS NULL ) THEN
            IF ( Doc.Clase_Factura IN ( 'C003', 'C005' ) ) THEN
                nImporte_Aplicado := T3.FN_Cobza_Pay( sFactura ) ;
                sNULL := 'Vta' ;
            ELSE
             -- nImporte_Aplicado := T3.FN_Cobza_CM( sFactura ) ;
                nImporte_Aplicado := T3.FN_COBZA_CM_UUID( sFactura ) ;
                sNULL := 'Dev' ;
            END IF ;
            IF ( ABS( NVL( Doc.Importe_Venta, 0 ) - NVL( nImporte_Aplicado, 0 ) ) > 0.05 ) THEN
               nProceso4 := nProceso4 + 1 ;  
               INSERT INTO EAI.CFDI_OPEN_ITEMS
                  ( Ctro, Nota_Venta, Cliente_SAP, Clte_Factura_SAP, Fecha_Venta, Tipo_Docto, Importe_Vta, Last_Updated )  
               VALUES
                  ( Doc.Ctro, Doc.Nota_Venta, Doc.Cliente_SAP, Doc.Cliente_SAP, Doc.Fecha_Venta, sNULL, Doc.Importe_Venta, SYSDATE ) ;
            END IF ;
         END IF ;
         IF ( MOD( nProceso4, 100 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ScrVenta' ;
   IF ( NVL( nEtapa, 0 ) <= 020 ) THEN
      FOR Doc IN ScrVenta LOOP
         sFactura := Doc.Nota_Venta ;
         FOR Cobza IN ScrCobza LOOP
            UPDATE EAI.CFDI_OPEN_ITEMS SET
                                           Importe        = Cobza.Importe       ,
                                           Efectivo       = Cobza.Efectivo      ,
                                           Agrupado       = Cobza.Agrupado      ,
                                           Aplica_NC      = Cobza.Aplica_NC     ,
                                           Efectivo_UUID  = Cobza.Efectivo_UUID ,
                                           Agrupado_UUID  = Cobza.Agrupado_UUID ,
                                           Aplica_NC_UUID = Cobza.Aplica_NC_UUID,
                                           Importe_UUID   = Cobza.Importe_UUID  ,
                                           Incobrable     = Cobza.Incobrable    ,
                                           Metodo_Pago    = Doc.Metodo_Pago     ,
                                           Tipo_Docto     = 'Vta'               ,
                                           Last_Updated   = SYSDATE
               WHERE Nota_Venta = sFactura ;
         END LOOP ;
         nProceso2 := nProceso2 + 1 ;  
         IF ( MOD( nProceso2, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ScrDevolucion' ;
   IF ( NVL( nEtapa, 0 ) <= 030 ) THEN
      FOR Doc IN ScrDevolucion LOOP
         sFactura := Doc.Nota_Venta ;
         FOR Cobza IN ScrCreditMemo LOOP
            UPDATE EAI.CFDI_OPEN_ITEMS SET
                                           Importe_NC       = Cobza.Importe_Aplicado,
                                           Incobrable       = Cobza.Incobrable      ,
                                           Fecha_Aplicacion = Cobza.Fecha_Asignacion,
                                           Tipo_Docto       = 'Dev'                 ,
                                           Last_Updated     = SYSDATE
               WHERE Nota_Venta = sFactura ;
         END LOOP ;
         nProceso2 := nProceso2 + 1 ;  
         IF ( MOD( nProceso2, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ImporteVenta' ;
   IF ( NVL( nEtapa, 0 ) <= 060 ) THEN
      FOR Doc IN ScrImporteVenta LOOP
            sFactura := Doc.Nota_Venta ;
            UPDATE EAI.CFDI_OPEN_ITEMS SET
                                           Ctro             = Doc.Ctro       ,
                                           RFC              = Doc.RFC        ,
                                           Importe_Vta      = Doc.Importe_Vta,
                                           Last_Updated     = SYSDATE
               WHERE Nota_Venta = sFactura ;
         nProceso3 := nProceso3 + 1 ;  
         IF ( MOD( nProceso3, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
      FOR Doc IN ScrImporteDebitNote LOOP
            sFactura := Doc.Nota_Venta ;
            UPDATE EAI.CFDI_OPEN_ITEMS SET
                                           Ctro             = Doc.Ctro       ,
                                           RFC              = Doc.RFC        ,
                                           Importe_Vta      = Doc.Importe    ,
                                           Last_Updated     = SYSDATE
               WHERE Nota_Venta = sFactura ;
         nProceso3 := nProceso3 + 1 ;  
         IF ( MOD( nProceso3, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'Fiscal' ;
   IF ( NVL( nEtapa, 0 ) <= 070 ) THEN
      FOR Doc IN ScrFiscal LOOP
            sFactura := Doc.Nota_Venta ;
            UPDATE EAI.CFDI_OPEN_ITEMS SET
                                           Nota_Venta_CFDI = Doc.Nota_Venta_CFDI,
                                           Folio_Fiscal    = Doc.Folio_Fiscal   ,
                                           Metodo_Pago     = Doc.Metodo_Pago    ,
                                           Last_Updated    = SYSDATE
               WHERE Nota_Venta = sFactura ;
         nProceso3 := nProceso3 + 1 ;  
         IF ( MOD( nProceso3, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;   
--
   v_ID := 'ScrUUID_Creditos' ;
   IF ( NVL( nEtapa, 0 ) <= 080 ) THEN
      FOR Doc IN ScrUUID_Creditos LOOP
            sFactura := Doc.Nota_Venta ;
            UPDATE EAI.CFDI_OPEN_ITEMS SET Importe_NC_UUID = Doc.Timbrado * NVL( Importe_NC, 0 ),
                                           Last_Updated    = SYSDATE
               WHERE Nota_Venta = sFactura ;
         nProceso3 := nProceso3 + 1 ;  
         IF ( MOD( nProceso3, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;   
--
   v_ID := 'ScrClte_Factura_SAP' ;
   IF ( NVL( nEtapa, 0 ) <= 090 ) THEN
      FOR Doc IN ScrClte_Factura_SAP LOOP
            sFactura := Doc.Nota_Venta ;
            UPDATE EAI.CFDI_OPEN_ITEMS SET Clte_Factura_SAP = Doc.Clte_Factura_SAP,
                                           Last_Updated     = SYSDATE
               WHERE ROWID = Doc.DOI_ROWID ;
         nProceso3 := nProceso3 + 1 ;  
         IF ( MOD( nProceso3, 1000 ) = 0 ) THEN
            COMMIT ;
         END IF ;
      END LOOP ;
      COMMIT ;
   END IF ;   
   UPDATE EAI.CFDI_Open_Items DOI SET ( RFC, Ctro ) = ( SELECT MAX( MC.RFC ), MAX( MC.Ctro ) FROM T3.Mov_Cliente MC WHERE MC.Cliente_SAP = DOI.Cliente_SAP )
      WHERE DOI.RFC IS NULL ;
--      
   UPDATE EAI.CFDI_OPEN_ITEMS DOI SET Importe_Vta = Importe_Vta + EAI_Owner.Fn_Get_Tax_Issue( DOI.Nota_Venta )
      WHERE DOI.Tipo_Docto = 'Dev' ;      
--
   UPDATE EAI.CFDI_OPEN_ITEMS DOI SET ( PedidoSAP, FacturaSAP ) =
       ( SELECT RF.Pedido, RF.Entrega FROM T3.Registro_Fiscal RF WHERE RF.Factura = DOI.Nota_Venta ) ;
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
          'Error'             , 'SF_CFDI_OPEN_ITEMS'     , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                     , NULL                , NULL            ) ;
      COMMIT ; 
      DBMS_Output.Put_LINE( '--------------------------------------' ) ;
      DBMS_Output.Put_LINE( '**** Error en SF_CFDI_OPEN_ITEMS *****' ) ;
      DBMS_Output.Put_LINE( sMsg ) ;      
END ;