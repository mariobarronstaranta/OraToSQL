CREATE OR ALTER PROCEDURE EAI_OWNER.WA_ACCNT_PAYAMOUNT_CM
(
      @pDiasIni INT = 0
    , @pDiasFin INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @nPID INT = @@SPID
        , @ErrorCode VARCHAR(30)
        , @ErrorMessage VARCHAR(300);

    BEGIN TRY

        BEGIN TRANSACTION;

        ;WITH BaseData AS
        (
            SELECT

                  Acc.ClearingDocNumber
                , Acc.ClearingDate
                , COALESCE(Acc.PaymentAmount,0) AS PaymentAmount
                , Acc.IdocNumber

                , CASE
                    WHEN Acc.DC_Indicator = 'S'
                    THEN Acc.Cte_Invoice
                  END AS Fact_DocReference

                , CASE
                    WHEN Acc.DC_Indicator = 'H'
                    THEN Acc.Cte_CreditMemo
                  END AS Nota_DocReference

                , CASE
                    WHEN Acc.DC_Indicator = 'S'
                    THEN Acc.IdocNumber
                  END AS Fact_IDocNumber

                , CASE
                    WHEN Acc.DC_Indicator = 'H'
                    THEN Acc.IdocNumber
                  END AS Nota_IDocNumber

                , CASE
                    WHEN Acc.DC_Indicator = 'S'
                    THEN Acc.Status
                  END AS Fact_Status

                , CASE
                    WHEN Acc.DC_Indicator = 'H'
                    THEN Acc.Status
                  END AS Nota_Status

                , CASE
                    WHEN Acc.DC_Indicator = 'H'
                    THEN Acc.ReferenceDocNumber
                  END AS Nota_Reference

                , COALESCE(Acc.Reversal,' ') AS Reversal

            FROM EAI_OWNER.tmp_Account_Header Acc

            WHERE Acc.Created >
                  CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE)

              AND Acc.Created <
                  CAST(DATEADD(DAY,-@pDiasFin,GETDATE()) AS DATE)

              AND Acc.PayMethSupplement = 'Z9'
        ),

        Documents AS
        (
            SELECT

                  ClearingDocNumber
                , ClearingDate
                , PaymentAmount

                , MAX(Fact_DocReference) AS Fact_DocReference
                , MAX(Nota_DocReference) AS Nota_DocReference

                , MAX(Fact_IDocNumber) AS Fact_IDocNumber
                , MAX(Nota_IDocNumber) AS Nota_IDocNumber

                , MAX(Fact_Status) AS Fact_Status
                , MAX(Nota_Status) AS Nota_Status

                , MAX(Nota_Reference) AS Nota_Reference

                , MAX(Reversal) AS Reversal

            FROM BaseData

            GROUP BY
                  ClearingDocNumber
                , ClearingDate
                , PaymentAmount

            HAVING COUNT(*) = 2
               AND MAX(Nota_Reference) IS NOT NULL
        ),

        EligibleDocuments AS
        (
            SELECT *

            FROM Documents

            WHERE Fact_DocReference IS NOT NULL
              AND Nota_DocReference IS NOT NULL
              AND Fact_Status IS NULL
              AND Nota_Status IS NULL
              AND Reversal = ' '
        ),

        ExistingAssignments AS
        (
            SELECT

                  E.ClearingDocNumber

                , COUNT(AP.Pago_ID) AS ExistingCount

            FROM EligibleDocuments E

            LEFT JOIN T3.Asignacion_Pago AP
                   ON AP.Asignacion_ID LIKE
                      E.ClearingDocNumber + '%'

            GROUP BY
                E.ClearingDocNumber
        ),

        NumberedDocuments AS
        (
            SELECT

                  E.*

                , EA.ExistingCount

                , ROW_NUMBER()
                    OVER
                    (
                        PARTITION BY E.ClearingDocNumber
                        ORDER BY E.Nota_DocReference
                    ) AS RowNum

            FROM EligibleDocuments E

            INNER JOIN ExistingAssignments EA
                ON EA.ClearingDocNumber =
                   E.ClearingDocNumber
        ),

        NewReferences AS
        (
            SELECT

                  Fact_IDocNumber
                , Nota_IDocNumber

                , ClearingDocNumber +
                  dbo.FN_CONV_DOCTO_LETRA
                  (
                     ExistingCount + RowNum
                  ) AS NewClearingDocument

            FROM NumberedDocuments
        )

        UPDATE H
           SET H.ClearingDocNumber =
               NR.NewClearingDocument
        FROM EAI_OWNER.tmp_Account_Header H
        INNER JOIN
        (
            SELECT
                Fact_IDocNumber AS IdocNumber,
                NewClearingDocument
            FROM NewReferences

            UNION ALL

            SELECT
                Nota_IDocNumber,
                NewClearingDocument
            FROM NewReferences
        ) NR
            ON NR.IdocNumber = H.IdocNumber;

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @ErrorCode =
            CAST(ERROR_NUMBER() AS VARCHAR(30));

        SET @ErrorMessage =
            LEFT(ERROR_MESSAGE(),300);

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
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Job Logging',
            NULL,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_ACCNT_PAYAMOUNT_CM',
            @ErrorMessage,
            'TSQL',
            @ErrorCode
        );

        THROW;

    END CATCH

END
GO