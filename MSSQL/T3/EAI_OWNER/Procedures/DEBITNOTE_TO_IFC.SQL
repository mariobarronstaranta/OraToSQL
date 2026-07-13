CREATE PROCEDURE EAI_OWNER.DEBITNOTE_TO_IFC
(
    @sInvoiceID VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg NVARCHAR(500),
        @sErrorCode NVARCHAR(500),
        @v_ID VARCHAR(50);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        INSERT INTO T3.DEBIT_NOTE_IFC
        (
            DEBIT_NOTE,
            DOCUMENT_DATE,
            CUST_TO_SAP,
            TOTAL_AMT,
            SAP_DOCUMENT,
            CREATED,
            FACTURA
        )
        SELECT
            PG.PedidoV3,
            CONVERT(
                DATE,
                SUBSTRING(PG.DocumentDate,1,8),
                112
            ) AS DocumentDate,
            PG.FacturaSAP,
            PD.Total,
            PG.ReferenceID,
            GETDATE(),
            REPLACE(PG.PedidoV3,'SU-','')
        FROM EAI_OWNER.TMP_DOCUMENT_HEADER PG
        INNER JOIN
        (
            SELECT
                PD.ItemID AS Num_Linea,
                PD.Material,
                PD.Cantidad AS Cantidad_Vta,
                (COALESCE(PD.Valor_Subt,0) / 100.0)
              + (COALESCE(PD.Valor_IVA,0) / 100.0) AS Total,
                COALESCE(PD.Valor_Subt,0) / 100.0 AS Valor_Subt,
                COALESCE(PD.Valor_IVA,0) / 100.0 AS Valor_IVA,
                PD.ReferenceID
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL PD
            WHERE PD.ReferenceID = @sInvoiceID
        ) PD
            ON PD.ReferenceID = PG.ReferenceID

        LEFT JOIN T3.DEBIT_NOTE_IFC DN
            ON PG.PedidoV3 = DN.DEBIT_NOTE

        WHERE PG.ReferenceID = @sInvoiceID
          AND PG.NombreCliente = 'DebitNote'
          AND DN.SAP_DOCUMENT IS NULL;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
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
            'Sending to V3',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'DEBITNOTE_TO_IFC',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END
GO