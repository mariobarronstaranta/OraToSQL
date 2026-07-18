/*
    Procedimiento : EAI_OWNER.RECV_ORDER
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_ORDER (Oracle)
    Proposito     : Coordinar acuses OrderAcknowledge pendientes y delegar la
                    evaluacion a PROC_ORDER.

    Seleccion del lote
    ------------------
    Cola OrderAcknowledge, ventana de dos dias y Processed NULL. Componente 406.

    Flujo
    -----
    Materializa el lote, valida la instancia, procesa cada acuse permitido y
    marca PI Issue para las instancias rechazadas.

    Advertencia funcional
    ---------------------
    El body Oracle no asigna ProcessID ni inserta RF_PROCESOS_LOG para este
    miembro. Por eso @nPID permanece NULL y el UPDATE final del log no afecta
    filas. Se conserva para evitar una correccion silenciosa; al normalizarlo se
    debe agregar la generacion de ProcessID y la apertura de RF_PROCESOS_LOG.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_ORDER]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 406
        , @nRecords BIGINT = 0
        , @nPID NUMERIC(10,0) = NULL
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Snapshot del lote que sustituye el cursor Oracle.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;

        -- Orden estable para diagnosticar y reproducir una ejecucion.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'OrderAcknowledge'
          AND R.CREATED > DATEADD(DAY, -2, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- El procedimiento interno decide Processed, CheckData o Discard.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;

            IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) = 'YES'
                EXEC [EAI_OWNER].[PROC_ORDER]
                     @sROW_ID = @RowID, @nROWNUM = @i, @nPID = @nPID;
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        -- En Oracle esta actualizacion tampoco afecta filas porque nPID es NULL.
        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- El ROW_ID del log de error se genera mediante su DEFAULT.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_ORDER', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
