create or replace PROCEDURE           "WA_ERR_PAYMENT_AMPERSAND" 
   ( pDias           IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrPresales IS
       SELECT 
              Err.Err_RowID                                       AS Err_RowID  ,
              Err.Row_ID                                          AS Row_ID     ,
              SYSDATE                                             AS Created    ,
              Err.Queue_Name                                      AS Queue_Name ,
              XMLTYPE(
              CONCAT( TO_CLOB( Err.Fase1 ),
                CONCAT( TO_CLOB( Err.Fase2 ), 
                CONCAT( TO_CLOB( Err.Fase3 ), 
                CONCAT( TO_CLOB( Err.Fase4 ), TO_CLOB( Err.Fase5 )
                      )  )  )  ) )                                AS XML_Content,
              CASE
                 WHEN ( Err.CloseDocType > 0 ) THEN SUBSTR( Err.Message, Err.CloseDocType - 2, 2 ) 
                 ELSE
                  '  '
              END   AS DocumentType                                            
       FROM (
              SELECT TO_CHAR( SYSDATE, 'YYYYMMDDHH24MISS' ) ||
                     LPAD( ROWNUM, 8, '0' )                                            AS Row_ID       ,
                     Err.Queue_Name                                                    AS Queue_Name   ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,     1 ), '&', 'y' )  AS Fase1        ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,  3901 ), '&', 'y' )  AS Fase2        ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,  7801 ), '&', 'y' )  AS Fase3        ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 11701 ), '&', 'y' )  AS Fase4        ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 15601 ), '&', 'y' )  AS Fase5        ,
                     Err.ROWID                                                         AS Err_RowID    ,
                     CAST( SUBSTR( Err.Message, 1, 2000 ) AS VARCHAR2(2000) )          AS Message      ,
                     INSTR( SUBSTR( Err.Message, 1, 2000 ), '</DocumentType>' )        AS CloseDocType                                       
                 FROM EAI_Owner.MX_EAI_Message_Log Err
                 WHERE Queue_Name  = 'Payment'
                   AND Direction   = 'Receive'
                   AND Status      = 'Error'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )
            ) Err ;                   
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(05)    ;
BEGIN
   nPedidos := 0 ;
   FOR Inv IN ScrPresales LOOP
      IF ( Inv.DocumentType = 'ZV' OR Inv.DocumentType = 'CR') THEN
         INSERT INTO EAI_Owner.MX_Receive_Message_Log
            ( Row_ID, Created, Queue_Name, XML_Content )
         VALUES
            ( Inv.Row_Id, Inv.Created, Inv.Queue_Name, Inv.XML_Content ) ;
         UPDATE EAI_Owner.MX_EAI_Message_Log SET Status = 'Reprocess'
            WHERE ROWID = Inv.Err_RowID ;  
         nPedidos := nPedidos + 1 ;   
      END IF ;
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE      , CREATED             , MESSAGE        ,
            STATUS           , QUEUE_NAME     , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE, RETRY_COUNT    , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA Payment'       , NULL                 , SYSDATE             , NULL           ,
          'Error'            , 'WA_ERR_PAYMENT'     , sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_PAYMENT_AMPERSAND ;