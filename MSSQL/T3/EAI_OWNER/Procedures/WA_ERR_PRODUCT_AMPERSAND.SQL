CREATE OR ALTER PROCEDURE dbo.WA_ERR_PRODUCT_AMPERSAND
(
      @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg VARCHAR(300),
        @nPedidos INT = 0,
        @nPID BIGINT,
        @nProceso INT = 839;

    BEGIN TRY

        BEGIN TRAN;

        SELECT
            @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
        (
            PID,
            Proceso,
            Fecha_Proc_BATMD,
            Inicio
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            GETDATE()
        );

        ;WITH Mensajes AS
        (
            SELECT
                MsgID,
                Queue_Name,
                GETDATE() AS Created,
                REPLACE(CAST(Message AS VARCHAR(MAX)), '&', 'y') AS XML_Content,
                FORMAT(GETDATE(),'yyyyMMddHHmmss')
                +
                RIGHT('000000000'+
                CAST(ROW_NUMBER() OVER(ORDER BY MsgID) AS VARCHAR(9)),9)
                AS Row_ID
            FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE Queue_Name='Product'
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created >
                DATEADD
                (
                    DAY,
                    -@pDias,
                    CAST(GETDATE() AS DATE)
                )
        )

        INSERT INTO EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
        (
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        )
        SELECT
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        FROM Mensajes;

        SELECT
            @nPedidos = @@ROWCOUNT;

        UPDATE M
        SET Status='Reprocess'
        FROM EAI_OWNER.MX_EAI_MESSAGE_LOG M
        INNER JOIN
        (
            SELECT MsgID
            FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE Queue_Name='Product'
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created >
                DATEADD
                (
                    DAY,
                    -@pDias,
                    CAST(GETDATE() AS DATE)
                )
        ) X
            ON M.MsgID = X.MsgID;

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET
            Fin = GETDATE(),
            Proceso_1 = 0,
            Proceso_2 = 0,
            Proceso_3 = 0,
            Proceso_4 = @nPedidos
        WHERE PID = @nPID;

        COMMIT;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT
            (
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
            @nPID,
            'Error',
            'WA_ERR_PRODUCT',
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