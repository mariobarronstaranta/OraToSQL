CREATE PROCEDURE EAI_OWNER.EXECUTE_TRUNCATE
(
    @pTableName VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @v_ID           VARCHAR(255),
        @SQL            NVARCHAR(MAX),
        @ErrorCode      VARCHAR(50),
        @ErrorMessage   VARCHAR(500);

    BEGIN TRY

        SET @v_ID = UPPER(@pTableName);

        ------------------------------------------------------------------
        -- Validar tabla autorizada
        ------------------------------------------------------------------
        IF EXISTS
        (
            SELECT 1
            FROM EAI_OWNER.EAI_TRUNC_TABLE
            WHERE UPPER(Table_Name) = @v_ID
        )
        BEGIN

            ------------------------------------------------------------------
            -- Construcción segura del TRUNCATE
            ------------------------------------------------------------------

            DECLARE
                @SchemaName SYSNAME,
                @TableOnly  SYSNAME;

            SET @SchemaName = PARSENAME(@v_ID,2);
            SET @TableOnly  = PARSENAME(@v_ID,1);

            SET @SQL =
                N'TRUNCATE TABLE '
                + QUOTENAME(@SchemaName)
                + N'.'
                + QUOTENAME(@TableOnly);

            EXEC sp_executesql @SQL;

            ------------------------------------------------------------------
            -- Auditoría
            ------------------------------------------------------------------

            INSERT INTO EAI_OWNER.EAI_TRUNC_LOG
            (
                TABLE_NAME,
                EXECUTED,
                USER_SCHEMA,
                USER_ID,
                IP_ADDRESS,
                TERMINAL
            )
            VALUES
            (
                @v_ID,
                GETDATE(),
                SUSER_SNAME(),
                ORIGINAL_LOGIN(),
                CAST(CONNECTIONPROPERTY('client_net_address') AS VARCHAR(100)),
                HOST_NAME()
            );
        END

    END TRY

    BEGIN CATCH

        SET @ErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @ErrorMessage =
            LEFT
            (
                CONCAT
                (
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
            'TRUNCATE',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'EXECUTE_TRUNCATE',
            @ErrorMessage,
            'T-SQL',
            @ErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO