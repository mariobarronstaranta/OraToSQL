/*
    Procedimiento : EAI_OWNER.RECV_CREDIT
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_CREDIT (Oracle)
    Proposito     : Coordinar mensajes Customer Credit pendientes y delegar su
                    transformacion a PROC_CREDIT.

    Seleccion del lote
    ------------------
    Cola Customer Credit, creada dentro de la ventana de dos dias y con
    Processed NULL. El componente asociado es 402.

    Flujo
    -----
    Genera ProcessID, materializa el lote, valida la instancia, procesa cada
    mensaje permitido y finalmente actualiza los logs de ejecucion.

    Mantenimiento
    -------------
    - Una instancia rechazada se marca PI Issue y no llega al transformador.
    - El Item sustituye ROWNUM y se pasa al procedimiento interno.
    - MX_EAI_MESSAGE_LOG.ROW_ID se genera automaticamente.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_CREDIT]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent   INT = 402
        , @nRecords     BIGINT = 0
        , @nPID         NUMERIC(10,0) = NULL
        , @i            BIGINT = 1
        , @RowID        VARCHAR(32)
        , @InstanceName VARCHAR(300)
        , @InstanceChk  VARCHAR(5);

    -- Lote estable de mensajes que existian al comenzar esta ejecucion.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

        -- Orden determinista para facilitar trazabilidad y reproduccion de errores.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'Customer Credit'
          AND R.CREATED > DATEADD(DAY, -2, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- Se mantiene el modelo fila por fila utilizado por el cursor Oracle.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;
            SET @InstanceChk = [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName);

            IF @InstanceChk = 'YES'
                EXEC [EAI_OWNER].[PROC_CREDIT]
                     @sROW_ID = @RowID, @nROWNUM = @i, @nPID = @nPID;
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Cierre funcional y estadistico de la ejecucion.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- Captura errores del coordinador, no los errores controlados por PROC_CREDIT.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_CREDIT', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
