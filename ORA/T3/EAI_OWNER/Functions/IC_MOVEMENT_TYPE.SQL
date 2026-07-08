create or replace FUNCTION           "IC_MOVEMENT_TYPE" 
  ( pClase_Docto         IN  VARCHAR2,
    pClave_Contable      IN  NUMBER  ,
    pDocto_Compensacion  IN  VARCHAR2,
    pDocumento           IN  VARCHAR2,
    pReferencia          IN  VARCHAR2
    )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(50)   ;
BEGIN
   sReturn := 'No aplica' ;
   IF    ( ( pClase_Docto = 'RV' ) AND ( pClave_Contable =  1 ) AND ( pDocto_Compensacion != pDocumento ) AND ( pReferencia IS NOT NULL ) ) THEN 
      sReturn := 'Pago Completo' ;
   ELSIF ( ( pClase_Docto = 'CR' ) AND ( pClave_Contable =  4 ) AND ( pDocto_Compensacion != pDocumento ) AND ( pReferencia IS NOT NULL ) ) THEN 
      sReturn := 'Pago Parcial'  ;
   ELSIF ( ( pClase_Docto = 'CR' ) AND ( pClave_Contable = 17 ) AND ( pReferencia IS NOT NULL ) ) THEN 
      sReturn := 'Pago Restante' ;
   END IF ;
   RETURN sReturn    ;
--
END IC_MOVEMENT_TYPE ;