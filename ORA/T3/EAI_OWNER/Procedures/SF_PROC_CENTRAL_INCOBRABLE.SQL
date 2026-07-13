create or replace PROCEDURE           SF_PROC_CENTRAL_INCOBRABLE ( 
    nDays              IN   NUMBER   DEFAULT 28,
    sClearingDocument  IN   VARCHAR2 DEFAULT 'EMPTY',
    nInsert            IN   NUMBER   DEFAULT 0,
    pOutput            IN   NUMBER   DEFAULT 0
) IS
   sMsg                    VARCHAR2(500)  ;   
   v_ID                    VARCHAR2(030)  ;
   sErrorCode              VARCHAR2(020)  ;
   sReferenceID            VARCHAR2(030)  ;
   sClearingDocNumber      VARCHAR2(020)  ;
   sProcesar               VARCHAR2(020)  ;
   sPago_ID                VARCHAR2(020)  ;
   nDocuments              NUMBER(06)     ;
   nRecords                NUMBER(06)     ;
   nInserts                NUMBER(06)     ;
   nMargen                 NUMBER(05,2)   ;
   nSQLCount               NUMBER(06)     ;
   nValor_Pago             NUMBER(15,4)   ;
   dtFecha_Asignacion      DATE           ;
   nMontoMaximo            NUMBER(15,4)   ;
   nPID                    NUMBER(08)     ;
   nProceso                NUMBER(08)     ;
   
--
   sInvDoc_Num             VARCHAR2(030)  ; 
   sInvCustomer            VARCHAR2(030)  ;
   nInvAmount              NUMBER(15,2)   ;
   nInvPending             NUMBER(15,2)   ;
   nPaid                   NUMBER(15,2)   ;
   sNCDoc_Num              VARCHAR2(030)  ; 
   sNCCustomer             VARCHAR2(030)  ;
   nNCAmount               NUMBER(15,2)   ;
   nNCPending              NUMBER(15,2)   ;
   nNCPaid                 NUMBER(15,2)   ;
   sCliente_SAP            VARCHAR2(030)  ;
   sCtro                   VARCHAR2(030)  ;
   sCliente_V3             VARCHAR2(030)  ;
   nDistribuidor           NUMBER(06)     ;
--
   CURSOR ScrData IS
      SELECT tmp.ClearingDocNumber    AS ClearingDocNumber, 
             tmp.ClearingDate         AS ClearingDate     ,
             COUNT( tmp.IdocNumber )  AS Cnt_Idocs
         FROM EAI_Owner.tmp_Account_Header tmp
         WHERE tmp.Created > TRUNC( SYSDATE - nDays )
         --AND tmp.Created < TRUNC( SYSDATE - 0     )
           AND tmp.Created <      ( SYSDATE - 2/24  )
           AND tmp.ClearingDocNumber LIKE '11%'
         GROUP BY tmp.ClearingDocNumber, tmp.ClearingDate
         ORDER BY tmp.ClearingDate, tmp.ClearingDocNumber ;
--
   CURSOR ScrDuplicated IS
      SELECT ReferenceDocNumber  AS ReferenceDocNumber, 
             COUNT(IdocNumber)   AS Cnt_RefDocNumber  , 
             MIN(IdocNumber)     AS Min_IdocNumber    ,
             MAX(IdocNumber)     AS Max_IdocNumber    ,
             MIN(PaymentAmount)  AS Min_PaymentAmount ,
             MIN(PaymentAmount)  AS Max_PaymentAmount 
         FROM EAI_Owner.tmp_Account_Header
         WHERE ClearingDocNumber = sClearingDocNumber
         GROUP BY ReferenceDocNumber
         HAVING COUNT(IdocNumber) > 1 ;   
--
   CURSOR ScrWorkAround IS
      SELECT Inco.IdocNumber                AS IdocNumber        ,
             Inco.ClearingDocNumber         AS ClearingDocNumber ,
             Inco.CustomerNumber            AS Cliente_SAP       ,
             Inco.AmountDocCurrency         AS AmountDocCurrency ,
             Inco.ClearingDate              AS ClearingDate      ,
             Inco.ReferenceDocNumber        AS ReferenceDocNumber,
             Inco.Created                   AS Created           ,
             MC.Ctro                        AS Ctro              ,
             MC.Cliente_V3                  AS Cliente_V3        , 
             MC.Dist_Venta                  AS Distribuidor
         FROM EAI_Owner.tmp_Account_Header Inco,
              T3.Mov_Cliente               MC
         WHERE Inco.Created                > TRUNC( SYSDATE - nDays )
           AND Inco.ClearingDocNumber      = sClearingDocNumber
           AND NVL( Inco.Status, 'NULO' ) != 'Duplicated'
           AND Inco.CustomerNumber         = MC.Cliente_SAP ;
--
   CURSOR ScrCustomerData IS
      SELECT MC.Ctro, MC.Cliente_V3, MC.Dist_Venta
         FROM T3.Mov_Cliente MC 
         WHERE MC.Cliente_SAP = sCliente_SAP ;
--
BEGIN
   nProceso  := 888 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;  
    nMargen := 1.5 ;
    IF ( TO_CHAR( SYSDATE, 'HH24' ) IN ( '01', '02' ) ) THEN
       nMargen := 0.0 ;
    END IF ;
    nDocuments   := 0      ;
    nRecords     := 0      ;
    nInserts     := 0      ;
    nMontoMaximo := 500000 ;
    IF ( pOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', TO_CHAR( SYSDATE, 'YYYYMMDDHH24MI' ), 'Begin' ) ;
    END IF ;
    FOR Rec IN ScrData LOOP
       nDocuments := nDocuments + 1        ;
       v_ID       := Rec.ClearingDocNumber ;
       UPDATE EAI_Owner.tmp_Inco_Header SET Last_Updated = SYSDATE
          WHERE ClearingDocNumber = Rec.ClearingDocNumber
            AND ClearingDate      = Rec.ClearingDate ;
       nSQLCount := SQL%ROWCOUNT ;
       IF ( nSQLCount = 0 ) THEN
          INSERT INTO EAI_Owner.tmp_Inco_Header 
             ( ClearingDocNumber    , ClearingDate, Created, Records )
          VALUES
             ( Rec.ClearingDocNumber, Rec.ClearingDate, SYSDATE, Rec.Cnt_Idocs ) ;
       --
          sClearingDocNumber := Rec.ClearingDocNumber                   ;
          dtFecha_Asignacion := TO_DATE( Rec.ClearingDate, 'YYYYMMDD' ) ;
          sPago_ID := '11' || sClearingDocNumber                        ;
       --
          FOR Dup IN ScrDuplicated LOOP
             UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Duplicated', Processed = SYSDATE
                WHERE IdocNumber = Dup.Max_IdocNumber ;             
          END LOOP ;
          COMMIT ;
       -- 
          FOR Det IN ScrWorkAround LOOP 
             sPago_ID      := '11' || Det.IdocNumber ;
             nRecords      := nRecords + 1           ;
             sReferenceID  := Det.ReferenceDocNumber ;
             nValor_Pago   := Det.AmountDocCurrency  ;
             sCliente_SAP  := ''                     ;
             sCliente_V3   := ''                     ;
             sCtro         := ''                     ;
             nDistribuidor := 00                     ;
             IF ( pOutput > 1 ) THEN
                INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                    VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                    sReferenceID || ',' || Det.Cliente_SAP || ',' || nValor_Pago || ' (' || Det.IdocNumber || ')' ) ;
             END IF ;
--
             IF ( nValor_Pago < nMontoMaximo ) THEN
                -- Invoice
                EAI_OWNER.SF_GET_INVOICE_DATA( sReferenceID, sInvDoc_Num, sInvCustomer, nInvAmount , nInvPending, nPaid ) ;
                IF ( nInvAmount > 0 ) THEN
                      IF ( pOutput > 1 ) THEN
                         INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                            VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                                     NVL( sInvDoc_Num, sReferenceID ) || ' pendiente ' || nInvPending ) ;
                      END IF ;
                      IF ( nInvPending >= nValor_Pago ) THEN
                         nInserts := nInserts + 1 ;
                         IF ( pOutput > 1 ) THEN
                            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                                                  sInvDoc_Num || ' -> Procesado' ) ;
                         END IF ;
                         IF ( nInsert > 0 ) THEN
                            sCliente_SAP := sInvCustomer ;
                            FOR Cust IN ScrCustomerData LOOP
                               sCliente_V3   := Cust.Cliente_V3 ;
                               sCtro         := Cust.Ctro       ;
                               nDistribuidor := Cust.Dist_Venta ;
                            END LOOP ;                            
                            INSERT INTO T3.Pago
                               ( Pago_ID         , Fecha_Trn         , Distribuidor    , Fecha_Pago        , 
                                 Cliente_V3      , Cliente_SAP       , Rep_ID          , 
                                 Tipo_Pago       , Metodo_Pago       , Valor_Pago      , Ctro               )
                            VALUES
                               ( sPago_ID        , SYSDATE           , nDistribuidor   , dtFecha_Asignacion, 
                                 sCliente_V3     , sCliente_SAP      , 'CENTRAL'       , 
                                 'PAYMENT'       , 'I'               , nValor_Pago     , sCtro              ) ;                        
                            INSERT INTO T3.Asignacion_Pago
                               ( Pago_ID         , Asignacion_ID     , Fecha_Trn       , Factura           , 
                                 Distribuidor    , Ctro              , Cliente_V3      , Cliente_SAP       , 
                                 Rep_ID          , Fecha_Asignacion  , Valor_Pago       )
                            VALUES 
                               ( sPago_ID        , sPago_ID          , SYSDATE         , sInvDoc_Num       , 
                                 nDistribuidor   , sCtro             , sCliente_V3     , sCliente_SAP      , 
                                 'CENTRAL'       , dtFecha_Asignacion, nValor_Pago      ) ;
                            UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Processed', Processed = SYSDATE
                               WHERE IdocNumber = Det.IdocNumber AND Status IS NULL ;                      
                         END IF ;
                      ELSE
                         UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Discarded', Processed = SYSDATE
                            WHERE IdocNumber = Det.IdocNumber AND Status IS NULL ;             
                         IF ( pOutput > 1 ) THEN
                            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                                        sInvDoc_Num || ' -> Discarded' ) ;
                         END IF ;                      
                      END IF ;
                ELSE
          -- Credit Note
                   EAI_OWNER.SF_GET_CREDIT_DATA( sReferenceID, sNCDoc_Num, sNCCustomer, nNCAmount , nNCPending, nNCPaid  ) ;
                   IF ( pOutput > 1 ) THEN
                      INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                         VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                         NVL( sNCDoc_Num, sReferenceID ) || ' pendiente ' || nNCPending ) ;
                   END IF ;
                   IF ( nNCAmount > 0 ) THEN
                      IF ( nNCPending >= nValor_Pago ) THEN
                         nInserts := nInserts + 1 ;                     
                         IF ( pOutput > 1 ) THEN
                            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                                       sNCDoc_Num || ' -> Procesado' ) ;
                         END IF ;
                         IF ( nInsert > 0 ) THEN
                            sCliente_SAP := sNCCustomer ;
                            FOR Cust IN ScrCustomerData LOOP
                               sCliente_V3   := Cust.Cliente_V3 ;
                               sCtro         := Cust.Ctro       ;
                               nDistribuidor := Cust.Dist_Venta ;
                            END LOOP ;                         
                            INSERT INTO T3.Asignacion_Pago
                              ( Pago_ID    , Asignacion_ID , Fecha_Trn      , Factura     , Nota_Credito        , Distribuidor    , 
                                Ctro       , Cliente_V3    , Cliente_SAP    , Rep_ID      , Fecha_Asignacion    , Valor_Pago        )
                            VALUES 
                              ( sPago_ID   , sPago_ID      , SYSDATE        , 'INCOBRABLE', sNCDoc_Num          , nDistribuidor   , 
                                sCtro      , sCliente_V3   , sCliente_SAP   , 'CENTRAL'   , dtFecha_Asignacion  , nValor_Pago       ) ;
                            UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Processed', Processed = SYSDATE
                               WHERE IdocNumber = Det.IdocNumber AND Status IS NULL ;                      
                         END IF ;
                      ELSE
                         UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Discarded', Processed = SYSDATE
                            WHERE IdocNumber = Det.IdocNumber AND Status IS NULL ;
                         IF ( pOutput > 1 ) THEN
                            INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
                               VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', sClearingDocNumber, 
                                       sNCDoc_Num || ' -> Discarded' ) ;
                         END IF ;
                      END IF ;
                   END IF ;               
                END IF ;   
             ELSE
                         UPDATE EAI_Owner.tmp_Account_Header SET Status = 'Max Amount exceeded', Processed = SYSDATE
                            WHERE IdocNumber = Det.IdocNumber AND Status IS NULL ;          
             END IF ;
          END LOOP ; 
          UPDATE EAI_Owner.tmp_Inco_Header SET Processed = SYSDATE
             WHERE ClearingDocNumber = Rec.ClearingDocNumber 
               AND ClearingDate      = Rec.ClearingDate ;
       END IF ;   
    END LOOP ;
--
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = nDocuments, Proceso_2 = nInserts,
                                                 Proceso_3 = 0         , Proceso_4 = 0
       WHERE PID = nPID  ;    
--       
    IF ( pOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', TO_CHAR( SYSDATE, 'YYYYMMDDHH24MI' ), 'Documents -> ' || LPAD( nDocuments, 6 ) ) ;
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', TO_CHAR( SYSDATE, 'YYYYMMDD' ), 'Records   -> ' || LPAD( nRecords  , 6 ) ) ;
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', TO_CHAR( SYSDATE, 'YYYYMMDD' ), 'Inserts   -> ' || LPAD( nInserts  , 6 ) ) ;
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_INCOBRABLE', TO_CHAR( SYSDATE, 'YYYYMMDD' ), 'End' ) ;
    END IF ;
    COMMIT ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG 
           ( DIRECTION          , REFERENCE                   , CREATED             , MESSAGE        , JOB_PID,
             STATUS             , QUEUE_NAME                  , SIEBEL_ERROR_MESSAGE, SOURCE         , 
             SIEBEL_ERROR_CODE  , RETRY_COUNT                 , SEQUENCE            , PARENT_ROW_ID    ) 
        VALUES
           ( 'Job Logging'      , v_ID                        , SYSDATE             , NULL           , NULL   ,
             'Error'            , 'SF_PROC_CENTRAL_INCOBRABLE', sMsg                , 'PL/SQL'       ,
             sErrorCode         , NULL                        , NULL                , NULL              ) ;
        COMMIT ;
END SF_PROC_CENTRAL_INCOBRABLE ;