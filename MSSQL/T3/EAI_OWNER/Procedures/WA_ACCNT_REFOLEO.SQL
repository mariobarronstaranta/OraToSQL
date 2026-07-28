/*
    Procedure : EAI_OWNER.WA_ACCNT_REFOLEO
    Objetivo  : Sustituir una referencia SAP por su folio T3MX cuando existe un
                refoleo DOI y el cliente del documento coincide.
    Auditoría : Cada cambio se registra en T3.CFDI_REFOLEO_LOG con referencia
                anterior y nueva.
    Integridad: Actualización y bitácora se confirman en una sola transacción.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.WA_ACCNT_REFOLEO
(
      @pDiasIni      INT = 0,
      @pDiasFin      INT = 0,
      @pClearStatus  INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @nPedidos INT = 0;

    BEGIN TRY

        BEGIN TRANSACTION;

        ---------------------------------------------------
        -- Obtener documentos candidatos
        ---------------------------------------------------

        ;WITH Documents AS
        (
            SELECT
                Acc.IdocNumber,
                Acc.CustomerNumber,
                Acc.ReferenceDocNumber,
                Acc.Processed,
                Acc.Status,
                RF.Cliente_SAP,
                COALESCE(Mapa.Docto_T3MX, Acc.ReferenceDocNumber) AS CFDI_Refoleo
            FROM EAI_OWNER.tmp_Account_Header Acc
            OUTER APPLY
            (
                /*
                    El DDL MSSQL no contiene la función T3.FN_CFDI_REFOLEO.
                    Su resultado se obtiene directamente del catálogo generado
                    por T3.WA_CFDI_REFOLEOS. Si no hay mapa, se conserva la
                    referencia original y el documento no se actualiza.
                */
                SELECT TOP (1) R.Docto_T3MX
                FROM T3.CFDI_REFOLEO R
                WHERE R.Docto_SAP = Acc.ReferenceDocNumber
                  AND R.Tipo_Registro = 'DOI'
                ORDER BY R.Fecha DESC
            ) Mapa
            LEFT JOIN T3.Registro_Fiscal RF
                ON RF.Factura = COALESCE(Mapa.Docto_T3MX, Acc.ReferenceDocNumber)
            WHERE
                Acc.Created >
                    CAST(DATEADD(DAY,-@pDiasIni,GETDATE()) AS DATE)
            AND Acc.Created <
                    CAST(DATEADD(DAY,-@pDiasFin,GETDATE()) AS DATE)
            AND Acc.ClearingDocNumber NOT LIKE '11000%'
            AND Acc.DocumentType <> 'BK'
        )
        SELECT *
        INTO #Docs
        FROM Documents
        WHERE
              ReferenceDocNumber <> CFDI_Refoleo
          AND CustomerNumber = Cliente_SAP;

        ---------------------------------------------------
        -- Contador
        ---------------------------------------------------

        SELECT @nPedidos = COUNT(*)
        FROM #Docs;

        ---------------------------------------------------
        -- Actualización principal
        ---------------------------------------------------

        UPDATE H
           SET ReferenceDocNumber = D.CFDI_Refoleo,
               Processed =
                    CASE
                       WHEN @pClearStatus > 0 THEN NULL
                       ELSE H.Processed
                    END,
               Status =
                    CASE
                       WHEN @pClearStatus > 0 THEN NULL
                       ELSE H.Status
                    END
        FROM EAI_OWNER.tmp_Account_Header H
        INNER JOIN #Docs D
            ON H.IdocNumber = D.IdocNumber;

        ---------------------------------------------------
        -- Auditoría
        ---------------------------------------------------

        INSERT INTO T3.CFDI_REFOLEO_LOG
        (
            IDocNumber,
            Created,
            ReferenceDocNumber,
            NewReferenceDocNumber
        )
        SELECT
            IdocNumber,
            GETDATE(),
            ReferenceDocNumber,
            CFDI_Refoleo
        FROM #Docs;

        COMMIT TRANSACTION;

        PRINT CONCAT('Documentos Procesados: ', @nPedidos);

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

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
            NULL,
            'Error',
            'WA_ACCNT_REFOLEO',
            LEFT(ERROR_MESSAGE(),250),
            'TSQL',
            CONCAT('SQL-',ERROR_NUMBER()),
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra el error y termina sin propagarlo.

    END CATCH

END;
GO
