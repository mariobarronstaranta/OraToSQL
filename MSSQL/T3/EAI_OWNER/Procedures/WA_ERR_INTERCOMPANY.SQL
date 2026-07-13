/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_INTERCOMPANY (Oracle).

    Objetivo:
      Recuperar mensajes intercompany cuyo XML fallo por caracteres invalidos,
      sanear su contenido, copiarlos al log de recepcion y dejarlos disponibles
      para reproceso.

    Nota de migracion:
      Oracle usa el ROWID fisico del log y genera otro identificador mediante
      fecha + ROWNUM. MX_EAI_MESSAGE_LOG no tiene una llave equivalente en SQL
      Server; para el nuevo mensaje se genera un GUID sin guiones (32 caracteres).
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_INTERCOMPANY]
    @pDias INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sErrorCode VARCHAR(30),
        @sMsg       VARCHAR(300),
        @nPedidos   INT = 0,
        @nPID       BIGINT,
        @nProceso   INT = 829,
        @FechaCorte DATETIME2(0);

    /* Equivale a TRUNC(SYSDATE - pDias). */
    SET @FechaCorte = DATEADD(DAY, -@pDias, CONVERT(date, SYSDATETIME()));

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------------
        -- 1. Inicio y auditoria del proceso 829
        ----------------------------------------------------------------------
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, SYSDATETIME());

        ----------------------------------------------------------------------
        -- 2. Congelar los errores que atendera esta ejecucion
        ----------------------------------------------------------------------
        /*
            UPDLOCK + HOLDLOCK evita que dos ejecuciones reprocesen el mismo
            conjunto. SourceToken solo sirve para distinguir las filas durante
            esta ejecucion; no se almacena en tablas de negocio.
        */
        SELECT
            SourceToken   = NEWID(),
            ReceiveRow_ID = REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''),
            Err.Queue_Name,
            Err.Message
        INTO #SourceMessages
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = 'Invoice-Intercompany'
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        ----------------------------------------------------------------------
        -- 3. Reconstruir y validar el XML
        ----------------------------------------------------------------------
        /*
            El Oracle original divide el CLOB en segmentos de 3900 caracteres,
            sanea cada segmento y concatena Fase1...Fase39. Aunque calcula una
            Fase40, no la concatena; por compatibilidad se conservan 39 bloques.

            Sustituciones originales:
              &    -> y
              <(>  -> cadena vacia
              <)>  -> cadena vacia
        */
        ;WITH ChunkNumbers AS
        (
            SELECT 1 AS ChunkNo
            UNION ALL
            SELECT ChunkNo + 1
            FROM ChunkNumbers
            WHERE ChunkNo < 39
        ),
        SanitizedChunks AS
        (
            SELECT
                S.SourceToken,
                S.ReceiveRow_ID,
                S.Queue_Name,
                N.ChunkNo,
                CleanChunk = REPLACE
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            SUBSTRING
                            (
                                CAST(S.Message AS VARCHAR(MAX)),
                                ((N.ChunkNo - 1) * 3900) + 1,
                                3900
                            ),
                            '&',
                            'y'
                        ),
                        '<(>',
                        ''
                    ),
                    '<)>',
                    ''
                )
            FROM #SourceMessages S
            CROSS JOIN ChunkNumbers N
        )
        SELECT
            C.SourceToken,
            C.ReceiveRow_ID,
            C.Queue_Name,
            XML_Content = CAST
            (
                STRING_AGG(CAST(C.CleanChunk AS VARCHAR(MAX)), '')
                    WITHIN GROUP (ORDER BY C.ChunkNo)
                AS XML
            )
        INTO #ReprocessedMessages
        FROM SanitizedChunks C
        GROUP BY
            C.SourceToken,
            C.ReceiveRow_ID,
            C.Queue_Name
        OPTION (MAXRECURSION 39);

        INSERT INTO [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
            (Row_ID, Created, Queue_Name, XML_Content)
        SELECT
            R.ReceiveRow_ID,
            SYSDATETIME(),
            R.Queue_Name,
            R.XML_Content
        FROM #ReprocessedMessages R;

        -- Oracle incrementa nPedidos por cada mensaje copiado.
        SET @nPedidos = @@ROWCOUNT;

        ----------------------------------------------------------------------
        -- 4. Marcar los errores originales para reproceso
        ----------------------------------------------------------------------
        UPDATE Err
        SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] Err
        WHERE Err.Queue_Name = 'Invoice-Intercompany'
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        PRINT CONCAT('Documentos -> ', @nPedidos);

        ----------------------------------------------------------------------
        -- 5. Cierre de auditoria
        ----------------------------------------------------------------------
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
        SET
            Fin       = SYSDATETIME(),
            Proceso_1 = 0,
            Proceso_2 = 0,
            Proceso_3 = 0,
            Proceso_4 = @nPedidos
        WHERE PID = @nPID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- El registro del error se realiza fuera de la transaccion fallida.
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

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
            Sequence,
            Parent_Row_ID
        )
        VALUES
        (
            'Job Logging',
            NULL,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_ERR_INTERCOMPANY',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra la excepcion y termina sin propagarla.
        RETURN;
    END CATCH;
END;
GO
