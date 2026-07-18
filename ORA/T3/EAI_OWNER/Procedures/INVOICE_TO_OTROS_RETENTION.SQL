create or replace PROCEDURE           INVOICE_TO_OTROS_RETENTION
   ( sInvoiceID   IN   VARCHAR2)
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   nItems          NUMBER(06)    ;
   nUpdated        NUMBER(06)    ;
   sRetCode        VARCHAR2(030) ;
   sRetDesc        VARCHAR2(030) ;
   sBillInfo       VARCHAR2(030) ;
   nRetRate        NUMBER(06,2)  ;
--
   CURSOR ScrDetalle IS
       SELECT OD.Factura, OD.Num_Linea, OD.Material,
              OG.Sociedad || '-' || OG.RFC AS BillInfo,
              CASE
                 WHEN ( INSTR( UPPER( NVL( OD.Leyenda_ES, NVL( OD.Leyenda_EN, OD.MaterialDescripcion ) ) ), UPPER( SAT.DESCRIPCION ) ) > 0 ) THEN 'YES'
                 ELSE
                     'NO'
              END                            AS Retencion       ,
             SAT.SAT_CLAVE                   AS SAT_CLAVE       ,
             SAT.SAT_UNIDADMEDIDA            AS SAT_UNIDADMEDIDA,
             NVL( SAT.RETENCION_TASA, 0 )    AS RETENCION_TASA
       FROM T3.Otros_Detalle                    OD ,
            EAI_OWNER.OTROS_PRODSERV_RETENTION  SAT,
            T3.Otros_General                    OG
       WHERE OD.Factura  = sInvoiceID 
         AND OD.Factura  = OG.Factura
         AND OD.Material = SAT.MATERIAL(+) ;
BEGIN
   v_ID      := sInvoiceID ;
   SELECT 
          EAI_Owner.getConv( 'CFG Settings', 'RetentionVAT-Code'        ) AS VAT_Code,
          EAI_Owner.getConv( 'CFG Settings', 'RetentionVAT-Description' ) AS VAT_Desc,
          EAI_Owner.getConv( 'CFG Settings', 'RetentionVAT-Rate'        ) AS VAT_Rate,
          EAI_Owner.getConv( 'CFG Settings', 'RetentionVAT-CompanyCode' ) || '-' ||
          EAI_Owner.getConv( 'CFG Settings', 'RetentionVAT-TaxID'       ) AS BillInfo
      INTO sRetCode, sRetDesc, nRetRate, sBillInfo
      FROM DUAL ;
   FOR Doc IN ScrDetalle LOOP
      nItems := nItems + 1 ;
      IF ( Doc.SAT_CLAVE IS NOT NULL ) THEN
         UPDATE T3.Otros_Detalle SET SAT_ProdID = Doc.SAT_CLAVE       ,
                                     SAT_UM     = Doc.SAT_UNIDADMEDIDA
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
      END IF ;
      IF ( Doc.Retencion != 'NO' ) THEN
         nUpdated := nUpdated + 1 ;
         UPDATE T3.Otros_Detalle SET Retencion_IVA = ROUND( Valor_Subt * Doc.RETENCION_TASA / 100, 2 )
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
         UPDATE T3.Otros_General OG SET Retencion_IVA = ( SELECT SUM( NVL( OD.Retencion_IVA, 0 ) ) FROM T3.Otros_Detalle OD WHERE OD.Factura = sInvoiceID )
            WHERE OG.Factura = sInvoiceID ;
      END IF ;
      IF ( ( Doc.Material = sRetCode ) AND ( Doc.BillInfo = sBillInfo ) ) THEN
         nUpdated := nUpdated + 1 ;
         UPDATE T3.Otros_Detalle SET Retencion_IVA = ROUND( Valor_Subt * nRetRate / 100, 2 )
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
         UPDATE T3.Otros_General OG SET Retencion_IVA = ( SELECT SUM( NVL( OD.Retencion_IVA, 0 ) ) FROM T3.Otros_Detalle OD WHERE OD.Factura = sInvoiceID )
            WHERE OG.Factura = sInvoiceID ;
      END IF ;
   END LOOP ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Retention VAT'    , v_ID           , SYSDATE             , NULL           ,
          'Error'            , 'Invoice to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_TO_OTROS_RETENTION ;