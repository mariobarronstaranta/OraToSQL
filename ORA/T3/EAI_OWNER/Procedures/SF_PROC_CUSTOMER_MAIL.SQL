create or replace PROCEDURE           SF_PROC_CUSTOMER_MAIL( sCliente_SAP VARCHAR2, sMail VARCHAR2 ) IS
   v_ID        VARCHAR2(030) ;
   sRFC        VARCHAR2(040) ;
   sErrorCode  VARCHAR2(500) ;
   sMsg        VARCHAR2(500) ;
   sProcesar   VARCHAR2(004) ;
   sCtro       VARCHAR2(004) ; 
   sFullName   VARCHAR2(100) ;
   nRecords    NUMBER(03)    ;
   CURSOR ScrData IS
      SELECT Creado, Creado_Por, NVL( Cliente_SAP, 'INSERT' ) AS Cliente_SAP, Email
      FROM T3.TMD_Email
      WHERE Cliente_SAP = sCliente_SAP ;
BEGIN
   v_ID      := sCliente_SAP ;
   nRecords  := 0            ;
   sProcesar := 'YES'        ;
   FOR Rec IN ScrData LOOP 
      nRecords  := nRecords + 1 ;
      sProcesar := 'NO' ;
   END LOOP ;
   IF ( sMail = 'contact@bat.com.mx' ) THEN
      sProcesar := 'NO' ;
   END IF ;
   IF ( LENGTH( NVL( sMail, 'NULL' ) ) <= 5 ) THEN
      sProcesar := 'NO' ;
   END IF ;
   IF ( LENGTH( NVL( sCliente_SAP, 'NULL' ) ) <= 5 ) THEN
      sProcesar := 'NO' ;
   END IF ;
   IF ( sProcesar != 'NO' ) THEN
     INSERT INTO T3.TMD_Email
        ( Creado, Creado_Por, Cliente_SAP, Email )
     VALUES
        ( SYSDATE, 'INTERFACE', sCliente_SAP, sMail ) ;
   END IF ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                     , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME             , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT            , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Receive'          , v_ID                   , SYSDATE             , NULL           ,
          'Error'            , 'SF_PROC_CUSTOMER_MAIL', sMsg                , 'XML'          ,
          sErrorCode         , NULL                   , NULL                , NULL            ) ;
      COMMIT ;
END SF_PROC_CUSTOMER_MAIL ;