/*
    Procedimiento : EAI_OWNER.RECV_PRODUCT
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_PRODUCT (Oracle)
    Proposito     : Revisar mensajes Product pendientes y rechazar los que
                    provienen de una instancia no autorizada.

    Seleccion del lote
    ------------------
    Cola Product, ventana de diez dias y Processed NULL. Componente 403.

    Advertencia funcional
    ---------------------
    El body Oracle NO llama un procesador cuando la instancia es valida. En ese
    caso el mensaje permanece pendiente. La migracion conserva esta conducta;
    agregar una llamada requiere una decision funcional y pruebas especificas.

    Dependencias: LOG_START, LOG_END y FN_CHECK_INSTANCE.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_PRODUCT]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @nComponent INT = 403
        , @nRecords BIGINT = 0
        , @dtStarting DATETIME2(0) = SYSDATETIME()
        , @dtEnding DATETIME2(0)
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Materializa el conjunto que sera revisado durante esta ejecucion.
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
    WHERE R.QUEUE_NAME = 'Product'
      AND R.CREATED > DATEADD(DAY, -10, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
      AND R.PROCESSED IS NULL;

    -- Solo las instancias no permitidas producen una actualizacion del mensaje.
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

    -- LOG_END restablece el componente y registra el total inspeccionado.
    EXEC [EAI_OWNER].[LOG_END]
         @nComponent = @nComponent, @dtBegin = @dtStarting,
         @dtEnd = @dtEnding, @nRecords = @nRecords;
END;
GO
