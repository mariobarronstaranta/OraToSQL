/*
    Procedimiento : EAI_OWNER.RECV_CUSTOMER
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_CUSTOMER (Oracle)
    Proposito     : Coordinar el procesamiento de mensajes Customer pendientes.

    Seleccion del lote
    ------------------
    Cola Customer, creados despues del inicio del dia, con Reference informado,
    Reference distinto de A0A% y Processed NULL.

    Flujo
    -----
    1. Abre el componente 401 y genera un ProcessID.
    2. Materializa los candidatos para mantener un lote estable.
    3. Valida la instancia emisora con FN_CHECK_INSTANCE.
    4. Si SalesForceOn=YES, delega cada fila a SF_PROC_CUSTOMER.
    5. Marca como PI Issue los mensajes de una instancia no permitida.
    6. Cierra MX_COMPONENTS y RF_PROCESOS_LOG.

    Mantenimiento
    -------------
    - El procesamiento fila por fila es deliberado: el procedimiento delegado
      tiene efectos independientes para cada mensaje.
    - Los errores del coordinador se registran en MX_EAI_MESSAGE_LOG; ROW_ID se
      llena mediante el DEFAULT de la tabla.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_CUSTOMER]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent    INT = 401
        , @nRecords      BIGINT = 0
        , @dtStarting    DATETIME2(0) = SYSDATETIME()
        , @sSalesForceOn VARCHAR(30)
        , @nPID          NUMERIC(10,0) = NULL
        , @i             BIGINT = 1
        , @RowID         VARCHAR(32)
        , @InstanceName  VARCHAR(300)
        , @InstanceChk   VARCHAR(5);

    -- Snapshot del lote: evita que mensajes nuevos alteren la ejecucion en curso.
    DECLARE @Records TABLE
    (
          Item         BIGINT PRIMARY KEY
        , Row_ID       VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @sSalesForceOn = [EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn');
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES
            (@nPID, @nComponent, NULL, SYSDATETIME());

        -- ROW_NUMBER sustituye ROWNUM y produce un orden repetible para el lote.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'Customer'
          AND R.CREATED > CONVERT(DATE, SYSDATETIME())
          AND R.REFERENCE IS NOT NULL
          AND R.REFERENCE NOT LIKE 'A0A%'
          AND R.PROCESSED IS NULL;

        -- Cada mensaje conserva su propio manejo de estado y errores.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;
            SET @InstanceChk = [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName);

            IF @InstanceChk = 'YES'
            BEGIN
                IF UPPER(@sSalesForceOn) = 'YES'
                    EXEC [EAI_OWNER].[SF_PROC_CUSTOMER]
                         @sROW_ID = @RowID, @nROWNUM = @i, @nPID = @nPID;
            END
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Publica la terminacion correcta del componente y sus contadores.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1
         WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- Log tecnico del job; el error de una fila puede registrarse dentro del delegado.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_CUSTOMER', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
