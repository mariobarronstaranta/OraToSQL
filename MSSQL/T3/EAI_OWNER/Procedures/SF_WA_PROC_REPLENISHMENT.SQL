CREATE PROCEDURE EAI_OWNER.SF_WA_PROC_REPLENISHMENT
(
    @nDays INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sMsg           VARCHAR(500);
    DECLARE @v_ID           VARCHAR(50);
    DECLARE @sErrorCode     VARCHAR(20);

    DECLARE
        @Row_ID       VARCHAR(50),
        @Created      DATETIME,
        @Queue_Name   VARCHAR(100),
        @Reference    VARCHAR(100),
        @Processed    VARCHAR(50),
        @Status       VARCHAR(50),
        @Docnum       VARCHAR(100),
        @Entrega      VARCHAR(100);

    BEGIN TRY

        DECLARE curData CURSOR LOCAL FAST_FORWARD FOR

            SELECT
                Recv.Row_ID,
                Recv.Created,
                Recv.Queue_Name,
                Recv.Reference,
                Recv.Processed,
                Recv.Status,
                Recv.Docnum,
                Ent.Entrega
            FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG Recv
                INNER JOIN T3.PREVENTA_GENERAL PG
                    ON Recv.Reference = PG.Factura
                LEFT JOIN T3.ENTREGA Ent
                    ON Recv.Reference = Ent.Factura
            WHERE Recv.Queue_Name = 'VanReplenishment'
              AND Recv.Created > DATEADD(DAY, -@nDays, GETDATE())
              AND Ent.Entrega IS NULL;

        OPEN curData;

        FETCH NEXT FROM curData
        INTO
            @Row_ID,
            @Created,
            @Queue_Name,
            @Reference,
            @Processed,
            @Status,
            @Docnum,
            @Entrega;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @v_ID = @Row_ID;

            EXEC EAI_OWNER.SF_PROC_REPLENISHMENT
                    @Row_ID,
                    0,
                    0,
                    NULL;

            FETCH NEXT FROM curData
            INTO
                @Row_ID,
                @Created,
                @Queue_Name,
                @Reference,
                @Processed,
                @Status,
                @Docnum,
                @Entrega;
        END

        CLOSE curData;
        DEALLOCATE curData;

    END TRY

    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT(
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
            'Processing PI',
            @v_ID,
            GETDATE(),
            NULL,
            NULL,
            'Error',
            'SF_WA_PROC_REPLENISHMENT',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END
GO