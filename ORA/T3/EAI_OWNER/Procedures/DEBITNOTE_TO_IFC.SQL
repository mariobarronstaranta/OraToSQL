create or replace PROCEDURE           DEBITNOTE_TO_IFC
   ( sInvoiceID   IN   VARCHAR2)
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(050) ;
   CURSOR ScrDebitNote IS
      SELECT 
          TO_DATE( SUBSTR( PG.DocumentDate, 1, 8 ), 'YYYYMMDD' )
                                                             AS DocumentDate  ,
          PG.PedidoV3                                        AS PedidoV3      ,
          PG.FacturaSAP                                      AS Cust_to_SAP   ,
          PD.Total                                           AS Total         ,
          PG.ReferenceID                                     AS SAP_Document  ,
          DN.SAP_Document                                    AS DN_DocumentSAP,
          REPLACE( PG.PedidoV3, 'SU-', '' )                  AS Factura
      FROM EAI_Owner.tmp_Document_Header    PG,
           T3.DEBIT_NOTE_IFC                DN,
                          (
                            SELECT PD.ItemID                            AS Num_Linea   ,
                                   PD.Material                          AS Material    ,
                                   PD.Cantidad                          AS Cantidad_Vta, 
                                     ( NVL( PD.Valor_Subt, 0 ) / 100 )
                                   + ( NVL( PD.Valor_IVA , 0 ) / 100 )  AS Total       ,
                                   NVL( PD.Valor_Subt, 0 ) / 100        AS Valor_Subt  ,
                                   NVL( PD.Valor_IVA , 0 ) / 100        AS Valor_IVA
                               FROM EAI_Owner.tmp_Document_Detail  PD
                               WHERE PD.ReferenceID  = sInvoiceID
                           )                    PD  
      WHERE PG.ReferenceID   = sInvoiceID 
        AND PG.NombreCliente = 'DebitNote'
        AND PG.PedidoV3      = DN.DEBIT_NOTE(+) ;   
BEGIN
   v_ID := sInvoiceID ;
   FOR DN IN ScrDebitNote LOOP
      IF ( DN.DN_DocumentSAP IS NULL ) THEN
         INSERT INTO T3.DEBIT_NOTE_IFC
            ( DEBIT_NOTE, DOCUMENT_DATE, CUST_TO_SAP, TOTAL_AMT, SAP_DOCUMENT, CREATED, FACTURA )      
         VALUES
            ( DN.PedidoV3, DN.DocumentDate, DN.Cust_to_SAP, DN.Total, DN.SAP_Document, SYSDATE, DN.Factura ) ;
      END IF ;
   END LOOP ;
--
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE         , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME        , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT       , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Sending to V3'    , v_ID              , SYSDATE             , NULL           ,
          'Error'            , 'DEBITNOTE_TO_IFC', sMsg                , 'XML'          ,
          sErrorCode         , NULL              , NULL                , NULL            ) ;
      COMMIT ;
END DEBITNOTE_TO_IFC ;