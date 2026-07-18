/*
    Homologo SQL Server de EAI_OWNER.WA_PURGE_MX_EAI_MESSAGE_LOG (Oracle).

    Objetivo funcional:
      1. Extraer Reference y Parent_Row_ID de mensajes recientes con ORA-31011.
      2. Eliminar del log los mensajes cuyo documento ya existe en las tablas
         operativas correspondientes.

    Importante:
      pDias solo limita la actualizacion de referencias. El cursor de purga
      Oracle no filtra por fecha, Direction ni Status; esta version conserva
      esa regla.

    MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle. Los candidatos se
    materializan por esa llave antes de eliminarlos, evitando depender de que
    las relaciones de negocio permanezcan sin cambios durante la purga.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_PURGE_MX_EAI_MESSAGE_LOG]
(
    /* NUMBER permite fracciones de dia; un NULL explicito sigue siendo NULL. */
    @pDias DECIMAL(10,4) = 2
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Oracle confirma trabajo parcial al entrar en WHEN OTHERS. */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg       VARCHAR(300),
        @nPedidos   INT = 0,
        @nPID       BIGINT = NULL,
        @sRowID     VARCHAR(50) = NULL,
        @FechaCorte DATETIME2(0);

    /*
        Cambio homologado ROW_ID:
        @PurgeRows conserva las llaves de las filas origen seleccionadas por
        las relaciones de negocio, antes de ejecutar la eliminacion.
    */
    DECLARE @PurgeRows TABLE
    (
        ROW_ID BIGINT NOT NULL PRIMARY KEY
    );

    BEGIN TRY
        /*
            Equivale a TRUNC(SYSDATE - pDias). No se usa COALESCE porque Oracle
            tampoco aplica NVL: si el llamador envia NULL, no se actualiza nada.
        */
        SET @FechaCorte = CONVERT
        (
            date,
            DATEADD
            (
                SECOND,
                CONVERT(INT, -@pDias * 86400),
                SYSDATETIME()
            )
        );

        ----------------------------------------------------------------------
        -- 1. Completar referencias usadas posteriormente por la purga.
        ----------------------------------------------------------------------
        BEGIN TRANSACTION;

        /*
            DBMS_LOB.SUBSTR usa (cantidad, posicion). Por ejemplo, (10,409)
            se convierte en SUBSTRING(Message, 409, 10).
        */
        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 409, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 245, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'VanReplenishment'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 408, 8),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 237, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'Product'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 399, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 238, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'Customer'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 362, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 248, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'Invoice-Intercompany'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 504, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 236, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'Payment'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        /* Primer COMMIT explicito del procedimiento Oracle. */
        COMMIT TRANSACTION;

        ----------------------------------------------------------------------
        -- 2. Eliminar mensajes cuyo documento relacionado ya fue cargado.
        ----------------------------------------------------------------------
        BEGIN TRANSACTION;

        /* Cambio homologado ROW_ID: materializar las filas candidatas. */
        INSERT INTO @PurgeRows (ROW_ID)
        SELECT Err.ROW_ID
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE
               (
                   Err.Queue_Name = 'VanReplenishment'
                   AND EXISTS
                       (
                           SELECT 1
                           FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER] AS Delv
                           WHERE Delv.ReferenceID = Err.Reference
                       )
               )
            OR (
                   Err.Queue_Name = 'Invoice'
                   AND EXISTS
                       (
                           SELECT 1
                           FROM [T3].[FACTURA_GENERAL] AS Inv
                           WHERE Inv.Entrega = Err.Reference
                       )
               )
            OR (
                   Err.Queue_Name = 'Invoice'
                   AND EXISTS
                       (
                           SELECT 1
                           FROM [T3].[PREVENTA_GENERAL] AS Inv
                           WHERE Inv.Entrega = Err.Reference
                       )
               )
            OR (
                   Err.Queue_Name = 'Invoice-Intercompany'
                   AND EXISTS
                       (
                           SELECT 1
                           FROM [T3].[PREVENTA_GENERAL] AS Inv
                           WHERE Inv.Entrega = Err.Reference
                       )
               )
            OR (
                   Err.Queue_Name = 'Invoice-Intercompany'
                   AND EXISTS
                       (
                           SELECT 1
                           FROM [T3].[OTROS_GENERAL] AS Inv
                           WHERE Inv.Factura = Err.Reference
                       )
               );

        /* Referencia equivalente a la ultima fila del cursor sin ORDER BY. */
        SELECT @sRowID = CONVERT(VARCHAR(50), MAX(ROW_ID))
        FROM @PurgeRows;

        /* Cambio homologado ROW_ID: eliminar solo las filas materializadas. */
        DELETE Err
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @PurgeRows AS P
            ON P.ROW_ID = Err.ROW_ID;

        /* Cantidad real de filas eliminadas por el DELETE de SQL Server. */
        SET @nPedidos = @@ROWCOUNT;

        /* Segundo COMMIT explicito del procedimiento Oracle. */
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        PRINT CONCAT('Documentos -> ', @nPedidos);
        PRINT CONCAT('Ref        -> ', @sRowID);

        /*
            Oracle ejecuta COMMIT al entrar en EXCEPTION. SQL Server no permite
            confirmar una transaccion condenada, por lo que en ese unico caso
            se hace ROLLBACK; una transaccion confirmable conserva sus cambios.
        */
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction,
            Reference,
            Created,
            Message,
            Job_PID,
            Status,
            Queue_Name,
            Siebel_Error_Message,
            Source,
            Siebel_Error_Code,
            Retry_Count,
            [Sequence],
            Parent_Row_ID
        )
        VALUES
        (
            'Job Logging',
            @sRowID,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_PURGE_MX_EAI_MESSAGE_LOG',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra el error y finaliza sin volver a lanzarlo.
        RETURN;
    END CATCH;
END;
GO
