create or replace PROCEDURE    "WA_ERR_INVOICE_PAYMETHOD" 
   ( pDias           IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrDocuments IS
      SELECT OG.Factura, OG.Fecha_Factura, OG.Fecha_Trn, OG.Sociedad, OG.Moneda, OG.Nombre, OG.MetodoPago, OG.Fecha_Proc_BATMD
         FROM T3.Otros_General  OG,
              T3.Otros_Detalle  OD
         WHERE OG.Fecha_Factura       > SYSDATE - NVL( pDias, 7 )
           AND OG.Factura             = OD.Factura
           AND OD.Material            = 'R900'
           AND OD.MaterialDescripcion = 'FIXED ASSET - External Sales' ;
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(03)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
   sReference            VARCHAR2(030) ;      
BEGIN
--
   nPedidos := 0 ;
   FOR Inv IN ScrDocuments LOOP  
      sReference := Inv.Factura ;
      IF ( ( Inv.MetodoPago = 'No identificado' ) AND ( Inv.Fecha_Proc_BATMD IS NULL ) ) THEN
         nPedidos := nPedidos + 1 ;   
         UPDATE T3.Otros_General  SET MetodoPago = '03'
            WHERE Factura = Inv.Factura ;
      END IF ;   
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE       , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sReference                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ERR_INVOICE_PAYMETHOD', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_INVOICE_PAYMETHOD ;