/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_SEQUENCE (Oracle).

    Objetivo:
      1. Detectar huecos de folios dentro de un territorio, fecha y recurso.
      2. Registrar el resumen en MISSING_DOCUMENTS y cada folio faltante en
         MISSING_DOCUMENTS_DETAIL cuando el salto sea menor de 30.
      3. Detectar discontinuidades entre grupos consecutivos de un territorio
         y registrarlas en SEQUENCE_ERRORS.

    Se utilizan cursores LOCAL FAST_FORWARD porque el procedimiento Oracle
    modifica las tablas fila por fila y el resultado de cada UPDATE determina
    si debe ejecutarse un INSERT. Este orden tambien evita consolidar recursos
    o crear duplicados que no produciria el procedimiento original.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_SEQUENCE]
(
    @pDays      INT = 1,
    /* Se conserva por compatibilidad: Oracle declara pDiffHours pero no lo usa. */
    @pDiffHours INT = 5,
    @pOutput    INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Oracle registra la excepcion y confirma el trabajo previo. */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @v_ID             VARCHAR(50) = NULL,
        @nRows            INT = 0,
        @nFailures        INT = 0,
        @nRange           BIGINT,
        @nFound           INT,
        @sTerritorio      VARCHAR(30),
        @sInvoiceDate     VARCHAR(30),
        @sResourceName    VARCHAR(100),
        @nDoctos          INT,
        @nMinFolio        BIGINT,
        @nMaxFolio        BIGINT,
        @sTSRowIDOld      VARCHAR(100) = 'Init',
        @sTerritorioOld   VARCHAR(100),
        @sResourceOld     VARCHAR(100),
        @nSequenceOld     BIGINT = 0,
        @nSequenceNew     BIGINT,
        @sDocTerr         VARCHAR(30),
        @sDocFolioText    VARCHAR(10),
        @nDocFolio        BIGINT,
        @bDocIsNumber     BIT,
        @nMissCounter     INT,
        @sFolio           VARCHAR(10),
        @sDayTerritorio   VARCHAR(30),
        @sDayInvoiceDate  VARCHAR(30),
        @sDayResource     VARCHAR(100),
        @nDayMinFolio     BIGINT,
        @nDayMaxFolio     BIGINT,
        @FechaCorteTexto  CHAR(10);

    /*
        Oracle compara INVC_DT (texto) contra YYYY-MM-DD. Se conserva esa
        comparacion lexicografica y las conversiones a DATE se hacen solamente
        al escribir en las tablas destino, igual que TO_DATE en el origen.
    */
    SET @FechaCorteTexto = CONVERT
    (
        CHAR(10),
        DATEADD(DAY, -COALESCE(@pDays, 1), SYSDATETIME()),
        23
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------------
        -- 1. Grupos con huecos internos: equivalente al cursor ScrInfo.
        ----------------------------------------------------------------------
        DECLARE ScrInfo CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                SUBSTRING(Inv.Doc_Num, 2, 4) AS Territorio,
                CONVERT(VARCHAR(30), Inv.Invc_dt) AS Invoice_Date,
                CONVERT(VARCHAR(100), Inv.Recurso) AS ResourceName,
                COUNT(DISTINCT Inv.Doc_Num) AS Doctos,
                MIN(F.Doc_Folio) AS Min_Folio,
                MAX(F.Doc_Folio) AS Max_Folio
            FROM [EAI_OWNER].[FACTURAS_B] AS Inv
            CROSS APPLY
            (
                SELECT Doc_Folio = CONVERT
                (
                    BIGINT,
                    CASE
                        WHEN TRY_CONVERT
                             (BIGINT, SUBSTRING(Inv.Doc_Num, 7, 8)) IS NOT NULL
                            THEN SUBSTRING(Inv.Doc_Num, 7, 10)
                        ELSE NULL
                    END
                )
            ) AS F
            WHERE Inv.Invc_dt >= @FechaCorteTexto
              AND SUBSTRING(Inv.Doc_Num, 6, 1) = '-'
              /* Equivale a T3.Func_is_Number sobre los primeros 8 digitos. */
              AND F.Doc_Folio IS NOT NULL
            GROUP BY
                SUBSTRING(Inv.Doc_Num, 2, 4),
                Inv.Invc_dt,
                Inv.Recurso
            HAVING COUNT(DISTINCT Inv.Doc_Num)
                   <> MAX(F.Doc_Folio) - MIN(F.Doc_Folio) + 1
            ORDER BY
                Inv.Invc_dt,
                SUBSTRING(Inv.Doc_Num, 2, 4);

        OPEN ScrInfo;

        FETCH NEXT FROM ScrInfo INTO
            @sTerritorio,
            @sInvoiceDate,
            @sResourceName,
            @nDoctos,
            @nMinFolio,
            @nMaxFolio;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @nRows = @nRows + 1;
            SET @v_ID = @sTerritorio;
            SET @nRange = @nDoctos - (@nMaxFolio - @nMinFolio + 1);

            IF COALESCE(@pOutput, 0) > 0
            BEGIN
                PRINT CONCAT
                (
                    'Territory -> ', @sTerritorio, '. ',
                    'Invoice_Date -> ', @sInvoiceDate, '. ',
                    'Missing -> ',
                    RIGHT(REPLICATE(' ', 4) + CONVERT(VARCHAR(20), ABS(@nRange)), 4),
                    '. Resource -> ', @sResourceName
                );
                PRINT CONCAT
                (
                    'Seq.Doctos    = ', @nDoctos, '. ',
                    'Seq.Min_Folio = ', @nMinFolio, '. ',
                    'Seq.Max_Folio = ', @nMaxFolio
                );
            END;

            /* Oracle actualiza primero; solamente inserta si no encontro fila. */
            UPDATE [EAI_OWNER].[MISSING_DOCUMENTS]
               SET Updated = SYSDATETIME(),
                   DocumentsUpd = ABS(@nRange)
            WHERE Doc_Type = 'V'
              AND Territory = @sTerritorio
              AND Document_Date = CONVERT(date, @sInvoiceDate, 23);

            SET @nFound = @@ROWCOUNT;

            IF @nFound = 0
            BEGIN
                INSERT INTO [EAI_OWNER].[MISSING_DOCUMENTS]
                (
                    Doc_Type,
                    Territory,
                    Documents,
                    Document_Date,
                    ResourceName,
                    Created
                )
                VALUES
                (
                    'V',
                    @sTerritorio,
                    ABS(@nRange),
                    CONVERT(date, @sInvoiceDate, 23),
                    @sResourceName,
                    SYSDATETIME()
                );
            END;

            ------------------------------------------------------------------
            -- 1.1 Localizar los folios faltantes del grupo actual.
            ------------------------------------------------------------------
            SET @sTSRowIDOld = 'Init';

            DECLARE ScrTransactionLost CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    SUBSTRING(Inv.Doc_Num, 2, 4) AS Doc_Terr,
                    SUBSTRING(Inv.Doc_Num, 7, 10) AS Doc_Folio,
                    CASE
                        WHEN TRY_CONVERT(BIGINT, SUBSTRING(Inv.Doc_Num, 7, 8))
                             IS NOT NULL THEN 1
                        ELSE 0
                    END AS Doc_Is_Number
                FROM [EAI_OWNER].[FACTURAS_B] AS Inv
                WHERE Inv.Invc_dt = @sInvoiceDate
                  AND SUBSTRING(Inv.Doc_Num, 6, 1) = '-'
                  AND SUBSTRING(Inv.Doc_Num, 2, 4) = @sTerritorio
                ORDER BY
                    Inv.Invc_dt,
                    SUBSTRING(Inv.Doc_Num, 1, 6)
                    + RIGHT(REPLICATE('0', 10)
                            + SUBSTRING(Inv.Doc_Num, 7, 10), 10);

            OPEN ScrTransactionLost;

            FETCH NEXT FROM ScrTransactionLost INTO
                @sDocTerr,
                @sDocFolioText,
                @bDocIsNumber;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @bDocIsNumber = 1
                BEGIN
                    /*
                        La conversion usa los 10 caracteres, tal como TO_NUMBER.
                        Si los dos ultimos no son numericos, debe ocurrir error.
                    */
                    SET @nDocFolio = CONVERT(BIGINT, @sDocFolioText);

                    IF @sTSRowIDOld <> @sDocTerr
                    BEGIN
                        SET @nSequenceOld = @nDocFolio - 1;
                        SET @sTSRowIDOld = @sDocTerr;
                    END;

                    SET @nSequenceOld = @nSequenceOld + 1;

                    IF COALESCE(@pOutput, 0) > 100
                       AND @sTerritorio = '1642'
                    BEGIN
                        PRINT CONCAT
                        (
                            '  nSequence_Number_Old = ', @nSequenceOld,
                            '. Doc_Folio = ', @nDocFolio
                        );
                    END;

                    IF @nSequenceOld <> @nDocFolio
                    BEGIN
                        SET @nRange = @nDocFolio - @nSequenceOld;

                        /* El origen solo detalla saltos positivos menores de 30. */
                        IF @nRange > 0 AND @nRange < 30
                        BEGIN
                            SET @nMissCounter = 1;

                            WHILE @nMissCounter <= @nRange
                            BEGIN
                                SET @nFailures = @nFailures + 1;

                                IF COALESCE(@pOutput, 0) > 5
                                    PRINT CONCAT
                                    (
                                        '  Search for V', @sTerritorio, '-',
                                        @nSequenceOld
                                    );

                                SET @sFolio = CASE
                                    WHEN @nSequenceOld < 100000
                                        THEN RIGHT('00000'
                                                   + CONVERT(VARCHAR(20), @nSequenceOld), 5)
                                    ELSE CONVERT(VARCHAR(10), @nSequenceOld)
                                END;

                                UPDATE [EAI_OWNER].[MISSING_DOCUMENTS_DETAIL]
                                   SET Updated = SYSDATETIME()
                                WHERE Doc_Num = CONCAT
                                      ('V', @sTerritorio, '-', @sFolio);

                                SET @nFound = @@ROWCOUNT;

                                IF @nFound = 0
                                BEGIN
                                    INSERT INTO [EAI_OWNER].[MISSING_DOCUMENTS_DETAIL]
                                    (
                                        Doc_Num,
                                        Document_Date,
                                        Created
                                    )
                                    VALUES
                                    (
                                        CONCAT('V', @sTerritorio, '-', @sFolio),
                                        CONVERT(date, @sInvoiceDate, 23),
                                        SYSDATETIME()
                                    );
                                END;

                                SET @nSequenceOld = @nSequenceOld + 1;
                                SET @nMissCounter = @nMissCounter + 1;
                            END;
                        END;
                    END;
                END;

                FETCH NEXT FROM ScrTransactionLost INTO
                    @sDocTerr,
                    @sDocFolioText,
                    @bDocIsNumber;
            END;

            CLOSE ScrTransactionLost;
            DEALLOCATE ScrTransactionLost;

            FETCH NEXT FROM ScrInfo INTO
                @sTerritorio,
                @sInvoiceDate,
                @sResourceName,
                @nDoctos,
                @nMinFolio,
                @nMaxFolio;
        END;

        CLOSE ScrInfo;
        DEALLOCATE ScrInfo;

        /* Oracle siempre muestra estos totales, incluso con pOutput = 0. */
        PRINT '--------------------------------';
        PRINT CONCAT('Reps Reviewed -> ', @nRows);
        PRINT CONCAT('Failures      -> ', @nFailures);

        ----------------------------------------------------------------------
        -- 2. Discontinuidades entre fechas: equivalente a ScrDayBefore.
        ----------------------------------------------------------------------
        SET @sTerritorioOld = 'Init';
        SET @nFailures = 0;

        DECLARE ScrDayBefore CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                SUBSTRING(Inv.Doc_Num, 2, 4) AS Territorio,
                CONVERT(VARCHAR(30), Inv.Invc_dt) AS Invoice_Date,
                CONVERT(VARCHAR(100), Inv.Recurso) AS Resource_Name,
                MIN(F.Doc_Folio) AS Min_Folio,
                MAX(F.Doc_Folio) AS Max_Folio
            FROM [EAI_OWNER].[FACTURAS_B] AS Inv
            CROSS APPLY
            (
                SELECT Doc_Folio = CONVERT
                (
                    BIGINT,
                    CASE
                        WHEN TRY_CONVERT
                             (BIGINT, SUBSTRING(Inv.Doc_Num, 7, 8)) IS NOT NULL
                            THEN SUBSTRING(Inv.Doc_Num, 7, 10)
                        ELSE NULL
                    END
                )
            ) AS F
            WHERE Inv.Invc_dt >= @FechaCorteTexto
              AND SUBSTRING(Inv.Doc_Num, 6, 1) = '-'
              AND F.Doc_Folio IS NOT NULL
            GROUP BY
                SUBSTRING(Inv.Doc_Num, 2, 4),
                Inv.Invc_dt,
                Inv.Recurso
            ORDER BY
                SUBSTRING(Inv.Doc_Num, 2, 4),
                Inv.Invc_dt;

        OPEN ScrDayBefore;

        FETCH NEXT FROM ScrDayBefore INTO
            @sDayTerritorio,
            @sDayInvoiceDate,
            @sDayResource,
            @nDayMinFolio,
            @nDayMaxFolio;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF COALESCE(@pOutput, 0) > 100
                PRINT CONCAT(@sDayTerritorio, @sDayInvoiceDate);

            IF @sTerritorioOld <> @sDayTerritorio
            BEGIN
                SET @sTerritorioOld = @sDayTerritorio;
                SET @sResourceOld = @sDayResource;
                SET @nSequenceOld = @nDayMaxFolio;
            END
            ELSE
            BEGIN
                SET @nSequenceNew = @nDayMinFolio;
                SET @nRange = @nSequenceNew - (@nSequenceOld + 1);

                IF @nRange <> 0
                BEGIN
                    SET @nFailures = @nFailures + 1;

                    IF COALESCE(@pOutput, 0) > 0
                    BEGIN
                        PRINT CONCAT
                        (
                            'Rule_Rugex -> ', @sTerritorioOld, '. ',
                            'Sequence -> ',
                            RIGHT(REPLICATE(' ', 6)
                                  + CONVERT(VARCHAR(20), @nSequenceOld), 6),
                            ' -> ',
                            RIGHT(REPLICATE(' ', 6)
                                  + CONVERT(VARCHAR(20), @nSequenceNew), 6),
                            '. Updated -> ', @sDayInvoiceDate, '. ',
                            'Resource -> ', @sResourceOld
                        );
                    END;

                    UPDATE [EAI_OWNER].[SEQUENCE_ERRORS]
                       SET Updated = SYSDATETIME()
                    WHERE Doc_Type = 'V'
                      AND Territory = @sTerritorioOld
                      AND Invoice_Date = CONVERT(date, @sDayInvoiceDate, 23);

                    SET @nFound = @@ROWCOUNT;

                    IF @nFound = 0
                    BEGIN
                        INSERT INTO [EAI_OWNER].[SEQUENCE_ERRORS]
                        (
                            Doc_Type,
                            Territory,
                            Starts_With,
                            Ends_With,
                            Invoice_Date,
                            Resource_Name,
                            Created
                        )
                        VALUES
                        (
                            'V',
                            @sTerritorioOld,
                            @nSequenceNew,
                            @nSequenceOld,
                            CONVERT(date, @sDayInvoiceDate, 23),
                            @sResourceOld,
                            SYSDATETIME()
                        );
                    END;
                END;

                SET @sResourceOld = @sDayResource;
                SET @nSequenceOld = @nDayMaxFolio;
            END;

            FETCH NEXT FROM ScrDayBefore INTO
                @sDayTerritorio,
                @sDayInvoiceDate,
                @sDayResource,
                @nDayMinFolio,
                @nDayMaxFolio;
        END;

        CLOSE ScrDayBefore;
        DEALLOCATE ScrDayBefore;

        PRINT CONCAT('Failures Date -> ', @nFailures);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Si la transaccion esta condenada debe revertirse. Si sigue siendo
            confirmable, el COMMIT inferior conserva el trabajo previo, igual
            que el bloque WHEN OTHERS de Oracle.
        */
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            [Sequence],
            Parent_Row_ID
        )
        VALUES
        (
            'WA Transaction Seq',
            @v_ID,
            SYSDATETIME(),
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

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y finaliza sin volver a lanzarlo.
        RETURN;
    END CATCH;
END;
GO
