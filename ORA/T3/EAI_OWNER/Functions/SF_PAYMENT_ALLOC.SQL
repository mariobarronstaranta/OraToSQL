create or replace FUNCTION           SF_PAYMENT_ALLOC
  ( pIdocNumber IN VARCHAR2 )
RETURN VARCHAR2 IS
   sReturn         VARCHAR2(04) ;
   sAccntDocNumber VARCHAR2(99) ;
   sFiscalYear     VARCHAR2(04) ;
   nLinea0         NUMBER  ;
--   
   CURSOR ScrAllocation IS
       SELECT IDoc.IDocNumber, IDoc.ClearingDocNumber, IDoc.Processed, IDoc.Status
                   FROM (
                          SELECT IDoc.IDocNumber, IDoc.ClearingDocNumber, IDoc.FiscalYear
                             FROM EAI_Owner.tmp_Account_Header IDoc
                             WHERE IDoc.IDocNumber = pIdocNumber                  
                        )  CC,
                        EAI_Owner.tmp_Account_Header IDoc
                   WHERE IDoc.ClearingDocNumber  = CC.ClearingDocNumber
                     AND IDoc.FiscalYear         = CC.FiscalYear
                     AND IDoc.DC_Indicator       = 'S'
                     AND IDoc.IDocNumber        != CC.IDocNumber ;
BEGIN
   sReturn := 'YES' ;
   FOR Alloc in ScrAllocation LOOP
      IF ( Alloc.Processed IS NOT NULL ) THEN
         sReturn := 'NO' ;
      END IF ;     
   END LOOP ;   
   RETURN sReturn  ;
EXCEPTION
   WHEN OTHERS THEN
      RETURN ( 'NO' ) ;   
END SF_PAYMENT_ALLOC ;