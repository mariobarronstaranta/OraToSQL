CREATE OR ALTER PROCEDURE dbo.EXECUTE_TRUNCATE
(
    @pTableName VARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ErrorCode VARCHAR(500);
    DECLARE @Msg VARCHAR(500);
    DECLARE @TableName VARCHAR(255);
    DECLARE @SQL NVARCHAR(MAX);

    BEGIN TRY

        SET @TableName = UPPER(@pTableName);

        IF EXISTS
        (
            SELECT 1
            FROM EAI_OWNER.dbo.EAI_TRUNC_TABLE
            WHERE UPPER(Table_Name) = @TableName
        )
        BEGIN

            SET @SQL = N'TRUNCATE TABLE ' + @TableName;

            EXEC(@SQL);

            INSERT INTO EAI_OWNER.dbo.EAI_TRUNC_LOG
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
                @TableName,
                GETDATE(),
                SCHEMA_NAME(),
                SUSER_SNAME(),
                CONVERT(VARCHAR(100),
                        CONNECTIONPROPERTY('client_net_address')),
                HOST_NAME()
            );
        END

    END TRY
    BEGIN CATCH

        SET @ErrorCode = CAST(ERROR_NUMBER() AS VARCHAR(50));

        SET @Msg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(50))
                + ' - '
                + ERROR_MESSAGE(),
                250
            );

        INSERT INTO EAI_OWNER.dbo.MX_EAI_MESSAGE_LOG
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
            @TableName,
            GETDATE(),
            NULL,
            'Error',
            'EXECUTE_TRUNCATE',
            @Msg,
            'TSQL',
            @ErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END;
GO
