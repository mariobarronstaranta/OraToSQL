CREATE OR ALTER PROCEDURE dbo.WA_ERR_REPLENISHMENT_LARGE
(
      @pDias INT = 0,
      @pQueueName VARCHAR(100) = 'VanReplenishment'
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
        @nProceso INT = 838;

    BEGIN TRY

        BEGIN TRAN;

        ---------------------------------------------------
        -- ProcessID.NextVal
        ---------------------------------------------------
        SELECT
            @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

        ---------------------------------------------------
        -- Log Start
        ---------------------------------------------------
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

        ---------------------------------------------------
        -- Construcción del dataset
        ---------------------------------------------------

        ;WITH ERR AS
        (
            SELECT
                ROW_NUMBER() OVER
                (
                    ORDER BY Created
                ) AS RN,

                PK_ID,
                Queue_Name,

                REPLACE(SUBSTRING(Message,1,3900),'&','y') AS Fase1,
                REPLACE(SUBSTRING(Message,3901,3900),'&','y') AS Fase2,
                REPLACE(SUBSTRING(Message,7801,3900),'&','y') AS Fase3,
                REPLACE(SUBSTRING(Message,11701,3900),'&','y') AS Fase4,
                REPLACE(SUBSTRING(Message,15601,3900),'&','y') AS Fase5,
                REPLACE(SUBSTRING(Message,19501,3900),'&','y') AS Fase6,
                REPLACE(SUBSTRING(Message,23401,3900),'&','y') AS Fase7,
                REPLACE(SUBSTRING(Message,27301,3900),'&','y') AS Fase8,
                REPLACE(SUBSTRING(Message,31201,3900),'&','y') AS Fase9,
                REPLACE(SUBSTRING(Message,35101,3900),'&','y') AS Fase10,
                Message
            FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
            WHERE Queue_Name = @pQueueName
            AND Status='Error'
            AND Siebel_Error_Message LIKE '%-ORA-31011%'
            AND Created >
                DATEADD
                (
                    DAY,
                    -@pDias,
                    CAST(GETDATE() AS DATE)
                )
        ),
        DATA AS
        (
            SELECT
                RIGHT
                (
                    FORMAT(GETDATE(),'yyyyMMddHHmmss')
                    +
                    RIGHT
                    (
                        '0000000'+CAST(RN AS VARCHAR(7)),
                        7
                    ),
                    21
                ) AS Row_ID,

                GETDATE() AS Created,
                Queue_Name,
                PK_ID,

                CONCAT
                (
                    Fase1,Fase2,Fase3,Fase4,Fase5,
                    Fase6,Fase7,Fase8,Fase9,Fase10
                ) AS XML_Content
            FROM ERR
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
            TRY_CAST(XML_Content AS XML)
        FROM DATA;

        ---------------------------------------------------
        -- Cantidad de registros
        ---------------------------------------------------

        SET @nPedidos = @@ROWCOUNT;

        ---------------------------------------------------
        -- Marcar para reproceso
        ---------------------------------------------------

        UPDATE E
        SET Status='Reprocess'
        FROM EAI_OWNER.MX_EAI_MESSAGE_LOG E
        INNER JOIN DATA D
            ON E.PK_ID = D.PK_ID;

        ---------------------------------------------------
        -- Actualizar proceso
        ---------------------------------------------------

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET Status=1
        WHERE Component=@nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET
            Fin=GETDATE(),
            Proceso_1=0,
            Proceso_2=0,
            Proceso_3=0,
            Proceso_4=@nPedidos
        WHERE PID=@nPID;

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
            'WA_ERR_REPLENISHMENT',
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