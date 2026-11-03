create or replace PROCEDURE    GET_SAT_CLAVEPRODUCTO
   ( pInvoiceType  IN   VARCHAR2,
     pInvoice      IN   VARCHAR2,
     pMaterial     IN   VARCHAR2,
     pDescription  IN   VARCHAR2,
     pUnitMeasure  IN   VARCHAR2,
     rtIdProdServ  OUT  VARCHAR2,
     rtUnitMeasure OUT  VARCHAR2 )
IS
   sMsg            VARCHAR2(500) ;
   sErrorCode      VARCHAR2(500) ;
   v_ID            VARCHAR2(030) ;
   sCtro           VARCHAR2(030) ;
   sMaterial       VARCHAR2(030) ;
   nCtro           NUMBER(2) ;
--
   CURSOR ScrSATInfo IS
       SELECT SAT_Clave, SAT_UnidadMedida
          FROM T3.CFDI_PRODSERV
          WHERE Material = sMaterial ;
BEGIN
   v_ID      := pInvoice ;
   nCtro     := 0 ;
   sMaterial := REPLACE( pMaterial, '.', '' ) ;
   FOR Mat IN ScrSATInfo LOOP
         nCtro         := nCtro + 1            ;
         rtIdProdServ  := Mat.SAT_Clave        ;
         rtUnitMeasure := Mat.SAT_UnidadMedida ;
   END LOOP ;
   IF ( nCtro = 0 ) THEN
      IF    ( pInvoiceType = 'Vta'  ) THEN
         rtIdProdServ  := '50211502' ;
         rtUnitMeasure := 'H87' ;
      ELSIF ( pInvoiceType = 'EXPO' ) THEN
         rtIdProdServ  := '50211502' ;
         rtUnitMeasure := 'NMP'      ;
         rtIdProdServ  := ''         ;
         rtUnitMeasure := ''         ;
      ELSIF ( pInvoiceType = 'SERV' ) THEN
         rtIdProdServ  := '50211502' ;
         rtUnitMeasure := 'NMP'      ;
      ELSE   
         rtIdProdServ  := '50211502' ;
         rtUnitMeasure := 'H87' ;
      END IF ;   
      IF ( SUBSTR( sMaterial, 1, 1 ) != 'R' ) THEN
         INSERT INTO T3.CFDI_PRODSERV ( Modulo, Material, NombreMaterial, UnidadMedida, SAT_Clave, SAT_UnidadMedida, Fecha_Creacion, Creado_Por ) 
            VALUES( pInvoiceType, sMaterial, pDescription, pUnitMeasure, rtIdProdServ, rtUnitMeasure, SYSDATE, 'INVOICING' ) ;
      END IF ;      
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      rtIdProdServ  := ''    ;
      rtUnitMeasure := ''    ;
      sErrorCode  := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
	        STATUS             , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
	        SIEBEL_ERROR_CODE  , RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'CFDI Mapping'     , v_ID                   , SYSDATE             , NULL           ,
          'Error'            , 'GET_SAT_CLAVEPRODUCTO', sMsg                , 'CFD'          ,
          sErrorCode         , NULL                   , NULL                , NULL            ) ;
      COMMIT ;
END GET_SAT_CLAVEPRODUCTO ;