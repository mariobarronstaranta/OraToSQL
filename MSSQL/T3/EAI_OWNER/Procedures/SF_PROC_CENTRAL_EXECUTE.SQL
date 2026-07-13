CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_EXECUTE]
(
      @nDays       INT        = 28
    , @sFiscalYear VARCHAR(4) = NULL
    , @nPID        NUMERIC(10,0) = NULL
    , @pOutput     INT        = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @sMsg                    VARCHAR(500)
        , @v_ID                    VARCHAR(30)
        , @sErrorCode              VARCHAR(20)
        , @sClearingDocNumber      VARCHAR(20)
        , @nRecords                INT = 0
        , @nMargen                 DECIMAL(5,2) = 1.5
        , @dtCreatedFrom           DATETIME2(0)
        , @dtCreatedTo             DATETIME2(0);

    /*
        Developer notes:
        - Conversion from ORA/T3/EAI_OWNER/Procedures/SF_PROC_CENTRAL_EXECUTE.SQL.
        - Keeps the Oracle rule set over EAI_OWNER.TMP_ACCOUNT_HEADER:
          processed rows are grouped by ClearingDocNumber and routed to payment,
          credit discard, credit allocation or the 4-row Z9 workaround.
        - Oracle commented filters remain disabled here:
          FiscalYear, Assignment and Reversal are intentionally not filtered.
        - Oracle LPAD(IDocNumber,16,'0') is implemented with RIGHT(REPLICATE...).
        - Oracle SUBSTR(...,7,10) is implemented with SUBSTRING(...,7,10).
        - Oracle exception behavior logs to MX_EAI_MESSAGE_LOG and does not
          rethrow; this procedure preserves that behavior.
    */

    BEGIN TRY
        IF @sFiscalYear IS NULL
            SET @sFiscalYear = CONVERT(VARCHAR(4), YEAR(GETDATE()));

        IF DATEPART(HOUR, GETDATE()) IN (1, 2)
            SET @nMargen = 0.0;

        SET @dtCreatedFrom = CONVERT(DATE, DATEADD(DAY, -@nDays, GETDATE()));
        SET @dtCreatedTo = DATEADD(MINUTE, -CONVERT(INT, @nMargen * 60), GETDATE());

        -- Mirrors EAI_OWNER.WA_ACCNT_PAYAMOUNT(1, -1) before evaluating central payments.
        EXEC [EAI_OWNER].[WA_ACCNT_PAYAMOUNT] 1, -1;

        IF @pOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (CREATED, OBJECT_TYPE, OBJECT_REFERENCE, DESCRIPTION)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_EXECUTE',
                 CONCAT(@sFiscalYear, '-', RIGHT(CONCAT('00', CONVERT(VARCHAR(2), @nDays)), 2)),
                 'Begin');
        END;

        DECLARE
              @ClearingDocNumber VARCHAR(20)
            , @ClearingDate      VARCHAR(10)
            , @PostingDate       VARCHAR(10)
            , @Records           INT
            , @Cnt_DC            INT
            , @Max_DC            VARCHAR(2)
            , @IDocNumber        VARCHAR(16)
            , @S_IDocNumber      VARCHAR(16)
            , @PayallocIDoc      VARCHAR(10)
            , @ClearingDateAsDate DATE;

        DECLARE curData CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                  Doc.ClearingDocNumber
                , MAX(Doc.ClearingDate) AS ClearingDate
                , MAX(Doc.ClearingDate) AS PostingDate
                , COUNT(Doc.ClearingDocNumber) AS Records
                , COUNT(DISTINCT Doc.DC_Indicator) AS Cnt_DC
                , MAX(Doc.DC_Indicator) AS Max_DC
                , MAX(RIGHT(REPLICATE('0', 16) + COALESCE(CONVERT(VARCHAR(16), Doc.IDocNumber), '0'), 16)) AS IDocNumber
                , MAX(CASE
                          WHEN Doc.DC_Indicator = 'S'
                          THEN RIGHT(REPLICATE('0', 16) + COALESCE(CONVERT(VARCHAR(16), Doc.IDocNumber), '0'), 16)
                          ELSE REPLICATE('0', 16)
                      END) AS S_IDocNumber
            FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS Doc
            WHERE Doc.Created > @dtCreatedFrom
              AND Doc.Created < @dtCreatedTo
              AND Doc.ClearingDocNumber IS NOT NULL
              AND Doc.ClearingDocNumber NOT LIKE '11000%'
              AND Doc.PaymentAmount IS NOT NULL
              AND Doc.Processed IS NULL
            GROUP BY Doc.ClearingDocNumber;

        OPEN curData;

        FETCH NEXT FROM curData
        INTO @ClearingDocNumber, @ClearingDate, @PostingDate, @Records,
             @Cnt_DC, @Max_DC, @IDocNumber, @S_IDocNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @nRecords += 1;
            SET @sClearingDocNumber = @ClearingDocNumber;

            IF (@Records = 1 AND @Max_DC = 'S')
            BEGIN
                -- Single debit/payment document.
                SET @v_ID = @IDocNumber;
                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV] @IDocNumber, @pOutput;
            END
            ELSE IF (@Records = 1 AND @Max_DC = 'H')
            BEGIN
                -- Single credit document is discarded in the Oracle procedure.
                SET @v_ID = @IDocNumber;

                UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                   SET Status = 'Discarded',
                       Processed = GETDATE()
                 WHERE ClearingDocNumber = @ClearingDocNumber
                   AND Created > @dtCreatedFrom
                   AND DC_Indicator = @Max_DC;
            END
            ELSE IF (@Records = 2 AND @Cnt_DC = 1 AND @Max_DC = 'S')
            BEGIN
                -- Two same-side S records are processed through the S IDoc.
                SET @v_ID = @IDocNumber;
                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV] @S_IDocNumber, @pOutput;
            END
            ELSE IF (@Records = 2 AND @Cnt_DC = 2)
            BEGIN
                -- Debit and credit pair: allocate the payment against the credit.
                SET @v_ID = @ClearingDocNumber;
                SET @PayallocIDoc = SUBSTRING(@S_IDocNumber, 7, 10);
                SET @ClearingDateAsDate = TRY_CONVERT(DATE, @ClearingDate, 112);

                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYALLOC]
                      @PayallocIDoc
                    , @ClearingDocNumber
                    , @ClearingDate
                    , @ClearingDateAsDate
                    , @pOutput;
            END
            ELSE IF (@Records = 4 AND @Cnt_DC = 2)
            BEGIN
                /*
                    Oracle workaround:
                    when all four rows share PMS Z9 and the same payment amount,
                    discard the lowest S/H rows by moving them to ClearingDocNumber+'D',
                    then process the remaining pair as a normal allocation.
                */
                DECLARE
                      @waMinPMS        VARCHAR(4)
                    , @waMaxPMS        VARCHAR(4)
                    , @waMinPaymentAmt NUMERIC(18,4)
                    , @waMaxPaymentAmt NUMERIC(18,4)
                    , @waMinDcS        VARCHAR(10)
                    , @waMinDcH        VARCHAR(10);

                SELECT
                      @waMinDcS = MIN(CASE WHEN Doc.DC_Indicator = 'S' THEN Doc.IdocNumber ELSE '9999999999' END)
                    , @waMinDcH = MIN(CASE WHEN Doc.DC_Indicator = 'H' THEN Doc.IdocNumber ELSE '9999999999' END)
                    , @waMinPMS = MIN(Doc.PayMethSupplement)
                    , @waMaxPMS = MAX(Doc.PayMethSupplement)
                    , @waMinPaymentAmt = MIN(Doc.PaymentAmount)
                    , @waMaxPaymentAmt = MAX(Doc.PaymentAmount)
                FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS Doc
                WHERE Doc.ClearingDocNumber = @sClearingDocNumber
                  AND Doc.Processed IS NULL
                GROUP BY Doc.ClearingDocNumber;

                IF (@waMinPMS = @waMaxPMS
                    AND @waMinPMS = 'Z9'
                    AND @waMinPaymentAmt = @waMaxPaymentAmt)
                BEGIN
                    UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                       SET Status = 'Discarded',
                           Processed = GETDATE(),
                           ClearingDocNumber = CONCAT(ClearingDocNumber, 'D')
                     WHERE IdocNumber = @waMinDcS;

                    UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                       SET Status = 'Discarded',
                           Processed = GETDATE(),
                           ClearingDocNumber = CONCAT(ClearingDocNumber, 'D')
                     WHERE IdocNumber = @waMinDcH;

                    SET @v_ID = @ClearingDocNumber;
                    SET @PayallocIDoc = SUBSTRING(@S_IDocNumber, 7, 10);
                    SET @ClearingDateAsDate = TRY_CONVERT(DATE, @ClearingDate, 112);

                    EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYALLOC]
                          @PayallocIDoc
                        , @ClearingDocNumber
                        , @ClearingDate
                        , @ClearingDateAsDate
                        , @pOutput;
                END;
            END
            ELSE
            BEGIN
                -- Same fallback as Oracle: keep the clearing document as current reference.
                SET @v_ID = @ClearingDocNumber;
            END;

            FETCH NEXT FROM curData
            INTO @ClearingDocNumber, @ClearingDate, @PostingDate, @Records,
                 @Cnt_DC, @Max_DC, @IDocNumber, @S_IDocNumber;
        END;

        CLOSE curData;
        DEALLOCATE curData;

        IF @pOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (CREATED, OBJECT_TYPE, OBJECT_REFERENCE, DESCRIPTION)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_EXECUTE',
                 CONCAT(@sFiscalYear, '-', RIGHT(CONCAT('00', CONVERT(VARCHAR(2), @nDays)), 2)),
                 CONCAT('Records -> ', RIGHT(CONCAT('000000', CONVERT(VARCHAR(6), @nRecords)), 6)));

            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (CREATED, OBJECT_TYPE, OBJECT_REFERENCE, DESCRIPTION)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_EXECUTE',
                 CONCAT(@sFiscalYear, '-', RIGHT(CONCAT('00', CONVERT(VARCHAR(2), @nDays)), 2)),
                 'End');
        END;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curData') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'curData') > -1
                CLOSE curData;
            DEALLOCATE curData;
        END;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
            STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
            SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID,
            'Error', 'PROC_CENTRAL_EXECUTE', @sMsg, 'TSQL',
            @sErrorCode, NULL, NULL, NULL
        );
    END CATCH;
END;
GO
