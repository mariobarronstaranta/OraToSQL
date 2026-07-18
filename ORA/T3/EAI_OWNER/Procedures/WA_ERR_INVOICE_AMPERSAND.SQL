create or replace PROCEDURE           "WA_ERR_INVOICE_AMPERSAND" 
   ( pDias           IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrPresales IS
       SELECT 
              Err.Err_RowID                                       AS Err_RowID  ,
              Err.Row_ID                                          AS Row_ID     ,
              Err.SAP_DocRef                                      AS SAP_DocRef ,
              SYSDATE                                             AS Created    ,
              Err.Queue_Name                                      AS Queue_Name ,
              XMLTYPE(
              CONCAT( TO_CLOB( Err.Fase1 ),
                CONCAT( TO_CLOB( Err.Fase2 ), 
                CONCAT( TO_CLOB( Err.Fase3 ), 
                CONCAT( TO_CLOB( Err.Fase4 ), 
                CONCAT( TO_CLOB( Err.Fase5 ), 
                CONCAT( TO_CLOB( Err.Fase6 ), 
                CONCAT( TO_CLOB( Err.Fase7 ), 
                CONCAT( TO_CLOB( Err.Fase8 ), 
                CONCAT( TO_CLOB( Err.Fase9 ), 
                CONCAT( TO_CLOB( Err.Fase10 ), 
                CONCAT( TO_CLOB( Err.Fase11 ), 
                CONCAT( TO_CLOB( Err.Fase12 ), 
                CONCAT( TO_CLOB( Err.Fase13 ), 
                CONCAT( TO_CLOB( Err.Fase14 ), 
                CONCAT( TO_CLOB( Err.Fase15 ),
                CONCAT( TO_CLOB( Err.Fase16 ),
                CONCAT( TO_CLOB( Err.Fase17 ),
                CONCAT( TO_CLOB( Err.Fase18 ),
                CONCAT( TO_CLOB( Err.Fase19 ),
                CONCAT( TO_CLOB( Err.Fase20 ),
                CONCAT( TO_CLOB( Err.Fase21 ),
                CONCAT( TO_CLOB( Err.Fase22 ),
                CONCAT( TO_CLOB( Err.Fase23 ),
                CONCAT( TO_CLOB( Err.Fase24 ),
                CONCAT( TO_CLOB( Err.Fase25 ),  
                CONCAT( TO_CLOB( Err.Fase26 ), 
                CONCAT( TO_CLOB( Err.Fase27 ), 
                CONCAT( TO_CLOB( Err.Fase28 ), 
                CONCAT( TO_CLOB( Err.Fase29 ), 
                CONCAT( TO_CLOB( Err.Fase30 ), 
                CONCAT( TO_CLOB( Err.Fase31 ), 
                CONCAT( TO_CLOB( Err.Fase32 ), 
                CONCAT( TO_CLOB( Err.Fase33 ), 
                CONCAT( TO_CLOB( Err.Fase34 ),
                CONCAT( TO_CLOB( Err.Fase35 ),
                CONCAT( TO_CLOB( Err.Fase36 ),
                CONCAT( TO_CLOB( Err.Fase37 ),
                CONCAT( TO_CLOB( Err.Fase38 ),
                CONCAT( TO_CLOB( Err.Fase39 ),
                CONCAT( TO_CLOB( Err.Fase40 ),
                TO_CLOB( Err.Fase41 )
                  )   ) ) ) ) ) ))))) )))) )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  )  ))))))          AS XML_Content
       FROM (
              SELECT TO_CHAR( SYSDATE, 'YYYYMMDDHH24MISS' ) ||
                     LPAD( ROWNUM, 5, '0' )                                           AS Row_ID    ,
                     Err.Queue_Name                                                   AS Queue_Name,
                     Err.Reference                                                    AS SAP_DocRef,
--                   CAST( Err.Message AS VARCHAR2(4000) )                            AS Msg_String,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,     1 ), '&', 'y' )  AS Fase1     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,  3901 ), '&', 'y' )  AS Fase2     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900,  7801 ), '&', 'y' )  AS Fase3     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 11701 ), '&', 'y' )  AS Fase4     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 15601 ), '&', 'y' )  AS Fase5     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 19501 ), '&', 'y' )  AS Fase6     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 23401 ), '&', 'y' )  AS Fase7     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 27301 ), '&', 'y' )  AS Fase8     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 31201 ), '&', 'y' )  AS Fase9     ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 35101 ), '&', 'y' )  AS Fase10    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 39001 ), '&', 'y' )  AS Fase11    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 42901 ), '&', 'y' )  AS Fase12    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 46801 ), '&', 'y' )  AS Fase13    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 50701 ), '&', 'y' )  AS Fase14    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 54601 ), '&', 'y' )  AS Fase15    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 58501 ), '&', 'y' )  AS Fase16    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 62401 ), '&', 'y' )  AS Fase17    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 66301 ), '&', 'y' )  AS Fase18    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 70201 ), '&', 'y' )  AS Fase19    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 74101 ), '&', 'y' )  AS Fase20    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 78001 ), '&', 'y' )  AS Fase21    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 81901 ), '&', 'y' )  AS Fase22    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 85801 ), '&', 'y' )  AS Fase23    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 89701 ), '&', 'y' )  AS Fase24    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 93601 ), '&', 'y' )  AS Fase25    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 97501 ), '&', 'y' )  AS Fase26    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 101401 ), '&', 'y' )  AS Fase27    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 105301 ), '&', 'y' )  AS Fase28    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 109201 ), '&', 'y' )  AS Fase29    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 113101 ), '&', 'y' )  AS Fase30    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 117001 ), '&', 'y' )  AS Fase31    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 120901 ), '&', 'y' )  AS Fase32    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 124801 ), '&', 'y' )  AS Fase33    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 128701 ), '&', 'y' )  AS Fase34    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 132601 ), '&', 'y' )  AS Fase35    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 136501 ), '&', 'y' )  AS Fase36    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 140401 ), '&', 'y' )  AS Fase37    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 144301 ), '&', 'y' )  AS Fase38    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 148201 ), '&', 'y' )  AS Fase39    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 152101 ), '&', 'y' )  AS Fase40    ,
                     REPLACE( DBMS_LOB.SUBSTR( Err.Message, 3900, 156001 ), '&', 'y' )  AS Fase41    ,
                     Err.ROWID                                   AS Err_RowID
                 FROM EAI_Owner.MX_EAI_Message_Log Err
                 WHERE Queue_Name  = 'Invoice'
                   AND Direction   = 'Receive'
                   AND Status      = 'Error'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - 1 )
            ) Err ;                         
--   
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;
   v_ID                  VARCHAR2(030) ;      
   nPedidos              NUMBER(05)    ;
   nPID                  NUMBER(08)    ;
   nProceso              NUMBER(08)    ;
BEGIN
   nProceso  := 830 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
--
   UPDATE EAI_Owner.MX_EAI_Message_Log Err SET Reference     = DBMS_LOB.SUBSTR( Err.Message,  10, 399 ),
                                               Parent_Row_ID = DBMS_LOB.SUBSTR( Err.Message,  16, 236 )
                 WHERE Queue_Name  = 'Invoice'
                   AND Direction   = 'Receive'
                   AND Siebel_Error_Message LIKE '%-ORA-31011%'
                   AND Created     > TRUNC( SYSDATE - pDias )  
                   AND Parent_Row_ID IS NULL ;
   COMMIT ;                
--
   nPedidos := 0 ;
   FOR Inv IN ScrPresales LOOP
      v_ID := Inv.SAP_DocRef ;
      INSERT INTO EAI_Owner.MX_Receive_Message_Log
         ( Row_ID, Created, Queue_Name, XML_Content )
      VALUES
         ( Inv.Row_Id, Inv.Created, Inv.Queue_Name, Inv.XML_Content ) ;
      UPDATE EAI_Owner.MX_EAI_Message_Log SET Status = 'Reprocess'
         WHERE ROWID = Inv.Err_RowID ;  
      nPedidos := nPedidos + 1 ;   
   END LOOP ;
   DBMS_Output.Put_Line( 'Documentos -> ' || nPedidos ) ;
   COMMIT ; 
   EAI_OWNER.WA_ERR_PAYMENT_AMPERSAND( pDias ) ; 
--   
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = 0       ,
                                                 Proceso_3 = 0, Proceso_4 = nPedidos
       WHERE PID = nPID  ;      
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , REFERENCE                 , CREATED             , MESSAGE       , JOB_PID,
          STATUS             , QUEUE_NAME                , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE  , RETRY_COUNT               , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'Job Logging'      , v_ID                      , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'WA_ERR_INVOICE_AMPERSAND', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                      , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_INVOICE_AMPERSAND ;