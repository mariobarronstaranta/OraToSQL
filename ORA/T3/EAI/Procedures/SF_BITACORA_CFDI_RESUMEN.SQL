create or replace PROCEDURE     "SF_BITACORA_CFDI_RESUMEN" 
   ( pFecha_Inicio     IN  VARCHAR2,
     pFecha_Final      IN  VARCHAR2 )
IS
-- Define Variables
   v_ID                 VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;      
   sMsg                 VARCHAR2(300) ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;   
--
   sPrograma            VARCHAR2(030) ;
   sPrograma2           VARCHAR2(030) ;
   nCount               NUMBER(10)    ;
   sFecha_Inicio        VARCHAR2(030) ;
   sFecha_Final         VARCHAR2(030) ;
   sAgrupada            VARCHAR2(030) ;
--
   CURSOR ScrPrompt IS       
       SELECT 
               'MX06'                                      AS Sociedad       ,
--             Cte.RFC                                     AS RFC            ,
               Paso.RFC_Factura                            AS RFC            , 
               Cte.Nombre                                  AS Nombre_Cliente ,
               Cte.Lista_Precio                            AS LP             ,
               HDoc.Nota_Venta_CFDI                        AS Folio_Interno  ,
               HDoc.Fecha_Factura                          AS Fecha          ,
               HDoc.Ctro                                   AS Ctro           ,
               PAC.Status                                  AS Status         ,
               PAC.Folio_Fiscal                            AS Folio_Fiscal   ,
               PAC.ID_Envio                                AS ID_Envio       ,
               PAC.ID_Confirmacion                         AS ID_Confirmacion,
               SUBSTR( FG.Ubicacion, 15, 4 )               AS Terr           ,
               FG.Tipo_Docto                               AS Tipo_Docto     ,
               DECODE( FG.Tipo_Docto, 'C003', 1, -1 )      AS Factor         ,
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_Subt
                  WHEN ( PAC.Status = 'PENDING'    ) THEN FG.Valor_Subt
                  WHEN ( PAC.Status = 'PUBLICADO'  ) THEN FG.Valor_Subt
--                WHEN ( PAC.Status = 'ERROR'      ) THEN FG.Valor_Subt
                  ELSE
                      0
               END                                         AS Valor_Subt     , 
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_IVA
                  WHEN ( PAC.Status = 'PENDING'    ) THEN FG.Valor_IVA
                  WHEN ( PAC.Status = 'PUBLICADO'  ) THEN FG.Valor_IVA
--                WHEN ( PAC.Status = 'ERROR'      ) THEN FG.Valor_IVA
                  ELSE
                      0
               END                                         AS Valor_IVA     ,
               NVL( FG.Valor_Subt, 0 ) + 
               NVL( FG.Valor_IVA , 0 )                     AS Total_T3In
          FROM T3.CFDI_Historia_Docto_PAC   HDoc,
               T3.CFDI_Documento_Paso       Paso,  
               T3.Factura_General           FG  ,
               T3.CFDI_Documentos           PAC ,
               T3.Cliente                   Cte
          WHERE TO_CHAR( HDoc.Fecha_Factura, 'YYYYMMDD' ) BETWEEN sFecha_Inicio AND sFecha_Final
            AND HDoc.Nota_Venta  = HDoc.Nota_Venta_CFDI
            AND HDoc.Nota_Venta  = FG.Factura
            AND HDoc.Nota_Venta  = Paso.Factura
            AND FG.Cliente_SAP   = Cte.Cliente_SAP
            AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
            AND HDoc.Nota_Venta  = PAC.Nota_Venta ;
--
   CURSOR ScrPreventa IS
       SELECT 
               DECODE( PG.Clase_Factura, 'C020', 'MX01',
                                         'C021', 'MX01',
                                         'C022', 'MX01',
                                         'MX06' )          AS Sociedad       ,
               Cte.RFC                                     AS RFC            ,                           
               Cte.Nombre                                  AS Nombre_Cliente ,
               Cte.Lista_Precio                            AS LP             ,
               HDoc.Nota_Venta_CFDI                        AS Folio_Interno  ,
               HDoc.Fecha_Factura                          AS Fecha          ,
               HDoc.Ctro                                   AS Ctro           ,
               PAC.Status                                  AS Status         ,
               PAC.Folio_Fiscal                            AS Folio_Fiscal   ,
               PAC.ID_Envio                                AS ID_Envio       ,
               PAC.ID_Confirmacion                         AS ID_Confirmacion,               
--             PG.Ubicacion                                AS Terr           ,
               NVL( E.Ubicacion, PG.Ubicacion )            AS Terr           ,               
               PG.Clase_Factura                            AS Tipo_Docto     ,
               DECODE( PG.Clase_Factura, 'C005', 1, 
                                         'C0FX', 1, 
                                         'C020', 1, 
                                                -1 )       AS Factor         ,               
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_Subt
                  WHEN ( PAC.Status = 'PENDING'    ) THEN PG.Valor_Subt
                  WHEN ( PAC.Status = 'PUBLICADO'  ) THEN PG.Valor_Subt
--                WHEN ( PAC.Status = 'ERROR'      ) THEN PG.Valor_Subt
                  ELSE
                      0
               END                                         AS Valor_Subt     , 
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_IVA
                  WHEN ( PAC.Status = 'PENDING'    ) THEN PG.Valor_IVA
                  WHEN ( PAC.Status = 'PUBLICADO'  ) THEN PG.Valor_IVA
--                WHEN ( PAC.Status = 'ERROR'      ) THEN PG.Valor_IVA
                  ELSE
                      0
               END                                         AS Valor_IVA      ,
--             NVL( PG.Valor_Subt, 0 ) + 
--             NVL( PG.Valor_IVA , 0 )                     AS Total_T3In
               CASE
                   WHEN PG.Fecha_Cancelacion IS NOT NULL                 THEN 0
                   WHEN TO_CHAR( PG.Fecha_Proc_BATMD, 'YYYY' ) = '2999'  THEN 0
                   ELSE
                      NVL( PG.Valor_Subt, 0 ) + 
                      NVL( PG.Valor_IVA , 0 )   
               END                                         AS Total_T3In
          FROM T3.CFDI_Historia_Docto_PAC   HDoc,
               T3.Preventa_General          PG  ,
               T3.CFDI_Documentos           PAC ,
               T3.Cliente                   Cte ,
               T3.Entrega                   E
          WHERE TO_CHAR( HDoc.Fecha_Factura, 'YYYYMMDD' ) BETWEEN sFecha_Inicio AND sFecha_Final
            AND HDoc.Nota_Venta  = HDoc.Nota_Venta_CFDI
            AND HDoc.Nota_Venta  = PG.Factura
            AND HDoc.Nota_Venta  = E.Factura(+)
            AND PG.Cliente_SAP   = Cte.Cliente_SAP
            AND PG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
            AND HDoc.Nota_Venta = PAC.Nota_Venta ;
--
   CURSOR ScrAgrupado IS
       SELECT 
               'MX06'                                      AS Sociedad       ,
               'XAXX010101000'                             AS RFC            ,
               FG.Doctos                                   AS Doctos         , 
              'CLIENTE AGRUPADOR VENTAS DIA'               AS Nombre_Cliente ,               
               Doc.Nota_Venta_CFDI                         AS Folio_Interno  ,
               Doc.Fecha_Factura                           AS Fecha          ,
               Doc.Ctro                                    AS Ctro           ,
               PAC.Status                                  AS Status         ,
               PAC.Folio_Fiscal                            AS Folio_Fiscal   ,
               PAC.ID_Envio                                AS ID_Envio       ,
               PAC.ID_Confirmacion                         AS ID_Confirmacion,               
               FG.Terr                                     AS Terr           ,
               FG.Tipo_Docto                               AS Tipo_Docto     ,
               DECODE( FG.Tipo_Docto, 'C003', 1, 
                                                -1 )       AS Factor         ,               
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_Subt
                  WHEN ( PAC.Status = 'PENDING'    ) THEN FG.Valor_Subt
--                WHEN ( PAC.Status = 'ERROR'      ) THEN FG.Valor_Subt
                  ELSE
                      0
               END                                         AS Valor_Subt     , 
               CASE
                  WHEN ( PAC.Status = 'CONFIRMADO' ) THEN PAC.Valor_IVA
                  WHEN ( PAC.Status = 'PENDING'    ) THEN FG.Valor_IVA
--                WHEN ( PAC.Status = 'ERROR'      ) THEN FG.Valor_IVA
                  ELSE
                      0
               END                                         AS Valor_IVA      ,
               Doc.Total_T3In                              AS Total_T3In
          FROM (
                 SELECT  HDoc.Ctro, HDoc.Fecha_Factura, HDoc.Nota_Venta_CFDI, SUM( FD.Valor_Subt + FD.Valor_IVA + NVL( FD.Envio_Subt, 0 ) + NVL( FD.Envio_IVA, 0 ) ) AS Total_T3In
                    FROM (
                             SELECT DISTINCT Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI
                                FROM T3.CFDI_Historia_Docto_PAC
                                WHERE TO_CHAR( Fecha_Factura, 'YYYYMMDD' ) BETWEEN sFecha_Inicio AND sFecha_Final
                         )                            HDoc,
                         T3.Factura_General           FG,
                         T3.Factura_Detalle           FD
                    WHERE TO_CHAR( HDoc.Fecha_Factura, 'YYYYMMDD' ) BETWEEN sFecha_Inicio AND sFecha_Final
                      AND HDoc.Nota_Venta != HDoc.Nota_Venta_CFDI
                      AND HDoc.Nota_Venta  = FG.Factura
                      AND HDoc.Nota_Venta  = FD.Factura
                    GROUP BY HDoc.Ctro, HDoc.Fecha_Factura, HDoc.Nota_Venta_CFDI  
               ) Doc,
               (
                 SELECT 
                        Agr.Ctro                                                     AS Ctro           ,
                        SUBSTR( Agr.Cliente_SAP, 2, 5 )                              AS Terr           ,
                        Agr.Tipo_Docto                                               AS Tipo_Docto     ,
                        Agr.Nota_Venta_CFDI                                          AS Nota_Venta_CFDI, 
                        TRUNC( Fecha_Documento )                                     AS Fecha          ,
                        MAX( Agr.Doctos )                                            AS Doctos         ,
                        SUM( Det.Valor_Subt + NVL( Det.Envio_Subt, 0 ) + NVL( Det.Credito_Subt, 0 ) )             
                                                                                     AS Valor_Subt     ,
                        SUM( Det.Valor_IVA  + NVL( Det.Envio_IVA , 0 ) + NVL( Det.Credito_IVA , 0 ) )             
                                                                                     AS Valor_IVA
                 FROM T3.CFDI_Agrupado          Agr,
                      T3.CFDI_Agrupado_Detalle  Det
                 WHERE Agr.Nota_Venta_CFDI = Det.Nota_Venta_CFDI     
                 GROUP BY Agr.Ctro, SUBSTR( Agr.Cliente_SAP, 2, 5 ), Agr.Tipo_Docto,
                        Agr.Nota_Venta_CFDI, TRUNC( Fecha_Documento )
               ) FG,         
               T3.CFDI_Documentos           PAC
          WHERE Doc.Nota_Venta_CFDI = FG.Nota_Venta_CFDI
            AND Doc.Nota_Venta_CFDI = PAC.Nota_Venta ;
--
   CURSOR ScrCIG_Individual IS
         SELECT CFD.RowID AS CFD_RowID, RF.Factura,
                SUM( CFD.Factor * RFD.Cantidad_Vta    
                    * DECODE( Prod.Unidad_Med_Vta, 'CAJ', NVL( Prod.Cig_x_CLL, 1), NVL( Prod.Cig_x_PAQ, 1 ) ) )
                                                                                     AS Cigarrillos  ,
                MAX( DECODE( RF.Tipo_Docto, 'C005', 0, 'C006', 0, 1 ) )              AS Sumar_Envio  ,
                SUM( NVL( RFD.Envio_Subt  , 0 ) )                                    AS Envio_Subt   ,
                SUM( NVL( RFD.Envio_IVA   , 0 ) )                                    AS Envio_IVA    ,
                SUM( NVL( RFD.Credito_Subt, 0 ) )                                    AS Credito_Subt ,
                SUM( NVL( RFD.Credito_IVA , 0 ) )                                    AS Credito_IVA  
         FROM EAI.CFDI_Informe            CFD ,
              T3.Registro_Fiscal         RF  ,
              T3.Registro_Fiscal_Detalle RFD ,
              T3.Material                Prod
         WHERE CFD.Folio_Interno = RF.Factura
           AND CFD.Folio_Interno = RFD.Factura
           AND RFD.Material      = Prod.Material
         GROUP BY CFD.RowID, RF.Factura ;
   CURSOR ScrCIG_Agrupado IS       
         SELECT CFD.RowID AS CFD_RowID, RF.Nota_Venta_CFDI,
                SUM( CFD.Factor * RFD.Cantidad_Vta 
                    * DECODE( Prod.Unidad_Med_Vta, 'CAJ', NVL( Prod.Cig_x_CLL, 1), NVL( Prod.Cig_x_PAQ, 1 ) ) )
                                                                                  AS Cigarrillos  ,
                SUM( NVL( RFD.Envio_Subt  , 0 ) )                                 AS Envio_Subt   ,
                SUM( NVL( RFD.Envio_IVA   , 0 ) )                                 AS Envio_IVA    ,
                SUM( NVL( RFD.Credito_Subt, 0 ) )                                 AS Credito_Subt ,
                SUM( NVL( RFD.Credito_IVA , 0 ) )                                 AS Credito_IVA  
         FROM EAI.CFDI_Informe            CFD ,
              T3.CFDI_Agrupado           RF  ,
              T3.CFDI_Agrupado_Detalle   RFD ,
              T3.Material                Prod
         WHERE CFD.Folio_Interno = RF.Nota_Venta_CFDI
           AND CFD.Folio_Interno = RFD.Nota_Venta_CFDI
           AND RFD.Material      = Prod.Material
         GROUP BY CFD.RowID, RF.Nota_Venta_CFDI ;
--
   CURSOR ScrComplementoAGR IS
       SELECT CFD.ROWID                       AS Info_RowID    , 
              CFD.Folio_Interno               AS Agrupada      ,
              Agr.Doctos                      AS Doctos        , 
              'CLIENTE AGRUPADOR VENTAS DIA'  AS Nombre_Cliente
          FROM EAI.CFDI_Informe  CFD,
               T3.CFDI_Agrupado  Agr
          WHERE CFD.Folio_Interno  = Agr.Nota_Venta_CFDI
            AND CFD.LP            IS NULL ;
--
   CURSOR ScrListaPrecioAgr IS
       SELECT DISTINCT Doc.Grupo_Precio
          FROM T3.CFDI_Historia_Docto_PAC HDP,
               T3.Fact_T3                 Doc
          WHERE HDP.Nota_Venta_CFDI = sAgrupada
            AND HDP.Nota_Venta      = Doc.Factura
       UNION ALL  
       SELECT DISTINCT Doc.Grupo_Precio
          FROM T3.CFDI_Historia_Docto_PAC HDP,
               T3.Nota_T3                 Doc
          WHERE HDP.Nota_Venta_CFDI = sAgrupada
            AND HDP.Nota_Venta      = Doc.Factura ;
--
   CURSOR ScrAgrupadoDiferencia IS
       SELECT Info.ROWID AS Info_ROWID, Info.Valor_Subt, Info.Valor_IVA, Info.Valor, Dif.Ajuste, 
              Info.Valor - Info.Valor_Subt - Info.Valor_IVA AS Calculando
          FROM EAI.CFDI_Informe      Info,
               T3.CFDI_Agrupado_DIF  Dif
          WHERE Info.Folio_Interno LIKE 'G-%'
            AND Info.Folio_Interno = Dif.Nota_Venta_CFDI
            AND Dif.Ajuste != 0 ;
--
   CURSOR ScrIndividualDiferencia IS
       SELECT Info.ROWID AS Info_ROWID, Info.Valor_Subt, Info.Valor_IVA, Info.Valor, Dif.Ajuste, 
              Info.Valor - Info.Valor_Subt - Info.Valor_IVA AS Calculando
          FROM EAI.CFDI_Informe      Info,
               T3.CFDI_Agrupado_DIF  Dif
          WHERE Info.Folio_Interno NOT LIKE 'G-%'
            AND Info.Folio_Interno = Dif.Nota_Venta_CFDI
            AND Dif.Ajuste != 0 ;
--
   CURSOR ScrCentavos_CFD IS
       SELECT CFD.Folio_Interno           AS Folio_Interno,
              CFD.Valor                   AS Valor        ,
              CFD.Valor_Subt              AS Valor_Subt   ,
              CFD.Valor_IVA               AS Valor_IVA    ,
              CFD.Monto_T3In              AS Monto_T3In   ,
              CFD.Valor - CFD.Monto_T3In  AS Diferencia   ,
              CFD.ROWID                   AS Info_ROWID
          FROM EAI.CFDI_Informe     CFD,
               EAI.FC__Time_Window  TW
          WHERE CFD.Valor != CFD.Monto_T3IN
            AND CFD.Folio_Interno NOT LIKE 'G-%'
            AND ABS( CFD.Valor - CFD.Monto_T3In ) < 0.06
            AND CFD.Fecha >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ) ;   
--
   CURSOR ScrFactCentral IS
      SELECT Bita.Doc_Num        AS Doc_Num   , 
             Bita.Invc_dt        AS Invc_dt   ,
             Bita.SAP_Amount     AS SAP_Amount,
             Bita.SF_Amount      AS SF_Amount ,
             'SAP'               AS Origen    
         FROM EAI.CFDI_Bitacora                Bita,
              EAI_Owner.WA_VENTA_CENTRALIZADA  Ctrl,
              EAI.CFDI_Informe                 Info
         WHERE Bita.Cliente_SAP = Ctrl.Cliente_SAP
           AND Bita.Doc_Num     = Info.Folio_Interno(+)
           AND Bita.Invc_dt BETWEEN Ctrl.Fecha_Ini_Vig AND Ctrl.Fecha_Fin_Vig ;            
--                       
BEGIN
   nProceso  := 802 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso1 := 000 ;
   nProceso2 := 000 ;
   nProceso3 := 000 ;
   nProceso4 := 000 ;
--   
   nCount := 0 ;
   DBMS_OUTPUT.PUT_LINE( '-----------------------------' ) ;
   DBMS_OUTPUT.PUT_LINE( 'Proc_T3_CFDI_Resumen' ) ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;   
   IF ( pFecha_Inicio IS NULL ) THEN
       SELECT 
--            TO_CHAR( TO_DATE( Start_Date, 'DD/MM/YYYY' ), 'YYYYMMDD' )                   AS Inicio,
              TO_CHAR( ADD_MONTHS( TO_DATE( Start_Date, 'DD/MM/YYYY' ), -1 ), 'YYYYMMDD' ) AS Inicio,
              TO_CHAR( SYSDATE, 'YYYYMMDD' )                                               AS Fin
          INTO sFecha_Inicio, sFecha_Final    
       FROM EAI.FC__Time_WINDOW  ;
   ELSE
      sFecha_Inicio := pFecha_Inicio ;
      sFecha_Final  := pFecha_Final  ;
   END IF ;  
--   
   UPDATE EAI.CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'BITACORA CFDI' ;
   DELETE EAI.CFDI_Informe ;   
--   
   FOR Vta IN ScrPrompt LOOP
      nCount    := nCount    + 1 ;
      nProceso1 := nProceso1 + 1 ;
      v_ID      := Vta.Folio_Interno ;
      INSERT INTO EAI.CFDI_Informe 
         ( Sociedad        , Folio_Interno    , Fecha     , Ctro    ,
           RFC             , ID_Envio         , ID_Confirmacion     ,
           Nombre_Cliente  , LP               , Doctos    ,
           Terr            , Tipo_Docto       , Factor    , 
           Folio_Fiscal    , Status           , Monto_T3In,
           Valor_Subt      , Valor_IVA        , Valor                 )
      VALUES
         ( Vta.Sociedad    , Vta.Folio_Interno, Vta.Fecha , Vta.Ctro,
           Vta.RFC         , Vta.ID_Envio     , Vta.ID_Confirmacion,
           Vta.Nombre_Cliente, Vta.LP         ,          1,
           Vta.Terr        , Vta.Tipo_Docto   , Vta.Factor, 
           Vta.Folio_Fiscal, Vta.Status       , Vta.Total_T3In * Vta.Factor, 
           Vta.Valor_Subt * Vta.Factor, Vta.Valor_IVA * Vta.Factor, 
           Vta.Factor * ( Vta.Valor_Subt + Vta.Valor_IVA  ) ) ;
      IF ( MOD( nCount, 1000 ) = 0 ) THEN
         COMMIT ;
      END IF ;
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
--   
   FOR Vta IN ScrPreventa LOOP
      nCount    := nCount    + 1 ;
      nProceso2 := nProceso2 + 1 ;
      v_ID      := Vta.Folio_Interno ;
      INSERT INTO EAI.CFDI_Informe 
         ( Sociedad        , Folio_Interno    , Fecha     , Ctro    ,
           RFC             , ID_Envio         , ID_Confirmacion     ,
           Nombre_Cliente  , LP               , Doctos    ,
           Terr            , Tipo_Docto       , Factor    , 
           Folio_Fiscal    , Status           , Monto_T3In,
           Valor_Subt      , Valor_IVA        , Valor                 )
      VALUES
         ( Vta.Sociedad    , Vta.Folio_Interno, Vta.Fecha , Vta.Ctro,
           Vta.RFC         , Vta.ID_Envio     , Vta.ID_Confirmacion ,
           Vta.Nombre_Cliente, Vta.LP         ,          1,
           Vta.Terr        , Vta.Tipo_Docto   , Vta.Factor, 
           Vta.Folio_Fiscal, Vta.Status       , Vta.Total_T3In * Vta.Factor, 
           Vta.Valor_Subt * Vta.Factor, Vta.Valor_IVA * Vta.Factor, 
           Vta.Factor * ( Vta.Valor_Subt + Vta.Valor_IVA  ) ) ;
      IF ( MOD( nCount, 1000 ) = 0 ) THEN
         COMMIT ;
      END IF ;
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
--
   FOR Vta IN ScrAgrupado LOOP
      nCount    := nCount    + 1 ;
      nProceso3 := nProceso3 + 1 ;
      v_ID      := Vta.Folio_Interno ;
      INSERT INTO EAI.CFDI_Informe 
         ( Sociedad        , Folio_Interno    , Fecha     , Ctro    ,
           RFC             , ID_Envio         , ID_Confirmacion     ,
           Nombre_Cliente  , Doctos           ,
           Terr            , Tipo_Docto       , Factor    , 
           Folio_Fiscal    , Status           , Monto_T3In,
           Valor_Subt      , Valor_IVA        , Valor                 )
      VALUES
         ( Vta.Sociedad    , Vta.Folio_Interno, Vta.Fecha , Vta.Ctro,
           Vta.RFC         , Vta.ID_Envio     , Vta.ID_Confirmacion ,
           Vta.Nombre_Cliente, Vta.Doctos     ,
           Vta.Terr        , Vta.Tipo_Docto   , Vta.Factor, 
           Vta.Folio_Fiscal, Vta.Status       , Vta.Total_T3In * Vta.Factor, 
           Vta.Valor_Subt * Vta.Factor, Vta.Valor_IVA * Vta.Factor, 
           Vta.Factor * ( Vta.Valor_Subt + Vta.Valor_IVA  ) ) ;
      IF ( MOD( nCount, 1000 ) = 0 ) THEN
         COMMIT ;
      END IF ;
   END LOOP ;
   COMMIT ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   DBMS_OUTPUT.PUT_LINE( 'Registros : ' || TO_CHAR( nCount) ) ;
   DBMS_OUTPUT.PUT_LINE( '-----------------------------' ) ;
--
   nCount := 0 ;
   v_ID   := 'ScrCIG_Individual' ;
   FOR ScrDoc IN ScrCIG_Individual LOOP
       nCount := nCount + 1 ;
       UPDATE EAI.CFDI_Informe SET Cigarrillos  = ScrDoc.Cigarrillos          ,
                                   Envio_Subt   = Factor * ScrDoc.Envio_Subt  ,
                                   Envio_IVA    = Factor * ScrDoc.Envio_IVA   ,
                                   Credito_Subt = Factor * ScrDoc.Credito_Subt,
                                   Credito_IVA  = Factor * ScrDoc.Credito_IVA ,                                   
                                   Monto_T3In   = Monto_T3In + ( Factor * ( ScrDoc.Envio_Subt + ScrDoc.Envio_IVA + ScrDoc.Credito_Subt + ScrDoc.Credito_IVA ) * ScrDoc.Sumar_Envio )  
          WHERE RowID = ScrDoc.CFD_RowID ;
      IF ( MOD( nCount, 5000 ) = 0 ) THEN
         COMMIT ;
      END IF ;          
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   DBMS_OUTPUT.PUT_LINE( 'Actualizados : ' || TO_CHAR( nCount) ) ;
   DBMS_OUTPUT.PUT_LINE( '-----------------------------' ) ;
   COMMIT ;
--
   nCount := 0 ;
   v_ID   := 'ScrCIG_Agrupado' ;
   FOR ScrDoc IN ScrCIG_Agrupado LOOP
       nCount := nCount + 1 ;
       UPDATE EAI.CFDI_Informe SET Cigarrillos  = ScrDoc.Cigarrillos          ,
                                   Envio_Subt   = Factor * ScrDoc.Envio_Subt  ,
                                   Envio_IVA    = Factor * ScrDoc.Envio_IVA   ,
                                   Credito_Subt = Factor * ScrDoc.Credito_Subt,
                                   Credito_IVA  = Factor * ScrDoc.Credito_IVA                                    
          WHERE RowID = ScrDoc.CFD_RowID ;
      IF ( MOD( nCount, 5000 ) = 0 ) THEN
         COMMIT ;
      END IF ;          
   END LOOP ;
   DBMS_OUTPUT.PUT_LINE( TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
   DBMS_OUTPUT.PUT_LINE( 'Actualizados : ' || TO_CHAR( nCount) ) ;
   DBMS_OUTPUT.PUT_LINE( '-----------------------------' ) ;
--
   nCount := 0 ;
   v_ID   := 'ScrComplementoAGR' ;      
   FOR Doc IN ScrComplementoAGR LOOP
      nCount := nCount + 1 ;
      sAgrupada := Doc.Agrupada ;
      FOR LP IN ScrListaPrecioAgr LOOP
         UPDATE EAI.CFDI_Informe SET  LP = LP.Grupo_Precio
            WHERE RowID = Doc.Info_RowID ;      
      END LOOP ;   
      IF ( MOD( nCount, 5000 ) = 0 ) THEN
         COMMIT ;
      END IF ;          
   END LOOP ;
   COMMIT ;    
--
   v_ID := 'ScrAgrupadoDiferencia' ;      
   FOR Doc IN ScrAgrupadoDiferencia LOOP
      nProceso4 := nProceso4 + 1 ;
      UPDATE EAI.CFDI_Informe SET  Valor_IVA = Valor_IVA + Doc.Ajuste, Valor = Valor + Doc.Ajuste
         WHERE RowID = Doc.Info_RowID ;      
   END LOOP ;   
--
   v_ID := 'ScrIndividualDiferencia' ;      
   FOR Doc IN ScrIndividualDiferencia LOOP
      nProceso4 := nProceso4 + 1 ;
      UPDATE EAI.CFDI_Informe SET  Valor_IVA = Valor_IVA + Doc.Ajuste, Valor = Valor + Doc.Ajuste
         WHERE RowID = Doc.Info_RowID ;      
   END LOOP ;   
--
   FOR Doc IN ScrCentavos_CFD LOOP
      UPDATE EAI.CFDI_Informe SET  Valor_IVA  = Valor_IVA - Doc.Diferencia,
                                   Valor      = Valor     - Doc.Diferencia,
                                   Diferencia = Doc.Diferencia
         WHERE RowID = Doc.Info_RowID ;      
   END LOOP ;   
   COMMIT ;
--
   v_ID := 'Updating Addenda' ;
   UPDATE EAI.CFDI_Informe  Bita SET Addenda = 'SI'
      WHERE Bita.RFC IN ( SELECT RFC FROM T3.CFDI_Addenda ) ;
   COMMIT ;
   UPDATE EAI.CFDI_Informe  Bita SET Addenda = 'NO'
       WHERE Addenda IS NULL ;          
   COMMIT ;   
--
    UPDATE EAI.CFDI_Informe SET Valor = Monto_T3In
       WHERE Status  = 'PUBLICADO'
         AND Valor  != Monto_T3In  ; 
--
   FOR WA IN ScrFactCentral LOOP
      UPDATE EAI.CFDI_Bitacora SET SF_Amount = SAP_Amount,
                                   Origen    = WA.Origen
          WHERE Doc_Num = WA.Doc_Num ;                         
      UPDATE EAI.CFDI_Informe SET Origen    = WA.Origen
          WHERE Folio_Interno = WA.Doc_Num ; 
   END LOOP ;
--
   UPDATE EAI.CONTROL_REPORTE  SET FIN = SYSDATE
      WHERE REPORTE = 'BITACORA CFDI' ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;         
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                      , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'SF_BITACORA_CFDI_RESUMEN', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      DBMS_OUTPUT.PUT_LINE( '*********** Mensaje ************************' ) ;
      DBMS_OUTPUT.PUT_LINE( '****** Error en BITACORA_CFDI_RESUMEN ***** ' ) ;
      DBMS_OUTPUT.PUT_LINE( sMsg ) ;
      COMMIT ;         
END ;