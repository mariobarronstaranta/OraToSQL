CREATE OR ALTER PROCEDURE [EAI].[T3R_REPLICA_SALESDOC]
    @sTipo_Act VARCHAR(50) = 'Full'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg       VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @v_ID       VARCHAR(50) = 'T3R_REPLICA_SALESDOC';

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE [EAI].[T3R_STATUS]
           SET [START_DATE] = SYSDATETIME(),
               [END_DATE] = NULL
         WHERE [PROCEDURE] = 'REPLICA T3R_SALES_DOCS';

        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO [EAI].[T3R_STATUS]
            (
                [PROCEDURE],
                [START_DATE],
                [END_DATE]
            )
            VALUES
            (
                'REPLICA T3R_SALES_DOCS',
                SYSDATETIME(),
                NULL
            );
        END;

        IF UPPER(ISNULL(@sTipo_Act, 'Full')) = 'DELTA'
        BEGIN
            INSERT INTO [EAI].[T3R_SALES_DOCS_OLD]
            (
                [DOC_DATE],
                [DISTRIBUTOR],
                [CUSTOMER],
                [DOC_NUM_R3],
                [DOC_ORD_R3],
                [DOC_NUM_REF1],
                [DOC_NUM_REF2],
                [DOC_TYPE],
                [DOC_STATUS],
                [DOC_NETAMT],
                [DOC_TAXAMT],
                [DOC_QTY],
                [CREATED]
            )
            SELECT
                Src.[DOC_DATE],
                Src.[DISTRIBUTOR],
                Src.[CUSTOMER],
                Src.[DOC_NUM_R3],
                Src.[DOC_ORD_R3],
                Src.[DOC_NUM_REF1],
                Src.[DOC_NUM_REF2],
                Src.[DOC_TYPE],
                Src.[DOC_STATUS],
                Src.[DOC_NETAMT],
                Src.[DOC_TAXAMT],
                Src.[DOC_QTY],
                SYSDATETIME()
            FROM [EAI].[T3R_SALES_DOCS] AS Src
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [EAI].[T3R_SALES_DOCS_OLD] AS Dest
                WHERE Dest.[DOC_NUM_R3] = Src.[DOC_NUM_R3]
            );
        END;
        ELSE
        BEGIN
            TRUNCATE TABLE [EAI].[T3R_SALES_DOCS_OLD];

            INSERT INTO [EAI].[T3R_SALES_DOCS_OLD]
            (
                [DOC_DATE],
                [DISTRIBUTOR],
                [CUSTOMER],
                [DOC_NUM_R3],
                [DOC_ORD_R3],
                [DOC_NUM_REF1],
                [DOC_NUM_REF2],
                [DOC_TYPE],
                [DOC_STATUS],
                [DOC_NETAMT],
                [DOC_TAXAMT],
                [DOC_QTY],
                [CREATED]
            )
            SELECT
                Src.[DOC_DATE],
                Src.[DISTRIBUTOR],
                Src.[CUSTOMER],
                Src.[DOC_NUM_R3],
                Src.[DOC_ORD_R3],
                Src.[DOC_NUM_REF1],
                Src.[DOC_NUM_REF2],
                Src.[DOC_TYPE],
                Src.[DOC_STATUS],
                Src.[DOC_NETAMT],
                Src.[DOC_TAXAMT],
                Src.[DOC_QTY],
                SYSDATETIME()
            FROM [EAI].[T3R_SALES_DOCS] AS Src;
        END;

        UPDATE [EAI].[T3R_STATUS]
           SET [END_DATE] = SYSDATETIME()
         WHERE [PROCEDURE] = 'REPLICA T3R_SALES_DOCS';

        INSERT INTO [EAI].[T3R_STATUS_LOG]
        (
            [DATE_INSERT],
            [PROCEDURE],
            [START_DATE],
            [END_DATE]
        )
        SELECT
            SYSDATETIME(),
            S.[PROCEDURE],
            S.[START_DATE],
            S.[END_DATE]
        FROM [EAI].[T3R_STATUS] AS S
        WHERE S.[PROCEDURE] = 'REPLICA T3R_SALES_DOCS';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
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
            NULL,
            'Error',
            'T3R_REPLICA_SALESDOC',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT '--------------------------------------';
        PRINT '**** Error en T3R_REPLICA_SALESDOC ****';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
GO
