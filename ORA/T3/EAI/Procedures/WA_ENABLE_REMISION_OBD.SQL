create or replace PROCEDURE    "WA_ENABLE_REMISION_OBD" 
   ( sCustomerSAP     IN VARCHAR2 )
IS
   nDoctos    NUMBER(6)      ;
   sCustomer  VARCHAR2(20)   ;
   dtFecha    DATE           ;
   dtFactura  DATE           ;
   sMsg       VARCHAR2(0500) ;
--   
   CURSOR CFGSett IS
       SELECT CFG.Source AS Cliente_SAP
       FROM EAI_Owner.MX_Hashtable CFG
       WHERE CFG.Type   = 'Genera Remision'
         AND CFG.Source = sCustomer ;
--
   CURSOR ScrCC IS
      SELECT Cliente_SAP 
         FROM EAI_Owner.WA_VENTA_CENTRALIZADA
         WHERE Cliente_SAP = sCustomer ;
--
   CURSOR ScrRemision IS
      SELECT PG.Factura, PG.Entrega, RG.Fecha_Trn
         FROM T3.Preventa_General PG, T3.Remision_General RG
         WHERE PG.Cliente_SAP    = sCustomer
           AND PG.Fecha_Factura >= TRUNC( SYSDATE )
           AND PG.Entrega        = RG.Factura(+) ;   
BEGIN
   sCustomer := LPAD( sCustomerSAP, 10, '0' ) ;
   nDoctos := 0 ;
   FOR Doc IN CFGSett LOOP
      nDoctos := nDoctos + 1 ;
   END LOOP ;
   IF ( nDoctos = 0 ) THEN
      INSERT INTO EAI_Owner.MX_Hashtable ( Type, Source, Target )
         VALUES ( 'Genera Remision', sCustomer, 'OBD' ) ;
      INSERT INTO EAI_Owner.WA_Logging
                   ( Fecha, Usuario, Usuario_Red, IP, Terminal, Documento, Comentario )
                VALUES
                   ( SYSDATE , USER, 
                     SYS_CONTEXT( 'USERENV' , 'OS_USER'    ), 
                     SYS_CONTEXT( 'USERENV' , 'IP_ADDRESS' ),
                     SYS_CONTEXT( 'USERENV' , 'HOST'       ),
                     sCustomer, 'WA_ENABLING_OBD' ) ;          
   END IF ;
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sMsg := SUBSTR( 'ERROR ORACLE ' || TO_CHAR( SQLCODE ) || ' ' || SQLERRM, 1, 480 ) ;
      DBMS_OUTPUT.PUT_LINE( '************* Mensaje *******************' ) ;
      DBMS_OUTPUT.PUT_LINE( '***  Error en WA_ENABLE_REMISION_OBD  ***' ) ;
      DBMS_OUTPUT.PUT_LINE( sMsg ) ;         
END ; -- Procedure