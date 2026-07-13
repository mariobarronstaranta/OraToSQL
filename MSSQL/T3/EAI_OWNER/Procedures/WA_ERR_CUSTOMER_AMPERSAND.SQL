/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_CUSTOMER_AMPERSAND (Oracle).

    Objetivo:
      Recuperar mensajes de clientes que quedaron en Error, reemplazar cada
      ampersand por el texto "-amp-" para obtener XML valido, copiarlos al log
      de recepcion y marcar el mensaje original para reproceso.

    Diferencia estructural entre motores:
      Oracle utiliza el ROWID fisico de MX_EAI_MESSAGE_LOG. Esa tabla no tiene
      una llave equivalente en el modelo SQL Server, por lo que se genera un
      ROW_ID unico de 32 caracteres al insertar en MX_RECEIVE_MESSAGE_LOG.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_CUSTOMER_AMPERSAND]
    @pDias INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @nCustomers INT = 0,
        @sErrorCode VARCHAR(30),
        @sMsg       VARCHAR(300),
        @v_ID       VARCHAR(50),
        @FechaCorte DATETIME2(0);

    /* Equivale a TRUNC(SYSDATE - pDias): la hora del corte es 00:00:00. */
    SET @FechaCorte = DATEADD(DAY, -@pDias, CONVERT(date, SYSDATETIME()));

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
            Se materializa el conjunto antes de modificarlo. UPDLOCK y
            HOLDLOCK evitan que otra ejecucion procese simultaneamente las
            mismas filas mientras esta transaccion permanece abierta.
        */
        SELECT
            Receive_Row_ID = REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            Err.Queue_Name,
            XML_Content = CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 3900),
                    '&',
                    '-amp-'
                )
                AS XML
            )
        INTO #CustomersToReprocess
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Created    > @FechaCorte
          AND Err.Queue_Name = 'Customer'
          AND Err.Status     = 'Error';

        -- Se guarda una referencia util para el log si una operacion posterior
        -- falla. En el proceso por conjuntos no existe una "fila actual".
        SELECT @v_ID = MIN(Receive_Row_ID)
        FROM #CustomersToReprocess;

        INSERT INTO [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
            (Row_ID, Created, Queue_Name, XML_Content)
        SELECT
            C.Receive_Row_ID,
            SYSDATETIME(),
            C.Queue_Name,
            C.XML_Content
        FROM #CustomersToReprocess C;

        SET @nCustomers = @@ROWCOUNT;

        /*
            Se aplica el mismo filtro utilizado para crear el conjunto. Los
            bloqueos anteriores impiden que cambie entre el INSERT y el UPDATE.
        */
        UPDATE Err
        SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        WHERE Err.Created    > @FechaCorte
          AND Err.Queue_Name = 'Customer'
          AND Err.Status     = 'Error';

        PRINT CONCAT('Customers -> ', @nCustomers);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- El log de error debe insertarse despues del ROLLBACK para que no sea
        -- descartado junto con el reproceso incompleto.
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            Sequence,
            Parent_Row_ID
        )
        VALUES
        (
            'WA Customer',
            @v_ID,
            SYSDATETIME(),
            NULL,
            'Error',
            'WA_ERR_CUSTOMER',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra el error y finaliza sin propagar la excepcion.
        RETURN;
    END CATCH;
END;
GO
