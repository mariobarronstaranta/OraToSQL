CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CUSTOMER]
(
      @sROW_ID   VARCHAR(50)
    , @nROWNUM   NUMERIC(18,0)
    , @nPID      NUMERIC(18,0) = NULL
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        SF_PROC_CUSTOMER
        ================
        Lee un mensaje XML de cliente, normaliza sus datos y realiza un UPSERT
        manual sobre T3.MOV_CLIENTE:
        1. intenta actualizar por Cliente_V3;
        2. si no encuentra una fila, inserta un cliente nuevo;
        3. marca el mensaje como procesado; y
        4. delega el correo a SF_PROC_CUSTOMER_MAIL.

        @nROWNUM y @nPID se conservan porque forman parte de la interfaz Oracle,
        aunque el procedimiento original no los utiliza en su logica interna.
    */

    DECLARE
          @v_ID VARCHAR(30)
        , @sRFC VARCHAR(40)
        , @sErrorCode VARCHAR(500)
        , @sMsg VARCHAR(500)
        , @sProcesar VARCHAR(2)
        , @sFullName VARCHAR(100)
        , @nMessageRows INT

        , @SAPCustomer VARCHAR(50)
        , @V3Customer VARCHAR(50)
        , @MaxCreditDays VARCHAR(50)
        , @IntegrationID VARCHAR(50)
        , @Country VARCHAR(50)
        , @Region VARCHAR(50)
        , @Name1 VARCHAR(100)
        , @Name2 VARCHAR(100)
        , @Name3 VARCHAR(100)
        , @Address VARCHAR(200)
        , @City VARCHAR(100)
        , @District VARCHAR(100)
        , @PostalCode VARCHAR(20)
        , @TaxID VARCHAR(40)
        , @Mail VARCHAR(200);

    BEGIN TRY

        /*
            XML.value(...)[1] es el equivalente T-SQL de extractValue.
            [1] obliga a obtener un solo valor por elemento y evita que un XML
            con nodos repetidos produzca un resultado ambiguo.
        */
        SELECT
            @SAPCustomer =
                XML_Content.value('(/Customer/Message/GeneralData/CustomerNumber)[1]','varchar(50)'),

            @V3Customer =
                XML_Content.value('(/Customer/Message/GeneralData/V3CustomerNumber)[1]','varchar(50)'),

            -- Oracle extrae estos valores aunque no los usa posteriormente.
            -- Se mantienen para que el contrato de lectura XML sea equivalente.
            @MaxCreditDays =
                XML_Content.value('(/Customer/Message/GeneralData/PaymentTerms)[1]','varchar(50)'),

            @IntegrationID =
                XML_Content.value('(/Customer/Message/GeneralData/IntegrationID)[1]','varchar(50)'),

            @Country =
                XML_Content.value('(/Customer/Message/GeneralData/Country)[1]','varchar(50)'),

            @Region =
                XML_Content.value('(/Customer/Message/GeneralData/Region)[1]','varchar(50)'),

            @Name1 =
                XML_Content.value('(/Customer/Message/GeneralData/Name1)[1]','varchar(100)'),

            @Name2 =
                XML_Content.value('(/Customer/Message/GeneralData/Name2)[1]','varchar(100)'),

            @Name3 =
                XML_Content.value('(/Customer/Message/GeneralData/Name3)[1]','varchar(100)'),

            @Address =
                XML_Content.value('(/Customer/Message/GeneralData/Address)[1]','varchar(200)'),

            @City =
                XML_Content.value('(/Customer/Message/GeneralData/City)[1]','varchar(100)'),

            @District =
                XML_Content.value('(/Customer/Message/GeneralData/District)[1]','varchar(100)'),

            @PostalCode =
                XML_Content.value('(/Customer/Message/GeneralData/PostalCode)[1]','varchar(20)'),

            @TaxID =
                XML_Content.value('(/Customer/Message/GeneralData/TaxID)[1]','varchar(40)'),

            @Mail =
                XML_Content.value('(/Customer/Message/GeneralData/CustomerEmailAddress)[1]','varchar(200)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        WHERE ROW_ID = @sROW_ID;

        SET @nMessageRows = @@ROWCOUNT;

        -- El FOR Oracle no ejecuta su cuerpo cuando ROW_ID no existe.
        IF @nMessageRows = 0
            RETURN 0;

        /*
            ROW_ID funciona como identificador logico del mensaje y se espera
            una sola fila. La tabla actual no declara una restriccion UNIQUE;
            conviene agregarla durante el endurecimiento del modelo de datos.
        */

        /*
            Oracle trata la cadena vacia como NULL; SQL Server no. Normalizar
            aqui evita crear clientes con una llave vacia y conserva el mismo
            resultado para elementos XML presentes pero sin contenido.
        */
        SELECT
            @SAPCustomer = NULLIF(@SAPCustomer, ''),
            @V3Customer = NULLIF(@V3Customer, ''),
            @Country = NULLIF(@Country, ''),
            @Region = NULLIF(@Region, ''),
            @Name1 = NULLIF(@Name1, ''),
            @Name2 = NULLIF(@Name2, ''),
            @Name3 = NULLIF(@Name3, ''),
            @Address = NULLIF(@Address, ''),
            @City = NULLIF(@City, ''),
            @District = NULLIF(@District, ''),
            @PostalCode = NULLIF(@PostalCode, ''),
            @TaxID = NULLIF(@TaxID, ''),
            @Mail = NULLIF(@Mail, '');

        -- V3 es la llave preferida. SAP se usa solo cuando V3 viene nulo.
        SET @v_ID = COALESCE(@V3Customer, @SAPCustomer);

        SET @sProcesar =
            CASE
                WHEN @v_ID IS NULL THEN 'NO'
                ELSE 'SI'
            END;

        /*
            Un RFC ausente o menor de 10 caracteres se reemplaza por el RFC
            generico nacional definido en Oracle.
        */
        SET @sRFC =
            CASE
                WHEN LEN(ISNULL(@TaxID,'')) < 10
                    THEN 'XAXX010101000'
                ELSE @TaxID
            END;

        /*
            Dependencia requerida: [T3].[FN_VALIDA_RFC].
            El script de esta funcion aun no existe en el repositorio, pero la
            llamada conserva exactamente el schema usado por Oracle.
        */
        IF [T3].[FN_VALIDA_RFC](@sRFC) = -1
            SET @sRFC = 'XAXX010101000';

        -- El productor XML sustituye '&' por '-amp-'. Se restaura antes de
        -- guardar nombres, RFC y domicilio.
        SET @Name1 = REPLACE(@Name1,'-amp-','&');
        SET @Name2 = REPLACE(@Name2,'-amp-','&');
        SET @Name3 = REPLACE(@Name3,'-amp-','&');

        SET @Address = REPLACE(@Address,'-amp-','&');
        SET @District = REPLACE(@District,'-amp-','&');
        SET @City = REPLACE(@City,'-amp-','&');

        SET @sRFC = REPLACE(@sRFC,'-amp-','&');

        IF @sProcesar = 'SI'
        BEGIN

            SET @sFullName =
                CONCAT(
                    ISNULL(@Name1,''),
                    ISNULL(@Name2,''),
                    ISNULL(@Name3,'')
                );

            /*
                Una sola transaccion mantiene sincronizados MOV_CLIENTE, el
                estado del mensaje y el correo. Si una etapa falla, ninguna de
                las anteriores queda confirmada parcialmente.
            */
            BEGIN TRAN;

            -- Primero se intenta actualizar al cliente existente.
            UPDATE [T3].[MOV_CLIENTE]
            SET
                Nombre = @sFullName,
                Alias = @sFullName,
                Cliente_SAP = @SAPCustomer,
                RFC = @sRFC,

                Direccion_1 = @Address,
                Colonia_1 = @District,
                Ciudad_1 = @City,
                Estado_1 = @Region,
                Pais_1 = @Country,
                Codigo_Postal_1 = @PostalCode,

                Direccion_2 = @Address,
                Colonia_2 = @District,
                Ciudad_2 = @City,
                Estado_2 = @Region,
                Pais_2 = @Country,
                Codigo_Postal_2 = @PostalCode,

                Direccion_3 = @Address,
                Colonia_3 = @District,
                Ciudad_3 = @City,
                Estado_3 = @Region,
                Pais_3 = @Country,
                Codigo_Postal_3 = @PostalCode,

                Fecha_Proc_BATMD = NULL,
                Fecha_Syncr = GETDATE()
            WHERE Cliente_V3 = @v_ID;

            -- @@ROWCOUNT = 0 equivale a SQL%NOTFOUND de Oracle.
            IF @@ROWCOUNT = 0
            BEGIN

                INSERT INTO [T3].[MOV_CLIENTE]
                (
                    Cliente_V3,
                    Nombre,
                    Clasif_Clte,
                    Tipo_Mov,
                    Status_Clte,
                    Alias,
                    Cliente_SAP,
                    RFC,
                    Fecha_Syncr,
                    Regimen_Fiscal,
                    Accion,

                    Direccion_1,
                    Ciudad_1,
                    Colonia_1,
                    Estado_1,
                    Pais_1,
                    Codigo_Postal_1,

                    Direccion_3,
                    Ciudad_3,
                    Colonia_3,
                    Estado_3,
                    Pais_3,
                    Codigo_Postal_3,

                    Ctro,
                    Dist_Venta,
                    Area_Mgr
                )
                VALUES
                (
                    @V3Customer,
                    @sFullName,
                    'Cliente',
                    1,
                    1,
                    @sFullName,
                    @SAPCustomer,
                    @sRFC,
                    GETDATE(),
                    '0',
                    'I',

                    @Address,
                    @City,
                    @District,
                    @Region,
                    @Country,
                    @PostalCode,

                    @Address,
                    @City,
                    @District,
                    @Region,
                    @Country,
                    @PostalCode,

                    [EAI_OWNER].[GETCONV]('CFG Settings','T3Default Ctro'),
                    [EAI_OWNER].[GETCONV]('CFG Settings','T3Default DistVenta'),
                    [EAI_OWNER].[GETCONV]('CFG Settings','T3Default AreaManager')
                );
            END

            UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
            SET
                Processed = GETDATE(),
                Status = 'Processed',
                Reference = @v_ID
            WHERE ROW_ID = @sROW_ID;

            /*
                El archivo convertido de esta dependencia esta declarado hoy
                en dbo. Debe cambiarse aqui a EAI_OWNER cuando ese procedimiento
                sea migrado a su schema definitivo.
            */
            EXEC [EAI_OWNER].[SF_PROC_CUSTOMER_MAIL]
                @sCliente_SAP = @SAPCustomer,
                @sMail = @Mail;

            COMMIT;
        END

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        SET
            Processed = GETDATE(),
            Status = 'Error'
        WHERE ROW_ID = @sROW_ID;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            ID,
            CREATED,
            MESSAGE,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Receive',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'TaO Customer Inbound',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO
