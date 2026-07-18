/*
    Procedimiento : EAI_OWNER.PROC_CUSTOMER
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.PROC_CUSTOMER (Oracle)
    Proposito     : Transformar un mensaje Customer recibido desde V3 en el
                    XML que sera enviado a la cola TaO Customer Inbound.

    Parametros
    ----------
    @sROW_ID : Identificador VARCHAR de MX_RECEIVE_MESSAGE_LOG.
    @nROWNUM : Posicion del mensaje en el lote. Se conserva por compatibilidad
               con la firma Oracle; este procedimiento no lo utiliza.
    @nPID    : Identificador de la ejecucion que origino el procesamiento.

    Flujo principal
    ---------------
    1. Extrae del XML los datos generales del cliente.
    2. Obtiene el centro en T3.MOV_CLIENTE; usa MX1A cuando no existe.
    3. Construye el XML Siebel/TaO y lo inserta en MX_SEND_MESSAGE_LOG.
    4. Marca el mensaje de entrada como Processed.
    5. Si ocurre un error, marca la entrada como Error y registra el detalle
       en MX_EAI_MESSAGE_LOG.

    Notas de mantenimiento
    ----------------------
    - @sROW_ID NO es MX_EAI_MESSAGE_LOG.ROW_ID. Esta ultima columna es BIGINT
      y se llena por el DEFAULT asociado a su secuencia.
    - Los nombres, prefijos y namespace del XML son parte del contrato de
      integracion. Deben compararse contra una muestra Oracle antes de cambiar.
    - Si V3CustomerNumber viene NULL, se conserva la conducta Oracle: no se
      genera salida y el mensaje permanece sin actualizar.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[PROC_CUSTOMER]
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
          @v_ID          VARCHAR(30)
        , @sProcesar     VARCHAR(2) = 'SI'
        , @sCtro         VARCHAR(4)
        , @SAPCustomer   VARCHAR(50)
        , @IntegrationID VARCHAR(100)
        , @MaxCreditDays VARCHAR(99)
        , @XmlSalida     XML;

    BEGIN TRY
        -- Lee un unico mensaje de entrada y extrae valores escalares del XML.
        SELECT
              @v_ID = R.XML_CONTENT.value('(/Customer/Message/GeneralData/V3CustomerNumber/text())[1]', 'varchar(30)')
            , @SAPCustomer = R.XML_CONTENT.value('(/Customer/Message/GeneralData/CustomerNumber/text())[1]', 'varchar(50)')
            , @IntegrationID = R.XML_CONTENT.value('(/Customer/Message/GeneralData/IntegrationID/text())[1]', 'varchar(100)')
            , @MaxCreditDays = R.XML_CONTENT.value('(/Customer/Message/GeneralData/PaymentTerms/text())[1]', 'varchar(99)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.ROW_ID = @sROW_ID;

        IF @@ROWCOUNT = 0
            RETURN;

        -- El centro determina el destino operativo del mensaje de salida.
        SELECT @sCtro = MAX(ISNULL(M.CTRO, 'MX1A'))
        FROM [T3].[MOV_CLIENTE] AS M
        WHERE M.CLIENTE_V3 = @v_ID;

        IF NULLIF(@sCtro, '') IS NULL
            SET @sCtro = 'MX1A';

        IF @v_ID IS NULL
            SET @sProcesar = 'NO';

        IF @sProcesar = 'SI'
        BEGIN
            /*
                Construccion del contrato XML equivalente a XMLELEMENT y
                XMLATTRIBUTES de Oracle. Los elementos vacios son deliberados.
            */
            ;WITH XMLNAMESPACES
            (
                'http://www.siebel.com/xml/BAT%20Customer%20Inbound%20IO' AS xnsp1
            )
            SELECT @XmlSalida =
            (
                SELECT
                      '' AS [@Operation]
                    , '' AS [xnsp1:Searchspec]
                    , '' AS [xnsp1:AccountStatus]
                    , '' AS [xnsp1:BATAllowedPayments]
                    , '' AS [xnsp1:BATCreditLimit]
                    , '' AS [xnsp1:BATEMCustField26]
                    , '' AS [xnsp1:BATEMCustField27]
                    , '' AS [xnsp1:BATEMCustField28]
                    , '' AS [xnsp1:BATEMCustField29]
                    , '' AS [xnsp1:BATEMCustField3]
                    , '' AS [xnsp1:BATEMCustField30]
                    , '' AS [xnsp1:BATGPSXCoord]
                    , '' AS [xnsp1:BATGPSYCoord]
                    , '' AS [xnsp1:BATInactiveReason]
                    , '' AS [xnsp1:BATIntDate]
                    , '' AS [xnsp1:BATInvoiceType]
                    , ISNULL([EAI_OWNER].[GETCONV]('ECC_V3 Payment Terms', @MaxCreditDays), '') AS [xnsp1:BATMAXCreditDays]
                    , '' AS [xnsp1:BATMAXCreditLimit]
                    , '' AS [xnsp1:BATOutletSubType]
                    , '' AS [xnsp1:BATOutletType]
                    , '' AS [xnsp1:BATOverdueInvoiceFlag]
                    , ISNULL(@SAPCustomer, '') AS [xnsp1:CSN]
                    , '' AS [xnsp1:CentralPaymentFlag]
                    , '' AS [xnsp1:CreditDays]
                    , ISNULL(@IntegrationID, '') AS [xnsp1:IntegrationId]
                    , ISNULL(@v_ID, '') AS [xnsp1:Location]
                    , '' AS [xnsp1:Name]
                    , '' AS [xnsp1:PriceList]
                    , '' AS [xnsp1:RuleAttribute2]
                    , '' AS [xnsp1:TaxExemptNumber]
                    , '' AS [xnsp1:TaxList]
                    , '' AS [xnsp1:BATGraceDays]
                    , '' AS [xnsp1:Type]
                FOR XML PATH('xnsp1:Account'), ROOT('xnsp1:ListOfBatCustomerInboundIo'), TYPE
            );

            -- Encola el XML transformado para el proceso de envio a TaO.
            INSERT INTO [EAI_OWNER].[MX_SEND_MESSAGE_LOG]
                (ROW_ID, CREATED, QUEUE_NAME, REFERENCE, CTRO, XML_CONTENT)
            VALUES
                (@sROW_ID, SYSDATETIME(), 'TaO Customer Inbound', @v_ID, @sCtro,
                 CONVERT(VARCHAR(MAX), @XmlSalida));

            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
               SET REFERENCE = @v_ID,
                   PROCESSED = SYSDATETIME(),
                   STATUS = CASE WHEN @sProcesar = 'SI' THEN 'Processed' ELSE 'Review' END
             WHERE ROW_ID = @sROW_ID;
        END;
    END TRY
    BEGIN CATCH
        DECLARE
              @sErrorCode VARCHAR(100) = CONCAT('MSSQL-', ERROR_NUMBER())
            , @sMsg       VARCHAR(250) = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- Evita que el mensaje con error vuelva a seleccionarse como pendiente.
        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
           SET PROCESSED = SYSDATETIME(), STATUS = 'Error'
         WHERE ROW_ID = @sROW_ID;

        /*
            ROW_ID no se incluye: el DEFAULT de MX_EAI_MESSAGE_LOG consume la
            secuencia definida para esa tabla.
        */
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, ID, CREATED, MESSAGE, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Receive', @v_ID, SYSDATETIME(), NULL, 'Error',
             'TaO Customer Inbound', @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);
    END CATCH;
END;
GO
