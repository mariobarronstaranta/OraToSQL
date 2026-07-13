CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CUSTOMER_O]
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
        SF_PROC_CUSTOMER_O
        ==================
        Procesa la variante "O" del mensaje XML de cliente.

        Reglas particulares de esta variante:
        - No ejecuta FN_VALIDA_RFC; solo valida una longitud minima de 10.
        - No sustituye el texto "-amp-". Esa normalizacion pertenece a otras
          variantes y no debe agregarse aqui sin cambiar la regla Oracle.
        - Al actualizar usa Name1 como Nombre y Name2 como Alias.
        - Al insertar usa Name1 + Name2 + Name3 como Nombre y Alias.
        - Solo una insercion nueva marca el mensaje como Processed. Una
          actualizacion deja el estado del mensaje sin cambios.

        @nROWNUM y @nPID forman parte de la interfaz, pero Oracle no los usa.
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
        -- XML.value(...)[1] es el equivalente de extractValue de Oracle.
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

        -- El FOR Oracle no hace nada cuando ROW_ID no existe.
        IF @nMessageRows = 0
            RETURN 0;

        /*
            Oracle convierte automaticamente '' en NULL. SQL Server requiere
            normalizarlo para no crear clientes con identificadores vacios.
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

        -- Cliente V3 es la llave preferida. SAP se usa como respaldo.
        SET @v_ID = COALESCE(@V3Customer, @SAPCustomer);
        SET @sProcesar = CASE WHEN @v_ID IS NULL THEN 'NO' ELSE 'SI' END;

        SET @sRFC =
            CASE
                WHEN LEN(COALESCE(@TaxID, 'NULO')) < 10
                    THEN 'XAXX010101000'
                ELSE @TaxID
            END;

        IF @sProcesar = 'SI'
        BEGIN
            -- Oracle limita sFullName a 100 caracteres.
            IF LEN(CONCAT(@Name1, @Name2, @Name3)) > 100
                THROW 51031, 'El nombre completo excede los 100 caracteres permitidos por el procedimiento Oracle.', 1;

            SET @sFullName = CONCAT(@Name1, @Name2, @Name3);

            BEGIN TRANSACTION;

                -- Paso 1: intentar actualizar por la llave efectiva v_ID.
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

                -- Paso 2: SQL%NOTFOUND de Oracle equivale a cero updates.
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
                        -- El INSERT Oracle usa V3Customer, no el fallback v_ID.
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
                        Esta actualizacion pertenece al bloque SQL%NOTFOUND en
                        Oracle. No moverla fuera: los updates no marcan el log.
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
