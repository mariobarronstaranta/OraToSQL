CREATE  PROCEDURE EAI_OWNER.WA_ACCNT_COMPLEMENT
(
      @pDias INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @nPedidos INT = 0;

    BEGIN TRY

        BEGIN TRAN;

        ;WITH Docs AS
        (
            SELECT
                  H.IDocNumber
                , H.BillingDocument AS BillingDocument_Original
                , COALESCE(H.BillingDocument, H.ReferenceDocNumber) AS BillingDocument
                , H.Assignment
                , H.ReferenceDocNumber
                , H.DC_Indicator
                , H.Cte_Invoice
                , H.Cte_CreditMemo
                , H.Cte_Tax_ID

                , dbo.get_4428_Reference(H.Assignment) AS Ref_Assignment

                , dbo.get_4428_Reference
                  (
                      COALESCE(H.BillingDocument,H.ReferenceDocNumber)
                  ) AS Ref_Billing

            FROM EAI_OWNER.tmp_Account_Header H
            WHERE CAST(H.Created AS DATE)
                    =
                  CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)

              AND H.Cte_Tax_ID IS NULL
              AND H.DocumentType <> 'BK'
        ),

        RefCalc AS
        (
            SELECT
                D.*,

                CASE
                    WHEN D.Ref_Assignment <> D.Assignment
                        THEN D.Ref_Assignment

                    WHEN D.Ref_Billing <> D.BillingDocument
                        THEN D.Ref_Billing

                    WHEN D.BillingDocument_Original IS NULL
                        THEN D.Ref_Billing

                    ELSE D.Assignment
                END AS ReferenceFinal
            FROM Docs D
        ),

        Hist AS
        (
            SELECT
                  RF.Factura
                , RF.Cliente_SAP
                , C.RFC
            FROM T3.Registro_Fiscal RF
                 INNER JOIN T3.Cliente C
                     ON RF.Cliente_SAP = C.Cliente_SAP
                    AND RF.Fecha_Factura BETWEEN
                        C.Fecha_Ini_Vig
                        AND
                        C.Fecha_Fin_Vig
        )

        UPDATE H
           SET Cte_Invoice =
                CASE
                    WHEN R.DC_Indicator = 'S'
                        THEN R.ReferenceFinal
                    ELSE ''
                END,

               Cte_CreditMemo =
                CASE
                    WHEN R.DC_Indicator <> 'S'
                        THEN R.ReferenceFinal
                    ELSE ''
                END,

               Cte_Tax_ID = Hist.RFC

        FROM EAI_OWNER.tmp_Account_Header H
             INNER JOIN RefCalc R
                ON H.IDocNumber = R.IDocNumber
             INNER JOIN Hist
                ON Hist.Factura = R.ReferenceFinal;

        SET @nPedidos = @@ROWCOUNT;

        COMMIT;

        PRINT 'Documentos Procesados: '
              + CAST(@nPedidos AS VARCHAR(20));

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        DECLARE
              @ErrorCode VARCHAR(30)
            , @Msg VARCHAR(250);

        SET @ErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @Msg =
            LEFT
            (
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-'
                + ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
              DIRECTION
            , REFERENCE
            , CREATED
            , MESSAGE
            , JOB_PID
            , STATUS
            , QUEUE_NAME
            , SIEBEL_ERROR_MESSAGE
            , SOURCE
            , SIEBEL_ERROR_CODE
            , RETRY_COUNT
            , SEQUENCE
            , PARENT_ROW_ID
        )
        VALUES
        (
              'Job Logging'
            , NULL
            , GETDATE()
            , NULL
            , @@SPID
            , 'Error'
            , 'WA_ACCNT_COMPLEMENT'
            , @Msg
            , 'T-SQL'
            , @ErrorCode
            , NULL
            , NULL
            , NULL
        );

        THROW;

    END CATCH

END
GO