CREATE PROCEDURE dbo.WA_ERR_INVOICE_AMPERSAND
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
        @v_ID VARCHAR(30),
        @nPedidos INT = 0,
        @nPID BIGINT,
        @nProceso INT = 830;

    BEGIN TRY

        ----------------------------------------------------
        -- PID
        ----------------------------------------------------

        SET @nPID =
            NEXT VALUE FOR EAI_OWNER.ProcessID;

        EXEC EAI_OWNER.LOG_START @nProceso;

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

        ----------------------------------------------------
        -- Actualizar referencia
        ----------------------------------------------------

        UPDATE Err
           SET Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)),399,10),
               Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)),236,16)
        FROM EAI_OWNER.MX_EAI_MESSAGE_LOG Err
        WHERE Queue_Name='Invoice'
          AND Direction='Receive'
          AND Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Created > DATEADD(DAY,-@pDias,CAST(GETDATE() AS DATE))
          AND Parent_Row_ID IS NULL;

        ----------------------------------------------------
        -- Reproceso
        ----------------------------------------------------

        ;WITH XML_ERRORS AS
        (
            SELECT
                RowGuid = NEWID(),
                ErrID = Err.ID,
                Queue_Name,
                Reference,
                XML_Content =
                    TRY_CAST
                    (
                        REPLACE
                        (
                            CAST(Err.Message AS VARCHAR(MAX)),
                            '&',
                            'y'
                        )
                    AS XML)
            FROM EAI_OWNER.MX_EAI_MESSAGE_LOG Err
            WHERE Queue_Name='Invoice'
              AND Direction='Receive'
              AND Status='Error'
              AND Siebel_Error_Message LIKE '%-ORA-31011%'
              AND Created > DATEADD
                  (
                    DAY,
                    -1,
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
            REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),
            GETDATE(),
            Queue_Name,
            XML_Content
        FROM XML_ERRORS;

        SET @nPedidos = @@ROWCOUNT;

        ----------------------------------------------------
        -- Marcar para reproceso
        ----------------------------------------------------

        UPDATE Err
           SET Status='Reprocess'
        FROM EAI_OWNER.MX_EAI_MESSAGE_LOG Err
        WHERE Queue_Name='Invoice'
          AND Direction='Receive'
          AND Status='Error'
          AND Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Created > DATEADD
              (
                  DAY,
                  -1,
                  CAST(GETDATE() AS DATE)
              );

        ----------------------------------------------------
        -- Proceso dependiente
        ----------------------------------------------------

        EXEC EAI_OWNER.WA_ERR_PAYMENT_AMPERSAND
            @pDias;

        ----------------------------------------------------
        -- Auditoría
        ----------------------------------------------------

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
            CAST(ERROR_NUMBER() AS VARCHAR(30));

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
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_ERR_INVOICE_AMPERSAND',
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