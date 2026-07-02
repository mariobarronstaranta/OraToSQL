create or replace PROCEDURE     CC_SALESDOC_LDR_TO_CIFRAS (
    pTruncate IN VARCHAR2 DEFAULT 'N',
    pOutput   IN NUMBER DEFAULT 0
) AS
    CURSOR ScrLoader IS
        SELECT
               Ldr.Doc_Date                      AS Doc_Date    ,
               Ldr.Distributor                   AS Distributor ,
               Ldr.Customer                      AS Customer    ,
               Ldr.Doc_Num_R3                    AS Doc_Num_R3  ,               -- SAP Invoice
               Ldr.Doc_Ord_R3                    AS Doc_Ord_R3  ,               -- SAP Order
               Ldr.Doc_Num_Ref2                  AS Doc_Num_Ref1,               -- Reference  ( V3 Document Number - XBLNR )
               Ldr.Doc_Num_Ref1                  AS Doc_Num_Ref2,               -- Assignment ( SAP Assignment     - ZUONR )
               Ldr.Doc_Type                      AS Doc_Type    ,
               Ldr.Doc_Status                    AS Doc_Status  ,
               Ldr.Doc_NetAmt                    AS Doc_NetAmt  ,
               Ldr.Doc_TaxAmt                    AS Doc_TaxAmt  ,
               Ldr.Doc_Qty                       AS Doc_Qty     ,
               CC.RowID                          AS CC_RowID    ,
               NVL( CC.Doc_Num_R3, 'NULL' )      AS CC_Num_R3   ,
               PG.Factura                        AS Factura     ,
               CASE
                   WHEN PG.Clase_Factura IS NOT NULL THEN PG.Clase_Factura
                   WHEN FG.Tipo_Docto    IS NOT NULL THEN FG.Tipo_Docto
                   WHEN ( Ldr.Doc_Type = 'ZF2' ) THEN 'C003'
                   WHEN ( Ldr.Doc_Type = 'ZRE' ) THEN 'C004'
                   ELSE
                      Ldr.Doc_Type
               END                               AS Tipo_Docto
          FROM EAI.TaO_SALES_DOCS_LDR  Ldr,
               EAI.T3R_Sales_Docs_Old  CC ,
               T3.Preventa_General     PG ,
               T3.Factura_General      FG
          WHERE Ldr.Doc_Num_R3   = CC.Doc_Num_R3(+)
            AND Ldr.Doc_Num_R3   = PG.Entrega(+)
            AND Ldr.Doc_Num_Ref1 = FG.Factura(+) ;
--
    CURSOR ScrStatusF IS
       SELECT T1.Doc_Num_R3, T1.Doc_Status, T1.Doc_TaxAmt, T1.Doc_Num_Ref1, T1.Doc_Num_Ref2, 
             'UPDATE EAI.T3R_SALES_DOCS_OLD SET Doc_TaxAmt = ' || T1.Doc_TaxAmt ||
                 ' , Doc_Status = ' || CHR(39) || T1.Doc_Status || CHR(39) || 
             ' WHERE Doc_Num_R3 = ' || CHR(39) || T1.Doc_Num_R3 || CHR(39) || ' ; ' AS UpdateStatement
       FROM EAI.TaO_SALES_DOCS_LDR T1,
            EAI.T3R_SALES_DOCS_Old T2
       WHERE T1.Doc_Num_R3 = T2.Doc_Num_R3
         AND T2.Doc_Status = 'F'
         AND T1.Doc_TaxAmt > 0 
         AND T2.Doc_TaxAmt = 0 ;
--
   sMsg                VARCHAR2(500) ;
   v_ID                VARCHAR2(030) ;
   sErrorCode          VARCHAR2(030) ;
   dtStarting          DATE          ;
   nRecords            NUMBER(08)    ;
   nInsert             NUMBER(08)    ;
   nUpdate             NUMBER(08)    ;
   sFolioFiscal        VARCHAR2(030) ;
   sReference          VARCHAR2(030) ;
   sInsertCommercial   VARCHAR2(004) ;
   sInsertProduction   VARCHAR2(004) ;
   sInsertOthers       VARCHAR2(004) ;
   nProceso            NUMBER(08)    ;
   nPID                NUMBER(18)    ;
   nProceso1           NUMBER(08)    ;
   nProceso2           NUMBER(08)    ;
   nProceso3           NUMBER(08)    ;
   nProceso4           NUMBER(08)    ;
BEGIN

   nProceso  := 701 ;
   nPID      := EAI_Owner.ProcessID.NextVal ;
   EAI_Owner.Log_Start( nProceso ) ;
   INSERT INTO T3.RF_PROCESOS_LOG ( PID , Proceso , Fecha_Proc_BATMD, Inicio )
      VALUES ( nPID, nProceso, NULL, SYSDATE ) ;   
   nProceso3 := 0 ;
   nProceso4 := 0 ;
    
   dtStarting := SYSDATE ;
   nRecords   := 0 ;
   nInsert    := 0 ;
   IF ( NVL( pTruncate, 'N' ) = 'Y' ) THEN
      EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.T3R_Sales_Docs_Old'      ) ;      
      EXECUTE IMMEDIATE( 'TRUNCATE TABLE EAI.T3R_Sales_Docs_Ldr_MX01' ) ;
      COMMIT ;
   END IF ;

-- checkpoint "loader-BEGINS".
   UPDATE EAI.Control_Reporte cr SET cr.INICIO = SYSDATE, CR.fin = NULL
      WHERE REPORTE IN ( 'LOAD CIFRAS VENTAS' );
   UPDATE EAI.CONTROL_REPORTE  SET  INICIO = SYSDATE, FIN = NULL
      WHERE REPORTE = 'AUTO-UPLOAD VENTAS' ;      
--
   FOR Rec IN ScrLoader LOOP
      BEGIN
      nRecords := nRecords + 1 ;
      sInsertCommercial := 'NO' ;
      sInsertProduction := 'NO' ;
      sInsertOthers     := 'NO' ;
      IF ( Rec.CC_Num_R3 = 'NULL' ) THEN
         sReference   := Rec.Doc_Num_Ref1 ;
         sFolioFiscal := Rec.Doc_Num_Ref2 ;
         IF ( Rec.Factura IS NOT NULL ) THEN
            sFolioFiscal := Rec.Factura      ;
            sReference   := Rec.Doc_Num_Ref2 ;
            sInsertCommercial := 'SI' ;            
         END IF ;
--     Checking BAT Commercial        
         IF ( Rec.Tipo_Docto IN ( 'C003', 'C004', 'C005', 'C006', 'C0FX', 'C019' ) ) THEN
            sInsertCommercial := 'YES' ;                        
         END IF ;
--     Checking BAT Production
         IF ( Rec.Tipo_Docto IN ( 'C020', 'C021', 'C022' ) ) THEN
            sInsertProduction := 'YES' ;                        
         END IF ;
--     Checking Others
         IF ( ( sInsertProduction = 'NO' ) AND ( sInsertProduction = 'NO' ) ) THEN
            sInsertOthers := 'YES' ;
         END IF ;
--
         IF ( sInsertCommercial = 'YES' ) THEN
               INSERT INTO EAI.T3R_Sales_Docs_Old
                  (  Doc_Date        , Distributor     , Customer        , Doc_Num_R3      ,
                     Doc_Ord_R3      , Doc_Num_Ref1    , Doc_Num_Ref2    , Doc_Type        ,
                     Created         ,
                     Doc_Status      , Doc_NetAmt      , Doc_TaxAmt      , Doc_Qty          )
               VALUES
                  (  Rec.Doc_Date    , Rec.Distributor , Rec.Customer    , Rec.Doc_Num_R3  ,
                     Rec.Doc_Ord_R3  , sReference      , sFolioFiscal    , Rec.Tipo_Docto  ,
                     SYSDATE         ,
                     Rec.Doc_Status  , Rec.Doc_NetAmt  , Rec.Doc_TaxAmt  , Rec.Doc_Qty      ) ;
               nInsert := nInsert + 1 ;
         ELSIF ( sInsertProduction = 'YES' ) THEN
            UPDATE EAI.T3R_Sales_Docs_Ldr_MX01 SET Doc_Qty = Doc_Qty + 0 
               WHERE Doc_Num_R3 = Rec.Doc_Num_R3 ;
            nUpdate := SQL%ROWCOUNT ;
            IF ( nUpdate = 0 ) THEN
               INSERT INTO EAI.T3R_Sales_Docs_Ldr_MX01
                  (  Doc_Date        , Distributor     , Customer        , Doc_Num_R3      ,
                     Doc_Ord_R3      , Doc_Num_Ref1    , Doc_Num_Ref2    , Doc_Type        ,
                     Created         ,
                     Doc_Status      , Doc_NetAmt      , Doc_TaxAmt      , Doc_Qty          )
               VALUES
                  (  Rec.Doc_Date    , Rec.Distributor , Rec.Customer    , Rec.Doc_Num_R3  ,
                     Rec.Doc_Ord_R3  , sReference      , sFolioFiscal    , Rec.Tipo_Docto  ,
                     SYSDATE         ,
                     Rec.Doc_Status  , Rec.Doc_NetAmt  , Rec.Doc_TaxAmt  , Rec.Doc_Qty      ) ;
               nInsert := nInsert + 1 ;
            END IF ;
         ELSIF ( sInsertOthers = 'YES' ) THEN   
            UPDATE EAI.T3R_Sales_Docs_Others SET Doc_Qty = Doc_Qty + 0 
               WHERE Doc_Num_R3 = Rec.Doc_Num_R3 ;
            IF ( nUpdate = 0 ) THEN
               INSERT INTO EAI.T3R_Sales_Docs_Others
                  (  Doc_Date        , Distributor     , Customer        , Doc_Num_R3      ,
                     Doc_Ord_R3      , Doc_Num_Ref1    , Doc_Num_Ref2    , Doc_Type        ,
                     Created         ,
                     Doc_Status      , Doc_NetAmt      , Doc_TaxAmt      , Doc_Qty          )
               VALUES
                  (  Rec.Doc_Date    , Rec.Distributor , Rec.Customer    , Rec.Doc_Num_R3  ,
                     Rec.Doc_Ord_R3  , sReference      , sFolioFiscal    , Rec.Tipo_Docto  ,
                     SYSDATE         ,
                     Rec.Doc_Status  , Rec.Doc_NetAmt  , Rec.Doc_TaxAmt  , Rec.Doc_Qty      ) ;
               nInsert := nInsert + 1 ;
            END IF ;   
         END IF ;
      END IF ;
      EXCEPTION
         WHEN OTHERS THEN
            sMsg := SUBSTR(' ERROR ORACLE ' || TO_CHAR( SQLCODE ) || ' ' || SQLERRM, 1, 480 ) ;
            INSERT INTO ERROR_TABLE ( DISTRIBUTOR, PROCESS, DOC_NUM, ERR_DATE, MESSAGE, CTRO ) 
            VALUES ( Rec.Distributor, 'CC_SALESDOC_LDR_TO_CIFRAS', Rec.Doc_Num_R3, SYSDATE, sMsg, null ) ;-- Rec.Distributor, Ren.Doc_Num_R3
            COMMIT ;
      END ;
   END LOOP ;
-- Update Status F
   FOR Doc IN ScrStatusF LOOP
       UPDATE EAI.T3R_SALES_DOCS_OLD SET Doc_TaxAmt = Doc.Doc_TaxAmt,
                                         Doc_Status = Doc.Doc_Status
          WHERE Doc_Num_R3 = Doc.Doc_Num_R3 ;
   END LOOP ;   
-- checkpoint "loader-done".
   UPDATE Control_Reporte cr SET cr.fin = SYSDATE Where REPORTE in ('LOAD CIFRAS VENTAS');
   UPDATE EAI.CONTROL_REPORTE  SET  FIN = SYSDATE
      WHERE REPORTE = 'AUTO-UPLOAD VENTAS' ;
--      
   IF ( NVL( pOutput, 0 ) > 0 ) THEN
      DBMS_Output.Put_Line( 'Starting -> ' || TO_CHAR( dtStarting, 'HH24:MI:SS' ) ) ;
      DBMS_Output.Put_Line( 'Records  -> ' || TO_CHAR( nRecords  , '99,999,999' ) ) ;
      DBMS_Output.Put_Line( 'Inserts  -> ' || TO_CHAR( nInsert   , '99,999,999' ) ) ;
      DBMS_Output.Put_Line( 'End      -> ' || TO_CHAR( SYSDATE   , 'HH24:MI:SS' ) ) ;
   END IF ;
   UPDATE EAI_OWNER.MX_COMPONENTS SET Status = 1
      WHERE Component = nProceso ;
   UPDATE T3.RF_PROCESOS_LOG SET  Fin = SYSDATE, Proceso_1 = 0, Proceso_2 = nProceso2,
                                                 Proceso_3 = 0, Proceso_4 = nProceso4
       WHERE PID = nPID  ;
   COMMIT ;
EXCEPTION
   WHEN OTHERS THEN
      sErrorCode := 'ORA-' || TO_CHAR(SQLCODE) ;
      sMsg := SUBSTR( TO_CHAR(SQLCODE) || '-' || SQLERRM, 1, 250 ) ;
      INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        ( DIRECTION          , ID                         , CREATED             , MESSAGE        , JOB_PID,
          STATUS             , QUEUE_NAME                 , SIEBEL_ERROR_MESSAGE, SOURCE         ,
          SIEBEL_ERROR_CODE  , RETRY_COUNT                , SEQUENCE            , PARENT_ROW_ID   )
      VALUES
        ( 'CifrasControl'    , v_ID                       , SYSDATE             , NULL           , nPID   ,
          'Error'            , 'CC_SALESDOC_LDR_TO_CIFRAS', sMsg                , 'PL/SQL'       ,
          sErrorCode         , NULL                       , NULL                , NULL            ) ;
      COMMIT ;
END CC_SALESDOC_LDR_TO_CIFRAS ;