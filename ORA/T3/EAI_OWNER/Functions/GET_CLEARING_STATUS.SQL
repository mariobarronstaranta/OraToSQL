create or replace FUNCTION           "GET_CLEARING_STATUS" 
  ( pInvoice    IN VARCHAR2,
    pCreditNote IN VARCHAR2,
    pAmount     IN NUMBER  )
RETURN VARCHAR2 IS
   sReturn      VARCHAR2(50) ;
   sInvoice     VARCHAR2(50) ;
   sCreditNote  VARCHAR2(50) ;
   nAmount      NUMBER(15,2) ;
   nInvoiceAmt  NUMBER(15,2) ;
   nCreditAmt   NUMBER(15,2) ;
   nAllocAmt    NUMBER(15,2) ;
--    
   CURSOR ScrAllocation IS
       SELECT SUM( NVL( Cobza.Importe, 0 ) )                                                               AS Amount_Inv,
              SUM( DECODE( NVL( Cobza.Nota_Credito, 'EMPTY' ), sCreditNote, NVL( Cobza.Importe, 0 ), 0 ) ) AS Amount_CN
          FROM T3.CFDI_Cobranza Cobza
          WHERE Cobza.Factura = sInvoice ;
--
   CURSOR ScrCreditMemo IS
       SELECT SUM( NVL( Cobza.Importe, 0 ) )                                                               AS Amount_CN
          FROM T3.CFDI_Cobranza Cobza
          WHERE Cobza.Nota_Credito = sCreditNote ;
BEGIN
   sReturn      := '' ;
   sInvoice     := NVL( pInvoice   , 'NONE' ) ;
   sCreditNote  := NVL( pCreditNote, 'NONE' ) ;
   IF ( LENGTH( sCreditNote ) < 3 ) THEN
      sCreditNote := 'NONE' ;
   END IF ;
   nAmount      := NVL( pAmount    , 0      ) ;
   nInvoiceAmt  := 0 ;
   nCreditAmt   := 0 ;
   nAllocAmt    := 0 ;
--
   FOR Doc IN ScrAllocation LOOP
      nInvoiceAmt := NVL( Doc.Amount_Inv, 0 ) ;
      nCreditAmt  := NVL( Doc.Amount_CN , 0 ) ;
   END LOOP ;
   IF ( ( nAmount > 0 ) AND ( nInvoiceAmt > 0 ) ) THEN
      IF    ( ( ABS( nAmount - nInvoiceAmt ) < 0.50 ) AND ( sCreditNote = 'NONE' ) ) THEN 
          sReturn := 'Comp-Ok' ;
      ELSIF ( ( ABS( nAmount - nInvoiceAmt ) < 0.50 ) AND ( ABS( nCreditAmt - nInvoiceAmt ) < 0.50 ) ) THEN     
          sReturn := 'Comp-Inv-ZLOB' ;
      ELSIF ( sCreditNote != 'NONE' ) THEN
         FOR Doc IN ScrCreditMemo LOOP
            nCreditAmt  := NVL( Doc.Amount_CN , 0 ) ;
         END LOOP ;
         IF    ( ( ABS( nAmount - nInvoiceAmt ) < 0.50 ) AND ( ABS( nAmount - nCreditAmt ) < 0.50 ) ) THEN
            sReturn := 'Inv-Ok-ZLOB-Ok' ;
         ELSIF ( ( ABS( nAmount - nCreditAmt  ) < 0.50 ) ) THEN   
            sReturn := 'ZLOB-Ok' ;
         ELSIF ( ( ABS( nAmount - nInvoiceAmt ) < 0.50 ) ) THEN   
            sReturn := 'Inv-Ok' ;
         END IF ;
      END IF ;   
   END IF ;

   RETURN sReturn   ;
--
END GET_CLEARING_STATUS ;