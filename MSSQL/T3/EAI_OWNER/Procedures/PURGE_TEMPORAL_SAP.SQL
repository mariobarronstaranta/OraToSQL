CREATE OR ALTER  PROCEDURE EAI_OWNER.PURGE_TEMPORAL_SAP
(
      @sPeriod      VARCHAR(6),
      @sTableName   VARCHAR(50)
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sEtapa       VARCHAR(40),
        @sMsg         VARCHAR(500),
        @sErrorCode   VARCHAR(20);

    BEGIN TRY

        -----------------------------------------------------------------
        -- ACCOUNTING
        -----------------------------------------------------------------
        IF UPPER(@sTableName) = 'ACCOUNTING'
        BEGIN

            SET @sEtapa = 'TMP_ACCOUNT_HEADER';

            DELETE A
            FROM EAI_OWNER.TMP_ACCOUNT_HEADER A
            WHERE CONVERT(CHAR(6),A.Created,112) = @sPeriod;

        END

        -----------------------------------------------------------------
        -- DOCUMENT
        -----------------------------------------------------------------
        ELSE IF UPPER(@sTableName) = 'DOCUMENT'
        BEGIN

            SET @sEtapa = 'TMP_DOCUMENT_HEADER';

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE CONVERT(CHAR(6),Created,112) = @sPeriod
            )

            DELETE P
            FROM EAI_OWNER.TMP_DOCUMENT_PARTNERS P
            INNER JOIN Docs X
                ON X.ReferenceID = P.ReferenceID;

            DELETE H
            FROM EAI_OWNER.TMP_DOCUMENT_HEADER H
            WHERE CONVERT(CHAR(6),H.Created,112) = @sPeriod;

        END

        -----------------------------------------------------------------
        -- DOCUMENT-NULL
        -----------------------------------------------------------------
        ELSE IF UPPER(@sTableName) = 'DOCUMENT-NULL'
        BEGIN

            SET @sEtapa = 'TMP_DOCUMENT_HEADER';

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE Created IS NULL
                AND DeliveryType IS NULL
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL_COND D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            ;WITH Docs AS
            (
                SELECT ReferenceID
                FROM EAI_OWNER.TMP_DOCUMENT_HEADER
                WHERE Created IS NULL
                AND DeliveryType IS NULL
            )

            DELETE D
            FROM EAI_OWNER.TMP_DOCUMENT_DETAIL D
            INNER JOIN Docs X
                ON X.ReferenceID = D.ReferenceID;

            DELETE H
            FROM EAI_OWNER.TMP_DOCUMENT_HEADER H
            WHERE Created IS NULL
            AND DeliveryType IS NULL;

        END

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
            ID,
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
            'Purge',
            NULL,
            GETDATE(),
            NULL,
            'Error',
            @sEtapa,
            @sMsg,
            'Purge',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO