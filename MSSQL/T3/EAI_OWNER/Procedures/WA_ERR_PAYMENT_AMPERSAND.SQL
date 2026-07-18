/*
    Homologo SQL Server de EAI_OWNER.WA_ERR_PAYMENT_AMPERSAND (Oracle).

    Objetivo funcional:
      1. Buscar pagos recibidos que quedaron en Error por ORA-31011.
      2. Reemplazar cada ampersand (&) por "y" en los primeros 19,500
         caracteres del mensaje y validar el resultado como XML.
      3. Reprocesar solamente documentos cuyo DocumentType sea ZV o CR.
      4. Marcar el mensaje original con Status = 'Reprocess'.

    Equivalencia de identificadores:
      MX_EAI_MESSAGE_LOG.ROW_ID sustituye el ROWID Oracle para identificar la
      fila origen. El Row_ID generado para MX_RECEIVE_MESSAGE_LOG conserva su
      formato y proposito independiente.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ERR_PAYMENT_AMPERSAND]
(
    @pDias INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle registra la excepcion y hace COMMIT dentro de WHEN OTHERS.
        XACT_ABORT OFF permite confirmar el trabajo previo si SQL Server deja
        la transaccion en estado confirmable despues del error.
    */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         VARCHAR(300),
        @nPedidos     INT = 0,
        @FechaProceso DATETIME2(0),
        @FechaCorte   DATETIME2(0);

    /*
        La tabla variable materializa el cursor de Oracle. CandidateNo sustituye
        ROWNUM exclusivamente para construir el Row_ID del mensaje reprocesado.

        Cambio homologado ROW_ID:
        Source_ROW_ID conserva la llave de la fila origen del log.
    */
    DECLARE @PaymentErrors TABLE
    (
        CandidateNo   INT IDENTITY(1,1) NOT NULL,
        Source_ROW_ID BIGINT NOT NULL,
        Queue_Name    VARCHAR(30) NULL,
        XML_Content   XML NULL,
        DocumentType  VARCHAR(2) NULL,
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
        -- 1. Congelar y transformar los errores que atiende esta ejecucion.
        ----------------------------------------------------------------------
        /* Cambio homologado ROW_ID: materializar la llave de cada fila origen. */
        INSERT INTO @PaymentErrors
        (
            Source_ROW_ID,
            Queue_Name,
            XML_Content,
            DocumentType
        )
        SELECT
            Err.ROW_ID,
            Err.Queue_Name,
            /*
                Oracle concatena cinco bloques de 3,900 caracteres. Tomar los
                primeros 19,500 caracteres produce el mismo contenido. CAST,
                en lugar de TRY_CAST, conserva XMLTYPE: XML invalido es error.
            */
            CAST
            (
                REPLACE
                (
                    SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 19500),
                    '&',
                    'y'
                )
                AS XML
            ),
            CASE
                WHEN D.CloseDocType > 0
                    THEN SUBSTRING(D.MessagePrefix, D.CloseDocType - 2, 2)
                ELSE '  '
            END
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err WITH (UPDLOCK, HOLDLOCK)
        CROSS APPLY
        (
            SELECT MessagePrefix =
                CAST(SUBSTRING(CAST(Err.Message AS VARCHAR(MAX)), 1, 2000)
                     AS VARCHAR(2000))
        ) AS P
        CROSS APPLY
        (
            SELECT
                P.MessagePrefix,
                CloseDocType = CHARINDEX('</DocumentType>', P.MessagePrefix)
        ) AS D
        WHERE Err.Queue_Name = 'Payment'
          AND Err.Direction = 'Receive'
          AND Err.Status = 'Error'
          AND Err.Siebel_Error_Message LIKE '%-ORA-31011%'
          AND Err.Created > @FechaCorte;

        /*
            Formato Oracle: YYYYMMDDHH24MISS + LPAD(ROWNUM, 8, '0').
            El cursor Oracle no define ORDER BY, por lo que CandidateNo tampoco
            representa una prioridad de negocio.
        */
        UPDATE P
           SET P.Row_ID =
                   CONVERT(CHAR(8), @FechaProceso, 112)
                 + REPLACE(CONVERT(CHAR(8), @FechaProceso, 108), ':', '')
                 + CASE
                       WHEN LEN(N.SequenceText) >= 8
                           THEN LEFT(N.SequenceText, 8)
                       ELSE RIGHT('00000000' + N.SequenceText, 8)
                   END
        FROM @PaymentErrors AS P
        CROSS APPLY
        (
            SELECT CONVERT(VARCHAR(20), P.CandidateNo)
        ) AS N(SequenceText);

        ----------------------------------------------------------------------
        -- 2. Insertar y marcar solamente los tipos permitidos por Oracle.
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
        FROM @PaymentErrors AS P
        WHERE P.DocumentType IN ('ZV', 'CR');

        -- El cursor incrementa nPedidos una vez por cada INSERT exitoso.
        SET @nPedidos = @@ROWCOUNT;

        /* Cambio homologado ROW_ID: actualizar solo las filas materializadas. */
        UPDATE Err
           SET Err.Status = 'Reprocess'
        FROM [EAI_OWNER].[MX_EAI_MESSAGE_LOG] AS Err
        INNER JOIN @PaymentErrors AS P
            ON P.Source_ROW_ID = Err.ROW_ID
           AND P.DocumentType IN ('ZV', 'CR')
        WHERE Err.Status = 'Error';

        PRINT CONCAT('Documentos -> ', @nPedidos);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        /*
            Si la transaccion quedo no confirmable debe revertirse antes de
            escribir la bitacora. Si sigue valida, el COMMIT reproduce el
            manejo de excepcion del procedimiento Oracle.
        */
        IF XACT_STATE() = -1
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
            [Sequence],
            Parent_Row_ID
        )
        VALUES
        (
            'WA Payment',
            NULL,
            SYSDATETIME(),
            NULL,
            'Error',
            'WA_ERR_PAYMENT',
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
