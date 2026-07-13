CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_OTROS_PARTNERS
(
    @sInvoiceID VARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sMsg NVARCHAR(500);
    DECLARE @sErrorCode NVARCHAR(500);
    DECLARE @v_ID VARCHAR(30);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        UPDATE PF
           SET Sold_to_Name      = Bill_to_Name,
               Sold_to_Address   = Bill_to_Address,
               Sold_to_District  = Bill_to_District,
               Sold_to_City      = Bill_to_City,
               Sold_to_State     = Bill_to_State,
               Sold_to_Country   = Bill_to_Country,
               Sold_to_Zipcode   = Bill_to_ZipCode
        FROM EAI_OWNER.tmp_Document_Partners PF
        WHERE PF.ReferenceID = @sInvoiceID
          AND PF.Sold_to_Customer = 'PC-00-CR08'
          AND PF.Bill_to_Customer = 'IC-00-CR10';

    END TRY
    BEGIN CATCH

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
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
            'Sending to T3 V33',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'Invoice to T3',
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