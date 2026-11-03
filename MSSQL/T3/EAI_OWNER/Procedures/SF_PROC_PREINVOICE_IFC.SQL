/*
    Procedure : EAI_OWNER.SF_PROC_PREINVOICE_IFC
    Objetivo  : Descomponer un XML de factura SAP en encabezado, condiciones y
                detalles temporales, y enviarlo al flujo T3 correspondiente.
    Integridad: La reconstrucción temporal se ejecuta en una transacción para
                evitar mezclar datos nuevos con restos de una ejecución anterior.
    Errores   : Se revierten los cambios, se libera cualquier cursor abierto y
                se registra la incidencia si la transaccion es propia. Con
                transaccion externa se propaga la causa al llamador, sin
                confirmar ni revertir toda su transaccion.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
(
    @sRow_ID   VARCHAR(50),
    @nRowNum   INT = 1,
    @nOutput   INT = 0,
    @nPID      INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    -- La transaccion del llamador no pertenece a este procedimiento.
    DECLARE @EntryTranCount INT = @@TRANCOUNT,
            @StartedTran BIT = 0,
            @SavepointCreated BIT = 0;

    DECLARE
        @sMsg                NVARCHAR(500),
        @v_ID                NVARCHAR(30),
        @sErrorCode          NVARCHAR(20),
        @sReferenceID        NVARCHAR(30),
        @sProcesar           NVARCHAR(20),
        @sFacturaSAP         NVARCHAR(30),
        @sCurrency           NVARCHAR(30),
        @sRFC                NVARCHAR(30),
        @sRate               NVARCHAR(50),
        @sPaymentTerms       NVARCHAR(50),
        @sClienteSAP         NVARCHAR(50),
        @sCteEntregaSAP      NVARCHAR(50),
        @sCteFacturaSAP      NVARCHAR(50),
        @sCtePagadorSAP      NVARCHAR(50),
        @sFacturaV3          NVARCHAR(50),
        @sFechaFactura       NVARCHAR(50),
        @sFechaVencimiento   NVARCHAR(50),
        @sHoraFactura        NVARCHAR(50),
        @sPedidoSAP          NVARCHAR(50),
        @sPedidoV3           NVARCHAR(50),
        @sCountry            NVARCHAR(80),
        @sPartnerName        NVARCHAR(80),
        @sCity               NVARCHAR(80),
        @sDistrict           NVARCHAR(80),
        @sPostalCode         NVARCHAR(80),
        @sRegion             NVARCHAR(80),
        @sAddress            NVARCHAR(80),
        @sDOC_TYPE           NVARCHAR(20),
        @sNumLinea           NVARCHAR(50),
        @sOrgVentas          NVARCHAR(50),
        @sClaseFactura       NVARCHAR(50),
        @sCompanyCode        NVARCHAR(50),
        @sValor_Subt         NVARCHAR(50),
        @sValor_IVA          NVARCHAR(50),
        @sCantidadVta        NVARCHAR(50),
        @sUnidadMedVta       NVARCHAR(50),
        @sStatusItem         NVARCHAR(50),
        @sCentro             NVARCHAR(50),
        @sMaterialUOM        NVARCHAR(50),
        @sMaterial           NVARCHAR(50),
        @sMatDescription     NVARCHAR(50),
        @sPrecioUnitario     NVARCHAR(50),
        @sDetValor_Subt      NVARCHAR(50),
        @sDetValor_IVA       NVARCHAR(50),
        @sDetBonif_Subt      NVARCHAR(50),
        @sCondZFSIValue      NVARCHAR(50),
        @sCondZFSISign       NVARCHAR(50),
        @sCondZFSKValue      NVARCHAR(50),
        @sCondZFSKSign       NVARCHAR(50),
        @sCondZT21Value      NVARCHAR(50),
        @sCondZT21Sign       NVARCHAR(50),
        @sCondZPROValue      NVARCHAR(50),
        @sCondZEXSValue      NVARCHAR(50),
        @sCondZEXCValue      NVARCHAR(50),
        @sCondZEXOValue      NVARCHAR(50),
        @sPaymentMethod      NVARCHAR(200) = N'',
        @sBankReference      NVARCHAR(200) = N'',
        @sQualifier          NVARCHAR(80),
        @sLanguage           NVARCHAR(80),
        @sTextLine           NVARCHAR(80),
        @sItemText_ES        NVARCHAR(4000),
        @sItemText_EN        NVARCHAR(4000),
        @nItems              INT,
        @sTipoDocV3          NVARCHAR(4) = N'NO',
        @sFolioFiscalDoc     NVARCHAR(30),
        @sSalesDoc_Type      NVARCHAR(30),
        @nA51                INT = 0,
        @MessageFound        BIT = 0,
        @xmlContent          XML,
        @itemXML             XML,
        @itemTextos          XML;

    BEGIN TRY
        IF @EntryTranCount = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTran = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION PreinvoiceWork;
            SET @SavepointCreated = 1;
        END;

        IF @nOutput > 0
            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'Begin');

        SELECT
            @xmlContent = XML_Content,
            @MessageFound = 1
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        WHERE Row_ID = @sRow_ID;

        IF @xmlContent IS NOT NULL
        BEGIN
            SELECT
                @v_ID          = @xmlContent.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]', 'nvarchar(30)'),
                @sReferenceID  = @xmlContent.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]', 'nvarchar(30)'),
                @sFacturaSAP   = @xmlContent.value('(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]', 'nvarchar(30)'),
                @sCurrency     = @xmlContent.value('(/Invoice/Message/InvoiceHeader/Currency/text())[1]', 'nvarchar(30)'),
                @sRFC          = @xmlContent.value('(/Invoice/Message/InvoiceHeader/V3DocumentNumber/text())[1]', 'nvarchar(30)'),
                @sRate         = @xmlContent.value('(/Invoice/Message/InvoiceHeader/Rate/text())[1]', 'nvarchar(50)'),
                @sPaymentTerms = @xmlContent.value('(/Invoice/Message/InvoiceHeader/PaymentTerms/text())[1]', 'nvarchar(50)');

            SET @sProcesar = CASE WHEN NULLIF(@v_ID, N'') IS NULL THEN N'NO' ELSE N'SI' END;

            IF @sProcesar = N'SI'
            BEGIN
                /* RI_REF_SEEK_TMP_DOCUMENT_HEADER */
                -- Igualdad VARCHAR para buscar por indice; se conserva la comparacion
                -- Unicode y el predicado original si convertir la referencia pierde datos.
                IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@sReferenceID)))
                   = CONVERT(varbinary(max),@sReferenceID)
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                    WHERE ReferenceID = CONVERT(varchar(50),@sReferenceID)
                      AND CONVERT(nvarchar(50),ReferenceID) = @sReferenceID;
                END
                ELSE
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER] WHERE ReferenceID = @sReferenceID;
                END;
                /* RI_REF_END_TMP_DOCUMENT_HEADER */

                /* RI_REF_SEEK_TMP_DOCUMENT_DETAIL */
                -- Igualdad VARCHAR para buscar por indice; se conserva la comparacion
                -- Unicode y el predicado original si convertir la referencia pierde datos.
                IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@sReferenceID)))
                   = CONVERT(varbinary(max),@sReferenceID)
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
                    WHERE ReferenceID = CONVERT(varchar(50),@sReferenceID)
                      AND CONVERT(nvarchar(50),ReferenceID) = @sReferenceID;
                END
                ELSE
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL] WHERE ReferenceID = @sReferenceID;
                END;
                /* RI_REF_END_TMP_DOCUMENT_DETAIL */

                /* RI_REF_SEEK_TMP_DOCUMENT_CONDITIONS */
                -- Igualdad VARCHAR para buscar por indice; se conserva la comparacion
                -- Unicode y el predicado original si convertir la referencia pierde datos.
                IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@sReferenceID)))
                   = CONVERT(varbinary(max),@sReferenceID)
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]
                    WHERE ReferenceID = CONVERT(varchar(50),@sReferenceID)
                      AND CONVERT(nvarchar(50),ReferenceID) = @sReferenceID;
                END
                ELSE
                BEGIN
                    DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS] WHERE ReferenceID = @sReferenceID;
                END;
                /* RI_REF_END_TMP_DOCUMENT_CONDITIONS */

                /* Agregaciones sin entradas NULL: el indicador conserva NULL cuando
                   no hay valores aplicables; el MAX de texto conserva vacios y
                   duplicados como antes, sin emitir el aviso 8153.
                   ANSI_WARNINGS permanece habilitado. */
                ;WITH Partners AS
                (
                    SELECT
                        X.P.value('(Function/text())[1]',   'nvarchar(20)') AS FunctionID,
                        X.P.value('(PartnerID/text())[1]',  'nvarchar(50)') AS PartnerID,
                        X.P.value('(Country/text())[1]',    'nvarchar(80)') AS Country,
                        X.P.value('(Name/text())[1]',       'nvarchar(80)') AS PartnerName,
                        X.P.value('(City/text())[1]',       'nvarchar(80)') AS City,
                        X.P.value('(District/text())[1]',   'nvarchar(80)') AS District,
                        X.P.value('(PostalCode/text())[1]', 'nvarchar(80)') AS PostalCode,
                        X.P.value('(Region/text())[1]',     'nvarchar(80)') AS Region,
                        X.P.value('(Address/text())[1]',    'nvarchar(80)') AS Address
                    FROM @xmlContent.nodes('/Invoice/Message/InvoicePartner') X(P)
                )
                SELECT
                    @sClienteSAP = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND PartnerID IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(PartnerID, N'') ELSE N'' END) END, @sClienteSAP),
                    @sCountry = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND Country IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(Country, N'') ELSE N'' END) END, @sCountry),
                    @sPartnerName = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND PartnerName IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(PartnerName, N'') ELSE N'' END) END, @sPartnerName),
                    @sCity = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND City IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(City, N'') ELSE N'' END) END, @sCity),
                    @sDistrict = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND District IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(District, N'') ELSE N'' END) END, @sDistrict),
                    @sPostalCode = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND PostalCode IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(PostalCode, N'') ELSE N'' END) END, @sPostalCode),
                    @sRegion = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND Region IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(Region, N'') ELSE N'' END) END, @sRegion),
                    @sAddress = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'AG' AND Address IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'AG' THEN COALESCE(Address, N'') ELSE N'' END) END, @sAddress),
                    @sCteEntregaSAP = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'WE' AND PartnerID IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'WE' THEN COALESCE(PartnerID, N'') ELSE N'' END) END, @sCteEntregaSAP),
                    @sCtePagadorSAP = COALESCE(CASE WHEN MAX(CASE WHEN FunctionID = N'RE' AND PartnerID IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'RE' THEN COALESCE(PartnerID, N'') ELSE N'' END) END, @sCtePagadorSAP),
                    @sCteFacturaSAP = COALESCE(
                        CASE WHEN MAX(CASE WHEN FunctionID = N'RE' AND PartnerID IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'RE' THEN COALESCE(PartnerID, N'') ELSE N'' END) END,
                        CASE WHEN MAX(CASE WHEN FunctionID = N'RSA' AND PartnerID IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN FunctionID = N'RSA' THEN COALESCE(PartnerID, N'') ELSE N'' END) END,
                        @sCteFacturaSAP)
                FROM Partners;

                SELECT TOP (1)
                    @sFechaVencimiento = X.H.value('(Date/text())[1]', 'nvarchar(50)')
                FROM @xmlContent.nodes('/Invoice/Message/HeaderDate') X(H)
                WHERE X.H.value('(Qualifier/text())[1]', 'nvarchar(20)') = N'028';

                SELECT
                    @sPedidoV3 = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'001' AND UPPER(DocumentValue) IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'001' THEN COALESCE(UPPER(DocumentValue), N'') ELSE N'' END) END, @sPedidoV3),
                    @sPedidoSAP = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'002' AND DocumentValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'002' THEN COALESCE(DocumentValue, N'') ELSE N'' END) END, @sPedidoSAP),
                    @sFechaFactura = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'009' AND DateValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'009' THEN COALESCE(DateValue, N'') ELSE N'' END) END, @sFechaFactura),
                    @sHoraFactura = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'009' AND TimeValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'009' THEN COALESCE(TimeValue, N'') ELSE N'' END) END, @sHoraFactura),
                    @sFacturaV3 = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'017' AND DocumentValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'017' THEN COALESCE(DocumentValue, N'') ELSE N'' END) END, @sFacturaV3)
                FROM
                (
                    SELECT
                        X.R.value('(Qualifier/text())[1]', 'nvarchar(20)') AS Qualifier,
                        X.R.value('(Document/text())[1]', 'nvarchar(50)') AS DocumentValue,
                        X.R.value('(Date/text())[1]', 'nvarchar(50)') AS DateValue,
                        X.R.value('(Time/text())[1]', 'nvarchar(50)') AS TimeValue
                    FROM @xmlContent.nodes('/Invoice/Message/ReferenceData') X(R)
                ) ReferencesData;

                DECLARE @OrgQualifier NVARCHAR(20), @OrgValue NVARCHAR(50);

                DECLARE curOrg CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        X.O.value('(Qualifier/text())[1]',    'nvarchar(20)'),
                        X.O.value('(Organization/text())[1]', 'nvarchar(50)')
                    FROM @xmlContent.nodes('/Invoice/Message/OrganizationData') X(O);

                OPEN curOrg;
                FETCH NEXT FROM curOrg INTO @OrgQualifier, @OrgValue;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @OrgQualifier = N'008'
                        SET @sOrgVentas = @OrgValue;
                    ELSE IF @OrgQualifier = N'003'
                        SELECT @sCompanyCode = @OrgValue, @sOrgVentas = @OrgValue;
                    ELSE IF @OrgQualifier = N'015'
                    BEGIN
                        IF @OrgValue = N'Nota de Venta'
                            SET @sClaseFactura = N'C005';
                        ELSE IF @OrgValue = N'Payable'
                            SET @sClaseFactura = N'C004';
                        ELSE IF @OrgValue = N'PROFORMA'
                            SELECT @sClaseFactura = N'C006', @sFacturaV3 = @sReferenceID;
                        ELSE IF @OrgValue = N'ZIG2'
                            SELECT @sClaseFactura = N'C022', @sFacturaV3 = @sReferenceID;
                        ELSE IF @OrgValue = N'ZB1E'
                            SELECT @sClaseFactura = N'C019', @sFacturaV3 = @sReferenceID;
                        ELSE IF @OrgValue = N'ZG'
                            SELECT
                                @sClaseFactura = CASE WHEN SUBSTRING(@sClienteSAP, 1, 3) = N'009'
                                                     THEN N'C031' ELSE N'C025' END,
                                @sFacturaV3 = @sReferenceID;
                        ELSE IF @OrgValue = N'ZL'
                            SELECT
                                @sClaseFactura = CASE WHEN SUBSTRING(@sClienteSAP, 1, 3) = N'009'
                                                     THEN N'C030' ELSE N'C0FX' END,
                                @sFacturaV3 = @sReferenceID;
                    END;

                    FETCH NEXT FROM curOrg INTO @OrgQualifier, @OrgValue;
                END;

                CLOSE curOrg;
                DEALLOCATE curOrg;

                SELECT
                    @sValor_IVA = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'005' AND SummaryValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'005' THEN COALESCE(SummaryValue, N'') ELSE N'' END) END, @sValor_IVA),
                    @sValor_Subt = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'011' AND SummaryValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'011' THEN COALESCE(SummaryValue, N'') ELSE N'' END) END, @sValor_Subt)
                FROM
                (
                    SELECT
                        X.S.value('(Qualifier/text())[1]', 'nvarchar(20)') AS Qualifier,
                        X.S.value('(ValueSummary/text())[1]', 'nvarchar(50)') AS SummaryValue
                    FROM @xmlContent.nodes('/Invoice/Message/SummaryGeneral') X(S)
                ) Summaries;

                INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]
                (
                    ReferenceID, ItemID, Condition, TotalCondition,
                    TotalAmount, Currency, ConditionText, UnitPrice,
                    ConditionID, UnitMeasure, Quantity
                )
                SELECT
                    @sReferenceID,
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                    X.C.value('(Indicator/text())[1]',     'nvarchar(50)'),
                    X.C.value('(Total/text())[1]',         'nvarchar(50)'),
                    X.C.value('(Amount/text())[1]',        'nvarchar(50)'),
                    X.C.value('(Currency/text())[1]',      'nvarchar(50)'),
                    X.C.value('(ConditionText/text())[1]', 'nvarchar(200)'),
                    X.C.value('(UnitPrice/text())[1]',     'nvarchar(50)'),
                    X.C.value('(ConditionID/text())[1]',   'nvarchar(50)'),
                    X.C.value('(UOM/text())[1]',           'nvarchar(50)'),
                    X.C.value('(Quantity/text())[1]',      'nvarchar(50)')
                FROM @xmlContent.nodes('/Invoice/Message/HeaderConditions') X(C);

                DECLARE curHeaderText CURSOR LOCAL FAST_FORWARD FOR
                    SELECT X.T.query('.')
                    FROM @xmlContent.nodes('/Invoice/Message/TextIdentification') X(T);

                OPEN curHeaderText;
                FETCH NEXT FROM curHeaderText INTO @itemTextos;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SELECT
                        @sQualifier = @itemTextos.value('(/TextIdentification/TextID/text())[1]', 'nvarchar(80)'),
                        @sLanguage = @itemTextos.value('(/TextIdentification/Language/text())[1]', 'nvarchar(80)');

                    DECLARE curHeaderLine CURSOR LOCAL FAST_FORWARD FOR
                        SELECT X.L.value('(TextLine/text())[1]', 'nvarchar(80)')
                        FROM @itemTextos.nodes('/TextIdentification/TextHeader') X(L);

                    OPEN curHeaderLine;
                    FETCH NEXT FROM curHeaderLine INTO @sTextLine;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        IF @sQualifier = N'Z024'
                            SET @sPaymentMethod = CONCAT(COALESCE(@sPaymentMethod, N''), COALESCE(@sTextLine, N''));
                        ELSE IF @sQualifier = N'Z048'
                            SET @sBankReference = CONCAT(COALESCE(@sBankReference, N''), COALESCE(@sTextLine, N''));

                        FETCH NEXT FROM curHeaderLine INTO @sTextLine;
                    END;

                    CLOSE curHeaderLine;
                    DEALLOCATE curHeaderLine;
                    FETCH NEXT FROM curHeaderText INTO @itemTextos;
                END;

                CLOSE curHeaderText;
                DEALLOCATE curHeaderText;

                SET @nItems = 0;

                DECLARE curItemData CURSOR LOCAL FAST_FORWARD FOR
                    SELECT X.I.query('.')
                    FROM @xmlContent.nodes('/Invoice/Message/ItemData') X(I);

                OPEN curItemData;
                FETCH NEXT FROM curItemData INTO @itemXML;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @nItems += 1;

                    /* Oracle convierte '' en NULL. En SQL Server los importes
                       opcionales deben reiniciarse explícitamente a NULL; usar
                       N'' provoca SQL-8114 al insertarlos en columnas NUMERIC. */
                    SELECT
                        @sNumLinea = NULL, @sCantidadVta = NULL,
                        @sUnidadMedVta = NULL, @sCentro = NULL,
                        @sMaterial = NULL, @sMatDescription = NULL,
                        @sDetValor_Subt = NULL, @sPrecioUnitario = NULL,
                        @sDetBonif_Subt = NULL, @sDetValor_IVA = NULL,
                        @sItemText_ES = NULL, @sItemText_EN = NULL,
                        @sCondZFSIValue = NULL, @sCondZFSISign = NULL,
                        @sCondZFSKValue = NULL, @sCondZFSKSign = NULL,
                        @sCondZT21Value = NULL, @sCondZT21Sign = NULL,
                        @sCondZPROValue = NULL, @sCondZEXSValue = NULL,
                        @sCondZEXCValue = NULL, @sCondZEXOValue = NULL;

                    SELECT
                        @sNumLinea = @itemXML.value('(/ItemData/ItemNumber/text())[1]', 'nvarchar(50)'),
                        @sCantidadVta = @itemXML.value('(/ItemData/Quantity/text())[1]', 'nvarchar(50)'),
                        @sUnidadMedVta = @itemXML.value('(/ItemData/UnitOfMeasure/text())[1]', 'nvarchar(50)'),
                        @sCentro = @itemXML.value('(/ItemData/Plant/text())[1]', 'nvarchar(50)');

                    SELECT @sNumLinea = [EAI_OWNER].[LINE_ITEM_TEXT](@sNumLinea);

                    IF CONVERT(DECIMAL(38,0), @sNumLinea) > 9999
                        SET @sNumLinea = CONVERT(NVARCHAR(50), @nItems);

                    SELECT TOP (1)
                        @sMaterial = X.ID.value('(MaterialID/text())[1]', 'nvarchar(50)'),
                        @sMatDescription = X.ID.value('(MaterialDescription/text())[1]', 'nvarchar(50)')
                    FROM @itemXML.nodes('/ItemData/ItemID') X(ID)
                    WHERE X.ID.value('(ObjectIdentification/text())[1]', 'nvarchar(50)') = N'002';

                    SELECT
                        @sDetValor_Subt = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'003' AND ValueAmount IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'003' THEN COALESCE(ValueAmount, N'') ELSE N'' END) END, @sDetValor_Subt),
                        @sPrecioUnitario = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'003' AND PriceItem IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'003' THEN COALESCE(PriceItem, N'') ELSE N'' END) END, @sPrecioUnitario),
                        @sDetBonif_Subt = COALESCE(CASE WHEN MAX(CASE WHEN Qualifier = N'007' AND ValueAmount IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN Qualifier = N'007' THEN COALESCE(ValueAmount, N'') ELSE N'' END) END, @sDetBonif_Subt)
                    FROM
                    (
                        SELECT
                            X.T.value('(Qualifier/text())[1]', 'nvarchar(50)') AS Qualifier,
                            X.T.value('(ValueAmount/text())[1]', 'nvarchar(50)') AS ValueAmount,
                            X.T.value('(PriceItem/text())[1]', 'nvarchar(50)') AS PriceItem
                        FROM @itemXML.nodes('/ItemData/ItemTerms') X(T)
                    ) ItemTerms;

                    SELECT
                        @sCondZFSISign = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') AND ConditionSign IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') THEN COALESCE(ConditionSign, N'') ELSE N'' END) END, @sCondZFSISign),
                        @sCondZFSIValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZFSIValue),
                        @sCondZFSKSign = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZFSK' AND ConditionSign IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZFSK' THEN COALESCE(ConditionSign, N'') ELSE N'' END) END, @sCondZFSKSign),
                        @sCondZFSKValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZFSK' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZFSK' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZFSKValue),
                        @sCondZT21Sign = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZT21' AND ConditionSign IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZT21' THEN COALESCE(ConditionSign, N'') ELSE N'' END) END, @sCondZT21Sign),
                        @sCondZT21Value = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZT21' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZT21' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZT21Value),
                        @sDetBonif_Subt = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZDNV' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZDNV' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sDetBonif_Subt),
                        @sCondZPROValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZPR0' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZPR0' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZPROValue),
                        @sCondZEXSValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZEXS' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZEXS' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZEXSValue),
                        @sCondZEXCValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType IN (N'ZEXC', N'ZEXJ') AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType IN (N'ZEXC', N'ZEXJ') THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZEXCValue),
                        @sCondZEXOValue = COALESCE(CASE WHEN MAX(CASE WHEN ConditionType = N'ZEXO' AND ConditionValue IS NOT NULL THEN 1 ELSE 0 END) = 1
                        THEN MAX(CASE WHEN ConditionType = N'ZEXO' THEN COALESCE(ConditionValue, N'') ELSE N'' END) END, @sCondZEXOValue)
                    FROM
                    (
                        SELECT
                            X.C.value('(TermConditionIndicator/text())[1]', 'nvarchar(50)') AS ConditionSign,
                            X.C.value('(TermConditionType/text())[1]', 'nvarchar(50)') AS ConditionType,
                            X.C.value('(TermConditionValue/text())[1]', 'nvarchar(50)') AS ConditionValue
                        FROM @itemXML.nodes('/ItemData/ItemTermsCondition') X(C)
                    ) ItemConditions;

                    SELECT TOP (1)
                        @sDetValor_IVA = X.TX.value('(ValueTax/text())[1]', 'nvarchar(50)')
                    FROM @itemXML.nodes('/ItemData/ItemTaxes') X(TX);

                    DECLARE curItemText CURSOR LOCAL FAST_FORWARD FOR
                        SELECT X.TH.query('.')
                        FROM @itemXML.nodes('/ItemData/ItemTextHeader') X(TH);

                    OPEN curItemText;
                    FETCH NEXT FROM curItemText INTO @itemTextos;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SELECT
                            @sQualifier = @itemTextos.value('(/ItemTextHeader/TextID/text())[1]', 'nvarchar(80)'),
                            @sLanguage = @itemTextos.value('(/ItemTextHeader/Language/text())[1]', 'nvarchar(80)');

                        DECLARE curItemTextLine CURSOR LOCAL FAST_FORWARD FOR
                            SELECT X.D.value('(TextLine/text())[1]', 'nvarchar(80)')
                            FROM @itemTextos.nodes('/ItemTextHeader/ItemTextDetail') X(D);

                        OPEN curItemTextLine;
                        FETCH NEXT FROM curItemTextLine INTO @sTextLine;

                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                            IF @sLanguage = N'ES'
                                SET @sItemText_ES = CONCAT(COALESCE(@sItemText_ES, N''), COALESCE(@sTextLine, N''));
                            ELSE IF @sLanguage = N'EN'
                                SET @sItemText_EN = CONCAT(COALESCE(@sItemText_EN, N''), COALESCE(@sTextLine, N''));

                            FETCH NEXT FROM curItemTextLine INTO @sTextLine;
                        END;

                        CLOSE curItemTextLine;
                        DEALLOCATE curItemTextLine;
                        FETCH NEXT FROM curItemText INTO @itemTextos;
                    END;

                    CLOSE curItemText;
                    DEALLOCATE curItemText;

                    /* Workarounds de materiales y notas de debito de Oracle. */
                    IF @sMaterial IN (N'R031', N'R902')
                        SET @sMaterial = N'8800111';

                    IF @sMaterial IN (N'88000001', N'99000001')
                    BEGIN
                        SET @sTipoDocV3 = N'DN';
                        SET @sPartnerName = @sFacturaV3;
                        SET @sFacturaV3 = @sClienteSAP;
                        SET @sClienteSAP = RIGHT(REPLICATE(N'0', 10) + COALESCE(@sPartnerName, N''), 10);
                        SET @sPartnerName = N'DebitNote';
                        SET @sBankReference =
                            CONCAT(CONVERT(CHAR(8), SYSDATETIME(), 112), N' ',
                                   CONVERT(CHAR(8), SYSDATETIME(), 108));
                    END;

                    /* Se conserva este cursor residual porque Oracle aplica la
                       conversion secuencialmente a cada coincidencia MATERIAL. */
                    SET @sMaterialUOM = SUBSTRING(@sMaterial, 11, 8);

                    DECLARE
                        @UOM_Fact NVARCHAR(50),
                        @UOM_SKU NVARCHAR(50),
                        @CIG_X_CLL DECIMAL(18,6),
                        @CASE_PACK DECIMAL(18,6),
                        @MASTER_CASE DECIMAL(18,6),
                        @CantidadDecimal DECIMAL(18,6);

                    /* RI_SKU_SEEK_V1 */
                    -- Buscar con la clave VARCHAR sin perder la comparacion Unicode.
                    -- Se conserva el cursor y GETCONV por cada coincidencia de material.
                    IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(18),@sMaterialUOM)))
                       = CONVERT(varbinary(max),@sMaterialUOM)
                    BEGIN
DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR
                        SELECT
                            [EAI_OWNER].[GETCONV](N'ECC_V3 UOM', @sUnidadMedVta),
                            SKU.UM,
                            COALESCE(SKU.CIG_X_CLL, 0),
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE CONVERT(DECIMAL(18,6), SKU.CIG_X_PAQ) /
                                     CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL)
                            END,
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE CONVERT(DECIMAL(18,6), SKU.CIG_X_CT) /
                                     CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL)
                            END
                        FROM [T3].[MATERIAL] SKU
                        WHERE SKU.MATERIAL = CONVERT(varchar(18),@sMaterialUOM)
                          AND CONVERT(nvarchar(50),SKU.MATERIAL) = @sMaterialUOM;
                    END
                    ELSE
                    BEGIN
DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR
                        SELECT
                            [EAI_OWNER].[GETCONV](N'ECC_V3 UOM', @sUnidadMedVta),
                            SKU.UM,
                            COALESCE(SKU.CIG_X_CLL, 0),
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE CONVERT(DECIMAL(18,6), SKU.CIG_X_PAQ) /
                                     CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL)
                            END,
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE CONVERT(DECIMAL(18,6), SKU.CIG_X_CT) /
                                     CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL)
                            END
                        FROM [T3].[MATERIAL] SKU
                        WHERE SKU.MATERIAL = @sMaterialUOM;
                    END;
                    /* RI_SKU_SEEK_END_V1 */

                    OPEN curSKU;
                    FETCH NEXT FROM curSKU
                    INTO @UOM_Fact, @UOM_SKU, @CIG_X_CLL, @CASE_PACK, @MASTER_CASE;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        /* Sin COALESCE: en Oracle NULL != valor no es TRUE. */
                        IF @UOM_Fact <> @UOM_SKU
                        BEGIN
                            SET @sUnidadMedVta = @UOM_SKU;
                            SET @CantidadDecimal = CONVERT(DECIMAL(18,6), @sCantidadVta);

                            IF @UOM_Fact = N'PAQ'
                                SET @sCantidadVta =
                                    CONVERT(NVARCHAR(50), @CantidadDecimal * @CASE_PACK);
                            ELSE IF @UOM_Fact = N'CASES'
                                SET @sCantidadVta =
                                    CONVERT(NVARCHAR(50), @CantidadDecimal * @MASTER_CASE);
                            ELSE
                                SET @sUnidadMedVta = @UOM_Fact;
                        END;

                        FETCH NEXT FROM curSKU
                        INTO @UOM_Fact, @UOM_SKU, @CIG_X_CLL,
                             @CASE_PACK, @MASTER_CASE;
                    END;

                    CLOSE curSKU;
                    DEALLOCATE curSKU;

                    IF @nOutput > 0
                    BEGIN
                        INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                            (Created, Object_Type, Object_Reference, Description)
                        VALUES
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Item           = ', @sNumLinea)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Cantidad       = ', @sCantidadVta)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Unidad Vta     = ', @sUnidadMedVta)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Centro         = ', @sCentro)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Material       = ', @sMaterial)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Descripcion    = ', @sMatDescription)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor Subt     = ', @sDetValor_Subt)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor IVA      = ', @sDetValor_IVA)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Envio Subt     = ', @sCondZFSIValue)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Credito Subt   = ', @sCondZFSKValue)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor IEPS     = ', @sCondZT21Value)),
                            (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Bonif Subt     = ', @sDetBonif_Subt));
                    END;

                    INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
                    (
                        ReferenceID, ItemID, Material, Plant,
                        Cantidad, UnidadMedida, Valor_Subt, Valor_IVA,
                        Bonif_Subt, Status_Producto, MaterialDescripcion,
                        Envio_Subt, Valor_IEPS, Credito_Subt,
                        ZPRO_Valor, ZEXS_Valor, ZEXC_Valor, ZEXO_Valor,
                        PrecioUnitario, Leyenda_EN, Leyenda_ES
                    )
                    VALUES
                    (
                        @sReferenceID, @sNumLinea, @sMaterial, @sCentro,
                        @sCantidadVta, @sUnidadMedVta, @sDetValor_Subt, @sDetValor_IVA,
                        @sDetBonif_Subt, @sStatusItem, @sMatDescription,
                        @sCondZFSIValue, @sCondZT21Value, @sCondZFSKValue,
                        @sCondZPROValue, @sCondZEXSValue, @sCondZEXCValue, @sCondZEXOValue,
                        @sPrecioUnitario, @sItemText_EN, @sItemText_ES
                    );

                    FETCH NEXT FROM curItemData INTO @itemXML;
                END;

                CLOSE curItemData;
                DEALLOCATE curItemData;

                INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                (
                    ReferenceID, Cust_to_SAP, Bill_to_SAP, Ship_to_SAP,
                    ShippingPoint, DeliveryType, FacturaSAP, PedidoSAP,
                    PedidoV3, Valor_Subt, Valor_IVA, DocumentDate,
                    Moneda, RFC, Tipo_Cambio, CondicionPago,
                    Pais, NombreCliente, Ciudad, Colonia,
                    CodigoPostal, Estado, Direccion, MetodoPago,
                    Fecha_Vencimiento, Created,
                    CompanyCode, OrgVentas, ReferenciaBancaria
                )
                VALUES
                (
                    @sReferenceID, @sClienteSAP, @sCteFacturaSAP, @sCteEntregaSAP,
                    @sCentro, @sClaseFactura, @sFacturaV3, @sPedidoSAP,
                    @sPedidoV3, @sValor_Subt, @sValor_IVA,
                    CONCAT(@sFechaFactura, N' ', @sHoraFactura),
                    @sCurrency, @sRFC, @sRate, @sPaymentTerms,
                    @sCountry, @sPartnerName, @sCity, @sDistrict,
                    @sPostalCode, @sRegion, @sAddress, @sPaymentMethod,
                    @sFechaVencimiento, SYSDATETIME(),
                    @sCompanyCode, @sOrgVentas, @sBankReference
                );
            END
            ELSE IF @nOutput > 0
                INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'NO Procesado');
        END
        ELSE IF @MessageFound = 1
        BEGIN
            /* XML_CONTENT es tipo XML en SQL Server. NULL reproduce el registro
               Oracle cuyo DocumentNumber no puede procesarse. */
            SET @sProcesar = N'NO';
            IF @nOutput > 0
                INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'NO Procesado');
        END;

        /* Reglas posteriores al parseo, en el mismo orden que Oracle. */
        SELECT @nA51 = COUNT(1)
        FROM [EAI_OWNER].[MX_HASHTABLE] CFG
        WHERE CFG.Type = 'PDV A51'
          AND CFG.Source = @sClienteSAP;

        IF @nA51 > 0
            SET @sDOC_TYPE = N'PR';
        ELSE
            SELECT @sDOC_TYPE = [EAI_OWNER].[FN_GET_DOC_TYPE](@sPedidoV3);

        IF @sDOC_TYPE = N'VD'
        BEGIN
            SET @sProcesar = N'VD';
            SET @sClaseFactura = N'C003';
        END;

        IF @sPartnerName = N'DebitNote'
            SET @sProcesar = N'SI';

        /* Sin COALESCE: Oracle no rechaza cuando CompanyCode es NULL. */
        IF SUBSTRING(@sCompanyCode, 1, 2) <> N'MX'
            SET @sProcesar = N'DI';

        IF @sClaseFactura = N'Discard'
            SET @sProcesar = N'CN';

        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        SET
            Processed = SYSDATETIME(),
            Reference = @sReferenceID,
            Status =
                CASE @sProcesar
                    WHEN N'SI' THEN 'Processed'
                    WHEN N'VD' THEN 'Processed'
                    WHEN N'NA' THEN 'NotApply'
                    WHEN N'ED' THEN 'CheckData'
                    WHEN N'CN' THEN 'ConfirmCN'
                    WHEN N'DI' THEN CONCAT('Reject', @sCompanyCode)
                    ELSE 'Review'
                END
        WHERE Row_ID = @sRow_ID;

        IF @nOutput > 0
            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Procesar      -> ', @sProcesar)),
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('ClaseFactura  -> ', @sClaseFactura)),
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('SalesDoc_Type -> ', @sSalesDoc_Type)),
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('PedidoV3      -> ', @sPedidoV3));

        IF @sProcesar = N'SI'
        BEGIN
            IF @sTipoDocV3 = N'DN'
            BEGIN
                SET @sPedidoV3 = REPLACE(@sPedidoV3, N' ', N'_');

                UPDATE [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                SET PedidoV3 = @sPedidoV3
                WHERE ReferenceID = @sReferenceID;

                IF @nOutput > 0
                    INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID,
                         CONCAT('DEBITNOTE_TO_IFC( ', @sReferenceID, ' )'));

                EXEC [EAI_OWNER].[DEBITNOTE_TO_IFC] @sReferenceID;
            END
            ELSE
            BEGIN
                IF @nOutput > 0
                    INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID,
                         CONCAT('INVOICE_TO_PREVENTA( ', @sReferenceID, ' )'));

                EXEC [EAI_OWNER].[INVOICE_TO_PREVENTA]
                    @sReferenceID,
                    @sFolioFiscalDoc OUTPUT;
            END;
        END
        ELSE IF @sProcesar = N'VD'
        BEGIN
            IF @nOutput > 0
                INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID,
                     CONCAT('INVOICE_TO_FACTURA( ', @sReferenceID, ' )'));

            EXEC [EAI_OWNER].[INVOICE_TO_FACTURA]
                @sReferenceID,
                @sFolioFiscalDoc OUTPUT;
        END;

        IF @nOutput > 0
            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (SYSDATETIME(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'End');

        IF @StartedTran = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curItemTextLine') >= 0
            CLOSE curItemTextLine;
        IF CURSOR_STATUS('local', 'curItemTextLine') >= -1
            DEALLOCATE curItemTextLine;
        IF CURSOR_STATUS('local', 'curItemText') >= 0
            CLOSE curItemText;
        IF CURSOR_STATUS('local', 'curItemText') >= -1
            DEALLOCATE curItemText;
        IF CURSOR_STATUS('local', 'curHeaderLine') >= 0
            CLOSE curHeaderLine;
        IF CURSOR_STATUS('local', 'curHeaderLine') >= -1
            DEALLOCATE curHeaderLine;
        IF CURSOR_STATUS('local', 'curHeaderText') >= 0
            CLOSE curHeaderText;
        IF CURSOR_STATUS('local', 'curHeaderText') >= -1
            DEALLOCATE curHeaderText;
        IF CURSOR_STATUS('local', 'curOrg') >= 0
            CLOSE curOrg;
        IF CURSOR_STATUS('local', 'curOrg') >= -1
            DEALLOCATE curOrg;
        IF CURSOR_STATUS('local', 'curSKU') >= 0
            CLOSE curSKU;
        IF CURSOR_STATUS('local', 'curSKU') >= -1
            DEALLOCATE curSKU;
        IF CURSOR_STATUS('local', 'curItemData') >= 0
            CLOSE curItemData;
        IF CURSOR_STATUS('local', 'curItemData') >= -1
            DEALLOCATE curItemData;

        IF @StartedTran = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION PreinvoiceWork;

        -- Una transaccion externa invalida no admite rollback a savepoint
        -- ni INSERT al log. El llamador debe recibir la causa y revertirla.
        IF @EntryTranCount > 0
            THROW;

        SET @sErrorCode = CONCAT(N'SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT
        (
            CONCAT
            (
                N'SQL-', ERROR_NUMBER(),
                N'; linea=', ERROR_LINE(),
                N'; procedimiento=', COALESCE(ERROR_PROCEDURE(), N'SF_PROC_PREINVOICE_IFC_OPTIMIZADO'),
                N'; mensaje=', ERROR_MESSAGE()
            ),
            250
        );

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
            STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
            SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', @sReferenceID, SYSDATETIME(), NULL, @nPID,
            'Error', 'PROC_PREINVOICE_IFC', @sMsg, 'T-SQL',
            @sErrorCode, NULL, NULL, NULL
        );

        /* Sin transaccion externa, el error se registra para que el
           consumidor de la cola decida el reintento. */
    END CATCH;
END;
GO
