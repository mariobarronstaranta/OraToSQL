create or replace PROCEDURE           "WA_PURGE_MX_EAI_MESSAGE_LOG" 
   ( pDias           IN NUMBER   DEFAULT 2 )
   AS              
--
   CURSOR ScrPurge IS
      SELECT Err.ROWID, Err.Created, 'DELETE EAI_Owner.MX_EAI_Message_Log WHERE ROWID = ' || CHR(39) || Err.ROWID || CHR(39) || ' ;' as executeStatement
         FROM EAI_Owner.MX_EAI_Message_Log Err ,
              EAI_owner.tmp_Document_Header Delv
         WHERE Queue_Name = 'VanReplenishment'
           AND Err.Reference = Delv.ReferenceID
      UNION ALL     
      SELECT Err.ROWID, Err.Created, 'DELETE EAI_Owner.MX_EAI_Message_Log WHERE ROWID = ' || CHR(39) || Err.ROWID || CHR(39) || ' ;' as executeStatement
         FROM EAI_Owner.MX_EAI_Message_Log Err ,
              T3.Factura_General Inv
         WHERE Queue_Name = 'Invoice'
           AND Err.Reference = Inv.Entrega  
      UNION ALL     
      SELECT Err.ROWID, Err.Created, 'DELETE EAI_Owner.MX_EAI_Message_Log WHERE ROWID = ' || CHR(39) || Err.ROWID || CHR(39) || ' ;' as executeStatement
         FROM EAI_Owner.MX_EAI_Message_Log Err ,
              T3.Preventa_General Inv
         WHERE Queue_Name = 'Invoice'
           AND Err.Reference = Inv.Entrega  
      UNION ALL     
      SELECT Err.ROWID, Err.Created, 'DELETE EAI_Owner.MX_EAI_Message_Log WHERE ROWID = ' || CHR(39) || Err.ROWID || CHR(39) || ' ;' as executeStatement
         FROM EAI_Owner.MX_EAI_Message_Log Err ,
              T3.Preventa_General Inv
         WHERE Queue_Name = 'Invoice-Intercompany'
           AND Err.Reference = Inv.Entrega 
      UNION ALL     
      SELECT Err.ROWID, Err.Created, 'DELETE EAI_Owner.MX_EAI_Message_Log WHERE ROWID = ' || CHR(39) || Err.ROWID || CHR(39) || ' ;' as executeStatement
         FROM EAI_Owner.MX_EAI_Message_Log Err ,
              T3.Otros_General Inv
         WHERE Queue_Name = 'Invoice-Intercompany'
           AND Err.Reference = Inv.Factura ;
--
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   nPedidos              NUMBER(06)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
   sRowID                VARCHAR2(050) ;      
BEGIN
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,  10, 409 ),  
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 245 )
                 WHERE Queue_Name  = 'VanReplenishment'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,   8, 408 ),  
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 237 )
                 WHERE Queue_Name  = 'Product'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,  10, 399 ),  
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 238 )
                 WHERE Queue_Name  = 'Customer'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,  10, 362 ),  
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 248 )
                 WHERE Queue_Name  = 'Invoice-Intercompany'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,  10, 504 ),  
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 236 )
                 WHERE Queue_Name  = 'Payment'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
   COMMIT ;                
--   
   FOR Rec IN ScrPurge LOOP
      DELETE EAI_Owner.MX_EAI_Message_Log 
         WHERE ROWID = Rec.ROWID ;
      nPedidos := nPedidos + 1 ;   
   END LOOP ;
   COMMIT ;
--   
EXCEPTION
   WHEN OTHERS THEN
      COMMIT ;
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;  
      DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
      DBMS_Output.Put_Line( 'Ref        -> ' || sRowID   ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                    , CREATED             , MESSAGE       , JOB_PID,
          STATUS             , QUEUE_NAME                   , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT                  , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , sRowID                       , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_PURGE_MX_EAI_MESSAGE_LOG', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                         , NULL                , NULL            ) ;
      COMMIT ;   
END WA_PURGE_MX_EAI_MESSAGE_LOG ;