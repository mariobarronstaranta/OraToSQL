create or replace PROCEDURE     MOVE_EVIDENCIA_ENTREGA
   ( nDias IN NUMBER DEFAULT 30 )
IS
    v_ID                VARCHAR2(050) ;       
    sMsg                VARCHAR2(500) ;   
    sErrorCode          VARCHAR2(020) ;
    nPID                NUMBER(08)    ;
    nProceso            NUMBER(08)    ;
    nProceso1           NUMBER(08)    ;
    nProceso2           NUMBER(08)    ;
    nProceso3           NUMBER(08)    ;
    nProceso4           NUMBER(08)    ;
--    
    CURSOR ScrEvidencia IS
       SELECT Ldr.ItemInternalId                  AS ItemInternalId ,
              Ldr.Fecha                           AS Fecha          ,
              Ldr.Tienda                          AS Tienda         ,
              Ldr.Folio_Recepcion                 AS Folio_Recepcion,
              Ldr.Volumen_Ticket                  AS Volumen_Ticket ,
              Ldr.Volumen_Nota                    AS Volumen_Nota   ,
              Ldr.Folio_Interno                   AS Folio_Interno  ,
              Ldr.CoincideVolumen                 AS CoincideVolumen,
              NVL( Hist.Folio_Interno, 'INSERT' ) AS Insert_Hist    ,
              Suc.Entrega                         AS Entrega        ,
              Suc.Cliente_SAP                     AS Cliente_SAP    ,
              Suc.X_EM_Field_5                    AS X_EM_Field_5   ,
              NVL( IFC.Var_1, 'INSERT' )          AS Insert_IFC
          FROM EAI.LDR_EVIDENCIAS_ENTREGA  Ldr ,
               EAI.HIST_EVIDENCIAS_ENTREGA Hist,
             ( SELECT FG.Factura, FG.Cliente_SAP, FG.Entrega, Suc.X_EM_Field_5 
                  FROM T3.Factura_General FG, T3.TMD_eMail Suc
                  WHERE FG.Fecha_Trn > SYSDATE - NVL( nDias, 90 )
                    AND FG.Cliente_SAP = Suc.Cliente_SAP(+)
               UNION
               SELECT PG.Factura, PG.Cliente_SAP, PG.Entrega, Suc.X_EM_Field_5
                  FROM T3.Preventa_General PG, T3.TMD_eMail Suc
                  WHERE PG.Fecha_Trn > SYSDATE - NVL( nDias, 90 )
                   AND PG.Clase_Factura IN ( 'C005', 'C006' )
                   AND PG.Cliente_SAP = Suc.Cliente_SAP(+)
               ) Suc,
               EAI.IFC_Folios_FE    IFC
          WHERE Ldr.Folio_Interno = Hist.Folio_Interno(+)  
            AND Ldr.Folio_Interno = IFC.Var_1(+)
            AND Ldr.Folio_Interno = Suc.Factura(+) ;
--
BEGIN
    nProceso  := 929 ;
    nPID      := EAI_Owner.ProcessID.NextVal ;
    EAI_Owner.Log_Start( nProceso ) ;
    INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
       VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
    nProceso1 := 0 ;
    nProceso2 := 0 ;
    nProceso3 := 0 ;
    nProceso4 := 0 ;
    FOR Doc IN ScrEvidencia LOOP
       nProceso1 := nProceso1 + 1 ;
       IF ( Doc.Insert_Hist = 'INSERT' ) THEN
          INSERT INTO EAI.HIST_EVIDENCIAS_ENTREGA
             ( ItemInternalId    , Fecha           , Tienda             , Folio_Recepcion    , Volumen_Ticket  ,
               Folio_Interno     , Volumen_Nota    , CoincideVolumen    , INSERT_TS                              )
          VALUES
             ( Doc.ItemInternalId, Doc.Fecha       , Doc.Tienda         , Doc.Folio_Recepcion, Doc.Volumen_Ticket,
               Doc.Folio_Interno , Doc.Volumen_Nota, Doc.CoincideVolumen, SYSDATE                                 ) ;
       ELSE
          UPDATE EAI.HIST_EVIDENCIAS_ENTREGA SET UPDATE_TS = SYSDATE
             WHERE Folio_Interno = Doc.Folio_Interno ;
          nProceso2 := nProceso2 + 1 ;   
       END IF ;
       IF ( ( UPPER( Doc.CoincideVolumen ) = 'SI' ) AND ( Doc.Entrega IS NOT NULL ) ) THEN
          IF ( Doc.Insert_IFC = 'INSERT' ) THEN
             nProceso3 := nProceso3 + 1 ;
             INSERT INTO EAI.IFC_Folios_FE ( Row_ID, Entrada, CreadoPor, Creacion, Var_1 ) 
                VALUES ( Doc.Entrega, Doc.Folio_Recepcion, 'MODULE', SYSDATE, Doc.Folio_Interno ) ;
          END IF ;
          IF ( ( Doc.Cliente_SAP IS NOT NULL ) AND ( Doc.Tienda IS NOT NULL ) AND ( Doc.X_EM_Field_5 IS NULL ) ) THEN
             nProceso4 := nProceso4 + 1 ;
             UPDATE T3.TMD_eMail SET X_EM_Field_5 = Doc.Tienda
                WHERE Cliente_SAP = Doc.Cliente_SAP ;
          END IF ;
       END IF ;
    END LOOP ;
--
    UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
       WHERE Component = nProceso ;
    UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nProceso1, Proceso_3 = nProceso3,
                                                  Proceso_2 = nProceso2, Proceso_4 = nProceso4
       WHERE PID = nPID  ;          
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
          ( DIRECTION          , ID                      , CREATED             , MESSAGE        , JOB_PID,
            STATUS             , QUEUE_NAME              , SIEBEL_ERROR_MESSAGE, SOURCE         , 
            SIEBEL_ERROR_CODE  , RETRY_COUNT             , SEQUENCE            , PARENT_ROW_ID   ) 
        VALUES  
          ( 'Job Logging'      , v_ID                    , SYSDATE             , NULL           , nPID   ,
            'Error'            , 'MOVE_EVIDENCIA_ENTREGA', sMsg                , 'PL/SQL'       ,
            sErrorCode         , NULL                    , NULL                , NULL            ) ;
        COMMIT ;   
END MOVE_EVIDENCIA_ENTREGA ;