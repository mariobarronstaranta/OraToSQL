CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_INTER]
(
    @sRow_ID  VARCHAR(50),
    @nRowNum  INT = 1,
    @nOutput  INT = 0,
    @nPID     INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        SF_PROC_PREINVOICE_INTER
        ========================
        Convierte un XML de factura intercompany en tablas temporales
        relacionales para que los procedimientos de routing posteriores puedan
        generar la factura definitiva.

        Flujo general para un developer Jr:
        1. Leer encabezado y validar DocumentNumber.
        2. Borrar cualquier conversion previa de la misma referencia.
        3. Extraer partners, referencias, organizaciones, importes y textos.
        4. Recorrer cada ItemData y guardar detalle, impuestos y leyendas.
        5. Insertar encabezado y partners.
        6. Actualizar el log de recepcion.
        7. Enviar el documento a PREVENTA u OTROS segun tipo y compania.

        @nRowNum se conserva porque pertenece a la firma Oracle, aunque el
        procedimiento original no lo utiliza en sus reglas internas.
    */

    DECLARE
        @sMsg                VARCHAR(500),
        @v_ID                VARCHAR(30),
        @sErrorCode          VARCHAR(20),
        @sReferenceID        VARCHAR(30),
        @sProcesar           VARCHAR(20),
        @sFacturaSAP         VARCHAR(30),
        @sEntregaSAP         VARCHAR(30),
        @sCurrency           VARCHAR(30),
        @sCurrencyDoc        VARCHAR(30),
        @sCurrencyLocal      VARCHAR(30),
        @sRFC                VARCHAR(30),
        @sNIF                VARCHAR(30),
        @sRate               VARCHAR(50),
        @sPaymentTerms       VARCHAR(50),
        @sAssignment         VARCHAR(50),
        @sClienteSAP         VARCHAR(50),
        @sCteEntregaSAP      VARCHAR(50),
        @sCteFacturaSAP      VARCHAR(50),
        @sFacturaV3          VARCHAR(50),
        @sFechaFactura       VARCHAR(50),
        @sFechaVencimiento   VARCHAR(10),
        @sHoraFactura        VARCHAR(50),
        @sPedidoSAP          VARCHAR(50),
        @sPedidoV3           VARCHAR(50),
        @sCountry            VARCHAR(80),
        @sPartnerName        VARCHAR(80),
        @sCity               VARCHAR(80),
        @sDistrict           VARCHAR(80),
        @sPostalCode         VARCHAR(80),
        @sRegion             VARCHAR(80),
        @sAddress            VARCHAR(80),

        @sSold_Customer      VARCHAR(10),
        @sSold_Name          VARCHAR(80),
        @sSold_Address       VARCHAR(80),
        @sSold_District      VARCHAR(80),
        @sSold_City          VARCHAR(80),
        @sSold_State         VARCHAR(80),
        @sSold_Country       VARCHAR(80),
        @sSold_ZipCode       VARCHAR(80),
        @sBill_Customer      VARCHAR(10),
        @sBill_Name          VARCHAR(80),
        @sBill_Address       VARCHAR(80),
        @sBill_District      VARCHAR(80),
        @sBill_City          VARCHAR(80),
        @sBill_State         VARCHAR(80),
        @sBill_Country       VARCHAR(80),
        @sBill_ZipCode       VARCHAR(80),
        @sShip_Customer      VARCHAR(10),
        @sShip_Name          VARCHAR(80),
        @sShip_Address       VARCHAR(80),
        @sShip_District      VARCHAR(80),
        @sShip_City          VARCHAR(80),
        @sShip_State         VARCHAR(80),
        @sShip_Country       VARCHAR(80),
        @sShip_ZipCode       VARCHAR(80),

        @sNumLinea           VARCHAR(50),
        @sOrgVentas          VARCHAR(50),
        @sClaseFactura       VARCHAR(50),
        @sCompanyCode        VARCHAR(50),
        @sValor_Subt         VARCHAR(50),
        @sValor_IVA          VARCHAR(50),
        @sCantidadVta        VARCHAR(50),
        @sUnidadMedVta       VARCHAR(50),
        @sStatusItem         VARCHAR(50),
        @sCentro             VARCHAR(50),
        @sMaterial           VARCHAR(50),
        @sMatDescription     VARCHAR(50),
        @sPrecioUnitario     VARCHAR(50),
        @sDetValor_Subt      VARCHAR(50),
        @sDetValor_IVA       VARCHAR(50),
        @sDetBonif_Subt      VARCHAR(50),
        @sCondZFSIValue      VARCHAR(50),
        @sCondZFSISign       VARCHAR(50),
        @sPaymentMethod      VARCHAR(200),
        @sBankReference      VARCHAR(200),
        @sComments           VARCHAR(500),
        @sIncoterms          VARCHAR(200),
        @sQualifier          VARCHAR(80),
        @sLanguage           VARCHAR(80),
        @sTextLine           VARCHAR(4000),
        @sItemText_ES        VARCHAR(4000),
        @sItemText_EN        VARCHAR(300),
        @nItems              INT,
        @nTaxFactor          INT,
        @sTipoDocV3          VARCHAR(4),
        @sFolioFiscalDoc     VARCHAR(30),
        @sStateAux           VARCHAR(40),
        @sStateName          VARCHAR(40),
        @sSalesDoc_Type      VARCHAR(30),
        @sCustomerRep        VARCHAR(30),
        @XML_Content         XML,
        @ItemXML             XML,
        @ItemTextos          XML;

    BEGIN TRY

        SET @sTipoDocV3     = 'NO';
        SET @sPaymentMethod = '';
        SET @sBankReference = '';
        SET @sComments      = '';
        SET @sIncoterms     = '';
        SET @sAssignment    = '';
        SET @sProcesar      = 'NO';

        /*
            XML_CONTENT ya esta declarado como tipo XML en el modelo SQL
            Server. No requiere SQL_VARIANT_PROPERTY ni TRY_CAST.
        */
        SELECT @XML_Content = [XML_CONTENT]
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        WHERE Row_ID = @sRow_ID;

        IF @XML_Content IS NULL
        BEGIN
            SET @sProcesar = 'NO';
        END
        ELSE
        BEGIN
            SELECT
                @sReferenceID  = @XML_Content.value('(/InvoiceIntercompany/Message/InvoiceHeader/DocumentNumber/text())[1]', 'varchar(30)'),
                @sCurrency     = @XML_Content.value('(/InvoiceIntercompany/Message/InvoiceHeader/Currency/text())[1]',       'varchar(30)'),
                @sRFC          = @XML_Content.value('(/InvoiceIntercompany/Message/InvoiceHeader/RFC/text())[1]',            'varchar(30)'),
                @sRate         = @XML_Content.value('(/InvoiceIntercompany/Message/InvoiceHeader/Rate/text())[1]',           'varchar(50)'),
                @sPaymentTerms = @XML_Content.value('(/InvoiceIntercompany/Message/InvoiceHeader/PaymentTerms/text())[1]',   'varchar(50)');

            SET @v_ID        = @sReferenceID;
            SET @sFacturaSAP = @sReferenceID;
            SET @sProcesar   = CASE WHEN @v_ID IS NULL OR LTRIM(RTRIM(@v_ID)) = '' THEN 'NO' ELSE 'SI' END;
        END;

        IF @sProcesar = 'SI'
        BEGIN
            -- CURRENCY_TEXT genera la descripcion documental y local. Oracle
            -- conserva ambas, aunque solo la documental se guarda al final.
            SET @sCurrencyDoc   = [EAI_OWNER].[CURRENCY_TEXT](@sCurrency, 'Doc');
            SET @sCurrencyLocal = [EAI_OWNER].[CURRENCY_TEXT](@sCurrency, 'Local');
            SET @sCurrency      = @sCurrencyDoc;

            -- La conversion es reejecutable: primero elimina la version previa
            -- de esta misma referencia en las cinco tablas temporales.
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER]      WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL]      WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]  WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_PARTNERS]    WHERE ReferenceID = @sReferenceID;
            DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL_COND] WHERE ReferenceID = @sReferenceID;

            --------------------------------------------------------------------
            -- Partners
            --------------------------------------------------------------------
            ;WITH Partners AS
            (
                SELECT
                    P.N.value('(Function/text())[1]',   'varchar(50)') AS FunctionID,
                    P.N.value('(PartnerID/text())[1]',  'varchar(50)') AS PartnerID,
                    P.N.value('(Country/text())[1]',    'varchar(80)') AS Country,
                    P.N.value('(Name/text())[1]',       'varchar(80)') AS PartnerName,
                    P.N.value('(City/text())[1]',       'varchar(80)') AS City,
                    P.N.value('(District/text())[1]',   'varchar(80)') AS District,
                    P.N.value('(PostalCode/text())[1]', 'varchar(80)') AS PostalCode,
                    P.N.value('(Region/text())[1]',     'varchar(80)') AS Region,
                    P.N.value('(Address/text())[1]',    'varchar(80)') AS Address
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/InvoicePartner') AS P(N)
            )
            SELECT
                @sClienteSAP = MAX(CASE WHEN FunctionID = 'AG' THEN PartnerID END),
                @sSold_Customer = MAX(CASE WHEN FunctionID = 'AG' THEN PartnerID END),
                @sSold_Name     = MAX(CASE WHEN FunctionID = 'AG' THEN PartnerName END),
                @sSold_Address  = MAX(CASE WHEN FunctionID = 'AG' THEN Address END),
                @sSold_District = MAX(CASE WHEN FunctionID = 'AG' THEN District END),
                @sSold_City     = MAX(CASE WHEN FunctionID = 'AG' THEN City END),
                @sSold_State    = MAX(CASE WHEN FunctionID = 'AG' THEN Region END),
                @sSold_Country  = MAX(CASE WHEN FunctionID = 'AG' THEN Country END),
                @sSold_ZipCode  = MAX(CASE WHEN FunctionID = 'AG' THEN PostalCode END),

                @sCteFacturaSAP = MAX(CASE WHEN FunctionID = 'RE' THEN PartnerID END),
                @sCountry       = MAX(CASE WHEN FunctionID = 'RE' THEN Country END),
                @sPartnerName   = MAX(CASE WHEN FunctionID = 'RE' THEN PartnerName END),
                @sCity          = MAX(CASE WHEN FunctionID = 'RE' THEN City END),
                @sDistrict      = MAX(CASE WHEN FunctionID = 'RE' THEN District END),
                @sPostalCode    = MAX(CASE WHEN FunctionID = 'RE' THEN PostalCode END),
                @sRegion        = MAX(CASE WHEN FunctionID = 'RE' THEN Region END),
                @sAddress       = MAX(CASE WHEN FunctionID = 'RE' THEN Address END),
                @sBill_Customer = MAX(CASE WHEN FunctionID = 'RE' THEN PartnerID END),
                @sBill_Name     = MAX(CASE WHEN FunctionID = 'RE' THEN PartnerName END),
                @sBill_Address  = MAX(CASE WHEN FunctionID = 'RE' THEN Address END),
                @sBill_District = MAX(CASE WHEN FunctionID = 'RE' THEN District END),
                @sBill_City     = MAX(CASE WHEN FunctionID = 'RE' THEN City END),
                @sBill_State    = MAX(CASE WHEN FunctionID = 'RE' THEN Region END),
                @sBill_Country  = MAX(CASE WHEN FunctionID = 'RE' THEN Country END),
                @sBill_ZipCode  = MAX(CASE WHEN FunctionID = 'RE' THEN PostalCode END),

                @sCteEntregaSAP = MAX(CASE WHEN FunctionID = 'WE' THEN PartnerID END),
                @sShip_Customer = MAX(CASE WHEN FunctionID = 'WE' THEN PartnerID END),
                @sShip_Name     = MAX(CASE WHEN FunctionID = 'WE' THEN PartnerName END),
                @sShip_Address  = MAX(CASE WHEN FunctionID = 'WE' THEN Address END),
                @sShip_District = MAX(CASE WHEN FunctionID = 'WE' THEN District END),
                @sShip_City     = MAX(CASE WHEN FunctionID = 'WE' THEN City END),
                @sShip_State    = MAX(CASE WHEN FunctionID = 'WE' THEN Region END),
                @sShip_Country  = MAX(CASE WHEN FunctionID = 'WE' THEN Country END),
                @sShip_ZipCode  = MAX(CASE WHEN FunctionID = 'WE' THEN PostalCode END)
            FROM Partners;

            --------------------------------------------------------------------
            -- ReferenceData
            --------------------------------------------------------------------
            ;WITH ReferenceData AS
            (
                SELECT
                    R.N.value('(Qualifier/text())[1]', 'varchar(50)') AS RefQualifier,
                    R.N.value('(Document/text())[1]',  'varchar(50)') AS RefDocument,
                    R.N.value('(Date/text())[1]',      'varchar(50)') AS RefDate,
                    R.N.value('(Time/text())[1]',      'varchar(50)') AS RefTime
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/ReferenceData') AS R(N)
            )
            SELECT
                @sPedidoV3         = MAX(CASE WHEN RefQualifier = '001' THEN RefDocument END),
                @sPedidoSAP        = MAX(CASE WHEN RefQualifier = '002' THEN RefDocument END),
                @sFechaFactura     = MAX(CASE WHEN RefQualifier = '009' THEN RefDate END),
                @sHoraFactura      = MAX(CASE WHEN RefQualifier = '009' THEN RefTime END),
                @sFechaVencimiento = MAX(CASE WHEN RefQualifier = '028' THEN RefDate END),
                @sFacturaV3        = MAX(CASE WHEN RefQualifier = '017' THEN RefDocument END),
                @sEntregaSAP       = MAX(CASE WHEN RefQualifier = '012' THEN RefDocument END)
            FROM ReferenceData;

            --------------------------------------------------------------------
            -- HeaderDate
            -- Se conserva la ruta Oracle: /Invoice/Message/HeaderDate
            --------------------------------------------------------------------
            ;WITH HeaderDate AS
            (
                SELECT
                    H.N.value('(Qualifier/text())[1]', 'varchar(50)') AS RefQualifier,
                    H.N.value('(Date/text())[1]',      'varchar(50)') AS RefValue
                FROM @XML_Content.nodes('/Invoice/Message/HeaderDate') AS H(N)
            )
            SELECT
                @sFechaVencimiento = COALESCE(MAX(CASE WHEN RefQualifier = '028' THEN RefValue END), @sFechaVencimiento)
            FROM HeaderDate;

            --------------------------------------------------------------------
            -- OrganizationData
            --------------------------------------------------------------------
            /*
                Oracle recorre OrganizationData en orden. No se usa MAX porque
                cambiaria la regla cuando un calificador aparece varias veces.
            */
            DECLARE OrganizationCur CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    O.N.value('(Qualifier/text())[1]', 'varchar(50)'),
                    O.N.value('(Organization/text())[1]', 'varchar(50)')
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/OrganizationData') AS O(N);

            OPEN OrganizationCur;
            FETCH NEXT FROM OrganizationCur INTO @sQualifier, @sTextLine;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @sQualifier = '008'
                    SET @sOrgVentas = @sTextLine;
                ELSE IF @sQualifier = '003'
                BEGIN
                    SET @sCompanyCode = @sTextLine;
                    SET @sOrgVentas = @sTextLine;
                END
                ELSE IF @sQualifier = '017'
                    SET @sAssignment = @sTextLine;
                ELSE IF @sQualifier = '015'
                BEGIN
                    SET @sClaseFactura =
                        CASE @sTextLine
                            WHEN 'Nota de Venta' THEN 'C005'
                            WHEN 'Payable'       THEN 'C006'
                            WHEN 'IV'            THEN 'IV'
                            WHEN 'ZI01'          THEN 'ZI01'
                            WHEN 'ZI03'          THEN 'ZI03'
                            WHEN 'ZI06'          THEN 'ZI06'
                            WHEN 'ZI02'          THEN 'ZI02'
                            WHEN 'ZI04'          THEN 'ZI04'
                            WHEN 'ZF2'           THEN 'ZF2'
                            WHEN 'ZL'            THEN 'ZL'
                            WHEN 'IVS'           THEN 'IVS'
                            WHEN 'ZIG2'          THEN 'C021'
                            WHEN 'ZG'            THEN
                                CASE WHEN @sCteFacturaSAP <> 'IC-00-MX16' THEN 'ZG' ELSE 'C022' END
                            ELSE @sClaseFactura
                        END;
                END;

                FETCH NEXT FROM OrganizationCur INTO @sQualifier, @sTextLine;
            END;

            CLOSE OrganizationCur;
            DEALLOCATE OrganizationCur;

            --------------------------------------------------------------------
            -- SummaryGeneral
            --------------------------------------------------------------------
            ;WITH SummaryGeneral AS
            (
                SELECT
                    S.N.value('(Qualifier/text())[1]',    'varchar(50)') AS RefQualifier,
                    S.N.value('(ValueSummary/text())[1]', 'varchar(50)') AS RefValue
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/SummaryGeneral') AS S(N)
            )
            SELECT
                @sValor_IVA  = MAX(CASE WHEN RefQualifier = '005' THEN RefValue END),
                @sValor_Subt = MAX(CASE WHEN RefQualifier = '010' THEN RefValue END)
            FROM SummaryGeneral;

            --------------------------------------------------------------------
            -- HeaderConditions
            --------------------------------------------------------------------
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_CONDITIONS
            (
                ReferenceID, ItemID, Condition, TotalCondition,
                TotalAmount, Currency, ConditionText, UnitPrice,
                ConditionID, UnitMeasure, Quantity
            )
            SELECT
                @sReferenceID,
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ItemID,
                C.N.value('(Indicator/text())[1]',     'varchar(50)'),
                C.N.value('(Total/text())[1]',         'varchar(50)'),
                C.N.value('(Amount/text())[1]',        'varchar(50)'),
                C.N.value('(Currency/text())[1]',      'varchar(50)'),
                C.N.value('(ConditionText/text())[1]', 'varchar(200)'),
                C.N.value('(UnitPrice/text())[1]',     'varchar(50)'),
                C.N.value('(ConditionID/text())[1]',   'varchar(50)'),
                C.N.value('(UOM/text())[1]',           'varchar(50)'),
                C.N.value('(Quantity/text())[1]',      'varchar(50)')
            FROM @XML_Content.nodes('/InvoiceIntercompany/Message/HeaderConditions') AS C(N);

            --------------------------------------------------------------------
            -- Header Texts
            --------------------------------------------------------------------
            DECLARE HeaderTextCur CURSOR LOCAL FAST_FORWARD FOR
                SELECT T.N.query('.')
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/TextIdentification') AS T(N);

            OPEN HeaderTextCur;
            FETCH NEXT FROM HeaderTextCur INTO @ItemTextos;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT
                    @sQualifier = @ItemTextos.value('(/TextIdentification/TextID/text())[1]',   'varchar(80)'),
                    @sLanguage  = @ItemTextos.value('(/TextIdentification/Language/text())[1]', 'varchar(80)');

                IF @sLanguage = 'ES'
                BEGIN
                    SELECT @sPaymentMethod =
                        CASE WHEN @sQualifier = 'Z048'
                             THEN LEFT(CONCAT(@sPaymentMethod, X.N.value('(TextLine/text())[1]', 'varchar(4000)')), 80)
                             ELSE @sPaymentMethod END
                    FROM @ItemTextos.nodes('/TextIdentification/TextHeader') AS X(N);

                    SELECT @sBankReference =
                        CASE WHEN @sQualifier = 'Z024'
                             THEN LEFT(CONCAT(@sBankReference, X.N.value('(TextLine/text())[1]', 'varchar(4000)')), 80)
                             ELSE @sBankReference END
                    FROM @ItemTextos.nodes('/TextIdentification/TextHeader') AS X(N);

                    SELECT @sComments =
                        CASE WHEN @sQualifier = 'Z021'
                             THEN LEFT(CONCAT(@sComments, X.N.value('(TextLine/text())[1]', 'varchar(4000)')), 495)
                             ELSE @sComments END
                    FROM @ItemTextos.nodes('/TextIdentification/TextHeader') AS X(N);

                    SELECT @sIncoterms =
                        CASE
                            WHEN @sQualifier = 'INCO1'
                                THEN CONCAT(@sIncoterms, X.N.value('(TextLine/text())[1]', 'varchar(4000)'))
                            WHEN @sQualifier = 'INCO2'
                                THEN CONCAT(@sIncoterms, ' ', X.N.value('(TextLine/text())[1]', 'varchar(4000)'))
                            ELSE @sIncoterms
                        END
                    FROM @ItemTextos.nodes('/TextIdentification/TextHeader') AS X(N);
                END;

                FETCH NEXT FROM HeaderTextCur INTO @ItemTextos;
            END;

            CLOSE HeaderTextCur;
            DEALLOCATE HeaderTextCur;

            --------------------------------------------------------------------
            -- Workarounds de negocio
            --------------------------------------------------------------------
            IF @sClaseFactura = 'IV' AND SUBSTRING(COALESCE(@sClienteSAP, ''), 1, 8) = 'PC-00-MX'
                SET @sClaseFactura = 'C020';

            SET @sNIF = @sRFC;

            IF COALESCE(@sCountry, '') <> 'MX'
                SET @sRFC = 'XEXX010101000';

            SET @sStateAux  = CONCAT(@sCountry, '-', @sRegion);
            SET @sCountry   = EAI_OWNER.GETCONV('ECC_T3 Country', @sCountry);
            SET @sStateName = EAI_OWNER.GETCONV('ECC_T3 State', @sStateAux);

            IF @sStateAux <> @sStateName
                SET @sRegion = @sStateName;

            IF @nOutput > 0
            BEGIN
                PRINT 'Document Header';
                PRINT CONCAT('ReferenceID     => ', @sReferenceID);
                PRINT CONCAT('FacturaSAP      => ', @sFacturaSAP);
                PRINT CONCAT('EntregaSAP      => ', @sEntregaSAP);
                PRINT CONCAT('Currency        => ', @sCurrency);
                PRINT CONCAT('RFC             => ', @sRFC);
                PRINT CONCAT('NIF             => ', @sNIF);
                PRINT CONCAT('Rate            => ', @sRate);
                PRINT CONCAT('PaymentTerms    => ', @sPaymentTerms);
                PRINT CONCAT('ClienteSAP      => ', @sClienteSAP);
                PRINT CONCAT('CteFacturaSAP   => ', @sCteFacturaSAP);
                PRINT CONCAT('CteEntregaSAP   => ', @sCteEntregaSAP);
                PRINT CONCAT('ClaseFactura    => ', @sClaseFactura);
                PRINT CONCAT('CompanyCode     => ', @sCompanyCode);
            END;

            --------------------------------------------------------------------
            -- ItemData
            --------------------------------------------------------------------
            DECLARE ItemCur CURSOR LOCAL FAST_FORWARD FOR
                SELECT I.N.query('.')
                FROM @XML_Content.nodes('/InvoiceIntercompany/Message/ItemData') AS I(N);

            OPEN ItemCur;
            FETCH NEXT FROM ItemCur INTO @ItemXML;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sDetValor_Subt  = '';
                SET @sPrecioUnitario = '';
                SET @sDetBonif_Subt  = '';
                SET @sDetValor_IVA   = '';
                SET @sMaterial       = NULL;
                SET @sMatDescription = NULL;
                SET @sCondZFSISign   = NULL;
                SET @sCondZFSIValue  = NULL;
                SET @sItemText_ES    = '';
                SET @sItemText_EN    = '';

                SELECT
                    @sNumLinea     = @ItemXML.value('(/ItemData/ItemNumber/text())[1]',    'varchar(50)'),
                    @sCantidadVta  = @ItemXML.value('(/ItemData/Quantity/text())[1]',      'varchar(50)'),
                    @sUnidadMedVta = @ItemXML.value('(/ItemData/UnitOfMeasure/text())[1]', 'varchar(50)'),
                    @sCentro       = @ItemXML.value('(/ItemData/Plant/text())[1]',         'varchar(50)');

                SET @sUnidadMedVta = EAI_OWNER.GETCONV('ECC_V3 UOM', @sUnidadMedVta);

                IF @sUnidadMedVta = 'CASES' AND @sCteFacturaSAP = 'IC-00-MX16'
                    SET @sUnidadMedVta = 'CTN';

                SELECT TOP (1)
                    @sMaterial       = X.N.value('(MaterialID/text())[1]',  'varchar(50)'),
                    @sMatDescription = X.N.value('(ShortText/text())[1]',   'varchar(50)')
                FROM @ItemXML.nodes('/ItemData/ItemID') AS X(N)
                WHERE X.N.value('(ObjectIdentification/text())[1]', 'varchar(50)') = '002';

                SELECT
                    @sDetValor_Subt =
                        COALESCE(MAX(CASE WHEN X.N.value('(Qualifier/text())[1]', 'varchar(50)') = '003'
                                          THEN X.N.value('(ValueAmount/text())[1]', 'varchar(50)') END), @sDetValor_Subt),
                    @sPrecioUnitario =
                        COALESCE(MAX(CASE WHEN X.N.value('(Qualifier/text())[1]', 'varchar(50)') = '003'
                                          THEN X.N.value('(PriceItem/text())[1]', 'varchar(50)') END), @sPrecioUnitario),
                    @sDetBonif_Subt =
                        COALESCE(MAX(CASE WHEN X.N.value('(Qualifier/text())[1]', 'varchar(50)') = '007'
                                          THEN X.N.value('(ValueAmount/text())[1]', 'varchar(50)') END), @sDetBonif_Subt)
                FROM @ItemXML.nodes('/ItemData/ItemTerms') AS X(N);

                SELECT TOP (1)
                    @sCondZFSISign  = X.N.value('(TermConditionIndicator/text())[1]', 'varchar(50)'),
                    @sCondZFSIValue = X.N.value('(TermConditionValue/text())[1]',     'varchar(50)')
                FROM @ItemXML.nodes('/ItemData/ItemTermsCondition') AS X(N)
                WHERE X.N.value('(TermConditionType/text())[1]', 'varchar(50)') = 'ZFSI';

                INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_DETAIL_COND]
                (
                    ReferenceID,
                    ItemID,
                    Condition,
                    Amount
                )
                SELECT
                    @sReferenceID,
                    @sNumLinea,
                    T.N.value('(TaxConditionType/text())[1]', 'varchar(50)'),
                    /*
                        Oracle falla si TaxConditionValue no es numerico. Usar
                        CONVERT mantiene esa validacion; TRY_CONVERT ocultaria
                        el problema insertando NULL.
                    */
                    CONVERT(DECIMAL(18, 6), T.N.value('(TaxConditionValue/text())[1]', 'varchar(50)')) *
                    CASE WHEN T.N.value('(TaxConditionIndicator/text())[1]', 'varchar(50)') = '-' THEN -1 ELSE 1 END
                FROM @ItemXML.nodes('/ItemData/ItemTaxTerms') AS T(N)
                WHERE LEN(COALESCE(T.N.value('(TaxConditionType/text())[1]', 'varchar(50)'), '')) > 1;

                SELECT TOP (1)
                    @sDetValor_IVA = X.N.value('(ValueTax/text())[1]', 'varchar(50)')
                FROM @ItemXML.nodes('/ItemData/ItemTaxes') AS X(N);

                DECLARE ItemTextCur CURSOR LOCAL FAST_FORWARD FOR
                    SELECT IT.N.query('.')
                    FROM @ItemXML.nodes('/ItemData/ItemTextHeader') AS IT(N);

                OPEN ItemTextCur;
                FETCH NEXT FROM ItemTextCur INTO @ItemTextos;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SELECT
                        @sQualifier = @ItemTextos.value('(/ItemTextHeader/TextID/text())[1]',   'varchar(80)'),
                        @sLanguage  = @ItemTextos.value('(/ItemTextHeader/Language/text())[1]', 'varchar(80)');

                    DECLARE TextLineCur CURSOR LOCAL FAST_FORWARD FOR
                        SELECT L.N.value('(TagColumn/text())[1]', 'varchar(4000)')
                        FROM @ItemTextos.nodes('/ItemTextHeader/ItemTextDetail') AS L(N);

                    OPEN TextLineCur;
                    FETCH NEXT FROM TextLineCur INTO @sTextLine;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        IF @sLanguage = 'ES'
                            SET @sItemText_ES = CONCAT(@sItemText_ES, COALESCE(@sTextLine, ''));
                        ELSE IF @sLanguage = 'EN'
                            SET @sItemText_EN = LEFT(CONCAT(@sItemText_EN, COALESCE(@sTextLine, '')), 300);

                        FETCH NEXT FROM TextLineCur INTO @sTextLine;
                    END;

                    CLOSE TextLineCur;
                    DEALLOCATE TextLineCur;

                    FETCH NEXT FROM ItemTextCur INTO @ItemTextos;
                END;

                CLOSE ItemTextCur;
                DEALLOCATE ItemTextCur;

                IF @nOutput > 0
                BEGIN
                    PRINT CONCAT('Item               = ', @sNumLinea);
                    PRINT CONCAT('Cantidad           = ', @sCantidadVta);
                    PRINT CONCAT('Unidad Vta         = ', @sUnidadMedVta);
                    PRINT CONCAT('Centro             = ', @sCentro);
                    PRINT CONCAT('Material           = ', @sMaterial);
                    PRINT CONCAT('Descripcion        = ', @sMatDescription);
                    PRINT CONCAT('Valor Subt         = ', @sDetValor_Subt);
                    PRINT CONCAT('Valor IVA          = ', @sDetValor_IVA);
                    PRINT CONCAT('Bonif Subt         = ', @sDetBonif_Subt);
                    PRINT CONCAT('Precio Unitario    = ', @sPrecioUnitario);
                    PRINT CONCAT('Leyendas ES/EN     = ', @sItemText_ES, '/', @sItemText_EN);
                    PRINT '-----------------------------------------';
                END;

                INSERT INTO EAI_OWNER.TMP_DOCUMENT_DETAIL
                (
                    ReferenceID,
                    ItemID,
                    Material,
                    Plant,
                    Cantidad,
                    UnidadMedida,
                    Valor_Subt,
                    Valor_IVA,
                    Bonif_Subt,
                    Status_Producto,
                    MaterialDescripcion,
                    PrecioUnitario,
                    Leyenda_EN,
                    Leyenda_ES
                )
                VALUES
                (
                    @sReferenceID,
                    @sNumLinea,
                    @sMaterial,
                    @sCentro,
                    @sCantidadVta,
                    @sUnidadMedVta,
                    @sDetValor_Subt,
                    @sDetValor_IVA,
                    @sDetBonif_Subt,
                    @sStatusItem,
                    @sMatDescription,
                    @sPrecioUnitario,
                    @sItemText_EN,
                    @sItemText_ES
                );

                FETCH NEXT FROM ItemCur INTO @ItemXML;
            END;

            CLOSE ItemCur;
            DEALLOCATE ItemCur;

            IF LEN(COALESCE(@sPedidoV3, '')) > 30
                SET @sPedidoV3 = LEFT(@sPedidoV3, 30);

            --------------------------------------------------------------------
            -- Header
            --------------------------------------------------------------------
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_HEADER
            (
                ReferenceID,
                Cust_to_SAP,
                Bill_to_SAP,
                Ship_to_SAP,
                ShippingPoint,
                DeliveryType,
                FacturaSAP,
                PedidoSAP,
                PedidoV3,
                Valor_Subt,
                Valor_IVA,
                DocumentDate,
                Moneda,
                RFC,
                Tipo_Cambio,
                CondicionPago,
                Pais,
                NombreCliente,
                Ciudad,
                Colonia,
                CodigoPostal,
                Estado,
                Direccion,
                MetodoPago,
                Observaciones,
                Incoterms,
                NIF,
                EntregaSAP,
                Fecha_Vencimiento,
                Created,
                Order_Num,
                CompanyCode,
                OrgVentas,
                ReferenciaBancaria
            )
            VALUES
            (
                @sReferenceID,
                @sClienteSAP,
                @sCteFacturaSAP,
                @sCteEntregaSAP,
                @sCentro,
                @sClaseFactura,
                @sFacturaSAP,
                @sPedidoSAP,
                @sPedidoV3,
                @sValor_Subt,
                @sValor_IVA,
                CONCAT(@sFechaFactura, ' ', @sHoraFactura),
                @sCurrency,
                @sRFC,
                @sRate,
                @sPaymentTerms,
                @sCountry,
                @sPartnerName,
                @sCity,
                @sDistrict,
                @sPostalCode,
                @sRegion,
                @sAddress,
                @sPaymentMethod,
                @sComments,
                @sIncoterms,
                @sNIF,
                @sEntregaSAP,
                @sFechaVencimiento,
                GETDATE(),
                @sFacturaV3,
                @sCompanyCode,
                @sOrgVentas,
                @sBankReference
            );

            --------------------------------------------------------------------
            -- Partners
            --------------------------------------------------------------------
            INSERT INTO EAI_OWNER.TMP_DOCUMENT_PARTNERS
            (
                ReferenceID,
                Sold_to_Customer,
                Sold_to_Name,
                Sold_to_Address,
                Sold_to_District,
                Sold_to_City,
                Sold_to_State,
                Sold_to_Country,
                Sold_to_ZipCode,
                Bill_to_Customer,
                Bill_to_Name,
                Bill_to_Address,
                Bill_to_District,
                Bill_to_City,
                Bill_to_State,
                Bill_to_Country,
                Bill_to_ZipCode,
                Ship_to_Customer,
                Ship_to_Name,
                Ship_to_Address,
                Ship_to_District,
                Ship_to_City,
                Ship_to_State,
                Ship_to_Country,
                Ship_to_ZipCode
            )
            VALUES
            (
                @sReferenceID,
                @sSold_Customer,
                @sSold_Name,
                @sSold_Address,
                @sSold_District,
                @sSold_City,
                @sSold_State,
                @sSold_Country,
                @sSold_ZipCode,
                @sBill_Customer,
                @sBill_Name,
                @sBill_Address,
                @sBill_District,
                @sBill_City,
                @sBill_State,
                @sBill_Country,
                @sBill_ZipCode,
                @sShip_Customer,
                @sShip_Name,
                @sShip_Address,
                @sShip_District,
                @sShip_City,
                @sShip_State,
                @sShip_Country,
                @sShip_ZipCode
            );
        END
        ELSE
        BEGIN
            IF @nOutput > 0
                PRINT 'NO PROCESADO';
        END;

        ------------------------------------------------------------------------
        -- Actualiza log de recepción
        ------------------------------------------------------------------------
        UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
        SET
            Processed = GETDATE(),
            Reference = @sReferenceID,
            Status =
                CASE
                    WHEN @sProcesar = 'SI' THEN 'Processed'
                    WHEN @sProcesar = 'ED' THEN 'CheckData'
                    ELSE 'Review'
                END
        WHERE Row_ID = @sRow_ID;

        ------------------------------------------------------------------------
        -- Factura cancelada
        ------------------------------------------------------------------------
        IF @sClaseFactura = 'IVS'
        BEGIN
            SET @sProcesar = 'NO';

            UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER
            SET PedidoV3 = @sFolioFiscalDoc
            WHERE ReferenceID = @sReferenceID;
        END;

        ------------------------------------------------------------------------
        -- Routing posterior
        ------------------------------------------------------------------------
        IF @sProcesar = 'SI'
        BEGIN
            IF @sClaseFactura IN ('C020', 'C021', 'C022')
            BEGIN
                EXEC [EAI_OWNER].[INVOICE_TO_PREVENTA]
                    @sInvoiceID = @sReferenceID,
                    @pFolioFiscal = @sFolioFiscalDoc OUTPUT;
            END
            ELSE
            BEGIN
                IF SUBSTRING(COALESCE(@sCompanyCode, ''), 1, 2) = 'MX'
                BEGIN
                    EXEC [EAI_OWNER].[INVOICE_TO_OTROS]
                        @sInvoiceID = @sReferenceID;
                END
                ELSE
                BEGIN
                    UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
                    SET
                        Processed = GETDATE(),
                        Status = CONCAT('Reject', @sCompanyCode)
                    WHERE Row_ID = @sRow_ID;
                END;
            END;
        END;

    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging',
            @sReferenceID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'SF_PROC_PREINVOICE_INTER',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;
    END CATCH;
END;
GO
