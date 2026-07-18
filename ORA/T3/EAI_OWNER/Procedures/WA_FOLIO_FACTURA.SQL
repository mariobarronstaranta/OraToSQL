create or replace PROCEDURE           WA_FOLIO_FACTURA
   ( pFolioSAP      IN   VARCHAR2,
     pCentro        IN   VARCHAR2,
     pClaseFactura  IN   VARCHAR2,
     dtFechaFactura IN   DATE,
     nOutput        IN   NUMBER,
     sFolioT3       OUT  VARCHAR )
IS
   sMsg            VARCHAR2(500) ;   
   sRow_ID         VARCHAR2(020) ;
   sErrorCode      VARCHAR2(020) ;
   nFolio          NUMBER(02)    ;
   sCalcular       VARCHAR2(030) ;
   sMes            VARCHAR2(030) ;
   sCentro         VARCHAR2(004) ;
--
   CURSOR ScrExiste IS
      SELECT FacturaT3
         FROM EAI_Owner.MX_NRIV_RELACION 
         WHERE FacturaSAP    = pFolioSAP 
           AND Clase_Factura = pClaseFactura ;
--
   CURSOR ScrNRIV IS
      SELECT Centro, Clase_Factura, Serie_Par, Folio_Par, Serie_Non, Folio_Non
      FROM EAI_Owner.MX_NRIV
      WHERE Centro        = sCentro
        AND Clase_Factura = pClaseFactura ;   
BEGIN
   sRow_ID   := pFolioSAP ;
   sCalcular := 'NO' ;
   nFolio    :=  00  ;
   IF ( pClaseFactura IN ( 'C005', 'C006' ) ) THEN                              -- Preventa
      sCalcular := 'SI'    ;
      sCentro   := pCentro ;
   ELSIF ( pClaseFactura IN ( 'C0FX', 'C019' ) ) THEN                           -- Gastos Admtvos / Bonificacion
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura IN ( 'C025' ) ) THEN                                   -- Rebates
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura IN ( 'C030', 'C031' ) ) THEN                           -- Cargos y Creditos al Rep por Ajuste de Inventario
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura IN ( 'C020', 'C021', 'C022' ) ) THEN                   -- Intercompany
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura = 'DN'   ) THEN                                        -- DebitNote to V3
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura = 'SUBD' ) THEN                                        -- Traslados a Subdepositos
      sCalcular := 'SI'   ;
      sCentro   := 'MX99' ;
   ELSIF ( pClaseFactura = 'REM'  ) THEN                                        -- Remision
      sCalcular := 'SI'    ;
      sCentro   := pCentro ;
   ELSIF ( pClaseFactura = 'INVT' ) THEN                                        -- Traslado de Factura
      sCalcular := 'SI'    ;
      sCentro   := pCentro ;
   END IF ;
--
   IF ( sCalcular = 'SI' ) THEN
      IF ( TO_CHAR( dtFechaFactura, 'MM' ) IN ( '01', '03', '05', '07', '09', '11' ) ) THEN
         sMes := 'Non' ;         
      ELSE
         sMes := 'Par' ;
      END IF ;   
   -- En caso de ser DN ( Debit Note ) solo aplica una serie de folio
      IF ( pClaseFactura = 'DN' ) THEN
         sMes := 'Non' ; 
      END IF ;
   -- En caso de ser SUBD ( Subdepositos ) solo aplica una serie de folio
      IF ( pClaseFactura = 'SUBD' ) THEN
         sMes := 'Non' ; 
      END IF ;
   -- En caso de ser C025 ( Charolas ) solo aplica una serie de folio
      IF ( pClaseFactura = 'C025' ) THEN
         sMes := 'Non' ; 
      END IF ;
   -- En caso de ser REM ( Traslados ) solo aplica una serie de folio
      IF ( pClaseFactura = 'REM' ) THEN
         sMes := 'Non' ; 
      END IF ;
   -- En caso de ser INVT ( Traslado de Factura ) solo aplica una serie de folio
      IF ( pClaseFactura = 'INVT' ) THEN
         sMes := 'Non' ; 
      END IF ;
      FOR Doc IN ScrExiste LOOP
         nFolio   := nFolio + 1    ;
         sFolioT3 := Doc.FacturaT3 ;
      END LOOP ;
-- En caso de no existir, se detrermina la nueva vigencia
      IF ( nFolio = 0 ) THEN
         FOR NRIV IN ScrNRIV LOOP
            nFolio := nFolio + 1 ;
            IF ( sMes = 'Non' ) THEN
               sFolioT3 := NRIV.Serie_Non || '-' || LPAD( NRIV.Folio_Non, 6, '0' ) ;
               UPDATE EAI_Owner.MX_NRIV SET Folio_Non = Folio_Non + 1
                  WHERE Centro        = sCentro
                    AND Clase_Factura = pClaseFactura ;
            ELSE   
               sFolioT3 := NRIV.Serie_Par || '-' || LPAD( NRIV.Folio_Par, 6, '0' ) ;
               UPDATE EAI_Owner.MX_NRIV SET Folio_Par = Folio_Par + 1
                  WHERE Centro        = sCentro
                    AND Clase_Factura = pClaseFactura ;
            END IF ;
            INSERT INTO EAI_Owner.MX_NRIV_RELACION ( FacturaSAP, FacturaT3, Clase_Factura )
               VALUES ( pFolioSAP, sFolioT3, pClaseFactura ) ;
         END LOOP ;
         IF ( nFolio = 0 ) THEN                                                 -- No hay rango en NRIV
            sFolioT3 := pFolioSAP ;
            INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
              ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
	              STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	              SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
            VALUES 
              ( 'FolioFactura'     , sCentro || '/' || pClaseFactura, SYSDATE, NULL        ,
                'Error'            , 'Folio Interno', NULL                , 'PL/SQL'       ,
                'No hay NRIV'      , NULL           , NULL                , NULL            ) ;            
         END IF ;
      END IF ;
--      
      IF ( nOutput > 0 ) THEN
         DBMS_Output.Put_Line( 'FacturaSAP   => ' || pFolioSAP ) ;
         DBMS_Output.Put_Line( 'FacturaT3    => ' || sFolioT3  ) ;
      END IF ;   
    ELSE
       sFolioT3 := pFolioSAP ;
    END IF ;   
--   
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'FolioFactura'     , sRow_ID        , SYSDATE             , NULL           ,
          'Error'            , 'Folio Interno', sMsg                , 'WA'           ,
          sErrorCode         , NULL           , NULL                , NULL            ) ;
      COMMIT ;
END WA_FOLIO_FACTURA ;