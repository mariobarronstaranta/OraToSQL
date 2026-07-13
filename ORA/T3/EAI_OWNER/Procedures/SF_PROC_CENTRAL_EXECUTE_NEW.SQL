create or replace PROCEDURE           SF_PROC_CENTRAL_EXECUTE_NEW ( 
    nDays       IN   NUMBER   DEFAULT 28,
    sFiscalYear IN   VARCHAR2 DEFAULT TO_CHAR( SYSDATE, 'YYYY' ),
    nPID        IN   NUMBER   DEFAULT NULL,
    pOutput     IN   NUMBER   DEFAULT 0
) IS
   sMsg                    VARCHAR2(500) ;   
   v_ID                    VARCHAR2(030) ;
   sErrorCode              VARCHAR2(020) ;
   sReferenceID            VARCHAR2(030) ;
   sClearingDocNumber      VARCHAR2(020) ;
   sProcesar               VARCHAR2(020) ;
   nRecords                NUMBER(06)    ;
   nMargen                 NUMBER(05,2)  ;
--
   CURSOR ScrData IS
       SELECT ClearingDocNumber, 
--            MAX( PostingDate )                                                                  AS PostingDate , 
              MAX( ClearingDate )                                                                 AS ClearingDate,
              MAX( ClearingDate )                                                                 AS PostingDate , 
              COUNT( ClearingDocNumber )                                                          AS Records     ,
              COUNT( DISTINCT DC_Indicator )                                                      AS Cnt_DC      ,
              MAX( DC_Indicator )                                                                 AS Max_DC      ,
              MAX( LPAD( IDocNumber, 16, '0' ) )                                                  AS IDocNumber  ,
              MAX( DECODE( DC_Indicator, 'S', LPAD( IDocNumber, 16, '0' ), LPAD( 0, 16, '0' ) ) ) AS S_IDocNumber
          FROM EAI_Owner.tmp_Account_Header Cred      
          WHERE Created            > TRUNC( SYSDATE - nDays )
            AND Created            < ( SYSDATE - ( nMargen/24 ) )
            AND ClearingDocNumber IS NOT NULL
          --AND FiscalYear         = sFiscalYear
            AND ClearingDocNumber NOT LIKE '11000%'
            AND PaymentAmount     IS NOT NULL
          --AND Assignment        IS NOT NULL
            AND Processed         IS NULL
            AND Reversal          IS NULL
--          AND ClearingDocNumber = '2100000132'
          GROUP BY ClearingDocNumber ;
--
   CURSOR ScrWorkAround IS
         SELECT Doc.ClearingDocNumber                                                 AS ClearingDocNumber, 
                COUNT( Doc.IdocNumber )                                               AS IDocNumber_Cnt   ,
                SUM( DECODE( Doc.DC_Indicator, 'S', 1, 0 ) )                          AS Cnt_S            ,
                SUM( DECODE( Doc.DC_Indicator, 'H', 1, 0 ) )                          AS Cnt_H            ,
                MIN( DECODE( Doc.DC_Indicator, 'S', Doc.IdocNumber, '99999999999' ) ) AS MIN_DC_S         ,
                MAX( DECODE( Doc.DC_Indicator, 'S', Doc.IdocNumber, '00000000000' ) ) AS MAX_DC_S         ,
                MIN( DECODE( Doc.DC_Indicator, 'H', Doc.IdocNumber, '99999999999' ) ) AS MIN_DC_H         ,
                MAX( DECODE( Doc.DC_Indicator, 'H', Doc.IdocNumber, '00000000000' ) ) AS MAX_DC_H         ,
                MIN( Doc.PayMethSupplement )                                          AS MIN_PMS          ,
                MAX( Doc.PayMethSupplement )                                          AS MAX_PMS          ,
                MIN( Doc.PaymentAmount     )                                          AS MIN_PaymentAmt   ,
                MAX( Doc.PaymentAmount     )                                          AS MAX_PaymentAmt   
            FROM EAI_owner.tmp_Account_Header Doc
            WHERE Doc.ClearingDocNumber  = sClearingDocNumber
              AND Doc.Processed         IS NULL
            GROUP BY Doc.ClearingDocNumber ;   
--
BEGIN
    nMargen := 1.5 ;
    IF ( TO_CHAR( SYSDATE, 'HH24' ) IN ( '01', '02' ) ) THEN
       nMargen := 0.0 ;
    END IF ;
    EAI_OWNER.WA_ACCNT_PAYAMOUNT( 1, -1 ) ; 
    nRecords := 0 ;
    IF ( pOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_EXECUTE', sFiscalYear || '-' || LPAD( nDays, 2, '0'), 'Begin' ) ;
    END IF ;

    FOR Rec IN ScrData LOOP
       nRecords := nRecords + 1 ;
       sClearingDocNumber := Rec.ClearingDocNumber ;
       IF ( ( Rec.Records = 1 ) AND ( Rec.Max_DC = 'S' ) ) THEN
    -- Payment   
          v_ID := Rec.IDocNumber ;
          EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV ( Rec.IDocNumber, pOutput ) ;
       ELSIF ( ( Rec.Records = 1 ) AND ( Rec.Max_DC = 'H' ) ) THEN
    -- Credit   
          v_ID := Rec.IDocNumber ;
          UPDATE EAI_Owner.tmp_Account_Header SET Status    = 'Discarded',
                                                  Processed = SYSDATE  
              WHERE ClearingDocNumber = Rec.ClearingDocNumber
                AND Created           > TRUNC( SYSDATE - nDays ) 
                AND DC_Indicator      = Rec.Max_DC            ; 
       ELSIF ( ( Rec.Records = 2 ) AND ( Rec.Cnt_DC = 1 ) AND ( Rec.Max_DC = 'S' ) ) THEN
    -- TM Movements   
          v_ID := Rec.IDocNumber ;
          EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV ( Rec.S_IDocNumber, pOutput ) ;
       ELSIF ( ( Rec.Records = 2 ) AND ( Rec.Cnt_DC = 2 ) ) THEN
    -- Credit Allocation
          EAI_OWNER.SF_PROC_CENTRAL_PAYALLOC( SUBSTR( Rec.S_IDocNumber, 7, 10 ), Rec.ClearingDocNumber, Rec.ClearingDate, TO_DATE( Rec.ClearingDate, 'YYYYMMDD' ), pOutput ) ;     
       ELSIF ( ( Rec.Records = 4 ) AND ( Rec.Cnt_DC = 2 ) ) THEN   
          FOR WA IN ScrWorkAround LOOP
             IF ( ( WA.MIN_PMS = WA.MAX_PMS ) AND ( WA.MIN_PMS = 'Z9' ) AND ( WA.MIN_PaymentAmt = WA.MAX_PaymentAmt ) ) THEN
                UPDATE EAI_Owner.tmp_Account_Header SET Status    = 'Discarded', Processed = SYSDATE, ClearingDocNumber = ClearingDocNumber || 'D'
                    WHERE IdocNumber = WA.MIN_DC_S ;
                UPDATE EAI_Owner.tmp_Account_Header SET Status    = 'Discarded', Processed = SYSDATE, ClearingDocNumber = ClearingDocNumber || 'D'
                    WHERE IdocNumber = WA.MIN_DC_H ;
                EAI_OWNER.SF_PROC_CENTRAL_PAYALLOC( SUBSTR( Rec.S_IDocNumber, 7, 10 ), Rec.ClearingDocNumber, Rec.ClearingDate, TO_DATE( Rec.ClearingDate, 'YYYYMMDD' ), pOutput ) ;     
             END IF ;
          END LOOP ;
       ELSE
          v_ID := Rec.ClearingDocNumber ;          
       END IF ;
    END LOOP ; 
    IF ( pOutput > 0 ) THEN
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_EXECUTE', sFiscalYear || '-' || LPAD( nDays, 2, '0'), 'Records -> ' || LPAD( nRecords, 6 ) ) ;
       INSERT INTO EAI_Owner.Trace_EAI_Owner ( Created, Object_Type, Object_Reference, Description ) 
          VALUES ( SYSDATE, 'SF_PROC_CENTRAL_EXECUTE', sFiscalYear || '-' || LPAD( nDays, 2, '0'), 'End' ) ;
    END IF ;
EXCEPTION
    WHEN OTHERS THEN
        sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
        sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG 
           ( DIRECTION          , REFERENCE             , CREATED             , MESSAGE        , JOB_PID,
             STATUS             , QUEUE_NAME            , SIEBEL_ERROR_MESSAGE, SOURCE         , 
             SIEBEL_ERROR_CODE  , RETRY_COUNT           , SEQUENCE            , PARENT_ROW_ID    ) 
        VALUES
           ( 'Job Logging'      , v_ID                  , SYSDATE             , NULL           , nPID   ,
             'Error'            , 'PROC_CENTRAL_EXECUTE', sMsg                , 'PL/SQL'       ,
             sErrorCode         , NULL                  , NULL                , NULL              ) ;
        COMMIT ;
END SF_PROC_CENTRAL_EXECUTE_NEW ;