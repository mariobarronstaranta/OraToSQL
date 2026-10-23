create or replace PROCEDURE    "PROC_CFDI_PROCESAR_PAGOS" 
   ( dtFechaProcBATMD  IN  DATE )
IS
   sMsg                 VARCHAR2(0500) ;
   nDoctos              NUMBER(06)     ;
--
   strID                VARCHAR2(050) ;
   sErrorCode           VARCHAR2(030) ;      
   strFactura           VARCHAR2(050) ;
   strNotaCredito       VARCHAR2(050) ;
   sSubProcess          VARCHAR2(050) ;
   sReferencia          VARCHAR2(030) ;
   dtInicio             DATE          ;
   nPID                 NUMBER(08)    ;
   nProceso             NUMBER(08)    ;
   nProceso1            NUMBER(08)    ;
   nProceso2            NUMBER(08)    ;
   nProceso3            NUMBER(08)    ;
   nProceso4            NUMBER(08)    ;
   dtFacturaProcBATMD   DATE          ;
   nT3Importe           NUMBER(16,4)  ;
   nT3Existe            NUMBER(01)    ;
   nTtl_Invc_Amt        NUMBER(16,4)  ;
   dtInvc_dt            DATE          ;
   nSaldo_Pendiente     NUMBER(16,4)  ;
   sSub_Type_CD         VARCHAR2(30)  ;
   nSecuenciaPagos      NUMBER(10)    ;
   nSecuenciaCM         NUMBER(10)    ;
   nAbonoPagos          NUMBER(16,4)  ;
   nAbonoCM             NUMBER(16,4)  ;
--
   sFolio_ID            VARCHAR2(30)  ;
   sAsignacion_ID       VARCHAR2(30)  ;
   sPayment_Req_Num     VARCHAR2(30)  ;
   dtActl_Pay_dt        DATE          ;
   dtFecha_Asignacion   DATE          ;
   dtAsig_Created       DATE          ;
   nImporte             NUMBER(16,2)  ;
   nSaldo_Anterior      NUMBER(16,2)  ;
   nNumero_Pago         NUMBER(10)     ;
   sCreated_By          VARCHAR2(30)  ;
   sAccnt_ID            VARCHAR2(30)  ;
   sCliente_SAP         VARCHAR2(30)  ;
   sSociedad            VARCHAR2(30)  ;
   sReceptorBanco       VARCHAR2(30)  ;
   sReceptorCuenta      VARCHAR2(30)  ;
   sCtro                VARCHAR2(30)  ;
   sBanco_Nombre        VARCHAR2(30)  ;
   sBanco_Num_Cuenta    VARCHAR2(30)  ;
   sNumero_Cheque       VARCHAR2(30)  ; 
   dtDB_Last_Upd        DATE          ;
   sFactura             VARCHAR2(30)  ;
   sNota_Venta          VARCHAR2(30)  ;
   sRFC                 VARCHAR2(15)  ;
   sStatus              VARCHAR2(30)  ;
   sVia_Pago            VARCHAR2(30)  ; 
   nCant_Pagos          NUMBER(10)    ;
   nAbono_Pagos         NUMBER(16,2)  ;
   nCant_CM             NUMBER(10)    ;
   nAbono_CM            NUMBER(16,2)  ;
   sNota_Credito        VARCHAR2(40)  ;
   sVenta_UUID          VARCHAR2(40)  ;
   dtFecha_Factura      DATE          ; 
   nDias_Cdto           NUMBER(3)     ;
   nImporte_Factura     NUMBER(16,2)  ;
   sCteMethod           VARCHAR2(30)  ;
   sCteBankName         VARCHAR2(30)  ;
   sCteAccountNum       VARCHAR2(30)  ;
   dtFechaEnvio         DATE          ;
   nTasa_IVA            NUMBER(6,2)   ; 
   nSAT_Amount          NUMBER(13,3 ) ;
   nReq_SAT_Amt         NUMBER(04)    ;   
--   
   CURSOR ScrPagos IS
        SELECT 
               AP.Rep_ID                                      AS Created_By        , 
               AP.Pago_ID                                     AS Payment_Req_Num   ,  
               AP.Fecha_Asignacion                            AS Actl_Pay_dt       ,
               AP.Asignacion_ID                                                    , 
               AP.Pago_ID                                     AS Payment_ID        ,  
               AP.Factura                                                          , 
               AP.Nota_Credito                                                     , 
               AP.Cliente_SAP                                                      , 
               AP.Valor_Pago, 
               AP.Fecha_Asignacion, 
               AP.Ctro                                                             ,
               ''                                             AS Invoice_ID        ,
               NVL( TD.Origen, 'INCOBRABLE' )                 AS Sub_Type_CD       ,
               ''                                             AS Accnt_ID          ,
               T3.FN_TOTAL_FACT(Ap.Factura)                   AS Ttl_Invc_Amt      ,
               ''                                             AS Vendr_Invoice_Num ,
               AP.Fecha_Asignacion                            AS Asig_Created      ,
               Ap.Fecha_Trn                                   AS DB_Last_Upd       ,
               Cte.RFC                                        AS X_Cust_Tax_Number ,
               RF.Fecha_Factura                               AS Invc_dt           ,
               Cte.Dias_Cdto                                  AS Dias_Cdto         ,       
               ''                                             AS Banco_Nombre      ,
               ''                                             AS Banco_Num_Cuenta  ,
               ''                                             AS Numero_Cheque     ,
               NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT
           FROM T3.Asignacion_Pago        AP  ,
                T3.Cliente                Cte ,
                T3.Registro_Fiscal        RF  ,
                T3.Tipo_Documento         TD  ,
                T3.CFDI_Documentos        CFD
           WHERE AP.Fecha_Proc_BATMD   = dtFechaProcBATMD
              AND AP.Cliente_SAP       = Cte.Cliente_SAP
              AND AP.Fecha_Asignacion BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
              AND AP.Factura           = RF.Factura(+)
              AND RF.Tipo_Docto        = TD.Tipo_Documento(+)
              AND AP.Factura           = CFD.Nota_Venta(+)
            ORDER BY AP.Cliente_SAP, Ap.Fecha_Asignacion, Ap.Asignacion_ID;
-- 
   CURSOR ScrAsignaciones IS             
        SELECT 
               Asig.Asignacion_ID                              AS Row_ID        ,
               Asig.Fecha_Asignacion                           AS Created       , 
               NVL( Asig.Valor_Pago, 0)                        AS Paid_Amt      , 
               Decode(Pago.Fecha_Pago, NULL, Asig.Fecha_Asignacion              , 
                       Pago.Fecha_Pago                       ) AS Actl_Pay_dt   , 
               CASE
                  WHEN Asig.Nota_Credito IS NOT NULL 
                  THEN 'Returns' 
                  ELSE Pago.Tipo_Pago 
               END                                             AS Type_CD       , 
               CASE 
                  WHEN Asig.Nota_Credito IS NULL 
                  THEN EAI_OWNER.getConv( 'TMD_PAC Accnt Payment Type', 
                                          Pago.Metodo_Pago )
                  ELSE 'Credit Memo'
               END                                             AS Pay_Type_CD   , 
               NVL(Pago.REP_ID, Asig.Rep_ID)                   AS Created_By    ,
               CASE
                  WHEN Asig.Nota_Credito IS NULL
                  THEN EAI_OWNER.getConv( 'TMD_PAC Accnt Payment Method', 
                                          Pago.Metodo_Pago ) 
                  ELSE 'CM'
               END                                             AS Via_Pago      , 
               NVL(Cobza.Numero_Pago , 0 )                     AS Numero_Pago   ,
               NVL(Cobza.Cant_CM , 0     )                     AS Cant_CM       ,
               Asig.Nota_Credito                               AS Integration_ID,
               ''                                              AS Factura       , 
               ''                                              AS Entrega       , 
               ''                                              AS Referencia
           FROM T3.Asignacion_Pago       Asig,
                T3.Pago                  Pago,
                T3.CFDI_Cobranza         Cobza
           WHERE Asig.Factura           = strID
             AND Asig.Pago_ID           = Pago.Pago_ID(+)
             AND Asig.Asignacion_ID     = Cobza.Asignacion_ID(+)
             AND Asig.Fecha_Asignacion  >= TO_DATE( '20180901', 'YYYYMMDD' )    
             Order By Asig.Fecha_Asignacion, Asig.Asignacion_ID;  
--
   CURSOR ScrT3Procesado IS
        SELECT FG.Fecha_Proc_BATMD, HDP.Nota_Venta_CFDI, FG.Factura AS Referencia, 
               SUM( NVL( FD.Valor_Subt, 0 ) + NVL( FD.Valor_IVA, 0 ) + NVL( FD.Envio_Subt, 0 ) + NVL( FD.Envio_IVA, 0 ) 
                  + NVL( FD.Credito_Subt, 0 ) + NVL( FD.Credito_IVA, 0 )                                                ) AS Importe   ,
               SUM( NVL( FD.Valor_Subt, 0 ) + NVL( FD.Envio_Subt, 0 ) + NVL( FD.Credito_Subt, 0 ) )                       AS Valor_Subt, 
               SUM( NVL( FD.Valor_IVA , 0 ) + NVL( FD.Envio_IVA , 0 ) + NVL( FD.Credito_IVA , 0 ) )                       AS Valor_IVA
           FROM T3.Factura_General FG, T3.CFDI_Historia_Docto_PAC HDP, T3.Factura_Detalle FD
           WHERE FG.Factura = strFactura
             AND FG.Factura = HDP.Nota_Venta(+)
             AND FG.Factura = FD.Factura
        GROUP BY FG.Fecha_Proc_BATMD, HDP.Nota_Venta_CFDI, FG.Factura     
        UNION ALL
        SELECT PG.Fecha_Proc_BATMD, HDP.Nota_Venta_CFDI, PG.Referencia AS Referencia,
               SUM( NVL( PD.Valor_Subt  , 0 ) + NVL( PD.Valor_IVA  , 0 ) + NVL( PD.Envio_Subt, 0 ) + NVL( PD.Envio_IVA, 0 ) 
                  + NVL( PD.Credito_Subt, 0 ) + NVL( PD.Credito_IVA, 0 )
                                                                                                                        ) AS Importe   ,
               SUM( NVL( PD.Valor_Subt, 0 ) + NVL( PD.Envio_Subt, 0 ) + NVL( PD.Credito_Subt, 0 ) )                       AS Valor_Subt, 
               SUM( NVL( PD.Valor_IVA , 0 ) + NVL( PD.Envio_IVA , 0 ) + NVL( PD.Credito_IVA , 0 ) )                       AS Valor_IVA
           FROM T3.Preventa_General PG, T3.CFDI_Historia_Docto_PAC HDP, T3.Preventa_Detalle PD 
           WHERE PG.Factura = strFactura       
             AND PG.Factura = HDP.Nota_Venta(+)
             AND PG.Factura = PD.Factura
           GROUP BY PG.Fecha_Proc_BATMD, HDP.Nota_Venta_CFDI, PG.Referencia ;   
--
   CURSOR ScrVentaUUID IS
        SELECT Folio_Fiscal, Status 
           FROM T3.CFDI_Documentos
           WHERE Nota_Venta = sNota_Venta ;             
--
   CURSOR ScrDebitNote IS
      SELECT PG.Factura, CFD.Folio_Fiscal
         FROM T3.Preventa_General PG,
              T3.CFDI_Documentos CFD
         WHERE PG.Referencia = strFactura
           AND PG.Factura    = CFD.Nota_Venta(+) ;
--
   CURSOR ScrCancPago IS
      SELECT CP.Debit_Note         AS Factura      ,
             CP.Document_Date      AS Fecha_Factura,
             CP.Total_Amt          AS Ttl_Invc_Amt
         FROM T3.DEBIT_NOTE_IFC CP
         WHERE CP.Debit_Note = strFactura ;   
--
BEGIN
   dtInicio  := SYSDATE ;
   nProceso  := 604 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, dtFechaProcBATMD, SYSDATE ) ;   
   nDoctos   := 0 ;
   nProceso1 := 0 ;
   nProceso2 := 0 ;
   nProceso3 := 0 ;
   nProceso4 := 0 ;
   SELECT EAI_owner.getConv( 'CFG Settings', 'CompanyCode'          )   AS Sociedad      ,
          EAI_owner.getConv( 'CFG Settings', 'Banco Def - Directo'  )   AS ReceptorBanco ,
          EAI_owner.getConv( 'CFG Settings', 'Cuenta Def - Directo' )   AS ReceptorCuenta
             INTO sSociedad, sReceptorBanco, sReceptorCuenta
      FROM DUAL ;
 --DBMS_Output.Put_Line( 'Before ScrPagos' ) ;
   FOR Doc IN ScrPagos LOOP
    --DBMS_OUTPUT.PUT_LINE( Doc.Factura ) ;
      sSubProcess          := 'ScrPagos'            ;
--    strID                := Doc.Invoice_ID        ;
      strID                := Doc.Factura           ;      
      strFactura           := Doc.Factura           ;
      strNotaCredito       := Doc.Nota_Credito      ;
      sSub_Type_CD         := Doc.Sub_Type_CD       ;
      dtInvc_dt            := Doc.Invc_dt           ;
      dtFecha_Factura      := Doc.Invc_dt           ;
      nDias_Cdto           := Doc.Dias_Cdto         ;
      nDoctos              := nDoctos + 1           ;
      dtFacturaProcBATMD   := NULL                  ;
      nT3Importe           := 0                     ;
      sStatus              := NULL                  ;
      nT3Existe            := 0                     ;
    --DBMS_Output.Put_Line( 'Before sFolio_ID' ) ; 
      sFolio_ID            := Doc.Asignacion_ID     ;
      sAsignacion_ID       := Doc.Asignacion_ID     ;
      sPayment_Req_Num     := Doc.Payment_Req_Num   ;
      dtActl_Pay_dt        := Doc.Actl_Pay_dt       ;
      dtAsig_Created       := Doc.Asig_Created      ;
      dtDB_Last_Upd        := Doc.DB_Last_Upd       ;
      dtFecha_Asignacion   := NULL                  ;
      nImporte             := Doc.Valor_Pago        ;
      nSaldo_Anterior      := NULL                  ;
      nNumero_Pago         := NULL                  ;
      sCreated_By          := Doc.Created_By        ;
      sAccnt_ID            := Doc.Accnt_ID          ;
      sCliente_SAP         := Doc.Cliente_SAP       ;
      sFactura             := Doc.Factura           ;
      sBanco_Nombre        := Doc.Banco_Nombre      ;
      sBanco_Num_Cuenta    := Doc.Banco_Num_Cuenta  ;
      sNumero_Cheque       := Doc.Numero_Cheque     ;      
      sCtro                := Doc.Ctro              ;
      sNota_Venta          := NULL                  ;
    --DBMS_Output.Put_Line( 'Before sRFC' ) ; 
    --DBMS_Output.Put_Line( 'sRFC->' || Doc.X_Cust_Tax_Number || '<-' ) ;
      sRFC                 := Doc.X_Cust_Tax_Number ;
      nSAT_Amount          := Doc.Importe_SAT       ;
      sStatus              := ''                    ;
      sVia_Pago            := ''                    ;
      nCant_Pagos          := 0                     ;
      nAbono_Pagos         := 0                     ;
      nCant_CM             := 0                     ;
      nAbono_CM            := 0                     ;
      sNota_Venta          := ''                    ;
      sNota_Credito        := ''                    ;
      sVenta_UUID          := ''                    ;
      sReferencia          := ''                    ;
      nImporte_Factura     := 0                     ;
      nTasa_IVA            := NULL                  ;
    --DBMS_Output.Put_Line( 'Before IF sSub_Type_CD' ) ; 
      IF ( sSub_Type_CD != 'Nota de Venta' ) THEN
         sStatus          := sSub_Type_CD     ;      
         nImporte_Factura := Doc.Ttl_Invc_Amt ;
         nTtl_Invc_Amt    := Doc.Ttl_Invc_Amt ;
         sVenta_UUID      := ''               ;
         sSubProcess      := 'ScrDebitNote'   ;
         FOR DN IN ScrDebitNote LOOP
            sNota_Venta := DN.Factura      ;
            sVenta_UUID := DN.Folio_Fiscal ;
            sStatus     := 'DN - Penalizacion' ;
         END LOOP ;
         FOR CP IN ScrCancPago LOOP
            sNota_Venta      := CP.Factura       ;
            sVenta_UUID      := ''               ;
            sStatus          := 'Canc Pago'      ;
            nImporte_Factura := CP.Ttl_Invc_Amt  ;
            nTtl_Invc_Amt    := CP.Ttl_Invc_Amt  ;
            dtInvc_dt        := CP.Fecha_Factura ;
            dtFecha_Factura  := CP.Fecha_Factura ;
         END LOOP ;
      ELSE
      -- DBMS_Output.Put_Line( 'Before ScrT3Procesado' ) ;
      -- Informacion de Procesamiento en T3
         FOR Inv IN ScrT3Procesado LOOP
            sSubProcess        := 'ScrT3Procesado'     ;
            nT3Existe          := nT3Existe + 1        ;
            dtFacturaProcBATMD := Inv.Fecha_Proc_BATMD ;
            nT3Importe         := Inv.Importe          ;
            sNota_Venta        := Inv.Nota_Venta_CFDI  ;
            sReferencia        := Inv.Referencia       ;
            IF ( Inv.Valor_Subt > 0 ) THEN
               nTasa_IVA          := ROUND( Inv.Valor_IVA * 100 / Inv.Valor_Subt, 2 ) ;
            ELSE
               nTasa_IVA          := 0 ;
            END IF ;   
            IF ( nTasa_IVA >= 15.98 ) THEN
               nTasa_IVA := 16 ;
            END IF ;
         END LOOP ;         
         IF ( ( nT3Existe = 0 ) OR ( TO_CHAR( NVL( dtFacturaProcBATMD, TO_DATE( '29991231', 'YYYYMMDD' ) ), 'YYYY' ) = '2999' ) ) THEN
            nTtl_Invc_Amt := Doc.Ttl_Invc_Amt ;
            sStatus       := 'PendienteT3'    ;
            nTasa_IVA     := 00 ;
         ELSE
            nTtl_Invc_Amt := nT3Importe       ;     
            FOR CFD IN ScrVentaUUID LOOP
               IF ( CFD.Status = 'CONFIRMADO' ) THEN
                  sVenta_UUID := CFD.Folio_Fiscal ; 
               END IF ;
            END LOOP ;    
         END IF ;
      END IF ;          
--
      IF ( ( LENGTH( sRFC ) > 0 ) AND ( sRFC != 'XAXX010101000' ) ) THEN
         SELECT MAX( NVL( Target, '0' ) ) INTO nReq_SAT_Amt
            FROM EAI_Owner.MX_HashTable 
            WHERE Type   = 'SAT Amount Invoice'
              AND Source = sRFC ;
         IF ( NVL( nReq_SAT_Amt, 0 ) > 1 ) AND ( nSAT_Amount > 0 ) THEN
            nTtl_Invc_Amt := nSAT_Amount ;
         END IF ;
      END IF ;
--      
      -- Informacion de Cobranza
         nSecuenciaPagos  := 0             ;
         nSecuenciaCM     := 0             ;
         nAbonoPagos      := 0             ;
         nAbonoCM         := 0             ;          
         nSaldo_Pendiente := nTtl_Invc_Amt ;
         nImporte_Factura := nTtl_Invc_Amt ;
       --DBMS_Output.Put_Line( 'Before ScrAsignaciones' ) ;
         IF ( strID != 'INCOBRABLE' ) THEN
            FOR Pay IN ScrAsignaciones LOOP
               sSubProcess        := 'ScrAsignaciones'     ; 
               IF ( sAsignacion_ID = Pay.Row_ID ) THEN
                  IF ( ( Pay.Type_CD = 'Returns' ) OR ( LENGTH( Pay.Referencia ) > 0 ) ) THEN
                     nNumero_Pago    := nSecuenciaPagos     ;
                     sNota_Credito   := Pay.Integration_ID  ;
                     sVia_Pago       := Pay.Via_Pago        ;
--                   sStatus         := 'CreditMemo'        ;
                     IF (  LENGTH( Pay.Referencia ) > 0 ) THEN
                        sNota_Credito := Pay.Referencia  ;
                        sVia_Pago     := 'CM'            ;
                     END IF ;
                  ELSE
                     --nSecuenciaPagos := Pay.Numero_Pago     ;
                     nNumero_Pago    := nSecuenciaPagos + 1 ;
                     sVia_Pago       := Pay.Via_Pago        ;
                  END IF ;   
                  dtFecha_Asignacion := Pay.Created         ;
                  nImporte           := Pay.Paid_Amt        ;
                  nSaldo_Anterior    := nSaldo_Pendiente    ;
                  nCant_Pagos        := nSecuenciaPagos     ;
                  nAbono_Pagos       := nAbonoPagos         ;
                  nCant_CM           := nSecuenciaCM        ;
                  nAbono_CM          := nAbonoCM            ;
              END IF ;
            --
            --DBMS_Output.Put_Line( 'Asignacion_ID: '|| Pay.Row_ID ) ; 
            --DBMS_Output.Put_Line( 'Type_CD: '|| Pay.Type_CD ) ;
            --DBMS_Output.Put_Line( 'Cant_CM: '|| nCant_Pagos ||' / '|| nSecuenciaPagos) ;

               IF ( ( Pay.Type_CD = 'Returns' ) OR ( LENGTH( Pay.Referencia ) > 0 ) ) THEN
                  nSecuenciaCM    := nSecuenciaCM    + 1        ;
                  nAbonoCM        := nAbonoCM    + Pay.Paid_Amt ;
               ELSE
                  nSecuenciaPagos := nSecuenciaPagos + 1        ;  
                  nAbonoPagos     := nAbonoPagos + Pay.Paid_Amt ;
               END IF ;     

               nSaldo_Pendiente := nSaldo_Pendiente - Pay.Paid_Amt ;       
            END LOOP ;         
         END IF ;
--    END IF ;  
      IF ( dtFecha_Asignacion IS NULL ) THEN
         dtFecha_Asignacion := dtAsig_Created ;
      END IF ;
    --DBMS_Output.Put_Line( 'Before T3.CFDI_Cobranza' ) ;
      sSubProcess        := 'T3.GET_CUSTOMERPAYMENT_INFO' ; 
--      T3.GET_CUSTOMERPAYMENT_INFO( sAccnt_ID, sCteMethod, sCteBankName, sCteAccountNum ) ;

      sCteMethod := ''; 
      sCteBankName := ''; 
      sCteAccountNum := '';    
--
      dtFechaEnvio := NULL ;
      IF ( sRFC = 'XAXX010101000' ) THEN
         dtFechaEnvio := dtFechaProcBATMD ;
      END IF ;
--    
      IF ( sFactura = 'INCOBRABLE' ) THEN
         sVia_Pago := 'AI' ;
         sNota_Credito := strNotaCredito ;
      END IF ;
      --DBMS_Output.Put_Line( 'ANTES DE INSERT CANT_CM: '|| nCant_CM ) ; 
      INSERT INTO T3.CFDI_Cobranza 
         ( Folio_ID            , Asignacion_ID       , Fecha_Asignacion    , Importe             ,
           Saldo_Anterior      , Numero_Pago         , Accnt_ID            , Factura             ,
           Fecha_Factura       , Dias_Cdto           , Importe_Factura     , Created_By          ,
           DB_Last_Upd         , Banco_Nombre        , Banco_Num_Cuenta    , Numero_Cheque       ,
           Master_Banco        , Master_Cuenta       , Receptor_Banco      , Receptor_Cuenta     ,
           Pago_ID             , Fecha_Pago          , Sociedad            , Ctro                ,
           Nota_Venta          , RFC                 , Fecha_Proc_BATMD    , Fecha_Proceso       ,
           Fecha_Envio         , Tasa_IVA            , Referencia          ,
           Cant_Pagos          , Abono_Pagos         , Cant_CM             , Abono_CM            , 
           Status              , Via_Pago            , Nota_Credito        , UUID_Venta          , 
           Cliente_SAP)
      VALUES  
         ( sFolio_ID           , sAsignacion_ID      , dtFecha_Asignacion  , nImporte            ,
           nSaldo_Anterior     , nNumero_Pago        , sAccnt_ID           , sFactura            ,
           dtFecha_Factura     , nDias_Cdto          , nImporte_Factura    , sCreated_By         ,
           dtDB_Last_Upd       , sBanco_Nombre       , sBanco_Num_Cuenta   , sNumero_Cheque      ,    
           sCteBankName        , sCteAccountNum      , sReceptorBanco      , sReceptorCuenta     , 
           sPayment_Req_Num    , dtActl_Pay_dt       , sSociedad           , sCtro               ,
           sNota_Venta         , sRFC                , dtFechaProcBATMD    , SYSDATE             ,
           dtFechaEnvio        , nTasa_IVA           , sReferencia         ,
           nCant_Pagos         , nAbono_Pagos        , nCant_CM            , nAbono_CM           , 
           sStatus             , sVia_Pago           , sNota_Credito       , sVenta_UUID         ,
           sCliente_SAP); 
   END LOOP ;
   nProceso1 := nDoctos ;
--
--   INSERT INTO T3.RF_PROCESOS_LOG 
--      ( PID , Proceso , Fecha_Proc_BATMD, Inicio  , Fin    , Proceso_1, Proceso_2, Proceso_3, Proceso_4 )
--   VALUES 
--      ( nPID, nProceso, dtFechaProcBATMD, dtInicio, SYSDATE, nProceso1, nProceso2, nProceso3, nProceso4 ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_2 = nProceso2,
                                                 Proceso_3 = nProceso3, Proceso_4 = nProceso4
       WHERE PID = nPID  ;         
   COMMIT ;   
   T3.WA_CFDI_COBZA_ASIG_CTRL( 3, 0 ) ;
   COMMIT ;
--   
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      sMsg := SUBSTR( SQLERRM, 1, 250 ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
      DBMS_Output.Put_Line( 'Problemas en la ejecucion del Procedimiento' ) ;
      DBMS_Output.Put_Line( 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :' ) ;
      DBMS_Output.Put_Line( 'Procedimiento : ' || 'PROC_CFDI_PAGOS' ) ;
      DBMS_Output.Put_Line( 'Fecha         : ' || TO_CHAR( SYSDATE, 'YYYYMMDD HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Referencia    : ' || sAsignacion_ID ) ;
      DBMS_Output.Put_Line( 'Substep       : ' || sSubProcess    ) ;
      DBMS_Output.Put_Line( 'Error         : ' || sMsg ) ;
      DBMS_Output.Put_Line( LPAD( '-', 80, '-' ) ) ;
--      INSERT INTO T3.RF_ERROR_LOG 
--         ( FECHA, RUTINA, REFERENCIA, ERROR_DESC )
--      VALUES
--         ( SYSDATE, 'PROC_CFDI_PAGOS', sAsignacion_ID, sMsg ) ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sAsignacion_ID            , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CFDI_PROCESAR_PAGOS', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CFDI_PROCESAR_PAGOS ;