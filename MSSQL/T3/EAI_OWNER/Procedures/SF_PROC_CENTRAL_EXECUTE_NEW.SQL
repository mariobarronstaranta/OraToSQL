CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_EXECUTE_NEW]
(
      @nDays        INT          = 28
    , @sFiscalYear  VARCHAR(4)   = NULL
    , @nPID         INT          = NULL
    , @pOutput      INT          = 0
)
AS
BEGIN

    SET NOCOUNT ON;

    /*
        SF_PROC_CENTRAL_EXECUTE_NEW
        ===========================
        Orquesta el procesamiento de compensaciones pendientes en
        EAI_OWNER.TMP_ACCOUNT_HEADER.

        Clasificacion conservada del procedimiento Oracle:
        - 1 registro S: pago normal mediante SF_PROC_CENTRAL_PAYMENT_ZV.
        - 1 registro H: nota de credito aislada; se descarta.
        - 2 registros, ambos S: movimiento TM; procesa el IDoc S.
        - 2 registros, S + H: asignacion factura/nota de credito.
        - 4 registros, S + H: workaround Z9; descarta un par duplicado y
          procesa los dos registros restantes.
        - Cualquier otra composicion queda pendiente para revision manual.

        Antes de clasificar se recalculan montos con WA_ACCNT_PAYAMOUNT. Solo
        se consideran registros no procesados, no reversados, con importe y
        documento de compensacion, excluyendo documentos 11000%.
    */

    IF @sFiscalYear IS NULL
       SET @sFiscalYear = YEAR(GETDATE());

    DECLARE
          @sMsg                 VARCHAR(500)
        , @v_ID                 VARCHAR(30)
        , @sErrorCode           VARCHAR(20)
        , @sClearingDocNumber   VARCHAR(20)
        , @nRecords             INT
        , @nMargen              DECIMAL(5,2)
        , @waMinDcS             VARCHAR(10)
        , @waMinDcH             VARCHAR(10)
        , @waMinPms             VARCHAR(4)
        , @waMaxPms             VARCHAR(4)
        , @waMinPaymentAmount   DECIMAL(18,4)
        , @waMaxPaymentAmount   DECIMAL(18,4)
        , @payAllocIDocNumber   VARCHAR(10)
        , @payAllocPostingDate  DATE;

    BEGIN TRY

        SET @nMargen = 1.5;

        IF DATEPART(HOUR,GETDATE()) IN (1,2)
            SET @nMargen = 0;

        -- Los nombres de parametros deben coincidir con el homologo T-SQL.
        EXEC [EAI_OWNER].[WA_ACCNT_PAYAMOUNT]
             @pDiasIni = 1,
             @pDiasFin = -1;

        SET @nRecords = 0;

        IF @pOutput > 0
        BEGIN

            INSERT INTO EAI_Owner.Trace_EAI_Owner
            (
                Created,
                Object_Type,
                Object_Reference,
                Description
            )
            VALUES
            (
                GETDATE(),
                'SF_PROC_CENTRAL_EXECUTE',
                @sFiscalYear + '-' + RIGHT('00'+CAST(@nDays AS VARCHAR(2)),2),
                'Begin'
            );

        END

        DECLARE curData CURSOR LOCAL FAST_FORWARD FOR

        SELECT
              ClearingDocNumber
            , MAX(ClearingDate) AS ClearingDate
            , MAX(ClearingDate) AS PostingDate
            , COUNT(*)          AS Records
            , COUNT(DISTINCT DC_Indicator) AS Cnt_DC
            , MAX(DC_Indicator) AS Max_DC
            , MAX(RIGHT(REPLICATE('0',16)+CAST(IDocNumber AS VARCHAR(16)),16))
            AS IDocNumber
            , MAX(
                CASE
                   WHEN DC_Indicator='S'
                   THEN RIGHT(REPLICATE('0',16)+CAST(IDocNumber AS VARCHAR(16)),16)
                   ELSE '0000000000000000'
                END
              ) AS S_IDocNumber
        FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER]
        WHERE Created > CAST(DATEADD(DAY,-@nDays,GETDATE()) AS DATE)
          -- Oracle resta nMargen/24 dias. Usar minutos evita que DATEADD
          -- trunque el margen normal de 1.5 horas a una sola hora.
          AND Created < DATEADD(MINUTE, -CONVERT(INT, @nMargen * 60), GETDATE())
          AND ClearingDocNumber IS NOT NULL
          AND ClearingDocNumber NOT LIKE '11000%'
          AND PaymentAmount IS NOT NULL
          AND Processed IS NULL
          AND Reversal IS NULL
        GROUP BY ClearingDocNumber;

        DECLARE
              @ClearingDocNumber VARCHAR(20)
            , @ClearingDate      VARCHAR(20)
            , @Records           INT
            , @Cnt_DC            INT
            , @Max_DC            VARCHAR(1)
            , @IDocNumber        VARCHAR(16)
            , @S_IDocNumber      VARCHAR(16);

        OPEN curData;

        FETCH NEXT FROM curData
        INTO
              @ClearingDocNumber
            , @ClearingDate
            , @Records
            , @Cnt_DC
            , @Max_DC
            , @IDocNumber
            , @S_IDocNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @nRecords += 1;
            SET @sClearingDocNumber = @ClearingDocNumber;

            IF (@Records = 1 AND @Max_DC='S')
            BEGIN

                SET @v_ID = @IDocNumber;

                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV]
                    @pIDocNum = @IDocNumber,
                    @pOutput = @pOutput;

            END

            ELSE IF (@Records = 1 AND @Max_DC='H')
            BEGIN

                SET @v_ID = @IDocNumber;

                UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                SET Status='Discarded',
                    Processed=GETDATE()
                WHERE ClearingDocNumber=@ClearingDocNumber
                  AND Created > CAST(DATEADD(DAY,-@nDays,GETDATE()) AS DATE)
                  AND DC_Indicator=@Max_DC;

            END

            ELSE IF (@Records = 2
                     AND @Cnt_DC = 1
                     AND @Max_DC='S')
            BEGIN

                SET @v_ID=@IDocNumber;

                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV]
                    @pIDocNum = @S_IDocNumber,
                    @pOutput = @pOutput;

            END

            ELSE IF (@Records = 2
                     AND @Cnt_DC = 2)
            BEGIN

                -- EXEC no admite expresiones como valores de parametros.
                -- Se calculan primero los equivalentes de SUBSTR y TO_DATE.
                SET @payAllocIDocNumber = SUBSTRING(@S_IDocNumber, 7, 10);
                SET @payAllocPostingDate = CONVERT(DATE, @ClearingDate, 112);

                EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYALLOC]
                    @pIDocNumber = @payAllocIDocNumber,
                    @pClearingDocNumber = @ClearingDocNumber,
                    @pClearingDate = @ClearingDate,
                    @pPostingDate = @payAllocPostingDate,
                    @pOutPut = @pOutput;

            END

            ELSE IF (@Records = 4
                     AND @Cnt_DC = 2)
            BEGIN

                -- ScrWorkAround Oracle devuelve una fila agregada. Variables
                -- escalares evitan crear una tabla temporal dentro del cursor.
                SELECT
                    @waMinDcS = MIN(CASE WHEN DC_Indicator = 'S' THEN IdocNumber END),
                    @waMinDcH = MIN(CASE WHEN DC_Indicator = 'H' THEN IdocNumber END),
                    @waMinPms = MIN(PayMethSupplement),
                    @waMaxPms = MAX(PayMethSupplement),
                    @waMinPaymentAmount = MIN(PaymentAmount),
                    @waMaxPaymentAmount = MAX(PaymentAmount)
                FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                WHERE ClearingDocNumber = @ClearingDocNumber
                  AND Processed IS NULL;

                IF @waMinPms = 'Z9'
                   AND @waMaxPms = 'Z9'
                   AND @waMinPaymentAmount = @waMaxPaymentAmount
                BEGIN

                    UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                    SET Status='Discarded',
                        Processed=GETDATE(),
                        ClearingDocNumber=ClearingDocNumber+'D'
                    WHERE IdocNumber = @waMinDcS;

                    UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                    SET Status='Discarded',
                        Processed=GETDATE(),
                        ClearingDocNumber=ClearingDocNumber+'D'
                    WHERE IdocNumber = @waMinDcH;

                    SET @payAllocIDocNumber = SUBSTRING(@S_IDocNumber, 7, 10);
                    SET @payAllocPostingDate = CONVERT(DATE, @ClearingDate, 112);

                    EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYALLOC]
                        @pIDocNumber = @payAllocIDocNumber,
                        @pClearingDocNumber = @ClearingDocNumber,
                        @pClearingDate = @ClearingDate,
                        @pPostingDate = @payAllocPostingDate,
                        @pOutPut = @pOutput;

                END

            END
            ELSE
            BEGIN
                SET @v_ID=@ClearingDocNumber;
            END

            FETCH NEXT FROM curData
            INTO
                  @ClearingDocNumber
                , @ClearingDate
                , @Records
                , @Cnt_DC
                , @Max_DC
                , @IDocNumber
                , @S_IDocNumber;

        END

        CLOSE curData;
        DEALLOCATE curData;

        IF @pOutput > 0
        BEGIN

            INSERT INTO EAI_Owner.Trace_EAI_Owner
            VALUES
            (
                GETDATE(),
                'SF_PROC_CENTRAL_EXECUTE',
                @sFiscalYear + '-' + RIGHT('00'+CAST(@nDays AS VARCHAR(2)),2),
                -- LPAD(nRecords, 6) de Oracle rellena con espacios.
                'Records -> ' + RIGHT(REPLICATE(' ', 6) + CAST(@nRecords AS VARCHAR(6)), 6)
            );

            INSERT INTO EAI_Owner.Trace_EAI_Owner
            VALUES
            (
                GETDATE(),
                'SF_PROC_CENTRAL_EXECUTE',
                @sFiscalYear + '-' + RIGHT('00'+CAST(@nDays AS VARCHAR(2)),2),
                'End'
            );

        END

    END TRY

    BEGIN CATCH

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO EAI_Owner.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            JOB_PID,
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
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'PROC_CENTRAL_EXECUTE',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO
