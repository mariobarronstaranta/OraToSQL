CREATE PROCEDURE EAI.CC_STOCK_SAP
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_ID         VARCHAR(50);
    DECLARE @sMsg         VARCHAR(500);
    DECLARE @sErrorCode   VARCHAR(20);

    DECLARE @nProceso     INT;
    DECLARE @nPID         BIGINT;
    DECLARE @nProceso4    INT;

    BEGIN TRY

        SET @nProceso = 721;

        SET @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

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

        UPDATE EAI.T3R_REPORTE_STOCK_TAO
        SET Ubicacion =
            CASE
                WHEN LEN(Partner_Name) >= 18
                THEN SUBSTRING(Partner_Name,15,4)
                ELSE NULL
            END
        WHERE ISNULL(Ubicacion,'') <>
              ISNULL(SUBSTRING(Partner_Name,15,4),'');

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE(),
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;

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
            ID,
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
            'CifrasControl',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'CC_STOCK_SAP',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END;
GO
