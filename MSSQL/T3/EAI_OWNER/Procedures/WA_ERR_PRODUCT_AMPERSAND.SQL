/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_PRODUCT_AMPERSAND (Oracle).

    Objetivo funcional:
      1. Iniciar y registrar la ejecucion del componente 839.
      2. Buscar mensajes Product en Error por ORA-31011 dentro del periodo.
      3. Reemplazar cada ampersand (&) por "y", validar el XML corregido e
         insertarlo en MX_RECEIVE_MESSAGE_LOG.
      4. Marcar los mensajes originales para reproceso y cerrar la bitacora.

    Equivalencia de identificadores:
      MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle para localizar la fila
      origen. El Row_ID del mensaje de recepcion conserva su formato actual.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_PRODUCT_AMPERSAND]
(
    @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle registra el error y hace COMMIT en WHEN OTHERS. XACT_ABORT OFF
        permite confirmar el trabajo previo cuando la transaccion de SQL Server
        permanece en estado confirmable despues de una excepcion.
    */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         VARCHAR(300),
        @nPedidos     INT = 0,
        @nPID         BIGINT = NULL,
        @nProceso     INT = 839,
        @FechaProceso DATETIME2(0),
        @FechaCorte   DATETIME2(0);

    /*
        Esta tabla materializa el cursor Oracle antes de insertar y actualizar.
        CandidateNo sustituye ROWNUM solamente para construir el nuevo Row_ID.

        Cambio homologado ROW_ID:
        Source_ROW_ID conserva la llave de la fila origen del log.
    */
    DECLARE @ProductErrors TABLE
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
        -- 2. Congelar, sanear y validar los mensajes Product con error.
        ----------------------------------------------------------------------
        /* Cambio homologado ROW_ID: materializar la llave de cada fila origen. */
        INSERT INTO @ProductErrors
        (
            Source_ROW_ID,
            Queue_Name,
            XML_Content
        )
        SELECT
            Err.ROW_ID,
            Err.Queue_Name,
            /*
                El origen calcula Fase1 a Fase24, pero XMLTYPE concatena solo
                Fase1 a Fase23. Por compatibilidad se procesan exactamente
                23 * 3,900 = 89,700 caracteres; Fase24 no forma parte del XML.

                CAST, y no TRY_CAST, conserva la regla de XMLTYPE: si despues
                del reemplazo el contenido no es XML valido, se ejecuta CATCH.
            */
            CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 89700),
                    '&',
                    'y'
                )
                AS XML
            )
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        WHERE Err.Queue_Name = 'Product'
          /* Direction = 'Receive' esta comentado en Oracle y no se aplica. */
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        /*
            Formato Oracle: YYYYMMDDHH24MISS + LPAD(ROWNUM, 9, '0').
            El cursor no contiene ORDER BY; CandidateNo tampoco establece una
            prioridad de negocio. LEFT reproduce el limite de nueve caracteres.
        */
        UPDATE P
           SET P.Row_ID =
                   CONVERT(CHAR(8), @FechaProceso, 112)
                 + REPLACE(CONVERT(CHAR(8), @FechaProceso, 108), ':', '')
                 + CASE
                       WHEN LEN(N.SequenceText) >= 9
                           THEN LEFT(N.SequenceText, 9)
                       ELSE RIGHT('000000000' + N.SequenceText, 9)
                   END
        FROM @ProductErrors AS P
        CROSS APPLY
        (
            SELECT CONVERT(VARCHAR(20), P.CandidateNo)
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
            P.Row_ID,
            @FechaProceso,
            P.Queue_Name,
            P.XML_Content
        FROM @ProductErrors AS P;

        -- El cursor Oracle incrementa nPedidos por cada INSERT exitoso.
        SET @nPedidos = @@ROWCOUNT;

        /* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
        UPDATE Err
           SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @ProductErrors AS P
            ON P.Source_ROW_ID = Err.ROW_ID
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
            Si la transaccion no puede confirmarse se revierte antes de insertar
            el log. Si aun es confirmable, el COMMIT final reproduce el manejo
            de excepcion del procedimiento Oracle.
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
            'WA_ERR_PRODUCT',
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
