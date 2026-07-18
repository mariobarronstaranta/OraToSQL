/*
    Procedimiento : EAI_OWNER.RECV_INVOICE
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_INVOICE (Oracle)
    Proposito     : Coordinar facturas pendientes y enviarlas al procesamiento
                    de preventa/interfaz mediante SF_PROC_PREINVOICE_IFC.

    Seleccion del lote
    ------------------
    Cola Invoice, ventana de cinco dias y Processed NULL. Componente 405.

    Reglas clave
    ------------
    - Solo procesa instancias aceptadas por FN_CHECK_INSTANCE.
    - La llamada a SF_PROC_PREINVOICE_IFC depende de SalesForceOn=YES.
    - Las instancias rechazadas se cierran con estado PI Issue.
    - El cierre actualiza MX_COMPONENTS y RF_PROCESOS_LOG.

    Los errores del coordinador se guardan en MX_EAI_MESSAGE_LOG y su ROW_ID
    BIGINT se obtiene del DEFAULT configurado para la tabla.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_INVOICE]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 405
        , @nRecords BIGINT = 0
        , @sSalesForceOn VARCHAR(30)
        , @nPID NUMERIC(10,0) = NULL
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Lote fijo que reemplaza el cursor implícito del package Oracle.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
        SET @sSalesForceOn = [EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn');

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

        -- El numero de fila se utiliza como nRowNum en el procedimiento delegado.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'Invoice'
          AND R.CREATED > DATEADD(DAY, -5, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- La delegacion individual aisla el estado de cada factura.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;

            IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) = 'YES'
            BEGIN
                IF UPPER(@sSalesForceOn) = 'YES'
                    EXEC [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
                         @sRow_ID = @RowID, @nRowNum = @i, @nOutput = 0, @nPID = @nPID;
            END
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Marca disponible el componente y conserva metricas del lote.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- Error general del job; los detalles por factura pertenecen al delegado.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_INVOICE', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
