/*
    Procedimiento : EAI_OWNER.RECV_PAYMENT
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_PAYMENT (Oracle)
    Proposito     : Coordinar pagos pendientes y enviarlos a
                    SF_PROC_CENTRAL_PAYMENT.

    Seleccion del lote
    ------------------
    Cola Payment, ventana de veinte dias, Processed NULL y orden por DOCNUM.
    El componente asociado es 408.

    Control de concurrencia heredado
    -------------------------------
    Antes de iniciar, revisa la ejecucion mas reciente en RF_PROCESOS_LOG y el
    estado de MX_COMPONENTS. Solo continua cuando la ejecucion anterior tiene
    Fin y el componente esta disponible (Status=1).

    Reglas de mantenimiento
    -----------------------
    - Si no existe ejecucion previa se registra el error 50020, reproduciendo el
      fallo que Oracle produciria al no encontrar datos para SELECT INTO.
    - Requiere instancia valida y SalesForceOn=YES.
    - El total registrado corresponde a mensajes recorridos.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_PAYMENT]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 408
        , @nRecords BIGINT = 0
        , @sSalesForceOn VARCHAR(30)
        , @nPID NUMERIC(10,0) = NULL
        , @dtLastBegin DATETIME2(0)
        , @dtLastEnd DATETIME2(0)
        , @nStatus INT
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Lote de pagos que sera procesado si el control de ejecucion lo permite.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        -- Obtiene el ultimo estado conocido para impedir ejecuciones traslapadas.
        SELECT
              @dtLastBegin = PL.INICIO
            , @dtLastEnd = PL.FIN
            , @nStatus = MC.STATUS
        FROM [T3].[RF_PROCESOS_LOG] AS PL
        INNER JOIN [EAI_OWNER].[MX_COMPONENTS] AS MC
            ON MC.COMPONENT = PL.PROCESO
        WHERE PL.PID =
        (
            SELECT MAX(PID)
            FROM [T3].[RF_PROCESOS_LOG]
            WHERE PROCESO = @nComponent
        );

        IF @@ROWCOUNT = 0
            THROW 50020, 'No existe ejecucion previa para el componente 408.', 1;

        SET @sSalesForceOn = [EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn');

        IF @dtLastEnd IS NOT NULL AND @nStatus = 1
        BEGIN
            EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
            SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

            INSERT INTO [T3].[RF_PROCESOS_LOG]
                (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
            VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

            -- DOCNUM conserva la prioridad definida en el cursor Oracle.
            INSERT INTO @Records (Item, Row_ID, InstanceName)
            SELECT ROW_NUMBER() OVER (ORDER BY R.DOCNUM, R.CREATED, R.ROW_ID), R.ROW_ID,
                   R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
            WHERE R.QUEUE_NAME = 'Payment'
              AND R.CREATED > DATEADD(DAY, -20, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
              AND R.PROCESSED IS NULL;

            -- Cada pago se procesa y registra de manera independiente.
            WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
            BEGIN
                SELECT @RowID = Row_ID, @InstanceName = InstanceName
                FROM @Records WHERE Item = @i;

                SET @nRecords += 1;

                IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) = 'YES'
                BEGIN
                    IF UPPER(@sSalesForceOn) = 'YES'
                        EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT]
                             @sRow_ID = @RowID, @nRowNum = @i, @nOutput = 0, @nPID = @nPID;
                END
                ELSE
                    UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                       SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                     WHERE ROW_ID = @RowID;

                SET @i += 1;
            END;

            -- Cierre del componente y persistencia de contadores del lote.
            UPDATE [EAI_OWNER].[MX_COMPONENTS]
               SET STATUS = 1 WHERE COMPONENT = @nComponent;

            UPDATE [T3].[RF_PROCESOS_LOG]
               SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
                   PROCESO_3 = 0, PROCESO_4 = @nRecords
             WHERE PID = @nPID;
        END;
    END TRY
    BEGIN CATCH
        -- Log de error del coordinador; ROW_ID se genera automaticamente.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, ID, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_PAYMENT', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'XML', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
