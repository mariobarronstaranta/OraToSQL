create or replace PROCEDURE           INVOICE_TO_ENTREGA_PO
   ( sInvoiceID   IN   VARCHAR2,
     nOutput      IN   NUMBER DEFAULT 0 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   sAccnt_ID       VARCHAR2(030) ;
   sProcesar       VARCHAR2(002) ;
   sFacturaV3      VARCHAR2(030) ;
   sClienteV3      VARCHAR2(030) ;
--
    CURSOR ScrFolioFE IS
        SELECT 
               ReferenceID                    AS Entrega  ,
               Doc.ReferenceID                AS Row_ID   ,
               Doc.ReferenciaBancaria         AS Pedido   ,
               'INTERFACE'                    AS CreadoPor,
               SYSDATE                        AS Creacion ,
               Doc.PedidoV3                   AS Var_1    ,
               NVL( FE.CreadoPor, 'INSERT' )  AS Operation
           FROM EAI_Owner.tmp_Document_Header   Doc,
                EAI.IFC_Folios_FE               FE
           WHERE Doc.ReferenceID         = sInvoiceID
             AND Doc.ReferenciaBancaria IS NOT NULL
             AND Doc.ReferenciaBancaria != Doc.PedidoV3
             AND Doc.ReferenciaBancaria NOT LIKE 'OV%'
             AND Doc.ReferenciaBancaria NOT LIKE 'OD%'
             AND Doc.PedidoV3            = FE.Var_1(+) ;                
--
BEGIN
   v_ID      := sInvoiceID ;
   sProcesar := 'NO'       ;
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA_PO', v_ID, 'Begin' ) ;
   END IF ;      
   FOR FE IN ScrFolioFE LOOP
      IF ( FE.Operation = 'INSERT' ) THEN
         INSERT INTO EAI.IFC_Folios_FE
            ( Row_ID, Pedido, CreadoPor, Creacion, Var_1 )  
         VALUES
            ( FE.Row_ID, FE.Pedido, FE.CreadoPor, FE.Creacion, FE.Var_1 ) ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA_PO', v_ID, 'Insert EAI.IFC_Folios_FE' ) ;
         END IF ;          
      ELSE
         UPDATE EAI.IFC_Folios_FE SET Pedido = FE.Pedido, Modificacion = SYSDATE
            WHERE Var_1 = FE.Var_1 ;
         IF ( nOutput > 0 ) THEN
            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
               VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA_PO', v_ID, 'Already inserted' ) ;
         END IF ;                
      END IF ;
   END LOOP ;   
   IF ( nOutput > 0 ) THEN
      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
         VALUES ( SYSDATE, 'INVOICE_TO_ENTREGA_PO', v_ID, 'End' ) ;
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
END INVOICE_TO_ENTREGA_PO ;