--------------------------------------------------------
--  DDL for Package Body RECV_TO_SEND_V3
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "EAI_OWNER"."RECV_TO_SEND_V3" AS

PROCEDURE RECV_CUSTOMER IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   sSalesForceOn VARCHAR2(030) ;
   nPID          NUMBER(08)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'Customer'
           AND Created     > TRUNC( SYSDATE )
           AND Reference  IS NOT NULL
           AND Reference NOT LIKE 'A0A%'
           AND Processed  IS NULL ;
BEGIN
   nComponent := 401 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;
   SELECT EAI_Owner.getConv( 'CFG Settings', 'SalesForceOn' )
      INTO sSalesForceOn
      FROM DUAL ;   
   nPID      := EAI_Owner.ProcessID.NextVal ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
--        PROC_CUSTOMER( Info.Row_ID, Info.Item ) ;
          IF ( UPPER( sSalesForceOn ) = 'YES' ) THEN
             EAI_OWNER.SF_PROC_CUSTOMER( Info.Row_ID, Info.Item, nPID ) ;
          ELSE
             nRecords := nRecords + 0 ;
          END IF ;
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_CUSTOMER'     , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;   
   COMMIT ;
END RECV_CUSTOMER ;

PROCEDURE PROC_CUSTOMER( sROW_ID VARCHAR2, nROWNUM NUMBER, nPID NUMBER DEFAULT NULL ) IS
   v_ID        VARCHAR2(030) ;
   sErrorCode  VARCHAR2(500) ;
   sMsg        VARCHAR2(500) ;
   sProcesar   VARCHAR2(002) ;
   sCtro       VARCHAR2(004) ; 
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/Customer/Message/GeneralData/V3CustomerNumber') AS V3Customer   ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/CustomerNumber')   AS SAPCustomer  ,
            extractValue( XML_Content, '/Customer/Message/GeneralData/IntegrationID')    AS IntegrationID,
            extractValue( XML_Content, '/Customer/Message/GeneralData/PaymentTerms')     AS MaxCreditDays
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;    
BEGIN
   FOR Rec IN ScrData LOOP 
      v_ID      := Rec.V3Customer ;
      sProcesar := 'SI'           ;
      SELECT MAX( NVL( Ctro, 'MX1A' ) ) AS Ctro  INTO  sCtro
         FROM T3.Mov_Cliente 
         WHERE Cliente_V3 = v_ID ;
      IF ( ( sCtro IS NULL ) OR ( LENGTH( sCtro ) = 0 ) ) THEN   
         sCtro := 'MX1A' ;
      END IF ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
      END IF ;
      IF ( sProcesar = 'SI' ) THEN
         INSERT INTO EAI_OWNER.MX_SEND_MESSAGE_LOG 
            ( Row_ID, Created, Queue_Name, Reference, Ctro, XML_Content )
         SELECT
               sROW_ID, SYSDATE, 'TaO Customer Inbound', v_ID, sCtro,
                XMLElement( "xnsp1:ListOfBatCustomerInboundIo",
                   XMLAttributes( 'http://www.siebel.com/xml/BAT%20Customer%20Inbound%20IO' AS "xmlns:xnsp1"),       
                   XMLElement( "xnsp1:Account",
                       XMLAttributes( '' AS "Operation"),
                       XMLElement( "xnsp1:Searchspec"           , ''                ),
                       XMLElement( "xnsp1:AccountStatus"        , ''                ),
                       XMLElement( "xnsp1:BATAllowedPayments"   , ''                ),
                       XMLElement( "xnsp1:BATCreditLimit"       , ''                ),
                       XMLElement( "xnsp1:BATEMCustField26"     , ''                ),
                       XMLElement( "xnsp1:BATEMCustField27"     , ''                ),
                       XMLElement( "xnsp1:BATEMCustField28"     , ''                ),
                       XMLElement( "xnsp1:BATEMCustField29"     , ''                ),
                       XMLElement( "xnsp1:BATEMCustField3"      , ''                ),
                       XMLElement( "xnsp1:BATEMCustField30"     , ''                ),
                       XMLElement( "xnsp1:BATGPSXCoord"         , ''                ),
                       XMLElement( "xnsp1:BATGPSYCoord"         , ''                ),
                       XMLElement( "xnsp1:BATInactiveReason"    , ''                ),
                       XMLElement( "xnsp1:BATIntDate"           , ''                ),
                       XMLElement( "xnsp1:BATInvoiceType"       , ''                ),
                       XMLElement( "xnsp1:BATMAXCreditDays"     , 
                           EAI_Owner.getConv( 'ECC_V3 Payment Terms', Rec.MaxCreditDays )
                                                                                    ),
                       XMLElement( "xnsp1:BATMAXCreditLimit"    , ''                ),
                       XMLElement( "xnsp1:BATOutletSubType"     , ''                ),
                       XMLElement( "xnsp1:BATOutletType"        , ''                ),
                       XMLElement( "xnsp1:BATOverdueInvoiceFlag", ''                ),
                       XMLElement( "xnsp1:CSN"                  , Rec.SAPCustomer   ),
                       XMLElement( "xnsp1:CentralPaymentFlag"   , ''                ),
                       XMLElement( "xnsp1:CreditDays"           , ''                ),
                       XMLElement( "xnsp1:IntegrationId"        , Rec.IntegrationID ),
                       XMLElement( "xnsp1:Location"             , Rec.V3Customer    ),
                       XMLElement( "xnsp1:Name"                 , ''                ),
                       XMLElement( "xnsp1:PriceList"            , ''                ),
                       XMLElement( "xnsp1:RuleAttribute2"       , ''                ),
                       XMLElement( "xnsp1:TaxExemptNumber"      , ''                ),
                       XMLElement( "xnsp1:TaxList"              , ''                ),  
                       XMLElement( "xnsp1:BATGraceDays"         , ''                ),  
                       XMLElement( "xnsp1:Type"                 , ''                )
                   )
               ).getClobVal() AS XML_Content
         FROM DUAL ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = Rec.V3Customer,
                                                     Processed = SYSDATE       , 
                                                     Status    = DECODE( sProcesar, 'SI', 'Processed', 'Review' )
            WHERE Row_ID = sROW_ID ;
      END IF ;   
   END LOOP ;  
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Error'
         WHERE Row_ID = sROW_ID ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        ,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Receive'          , v_ID                  , SYSDATE             , NULL           ,
          'Error'            , 'TaO Customer Inbound', sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CUSTOMER ;



PROCEDURE RECV_CREDIT IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   nPID          NUMBER(08)    ;
--   
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'Customer Credit'
           AND Created     > TRUNC( SYSDATE - 2 )
           AND Processed  IS NULL ;
BEGIN
   nComponent := 402 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   nPID      := EAI_Owner.ProcessID.NextVal ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          PROC_CREDIT( Info.Row_ID, Info.Item, nPID ) ;
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_CREDIT'       , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;   
END RECV_CREDIT ;

PROCEDURE PROC_CREDIT( sROW_ID VARCHAR2, nROWNUM NUMBER, nPID NUMBER DEFAULT NULL ) IS
   v_ID             VARCHAR2(030) ;
   sErrorCode       VARCHAR2(500) ;
   sMsg             VARCHAR2(500) ;
   sProcesar        VARCHAR2(002) ;
   nCreditLimit     NUMBER(22,4 ) ;
   nAvailableLimit  NUMBER(22,4 ) ;
   nGraceDays       NUMBER(22,4 ) ;
   sCtro            VARCHAR2(004) ; 
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/V3CustomerNumber')          AS V3Customer    ,
            extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/CustomerNumber')            AS SAPCustomer   ,
            extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/CreditData/CreditLimit')    AS CreditLimit   ,
            extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/CreditData/AvailableLimit') AS AvailableLimit,
            extractValue( XML_Content, '/CustomerCredit/Message/PartnerData/CreditData/GraceDays')      AS GraceDays -- added afterward (20150122)
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;    
BEGIN
   FOR Rec IN ScrData LOOP 
      v_ID      := Rec.V3Customer ;
      sProcesar := 'SI'           ;
      SELECT MAX( NVL( Ctro, 'MX1A' ) ) AS Ctro  INTO  sCtro
         FROM T3.Mov_Cliente 
         WHERE Cliente_V3 = v_ID ;
      IF ( ( sCtro IS NULL ) OR ( LENGTH( sCtro ) = 0 ) ) THEN   
         sCtro := 'MX1A' ;
      END IF ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'NO' ;
      END IF ;
      IF ( sProcesar = 'SI' ) THEN
         nCreditLimit    := TO_NUMBER( NVL( Rec.CreditLimit   , '0' ) ) / 100 ;
         nAvailableLimit := TO_NUMBER( NVL( Rec.AvailableLimit, '0' ) ) / 100 ;
         INSERT INTO EAI_OWNER.MX_SEND_MESSAGE_LOG
            ( Row_ID, Created, Queue_Name, Reference, Ctro, XML_Content )
         SELECT
                sROW_ID, SYSDATE, 'TaO Customer Credit Inbound', v_ID, sCtro,
                XMLElement( "xnsp1:ListOfBatCustomerCreditInboundIo",
                   XMLAttributes( 'http://www.siebel.com/xml/BAT%20Customer%20Credit%20Inbound%20IO' AS "xmlns:xnsp1"),       
                   XMLElement( "xnsp1:Account",
                       XMLAttributes( rownum AS "Operation"),
                       XMLElement( "xnsp1:Searchspec"           , ''                  ),
--                     XMLElement( "xnsp1:AvailableCredit"      , nAvailableLimit     ),
                       XMLElement( "xnsp1:AvailableCredit"      , ''                  ),
                       XMLElement( "xnsp1:BATAllowedPayments"   , ''                  ),
                       XMLElement( "xnsp1:BATAmtDue"            , ''                  ),
                       XMLElement( "xnsp1:BATCreditDays"        , ''                  ),
                       XMLElement( "xnsp1:BATCreditLimit"       , nCreditLimit        ),
                       XMLElement( "xnsp1:BATEMCustField30"     , ''                  ),
                       XMLElement( "xnsp1:BATInvoiceType"       , ''                  ),
                       XMLElement( "xnsp1:BATLicenseNumber"     , ''                  ),
                       XMLElement( "xnsp1:BATMAXCreditDays"     , ''                  ),
                       XMLElement( "xnsp1:BATMAXCreditLimit"    , nCreditLimit        ),
                       XMLElement( "xnsp1:BATOverdueInvoiceFlag", ''                  ),
                       XMLElement( "xnsp1:BadCreditFlag"        , ''                  ), 
                       XMLElement( "xnsp1:CSN"                  , Rec.SAPCustomer     ),
                       XMLElement( "xnsp1:CreditDays"           , ''                  ),
                       XMLElement( "xnsp1:IntegrationId"        , Rec.SAPCustomer     ),
                       XMLElement( "xnsp1:Location"             , Rec.V3Customer      ),
                       XMLElement( "xnsp1:Name"                 , ''                  ),
                       XMLElement( "xnsp1:PaymentType"          , ''                  ),
                       XMLElement( "xnsp1:RevenueClass"         , ''                  ),
                       XMLElement( "xnsp1:TaxExemptNumber"      , ''                  ),
                       XMLElement( "xnsp1:BATGraceDays"         , Rec.GraceDays       )
                   )
                ).getClobVal() AS XML_Content
         FROM DUAL ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = Rec.V3Customer,
                                                     Processed = SYSDATE       , 
                                                     Status = DECODE( sProcesar, 'SI', 'Processed', 'Review' )
            WHERE Row_ID = sROW_ID ;
      END IF ;  
   END LOOP ;  
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Error'
         WHERE Row_ID = sROW_ID ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                  , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_CREDIT'         , sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END PROC_CREDIT ;




PROCEDURE RECV_PRODUCT IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name = 'Product'
           AND Created     > TRUNC( SYSDATE - 10 )
           AND Processed IS NULL ;
BEGIN
   nComponent := 403 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   FOR Info IN ScrRecords LOOP
       nRecords     := nRecords + 1 ;     
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          nRecords     := nRecords + 0 ;
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
   Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   COMMIT ;
END RECV_PRODUCT ;


PROCEDURE RECV_PRICE IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name = 'TaO Price List Inbound'
           AND Processed IS NULL ;
BEGIN
   nComponent := 404 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          nRecords := nRecords + 0 ;       
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
   Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   COMMIT ;
END RECV_PRICE ;



PROCEDURE RECV_INVOICE IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;
   sSalesforceOn VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   nPID          NUMBER(08)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'Invoice'
           AND Created     > TRUNC( SYSDATE - 5 )
           AND Processed  IS NULL ;
BEGIN
   nComponent := 405 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   nPID      := EAI_Owner.ProcessID.NextVal ;
   SELECT EAI_Owner.getConv( 'CFG Settings', 'SalesForceOn' )
      INTO sSalesForceOn
      FROM DUAL ;   
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          IF ( UPPER( sSalesforceOn ) = 'YES' ) THEN
             EAI_OWNER.SF_PROC_PREINVOICE_IFC( Info.Row_ID, Info.Item, 0, nPID ) ;
          ELSE   
             nRecords := nRecords + 0 ;
          END IF ;   
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_INVOICE'      , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;   
   COMMIT ;
END RECV_INVOICE ;



PROCEDURE RECV_ORDER IS
--
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   nPID          NUMBER(08)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'OrderAcknowledge'
           AND Created     > TRUNC( SYSDATE - 2 ) 
           AND Processed  IS NULL ;
BEGIN
   nComponent := 406 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          PROC_ORDER( Info.Row_ID, Info.Item, nPID ) ;
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE           , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_ORDER'        , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                , NULL                , NULL            ) ;   
   COMMIT ;
END RECV_ORDER ;


PROCEDURE PROC_ORDER( sROW_ID VARCHAR2, nROWNUM NUMBER, nPID NUMBER DEFAULT NULL ) IS
   v_ID        VARCHAR2(030) ;
   sErrorCode  VARCHAR2(500) ;
   sMsg        VARCHAR2(500) ;
   sStatus_CD  VARCHAR2(030) ; 
   sProcesar   VARCHAR2(002) ;
   sOrderID    VARCHAR2(050) ; 
   CURSOR ScrData IS
        SELECT
            extractValue( XML_Content, '/OrderAcknowledge/Message/ReferenceData/DocumentStatus')  AS  Status_CD,
            extractValue( XML_Content, '/OrderAcknowledge/Message/ReferenceData/DocumentNumber')  AS  V3Order
        FROM EAI_Owner.MX_Receive_Message_Log
        WHERE Row_ID = sROW_ID ;    
BEGIN
   FOR Rec IN ScrData LOOP 
      v_ID      := Rec.V3Order ;
      sProcesar := 'NO'        ;
      SELECT EAI_Owner.getConv( 'ECC_V3 Order Update', Rec.Status_CD )  AS sStatus_CD  
        INTO sStatus_CD
        FROM DUAL ;
      IF ( sStatus_CD = 'Cancelled' ) THEN
         sProcesar := 'SI' ;
      ELSE   
         sProcesar := 'NA' ;
      END IF ;
      IF ( v_ID IS NULL ) THEN
         sProcesar := 'ED' ;
      END IF ;
      IF ( sProcesar = 'SI' ) THEN
         sOrderID := REPLACE( Rec.V3Order, 'MX-', '' ) ;
         INSERT INTO EAI_OWNER.MX_SEND_MESSAGE_LOG          
            ( Row_ID, Created, Queue_Name, Reference, XML_Content )
         SELECT
               sROW_ID, SYSDATE, 'TaO OrderAck Inbound', v_ID,
                XMLElement( "xsdLocal1:ListOfBatOrderAckInboundIo",
                   XMLAttributes( 'http://www.siebel.com/xml/BAT%20Order%20Ack%20Inbound%20IO' AS "xmlns:xsdLocal1"),       
                   XMLElement( "xsdLocal1:BatEaiOrderEntry-Orders",
                      XMLAttributes( '' AS "Operation"),
                      XMLElement( "xsdLocal1:Searchspec"                      , ''                   ),
                      XMLElement( "xsdLocal1:IntegrationId"                   , ''                   ),
                      XMLElement( "xsdLocal1:OrderNumber"                     , sOrderID             ), 
                      XMLElement( "xsdLocal1:RequestedShipDate"               , ''                   ),
                      XMLElement( "xsdLocal1:SourceInventoryId"               , ''                   ),  
                      XMLElement( "xsdLocal1:SourceInventoryLocIntegrationId" , ''                   ),
                      XMLElement( "xsdLocal1:SourceInventoryLocation"         , ''                   ),
                      XMLElement( "xsdLocal1:Status"                          , 'Cancelled'          )
                   )   
                ).getClobVal()    
                  AS XML_Content
         FROM DUAL ;
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = Rec.V3Order,
                                                     Processed = SYSDATE    , 
                                                     Status    = 'Processed'
            WHERE Row_ID = sROW_ID ;
      ELSE      
         UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Reference = Rec.V3Order,
                                                     Processed = SYSDATE    , 
                                                     Status    = DECODE( sProcesar, 'ED', 'CheckData',
                                                                                          'Discard' )
            WHERE Row_ID = sROW_ID ;
      END IF ;  
   END LOOP ;  
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Processed = SYSDATE, Status = 'Error'
         WHERE Row_ID = sROW_ID ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                  , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'PROC_ORDER'          , sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END PROC_ORDER ;


PROCEDURE RECV_REPLENISHMENT IS
--
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   sSalesForceOn VARCHAR2(030) ;
   nPID          NUMBER(08)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'VanReplenishment'
           AND Created     > TRUNC( SYSDATE - 5 )
           AND Processed  IS NULL ;
BEGIN
   nComponent := 407 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   SELECT EAI_Owner.getConv( 'CFG Settings', 'SalesForceOn' )
      INTO sSalesForceOn
      FROM DUAL ;    
   nPID      := EAI_Owner.ProcessID.NextVal ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          IF ( UPPER( sSalesForceOn ) = 'YES' ) THEN
             EAI_OWNER.SF_PROC_REPLENISHMENT( Info.Row_ID, Info.Item, 0, nPID ) ;
          ELSE
             nRecords := nRecords + 0 ;
          END IF ;
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                  , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_REPLENISHMENT'  , sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END RECV_REPLENISHMENT ;


PROCEDURE RECV_PAYMENT IS
--
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sSalesForceOn VARCHAR2(05)  ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sMsg          VARCHAR2(300) ;
   nPID          NUMBER(08)    ;
   dtLastBegin   DATE          ;
   dtLastEnd     DATE          ;
   nStatus       NUMBER(04)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'Payment'
           AND Created     > TRUNC( SYSDATE - 20 )
           AND Processed  IS NULL 
         ORDER BY DocNum ;  
BEGIN
   nComponent := 408 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   SELECT PL.Inicio, PL.Fin, MC.Status
      INTO dtLastBegin, dtLastEnd, nStatus
      FROM T3.RF_Procesos_Log      PL,
           EAI_Owner.MX_Components MC
      WHERE PL.PID = ( SELECT MAX( PID ) AS PID FROM T3.RF_Procesos_Log WHERE Proceso = nComponent ) 
        AND PL.Proceso = MC.Component ;
   SELECT EAI_Owner.getConv( 'CFG Settings', 'SalesForceOn' )
      INTO sSalesForceOn
      FROM DUAL ;         
   IF ( ( dtLastEnd IS NOT NULL ) AND ( nStatus = 1 ) ) THEN
      Log_Start( nComponent ) ;   
      nPID      := EAI_Owner.ProcessID.NextVal ;
      INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
         VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
      FOR Info IN ScrRecords LOOP
          nRecords := nRecords + 1 ;       
          sInstanceChk := 'NO'         ;
          SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
             FROM DUAL ;
          IF ( sInstanceChk = 'YES' ) THEN
             IF ( UPPER( sSalesForceOn ) = 'YES' ) THEN
                EAI_OWNER.SF_PROC_CENTRAL_PAYMENT( Info.Row_ID, Info.Item, 0, nPID ) ;
             ELSE
                nRecords := nRecords + 0 ;
             END IF ;   
          ELSE
             UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                         Processed = SYSDATE
                WHERE Row_ID = Info.Row_ID ;
          END IF ;
          IF ( MOD ( nRecords, 50 ) = 0 ) THEN
             COMMIT ;
          END IF ;
      END LOOP ;
--    Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
      UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
         WHERE Component = nComponent ;
      UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                    Proceso_3 = 0, Proceso_4 = nRecords
          WHERE PID = nPID  ;
   END IF ;          
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                    , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , NULL                  , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_PAYMENT'        , sMsg                , 'XML'          ,
          sErrorCode         , NULL                  , NULL                , NULL            ) ;
      COMMIT ;
END RECV_PAYMENT ;


PROCEDURE RECV_INVOICE_INTERCOMPANY IS
   nComponent    NUMBER(3)     ;
   nRecords      NUMBER(6)     ;
   dtStarting    DATE          ;
   sInstanceChk  VARCHAR2(05)  ;
   sErrorCode    VARCHAR2(030) ;      
   sSalesForceOn VARCHAR2(030) ;
   sMsg          VARCHAR2(300) ;
   nPID          NUMBER(08)    ;
   CURSOR ScrRecords IS
      SELECT Row_ID, ROWNUM AS Item,
             extractValue( XML_Content, '*/Header/Sender/System/SystemName') AS InstanceName
         FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
         WHERE Queue_Name  = 'Invoice-Intercompany'
           AND Created     > TRUNC( SYSDATE - 5 )
           AND Processed  IS NULL ;
BEGIN
   nComponent := 409 ;
   nRecords   := 0   ;
   dtStarting := SYSDATE ;
   Log_Start( nComponent ) ;   
   SELECT EAI_Owner.getConv( 'CFG Settings', 'SalesForceOn' )
      INTO sSalesForceOn
      FROM DUAL ;   
   nPID      := EAI_Owner.ProcessID.NextVal ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ;     
   FOR Info IN ScrRecords LOOP
       nRecords := nRecords + 1 ;       
       sInstanceChk := 'NO'         ;
       SELECT EAI_Owner.fn_Check_Instance( Info.InstanceName ) INTO sInstanceChk
          FROM DUAL ;
       IF ( sInstanceChk = 'YES' ) THEN
          IF ( UPPER( sSalesforceOn ) = 'YES' ) THEN
             EAI_OWNER.SF_PROC_PREINVOICE_INTER( Info.Row_ID, Info.Item, 0, nPID ) ;
          ELSE
             nRecords := nRecords + 0 ;
          END IF ;   
       ELSE
          UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET Status    = 'PI Issue',
                                                      Processed = SYSDATE
             WHERE Row_ID = Info.Row_ID ;
       END IF ;
       IF ( MOD ( nRecords, 50 ) = 0 ) THEN
          COMMIT ;
       END IF ;
   END LOOP ;
-- Log_End( nComponent, dtStarting, SYSDATE, nRecords ) ;   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0,
                                                 Proceso_3 = 0, Proceso_4 = nRecords
       WHERE PID = nPID  ;   
   COMMIT ;
   sInstanceChk := 'T3'  ;
   T3.PROC_T3_OT_GENERAL ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                  , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sInstanceChk               , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'RECV_INVOICE_INTERCOMPANY', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;   
   COMMIT ;
END RECV_INVOICE_INTERCOMPANY ;

END ;

/

  GRANT EXECUTE ON "EAI_OWNER"."RECV_TO_SEND_V3" TO "LEGV3_SUPPORT";
  GRANT EXECUTE ON "EAI_OWNER"."RECV_TO_SEND_V3" TO "INTEGRATION_ROLE";
  GRANT EXECUTE ON "EAI_OWNER"."RECV_TO_SEND_V3" TO "ITX_DEV";
