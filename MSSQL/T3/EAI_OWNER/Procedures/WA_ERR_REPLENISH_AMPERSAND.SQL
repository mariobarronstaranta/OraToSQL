CREATE OR ALTER PROCEDURE dbo.WA_ERR_REPLENISH_AMPERSAND
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
        @nProceso INT = 838,
        @sRowID VARCHAR(50);

    BEGIN TRY

        SELECT @nPID = NEXT VALUE FOR EAI_Owner.ProcessID;

        EXEC EAI_Owner.Log_Start @nProceso;

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

        --------------------------------------------------
        -- VanReplenishment
        --------------------------------------------------

        UPDATE Err
           SET Reference =
                SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)),409,10),
               Parent_Row_ID =
                SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)),245,16)
        FROM EAI_Owner.MX_EAI_Message_Log Err
        WHERE Queue_Name='VanReplenishment'
        AND Direction='Receive'
        AND Status='Error'
        AND Siebel_Error_Message LIKE '%-ORA-31011%'
        AND Created > CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        AND Parent_Row_ID IS NULL;

        --------------------------------------------------
        -- Insert set-based
        --------------------------------------------------

        ;WITH CTE AS
        (
            SELECT
                ID,
                Queue_Name,
                NewRowID =
                    FORMAT(GETDATE(),'yyyyMMddHHmmss')
                    +
                    RIGHT('000000'
                    + CAST(ROW_NUMBER()
                    OVER(ORDER BY ID) AS VARCHAR(6)),6),

                XML_Content =
                    REPLACE(
                        CAST(Message AS VARCHAR(MAX)),
                        '&',
                        'y'
                    )
            FROM EAI_Owner.MX_EAI_Message_Log
            WHERE Queue_Name='VanReplenishment'
            AND Direction='Receive'
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created > CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        )

        INSERT INTO EAI_Owner.MX_Receive_Message_Log
        (
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        )
        SELECT
            NewRowID,
            GETDATE(),
            Queue_Name,
            TRY_CAST(XML_Content AS XML)
        FROM CTE;

        SET @nPedidos = @@ROWCOUNT;

        UPDATE Err
           SET Status='Reprocess'
        FROM EAI_Owner.MX_EAI_Message_Log Err
        INNER JOIN
        (
            SELECT ID
            FROM EAI_Owner.MX_EAI_Message_Log
            WHERE Queue_Name='VanReplenishment'
            AND Direction='Receive'
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created >
                CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        ) X
            ON Err.ID = X.ID;

        PRINT 'Documentos -> '
            + CAST(@nPedidos AS VARCHAR);

        --------------------------------------------------
        -- Product
        --------------------------------------------------

        UPDATE Err
           SET Reference =
                SUBSTRING(Message,408,8),
               Parent_Row_ID =
                SUBSTRING(Message,237,16)
        FROM EAI_Owner.MX_EAI_Message_Log Err
        WHERE Queue_Name='Product'
        AND Siebel_Error_Message LIKE '%-ORA-31011%'
        AND Created >
            CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        AND Parent_Row_ID IS NULL;

        --------------------------------------------------
        -- Customer
        --------------------------------------------------

        UPDATE Err
           SET Reference =
                SUBSTRING(Message,399,10),
               Parent_Row_ID =
                SUBSTRING(Message,238,16)
        FROM EAI_Owner.MX_EAI_Message_Log Err
        WHERE Queue_Name='Customer'
        AND Siebel_Error_Message LIKE '%-ORA-31011%'
        AND Created >
            CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        AND Parent_Row_ID IS NULL;

        --------------------------------------------------
        -- Invoice-Intercompany
        --------------------------------------------------

        UPDATE Err
           SET Reference =
                SUBSTRING(Message,362,10),
               Parent_Row_ID =
                SUBSTRING(Message,248,16)
        FROM EAI_Owner.MX_EAI_Message_Log Err
        WHERE Queue_Name='Invoice-Intercompany'
        AND Siebel_Error_Message LIKE '%-ORA-31011%'
        AND Created >
            CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        AND Parent_Row_ID IS NULL;

        --------------------------------------------------
        -- Payment
        --------------------------------------------------

        UPDATE Err
           SET Reference =
                SUBSTRING(Message,504,10),
               Parent_Row_ID =
                SUBSTRING(Message,236,16)
        FROM EAI_Owner.MX_EAI_Message_Log Err
        WHERE Queue_Name='Payment'
        AND Siebel_Error_Message LIKE '%-ORA-31011%'
        AND Created >
            CAST(DATEADD(DAY,-@pDias,GETDATE()) AS DATE)
        AND Parent_Row_ID IS NULL;

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = 0,
               Proceso_4 = @nPedidos
        WHERE PID = @nPID;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR);

        SET @sMsg =
            LEFT(ERROR_MESSAGE(),250);

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
            @sRowID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_ERR_REPLENISH_AMPERSAND',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END
GO