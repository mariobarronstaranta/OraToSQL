create or replace PROCEDURE     CCEA_DATA_OPENITEM
IS
    v_ID                VARCHAR2(050) ;       
    sMsg                VARCHAR2(500) ;   
    sErrorCode          VARCHAR2(020) ;
    nPID                NUMBER(08)    ;
    nProceso            NUMBER(08)    ;
    nProceso3           NUMBER(08)    ;
    nProceso4           NUMBER(08)    ;
 --
BEGIN
    nProceso  := 712 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso3 := 0 ;
    nProceso4 := 0 ;

    EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.CC_DATA_OPENITEM' ) ;
      INSERT INTO EAI.CC_DATA_OPENITEM (
          PLANT              , SFDC_CUSTOMER       , SAP_CUSTOMER        , HEAD_OFFICE         ,
          PAYMENT_SOURCE     , SAP_REFERENCE       , DOCUMENT_DATE       , DOCUMENT_TYPE       ,
          SFDC_REFERENCE     , SAP_AMOUNT                                                       )
       SELECT NVL( MC.Ctro, 'MXAD' )                               AS PLANT              ,
              TRIM( MC.Cliente_V3 )                                AS SFDC_CUSTOMER      ,
              Ldr.Head_Office                                      AS SAP_CUSTOMER       ,
              Ldr.Head_Office                                      AS HEAD_OFFICE        ,
              NVL( CS.Forma_Pago, 'Central Payment' )              AS PAYMENT_SOURCE     ,
              TRIM( Ldr.SAP_Reference )                            AS SAP_REFERENCE      ,
              Ldr.Document_Date                                    AS DOCUMENT_DATE      ,
              TRIM( Ldr.Document_Type )                            AS DOCUMENT_TYPE      ,
              Ldr.SFDC_Reference                                   AS SFDC_REFERENCE     ,
              Ldr.SAP_Amount                                       AS SAP_AMOUNT
          FROM (
                SELECT 
                       NVL( Ldr.Branch_Number, Ldr.Cliente )       AS SAP_Customer   ,
                       Ldr.Cliente                                 AS Head_Office    ,
                       Ldr.Asignacion                              AS SAP_Assignment ,
                       Ldr.AccountDocument                         AS SAP_Reference  ,
                       SUBSTR( Ldr.Fecha_Doc, 1, 4 ) || '-' ||
                       SUBSTR( Ldr.Fecha_Doc, 5, 2 ) || '-' ||
                       SUBSTR( Ldr.Fecha_Doc, 7, 2 )               AS Document_Date  ,
                       CASE
                           WHEN ( Ldr.Tipo_Doc = 'KP' ) THEN 'Debit Note'
                           WHEN ( Ldr.Tipo_Doc = 'Z2' ) THEN 'Debit Note'
                           WHEN ( Ldr.Tipo_Doc = 'ZD' ) THEN 'Debit Note'
                           WHEN ( Ldr.Tipo_Doc = 'RV' ) THEN 'Invoice'      
                           WHEN ( Ldr.Tipo_Doc = 'CG' ) THEN 'Pending Allocation'      
                           WHEN ( Ldr.Tipo_Doc = 'CR' ) THEN 'Invoice'    
                           ELSE
                              Ldr.Tipo_Doc
                       END                                         AS Document_Type ,
                       Ldr.Referencia                              AS SFDC_Reference,
                       DECODE( Ldr.Cargo, 'S', 1, -1 ) *
                       TO_NUMBER( TRIM( NVL( Ldr.Monto, '0' ) ) )  AS SAP_Amount       
                   FROM EAI.TAO_CARTERA_SAP_LDR  Ldr 
                   WHERE Ldr.Fecha_Doc >= '20190101'
                     AND Ldr.Referencia NOT IN ( SELECT Referencia FROM EAI_Owner.TAO_EXCLUDE_ITEMS )
                     AND Ldr.Cliente NOT IN ( SELECT Target FROM EAI_Owner.MX_hashTable 
                                                 WHERE Type = 'CifrasControl'
                                                   AND Source = 'Discarding Customer' )
                                                     ) Ldr,
                   T3.Mov_Cliente                       MC ,
                   EAI.Cliente_Siebel                   CS
              WHERE Ldr.Head_Office = MC.Cliente_SAP(+)  
                AND Ldr.Head_Office = CS.Cliente_SAP(+) ;
          nProceso4 := SQL%ROWCOUNT ;
--
    UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
       WHERE Component = nProceso ;
    UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_3 = nProceso3,
                                                  Proceso_2 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;          
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                  , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME          , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT         , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , v_ID                , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'CCEA_DATA_OPENITEM', sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL                , NULL                , NULL            ) ;
        COMMIT ;   
END CCEA_DATA_OPENITEM ;