create or replace PROCEDURE           SF_WA_PROC_REPLENISHMENT
   ( nDays     IN   NUMBER DEFAULT 0 )
IS
   sMsg              VARCHAR2(500) ;   
   v_ID              VARCHAR2(050) ;
   sErrorCode        VARCHAR2(020) ;
   sProcesar         VARCHAR2(002) ;
   sLineDebug        VARCHAR2(999) ;
--   
   CURSOR ScrData IS
      SELECT Row_ID, Created, Queue_Name, Reference, Processed, Status, Docnum, Ent.Entrega
         FROM EAI_Owner.MX_Receive_Message_Log Recv,
              T3.Preventa_General              PG  ,
              T3.Entrega                       Ent
         WHERE Recv.Queue_Name  = 'VanReplenishment'
           AND Recv.Created     > SYSDATE - nDays
           AND Recv.Reference   = PG.Factura
           AND Recv.Reference   = Ent.Factura(+)
           AND Ent.Entrega     IS NULL ;
BEGIN
   FOR Ent IN ScrData LOOP
      v_ID :=  Ent.Row_ID ;
      EAI_OWNER.SF_PROC_REPLENISHMENT( Ent.Row_ID, 0, 0, NULL ) ;
   END LOOP ;   
--
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE                 , CREATED             , MESSAGE        , JOB_PID,
          STATUS              , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Processing PI'     , v_ID                      , SYSDATE             , NULL           , NULL   ,
          'Error'             , 'SF_WA_PROC_REPLENISHMENT', sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                      , NULL                , NULL            ) ;
      COMMIT ;
END SF_WA_PROC_REPLENISHMENT ;