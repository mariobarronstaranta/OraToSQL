CREATE OR ALTER PROCEDURE [EAI_Owner].[WA_ERR_SEQUENCE]
(
    @pDays      INT = 1,
    @pDiffHours INT = 5, -- Se conserva por compatibilidad. En Oracle no se utiliza.
    @pOutput    INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID              VARCHAR(50)  = NULL,
        @sErrorCode        VARCHAR(30),
        @sMsg              VARCHAR(300),
        @nRows             INT = 0,
        @nFailures         INT = 0,
        @nFailuresDate     INT = 0;

    BEGIN TRY
        BEGIN TRAN;

        DROP TABLE IF EXISTS #ValidDocs;
        DROP TABLE IF EXISTS #Seq;
        DROP TABLE IF EXISTS #SeqAgg;
        DROP TABLE IF EXISTS #MissingCandidates;
        DROP TABLE IF EXISTS #DayBefore;
        DROP TABLE IF EXISTS #SequenceDateErrors;

        /*
            Base normalizada.
            Reemplaza:
            - SUBSTR       -> SUBSTRING
            - TO_NUMBER    -> TRY_CONVERT
            - TO_CHAR date -> TRY_CONVERT(date)
            - Func_is_Number -> TRY_CONVERT(...) IS NOT NULL
        */
        SELECT
            Inv.ID AS Doc_ID,
            Inv.Name AS Doc_Name,
            Inv.Doc_Num,
            SUBSTRING(Inv.Doc_Num, 2, 4) AS Doc_Terr,
            SUBSTRING(Inv.Doc_Num, 7, 10) AS Doc_Folio_Text,
            TRY_CONVERT(INT, SUBSTRING(Inv.Doc_Num, 7, 10)) AS Doc_Folio,
            REPLACE(REPLACE(CONVERT(VARCHAR(100), Inv.Created_Date), '.000Z', ''), 'T', ' ') AS CreatedDate,
            TRY_CONVERT(DATE, Inv.Invc_dt, 23) AS Invoice_Date,
            Inv.Invc_Status,
            Inv.Delivery_Status,
            Inv.Extract_dt AS ExtractedDate,
            Inv.Recurso AS ResourceName
        INTO #ValidDocs
        FROM [EAI_Owner].[Facturas_B] Inv
        WHERE TRY_CONVERT(DATE, Inv.Invc_dt, 23) >= DATEADD(DAY, -COALESCE(@pDays, 1), CONVERT(DATE, GETDATE()))
          AND SUBSTRING(Inv.Doc_Num, 6, 1) = '-'
          AND TRY_CONVERT(BIGINT, SUBSTRING(Inv.Doc_Num, 7, 8)) IS NOT NULL
          AND TRY_CONVERT(INT, SUBSTRING(Inv.Doc_Num, 7, 10)) IS NOT NULL;

        /*
            Equivalente del cursor ScrInfo:
            Detecta grupos donde el número de documentos no coincide con
            Max_Folio - Min_Folio + 1.
        */
        SELECT
            Doc.Doc_Terr AS Territory,
            Doc.Invoice_Date,
            Doc.ResourceName,
            COUNT(DISTINCT Doc.Doc_Num) AS Doctos,
            MIN(Doc.Doc_Folio) AS Min_Folio,
            MAX(Doc.Doc_Folio) AS Max_Folio,
            MIN(Doc.CreatedDate) AS Min_CreatedDate,
            MAX(Doc.CreatedDate) AS Max_CreatedDate,
            (MAX(Doc.Doc_Folio) - MIN(Doc.Doc_Folio) + 1) AS Doc_x_Folios,
            ABS(COUNT(DISTINCT Doc.Doc_Num) - (MAX(Doc.Doc_Folio) - MIN(Doc.Doc_Folio) + 1)) AS Missing_Documents
        INTO #Seq
        FROM #ValidDocs Doc
        GROUP BY
            Doc.Doc_Terr,
            Doc.Invoice_Date,
            Doc.ResourceName
        HAVING COUNT(DISTINCT Doc.Doc_Num) <> (MAX(Doc.Doc_Folio) - MIN(Doc.Doc_Folio) + 1);

        SELECT @nRows = COUNT(*) FROM #Seq;

        IF COALESCE(@pOutput, 0) > 0
        BEGIN
            SELECT
                'Territory -> ' + Territory
                + '. Invoice_Date -> ' + CONVERT(VARCHAR(10), Invoice_Date, 23)
                + '. Missing -> ' + RIGHT(REPLICATE(' ', 4) + CONVERT(VARCHAR(20), Missing_Documents), 4)
                + '. Resource -> ' + COALESCE(ResourceName, '') AS OutputMessage,
                Doctos,
                Min_Folio,
                Max_Folio
            FROM #Seq
            ORDER BY Invoice_Date, Territory;
        END;

        /*
            La tabla Missing_Documents parece tener una fila por:
            Doc_Type + Territory + Document_Date.
            Si hay varios recursos para el mismo territorio/fecha, se consolida.
        */
        SELECT
            Territory,
            Invoice_Date,
            MAX(ResourceName) AS ResourceName,
            SUM(Missing_Documents) AS Missing_Documents
        INTO #SeqAgg
        FROM #Seq
        GROUP BY
            Territory,
            Invoice_Date;

        UPDATE MD
            SET
                MD.Updated = GETDATE(),
                MD.DocumentsUpd = S.Missing_Documents
        FROM [EAI_Owner].[Missing_Documents] MD
        INNER JOIN #SeqAgg S
            ON MD.Doc_Type = 'V'
           AND MD.Territory = S.Territory
           AND MD.Document_Date = S.Invoice_Date;

        INSERT INTO [EAI_Owner].[Missing_Documents]
        (
            Doc_Type,
            Territory,
            Documents,
            Document_Date,
            ResourceName,
            Created
        )
        SELECT
            'V',
            S.Territory,
            S.Missing_Documents,
            S.Invoice_Date,
            S.ResourceName,
            GETDATE()
        FROM #SeqAgg S
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_Owner].[Missing_Documents] MD
            WHERE MD.Doc_Type = 'V'
              AND MD.Territory = S.Territory
              AND MD.Document_Date = S.Invoice_Date
        );

        /*
            Equivalente mejorado de ScrTransactionLost:
            Usa LAG para detectar huecos entre folios consecutivos.
            El Oracle sólo inserta faltantes cuando el gap es > 0 y < 30.
        */
        ;WITH OrderedDocs AS
        (
            SELECT
                V.Doc_Terr AS Territory,
                V.Invoice_Date,
                V.Doc_Num,
                V.Doc_Folio,
                LAG(V.Doc_Folio) OVER
                (
                    PARTITION BY V.Doc_Terr, V.Invoice_Date
                    ORDER BY
                        V.Invoice_Date,
                        SUBSTRING(V.Doc_Num, 1, 6)
                        + RIGHT(REPLICATE('0', 10) + CONVERT(VARCHAR(20), V.Doc_Folio), 10)
                ) AS Prev_Folio
            FROM #ValidDocs V
            WHERE EXISTS
            (
                SELECT 1
                FROM #Seq S
                WHERE S.Territory = V.Doc_Terr
                  AND S.Invoice_Date = V.Invoice_Date
            )
        ),
        Gaps AS
        (
            SELECT
                Territory,
                Invoice_Date,
                Prev_Folio,
                Doc_Folio,
                Doc_Folio - (Prev_Folio + 1) AS Gap_Count
            FROM OrderedDocs
            WHERE Prev_Folio IS NOT NULL
              AND Doc_Folio - (Prev_Folio + 1) > 0
              AND Doc_Folio - (Prev_Folio + 1) < 30
        ),
        N AS
        (
            SELECT TOP (30)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects
        )
        SELECT
            G.Territory,
            G.Invoice_Date,
            G.Prev_Folio + N.n AS Missing_Folio,
            'V' + G.Territory + '-' +
                CASE
                    WHEN G.Prev_Folio + N.n < 100000
                        THEN RIGHT(REPLICATE('0', 5) + CONVERT(VARCHAR(20), G.Prev_Folio + N.n), 5)
                    ELSE CONVERT(VARCHAR(20), G.Prev_Folio + N.n)
                END AS Doc_Num
        INTO #MissingCandidates
        FROM Gaps G
        INNER JOIN N
            ON N.n <= G.Gap_Count;

        SELECT @nFailures = COUNT(*) FROM #MissingCandidates;

        IF COALESCE(@pOutput, 0) > 5
        BEGIN
            SELECT 'Search for ' + Doc_Num AS OutputMessage
            FROM #MissingCandidates
            ORDER BY Territory, Invoice_Date, Missing_Folio;
        END;

        UPDATE MDD
            SET MDD.Updated = GETDATE()
        FROM [EAI_Owner].[Missing_Documents_Detail] MDD
        INNER JOIN #MissingCandidates MC
            ON MDD.Doc_Num = MC.Doc_Num;

        INSERT INTO [EAI_Owner].[Missing_Documents_Detail]
        (
            Doc_Num,
            Document_Date,
            Created
        )
        SELECT
            MC.Doc_Num,
            MC.Invoice_Date,
            GETDATE()
        FROM #MissingCandidates MC
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_Owner].[Missing_Documents_Detail] MDD
            WHERE MDD.Doc_Num = MC.Doc_Num
        );

        /*
            Equivalente de ScrDayBefore:
            Revisa continuidad entre grupos por territorio, ordenados por fecha.
        */
        SELECT
            Doc.Doc_Terr + CONVERT(VARCHAR(10), Doc.Invoice_Date, 23) AS TS_Row_ID,
            Doc.Doc_Terr AS Territory,
            Doc.Invoice_Date,
            Doc.ResourceName AS Resource_Name,
            COUNT(DISTINCT Doc.Doc_Num) AS Doctos,
            MIN(Doc.Doc_Folio) AS Min_Folio,
            MAX(Doc.Doc_Folio) AS Max_Folio,
            (MAX(Doc.Doc_Folio) - MIN(Doc.Doc_Folio) + 1) AS Doc_x_Folios
        INTO #DayBefore
        FROM #ValidDocs Doc
        GROUP BY
            Doc.Doc_Terr,
            Doc.Invoice_Date,
            Doc.ResourceName;

        ;WITH DaySeq AS
        (
            SELECT
                DB.*,
                LAG(DB.Max_Folio) OVER
                (
                    PARTITION BY DB.Territory
                    ORDER BY DB.Invoice_Date, DB.TS_Row_ID
                ) AS Prev_Max_Folio,
                LAG(DB.Resource_Name) OVER
                (
                    PARTITION BY DB.Territory
                    ORDER BY DB.Invoice_Date, DB.TS_Row_ID
                ) AS Prev_Resource_Name
            FROM #DayBefore DB
        )
        SELECT
            Territory,
            Invoice_Date,
            Resource_Name,
            Prev_Resource_Name,
            Min_Folio,
            Prev_Max_Folio,
            Min_Folio - (Prev_Max_Folio + 1) AS Range_Diff
        INTO #SequenceDateErrors
        FROM DaySeq
        WHERE Prev_Max_Folio IS NOT NULL
          AND Min_Folio - (Prev_Max_Folio + 1) <> 0;

        SELECT @nFailuresDate = COUNT(*) FROM #SequenceDateErrors;

        IF COALESCE(@pOutput, 0) > 0
        BEGIN
            SELECT
                'Rule_Rugex -> ' + Territory
                + '. Sequence -> ' + RIGHT(REPLICATE(' ', 6) + CONVERT(VARCHAR(20), Prev_Max_Folio), 6)
                + ' -> ' + RIGHT(REPLICATE(' ', 6) + CONVERT(VARCHAR(20), Min_Folio), 6)
                + '. Updated -> ' + CONVERT(VARCHAR(10), Invoice_Date, 23)
                + '. Resource -> ' + COALESCE(Prev_Resource_Name, Resource_Name, '') AS OutputMessage
            FROM #SequenceDateErrors
            ORDER BY Territory, Invoice_Date;
        END;

        UPDATE SE
            SET SE.Updated = GETDATE()
        FROM [EAI_Owner].[Sequence_Errors] SE
        INNER JOIN #SequenceDateErrors E
            ON SE.Doc_Type = 'V'
           AND SE.Territory = E.Territory
           AND SE.Invoice_Date = E.Invoice_Date;

        INSERT INTO [EAI_Owner].[Sequence_Errors]
        (
            Doc_Type,
            Territory,
            Starts_With,
            Ends_With,
            Invoice_Date,
            Resource_Name,
            Created
        )
        SELECT
            'V',
            E.Territory,
            E.Min_Folio,
            E.Prev_Max_Folio,
            E.Invoice_Date,
            COALESCE(E.Prev_Resource_Name, E.Resource_Name),
            GETDATE()
        FROM #SequenceDateErrors E
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_Owner].[Sequence_Errors] SE
            WHERE SE.Doc_Type = 'V'
              AND SE.Territory = E.Territory
              AND SE.Invoice_Date = E.Invoice_Date
        );

        IF COALESCE(@pOutput, 0) > 0
        BEGIN
            PRINT '--------------------------------';
            PRINT 'Reps Reviewed -> ' + CONVERT(VARCHAR(20), @nRows);
            PRINT 'Failures      -> ' + CONVERT(VARCHAR(20), @nFailures);
            PRINT 'Failures Date -> ' + CONVERT(VARCHAR(20), @nFailuresDate);
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = 'SQL-' + CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(20), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'WA Transaction Seq',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'WA_ERR_SEQUENCE',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;
    END CATCH
END;
GO