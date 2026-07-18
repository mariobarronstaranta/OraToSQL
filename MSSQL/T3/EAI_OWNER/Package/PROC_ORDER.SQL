/*
    Procedimiento : EAI_OWNER.PROC_ORDER
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.PROC_ORDER (Oracle)
    Proposito     : Interpretar el acuse de una orden y, cuando su estado se
                    convierte a Cancelled, generar el XML para TaO.

    Parametros
    ----------
    @sROW_ID : Identificador VARCHAR de MX_RECEIVE_MESSAGE_LOG.
    @nROWNUM : Posicion del mensaje en el lote; se conserva por compatibilidad.
    @nPID    : Identificador de la ejecucion para el log de errores.

    Estados generados
    -----------------
    Processed : Se genero el XML de cancelacion.
    CheckData : El XML no contiene DocumentNumber.
    Discard   : El estado convertido no requiere una cancelacion.
    Error     : Ocurrio una excepcion durante la transformacion.

    Notas de mantenimiento
    ----------------------
    - GETCONV con el tipo ECC_V3 Order Update decide si el documento se cancela.
    - El prefijo MX- se elimina antes de escribir OrderNumber en el XML.
    - Los nombres y namespace XML forman parte del contrato con TaO.
    - MX_EAI_MESSAGE_LOG.ROW_ID se genera por DEFAULT y no debe recibir el
      @sROW_ID VARCHAR del mensaje de entrada.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[PROC_ORDER]
(
      @sROW_ID VARCHAR(32)
    , @nROWNUM BIGINT
    , @nPID    NUMERIC(10,0) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @v_ID       VARCHAR(30)
        , @Status_CD  VARCHAR(99)
        , @sStatus_CD VARCHAR(30)
        , @sProcesar  VARCHAR(2) = 'NO'
        , @sOrderID   VARCHAR(50)
        , @XmlSalida  XML;

    BEGIN TRY
        -- Obtiene el estado y numero de documento desde el mensaje recibido.
        SELECT
              @Status_CD = R.XML_CONTENT.value('(/OrderAcknowledge/Message/ReferenceData/DocumentStatus/text())[1]', 'varchar(99)')
            , @v_ID = R.XML_CONTENT.value('(/OrderAcknowledge/Message/ReferenceData/DocumentNumber/text())[1]', 'varchar(30)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.ROW_ID = @sROW_ID;

        IF @@ROWCOUNT = 0
            RETURN;

        -- Traduce el estado V3 a la accion esperada por el flujo TaO.
        SET @sStatus_CD = [EAI_OWNER].[GETCONV]('ECC_V3 Order Update', @Status_CD);

        IF @sStatus_CD = 'Cancelled'
            SET @sProcesar = 'SI';
        ELSE
            SET @sProcesar = 'NA';

        IF @v_ID IS NULL
            SET @sProcesar = 'ED';

        IF @sProcesar = 'SI'
        BEGIN
            SET @sOrderID = REPLACE(@v_ID, 'MX-', '');

            -- Construye el documento de cancelacion equivalente al XML Oracle.
            ;WITH XMLNAMESPACES
            (
                'http://www.siebel.com/xml/BAT%20Order%20Ack%20Inbound%20IO' AS xsdLocal1
            )
            SELECT @XmlSalida =
            (
                SELECT
                      '' AS [@Operation]
                    , '' AS [xsdLocal1:Searchspec]
                    , '' AS [xsdLocal1:IntegrationId]
                    , ISNULL(@sOrderID, '') AS [xsdLocal1:OrderNumber]
                    , '' AS [xsdLocal1:RequestedShipDate]
                    , '' AS [xsdLocal1:SourceInventoryId]
                    , '' AS [xsdLocal1:SourceInventoryLocIntegrationId]
                    , '' AS [xsdLocal1:SourceInventoryLocation]
                    , 'Cancelled' AS [xsdLocal1:Status]
                FOR XML PATH('xsdLocal1:BatEaiOrderEntry-Orders'),
                        ROOT('xsdLocal1:ListOfBatOrderAckInboundIo'), TYPE
            );

            -- Encola unicamente las ordenes cuyo estado convertido es Cancelled.
            INSERT INTO [EAI_OWNER].[MX_SEND_MESSAGE_LOG]
                (ROW_ID, CREATED, QUEUE_NAME, REFERENCE, XML_CONTENT)
            VALUES
                (@sROW_ID, SYSDATETIME(), 'TaO OrderAck Inbound', @v_ID,
                 CONVERT(VARCHAR(MAX), @XmlSalida));

            -- Los casos sin datos o sin accion se cierran sin generar salida.
            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
               SET REFERENCE = @v_ID, PROCESSED = SYSDATETIME(), STATUS = 'Processed'
             WHERE ROW_ID = @sROW_ID;
        END
        ELSE
        BEGIN
            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
               SET REFERENCE = @v_ID,
                   PROCESSED = SYSDATETIME(),
                   STATUS = CASE WHEN @sProcesar = 'ED' THEN 'CheckData' ELSE 'Discard' END
             WHERE ROW_ID = @sROW_ID;
        END;
    END TRY
    BEGIN CATCH
        DECLARE
              @sErrorCode VARCHAR(100) = CONCAT('MSSQL-', ERROR_NUMBER())
            , @sMsg       VARCHAR(250) = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
           SET PROCESSED = SYSDATETIME(), STATUS = 'Error'
         WHERE ROW_ID = @sROW_ID;

        -- ROW_ID se genera mediante el DEFAULT de MX_EAI_MESSAGE_LOG.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, ID, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', @v_ID, SYSDATETIME(), NULL, @nPID, 'Error',
             'PROC_ORDER', @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);
    END CATCH;
END;
GO
