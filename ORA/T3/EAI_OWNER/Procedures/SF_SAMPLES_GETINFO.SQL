create or replace PROCEDURE           SF_SAMPLES_GETINFO
   ( pInvoiceRef   IN   VARCHAR2,
     pCreditRef    IN   VARCHAR2 )
IS
   sInvDoc_Num     VARCHAR2(30) ;
   sInvCliente     VARCHAR2(30) ;
   nInvAmount      NUMBER(13,2) ;
   nInvPending     NUMBER(13,2) ;
   nInvPaid        NUMBER(13,2) ;
   sCredDoc_Num    VARCHAR2(30) ;
   sCredCliente    VARCHAR2(30) ;
   nCredAmount     NUMBER(13,2) ;
   nCredPending    NUMBER(13,2) ;
   nCredPaid       NUMBER(13,2) ;
   sCustomer_TMD   VARCHAR2(30) ;
   sCtro           VARCHAR2(30) ;
   nDistributor    NUMBER(04)   ;
   sRep_ID         VARCHAR2(30) ;
   sCustomer_Name  VARCHAR2(1024);
BEGIN
   EAI_OWNER.SF_GET_INVOICE_DATA( pInvoiceRef, sInvDoc_Num , sInvCliente , nInvAmount , nInvPending, nInvPaid  ) ;
   EAI_OWNER.SF_GET_CUSTOMER_DATA( sInvCliente, TRUNC(SYSDATE), sCustomer_TMD, sCtro, nDistributor, sRep_ID, sCustomer_Name ) ;
   DBMS_Output.Put_Line( 'Invoice  => ' || sInvDoc_Num   ) ;
   DBMS_Output.Put_Line( 'Reference=> ' || pInvoiceRef   ) ;
   DBMS_Output.Put_Line( 'Cliente  => ' || sInvCliente   ) ;
   DBMS_Output.Put_Line( 'Amount   => ' || nInvAmount    ) ;
   DBMS_Output.Put_Line( 'Pending  => ' || nInvPending   ) ;
   DBMS_Output.Put_Line( 'Cust V3  => ' || sCustomer_TMD ) ;
   DBMS_Output.Put_Line( 'Ctro     => ' || sCtro         ) ;
   DBMS_Output.Put_Line( 'Dist     => ' || nDistributor  ) ;
   DBMS_Output.Put_Line( '----------------------------' ) ;
   IF ( LENGTH( NVL( pCreditRef, 'NULL' ) ) > 5 ) THEN
      EAI_OWNER.SF_GET_CREDIT_DATA(   pCreditRef, sCredDoc_Num, sCredCliente, nCredAmount, nCredPending, nCredPaid ) ;
      EAI_OWNER.SF_GET_CUSTOMER_DATA( sCredCliente, TRUNC(SYSDATE), sCustomer_TMD, sCtro, nDistributor, sRep_ID, sCustomer_Name ) ;
      DBMS_Output.Put_Line( 'Credit   => ' || sCredDoc_Num ) ;
      DBMS_Output.Put_Line( 'Reference=> ' || pCreditRef ) ;
      DBMS_Output.Put_Line( 'Cliente  => ' || sCredCliente ) ;
      DBMS_Output.Put_Line( 'Amount   => ' || nCredAmount  ) ;
      DBMS_Output.Put_Line( 'Pending  => ' || nCredPending ) ;
      DBMS_Output.Put_Line( 'Cust V3  => ' || sCustomer_TMD ) ;
      DBMS_Output.Put_Line( 'Ctro     => ' || sCtro         ) ;
      DBMS_Output.Put_Line( 'Dist     => ' || nDistributor  ) ;
   END IF ;   
END ;