CREATE PROCEDURE EAI_OWNER.WA_CHECK_PAYNULL
(
      @pDays       INT = 0,
      @pSequence   INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode       VARCHAR(30),
        @sMsg             VARCHAR(300),
        @nPID             INT = @@SPID,
        @rsDoc_Num        VARCHAR(30),
        @rsCliente_SAP    VARCHAR(10),
        @rnAmount         DECIMAL(15,2),
        @rnPending        DECIMAL(15,2),
        @rnPaid           DECIMAL(15,2);

    BEGIN TRY

        PRINT 'Inicio -> '
              + CONVERT(VARCHAR(8),GETDATE(),108);

        TRUNCATE TABLE EAI_OWNER.Z_CHECK_PAYAMT_NULL;

        INSERT INTO EAI_OWNER.Z_CHECK_PAYAMT_NULL
        (
            ClearingDocNumber,
            IDocNumber,
            ReferenceDocNumber,
            DC_Indicator,
            Pay_Amount
        )
        SELECT
            Info.ClearingDocNumber,
            Info.IDocNumber,
            Info.ReferenceDocNumber,
            Info.Max_DC,
            Info.DocAmount
        FROM
        (
            SELECT
                ClearingDocNumber,
                MAX(IDocNumber) AS IDocNumber,
                MAX(ReferenceDocNumber) AS ReferenceDocNumber,
                MAX(DC_Indicator) AS Max_DC,
                MAX(AmountDocCurrency) AS DocAmount,
                COUNT(*) AS Registros,
                SUM(CASE
                        WHEN PaymentAmount IS NULL THEN 1
                        ELSE 0
                    END) AS PayAmt_NULL,
                SUM(CASE
                        WHEN Processed IS NULL THEN 0
                        ELSE 1
                    END) AS Procesados
            FROM EAI_OWNER.tmp_Account_Header
            WHERE Created >
                  DATEADD(DAY,-ISNULL(@pDays,0),CAST(GETDATE() AS DATE))
            AND ClearingDocNumber IS NOT NULL
            GROUP BY ClearingDocNumber
        ) Info
        WHERE
            Info.Registros = 1
            AND Info.PayAmt_NULL = 1
            AND Info.Procesados = 0;

        ----------------------------------------------------
        -- Cursor necesario por dependencia al SP
        ----------------------------------------------------

        DECLARE
            @ClearingDocNumber VARCHAR(30),
            @IDocNumber VARCHAR(30),
            @ReferenceDocNumber VARCHAR(30);

        DECLARE curDoc CURSOR LOCAL FAST_FORWARD
        FOR
        SELECT
            ClearingDocNumber,
            IDocNumber,
            ReferenceDocNumber
        FROM EAI_OWNER.Z_CHECK_PAYAMT_NULL;

        OPEN curDoc;

        FETCH NEXT
        FROM curDoc
        INTO
            @ClearingDocNumber,
            @IDocNumber,
            @ReferenceDocNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            EXEC EAI_OWNER.SF_GET_INVOICE_DATA
                    @ReferenceDocNumber,
                    @rsDoc_Num OUTPUT,
                    @rsCliente_SAP OUTPUT,
                    @rnAmount OUTPUT,
                    @rnPending OUTPUT,
                    @rnPaid OUTPUT;

            UPDATE EAI_OWNER.Z_CHECK_PAYAMT_NULL
            SET
                Doc_Amount = @rnAmount,
                Doc_Pending = @rnPending,
                Cliente_SAP = @rsCliente_SAP
            WHERE ClearingDocNumber = @ClearingDocNumber;

            FETCH NEXT
            FROM curDoc
            INTO
                @ClearingDocNumber,
                @IDocNumber,
                @ReferenceDocNumber;
        END

        CLOSE curDoc;
        DEALLOCATE curDoc;

        ----------------------------------------------------
        -- Corrección de pagos
        ----------------------------------------------------

        IF ISNULL(@pSequence,100) >= 100
        BEGIN

            UPDATE T
            SET
                PaymentAmount = T.AmountDocCurrency,
                PaymentMethod = P.PayMethod
            FROM EAI_OWNER.tmp_Account_Header T
            INNER JOIN
            (
                SELECT
                    Pay.IDocNumber,
                    dbo.getConv(
                        'V3_ECC PaymentMethod',
                        ISNULL(Cte.Metodo_Pago,'-')
                    ) AS PayMethod,
                    ISNULL(Cte.Metodo_Pago,'-') AS Metodo_Pago
                FROM EAI_OWNER.Z_CHECK_PAYAMT_NULL Pay
                INNER JOIN T3.Mov_Cliente Cte
                    ON Pay.Cliente_SAP = Cte.Cliente_SAP
                WHERE
                    ISNULL(Pay.Doc_Pending,0)
                    =
                    ISNULL(Pay.Doc_Amount,0)
                AND ISNULL(Pay.Doc_Amount,0) > 0
            ) P
                ON T.IDocNumber = P.IDocNumber
            WHERE
                T.PaymentMethod <> P.PayMethod;
        END

        PRINT 'Fin -> '
              + CONVERT(VARCHAR(8),GETDATE(),108);

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR);

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR)
                + '-'
                + ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            NULL,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_CHECK_PAYNULL',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END
GO