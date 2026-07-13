CREATE PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
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

    DECLARE
        @sMsg                NVARCHAR(500),
        @v_ID                NVARCHAR(30),
        @sErrorCode          NVARCHAR(20),
        @sReferenceID        NVARCHAR(30),
        @sProcesar           NVARCHAR(20) = N'NO',
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
        @xmlContent          XML,
        @itemXML             XML,
        @itemTextos          XML;

    BEGIN TRY
        BEGIN TRAN;

        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'Begin');
        END;

        SELECT @xmlContent = TRY_CONVERT(XML, XML_Content)
        FROM [EAI_OWNER].[MX_Receive_Message_Log]
        WHERE Row_ID = @sRow_ID;

        IF @xmlContent IS NULL
        BEGIN
            SET @sProcesar = N'NO';

            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'NO Procesado - XML vacío o inválido');
            END;
        END
        ELSE
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
                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                WHERE ReferenceID = @sReferenceID;

                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
                WHERE ReferenceID = @sReferenceID;

                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]
                WHERE ReferenceID = @sReferenceID;

                --------------------------------------------------------------------
                -- Partners
                --------------------------------------------------------------------
                ;WITH P AS
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
                    @sClienteSAP    = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN PartnerID    END), @sClienteSAP),
                    @sCountry       = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN Country      END), @sCountry),
                    @sPartnerName   = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN PartnerName  END), @sPartnerName),
                    @sCity          = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN City         END), @sCity),
                    @sDistrict      = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN District     END), @sDistrict),
                    @sPostalCode    = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN PostalCode   END), @sPostalCode),
                    @sRegion        = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN Region       END), @sRegion),
                    @sAddress       = COALESCE(MAX(CASE WHEN FunctionID = 'AG'  THEN Address      END), @sAddress),
                    @sCteEntregaSAP = COALESCE(MAX(CASE WHEN FunctionID = 'WE'  THEN PartnerID    END), @sCteEntregaSAP),
                    @sCtePagadorSAP = COALESCE(MAX(CASE WHEN FunctionID = 'RE'  THEN PartnerID    END), @sCtePagadorSAP),
                    @sCteFacturaSAP = COALESCE(
                                            MAX(CASE WHEN FunctionID = 'RE'  THEN PartnerID END),
                                            MAX(CASE WHEN FunctionID = 'RSA' THEN PartnerID END),
                                            @sCteFacturaSAP
                                       )
                FROM P;

                --------------------------------------------------------------------
                -- Header Date
                --------------------------------------------------------------------
                SELECT TOP (1)
                    @sFechaVencimiento = X.H.value('(Date/text())[1]', 'nvarchar(50)')
                FROM @xmlContent.nodes('/Invoice/Message/HeaderDate') X(H)
                WHERE X.H.value('(Qualifier/text())[1]', 'nvarchar(20)') = '028';

                --------------------------------------------------------------------
                -- Reference Data
                --------------------------------------------------------------------
                SELECT
                    @sPedidoV3     = COALESCE(MAX(CASE WHEN RefQualifier = '001' THEN UPPER(RefDocument) END), @sPedidoV3),
                    @sPedidoSAP    = COALESCE(MAX(CASE WHEN RefQualifier = '002' THEN RefDocument        END), @sPedidoSAP),
                    @sFechaFactura = COALESCE(MAX(CASE WHEN RefQualifier = '009' THEN RefDate            END), @sFechaFactura),
                    @sHoraFactura  = COALESCE(MAX(CASE WHEN RefQualifier = '009' THEN RefTime            END), @sHoraFactura),
                    @sFacturaV3    = COALESCE(MAX(CASE WHEN RefQualifier = '017' THEN RefDocument        END), @sFacturaV3)
                FROM
                (
                    SELECT
                        X.R.value('(Qualifier/text())[1]', 'nvarchar(20)') AS RefQualifier,
                        X.R.value('(Document/text())[1]',  'nvarchar(50)') AS RefDocument,
                        X.R.value('(Date/text())[1]',      'nvarchar(50)') AS RefDate,
                        X.R.value('(Time/text())[1]',      'nvarchar(50)') AS RefTime
                    FROM @xmlContent.nodes('/Invoice/Message/ReferenceData') X(R)
                ) R;

                --------------------------------------------------------------------
                -- Organization Data
                --------------------------------------------------------------------
                DECLARE curOrg CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        X.O.value('(Qualifier/text())[1]',    'nvarchar(20)') AS RefQualifier,
                        X.O.value('(Organization/text())[1]', 'nvarchar(50)') AS RefValue
                    FROM @xmlContent.nodes('/Invoice/Message/OrganizationData') X(O);

                DECLARE @OrgQualifier NVARCHAR(20), @OrgValue NVARCHAR(50);

                OPEN curOrg;
                FETCH NEXT FROM curOrg INTO @OrgQualifier, @OrgValue;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @OrgQualifier = '008'
                        SET @sOrgVentas = @OrgValue;
                    ELSE IF @OrgQualifier = '003'
                    BEGIN
                        SET @sCompanyCode = @OrgValue;
                        SET @sOrgVentas = @OrgValue;
                    END
                    ELSE IF @OrgQualifier = '015'
                    BEGIN
                        IF @OrgValue = 'Nota de Venta'
                            SET @sClaseFactura = 'C005';
                        ELSE IF @OrgValue = 'Payable'
                            SET @sClaseFactura = 'C004';
                        ELSE IF @OrgValue = 'PROFORMA'
                        BEGIN
                            SET @sClaseFactura = 'C006';
                            SET @sFacturaV3 = @sReferenceID;
                        END
                        ELSE IF @OrgValue = 'ZIG2'
                        BEGIN
                            SET @sClaseFactura = 'C022';
                            SET @sFacturaV3 = @sReferenceID;
                        END
                        ELSE IF @OrgValue = 'ZB1E'
                        BEGIN
                            SET @sClaseFactura = 'C019';
                            SET @sFacturaV3 = @sReferenceID;
                        END
                        ELSE IF @OrgValue = 'ZG'
                        BEGIN
                            SET @sClaseFactura = 'C025';
                            SET @sFacturaV3 = @sReferenceID;

                            IF SUBSTRING(COALESCE(@sClienteSAP, ''), 1, 3) = '009'
                                SET @sClaseFactura = 'C031';
                        END
                        ELSE IF @OrgValue = 'ZL'
                        BEGIN
                            SET @sClaseFactura = 'C0FX';
                            SET @sFacturaV3 = @sReferenceID;

                            IF SUBSTRING(COALESCE(@sClienteSAP, ''), 1, 3) = '009'
                                SET @sClaseFactura = 'C030';
                        END
                    END;

                    FETCH NEXT FROM curOrg INTO @OrgQualifier, @OrgValue;
                END;

                CLOSE curOrg;
                DEALLOCATE curOrg;

                --------------------------------------------------------------------
                -- Summary General
                --------------------------------------------------------------------
                SELECT
                    @sValor_IVA  = COALESCE(MAX(CASE WHEN RefQualifier = '005' THEN RefValue END), @sValor_IVA),
                    @sValor_Subt = COALESCE(MAX(CASE WHEN RefQualifier = '011' THEN RefValue END), @sValor_Subt)
                FROM
                (
                    SELECT
                        X.S.value('(Qualifier/text())[1]',    'nvarchar(20)') AS RefQualifier,
                        X.S.value('(ValueSummary/text())[1]', 'nvarchar(50)') AS RefValue
                    FROM @xmlContent.nodes('/Invoice/Message/SummaryGeneral') X(S)
                ) S;

                --------------------------------------------------------------------
                -- Header Conditions
                --------------------------------------------------------------------
                INSERT INTO [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]
                (
                    ReferenceID, ItemID, Condition, TotalCondition,
                    TotalAmount, Currency, ConditionText, UnitPrice,
                    ConditionID, UnitMeasure, Quantity
                )
                SELECT
                    @sReferenceID,
                    ROW_NUMBER() OVER (ORDER BY (SELECT 1)),
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

                --------------------------------------------------------------------
                -- Header Text: Z024 PaymentMethod, Z048 BankReference
                --------------------------------------------------------------------
                DECLARE curHeaderText CURSOR LOCAL FAST_FORWARD FOR
                    SELECT X.T.query('.')
                    FROM @xmlContent.nodes('/Invoice/Message/TextIdentification') X(T);

                OPEN curHeaderText;
                FETCH NEXT FROM curHeaderText INTO @itemTextos;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SELECT
                        @sQualifier = @itemTextos.value('(/TextIdentification/TextID/text())[1]', 'nvarchar(80)'),
                        @sLanguage  = @itemTextos.value('(/TextIdentification/Language/text())[1]', 'nvarchar(80)');

                    DECLARE curHeaderLine CURSOR LOCAL FAST_FORWARD FOR
                        SELECT
                            X.L.value('(TextLine/text())[1]', 'nvarchar(80)')
                        FROM @itemTextos.nodes('/TextIdentification/TextHeader') X(L);

                    OPEN curHeaderLine;
                    FETCH NEXT FROM curHeaderLine INTO @sTextLine;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        IF @sQualifier = 'Z024'
                            SET @sPaymentMethod = CONCAT(COALESCE(@sPaymentMethod, N''), COALESCE(@sTextLine, N''));
                        ELSE IF @sQualifier = 'Z048'
                            SET @sBankReference = CONCAT(COALESCE(@sBankReference, N''), COALESCE(@sTextLine, N''));

                        FETCH NEXT FROM curHeaderLine INTO @sTextLine;
                    END;

                    CLOSE curHeaderLine;
                    DEALLOCATE curHeaderLine;

                    FETCH NEXT FROM curHeaderText INTO @itemTextos;
                END;

                CLOSE curHeaderText;
                DEALLOCATE curHeaderText;

                --------------------------------------------------------------------
                -- Document Detail / Items
                --------------------------------------------------------------------
                SET @nItems = 0;

                DECLARE curItemData CURSOR LOCAL FAST_FORWARD FOR
                    SELECT X.I.query('.')
                    FROM @xmlContent.nodes('/Invoice/Message/ItemData') X(I);

                OPEN curItemData;
                FETCH NEXT FROM curItemData INTO @itemXML;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @nItems += 1;

                    SELECT
                        @sNumLinea       = N'',
                        @sCantidadVta    = N'',
                        @sUnidadMedVta   = N'',
                        @sCentro         = N'',
                        @sMaterial       = N'',
                        @sMatDescription = N'',
                        @sDetValor_Subt  = N'',
                        @sPrecioUnitario = N'',
                        @sDetBonif_Subt  = N'',
                        @sDetValor_IVA   = N'',
                        @sItemText_ES    = N'',
                        @sItemText_EN    = N'',
                        @sCondZFSIValue  = N'',
                        @sCondZFSISign   = N'',
                        @sCondZFSKValue  = N'',
                        @sCondZFSKSign   = N'',
                        @sCondZT21Value  = N'',
                        @sCondZT21Sign   = N'',
                        @sCondZPROValue  = N'',
                        @sCondZEXSValue  = N'',
                        @sCondZEXCValue  = N'',
                        @sCondZEXOValue  = N'';

                    SELECT
                        @sNumLinea     = @itemXML.value('(/ItemData/ItemNumber/text())[1]',    'nvarchar(50)'),
                        @sCantidadVta  = @itemXML.value('(/ItemData/Quantity/text())[1]',      'nvarchar(50)'),
                        @sUnidadMedVta = @itemXML.value('(/ItemData/UnitOfMeasure/text())[1]', 'nvarchar(50)'),
                        @sCentro       = @itemXML.value('(/ItemData/Plant/text())[1]',         'nvarchar(50)');

                    SELECT @sNumLinea = [EAI_OWNER].[LINE_ITEM_TEXT](@sNumLinea);

                    IF TRY_CONVERT(INT, @sNumLinea) > 9999
                        SET @sNumLinea = CONVERT(NVARCHAR(50), @nItems);

                    SELECT TOP (1)
                        @sMaterial       = X.ID.value('(MaterialID/text())[1]',          'nvarchar(50)'),
                        @sMatDescription = X.ID.value('(MaterialDescription/text())[1]', 'nvarchar(50)')
                    FROM @itemXML.nodes('/ItemData/ItemID') X(ID)
                    WHERE X.ID.value('(ObjectIdentification/text())[1]', 'nvarchar(50)') = '002';

                    SELECT
                        @sDetValor_Subt  = COALESCE(MAX(CASE WHEN RefQualifier = '003' THEN RefValueAmount END), @sDetValor_Subt),
                        @sPrecioUnitario = COALESCE(MAX(CASE WHEN RefQualifier = '003' THEN RefPriceItem   END), @sPrecioUnitario),
                        @sDetBonif_Subt  = COALESCE(MAX(CASE WHEN RefQualifier = '007' THEN RefValueAmount END), @sDetBonif_Subt)
                    FROM
                    (
                        SELECT
                            X.T.value('(ValueAmount/text())[1]',   'nvarchar(50)') AS RefValueAmount,
                            X.T.value('(Qualifier/text())[1]',     'nvarchar(50)') AS RefQualifier,
                            X.T.value('(TotalLineItem/text())[1]', 'nvarchar(50)') AS RefTotalLineItem,
                            X.T.value('(PriceItem/text())[1]',     'nvarchar(50)') AS RefPriceItem
                        FROM @itemXML.nodes('/ItemData/ItemTerms') X(T)
                    ) IT;

                    SELECT
                        @sCondZFSISign  = COALESCE(MAX(CASE WHEN ItemCondType IN ('ZFSI', 'ZDN3') THEN ItemCondSign  END), @sCondZFSISign),
                        @sCondZFSIValue = COALESCE(MAX(CASE WHEN ItemCondType IN ('ZFSI', 'ZDN3') THEN ItemCondValue END), @sCondZFSIValue),
                        @sCondZFSKSign  = COALESCE(MAX(CASE WHEN ItemCondType = 'ZFSK' THEN ItemCondSign  END), @sCondZFSKSign),
                        @sCondZFSKValue = COALESCE(MAX(CASE WHEN ItemCondType = 'ZFSK' THEN ItemCondValue END), @sCondZFSKValue),
                        @sCondZT21Sign  = COALESCE(MAX(CASE WHEN ItemCondType = 'ZT21' THEN ItemCondSign  END), @sCondZT21Sign),
                        @sCondZT21Value = COALESCE(MAX(CASE WHEN ItemCondType = 'ZT21' THEN ItemCondValue END), @sCondZT21Value),
                        @sDetBonif_Subt = COALESCE(MAX(CASE WHEN ItemCondType = 'ZDNV' THEN ItemCondValue END), @sDetBonif_Subt),
                        @sCondZPROValue = COALESCE(MAX(CASE WHEN ItemCondType = 'ZPR0' THEN ItemCondValue END), @sCondZPROValue),
                        @sCondZEXSValue = COALESCE(MAX(CASE WHEN ItemCondType = 'ZEXS' THEN ItemCondValue END), @sCondZEXSValue),
                        @sCondZEXCValue = COALESCE(MAX(CASE WHEN ItemCondType IN ('ZEXC', 'ZEXJ') THEN ItemCondValue END), @sCondZEXCValue),
                        @sCondZEXOValue = COALESCE(MAX(CASE WHEN ItemCondType = 'ZEXO' THEN ItemCondValue END), @sCondZEXOValue)
                    FROM
                    (
                        SELECT
                            X.C.value('(TermConditionIndicator/text())[1]', 'nvarchar(50)') AS ItemCondSign,
                            X.C.value('(TermConditionType/text())[1]',      'nvarchar(50)') AS ItemCondType,
                            X.C.value('(TermConditionValue/text())[1]',     'nvarchar(50)') AS ItemCondValue
                        FROM @itemXML.nodes('/ItemData/ItemTermsCondition') X(C)
                    ) IC;

                    SELECT TOP (1)
                        @sDetValor_IVA = X.TX.value('(ValueTax/text())[1]', 'nvarchar(50)')
                    FROM @itemXML.nodes('/ItemData/ItemTaxes') X(TX);

                    ----------------------------------------------------------------
                    -- Item Texts
                    ----------------------------------------------------------------
                    DECLARE curItemText CURSOR LOCAL FAST_FORWARD FOR
                        SELECT X.TH.query('.')
                        FROM @itemXML.nodes('/ItemData/ItemTextHeader') X(TH);

                    OPEN curItemText;
                    FETCH NEXT FROM curItemText INTO @itemTextos;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SELECT
                            @sQualifier = @itemTextos.value('(/ItemTextHeader/TextID/text())[1]',   'nvarchar(80)'),
                            @sLanguage  = @itemTextos.value('(/ItemTextHeader/Language/text())[1]', 'nvarchar(80)');

                        DECLARE curItemTextLine CURSOR LOCAL FAST_FORWARD FOR
                            SELECT X.TD.value('(TextLine/text())[1]', 'nvarchar(80)')
                            FROM @itemTextos.nodes('/ItemTextHeader/ItemTextDetail') X(TD);

                        OPEN curItemTextLine;
                        FETCH NEXT FROM curItemTextLine INTO @sTextLine;

                        WHILE @@FETCH_STATUS = 0
                        BEGIN
                            IF @sLanguage = 'ES'
                                SET @sItemText_ES = CONCAT(COALESCE(@sItemText_ES, N''), COALESCE(@sTextLine, N''));
                            ELSE IF @sLanguage = 'EN'
                                SET @sItemText_EN = CONCAT(COALESCE(@sItemText_EN, N''), COALESCE(@sTextLine, N''));

                            FETCH NEXT FROM curItemTextLine INTO @sTextLine;
                        END;

                        CLOSE curItemTextLine;
                        DEALLOCATE curItemTextLine;

                        FETCH NEXT FROM curItemText INTO @itemTextos;
                    END;

                    CLOSE curItemText;
                    DEALLOCATE curItemText;

                    ----------------------------------------------------------------
                    -- Workaround materiales
                    ----------------------------------------------------------------
                    IF @sMaterial IN ('R031', 'R902')
                        SET @sMaterial = '8800111';

                    ----------------------------------------------------------------
                    -- Workaround Debit Note
                    ----------------------------------------------------------------
                    IF @sMaterial IN ('88000001', '99000001')
                    BEGIN
                        SET @sTipoDocV3 = 'DN';
                        SET @sPartnerName = @sFacturaV3;
                        SET @sFacturaV3 = @sClienteSAP;
                        SET @sClienteSAP = RIGHT(REPLICATE('0', 10) + COALESCE(@sPartnerName, ''), 10);
                        SET @sPartnerName = 'DebitNote';
                        SET @sBankReference = CONVERT(CHAR(8), GETDATE(), 112) + ' ' + CONVERT(CHAR(8), GETDATE(), 108);
                    END;

                    ----------------------------------------------------------------
                    -- Workaround UOM
                    ----------------------------------------------------------------
                    SET @sMaterialUOM = SUBSTRING(COALESCE(@sMaterial, ''), 11, 8);

                    DECLARE
                        @UOM_Fact NVARCHAR(50),
                        @UOM_SKU NVARCHAR(50),
                        @CIG_X_CLL DECIMAL(18,6),
                        @CASE_PACK DECIMAL(18,6),
                        @MASTER_CASE DECIMAL(18,6),
                        @CantidadDecimal DECIMAL(18,6);

                    DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR
                        SELECT
                            [EAI_OWNER].[GETCONV]('ECC_V3 UOM', @sUnidadMedVta) AS UOM_Fact,
                            SKU.UM AS UOM_SKU,
                            COALESCE(SKU.CIG_X_CLL, 0) AS CIG_X_CLL,
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE TRY_CONVERT(DECIMAL(18,6), SKU.CIG_X_PAQ) / NULLIF(TRY_CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL), 0)
                            END AS CASE_PACK,
                            CASE
                                WHEN COALESCE(SKU.CIG_X_CLL, 0) = 0 THEN 1
                                ELSE TRY_CONVERT(DECIMAL(18,6), SKU.CIG_X_CT) / NULLIF(TRY_CONVERT(DECIMAL(18,6), SKU.CIG_X_CLL), 0)
                            END AS MASTER_CASE
                        FROM [T3].[MATERIAL] SKU
                        WHERE SKU.MATERIAL = @sMaterialUOM;

                    OPEN curSKU;
                    FETCH NEXT FROM curSKU INTO @UOM_Fact, @UOM_SKU, @CIG_X_CLL, @CASE_PACK, @MASTER_CASE;

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        IF COALESCE(@UOM_Fact, '') <> COALESCE(@UOM_SKU, '')
                        BEGIN
                            SET @sUnidadMedVta = @UOM_SKU;
                            SET @CantidadDecimal = TRY_CONVERT(DECIMAL(18,6), @sCantidadVta);

                            IF @UOM_Fact = 'PAQ'
                                SET @sCantidadVta = CONVERT(NVARCHAR(50), @CantidadDecimal * @CASE_PACK);
                            ELSE IF @UOM_Fact = 'CASES'
                                SET @sCantidadVta = CONVERT(NVARCHAR(50), @CantidadDecimal * @MASTER_CASE);
                            ELSE
                                SET @sUnidadMedVta = @UOM_Fact;
                        END;

                        FETCH NEXT FROM curSKU INTO @UOM_Fact, @UOM_SKU, @CIG_X_CLL, @CASE_PACK, @MASTER_CASE;
                    END;

                    CLOSE curSKU;
                    DEALLOCATE curSKU;

                    IF @nOutput > 0
                    BEGIN
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                            (Created, Object_Type, Object_Reference, Description)
                        VALUES
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Item           = ', @sNumLinea)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Cantidad       = ', @sCantidadVta)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Unidad Vta     = ', @sUnidadMedVta)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Centro         = ', @sCentro)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Material       = ', @sMaterial)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Descripcion    = ', @sMatDescription)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor Subt     = ', @sDetValor_Subt)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor IVA      = ', @sDetValor_IVA)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Envio Subt     = ', @sCondZFSIValue)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Credito Subt   = ', @sCondZFSKValue)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Valor IEPS     = ', @sCondZT21Value)),
                            (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Bonif Subt     = ', @sDetBonif_Subt));
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

                --------------------------------------------------------------------
                -- Header insert
                --------------------------------------------------------------------
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
                    CONCAT(@sFechaFactura, ' ', @sHoraFactura),
                    @sCurrency, @sRFC, @sRate, @sPaymentTerms,
                    @sCountry, @sPartnerName, @sCity, @sDistrict,
                    @sPostalCode, @sRegion, @sAddress, @sPaymentMethod,
                    @sFechaVencimiento, GETDATE(),
                    @sCompanyCode, @sOrgVentas, @sBankReference
                );
            END
            ELSE
            BEGIN
                IF @nOutput > 0
                BEGIN
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'NO Procesado');
                END;
            END;
        END;

        ------------------------------------------------------------------------
        -- Determinación de tipo de documento
        ------------------------------------------------------------------------
        SELECT @nA51 = COUNT(1)
        FROM [EAI_OWNER].[MX_Hashtable] CFG
        WHERE CFG.Type = 'PDV A51'
          AND CFG.Source = @sClienteSAP;

        IF @nA51 > 0
            SET @sDOC_TYPE = 'PR';
        ELSE
            SELECT @sDOC_TYPE = [EAI_OWNER].[FN_GET_DOC_TYPE](@sPedidoV3);

        IF @sDOC_TYPE = 'VD'
        BEGIN
            SET @sProcesar = 'VD';
            SET @sClaseFactura = 'C003';
        END;

        IF @sPartnerName = 'DebitNote'
            SET @sProcesar = 'SI';

        IF SUBSTRING(COALESCE(@sCompanyCode, ''), 1, 2) <> 'MX'
            SET @sProcesar = 'DI';

        IF @sClaseFactura = 'Discard'
            SET @sProcesar = 'CN';

        UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
        SET
            Processed = GETDATE(),
            Reference = @sReferenceID,
            Status =
                CASE @sProcesar
                    WHEN 'SI' THEN 'Processed'
                    WHEN 'VD' THEN 'Processed'
                    WHEN 'NA' THEN 'NotApply'
                    WHEN 'ED' THEN 'CheckData'
                    WHEN 'CN' THEN 'ConfirmCN'
                    WHEN 'DI' THEN CONCAT('Reject', COALESCE(@sCompanyCode, ''))
                    ELSE 'Review'
                END
        WHERE Row_ID = @sRow_ID;

        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('Procesar      -> ', @sProcesar)),
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('ClaseFactura  -> ', @sClaseFactura)),
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('SalesDoc_Type -> ', @sSalesDoc_Type)),
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('PedidoV3      -> ', @sPedidoV3));
        END;

        ------------------------------------------------------------------------
        -- Dispatch downstream
        ------------------------------------------------------------------------
        IF @sProcesar = 'SI'
        BEGIN
            IF @sTipoDocV3 = 'DN'
            BEGIN
                SET @sPedidoV3 = REPLACE(@sPedidoV3, ' ', '_');

                UPDATE [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                SET PedidoV3 = @sPedidoV3
                WHERE ReferenceID = @sReferenceID;

                IF @nOutput > 0
                BEGIN
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('DEBITNOTE_TO_IFC( ', @sReferenceID, ' )'));
                END;

                EXEC [EAI_OWNER].[DEBITNOTE_TO_IFC] @sReferenceID;
            END
            ELSE
            BEGIN
                IF @nOutput > 0
                BEGIN
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('INVOICE_TO_PREVENTA( ', @sReferenceID, ' )'));
                END;

                EXEC [EAI_OWNER].[INVOICE_TO_PREVENTA]
                    @sReferenceID,
                    @sFolioFiscalDoc OUTPUT;
            END;
        END
        ELSE IF @sProcesar = 'VD'
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    (Created, Object_Type, Object_Reference, Description)
                VALUES
                    (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, CONCAT('INVOICE_TO_FACTURA( ', @sReferenceID, ' )'));
            END;

            EXEC [EAI_OWNER].[INVOICE_TO_FACTURA]
                @sReferenceID,
                @sFolioFiscalDoc OUTPUT;
        END;

        IF @nOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_PREINVOICE_IFC', @sRow_ID, 'End');
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curOrg') >= -1
        BEGIN
            CLOSE curOrg;
            DEALLOCATE curOrg;
        END;

        IF CURSOR_STATUS('local', 'curHeaderText') >= -1
        BEGIN
            CLOSE curHeaderText;
            DEALLOCATE curHeaderText;
        END;

        IF CURSOR_STATUS('local', 'curItemData') >= -1
        BEGIN
            CLOSE curItemData;
            DEALLOCATE curItemData;
        END;

        IF CURSOR_STATUS('local', 'curItemText') >= -1
        BEGIN
            CLOSE curItemText;
            DEALLOCATE curItemText;
        END;

        IF CURSOR_STATUS('local', 'curSKU') >= -1
        BEGIN
            CLOSE curSKU;
            DEALLOCATE curSKU;
        END;

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
            STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
            SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', @sReferenceID, GETDATE(), NULL, @nPID,
            'Error', 'PROC_PREINVOICE_IFC', @sMsg, 'T-SQL',
            @sErrorCode, NULL, NULL, NULL
        );

        THROW;
    END CATCH;
END;
GO