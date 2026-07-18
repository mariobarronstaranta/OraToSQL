create or replace PROCEDURE           SF_GET_INVOICE_DATA
   ( pInvoiceRef   IN   VARCHAR2,
     rtDoc_Num     OUT  VARCHAR2,
     rtCliente_SAP OUT  VARCHAR2,
     rtAmount      OUT  NUMBER  ,
     rtPending     OUT  NUMBER  ,
     rtPaid        OUT  NUMBER )
IS
   sInvoiceRef         VARCHAR2(500) ;
   sMsg                VARCHAR2(500) ;
   sErrorCode          VARCHAR2(500) ;
   v_ID                VARCHAR2(030) ;
   sDoc_Num            VARCHAR2(050) ;
   sCliente_SAP        VARCHAR2(050) ;
   sRow_ID             VARCHAR2(050) ;
   nAmount             NUMBER(13,3 ) ;
   nPending            NUMBER(13,3 ) ;
   nPaid               NUMBER(13,3 ) ;
   sDocType            VARCHAR2(030) ;
   sStatus_CD          VARCHAR2(030) ;
   dtFecha_Proc_BATMD  DATE          ;
   dtFechaCancelacion  DATE          ;
   nSAT_Amount         NUMBER(13,3 ) ;
   sRFC                VARCHAR2(030) ;
   nReq_SAT_Amt        NUMBER(04)    ;
--
   CURSOR ScrPromptSales IS
       SELECT FG.Factura, FG.Cliente_SAP, FG.Fecha_Proc_BATMD,
              MC.RFC                                             AS RFC,
              NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT
          FROM T3.Factura_General FG, 
               T3.Tipo_Documento  TD,
               T3.Mov_Cliente     MC,
               T3.CFDI_Documentos CFD
          WHERE FG.Factura        = sInvoiceRef
            AND FG.Tipo_Docto     = TD.Tipo_Documento
            AND TD.Cargo_Credito  = 1
            AND TD.Comercial      = 1
            AND FG.Cliente_SAP    = MC.Cliente_SAP
            AND FG.Factura        = CFD.Nota_Venta(+)
       UNION     
       SELECT FG.Factura, FG.Cliente_SAP, FG.Fecha_Factura AS Fecha_Proc_BATMD,
              MC.RFC                                             AS RFC,
              NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT
          FROM T3.Registro_Fiscal FG, 
               T3.Tipo_Documento  TD,
               T3.Mov_Cliente     MC,
               T3.CFDI_Documentos CFD
          WHERE FG.Entrega        = sInvoiceRef
            AND FG.Tipo_Docto     = TD.Tipo_Documento
            AND FG.Tipo_Docto     = 'C003'
            AND TD.Cargo_Credito  = 1
            AND FG.Cliente_SAP    = MC.Cliente_SAP
            AND FG.Factura        = CFD.Nota_Venta(+)
            AND TD.Comercial      = 1 ;            
--
   CURSOR ScrPresales IS
       SELECT FG.Factura, FG.Cliente_SAP, FG.Fecha_Proc_BATMD, FG.Fecha_Cancelacion,
              MC.RFC                                             AS RFC,
              NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT       
          FROM T3.Preventa_General FG, 
               T3.Tipo_Documento   TD,
               T3.Mov_Cliente      MC,
               T3.CFDI_Documentos  CFD               
          WHERE FG.Factura        = sInvoiceRef
            AND FG.Clase_Factura  = TD.Tipo_Documento
            AND TD.Cargo_Credito  = 1
            AND TD.Comercial      = 1 
            AND FG.Cliente_SAP    = MC.Cliente_SAP
            AND FG.Factura        = CFD.Nota_Venta(+)            
       UNION   
       SELECT FG.Factura, FG.Cliente_SAP, FG.Fecha_Proc_BATMD, FG.Fecha_Cancelacion,
              MC.RFC                                             AS RFC,
              NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT       
          FROM T3.Preventa_General FG, 
               T3.Tipo_Documento   TD,
               T3.Mov_Cliente      MC,
               T3.CFDI_Documentos  CFD
          WHERE FG.Entrega        = sInvoiceRef
            AND FG.Clase_Factura  = TD.Tipo_Documento
            AND TD.Cargo_Credito  = 1
            AND TD.Comercial      = 1 
            AND FG.Cliente_SAP    = MC.Cliente_SAP
            AND FG.Factura        = CFD.Nota_Venta(+)            
       UNION   
       SELECT FG.Factura, FG.Cliente_SAP, FG.Fecha_Proc_BATMD, FG.Fecha_Cancelacion,
              MC.RFC                                             AS RFC,
              NVL( CFD.Valor_Subt, 0 ) + NVL( CFD.Valor_IVA, 0 ) AS Importe_SAT       
          FROM T3.Preventa_General FG, 
               T3.Tipo_Documento   TD,
               T3.Mov_Cliente      MC,
               T3.CFDI_Documentos  CFD               
          WHERE FG.Referencia     = sInvoiceRef
            AND FG.Clase_Factura  = TD.Tipo_Documento
            AND TD.Cargo_Credito  = 1
            AND FG.Cliente_SAP    = MC.Cliente_SAP
            AND FG.Factura        = CFD.Nota_Venta(+)            
            AND TD.Comercial      = 1 ;
--
   CURSOR ScrCancPago IS
       SELECT CP.Debit_Note ,
              CP.Cust_to_SAP,
              CP.Total_Amt
          FROM T3.DEBIT_NOTE_IFC CP
          WHERE CP.Debit_Note = sInvoiceRef ;
BEGIN
   v_ID         := pInvoiceRef ;
   sInvoiceRef  := pInvoiceRef ;
   sDoc_Num     := NULL        ;
   sCliente_SAP := NULL        ;
   sRow_ID      := NULL        ;
   nAmount      := 0           ;
   nPending     := 0           ;
   nPaid        := 0           ;
   sStatus_CD   := NULL        ;
   sDocType     := 'None'      ;
   sRFC         := ''          ;
   nSAT_Amount  := 00          ;
   nReq_SAT_Amt := 00          ;
--
   FOR Doc IN ScrPromptSales LOOP
      sDocType           := 'Prompt'              ;
      sDoc_Num           := Doc.Factura           ;
      sCliente_SAP       := Doc.Cliente_SAP       ;
      dtFecha_Proc_BATMD := Doc.Fecha_Proc_BATMD  ;
      dtFechaCancelacion := NULL                  ;
      sRFC               := Doc.RFC               ;
      nSAT_Amount        := Doc.Importe_SAT       ;
   END LOOP ;
   IF ( sDocType = 'None' ) THEN
      FOR Doc IN ScrPreSales LOOP
         sDocType           := 'Presales'            ;
         sDoc_Num           := Doc.Factura           ;
         sCliente_SAP       := Doc.Cliente_SAP       ;
         dtFecha_Proc_BATMD := Doc.Fecha_Proc_BATMD  ;
         dtFechaCancelacion := Doc.Fecha_Cancelacion ;
         sRFC               := Doc.RFC               ;
         nSAT_Amount        := Doc.Importe_SAT       ;
      END LOOP ;
   END IF ;
   IF ( sDocType = 'None' ) THEN
      FOR Doc IN ScrCancPago LOOP
         sDocType           := 'CancPago'            ;
         sDoc_Num           := Doc.Debit_Note        ;
         sCliente_SAP       := Doc.Cust_to_SAP       ;
         dtFecha_Proc_BATMD := SYSDATE - 1           ;
         dtFechaCancelacion := NULL                  ;
         nAmount            := Doc.Total_Amt         ;
      END LOOP ;
   END IF ;
-- DBMS_Output.Put_Line( 'DocType => ' || sDocType ) ;
   IF ( sDocType != 'None' ) THEN
      IF ( sDocType = 'Prompt' ) THEN
          SELECT SUM( NVL( Valor_Subt, 0 ) + NVL( Valor_IVA, 0 ) + NVL( Envio_Subt, 0 ) + NVL( Envio_IVA, 0 ) + NVL( Credito_Subt, 0 ) + NVL( Credito_IVA, 0 ) ) INTO nAmount
             FROM T3.Factura_Detalle
             WHERE Factura = sDoc_Num ;
          IF SQL%NOTFOUND THEN
             nAmount := 0 ;
          END IF ;
      ELSIF ( sDocType = 'Presales' ) THEN
          SELECT SUM( NVL( Valor_Subt, 0 ) + NVL( Valor_IVA, 0 ) + NVL( Envio_Subt, 0 ) + NVL( Envio_IVA, 0 ) + NVL( Credito_Subt, 0 ) + NVL( Credito_IVA, 0 ) ) INTO nAmount
             FROM T3.Preventa_Detalle
             WHERE Factura = sDoc_Num ;
          IF SQL%NOTFOUND THEN
             nAmount := 0 ;
          END IF ;      
      END IF ;
-- 
      IF ( ( LENGTH( sRFC ) > 0 ) AND ( sRFC != 'XAXX010101000' ) ) THEN
             INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                VALUES ( SYSDATE, 'SF_GET_INVOICE_DATA', pInvoiceRef, 'Check ' || sRFC ) ;      
         SELECT MAX( NVL( Target, '0' ) ) INTO nReq_SAT_Amt
            FROM EAI_Owner.MX_HashTable 
            WHERE Type   = 'SAT Amount Invoice'
              AND Source = sRFC ;
         IF ( NVL( nReq_SAT_Amt, 0 ) > 1 ) AND ( nSAT_Amount > 0 ) THEN
            nAmount := nSAT_Amount ;
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                VALUES ( SYSDATE, 'SF_GET_INVOICE_DATA', pInvoiceRef, 'WA -> SAT Amount' ) ;
         END IF ;
      END IF ;
--
      IF ( nAmount > 0 ) THEN
         SELECT SUM( NVL( Importe, 0 ) )  INTO  nPaid
            FROM T3.CFDI_Cobranza
            WHERE Factura = sDoc_Num ;
         IF SQL%NOTFOUND THEN
            nPaid := 0 ;
         END IF ;
         nPending := nAmount - NVL( nPaid, 0 ) ;
      END IF ;
   END IF ;   
   rtDoc_Num     := sDoc_Num        ;
   rtCliente_SAP := sCliente_SAP    ;
   rtAmount      := nAmount         ;
   rtPending     := nPending        ;
   rtPaid        := NVL( nPaid, 0 ) ;
-- DBMS_Output.Put_Line( 'Cliente SAP : ' || rtCliente_SAP ) ;
-- DBMS_Output.Put_Line( 'Amount      : ' || rtAmount      ) ;   
EXCEPTION
   WHEN OTHERS THEN
      rtDoc_Num   := NULL ;
      rtAmount    := 0    ;
      rtPending   := 0    ;
      sErrorCode  := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE         , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME        , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT       , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Getting Info'     , v_ID              , SYSDATE             , NULL           ,
          'Error'            , 'GET_INVOICE_DATA', sMsg                , 'XML'          ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;
END SF_GET_INVOICE_DATA ;