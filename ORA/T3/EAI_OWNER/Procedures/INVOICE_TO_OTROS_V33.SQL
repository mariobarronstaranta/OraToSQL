create or replace PROCEDURE           INVOICE_TO_OTROS_V33
   ( sInvoiceID   IN   VARCHAR2)
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   nItems          NUMBER(06)    ;
   nUpdated        NUMBER(06)    ;
--
   CURSOR ScrSociedad IS
       SELECT OD.Factura, OD.Num_Linea, OD.Material, OD.MaterialDescripcion, OD.Leyenda_EN, OD.Leyenda_ES,
              SAT.NombreMaterial     AS SAT_NombreMaterial,
              SAT.SAT_Clave          AS SAT_Clave         ,
              SAT.SAT_UnidadMedida   AS SAT_UnidadMedida  
       FROM T3.Otros_General     OG ,
            T3.Otros_Detalle     OD ,
            T3.CFDI_PRODSERV_WA  SAT
       WHERE OG.Factura     = sInvoiceID
         AND OG.Factura     = OD.Factura
         AND OG.Sociedad    = SAT.Sociedad 
         AND OD.Material    = SAT.Material
         AND OD.SAT_ProdID IS NULL 
         AND ( ( UPPER( OD.MaterialDescripcion ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' )
            OR ( UPPER( OD.Leyenda_EN          ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' )
            OR ( UPPER( OD.Leyenda_ES          ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' ) 
            OR ( UPPER( OD.MaterialDescripcion ) = UPPER( NVL( SAT.NombreMaterial, OD.MaterialDescripcion  ) ) ) ) ;
--
   CURSOR ScrGeneral IS
       SELECT OD.Factura, OD.Num_Linea, OD.Material, OD.MaterialDescripcion, OD.Leyenda_EN, OD.Leyenda_ES,
              SAT.NombreMaterial     AS SAT_NombreMaterial,
              SAT.SAT_Clave          AS SAT_Clave         ,
              SAT.SAT_UnidadMedida   AS SAT_UnidadMedida  
       FROM T3.Otros_General     OG ,
            T3.Otros_Detalle     OD ,
            T3.CFDI_PRODSERV_WA  SAT
       WHERE OG.Factura     = sInvoiceID
         AND OG.Factura     = OD.Factura
         AND SAT.Sociedad  IS NULL
         AND OD.Material    = SAT.Material
         AND OD.SAT_ProdID IS NULL 
         AND ( ( UPPER( OD.MaterialDescripcion ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' )
            OR ( UPPER( OD.Leyenda_EN          ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' )
            OR ( UPPER( OD.Leyenda_ES          ) LIKE '%' || UPPER( NVL( SAT.NombreMaterial, 'NULL' ) ) || '%' ) 
            OR ( UPPER( OD.MaterialDescripcion ) = UPPER( NVL( SAT.NombreMaterial, OD.MaterialDescripcion  ) ) ) ) ;
--
   CURSOR ScrDetalle IS
       SELECT OD.Factura, OD.Num_Linea, OD.Material, OD.MaterialDescripcion, 
              SAT.NombreMaterial     AS SAT_NombreMaterial,
              SAT.SAT_Clave          AS SAT_Clave         ,
              SAT.SAT_UnidadMedida   AS SAT_UnidadMedida  ,
              SAT.Fecha_Creacion
       FROM T3.Otros_Detalle  OD,
            T3.CFDI_PRODSERV  SAT
       WHERE OD.Factura     = sInvoiceID
         AND OD.Material    = SAT.Material(+) 
         AND OD.SAT_ProdID IS NULL ;
BEGIN
   v_ID      := sInvoiceID ;
   nItems    := 0 ;
   nUpdated  := 0 ;
   FOR Doc IN ScrSociedad LOOP
      nItems := nItems + 1 ;
      IF ( LENGTH( NVL( Doc.SAT_Clave, '' ) ) > 4 ) THEN
         nUpdated := nUpdated + 1 ;
         UPDATE T3.Otros_Detalle SET SAT_ProdID = Doc.SAT_Clave       ,
                                     SAT_UM     = Doc.SAT_UnidadMedida
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
      END IF ;
   END LOOP ;
--
   FOR Doc IN ScrGeneral LOOP
      nItems := nItems + 1 ;
      IF ( LENGTH( NVL( Doc.SAT_Clave, '' ) ) > 4 ) THEN
         nUpdated := nUpdated + 1 ;
         UPDATE T3.Otros_Detalle SET SAT_ProdID = Doc.SAT_Clave       ,
                                     SAT_UM     = Doc.SAT_UnidadMedida
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
      END IF ;
   END LOOP ;
--
   FOR Doc IN ScrDetalle LOOP
      nItems := nItems + 1 ;
      IF ( LENGTH( NVL( Doc.SAT_Clave, '' ) ) > 4 ) THEN
         nUpdated := nUpdated + 1 ;
         UPDATE T3.Otros_Detalle SET SAT_ProdID = Doc.SAT_Clave       ,
                                     SAT_UM     = Doc.SAT_UnidadMedida
            WHERE Factura   = Doc.Factura
              AND Num_Linea = Doc.Num_Linea
              AND Material  = Doc.Material ;
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
        ( 'Sending to T3 V33', v_ID           , SYSDATE             , NULL           ,
          'Error'            , 'Invoice to T3', sMsg                , 'XML'          ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END INVOICE_TO_OTROS_V33 ;