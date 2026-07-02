create or replace PROCEDURE     "SF_BITACORA_CFDI"
      ( nEtapa IN NUMBER DEFAULT 0  )
IS
  nDist                 NUMBER(3)     ;
  sCtro                 VARCHAR2(4)   ;
  sTerr                 VARCHAR2(4)   ;
  sFecha                VARCHAR2(8)   ; 
  dtFecha               DATE          ;     
  sError                VARCHAR2(250) ;
  sResp                 VARCHAR2(30)  ;
  sStep                 VARCHAR2(30)  ;
  sFactura              VARCHAR2(20)  ;
  sNULL                 VARCHAR2(10)  ;
  sMsg                  VARCHAR2(500) ;
  nItems                NUMBER(10)    ;
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
       SELECT Bit.RowID  AS Bit_RowID,
              FG.Ctro, FG.Fecha_Trn, FG.Fecha_Proc_BATMD,
              SUBSTR( FG.Ubicacion, 15, 4 ) AS Terr      ,
              FG.Valor_Subt                 AS Valor_Subt,
              FG.Valor_IVA                  AS Valor_IVA   
          FROM EAI.CFDI_Bitacora   Bit,
               T3.Factura_General  FG
          WHERE Bit.Doc_Num = FG.Factura ;       
--
    CURSOR ScrPresales1 IS
       SELECT Bit.RowID  AS Bit_RowID,
              FG.Ctro, E.Fecha_Trn, FG.Fecha_Proc_BATMD,
              NVL( E.Ubicacion, FG.Ubicacion )           AS Terr      
          FROM EAI.CFDI_Bitacora    Bit,
               T3.Preventa_General  FG ,
               T3.Entrega           E
          WHERE Bit.Doc_Num           = FG.Factura
            AND FG.Fecha_Cancelacion IS NULL
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )
            AND Bit.Doc_Num           = E.Factura ;
--
    CURSOR ScrPresales IS    
       SELECT Bit.RowID  AS Bit_RowID,
              FG.Ctro, E.Fecha_Trn, FG.Fecha_Proc_BATMD,
              NVL( E.Ubicacion, FG.Ubicacion )  AS Terr     
          FROM EAI.CFDI_Bitacora    Bit,
               T3.Preventa_General  FG ,
               T3.Entrega           E
          WHERE Bit.Doc_Num           = FG.Factura
            AND FG.Fecha_Cancelacion IS NULL
            AND TO_CHAR( NVL( FG.Fecha_Proc_BATMD, SYSDATE + 366), 'YYYY' ) = TO_CHAR( SYSDATE, 'YYYY' )
            AND Bit.Doc_Num           = E.Factura ;            
--
    CURSOR ScrIndividual IS
       SELECT Bit.RowID  AS Bit_RowID,
              Doc.Nota_Venta,
              Doc.Fecha_Liberacion, 
              Doc.Fecha_Envio,
              Doc.Fecha_Timbre,
              Doc.Fecha_CFD,
              Doc.Status,
              NVL( Doc.Valor_Subt, 0 ) + NVL( Doc.Valor_IVA, 0 ) AS Total_CFD
          FROM EAI.CFDI_Bitacora   Bit,
               T3.CFDI_Documentos  Doc
          WHERE Bit.Fecha_Proc_BATMD IS NOT NULL
            AND Bit.Doc_Num           = Doc.Nota_Venta ;              
--
    CURSOR ScrAgrupado IS
       SELECT Bit.RowID  AS Bit_RowID,
              Agr.Fecha_Documento,
              Agr.Doctos,
              Doc.Nota_Venta,
              Doc.Fecha_Liberacion, 
              Doc.Fecha_Envio,
              Doc.Fecha_Timbre,
              Doc.Fecha_CFD,
              Doc.Status,
              NVL( Doc.Valor_Subt, 0 ) + NVL( Doc.Valor_IVA, 0 ) AS Total_CFD
          FROM EAI.CFDI_Bitacora           Bit,
               T3.CFDI_Historia_Docto_PAC  HDP,
               T3.CFDI_Agrupado            Agr,
               T3.CFDI_Documentos          Doc
          WHERE Bit.Fecha_Proc_BATMD IS NOT NULL
            AND Bit.Doc_Num           = HDP.Nota_Venta 
            AND HDP.Nota_Venta_CFDI  != HDP.Nota_Venta
            AND HDP.Nota_Venta_CFDI   = Agr.Nota_Venta_CFDI
            AND HDP.Nota_Venta_CFDI   = Doc.Nota_Venta ;
--
   CURSOR ScrBonificaciones IS
      SELECT Info.ROWID AS Info_ROWID, Info.Doc_Num, SUM( NVL( RFD.Bonif_Subt, 0 ) + NVL( RFD.Bonif_IVA, 0 ) ) AS Bonif_Subt
      FROM EAI.CFDI_Bitacora           Info,
           T3.Registro_Fiscal_Detalle  RFD ,
           EAI.FC__TIME_Window         TW
      WHERE Info.Doc_Num  = RFD.Factura
        AND Info.Invc_dt >= ADD_MONTHS( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ), -1 )
      GROUP BY Info.ROWID, Info.Doc_Num
      HAVING SUM( NVL( RFD.Bonif_Subt, 0 ) ) > 0 ;    
--
   CURSOR ScrVolumen IS
       SELECT Info.Bit_ROWID            AS Bit_ROWID  ,
              SUM( Info.Sticks )        AS Sticks     ,
              SUM( Info.Segunda_Cat )   AS Segunda_Cat
          FROM (       
                SELECT  Bit.ROWID                                                                                                  AS Bit_ROWID   ,
                        RFD.Material                                                                                               AS Material    ,
                        RFD.Cantidad_Vta                                                                                           AS Cantidad_Vta,
                        DECODE( SUBSTR( TRIM( RFD.Material ), 1, 1 ), '1', 1, 0 ) * RFD.Cantidad_Vta 
                                                       * DECODE( SKU.Unidad_Med_Vta, 'CAJ', SKU.Cig_x_CLL, SKU.Cig_x_PAQ )         AS Sticks      ,
                        DECODE( SUBSTR( TRIM( RFD.Material ), 1, 1 ), '1', 0, 1 ) * RFD.Cantidad_Vta                               AS Segunda_Cat 
                   FROM EAI.CFDI_Bitacora            Bit ,
                        T3.Registro_Fiscal           RF  ,
                        T3.Registro_Fiscal_Detalle   RFD ,
                        T3.Material                  SKU
                   WHERE Bit.Doc_Num  = RFD.Factura     
                     AND Bit.Doc_Num  = RF.Factura
                     AND RFD.Material = SKU.Material
                ) Info
          GROUP BY Info.Bit_ROWID ;
--
   CURSOR ScrDiferencias IS
       SELECT Bit.Doc_Num, Bit.Ttl_Invc_Amt, Bit.Valor_Subt, Bit.Valor_IVA
          FROM EAI.CFDI_Bitacora Bit, EAI.CFDI_Informe Info, T3.CFDI_Documentos CFD
          WHERE NVL( Bit.Bonif_Subt, 0 )  > 0
            AND Bit.Created_by            = '1-80QF'
            AND Bit.Doc_Num               = Info.Folio_Interno
            AND Bit.Valor_Subt           != Info.Valor_Subt
            AND Bit.Valor_IVA            != Info.Valor_IVA
            AND Bit.Doc_Num               = CFD.Nota_Venta ;            
--              
   CURSOR ScrBackOffice IS
      SELECT Bit.Ctro, Bit.Doc_Num, Bit.RFC, Bit.Cliente_SAP, Bit.Invc_dt, Bit.Tipo_Vta,
             Back.Ctro_HUB      AS Vta_Ctro,
             Back.Ctro_Customer AS Dev_Ctro
         FROM EAI.CFDI_Bitacora          Bit ,
              EAI_Owner.TAO_Cedis_Valid  Back
         WHERE Bit.Cliente_SAP = Back.Accnt_ID
           AND Bit.Cliente_SAP = Back.Loc ;
--              
   CURSOR ScrSAP_Amount IS          
      SELECT Bit.ROWID AS Bit_ROWID, Bit.Doc_Num, Bit.Factura_SAP, 
             DECODE( Bit.Tipo_Vta, 'Vta', 1, -1 ) *
             ( SAP.Doc_NetAmt + SAP.Doc_TaxAmt )     AS SAP_Amount
         FROM EAI.CFDI_Bitacora       Bit,
              EAI.T3R_Sales_Docs_Old  SAP
         WHERE EAI_Owner.getConv( 'FolioDuplicado', Bit.Doc_Num ) = SAP.Doc_Num_Ref2
--         AND Bit.Doc_Num     = SAP.Doc_Num_Ref2         
           AND SAP.Doc_Status != 'D'
           AND SAP.Doc_Status != 'E' ; 
--              
   CURSOR ScrDESC_Amount IS          
      SELECT Bit.ROWID AS Bit_ROWID, Bit.Doc_Num,
             SUM( NVL( Det.Valor_Subt, 0 ) + NVL( Det.Valor_IVA, 0 ) ) AS SAP_Amount
         FROM EAI.CFDI_Bitacora              Bit,
              EAI_Owner.tmp_Document_Header  Doc,
              EAI_Owner.tmp_Document_Detail  Det
         WHERE Bit.Factura_SAP  = Doc.ReferenceID
           AND Doc.DeliveryType = 'C025'
           AND Bit.Factura_SAP  = Det.ReferenceID
      GROUP BY Bit.ROWID, Bit.Doc_Num ;  
--      
   CURSOR ScrDESC_Amount_Old IS          
      SELECT Bit.ROWID AS Bit_ROWID, Bit.Doc_Num,
             SUM( NVL( Det.Valor_Subt, 0 ) + NVL( Det.Valor_IVA, 0 ) ) AS SAP_Amount
         FROM EAI.CFDI_Bitacora              Bit,
              EAI_Owner.tmp_Document_Detail  Det
         WHERE (( Bit.Doc_Num     LIKE 'DESC%' )
             OR ( Bit.Doc_Num     LIKE 'CONECT%' ) )
           AND Bit.Factura_SAP = Det.ReferenceID
      GROUP BY Bit.ROWID, Bit.Doc_Num ;         
--
   CURSOR ScrMetodoPago IS
      SELECT Bit.Doc_Num, Bit.Ctro, Bit.Invc_dt,
             Bit.RowID                                                                                            AS Bit_RowID ,
             EXTRACT( XML.Anexo_CFD, '/cfdi:Comprobante/@MetodoPago', 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"') AS MetodoPago,
             EXTRACT( XML.Anexo_CFD, '/cfdi:Comprobante/@FormaPago' , 'xmlns:cfdi="http://www.sat.gob.mx/cfd/4"') AS FormaPago
         FROM EAI.CFDI_Bitacora Bit, T3.RF_Documentos XML
         WHERE Bit.Doc_Num = Bit.Nota_Venta_CFDI
           AND Bit.Doc_Num = XML.Factura ;   
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
BEGIN
-- Inicio
   dtInicio  := SYSDATE ;
   nProceso  := 801 ;
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
   UPDATE CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'BITACORA CFDI - DETALLE' ;
   v_ID := 'CFDI_Bitacora' ;
   sStep := 'CFDI_Bitacora' ;
   IF ( nEtapa <= 000 ) THEN
      DELETE FROM EAI.CFDI_Bitacora ;
      INSERT INTO EAI.CFDI_Bitacora
         ( Ctro, Doc_Num, Factura_SAP, Nota_Venta_CFDI, Cliente_SAP, Clte_Factura_SAP, Invc_dt, Tipo_Vta, Fecha_Trn, Fecha_Proc_BATMD, 
           Valor_Subt, Valor_IVA, Bonif_Subt, Envio_Subt, Envio_IVA, Credito_Subt, Credito_IVA )  
         SELECT Info.Ctro                              AS Ctro            ,
                Info.Factura                           AS Factura         ,
                Info.Factura_SAP                       AS Factura_SAP     ,
                Info.Nota_Venta_CFDI                   AS Nota_Venta_CFDI ,
                Info.Cliente_SAP                       AS Cliente_SAP     ,
                Info.Clte_Factura_SAP                  AS Clte_Factura_SAP,
                Info.Fecha_Documento                   AS Fecha_Documento ,
                Info.Tipo_Docto                        AS Tipo_Docto      ,
                Info.Fecha_Trn                         AS Fecha_Trn       ,
                Info.Fecha_Proc_BATMD                  AS Fecha_Proc_BATMD,
                SUM( Info.Valor_Subt )                 AS Valor_Subt      ,
                SUM( Info.Valor_IVA  )                 AS Valor_IVA       ,
                SUM( Info.Bonif_Subt )                 AS Bonif_Subt      ,
                SUM( Info.Envio_Subt )                 AS Envio_Subt      ,
                SUM( Info.Envio_IVA  )                 AS Envio_IVA       ,
                SUM( Info.Credito_Subt )               AS Credito_Subt    ,
                SUM( Info.Credito_IVA  )               AS Credito_IVA       
            FROM (  
                   SELECT FG.Ctro                               AS Ctro            ,
                          FG.Factura                            AS Factura         ,
                          FG.Entrega                            AS Factura_SAP     ,
                          HDP.Nota_Venta_CFDI                   AS Nota_Venta_CFDI ,
                          FG.Cliente_SAP                        AS Cliente_SAP     ,
                          FG.Clte_Factura_SAP                   AS Clte_Factura_SAP,
                          TRUNC( FG.Fecha_Factura )             AS Fecha_Documento ,
                          DECODE( FG.Tipo_Docto, 'C003', 
                                                'Vta', 'Dev' )  AS Tipo_Docto      ,
                          FG.Fecha_Trn                          AS Fecha_Trn       ,
                          FG.Fecha_Proc_BATMD                   AS Fecha_Proc_BATMD,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Valor_Subt, 0 )               AS Valor_Subt      ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Valor_IVA , 0 )               AS Valor_IVA       ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Bonif_Subt, 0 )               AS Bonif_Subt      ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Envio_Subt, 0 )               AS Envio_Subt      ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Envio_IVA , 0 )               AS Envio_IVA       ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Credito_Subt, 0 )             AS Credito_Subt    ,
                          DECODE( FG.Tipo_Docto, 'C003', 1, -1 ) *
                          NVL( FD.Credito_IVA , 0 )             AS Credito_IVA                          
                      FROM T3.Factura_General           FG ,
                           EAI.FC__TIME_WINDOW          TW ,
                           T3.Factura_Detalle           FD ,
                           T3.CFDI_Historia_Docto_PAC   HDP
                      WHERE FG.Fecha_Factura  >= ADD_MONTHS( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ), -1 )
                      --AND FG.Fecha_Factura  >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )    
                        AND FG.Factura         = FD.Factura
                        AND FG.Factura         = HDP.Nota_Venta(+) 
                                                                  ) Info
         GROUP BY Info.Ctro, Info.Factura, Info.Factura_SAP, Info.Nota_Venta_CFDI, Info.Cliente_SAP, Info.Clte_Factura_SAP, Info.Fecha_Documento, Info.Tipo_Docto, Info.Fecha_Trn, Info.Fecha_Proc_BATMD 
         UNION
         SELECT Info.Ctro                              AS Ctro            ,
                Info.Factura                           AS Factura         ,
                Info.Factura_SAP                       AS Factura_SAP     ,
                Info.Factura                           AS Nota_Venta_CFDI ,
                Info.Cliente_SAP                       AS Cliente_SAP     ,
                Info.Clte_Factura_SAP                  AS Clte_Factura_SAP,
                Info.Fecha_Documento                   AS Fecha_Documento ,
                Info.Clase_Factura                     AS Tipo_Docto      ,
                Info.Fecha_Trn                         AS Fecha_Trn       ,
                Info.Fecha_Proc_BATMD                  AS Fecha_Proc_BATMD,
                SUM( Info.Valor_Subt   * Factor_T3MX ) AS Valor_Subt      ,
                SUM( Info.Valor_IVA    * Factor_T3MX ) AS Valor_IVA       ,
                SUM( Info.Bonif_Subt   * Factor_T3MX ) AS Bonif_Subt      ,
                SUM( Info.Envio_Subt   * Factor_T3MX ) AS Envio_Subt      ,
                SUM( Info.Envio_IVA    * Factor_T3MX ) AS Envio_IVA       ,
                SUM( Info.Credito_Subt * Factor_T3MX ) AS Credito_Subt    ,
                SUM( Info.Credito_IVA  * Factor_T3MX ) AS Credito_IVA
            FROM (  
                   SELECT FG.Ctro                               AS Ctro            ,
                          FG.Factura                            AS Factura         ,
                          FG.Entrega                            AS Factura_SAP     ,
                          FG.Cliente_SAP                        AS Cliente_SAP     ,
                          FG.Cliente_SAP                        AS Clte_Factura_SAP,
                          TRUNC( FG.Fecha_Factura )             AS Fecha_Documento ,
                          DECODE( FG.Clase_Factura, 'C005', 
                                                 'Vta', 'Dev' ) AS Clase_Factura   ,
                          FG.Fecha_Trn                          AS Fecha_Trn       ,
                          FG.Fecha_Proc_BATMD                   AS Fecha_Proc_BATMD,
                          DECODE( FG.Fecha_Cancelacion, NULL, 1, 0 )
                                                                AS Factor_T3MX     ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Valor_Subt, 0 )               AS Valor_Subt      ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Valor_IVA , 0 )               AS Valor_IVA       ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Bonif_Subt, 0 )               AS Bonif_Subt      ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Envio_Subt, 0 )               AS Envio_Subt      ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Envio_IVA , 0 )               AS Envio_IVA       ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Credito_Subt, 0 )             AS Credito_Subt    ,
                          DECODE( FG.Clase_Factura, 'C005', 1, -1 ) *
                          NVL( FD.Credito_IVA , 0 )             AS Credito_IVA
                      FROM T3.Preventa_General          FG ,
                           EAI.FC__TIME_WINDOW          TW ,
                           T3.Preventa_Detalle          FD 
                      WHERE FG.Fecha_Factura      >= ADD_MONTHS( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ), -1 ) 
                      --AND FG.Fecha_Factura      >= TO_DATE( TW.Start_Date, 'DD/MM/YYYY' )    
                        AND FG.Fecha_Proc_BATMD   IS NOT NULL
                        AND FG.Clase_Factura      IN ( 'C005', 'C006', 'C025' )
                        AND FG.Factura             = FD.Factura
                 --     AND FG.Fecha_Cancelacion  IS NULL  
                 ) Info
         GROUP BY Info.Ctro, Info.Factura, Info.Factura_SAP, Info.Cliente_SAP, Info.Clte_Factura_SAP, Info.Fecha_Documento, Info.Clase_Factura, Info.Fecha_Trn, Info.Fecha_Proc_BATMD ;          
       COMMIT ;   
       UPDATE EAI.CFDI_Bitacora  SET  Credit_Days = 0 
          WHERE Tipo_Vta != 'Vta' ;
       COMMIT ;
       FOR Doc IN ScrBonificaciones LOOP
          UPDATE EAI.CFDI_Bitacora  SET  Bonif_Subt = Doc.Bonif_Subt
             WHERE ROWID = Doc.Info_ROWID ;
       END LOOP ;
       COMMIT ;   
   END IF ;
--
   v_ID := 'ScrPrompt' ;
   IF ( nEtapa <= 010 ) THEN
      sFecha := '010' ;
      FOR Doc IN ScrPrompt LOOP
         UPDATE EAI.CFDI_Bitacora SET Ctro             = Doc.Ctro             ,
                                      Terr             = Doc.Terr             
            WHERE RowID = Doc.Bit_RowID ;
         nProceso1 := nProceso1 + 1 ;   
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ScrPresales' ;
   IF ( nEtapa <= 020 ) THEN
      sFecha := '020' ;
      FOR Doc IN ScrPresales LOOP
         UPDATE EAI.CFDI_Bitacora SET 
                                      Terr             = Doc.Terr             
            WHERE RowID = Doc.Bit_RowID ;
         nProceso2 := nProceso2 + 1 ;              
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ScrIndividual' ; 
   IF ( nEtapa <= 030 ) THEN
      sFecha := '030' ;
      FOR Doc IN ScrIndividual LOOP
         UPDATE EAI.CFDI_Bitacora SET Nota_Venta_CFDI  = Doc.Nota_Venta       ,
                                      Fecha_Venta      = Invc_dt              ,
                                      Fecha_Liberacion = Doc.Fecha_Liberacion ,
                                      Fecha_Envio      = Doc.Fecha_Envio      ,
                                      Fecha_Timbre     = Doc.Fecha_Timbre     ,
                                      Fecha_CFD        = Doc.Fecha_CFD        ,
                                      Status           = Doc.Status           ,
                                      Total_CFD        = Doc.Total_CFD        ,
                                      Docto_Ind        = 1
            WHERE RowID = Doc.Bit_RowID ;
      END LOOP ;
      COMMIT ;
   END IF ;
--
   v_ID := 'ScrAgrupado' ;
   IF ( nEtapa <= 040 ) THEN
      sFecha := '040' ;
      nItems := 0 ;
      FOR Doc IN ScrAgrupado LOOP
         UPDATE EAI.CFDI_Bitacora SET 
                                      Fecha_Venta      = Doc.Fecha_Documento  ,
                                      Fecha_Liberacion = Doc.Fecha_Liberacion ,
                                      Fecha_Envio      = Doc.Fecha_Envio      ,
                                      Fecha_Timbre     = Doc.Fecha_Timbre     ,
                                      Fecha_CFD        = Doc.Fecha_CFD        ,
                                      Status           = Doc.Status           ,
                                      Total_CFD        = Doc.Total_CFD        ,
                                      Docto_SAT        = DECODE( INSTR( Doc.Nota_Venta, Doc_Num ), 0, 0, 1 ),
                                      Doctos           = DECODE( INSTR( Doc.Nota_Venta, Doc_Num ), 0, 0, Doc.Doctos )
            WHERE RowID = Doc.Bit_RowID ;
          nItems := nItems + 1 ;
          IF ( MOD( nItems, 1000 ) = 0 ) THEN
             COMMIT ;
          END IF ;            
         nProceso3 := nProceso3 + 1 ;               
      END LOOP ;
      COMMIT ;
   END IF ;   
--
   v_ID := 'ScrVolumen' ;
   IF ( nEtapa <= 080 ) THEN
      FOR Doc IN ScrVolumen LOOP
         UPDATE EAI.CFDI_Bitacora SET Primer_Categoria  = Doc.Sticks     ,
                                      Segunda_Categoria = Doc.Segunda_Cat
            WHERE RowID = Doc.Bit_RowID ;
      END LOOP ;   
   END IF ;      
--
--
   v_ID := 'SAP_Amount' ;
   IF ( nEtapa <= 090 ) THEN
      FOR Doc IN ScrSAP_Amount LOOP
         UPDATE EAI.CFDI_Bitacora SET SAP_Amount = Doc.SAP_Amount
            WHERE RowID = Doc.Bit_RowID ;
      END LOOP ;  
      COMMIT ;
   END IF ;      
--
   v_ID := 'DESC_Amount' ;
   IF ( nEtapa <= 090 ) THEN
      FOR Doc IN ScrDESC_Amount LOOP
         UPDATE EAI.CFDI_Bitacora SET SAP_Amount = Doc.SAP_Amount * -1 / 100
            WHERE RowID = Doc.Bit_RowID ;
      END LOOP ;  
      COMMIT ;
   END IF ;      
--
   v_ID := 'MetodoPago' ;
   IF ( nEtapa <= 100 ) THEN
      UPDATE EAI.CFDI_Bitacora  SET Metodo_Pago = 'PUE', Forma_Pago = '99'
         WHERE Doc_Num != Nota_Venta_CFDI
           AND Nota_Venta_CFDI IS NOT NULL ;
      FOR Doc IN ScrMetodoPago LOOP
         UPDATE EAI.CFDI_Bitacora SET Metodo_Pago = Doc.MetodoPago, Forma_Pago = Doc.FormaPago
            WHERE RowID = Doc.Bit_RowID ;
      END LOOP ;  
      COMMIT ;
   END IF ;      
   
--
   UPDATE EAI.CFDI_Bitacora Bit SET RFC = 
      ( SELECT MAX( C.RFC ) FROM T3.Cliente C WHERE C.Cliente_SAP = Bit.Cliente_SAP 
           AND Bit.Invc_dt BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig ) ;
   COMMIT ;
   FOR Doc IN ScrBackOffice LOOP
      IF    ( Doc.Tipo_Vta = 'Vta' ) THEN
         UPDATE EAI.CFDI_Bitacora SET Ctro = Doc.Vta_Ctro
            WHERE Doc_Num = Doc.Doc_Num AND ( Ctro != Doc.Vta_Ctro ) ;
      ELSIF ( Doc.Tipo_Vta = 'Dev' ) THEN
         UPDATE EAI.CFDI_Bitacora SET Ctro = Doc.Dev_Ctro
            WHERE Doc_Num = Doc.Doc_Num AND ( Ctro != Doc.Dev_Ctro ) ;
      ELSE
         nItems := nItems ;
      END IF ;
   END LOOP ;
   COMMIT ;
--
   FOR WA IN ScrFactCentral LOOP
      UPDATE EAI.CFDI_Bitacora SET SF_Amount = SAP_Amount,
                                   Origen    = WA.Origen
          WHERE Doc_Num = WA.Doc_Num ;                         
      UPDATE EAI.CFDI_Informe SET Origen    = WA.Origen
          WHERE Folio_Interno = WA.Doc_Num ; 
   END LOOP ;
--
/*
   v_ID := 'ScrDiferencias' ;
   IF ( nEtapa <= 090 ) THEN
      FOR Doc IN ScrDiferencias LOOP
         T3.WA_FOLIO_FISCAL_VALORES( Doc.Doc_Num ) ;
         UPDATE EAI.CFDI_Informe Info SET ( Valor_Subt, Valor_IVA ) = ( SELECT Valor_Subt, Valor_IVA FROM T3.CFDI_Documentos CFD WHERE CFD.Nota_Venta = Info.Folio_Interno )
            WHERE Info.Folio_Interno = Doc.Doc_Num ; 
      END LOOP ;
   END IF ;   
--
   UPDATE EAI.CFDI_Bitacora SET Created_By = 'DESCNA' WHERE Doc_Num LIKE 'DESCNA%' ;
   UPDATE EAI.CFDI_Bitacora  Bita SET Status = 'PENDING'
      WHERE Bita.Status = 'PUBLICADO'  
        AND Bita.RFC IN ( SELECT RFC FROM T3.CFDI_Addenda ) ;
   v_ID := 'Replicate to CEDIS' ;           
--
--  */
   UPDATE CONTROL_REPORTE  SET  FIN = SYSDATE
      WHERE REPORTE = 'BITACORA CFDI - DETALLE' ;
   COMMIT ;
   v_ID := 'BITACORA_CFDI_COMPLEMENTO' ;
-- EAI.BITACORA_CFDI_COMPLEMENTO( 'INFORME' ) ;
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
          'Error'             , 'SF_BITACORA_CFDI'       , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                     , NULL                , NULL            ) ;
      COMMIT ; 
      DBMS_Output.Put_LINE( '----------------------------------' ) ;
      DBMS_Output.Put_LINE( '**** Error en BITACORA_CFDI *****'  ) ;
      DBMS_Output.Put_LINE( v_ID ) ;
      DBMS_Output.Put_LINE( sMsg ) ;      
END ;