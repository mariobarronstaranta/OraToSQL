create or replace PROCEDURE     "SF_BITACORA_CFDI_VENTA_SF"
      ( nEtapa   IN NUMBER   DEFAULT 0,
        sPeriod  IN VARCHAR2 DEFAULT '' )
IS
  nDist                 NUMBER(3)     ;
  sCtro                 VARCHAR2(4)   ;
  sTerr                 VARCHAR2(4)   ;
  sFecha                VARCHAR2(8)   ; 
  dtFecha               DATE          ;     
  sError                VARCHAR2(250) ;
  sResp                 VARCHAR2(30)  ;
  sFactura              VARCHAR2(20)  ;
  sPeriodo              VARCHAR2(20)  ;
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
   CURSOR ScrVentaSalesforce IS
   SELECT SF.Factura                    AS SF_Factura      ,
          SF.Fecha_Factura              AS SF_Fecha_Factura,
          SF.Cliente_SAP                AS SF_Cliente_SAP  ,
          SF.Importe_TMD                AS SF_Importe_TMD  ,
          SF.Tipo_Doc                   AS SF_Tipo_Doc     ,
          SF.Delivery_Status            AS Delivery_Status ,
          Bit.ROWID                     AS Bitacora_RowID  ,
          NVL( Bit.Doc_Num, 'INSERT' )  AS Bitacora_DocNum ,
          MC.Ctro                       AS Ctro            ,
          MC.Nombre                     AS Nombre_Cliente
     FROM (
           SELECT Inv.Doc_Num                AS Factura        ,
                  Inv.Invc_dt                AS Fecha_Factura  ,
                  Inv.Cte_SAP                AS Cliente_SAP    ,
                  Inv.Ttl_Invc_Amt           AS Importe_TMD    ,
                  'Vta'                      AS Tipo_Doc       , 
                  Inv.Delivery_Status        AS Delivery_Status
              FROM EAI_Owner.Facturas_B Inv, 
                   EAI.FC__Time_Window  TW
              WHERE Inv.Invc_Status     != 'Cancelled'
                AND Inv.Invc_Status     != 'Invalid'
              --AND Inv.Delivery_Status != 'Unsuccessful'
                AND Inv.Invc_dt         IS NOT NULL
                AND Inv.Doc_Num        NOT IN ( SELECT Referencia FROM EAI_Owner.Doctos_Cancelled  )
                AND Inv.Invc_dt          < TO_CHAR( SYSDATE, 'YYYY-MM-DD' )
                AND Inv.Invc_dt         >= TO_CHAR( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ) - 45, 'YYYY-MM-DD' )
           UNION ALL     
           SELECT Dev.SR_Invoice_Key         AS Factura        ,
                  Dev.SRI_Date               AS Fecha_Factura  ,
                  Dev.SAP_CustomerID         AS Cliente_SAP    ,
                  Dev.Total_Amount * -1      AS Importe_TMD    ,
                  'Dev'                      AS Tipo_Doc       , 
                  NVL( Dev.Received_Status,
                    'Empty' )
                                             AS Delivery_Status
              FROM EAI_Owner.SR_Invoice Dev,
                   EAI.FC__Time_Window  TW
              WHERE Dev.SRI_Date IS NOT NULL
                AND Dev.SR_Invoice_Key NOT IN ( SELECT Referencia FROM EAI_Owner.Doctos_Cancelled  )
                AND Dev.SRI_Date  < TO_CHAR( SYSDATE, 'YYYY-MM-DD' )
                AND Dev.SRI_Date >= TO_CHAR( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ) - 45, 'YYYY-MM-DD' )
           UNION ALL     
           SELECT 
                  CN.Reference_NO            AS Factura        ,
                  CN.Fecha                   AS Fecha_Factura  ,
                  CN.Cte_SAP                 AS Cliente_SAP    ,
                  NVL( CN.Amount , 0 ) * -1  AS Importe_TMD    ,
                  'Dev'                      AS Tipo_Doc       ,
                  'CreditMemo'               AS Delivery_Status
              FROM EAI_OWNER.CREDIT_NOTES CN,
                   EAI.FC__Time_Window    TW
              WHERE ( ( CN.Reference_NO LIKE 'DESC%'   )
                   OR ( CN.Reference_NO LIKE 'CONECT%' ) )                   
                AND CN.Fecha  < TO_CHAR( SYSDATE, 'YYYY-MM-DD' )
                AND CN.Fecha >= TO_CHAR( TO_DATE( TW.Start_Date, 'DD/MM/YYYY' ) -45, 'YYYY-MM-DD' )                  
           ) SF,
         EAI.CFDI_Bitacora Bit,
         T3.Mov_Cliente    MC
     WHERE SF.Factura     = Bit.Doc_Num(+) 
       AND SF.Cliente_SAP = MC.Cliente_SAP(+) ;
--
   CURSOR ScrInfoSAP IS
       SELECT Bita.Doc_Num                                        AS Doc_Num      ,
              DECODE( Bita.Tipo_Vta, 'Vta', 1, -1 )               AS Factor_SAP   ,
              SAP.Distributor                                     AS Distributor  ,
              SAP.Doc_Num_R3                                      AS Documento_SAP,
              NVL( SAP.Doc_NetAmt, 0 ) + NVL( SAP.Doc_TaxAmt, 0 ) AS Monto_SAP
          FROM EAI.CFDI_Bitacora Bita, EAI.T3R_Sales_Docs_Old SAP
          WHERE Bita.Row_ID    IS NOT NULL
            AND Bita.Doc_Num    = SAP.Doc_Num_ref2
            AND SAP.Doc_Status  = 'C' ;   
--
   CURSOR ScrCreditMemoDelete IS
      SELECT Bita.Doc_Num, Bita.Row_ID, Bita.Invc_dt, 
             PG.Factura, PG.Fecha_Factura,
             Bita.Invc_dt - PG.Fecha_Factura   AS Diferencia
         FROM EAI.CFDI_Bitacora  Bita, T3.Preventa_General PG
         WHERE ( ( Bita.Doc_Num LIKE 'DESC%'   )
              OR ( Bita.Doc_Num LIKE 'CONECT%' ) )  
           AND Bita.Doc_Num = PG.Factura
           AND ( ( Bita.Invc_dt - PG.Fecha_Factura ) >= 35 ) ;   
--
   CURSOR ScrWA_MesSiguiente IS
      SELECT Bita.Doc_Num, Bita.Invc_dt, FG.Fecha_Factura
         FROM EAI.CFDI_Bitacora  Bita,
              T3.Factura_General FG
         WHERE Bita.Doc_Num = FG.Factura     
           AND TO_CHAR( Bita.Invc_dt, 'YYYYMM' ) != TO_CHAR( FG.Fecha_Factura, 'YYYYMM' )
           AND TO_CHAR( Bita.Invc_dt, 'YYYYMM' )  = sPeriodo
      ORDER BY Bita.Invc_dt, Bita.Doc_Num  ;
--
   CURSOR ScrWA_MesAnterior IS
      SELECT Bita.Doc_Num, Bita.Invc_dt, FG.Fecha_Factura, 
             DECODE( Bita.Tipo_Vta, 'Vta', 1, -1 ) AS FactorDoc,
             T3.FN_TOTAL_FACT( Bita.Doc_Num )      AS Importe
         FROM EAI.CFDI_Bitacora  Bita,
              T3.Factura_General FG
         WHERE Bita.Doc_Num = FG.Factura
           AND NVL( Bita.SF_Amount, 0 ) = 0
           AND TO_CHAR( Bita.Invc_dt, 'YYYYMM' ) = sPeriodo 
      UNION ALL
      SELECT Bita.Doc_Num, Bita.Invc_dt, FG.Fecha_Factura, 
             DECODE( Bita.Tipo_Vta, 'Vta', 1, -1 ) AS FactorDoc,
             T3.FN_TOTAL_FACT( Bita.Doc_Num )      AS Importe
         FROM EAI.CFDI_Bitacora  Bita,
              T3.Preventa_General FG
         WHERE Bita.Doc_Num = FG.Factura
           AND NVL( Bita.SF_Amount, 0 ) = 0
           AND TO_CHAR( Bita.Invc_dt, 'YYYYMM' ) = sPeriodo
           AND FG.Fecha_Proc_BATMD < SYSDATE
           AND FG.Fecha_Cancelacion IS NULL ;
--
   CURSOR ScrWA_LOBInicioMes IS
      SELECT PG.Factura, PG.Fecha_Factura, PG.Fecha_Trn, PG.Entrega,
             PG.Ctro, '0000' AS Terr,
             DECODE( PG.Clase_Factura, 'C005', 'Vta', 'Dev' ) AS Tipo_Vta ,
             DECODE( PG.Clase_Factura, 'C005',     1, -1    ) AS FactorDoc,
             MC.Nombre AS Nombre_Cliente, PG.Cliente_SAP, 
             NVL( SAP.Doc_NetAmt, 0 ) + NVL( SAP.Doc_TaxAmt, 0 ) AS Importe_SAP
         FROM T3.Preventa_General    PG  , 
              EAI.CFDI_Bitacora      Bita,
              T3.Mov_Cliente         MC  , 
              EAI.FC__Time_Window    TW  ,
              EAI.T3R_Sales_Docs_Old SAP 
         WHERE PG.Clase_Factura              IN ( 'C005', 'C006' )
           AND PG.Fecha_Cancelacion          IS NOT NULL
           AND PG.Fecha_Proc_BATMD            < SYSDATE
           AND PG.Factura                     = Bita.Doc_Num(+)
           AND NVL( Bita.Doc_Num, 'INSERT' )  = 'INSERT'
           AND PG.Cliente_SAP                 = MC.Cliente_SAP
           AND PG.Fecha_Factura              >= TO_DATE( TW.Start_DAte, 'DD/MM/YYYY' )
           AND PG.Entrega                     = SAP.Doc_Num_R3(+) ;   
--
BEGIN
-- 
   IF ( LENGTH( NVL( sPeriod, ' ' ) ) < 4 ) THEN
      sPeriodo := '' ;
      IF ( TO_CHAR( SYSDATE, 'DD' ) IN ( '01', '02' ) ) THEN
         sPeriodo := TO_CHAR( SYSDATE - 3, 'YYYYMM' ) ;
      END IF ;
   ELSE
      sPeriodo := sPeriod ;
   END IF ;
--
   dtInicio  := SYSDATE ;
   nProceso  := 826 ;
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
   FOR Doc IN ScrVentaSalesforce LOOP
      IF ( Doc.SF_Factura = Doc.Bitacora_DocNum ) THEN
         IF ( Doc.Delivery_Status != 'Unsuccessful-X' ) THEN
            nProceso1 := nProceso1 + 1 ;
            UPDATE EAI.CFDI_Bitacora Bit SET SF_AMOUNT = Doc.SF_Importe_TMD
               WHERE ROWID = Doc.Bitacora_RowID ;
         ELSE    
            nProceso2 := nProceso2 + 1 ;
         END IF ;
      ELSE
         IF ( 1 = 1 ) THEN
            nProceso3 := nProceso3 + 1 ;
            INSERT INTO EAI.CFDI_Bitacora 
               ( Row_ID     , Doc_Num         , Nota_Venta_CFDI, 
                 Invc_Dt    , Fecha_Trn       , 
                 Ctro       , Terr, Tipo_Vta  , Docto_Ind, Fecha_Venta, 
                 Nombre_Cliente,
                 Cliente_SAP, Clte_Factura_SAP, SF_Amount )
            VALUES    
              ( Doc.SF_Factura, Doc.SF_Factura, Doc.SF_Factura, 
                TO_DATE( Doc.SF_Fecha_Factura, 'YYYY-MM-DD' ), SYSDATE,
                Doc.Ctro, '0000', Doc.SF_Tipo_Doc, 1, TO_DATE( Doc.SF_Fecha_Factura, 'YYYY-MM-DD' ),
                Doc.Nombre_Cliente,
                Doc.SF_Cliente_SAP, Doc.SF_Cliente_SAP, Doc.SF_Importe_TMD ) ;
         END IF ;       
      END IF ;
   END LOOP ;
   FOR Doc IN ScrInfoSAP LOOP
      nProceso4 := nProceso4 + 1 ;
      UPDATE EAI.CFDI_Bitacora SET SAP_Amount  = Doc.Monto_SAP * Doc.Factor_SAP,
                                   Factura_SAP = Doc.Documento_SAP 
         WHERE Doc_Num = Doc.Doc_Num ;
   END LOOP ;
--
-- Workaround para CreditMemo - Credit Notes - Entity
   FOR CM IN ScrCreditMemoDelete LOOP
      DELETE EAI.CFDI_Bitacora  
         WHERE Doc_Num = CM.Doc_Num ;
   END LOOP ;
   UPDATE EAI.CFDI_Bitacora  Bita SET Bita.SF_Amount = NVL( Bita.SAP_Amount, 0 )
      WHERE ( ( Bita.Doc_Num LIKE 'DESC%'   )
           OR ( Bita.Doc_Num LIKE 'CONECT%' ) )  
        AND NVL( Bita.SAP_Amount, 0 ) != NVL( Bita.SF_Amount, 0 )
        AND NVL( Bita.SF_Amount , 0 ) != 0
        AND Bita.Invc_dt > SYSDATE - 45 ;   
--
   UPDATE EAI.CFDI_Informe  Info SET ( Status, Folio_Fiscal, Valor_Subt, Valor_IVA ) =
       ( SELECT CFD.Status, CFD.Folio_Fiscal , CFD.Valor_Subt * Info.Factor , CFD.Valor_IVA * Info.Factor
            FROM T3.CFDI_Documentos CFD
            WHERE Info.Folio_Interno = CFD.Nota_Venta AND CFD.Folio_Fiscal IS NOT NULL )
      WHERE Info.Folio_Fiscal IS NULL ;
   IF ( LENGTH( sPeriodo ) > 4 ) THEN
      FOR Doc IN ScrWA_MesAnterior LOOP
         UPDATE EAI.CFDI_Bitacora SET SF_Amount = Doc.Importe * Doc.FactorDoc
            WHERE Doc_Num = Doc.Doc_Num ;
      END LOOP ;
      FOR Doc IN ScrWA_MesSiguiente LOOP
         UPDATE EAI.CFDI_Bitacora SET Invc_dt = Doc.Fecha_Factura
            WHERE Doc_Num = Doc.Doc_Num ;
      END LOOP ;
      FOR Doc IN ScrWA_LOBInicioMes LOOP
            nProceso3 := nProceso3 + 1 ;
            INSERT INTO EAI.CFDI_Bitacora 
               ( Row_ID     , Doc_Num         , Nota_Venta_CFDI, 
                 Invc_Dt    , Fecha_Trn       , Factura_SAP,
                 Ctro       , Terr, Tipo_Vta  , Docto_Ind, Fecha_Venta, 
                 Nombre_Cliente, Cliente_SAP, Clte_Factura_SAP, 
                 SF_Amount, SAP_Amount )
            VALUES    
              ( Doc.Factura, Doc.Factura, Doc.Factura, 
                Doc.Fecha_Factura, Doc.Fecha_Trn, Doc.Entrega,
                Doc.Ctro, '0000', Doc.Tipo_Vta, 1, Doc.Fecha_Factura, 
                Doc.Nombre_Cliente, Doc.Cliente_SAP, Doc.Cliente_SAP, 
                Doc.Importe_SAP * Doc.FactorDoc ,
                Doc.Importe_SAP * Doc.FactorDoc ) ;   
      END LOOP ;
   END IF ;
-- Eliminar Cheques Devueltos   
   DELETE EAI.CFDI_Bitacora
      WHERE Doc_Num LIKE 'CHP%' ;
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
        ( DIRECTION           , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,          
          STATUS              , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'       , v_ID                       , SYSDATE             , NULL           , nPID   , 
          'Error'             , 'SF_BITACORA_CFDI_VENTA_SF', sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                       , NULL                , NULL            ) ;
      COMMIT ; 
      DBMS_Output.Put_LINE( '---------------------------------------------' ) ;
      DBMS_Output.Put_LINE( '**** Error en SF_BITACORA_CFDI_VENTA_SF *****' ) ;
      DBMS_Output.Put_LINE( sMsg ) ;      
END ;