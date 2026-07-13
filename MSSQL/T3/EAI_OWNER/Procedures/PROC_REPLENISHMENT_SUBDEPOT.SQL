CREATE OR ALTER PROCEDURE dbo.PROC_REPLENISHMENT_SUBDEPOT
(
    @sReferenceID VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF EXISTS
        (
            SELECT 1
            FROM
            (
                SELECT
                    Head.Cust_to_SAP
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER Head
                INNER JOIN EAI_OWNER.MX_PRINT_DELIVERY Send
                    ON Head.Cust_to_SAP = Send.Cust_to_SAP
                WHERE Head.ReferenceID = @sReferenceID
                  AND Head.DeliveryType = 'Receive Other'
            ) X
        )
        BEGIN
            EXEC T3.DELIVERY_TO_SUBDEPOT
                 @sReferenceID,
                 0;
        END

        /*
        Validar con negocio si sigue vigente.

        EXEC EAI_OWNER.PROC_REPLENISHMENT_FILLRATE
             @sReferenceID;
        */

    END TRY
    BEGIN CATCH

        DECLARE @sErrorCode VARCHAR(20);
        DECLARE @sMsg VARCHAR(500);

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT
            (
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE(),
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
            'Stamp CFD Subdepot',
            @sReferenceID,
            GETDATE(),
            NULL,
            'Error',
            'PROC_REPLENISHMENT_SUBDEPOT',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END;
GO