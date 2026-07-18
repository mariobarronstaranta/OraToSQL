/*
    Procedimiento : EAI_OWNER.RECV_REPLENISHMENT
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_REPLENISHMENT (Oracle)
    Proposito     : Coordinar mensajes VanReplenishment pendientes y delegarlos
                    a SF_PROC_REPLENISHMENT.

    Seleccion del lote
    ------------------
    Cola VanReplenishment, ventana de cinco dias y Processed NULL.
    El componente asociado es 407.

    Reglas clave
    ------------
    - Requiere instancia valida y SalesForceOn=YES para procesar.
    - Una instancia invalida se marca PI Issue.
    - Si SalesForceOn no esta activo, el mensaje permanece pendiente, igual que
      en el package Oracle.
    - El cierre registra el total recorrido, no necesariamente el total enviado.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_REPLENISHMENT]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 407
        , @nRecords BIGINT = 0
        , @sSalesForceOn VARCHAR(30)
        , @nPID NUMERIC(10,0) = NULL
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Lote fijo para evitar incorporar mensajes recibidos durante la ejecucion.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @sSalesForceOn = [EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn');
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

        -- Item reemplaza ROWNUM y se entrega como nRowNum al procedimiento SF.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'VanReplenishment'
          AND R.CREATED > DATEADD(DAY, -5, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- Mantiene el procesamiento independiente por mensaje del cursor Oracle.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;

            IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) = 'YES'
            BEGIN
                IF UPPER(@sSalesForceOn) = 'YES'
                    EXEC [EAI_OWNER].[SF_PROC_REPLENISHMENT]
                         @sRow_ID = @RowID, @nRowNum = @i, @nOutput = 0, @nPID = @nPID;
            END
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Libera el componente y finaliza su registro de proceso.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- ROW_ID se omite porque lo genera la secuencia/default del log.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, ID, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_REPLENISHMENT', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'XML', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
