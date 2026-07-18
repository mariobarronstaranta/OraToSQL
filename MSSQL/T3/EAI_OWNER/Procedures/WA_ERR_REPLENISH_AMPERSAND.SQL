/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_REPLENISH_AMPERSAND (Oracle).

    Objetivo funcional:
      1. Completar Reference y Parent_Row_ID de errores VanReplenishment.
      2. Corregir ampersands en el XML, reinsertarlo para reproceso y cambiar
         el mensaje original a Status = 'Reprocess'.
      3. Completar referencias faltantes de Product, Customer,
         Invoice-Intercompany y Payment.
      4. Cerrar la bitacora del componente 838.

    MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle para relacionar cada
    mensaje con su fila origen. El Row_ID generado para MX_RECEIVE_MESSAGE_LOG
    conserva su formato y proposito independiente.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_REPLENISH_AMPERSAND]
(
    @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Oracle confirma trabajo parcial dentro del bloque EXCEPTION. */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         VARCHAR(300),
        @nPedidos     INT = 0,
        @nPID         BIGINT = NULL,
        @nProceso     INT = 838,
        @sRowID       VARCHAR(50) = NULL,
        @FechaProceso DATETIME2(0),
        @FechaCorte   DATETIME2(0);

    /*
        Materializa el cursor Oracle y genera el consecutivo usado en Row_ID.

        Cambio homologado ROW_ID:
        Source_ROW_ID conserva la llave de la fila origen del log.
    */
    DECLARE @ReplenishmentErrors TABLE
    (
        CandidateNo   INT IDENTITY(1,1) NOT NULL,
        Source_ROW_ID BIGINT NOT NULL,
        Queue_Name    VARCHAR(30) NULL,
        XML_Content   XML NULL,
        Row_ID        VARCHAR(32) NULL
    );

    BEGIN TRY
        SET @FechaProceso = SYSDATETIME();

        ----------------------------------------------------------------------
        -- 1. Inicio de proceso, referencias Van y reproceso del XML.
        ----------------------------------------------------------------------
        BEGIN TRANSACTION;

        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[LOG_START]
            @nComponent = @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
        (
            PID,
            Proceso,
            Fecha_Proc_BATMD,
            Inicio
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            @FechaProceso
        );

        /* Equivale a TRUNC(SYSDATE - pDias): inicia a las 00:00:00. */
        SET @FechaCorte = DATEADD
        (
            DAY,
            -@pDias,
            CONVERT(date, @FechaProceso)
        );

        /*
            DBMS_LOB.SUBSTR recibe (cantidad, posicion). Por eso los valores
            Oracle (10,409) y (16,245) se traducen a inicio 409/245 y longitud
            10/16. Este UPDATE no filtra Status en el procedimiento original.
        */
        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 409, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 245, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        WHERE Err.Queue_Name = 'VanReplenishment'
          AND Err.Direction = 'Receive'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte
          AND Err.Parent_Row_ID IS NULL;

        /* Cambio homologado ROW_ID: materializar la llave de cada fila origen. */
        INSERT INTO @ReplenishmentErrors
        (
            Source_ROW_ID,
            Queue_Name,
            XML_Content
        )
        SELECT
            Err.ROW_ID,
            Err.Queue_Name,
            /*
                Oracle concatena 25 bloques de 3,900 caracteres: 97,500 en
                total. CAST estricto reproduce XMLTYPE; TRY_CAST ocultaria un
                XML que continua invalido y cambiaria la regla del origen.
            */
            CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 97500),
                    '&',
                    'y'
                )
                AS XML
            )
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = 'VanReplenishment'
          AND Err.Direction = 'Receive'
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        /* Formato Oracle: YYYYMMDDHH24MISS + LPAD(ROWNUM, 6, '0'). */
        UPDATE R
           SET R.Row_ID =
                   CONVERT(CHAR(8), @FechaProceso, 112)
                 + REPLACE(CONVERT(CHAR(8), @FechaProceso, 108), ':', '')
                 + CASE
                       WHEN LEN(N.SequenceText) >= 6
                           THEN LEFT(N.SequenceText, 6)
                       ELSE RIGHT('000000' + N.SequenceText, 6)
                   END
        FROM @ReplenishmentErrors AS R
        CROSS APPLY
        (
            SELECT CONVERT(VARCHAR(20), R.CandidateNo)
        ) AS N(SequenceText);

        /* Conserva como referencia el ROW_ID origen de la ultima candidata. */
        SELECT TOP (1)
            @sRowID = CONVERT(VARCHAR(50), R.Source_ROW_ID)
        FROM @ReplenishmentErrors AS R
        ORDER BY R.CandidateNo DESC;

        INSERT INTO [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        (
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        )
        SELECT
            R.Row_ID,
            @FechaProceso,
            R.Queue_Name,
            R.XML_Content
        FROM @ReplenishmentErrors AS R;

        SET @nPedidos = @@ROWCOUNT;

        /* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
        UPDATE Err
           SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @ReplenishmentErrors AS R
            ON R.Source_ROW_ID = Err.ROW_ID
        WHERE Err.Status = 'Error';

        PRINT CONCAT('Documentos -> ', @nPedidos);

        /* Primer COMMIT explicito del procedimiento Oracle. */
        COMMIT TRANSACTION;

        ----------------------------------------------------------------------
        -- 2. Completar referencias de las demas colas.
        ----------------------------------------------------------------------
        BEGIN TRANSACTION;

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

        /* Segundo COMMIT explicito del procedimiento Oracle. */
        COMMIT TRANSACTION;

        ----------------------------------------------------------------------
        -- 3. Cerrar el componente y la bitacora del proceso 838.
        ----------------------------------------------------------------------
        BEGIN TRANSACTION;

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
        WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = SYSDATETIME(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = 0,
               Proceso_4 = @nPedidos
        WHERE PID = @nPID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        PRINT CONCAT('Documentos -> ', @nPedidos);
        PRINT CONCAT('Ref        -> ', @sRowID);

        /*
            Oracle ejecuta COMMIT al entrar en EXCEPTION. En SQL Server una
            transaccion condenada debe revertirse; una confirmable se conserva.
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
            'WA_ERR_REPLENISH_AMPERSAND',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- En autocommit, el INSERT anterior equivale al COMMIT final de Oracle.
        RETURN;
    END CATCH;
END;
GO
