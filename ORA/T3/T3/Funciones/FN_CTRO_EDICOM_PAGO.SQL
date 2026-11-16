--------------------------------------------------------
--  DDL for Function FN_CTRO_EDICOM_PAGO
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "T3"."FN_CTRO_EDICOM_PAGO" 
   ( sAccnt_ID VARCHAR2 )  RETURN  VARCHAR2
IS
   sCtro_EDICOM   VARCHAR2(020) ;
   sCustomerSAP   VARCHAR2(020) ;
   nRecords       NUMBER(3)     ;
--
   CURSOR ScrPagos IS
       SELECT HO.Customer                           AS Customer_SAP      ,
              HO.Ctro_Cobza                         AS Centro_Cobza      ,
              NVL( HO.Ctro_EDICOM, '' )             AS Visibilidad_EDICOM
       FROM EAI_Owner.MX_Head_Office  HO
       WHERE HO.Customer = sAccnt_ID;
--
   CURSOR ScrCobzaLocal IS
       SELECT MAX( Ctro ) AS Ctro
          FROM T3.Mov_Cliente
          WHERE Cliente_SAP = sAccnt_ID  ;        
--
   CURSOR ScrCobzaLocal_Ant IS
       SELECT MAX( SUBSTR( Territorio_Delivery, 6, 4 ) ) AS Ctro
          FROM EAI.Cliente_Siebel
          WHERE Cliente_SAP = sAccnt_ID  ;                  
BEGIN
   sCtro_EDICOM := 'MXAB' ;
   nRecords     := 0      ;
   FOR Doc IN ScrPagos LOOP
      nRecords     := nRecords + 1 ;
      sCustomerSAP := Doc.Customer_SAP ;
      IF ( Doc.Customer_SAP = '0000000000' ) THEN
         FOR Vta IN ScrCobzaLocal LOOP
            sCtro_EDICOM := Vta.Ctro ;
         END LOOP ;
      ELSIF ( LENGTH( Doc.Visibilidad_EDICOM ) >= 4 ) THEN
         sCtro_EDICOM := Doc.Visibilidad_EDICOM ;
      END IF ;
   END LOOP ;   
   IF ( nRecords = 0 ) THEN
         FOR Vta IN ScrCobzaLocal LOOP
            sCtro_EDICOM := Vta.Ctro ;
         END LOOP ;
   END IF ;
   RETURN ( sCtro_EDICOM ) ;
EXCEPTION
   WHEN OTHERS THEN
     RETURN ( sCtro_EDICOM ) ;
END FN_CTRO_EDICOM_PAGO ;

/

  GRANT EXECUTE ON "T3"."FN_CTRO_EDICOM_PAGO" TO "EAI_OWNER";
  GRANT EXECUTE ON "T3"."FN_CTRO_EDICOM_PAGO" TO "INTEGRATION_ROLE";
  GRANT EXECUTE ON "T3"."FN_CTRO_EDICOM_PAGO" TO "EAI";
  GRANT EXECUTE ON "T3"."FN_CTRO_EDICOM_PAGO" TO "SYSADMIN_ROLE";
  GRANT EXECUTE ON "T3"."FN_CTRO_EDICOM_PAGO" TO "ITX_DEV";
