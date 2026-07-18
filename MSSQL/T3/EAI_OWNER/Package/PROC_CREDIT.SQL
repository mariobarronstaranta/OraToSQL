/*
    Procedimiento : EAI_OWNER.PROC_CREDIT
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.PROC_CREDIT (Oracle)
    Proposito     : Convertir un mensaje Customer Credit de V3 al XML de la
                    cola TaO Customer Credit Inbound.

    Parametros
    ----------
    @sROW_ID : Identificador VARCHAR de MX_RECEIVE_MESSAGE_LOG.
    @nROWNUM : Posicion dentro del lote; se mantiene por compatibilidad.
    @nPID    : Identificador de la ejecucion para trazabilidad de errores.

    Flujo principal
    ---------------
    1. Extrae cliente, limites de credito y dias de gracia del XML recibido.
    2. Convierte los importes de centavos a unidades dividiendo entre 100.
    3. Construye el XML de salida y lo inserta en MX_SEND_MESSAGE_LOG.
    4. Actualiza el estado del mensaje recibido.

    Notas de mantenimiento
    ----------------------
    - La conversion numerica es intencionalmente estricta: un valor no numerico
      genera error, igual que TO_NUMBER en Oracle.
    - AvailableLimit se valida y convierte, aunque el XML Oracle vigente envia
      AvailableCredit vacio. No eliminarlo sin confirmar el contrato funcional.
    - El atributo Operation vale 1 porque el Oracle original usa ROWNUM sobre
      DUAL; no corresponde a @nROWNUM.
    - MX_EAI_MESSAGE_LOG.ROW_ID se llena automaticamente mediante su DEFAULT.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[PROC_CREDIT]
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
          @v_ID            VARCHAR(30)
        , @SAPCustomer     VARCHAR(50)
        , @CreditLimitText VARCHAR(100)
        , @AvailableText   VARCHAR(100)
        , @GraceDays       VARCHAR(100)
        , @nCreditLimit    DECIMAL(22,4)
        , @nAvailableLimit DECIMAL(22,4)
        , @sProcesar       VARCHAR(2) = 'SI'
        , @sCtro           VARCHAR(4)
        , @XmlSalida       XML;

    BEGIN TRY
        -- Extrae los datos del mensaje identificado por el ROW_ID logico.
        SELECT
              @v_ID = R.XML_CONTENT.value('(/CustomerCredit/Message/PartnerData/V3CustomerNumber/text())[1]', 'varchar(30)')
            , @SAPCustomer = R.XML_CONTENT.value('(/CustomerCredit/Message/PartnerData/CustomerNumber/text())[1]', 'varchar(50)')
            , @CreditLimitText = R.XML_CONTENT.value('(/CustomerCredit/Message/PartnerData/CreditData/CreditLimit/text())[1]', 'varchar(100)')
            , @AvailableText = R.XML_CONTENT.value('(/CustomerCredit/Message/PartnerData/CreditData/AvailableLimit/text())[1]', 'varchar(100)')
            , @GraceDays = R.XML_CONTENT.value('(/CustomerCredit/Message/PartnerData/CreditData/GraceDays/text())[1]', 'varchar(100)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.ROW_ID = @sROW_ID;

        IF @@ROWCOUNT = 0
            RETURN;

        -- Recupera el centro del cliente o utiliza el valor operativo por defecto.
        SELECT @sCtro = MAX(ISNULL(M.CTRO, 'MX1A'))
        FROM [T3].[MOV_CLIENTE] AS M
        WHERE M.CLIENTE_V3 = @v_ID;

        IF NULLIF(@sCtro, '') IS NULL
            SET @sCtro = 'MX1A';

        IF @v_ID IS NULL
            SET @sProcesar = 'NO';

        IF @sProcesar = 'SI'
        BEGIN
            -- Oracle recibe importes expresados en centavos.
            SET @nCreditLimit = CONVERT(DECIMAL(22,4), ISNULL(NULLIF(@CreditLimitText, ''), '0')) / 100;
            SET @nAvailableLimit = CONVERT(DECIMAL(22,4), ISNULL(NULLIF(@AvailableText, ''), '0')) / 100;

            -- Equivalente T-SQL de la construccion XMLELEMENT de Oracle.
            ;WITH XMLNAMESPACES
            (
                'http://www.siebel.com/xml/BAT%20Customer%20Credit%20Inbound%20IO' AS xnsp1
            )
            SELECT @XmlSalida =
            (
                SELECT
                      '1' AS [@Operation]
                    , '' AS [xnsp1:Searchspec]
                    , '' AS [xnsp1:AvailableCredit]
                    , '' AS [xnsp1:BATAllowedPayments]
                    , '' AS [xnsp1:BATAmtDue]
                    , '' AS [xnsp1:BATCreditDays]
                    , @nCreditLimit AS [xnsp1:BATCreditLimit]
                    , '' AS [xnsp1:BATEMCustField30]
                    , '' AS [xnsp1:BATInvoiceType]
                    , '' AS [xnsp1:BATLicenseNumber]
                    , '' AS [xnsp1:BATMAXCreditDays]
                    , @nCreditLimit AS [xnsp1:BATMAXCreditLimit]
                    , '' AS [xnsp1:BATOverdueInvoiceFlag]
                    , '' AS [xnsp1:BadCreditFlag]
                    , ISNULL(@SAPCustomer, '') AS [xnsp1:CSN]
                    , '' AS [xnsp1:CreditDays]
                    , ISNULL(@SAPCustomer, '') AS [xnsp1:IntegrationId]
                    , ISNULL(@v_ID, '') AS [xnsp1:Location]
                    , '' AS [xnsp1:Name]
                    , '' AS [xnsp1:PaymentType]
                    , '' AS [xnsp1:RevenueClass]
                    , '' AS [xnsp1:TaxExemptNumber]
                    , ISNULL(@GraceDays, '') AS [xnsp1:BATGraceDays]
                FOR XML PATH('xnsp1:Account'), ROOT('xnsp1:ListOfBatCustomerCreditInboundIo'), TYPE
            );

            -- Registra el documento que sera consumido por el flujo de salida.
            INSERT INTO [EAI_OWNER].[MX_SEND_MESSAGE_LOG]
                (ROW_ID, CREATED, QUEUE_NAME, REFERENCE, CTRO, XML_CONTENT)
            VALUES
                (@sROW_ID, SYSDATETIME(), 'TaO Customer Credit Inbound', @v_ID,
                 @sCtro, CONVERT(VARCHAR(MAX), @XmlSalida));

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

        -- Cierra el mensaje de entrada y conserva el detalle tecnico del fallo.
        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
           SET PROCESSED = SYSDATETIME(), STATUS = 'Error'
         WHERE ROW_ID = @sROW_ID;

        -- ROW_ID se omite para permitir que actue el DEFAULT de la secuencia.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, ID, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', @v_ID, SYSDATETIME(), NULL, @nPID, 'Error',
             'PROC_CREDIT', @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);
    END CATCH;
END;
GO
