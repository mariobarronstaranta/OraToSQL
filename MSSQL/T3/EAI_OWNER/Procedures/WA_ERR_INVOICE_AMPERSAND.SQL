/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_INVOICE_AMPERSAND (Oracle).

    Objetivo funcional:
      1. Identificar mensajes de factura rechazados por el error ORA-31011.
      2. Completar Reference y Parent_Row_ID a partir de posiciones fijas del XML.
      3. Reemplazar cada ampersand (&) por "y", validar el XML corregido e
         insertarlo nuevamente en MX_RECEIVE_MESSAGE_LOG.
      4. Marcar el mensaje original como Reprocess.
      5. Ejecutar el reproceso equivalente para pagos y cerrar la bitacora 830.

    MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle y permite relacionar
    cada mensaje reprocesado con una unica fila origen.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_INVOICE_AMPERSAND]
(
    @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Oracle confirma el trabajo previo dentro de WHEN OTHERS. XACT_ABORT OFF
    -- permite hacer lo mismo cuando la transaccion continua siendo confirmable.
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode    VARCHAR(30),
        @sMsg          VARCHAR(300),
        @v_ID          VARCHAR(30) = NULL,
        @nPedidos      INT = 0,
        @nPID          BIGINT = NULL,
        @nProceso      INT = 830,
        @ReferenceNow  DATETIME2(0),
        @ReprocessNow  DATETIME2(0);

    /*
        Cambio homologado ROW_ID:
        Source_ROW_ID conserva la identidad de la fila origen. Row_ID mantiene
        por separado el identificador logico de MX_RECEIVE_MESSAGE_LOG.
    */
    DECLARE @InvoiceErrors TABLE
    (
        CandidateNo   INT IDENTITY(1,1) NOT NULL,
        Source_ROW_ID BIGINT NOT NULL,
        SAP_DocRef    VARCHAR(50) NULL,
        Queue_Name    VARCHAR(30) NULL,
        XML_Content   XML NULL,
        Row_ID        VARCHAR(32) NULL
    );

    BEGIN TRY
        -----------------------------------------------------------------------
        -- 1. Inicio de proceso y extraccion de referencias desde el mensaje.
        -----------------------------------------------------------------------
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
            SYSDATETIME()
        );

        SET @ReferenceNow = SYSDATETIME();

        UPDATE Err
           SET Err.Reference =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 399, 10),
               Err.Parent_Row_ID =
                   SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 236, 16)
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = 'Invoice'
          AND Err.Direction = 'Receive'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          -- Equivale a Created > TRUNC(SYSDATE - pDias).
          AND Err.Created > DATEADD(DAY, -@pDias, CAST(@ReferenceNow AS DATE))
          AND Err.Parent_Row_ID IS NULL;

        -- Primer COMMIT explicito del procedure Oracle.
        COMMIT TRANSACTION;

        -----------------------------------------------------------------------
        -- 2. Preparacion de los errores de factura que se van a reprocesar.
        -----------------------------------------------------------------------
        BEGIN TRANSACTION;

        SET @ReprocessNow = SYSDATETIME();

        /* Cambio homologado ROW_ID: materializar la llave de cada fila origen. */
        INSERT INTO @InvoiceErrors
        (
            Source_ROW_ID,
            SAP_DocRef,
            Queue_Name,
            XML_Content
        )
        SELECT
            Err.ROW_ID,
            Err.Reference,
            Err.Queue_Name,
            /*
                Oracle concatena 41 bloques de 3,900 caracteres: como maximo
                procesa 159,900 caracteres. CAST, y no TRY_CAST, conserva la
                regla de XMLTYPE: un XML invalido debe activar el CATCH.
            */
            CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 159900),
                    '&',
                    'y'
                )
                AS XML
            )
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = 'Invoice'
          AND Err.Direction = 'Receive'
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          -- ScrPresales siempre usa un dia; no utiliza @pDias.
          AND Err.Created > DATEADD(DAY, -1, CAST(@ReprocessNow AS DATE));

        /*
            Formato Oracle: YYYYMMDDHH24MISS + LPAD(ROWNUM, 5, '0').
            ROWNUM no tiene ORDER BY, por eso CandidateNo tampoco agrega una
            prioridad de negocio. LEFT reproduce el recorte de LPAD si el
            consecutivo llega a tener mas de cinco caracteres.
        */
        UPDATE E
           SET E.Row_ID =
                   CONVERT(CHAR(8), @ReprocessNow, 112)
                 + REPLACE(CONVERT(CHAR(8), @ReprocessNow, 108), ':', '')
                 + CASE
                       WHEN LEN(S.SequenceText) >= 5 THEN LEFT(S.SequenceText, 5)
                       ELSE RIGHT('00000' + S.SequenceText, 5)
                   END
        FROM @InvoiceErrors AS E
        CROSS APPLY
        (
            SELECT CONVERT(VARCHAR(20), E.CandidateNo)
        ) AS S(SequenceText);

        -- Equivale a v_ID := Inv.SAP_DocRef de la ultima vuelta del cursor.
        SELECT TOP (1)
            @v_ID = E.SAP_DocRef
        FROM @InvoiceErrors AS E
        ORDER BY E.CandidateNo DESC;

        INSERT INTO [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        (
            Row_ID,
            Created,
            Queue_Name,
            XML_Content
        )
        SELECT
            E.Row_ID,
            @ReprocessNow,
            E.Queue_Name,
            E.XML_Content
        FROM @InvoiceErrors AS E;

        -- Oracle incrementa nPedidos una vez por cada INSERT exitoso.
        SET @nPedidos = @@ROWCOUNT;

        /* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
        UPDATE Err
           SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @InvoiceErrors AS E
            ON E.Source_ROW_ID = Err.ROW_ID
        WHERE Err.Status = 'Error';

        PRINT CONCAT('Documentos -> ', @nPedidos);

        -- Segundo COMMIT explicito del procedure Oracle.
        COMMIT TRANSACTION;

        -----------------------------------------------------------------------
        -- 3. El origen ejecuta despues el mismo saneamiento para pagos.
        -----------------------------------------------------------------------
        EXEC [EAI_OWNER].[WA_ERR_PAYMENT_AMPERSAND]
            @pDias = @pDias;

        -----------------------------------------------------------------------
        -- 4. Cierre del componente y de la bitacora del proceso 830.
        -----------------------------------------------------------------------
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
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- Una transaccion no confirmable debe revertirse antes de insertar el
        -- log. Si sigue valida, Oracle la confirma junto con la bitacora.
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            JOB_PID,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            [Sequence],
            PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging',
            @v_ID,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_ERR_INVOICE_AMPERSAND',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y termina sin RAISE.
        RETURN;
    END CATCH;
END;
GO
