/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_REPLENISHMENT_LARGE (Oracle).

    Objetivo funcional:
      1. Iniciar y registrar la ejecucion del componente 838.
      2. Buscar mensajes de la cola indicada que quedaron en Error por
         ORA-31011 dentro del periodo solicitado.
      3. Reemplazar cada ampersand (&) por "y", validar el XML corregido e
         insertarlo en MX_RECEIVE_MESSAGE_LOG.
      4. Marcar los mensajes originales para reproceso y cerrar la bitacora.

    Equivalencia de identificadores:
      MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle para localizar la fila
      origen. El Row_ID del mensaje de recepcion conserva su formato actual.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_REPLENISHMENT_LARGE]
(
    @pDias      INT = 0,
    @pQueueName VARCHAR(30) = 'VanReplenishment'
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle registra la excepcion y ejecuta COMMIT dentro de WHEN OTHERS.
        XACT_ABORT OFF permite confirmar el trabajo previo cuando SQL Server
        deja la transaccion en un estado confirmable despues de un error.
    */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         VARCHAR(300),
        @nPedidos     INT = 0,
        @nPID         BIGINT = NULL,
        @nProceso     INT = 838,
        @FechaProceso DATETIME2(0),
        @FechaCorte   DATETIME2(0);

    /*
        Esta tabla materializa el cursor Oracle. CandidateNo sustituye ROWNUM
        exclusivamente para formar el Row_ID del mensaje que se reprocesara.

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
        BEGIN TRANSACTION;

        SET @FechaProceso = SYSDATETIME();

        /* Equivale a TRUNC(SYSDATE - pDias): el corte inicia a medianoche. */
        SET @FechaCorte = DATEADD
        (
            DAY,
            -@pDias,
            CONVERT(date, @FechaProceso)
        );

        ----------------------------------------------------------------------
        -- 1. Inicio del componente y de su bitacora de proceso.
        ----------------------------------------------------------------------
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

        ----------------------------------------------------------------------
        -- 2. Congelar, sanear y validar los mensajes seleccionados.
        ----------------------------------------------------------------------
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
                Oracle calcula Fase1 a Fase40, pero XMLTYPE concatena solamente
                Fase1 a Fase39. Por compatibilidad se procesan exactamente
                39 * 3,900 = 152,100 caracteres; Fase40 queda fuera del XML.

                CAST, y no TRY_CAST, reproduce XMLTYPE: si el contenido sigue
                siendo XML invalido, el flujo debe pasar al bloque CATCH.
            */
            CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 152100),
                    '&',
                    'y'
                )
                AS XML
            )
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = @pQueueName
          /* Direction = 'Receive' esta comentado en Oracle y no se aplica. */
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        /*
            Formato Oracle: YYYYMMDDHH24MISS + LPAD(ROWNUM, 7, '0').
            El cursor no tiene ORDER BY; CandidateNo tampoco representa una
            prioridad de negocio. LEFT conserva el limite de siete caracteres.
        */
        UPDATE R
           SET R.Row_ID =
                   CONVERT(CHAR(8), @FechaProceso, 112)
                 + REPLACE(CONVERT(CHAR(8), @FechaProceso, 108), ':', '')
                 + CASE
                       WHEN LEN(N.SequenceText) >= 7
                           THEN LEFT(N.SequenceText, 7)
                       ELSE RIGHT('0000000' + N.SequenceText, 7)
                   END
        FROM @ReplenishmentErrors AS R
        CROSS APPLY
        (
            SELECT CONVERT(VARCHAR(20), R.CandidateNo)
        ) AS N(SequenceText);

        ----------------------------------------------------------------------
        -- 3. Crear los mensajes corregidos y habilitar su reproceso.
        ----------------------------------------------------------------------
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

        -- El cursor Oracle incrementa nPedidos por cada INSERT exitoso.
        SET @nPedidos = @@ROWCOUNT;

        /* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
        UPDATE Err
           SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @ReplenishmentErrors AS R
            ON R.Source_ROW_ID = Err.ROW_ID
        WHERE Err.Status = 'Error';

        PRINT CONCAT('Documentos -> ', @nPedidos);

        ----------------------------------------------------------------------
        -- 4. Cerrar el componente y registrar el resultado de la ejecucion.
        ----------------------------------------------------------------------
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

        /*
            Una transaccion no confirmable debe revertirse antes de escribir el
            log. Si sigue confirmable, el COMMIT final reproduce la excepcion
            Oracle, que conserva el trabajo realizado antes del error.
        */
        IF XACT_STATE() = -1
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
            [Sequence],
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
            'WA_ERR_REPLENISHMENT',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y finaliza sin volver a lanzarlo.
        RETURN;
    END CATCH;
END;
GO
