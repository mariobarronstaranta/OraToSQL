create or replace PROCEDURE           INVOICE_TO_ENTREGA
   ( sInvoiceID   IN   VARCHAR2,
     nOutput      IN   NUMBER DEFAULT 0,
     sBillingDoc  IN   VARCHAR2 DEFAULT 'NOBILL' )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   sAccnt_ID       VARCHAR2(030) ;
   sProcesar       VARCHAR2(002) ;
   sFacturaV3      VARCHAR2(030) ;
   sClienteV3      VARCHAR2(030) ;
--
   CURSOR ScrEntrega IS
       SELECT Doc.Cust_to_SAP, Doc.Order_Num, PG.Factura, Ent.Entrega, PG.Fecha_Proc_BATMD, PG.Fecha_Factura,
              TO_DATE( SUBSTR( Head.Fecha_Vencimiento, 1, 8 ), 'YYYYMMDD' )     AS Fecha_Pago,
              EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP)                    AS Cliente_V3                       
          FROM EAI_Owner.tmp_Document_Header   Doc,
               T3.Preventa_General             PG ,
               T3.Entrega                      Ent,
               EAI_Owner.tmp_Document_Header   Head
          WHERE Doc.ReferenceID = sInvoiceID
            AND Doc.Order_Num   = PG.Referencia
            AND PG.Entrega      = Head.ReferenceID
            AND PG.Factura      = Ent.Factura(+)
       UNION    
       SELECT Doc.Cust_to_SAP, Doc.PedidoV3 AS Order_Num, PG.Factura, Ent.Entrega, PG.Fecha_Proc_BATMD, PG.Fecha_Factura,
              TO_DATE( SUBSTR( Head.Fecha_Vencimiento, 1, 8 ), 'YYYYMMDD' )     AS Fecha_Pago,
              EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP)                    AS Cliente_V3                       
          FROM EAI_Owner.tmp_Document_Header   Doc,
               T3.Preventa_General             PG ,
               T3.Entrega                      Ent,
               EAI_Owner.tmp_Document_Header   Head
          WHERE Doc.ReferenceID = sBillingDoc
            AND Doc.PedidoV3    = PG.Referencia
            AND PG.Entrega      = Head.ReferenceID
            AND PG.Factura      = Ent.Factura(+) ;        
--
    CURSOR ScrFolioFE IS
        SELECT Doc.ReferenceID                AS Row_ID   ,
               Doc.ReferenciaBancaria         AS Entrada  ,
               'INTERFACE'                    AS CreadoPor,
               SYSDATE                        AS Creacion ,
               Doc.Order_Num                  AS Var_1    ,
               NVL( FE.CreadoPor, 'INSERT' )  AS Operation
           FROM EAI_Owner.tmp_Document_Header   Doc,
                EAI.IFC_Folios_FE               FE
           WHERE Doc.ReferenceID         = sInvoiceID   
             AND Doc.ReferenciaBancaria IS NOT NULL
             AND Doc.MetodoPago          = 'Van Replenishment'
--           AND Doc.ReferenceID         = FE.Row_ID(+) ;     
             AND Doc.Order_Num           = FE.Var_1(+) ;              
--
BEGIN
   v_ID      := sInvoiceID ;
   sProcesar := 'NO'       ;
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'Begin' ) ;
   END IF ;      
   FOR Doc IN ScrEntrega LOOP
      IF ( nOutput > 0 ) THEN
         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
            VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'ScrEntrega' ) ;
      END IF ;          
      sFacturaV3 := Doc.Factura    ;
      sClienteV3 := Doc.Cliente_V3 ;
      IF ( Doc.Entrega IS NULL ) THEN
         sProcesar := 'SI' ;
      END IF ;   
-- 
     IF ( sProcesar = 'SI' ) THEN
            IF ( nOutput > 0 ) THEN
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', sFacturaV3, 'Insert T3.Entrega' ) ;
            END IF ;          
--
            DELETE FROM T3.RF_Complemento WHERE Factura = sFacturaV3 ;
            DELETE FROM T3.Entrega        WHERE Factura = sFacturaV3 ;
            INSERT INTO T3.RF_Complemento 
               ( Factura     , Hora_Factura, Anio_Aprob, Folio_Aprob, Order_Num    , Rep_ID     , X_DelRep_Invloc, 
                 Volumen     , Sociedad    , Cadena_Original        , Sello_Digital, Dias_Pago )
            VALUES 
               ( sFacturaV3  , TO_CHAR( SYSDATE, 'HH24:MI:SS'), 'Error', 'Error', '', 'U00000000', '', 
                 NULL, 'MX06', 'CFDI - Documento', 'CFDI - Documento', Doc.Fecha_Pago - Doc.Fecha_Factura ) ;            
            INSERT INTO T3.Entrega
               ( Factura, Entrega, Fecha_Trn, Status_Entrega, Ubicacion, Rep_ID, Fecha_Entrega, Cliente_V3, Cliente_SAP )            
            SELECT PG.Factura, PG.Entrega, SYSDATE AS Fecha_Trn, '1' AS Status, '0000' AS Ubicacion, 'U00000000' AS Rep_ID, 
               PG.Fecha_Factura, sClienteV3, PG.Cliente_SAP
               FROM T3.Preventa_General PG
               WHERE PG.Factura = sFacturaV3 ;
      ELSE         
            IF ( nOutput > 0 ) THEN
               INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                  VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'Discarded' ) ;
            END IF ;          
      END IF ;
   END LOOP ;
--
   FOR FE IN ScrFolioFE LOOP
      IF ( FE.Operation = 'INSERT' ) THEN
         INSERT INTO EAI.IFC_Folios_FE
            ( Row_ID, Entrada, CreadoPor, Creacion, Var_1 )  
         VALUES
            ( FE.Row_ID, FE.Entrada, FE.CreadoPor, FE.Creacion, FE.Var_1 ) ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'Insert EAI.IFC_Folios_FE' ) ;
         END IF ;          
      ELSE
         UPDATE EAI.IFC_Folios_FE SET Entrada = FE.Entrada, Modificacion = SYSDATE 
            WHERE Var_1 = FE.Var_1 ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'Already inserted' ) ;
         END IF ;                
      END IF ;
   END LOOP ;   
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA', v_ID, 'End' ) ;
   END IF ;      
--
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE       , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME      , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT     , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Sending to T3'    , v_ID            , SYSDATE             , NULL           ,
          'Error'            , 'Delivery to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL            , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_TO_ENTREGA ;