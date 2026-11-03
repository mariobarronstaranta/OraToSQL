create or replace FUNCTION      "FN_NUM_TO_CHAR_CFDI" 
   ( pValue     IN  NUMBER,
     pDecimals  IN  NUMBER DEFAULT 0 )
RETURN VARCHAR2
IS
--
    rParameter         VARCHAR2(200) ;
    sMask              VARCHAR2(030) ;
    nDecimals          NUMBER        ;
BEGIN
   sMask     := '99999999999990' ;
   nDecimals := pDecimals   ;
   IF ( NVL( pValue, 0 ) != TRUNC( NVL( pValue, 0 ), 0 ) ) THEN
      nDecimals := 2 ;
      IF ( nDecimals < NVL( pDecimals, 0 ) ) THEN
         nDecimals := pDecimals   ;
      END IF ;
   END IF ;
   IF ( NVL( nDecimals, 0 ) > 0 ) THEN
      sMask := sMask || '.' || LPAD( '9', nDecimals, '9' ) ;
   END IF ;
   rParameter := TRIM( TO_CHAR( NVL( pValue, 0 ), sMask ) ) ;
   RETURN rParameter ;
END FN_NUM_TO_CHAR_CFDI ;