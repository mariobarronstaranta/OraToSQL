create or replace PROCEDURE  "WA_ERR_SEQUENCE" 
   ( pDays           IN NUMBER   DEFAULT 1,
     pDiffHours      IN NUMBER   DEFAULT 5,
     pOutput         IN NUMBER   DEFAULT 0 )
   AS
--
   CURSOR ScrInfo IS
       SELECT
              Doc.Territorio                                 AS Territorio     ,
              Doc.Invoice_Date                               AS Invoice_Date   ,
              Doc.ResourceName                               AS ResourceName   ,
              Doc.Doctos                                     AS Doctos         ,
              ( Doc.Max_Folio - Doc.Min_Folio + 1 )          AS Doc_x_Folios   ,
              Doc.Min_Folio                                  AS Min_Folio      ,
              Doc.Max_Folio                                  AS Max_Folio      ,
              Doc.Min_CreatedDate                            AS Min_CreatedDate,
              Doc.Max_CreatedDate                            AS Max_CreatedDate       
          FROM (       
                 SELECT Info.Doc_Terr                           AS Territorio     ,
                        Info.Invoice_Date                       AS Invoice_Date   ,
                        Info.ResourceName                       AS ResourceName   ,
                        COUNT( DISTINCT Info.Doc_Num )          AS Doctos         ,
                        MIN( TO_NUMBER( Info.Doc_Folio ) )      AS Min_Folio      ,
                        MAX( TO_NUMBER( Info.Doc_Folio ) )      AS Max_Folio      ,
                        MIN( Info.CreatedDate )                 AS Min_CreatedDate,
                        MAX( Info.CreatedDate )                 AS Max_CreatedDate      
                    FROM (      
                           SELECT 
                                  Inv.ID                        AS Doc_ID         ,
                                  Inv.Name                      AS Doc_Name       ,
                                  Inv.Doc_Num                   AS Doc_Num        ,
                                  SUBSTR( Inv.Doc_Num, 2,  4 )  AS Doc_Terr       ,
                                  SUBSTR( Inv.Doc_Num, 7, 10 )  AS Doc_Folio      ,
                                  T3.Func_is_Number( SUBSTR( Inv.Doc_Num, 7, 8 ) )
                                                                AS Doc_Is_Number  ,
                                  REPLACE(
                                     REPLACE( Inv.Created_Date, '.000Z' ),
                                     'T', ' ' )                 AS CreatedDate    ,
                                  Inv.Invc_dt                   AS Invoice_Date   ,
                                  Inv.Invc_Status               AS Invc_Status    ,
                                  Inv.Delivery_Status           AS Delivery_Status, 
                                  Inv.Extract_dt                AS ExtractedDate , 
                                  Inv.Recurso                   AS ResourceName
                              FROM EAI_Owner.Facturas_B Inv
                              WHERE Inv.Invc_dt                 >= TO_CHAR( SYSDATE - NVL( pDays, 1 ), 'YYYY-MM-DD' )
                                AND SUBSTR( Inv.Doc_Num, 6, 1 )  = '-'
                          ) Info   
                    WHERE Info.Doc_is_Number = 'PASS'      
                    GROUP BY Info.Doc_Terr, Info.Invoice_Date, Info.ResourceName
                ) Doc
          WHERE Doc.Doctos != ( Doc.Max_Folio - Doc.Min_Folio + 1 )      
          ORDER BY Doc.Invoice_Date, Doc.Territorio  ;
--
   sTerritorio           VARCHAR2(030) ;
   sInvoice_Date         VARCHAR2(030) ;
   CURSOR ScrTransactionLost IS
                 SELECT 
                        Inv.ID                       AS Doc_ID         ,
                        Inv.Name                     AS Doc_Name       ,
                        Inv.Doc_Num                  AS Doc_Num        ,
                        SUBSTR( Inv.Doc_Num, 2,  4 ) AS Doc_Terr       ,
                        SUBSTR( Inv.Doc_Num, 7, 10 ) AS Doc_Folio      ,
                        T3.Func_is_Number( SUBSTR( Inv.Doc_Num, 7, 8 ) )
                                                     AS Doc_Is_Number  ,
                        REPLACE(
                           REPLACE( Inv.Created_Date, '.000Z' ),
                           'T', ' ' )                AS CreatedDate    ,
                        Inv.Invc_dt                  AS Invoice_Date   ,
                        Inv.Invc_Status              AS Invc_Status    ,
                        Inv.Delivery_Status          AS Delivery_Status, 
                        Inv.Extract_dt               AS ExtractedDate
                    FROM EAI_Owner.Facturas_B Inv
                    WHERE Inv.Invc_dt                  = sInvoice_Date
                      AND SUBSTR( Inv.Doc_Num, 6, 1 )  = '-'
                      AND SUBSTR( Inv.Doc_Num, 2, 4 )  = sTerritorio
                    ORDER BY Inv.Invc_dt, SUBSTR( Inv.Doc_Num, 1, 6 ) || LPAD( SUBSTR( Inv.Doc_Num, 7, 10 ), 10, '0' ) ; 
--
   CURSOR ScrDayBefore IS
       SELECT
              Doc.Territorio   ||
              Doc.Invoice_Date                                  AS TS_Row_ID      ,
              Doc.Territorio                                    AS Territorio     ,
              Doc.Invoice_Date                                  AS Invoice_Date   ,
              Doc.Resource_Name                                 AS Resource_Name  ,
              Doc.Doctos                                        AS Doctos         ,
              ( Doc.Max_Folio - Doc.Min_Folio + 1 )             AS Doc_x_Folios   ,
              Doc.Min_Folio                                     AS Min_Folio      ,
              Doc.Max_Folio                                     AS Max_Folio      
          FROM (       
                 SELECT Info.Doc_Terr                           AS Territorio     ,
                        Info.Invoice_Date                       AS Invoice_Date   ,
                        Info.Resource_Name                      AS Resource_Name  ,
                        COUNT( DISTINCT Info.Doc_Num )          AS Doctos         ,
                        MIN( TO_NUMBER( Info.Doc_Folio ) )      AS Min_Folio      ,
                        MAX( TO_NUMBER( Info.Doc_Folio ) )      AS Max_Folio      ,
                        MIN( Info.CreatedDate )                 AS Min_CreatedDate,
                        MAX( Info.CreatedDate )                 AS Max_CreatedDate      
                    FROM (      
                           SELECT 
                                  Inv.ID                        AS Doc_ID         ,
                                  Inv.Name                      AS Doc_Name       ,
                                  Inv.Doc_Num                   AS Doc_Num        ,
                                  SUBSTR( Inv.Doc_Num, 2,  4 )  AS Doc_Terr       ,
                                  SUBSTR( Inv.Doc_Num, 7, 10 )  AS Doc_Folio      ,
                                  T3.Func_is_Number( SUBSTR( Inv.Doc_Num, 7, 8 ) )
                                                                AS Doc_Is_Number  ,
                                  REPLACE(
                                     REPLACE( Inv.Created_Date, '.000Z' ),
                                     'T', ' ' )                 AS CreatedDate    ,
                                  Inv.Invc_dt                   AS Invoice_Date   ,
                                  Inv.Invc_Status               AS Invc_Status    ,
                                  Inv.Delivery_Status           AS Delivery_Status, 
                                  Inv.Extract_dt                AS ExtractedDate  ,
                                  Inv.Recurso                   AS Resource_Name
                              FROM EAI_Owner.Facturas_B Inv
                              WHERE Inv.Invc_dt                 >= TO_CHAR( SYSDATE - NVL( pDays, 1 ), 'YYYY-MM-DD' )
                                AND SUBSTR( Inv.Doc_Num, 6, 1 )  = '-'
                          ) Info   
                    WHERE Info.Doc_is_Number = 'PASS'      
                    GROUP BY Info.Doc_Terr, Info.Invoice_Date, Info.Resource_Name
                ) Doc
          ORDER BY Doc.Territorio, Doc.Invoice_Date ;
--
   sErrorCode            VARCHAR2(030) ;      
   sMsg                  VARCHAR2(300) ;    
   v_ID                  VARCHAR2(050) ;    
   nFailures             NUMBER(8)     ;
   nRows                 NUMBER(8)     ;
   nNotUpdated           NUMBER(8)     ;
   nUpdated              NUMBER(8)     ;
   nRange                NUMBER(8)     ;
   MissDoc               NUMBER(8)     ;
   nFound                NUMBER(3)     ;
--
   sTS_RowID_Old         VARCHAR2(100) ;
   sInvoice_Date_Old     VARCHAR2(100) ;
   sTS_Resource_Old      VARCHAR2(100) ;
   sTerritorio_Old       VARCHAR2(100) ;
   nSequence_Number_Old  NUMBER(8)     ;
   sRule_Rugex_Old       VARCHAR2(100) ;
   sModifiedDate_Old     VARCHAR2(100) ;
   sTS_RowID_New         VARCHAR2(100) ;
   sInvoice_Date_New     VARCHAR2(100) ;
   sTS_Resource_New      VARCHAR2(100) ;
   sTerritorio_New       VARCHAR2(100) ;
   nSequence_Number_New  NUMBER(8)     ;
   sRule_Rugex_New       VARCHAR2(100) ;
   sModifiedDate_New     VARCHAR2(100) ;
   sFolio                VARCHAR2(010) ;
--
BEGIN
   nRows         := 0      ;
   nFailures     := 0      ;
   nNotUpdated   := 0      ;
   nUpdated      := 0      ;
   sTS_RowID_Old := 'Init' ;
   nSequence_Number_Old := 0 ;
--   
   FOR Seq IN ScrInfo LOOP
      nRows         := nRows + 1        ;
      v_ID          := Seq.Territorio   ;
      sTerritorio   := Seq.Territorio   ;
      sInvoice_Date := Seq.Invoice_Date ;
      nRange        := Seq.Doctos - ( Seq.Max_Folio - Seq.Min_Folio + 1 ) ;
      IF ( NVL( pOutput, 0 ) > 0 ) THEN
         DBMS_Output.Put_Line( 
                                    'Territory -> '    || Seq.Territorio                 || '. ' || 
                                    'Invoice_Date -> ' || Seq.Invoice_Date               || '. ' || 
                                    'Missing -> '      || LPAD( ABS( nRange ), 4, ' ' )  || '. ' || 
                                    'Resource -> '     || Seq.ResourceName                  ) ;
         DBMS_Output.Put_Line( 'Seq.Doctos    = ' || Seq.Doctos    || '. ' ||
                               'Seq.Min_Folio = ' || Seq.Min_Folio || '. ' ||  
                               'Seq.Max_Folio = ' || Seq.Max_Folio           ) ;           
      END IF ;                             
      UPDATE EAI_Owner.Missing_Documents SET Updated = SYSDATE, DocumentsUpd = ABS( nRange )
         WHERE Doc_Type      = 'V'         
           AND Territory     = sTerritorio 
           AND Document_Date = TO_DATE( sInvoice_Date, 'YYYY-MM-DD' ) ;
      nFound := SQL%ROWCOUNT ;
      IF ( nFound = 0 ) THEN
         INSERT INTO EAI_Owner.Missing_Documents ( Doc_Type, Territory, Documents, Document_Date, ResourceName, Created )
            VALUES ( 'V', sTerritorio, ABS( nRange ) , TO_DATE( sInvoice_Date, 'YYYY-MM-DD' ), Seq.ResourceName, SYSDATE ) ;
      END IF ;      
      sTS_RowID_Old := 'Init' ;                              
      FOR Doc IN ScrTransactionLost LOOP
         IF ( Doc.Doc_Is_Number = 'PASS' ) THEN
            IF ( sTS_RowID_Old != Doc.Doc_Terr ) THEN
               nSequence_Number_Old := Doc.Doc_Folio - 1 ;
               sTS_RowID_Old        := Doc.Doc_Terr      ;
            END IF ;
            nSequence_Number_Old := nSequence_Number_Old + 1 ;
            IF ( NVL( pOutput, 0 ) > 100 ) AND ( sTerritorio = '1642' ) THEN
               DBMS_Output.Put_Line( '  nSequence_Number_Old = ' || nSequence_Number_Old || '. Doc_Folio = ' || TRIM( TO_CHAR( Doc.Doc_Folio) ) ) ;
            END IF ;
            IF ( nSequence_Number_Old != Doc.Doc_Folio ) THEN
               nRange := Doc.Doc_Folio - nSequence_Number_Old ;
               IF ( nRange > 0 ) AND ( nRange < 30 ) THEN
                  FOR MissDoc IN 1..nRange LOOP
                     nFailures := nFailures + 1 ;
                     IF ( NVL( pOutput, 0 ) > 5 ) THEN
                        DBMS_Output.Put_Line( '  Search for V' || sTerritorio || '-' || TRIM( TO_CHAR( nSequence_Number_Old ) ) ) ;
                     END IF ;   
                     IF ( nSequence_Number_Old  < 100000 ) THEN
                        sFolio := LPAD( nSequence_Number_Old, 5, '0' ) ;
                     ELSE
                        sFolio := TRIM( TO_CHAR( nSequence_Number_Old ) ) ;
                     END IF ;
                     UPDATE EAI_Owner.Missing_Documents_Detail SET Updated = SYSDATE
                        WHERE Doc_Num = 'V' || sTerritorio || '-' || sFolio ;
                     nFound := SQL%ROWCOUNT ;
                     IF ( nFound = 0 ) THEN
                        INSERT INTO EAI_Owner.Missing_Documents_Detail ( Doc_Num, Document_Date, Created )
                        VALUES
                           ( 'V' || sTerritorio || '-' || sFolio,
                             TO_DATE( sInvoice_Date, 'YYYY-MM-DD' ), SYSDATE ) ;
                     END IF ;
                     nSequence_Number_Old := nSequence_Number_Old + 1 ;
                  END LOOP ;   
               END IF ;   
            END IF ;
         END IF ;
      END LOOP ;
   END LOOP ;
   DBMS_Output.Put_Line( '--------------------------------' ) ;
   DBMS_Output.Put_Line( 'Reps Reviewed -> ' || nRows       ) ;
   DBMS_Output.Put_Line( 'Failures      -> ' || nFailures   ) ;
--  
   sTerritorio_Old := 'Init' ;
   nFailures       := 0      ;
   FOR Seq IN ScrDayBefore LOOP 
      IF ( NVL( pOutput, 0 ) > 100 ) THEN
           DBMS_Output.Put_Line( Seq.TS_Row_ID ) ;
      END IF ;     
      IF ( sTerritorio_Old != Seq.Territorio ) THEN
         sTS_RowID_Old         := Seq.TS_Row_ID        ;
         sInvoice_Date_Old     := Seq.Invoice_Date     ;
         sTS_Resource_Old      := Seq.Resource_Name    ;
         sTerritorio_Old       := Seq.Territorio       ;
         nSequence_Number_Old  := Seq.Max_Folio        ;
      ELSE
         nSequence_Number_New  := Seq.Min_Folio        ;
         nRange := nSequence_Number_New - ( nSequence_Number_Old + 1 ) ;
         IF    ( nRange != 0 ) THEN
              nFailures := nFailures + 1 ;
              IF ( NVL( pOutput, 0 ) > 0 ) THEN
                 DBMS_Output.Put_Line( 
                                    'Rule_Rugex -> ' || sTerritorio_Old                 || '. '   || 
                                    'Sequence -> '   || LPAD( nSequence_Number_Old, 6 ) || ' -> ' || LPAD( nSequence_Number_New, 6 ) || '. ' ||
                                    'Updated -> '    || Seq.Invoice_Date                || '. '   ||                                     
                                    'Resource -> '   || sTS_Resource_Old                  ) ; 
              END IF ;                      
              UPDATE EAI_Owner.Sequence_Errors SET Updated = SYSDATE
                 WHERE Doc_Type     = 'V'
                   AND Territory    = sTerritorio_Old
                   AND Invoice_Date = TO_DATE( Seq.Invoice_Date, 'YYYY-MM-DD' ) ;
              nFound := SQL%ROWCOUNT ;
              IF ( nFound = 0 ) THEN
                 INSERT INTO EAI_Owner.Sequence_Errors
                    ( Doc_Type, Territory, Starts_With, Ends_With,
                      Invoice_Date, Resource_Name, Created )
                 VALUES
                    ( 'V', sTerritorio_Old, nSequence_Number_New, nSequence_Number_Old, 
                      TO_DATE( Seq.Invoice_Date, 'YYYY-MM-DD' ), sTS_Resource_Old, SYSDATE ) ;
              END IF ;    
         END IF ;
--       
         sTS_Resource_Old      := Seq.Resource_Name    ;
         nSequence_Number_Old  := Seq.Max_Folio        ;
      END IF ; 
   END LOOP ;
   DBMS_Output.Put_Line( 'Failures Date -> ' || nFailures ) ;
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
          'Error'             , 'WA_ERR_SEQUENCE'    , sMsg                , 'PL/SQL'       ,
          sErrorCode          , NULL                 , NULL                , NULL            ) ;
      COMMIT ;   
END WA_ERR_SEQUENCE ;