/*
    Procedimiento : EAI_OWNER.RECV_PRICE
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_PRICE (Oracle)
    Proposito     : Revisar mensajes TaO Price List Inbound pendientes y marcar
                    PI Issue cuando la instancia emisora no esta autorizada.

    Seleccion del lote
    ------------------
    Todos los mensajes pendientes de la cola, sin filtro de antiguedad.
    El componente asociado es 404.

    Advertencia funcional
    ---------------------
    Igual que el Oracle original, una instancia valida no dispara ningun
    procesador y el mensaje queda pendiente. No completar ese flujo sin conocer
    el procedimiento funcional esperado.

    Dependencias: LOG_START, LOG_END y FN_CHECK_INSTANCE.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_PRICE]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @nComponent INT = 404
        , @nRecords BIGINT = 0
        , @dtStarting DATETIME2(0) = SYSDATETIME()
        , @dtEnding DATETIME2(0)
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Snapshot de mensajes para que el lote no cambie durante el recorrido.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;

    INSERT INTO @Records (Item, Row_ID, InstanceName)
    SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
           R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
    FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
    WHERE R.QUEUE_NAME = 'TaO Price List Inbound'
      AND R.PROCESSED IS NULL;

    -- Conserva el recorrido individual del cursor Oracle.
    WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
    BEGIN
        SELECT @RowID = Row_ID, @InstanceName = InstanceName
        FROM @Records WHERE Item = @i;

        SET @nRecords += 1;

        IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) <> 'YES'
            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
               SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
             WHERE ROW_ID = @RowID;

        SET @i += 1;
    END;

    SET @dtEnding = SYSDATETIME();

    -- Registra el numero de mensajes revisados, aun si quedaron pendientes.
    EXEC [EAI_OWNER].[LOG_END]
         @nComponent = @nComponent, @dtBegin = @dtStarting,
         @dtEnd = @dtEnding, @nRecords = @nRecords;
END;
GO
