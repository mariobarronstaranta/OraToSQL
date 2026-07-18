create or replace PROCEDURE  "WA_ERR_TSEQ" 
   ( pDays           IN NUMBER   DEFAULT 1,
     pDiffHours      IN NUMBER   DEFAULT 5 )
   AS
--
   CURSOR ScrInfo IS
       SELECT Info.TS_RowID                                     AS TS_RowID        ,
              Info.TS_Name                                      AS TS_Name         ,
              Info.TS_Resource                                  AS TS_Resource     ,
              Info.Transaction_Type                             AS Transaction_Type,
              Info.Sequence_Number                              AS Sequence_Number ,
              Info.Rule_Rugex                                   AS Rule_Rugex      ,
              Info.ModifiedDate                                 AS ModifiedDate    ,
              TO_CHAR(
                 TO_DATE( Info.ModifiedDate, 'YYYY-MM-DD HH24:MI:SS' )
                 - ( NVL( pDiffHours, 0 ) / 24 ), 'YYYY-MM-DD HH24:MI:SS' )
                                                                AS MX_ModifiedDate ,
              Info.Extract_dt
          FROM (
                 SELECT ID                                         AS TS_RowID        ,
                        Name                                       AS TS_Name         ,
                        Resource_R                                 AS TS_Resource     ,
                        Transaction_Type                           AS Transaction_Type,
                        Sequence_Number                            AS Sequence_Number ,
                        Rule_Rugex                                 AS Rule_Rugex      ,
                        REPLACE( 
                           REPLACE( LastModifiedDate, '.000Z', '' ), 'T', ' ' )
                                                                   AS ModifiedDate    ,
                        Extract_dt                                           
                    FROM EAI_Owner.Transaction_Sequence_Hist  TSH
                    WHERE TSH.Transaction_Type IN ( 'INV', 'SR' )
                      AND TSH.Insert_Hist       > TRUNC( SYSDATE - NVL( pDays, 1 ) )
                ) Info    
          ORDER BY Info.TS_RowID, Info.ModifiedDate, Info.Extract_dt ;
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;    
   v_ID                  VARCHAR2(050) ;    
   nFailures             NUMBER(8)     ;
   nRows                 NUMBER(8)     ;
   nNotUpdated           NUMBER(8)     ;
   nUpdated              NUMBER(8)     ;
   nRange                NUMBER(8)     ;
--
   sTS_RowID_Old         VARCHAR2(100) ;
   sTS_Name_Old          VARCHAR2(100) ;
   sTS_Resource_Old      VARCHAR2(100) ;
   sTransaction_Type_Old VARCHAR2(100) ;
   nSequence_Number_Old  NUMBER(8)     ;
   sRule_Rugex_Old       VARCHAR2(100) ;
   sModifiedDate_Old     VARCHAR2(100) ;
   sTS_RowID_New         VARCHAR2(100) ;
   sTS_Name_New          VARCHAR2(100) ;
   sTS_Resource_New      VARCHAR2(100) ;
   sTransaction_Type_New VARCHAR2(100) ;
   nSequence_Number_New  NUMBER(8)     ;
   sRule_Rugex_New       VARCHAR2(100) ;
   sModifiedDate_New     VARCHAR2(100) ;
   nComponent            NUMBER(08)    ;
   nPID                  NUMBER(08)    ;   
--
BEGIN
   nComponent := 927 ;
   Log_Start( nComponent ) ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nComponent, NULL, SYSDATE ) ; 
   nRows         := 0      ;
   nFailures     := 0      ;
   nNotUpdated   := 0      ;
   nUpdated      := 0      ;
   sTS_RowID_Old := 'Init' ;
   FOR Seq IN ScrInfo LOOP
      v_ID := Seq.TS_RowID ;
      IF ( sTS_RowID_Old != Seq.TS_RowID ) THEN
         nRows                 := nRows + 1            ;
         sTS_RowID_Old         := Seq.TS_RowID         ;
         sTS_Name_Old          := Seq.TS_Name          ;
         sTS_Resource_Old      := Seq.TS_Resource      ;
         sTransaction_Type_Old := Seq.Transaction_Type ;
         nSequence_Number_Old  := Seq.Sequence_Number  ;
         sRule_Rugex_Old       := Seq.Rule_Rugex       ;
         sModifiedDate_Old     := Seq.ModifiedDate     ;
      ELSE
         nSequence_Number_New  := Seq.Sequence_Number  ;
         nRange := nSequence_Number_New - nSequence_Number_Old ;
         IF    ( nRange < 0 ) THEN
              nFailures := nFailures + 1 ;
              DBMS_Output.Put_Line( 
                                    'Rule_Rugex -> ' || SUBSTR( sRule_Rugex_Old, 2, 5 ) || '. '   || 
                                    'Sequence -> '   || LPAD( nSequence_Number_Old, 6 ) || ' -> ' || LPAD( nSequence_Number_New, 6 ) || '. ' ||
                                    'Updated -> '    || Seq.MX_ModifiedDate             || '. '   || 
                                    'Resource -> '   || sTS_Resource_Old                  ) ; 
              UPDATE EAI_Owner.Transaction_Sequence_Errors SET UpdatedOn = SYSDATE
                 WHERE Rule_Rugex   = SUBSTR( sRule_Rugex_Old, 2, 5 )
                   AND LastUpdated  = Seq.MX_ModifiedDate
                   AND ResourceName = sTS_Resource_Old ;
              nRange := SQL%ROWCOUNT ;
              IF ( nRange = 0 ) THEN
                 INSERT INTO EAI_Owner.Transaction_Sequence_Errors 
                    ( Rule_Rugex                     , Seq_Prev            , Seq_Next            ,
                      LastUpdated                    , ResourceName        , CreatedOn            )
                 VALUES
                    ( SUBSTR( sRule_Rugex_Old, 2, 5 ), nSequence_Number_Old, nSequence_Number_New,
                      Seq.MX_ModifiedDate            , sTS_Resource_Old    , SYSDATE              ) ;
              END IF ;      
         ELSIF ( nRange = 0 ) THEN
              nNotUpdated := nNotUpdated + 1 ;
         ELSE
              nUpdated    := nUpdated    + 1 ;
         END IF ;
--       
         sTS_Resource_Old      := Seq.TS_Resource      ;
         nSequence_Number_Old  := Seq.Sequence_Number  ;
         sModifiedDate_Old     := Seq.ModifiedDate     ;
      END IF ;
   END LOOP ;
   DBMS_Output.Put_Line( '--------------------------------' ) ;
   DBMS_Output.Put_Line( 'TSeq Reviewed -> ' || nRows       ) ;
   DBMS_Output.Put_Line( 'Failures      -> ' || nFailures   ) ;
   DBMS_Output.Put_Line( 'NotUpdated    -> ' || nNotUpdated ) ;
   DBMS_Output.Put_Line( 'Updated Ok    -> ' || nUpdated    ) ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nComponent ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nRows      , Proceso_2 = nFailures,
                                                 Proceso_3 = nNotUpdated, Proceso_4 = nUpdated
       WHERE PID = nPID  ;    
   COMMIT ; 
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR( SQLCODE ) ;
      sMsg := SUBSTR( TO_CHAR( SQLCODE ) || '-' || SQLERRM, 1, 250 ) ;      
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION           , REFERENCE            , CREATED             , MESSAGE        ,
          STATUS              , QUEUE_NAME           , SIEBEL_ERROR_MESSAGE, SOURCE         , 
          SIEBEL_ERROR_CODE   , RETRY_COUNT          , SEQUENCE            , PARENT_ROW_ID   )
      VALUES 
        ( 'WA Transaction Seq', v_ID                 , SYSDATE             , NULL           ,
          'Error'             , 'WA_ERR_TSEQ'        , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_TSEQ ;