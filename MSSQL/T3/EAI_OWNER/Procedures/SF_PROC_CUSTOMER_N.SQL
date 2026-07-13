CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CUSTOMER_N]
(
    @sROW_ID VARCHAR(50),
    @nROWNUM NUMERIC(18,0),
    @nPID    NUMERIC(18,0) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        SF_PROC_CUSTOMER_N
        ==================
        Procesa la variante "N" del mensaje XML de clientes.

        Diferencias importantes respecto a SF_PROC_CUSTOMER:
        - No llama FN_VALIDA_RFC; solo valida la longitud minima del RFC.
        - En una actualizacion usa Name1 como Nombre y Name2 como Alias.
        - En una insercion usa Name1 + Name2 + Name3 como Nombre y Alias.
        - No procesa correo.
        - El Oracle marca el mensaje como Processed solamente al insertar un
          cliente nuevo. Si actualiza uno existente, deja el mensaje sin cambio.

        @nROWNUM y @nPID se conservan por compatibilidad con la firma Oracle,
        aunque el procedimiento original no los utiliza.
    */

    DECLARE
        @v_ID           VARCHAR(30),
        @sRFC           VARCHAR(40),
        @sErrorCode     VARCHAR(500),
        @sMsg           VARCHAR(500),
        @sProcesar      VARCHAR(2),
        @sFullName      VARCHAR(100),
        @nMessageRows   INT,
        @nUpdatedRows   INT,

        @SAPCustomer    VARCHAR(50),
        @V3Customer     VARCHAR(50),
        @MaxCreditDays  VARCHAR(50),
        @IntegrationID  VARCHAR(50),
        @Country        VARCHAR(50),
        @Region         VARCHAR(50),
        @Name1          VARCHAR(100),
        @Name2          VARCHAR(100),
        @Name3          VARCHAR(100),
        @Address        VARCHAR(200),
        @City           VARCHAR(100),
        @District       VARCHAR(100),
        @PostalCode     VARCHAR(20),
        @TaxID          VARCHAR(40);

    BEGIN TRY
        /*
            XML.value(...)[1] sustituye extractValue de Oracle. ROW_ID debe
            identificar logicamente un solo mensaje dentro del log.
        */
        SELECT
            @SAPCustomer = XML_Content.value
                ('(/Customer/Message/GeneralData/CustomerNumber/text())[1]', 'varchar(50)'),
            @V3Customer = XML_Content.value
                ('(/Customer/Message/GeneralData/V3CustomerNumber/text())[1]', 'varchar(50)'),
            @MaxCreditDays = XML_Content.value
                ('(/Customer/Message/GeneralData/PaymentTerms/text())[1]', 'varchar(50)'),
            @IntegrationID = XML_Content.value
                ('(/Customer/Message/GeneralData/IntegrationID/text())[1]', 'varchar(50)'),
            @Country = XML_Content.value
                ('(/Customer/Message/GeneralData/Country/text())[1]', 'varchar(50)'),
            @Region = XML_Content.value
                ('(/Customer/Message/GeneralData/Region/text())[1]', 'varchar(50)'),
            @Name1 = XML_Content.value
                ('(/Customer/Message/GeneralData/Name1/text())[1]', 'varchar(100)'),
            @Name2 = XML_Content.value
                ('(/Customer/Message/GeneralData/Name2/text())[1]', 'varchar(100)'),
            @Name3 = XML_Content.value
                ('(/Customer/Message/GeneralData/Name3/text())[1]', 'varchar(100)'),
            @Address = XML_Content.value
                ('(/Customer/Message/GeneralData/Address/text())[1]', 'varchar(200)'),
            @City = XML_Content.value
                ('(/Customer/Message/GeneralData/City/text())[1]', 'varchar(100)'),
            @District = XML_Content.value
                ('(/Customer/Message/GeneralData/District/text())[1]', 'varchar(100)'),
            @PostalCode = XML_Content.value
                ('(/Customer/Message/GeneralData/PostalCode/text())[1]', 'varchar(20)'),
            @TaxID = XML_Content.value
                ('(/Customer/Message/GeneralData/TaxID/text())[1]', 'varchar(40)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        WHERE [ROW_ID] = @sROW_ID;

        SET @nMessageRows = @@ROWCOUNT;

        -- El FOR Oracle no ejecuta ninguna regla si ROW_ID no existe.
        IF @nMessageRows = 0
            RETURN 0;

        /*
            Oracle considera '' igual a NULL. Esta normalizacion evita usar
            cadenas vacias como identificadores o datos de domicilio.
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
            @TaxID = NULLIF(@TaxID, '');

        -- Cliente V3 es la llave preferida; SAP funciona como respaldo.
        SET @v_ID = COALESCE(@V3Customer, @SAPCustomer);
        SET @sProcesar = CASE WHEN @v_ID IS NULL THEN 'NO' ELSE 'SI' END;

        -- Esta variante solo valida longitud. No agregar FN_VALIDA_RFC porque
        -- esa llamada no existe en SF_PROC_CUSTOMER_N de Oracle.
        SET @sRFC =
            CASE
                WHEN LEN(COALESCE(@TaxID, 'NULO')) < 10
                    THEN 'XAXX010101000'
                ELSE @TaxID
            END;

        -- Restaurar el ampersand que el sistema emisor codifica como -amp-.
        SELECT
            @Name1 = REPLACE(@Name1, '-amp-', '&'),
            @Name2 = REPLACE(@Name2, '-amp-', '&'),
            @Name3 = REPLACE(@Name3, '-amp-', '&'),
            @sRFC = REPLACE(@sRFC, '-amp-', '&'),
            @Address = REPLACE(@Address, '-amp-', '&'),
            @District = REPLACE(@District, '-amp-', '&'),
            @City = REPLACE(@City, '-amp-', '&');

        IF @sProcesar = 'SI'
        BEGIN
            /*
                Oracle concatena sin separadores. CONCAT conserva esa regla y
                trata cada componente NULL como cadena vacia.
            */
            IF LEN(CONCAT(@Name1, @Name2, @Name3)) > 100
                THROW 51030, 'El nombre completo excede los 100 caracteres permitidos por el procedimiento Oracle.', 1;

            SET @sFullName = CONCAT(@Name1, @Name2, @Name3);

            BEGIN TRANSACTION;

                -- Paso 1: actualizar un cliente existente por la llave efectiva.
                UPDATE [T3].[MOV_CLIENTE]
                   SET [Nombre] = @Name1,
                       [Alias] = @Name2,
                       [Cliente_SAP] = @SAPCustomer,
                       [RFC] = @sRFC,
                       [Direccion_1] = @Address,
                       [Colonia_1] = @District,
                       [Ciudad_1] = @City,
                       [Estado_1] = @Region,
                       [Pais_1] = @Country,
                       [Codigo_Postal_1] = @PostalCode,
                       [Fecha_Proc_BATMD] = NULL,
                       [Fecha_Syncr] = GETDATE()
                 WHERE [Cliente_V3] = @v_ID;

                SET @nUpdatedRows = @@ROWCOUNT;

                -- SQL%NOTFOUND de Oracle equivale a @@ROWCOUNT = 0.
                IF @nUpdatedRows = 0
                BEGIN
                    INSERT INTO [T3].[MOV_CLIENTE]
                    (
                        [Cliente_V3], [Nombre], [Clasif_Clte], [Tipo_Mov],
                        [Status_Clte], [Alias], [Cliente_SAP], [RFC],
                        [Fecha_Syncr], [Regimen_Fiscal], [Accion],
                        [Direccion_1], [Ciudad_1], [Colonia_1], [Estado_1],
                        [Pais_1], [Codigo_Postal_1], [Ctro], [Dist_Venta], [Area_Mgr]
                    )
                    VALUES
                    (
                        -- Oracle usa V3Customer, no la llave fallback v_ID.
                        @V3Customer, @sFullName, 'Cliente', 1,
                        1, @sFullName, @SAPCustomer, @sRFC,
                        GETDATE(), '0', 'I',
                        @Address, @City, @District, @Region,
                        @Country, @PostalCode,
                        [EAI_OWNER].[GETCONV]('CFG Settings', 'T3Default Ctro'),
                        [EAI_OWNER].[GETCONV]('CFG Settings', 'T3Default DistVenta'),
                        [EAI_OWNER].[GETCONV]('CFG Settings', 'T3Default AreaManager')
                    );

                    /*
                        Esta actualizacion esta dentro de SQL%NOTFOUND en Oracle:
                        solo los clientes insertados marcan el mensaje Processed.
                    */
                    UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                       SET [Processed] = GETDATE(),
                           [Status] = 'Processed',
                           [Reference] = @v_ID
                     WHERE [ROW_ID] = @sROW_ID;
                END;

            COMMIT TRANSACTION;
        END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
           SET [Processed] = GETDATE(),
               [Status] = 'Error'
         WHERE [ROW_ID] = @sROW_ID;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            [DIRECTION], [ID], [CREATED], [MESSAGE], [STATUS], [QUEUE_NAME],
            [SIEBEL_ERROR_MESSAGE], [SOURCE], [SIEBEL_ERROR_CODE],
            [RETRY_COUNT], [SEQUENCE], [PARENT_ROW_ID]
        )
        VALUES
        (
            'Receive', @v_ID, GETDATE(), NULL, 'Error',
            'TaO Customer Inbound', @sMsg, 'XML', @sErrorCode,
            NULL, NULL, NULL
        );

        THROW;
    END CATCH;
END;
GO
