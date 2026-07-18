create or replace PROCEDURE           "WA_REP_MASTERDATA" 
   ( pInsert           IN NUMBER   DEFAULT 0 )
   AS
--
   sReference            VARCHAR2(030) ;
   sReferenceInv         VARCHAR2(030) ;
   sReferenceCM          VARCHAR2(030) ;
   sReferenceRFC         VARCHAR2(030) ;
--
   CURSOR ScrReps IS
       SELECT A.Cliente_SAP, A.Nombre_Rep, B.Nombre,
              DECODE( A.Cliente_SAP, B.Cliente_SAP, 'UPDATE', 'INSERT' ) AS Accion,
              REPLACE( 
                  REPLACE( A.IvyBase__Username__c,
                                        'petra3.', '' ),
                                        'PETRA3.', '' )        AS eMail,
             NVL( B.Correo_Electronico, 'NULL' )               AS Correo_Electronico
          FROM ( SELECT Stock_Partner_Resource    AS Cliente_SAP         ,
                        Resource_Name             AS Nombre_Rep          ,
                        IvyBase__Username__c      AS IvyBase__Username__c
                    FROM EAI_Owner.VANS_Vigentes
                    WHERE Name LIKE 'VAN%' ) A,
               ( SELECT Cliente_SAP, Nombre, Correo_Electronico
                  FROM EAI_Owner.Cat_Reps ) B
          WHERE A.Cliente_SAP = B.Cliente_SAP(+)        
            AND A.Cliente_SAP NOT LIKE '%RESOURCE%' ;
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(08)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
BEGIN
   nPedidos := 0 ;
   nProceso := 0 ;
   FOR Rep IN ScrReps LOOP
      sReference := Rep.Cliente_SAP ;
      nProceso   := nProceso + 1 ;
      IF ( Rep.Accion = 'UPDATE' ) THEN
--       UPDATE EAI_Owner.Cat_Reps SET Nombre = Rep.Nombre_Rep
--          WHERE Cliente_SAP = Rep.Cliente_SAP ;
         IF ( ( LENGTH( TRIM( Rep.Correo_Electronico ) ) < 5 ) AND ( LENGTH( TRIM( Rep.eMail ) ) > 0 ) ) THEN
            UPDATE EAI_Owner.Cat_Reps SET Correo_Electronico  = Rep.eMail  ,
                                          Ultima_Modificacion = SYSDATE    ,
                                          ModificadoPor       = 'REPLICATE'
               WHERE Cliente_SAP = Rep.Cliente_SAP ;
         END IF ;
         nPedidos := nPedidos + 0 ;   
      ELSE
         IF ( NVL( pInsert, 0) > 0 ) THEN
            INSERT INTO EAI_Owner.Cat_Reps ( Cliente_SAP, Nombre, Correo_Electronico, Creacion, CreadoPor )
               VALUES ( Rep.Cliente_SAP, Rep.Nombre_Rep, Rep.eMail, SYSDATE, 'REPLICATE' ) ;
            nPedidos := nPedidos + 1 ;   
         END IF ;      
      END IF ;
   END LOOP ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE            , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sReference           , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_REP_MASTERDATA'  , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_REP_MASTERDATA ;