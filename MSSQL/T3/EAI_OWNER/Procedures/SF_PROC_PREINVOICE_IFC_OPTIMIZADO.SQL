/*
    Despliegue de EAI_OWNER.SF_PROC_PREINVOICE_IFC_OPTIMIZADO.

    Segunda optimizacion: elimina las doce variables tabla, #ItemQueue y
    #Trace de la primera propuesta. Se recupera el camino de lectura XML del
    procedimiento original porque resulto mas rapido que la materializacion
    intermedia y que las alternativas XQuery/FOR XML evaluadas.

    Tambien corrige la equivalencia Oracle '' = NULL para importes opcionales;
    en SQL Server el texto vacio no puede insertarse en columnas NUMERIC.

    La version optimizada convive con SF_PROC_PREINVOICE_IFC. No modifica
    SF_PROC_CENTRAL_PAYMENT ni ningun otro llamador. Antes de sustituir el
    procedimiento original deben completarse las pruebas descritas en
    SF_PROC_PREINVOICE_IFC.MD.

    El script incluye indices idempotentes. Su creacion debe ejecutarse en una
    ventana controlada y despues de revisar indices equivalentes en la instancia.
*/
USE [T3QA];
GO

SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* Dependencias indispensables del flujo Oracle. */
IF SCHEMA_ID(N'EAI_OWNER') IS NULL
    THROW 51801, 'No existe el esquema EAI_OWNER.', 1;
IF SCHEMA_ID(N'T3') IS NULL
    THROW 51802, 'No existe el esquema T3.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]', N'U') IS NULL
    THROW 51803, 'No existe EAI_OWNER.MX_RECEIVE_MESSAGE_LOG.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_HEADER]', N'U') IS NULL
    THROW 51804, 'No existe EAI_OWNER.TMP_DOCUMENT_HEADER.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_DETAIL]', N'U') IS NULL
    THROW 51805, 'No existe EAI_OWNER.TMP_DOCUMENT_DETAIL.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]', N'U') IS NULL
    THROW 51806, 'No existe EAI_OWNER.TMP_DOCUMENT_CONDITIONS.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TRACE_EAI_OWNER]', N'U') IS NULL
    THROW 51807, 'No existe EAI_OWNER.TRACE_EAI_OWNER.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]', N'U') IS NULL
    THROW 51808, 'No existe EAI_OWNER.MX_EAI_MESSAGE_LOG.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[MX_HASHTABLE]', N'U') IS NULL
    THROW 51809, 'No existe EAI_OWNER.MX_HASHTABLE.', 1;
IF OBJECT_ID(N'[T3].[MATERIAL]', N'U') IS NULL
    THROW 51810, 'No existe T3.MATERIAL.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[LINE_ITEM_TEXT]') IS NULL
    THROW 51811, 'No existe EAI_OWNER.LINE_ITEM_TEXT.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[GETCONV]') IS NULL
    THROW 51812, 'No existe EAI_OWNER.GETCONV.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[FN_GET_DOC_TYPE]') IS NULL
    THROW 51813, 'No existe EAI_OWNER.FN_GET_DOC_TYPE.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[DEBITNOTE_TO_IFC]', N'P') IS NULL
    THROW 51814, 'No existe EAI_OWNER.DEBITNOTE_TO_IFC.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[INVOICE_TO_PREVENTA]', N'P') IS NULL
    THROW 51815, 'No existe EAI_OWNER.INVOICE_TO_PREVENTA.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[INVOICE_TO_FACTURA]', N'P') IS NULL
    THROW 51816, 'No existe EAI_OWNER.INVOICE_TO_FACTURA.', 1;
GO

/* Acceso por Row_ID al XML recibido y posterior actualizacion del mismo registro. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS I
    INNER JOIN sys.index_columns AS IC
        ON IC.object_id = I.object_id
       AND IC.index_id = I.index_id
       AND IC.key_ordinal = 1
    INNER JOIN sys.columns AS C
        ON C.object_id = IC.object_id
       AND C.column_id = IC.column_id
    WHERE I.object_id = OBJECT_ID(N'[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]')
      AND I.is_disabled = 0
      AND I.is_hypothetical = 0
      AND C.name = N'ROW_ID'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MX_RECEIVE_MESSAGE_LOG_ROW_ID]
    ON [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] ([ROW_ID])
    INCLUDE ([REFERENCE], [PROCESSED], [STATUS]);
END;
GO

/* Completa los indices por ReferenceID usados al reconstruir el documento. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS I
    INNER JOIN sys.index_columns AS IC
        ON IC.object_id = I.object_id
       AND IC.index_id = I.index_id
       AND IC.key_ordinal = 1
    INNER JOIN sys.columns AS C
        ON C.object_id = IC.object_id
       AND C.column_id = IC.column_id
    WHERE I.object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]')
      AND I.is_disabled = 0
      AND I.is_hypothetical = 0
      AND C.name = N'REFERENCEID'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TMP_DOCUMENT_CONDITIONS_REFERENCEID]
    ON [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS] ([REFERENCEID]);
END;
GO

/* Cubre el workaround de conversion de unidad de medida por material. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS I
    INNER JOIN sys.index_columns AS IC
        ON IC.object_id = I.object_id
       AND IC.index_id = I.index_id
       AND IC.key_ordinal = 1
    INNER JOIN sys.columns AS C
        ON C.object_id = IC.object_id
       AND C.column_id = IC.column_id
    WHERE I.object_id = OBJECT_ID(N'[T3].[MATERIAL]')
      AND I.is_disabled = 0
      AND I.is_hypothetical = 0
      AND C.name = N'MATERIAL'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MATERIAL_MATERIAL_UOM]
    ON [T3].[MATERIAL] ([MATERIAL])
    INCLUDE ([UM], [CIG_X_CLL], [CIG_X_PAQ], [CIG_X_CT]);
END;
GO

CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC_OPTIMIZADO]
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
        BEGIN TRANSACTION;

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
                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_HEADER]
                WHERE ReferenceID = @sReferenceID;

                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
                WHERE ReferenceID = @sReferenceID;

                DELETE FROM [EAI_OWNER].[TMP_DOCUMENT_CONDITIONS]
                WHERE ReferenceID = @sReferenceID;

                /* Cada grupo se recorre una sola vez. La asignacion secuencial
                   reproduce la ultima ocurrencia de Oracle sin reescanear el
                   XML con multiples llamadas value(). */
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
                    @sClienteSAP = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN PartnerID END), @sClienteSAP),
                    @sCountry = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN Country END), @sCountry),
                    @sPartnerName = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN PartnerName END), @sPartnerName),
                    @sCity = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN City END), @sCity),
                    @sDistrict = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN District END), @sDistrict),
                    @sPostalCode = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN PostalCode END), @sPostalCode),
                    @sRegion = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN Region END), @sRegion),
                    @sAddress = COALESCE(MAX(CASE WHEN FunctionID = N'AG' THEN Address END), @sAddress),
                    @sCteEntregaSAP = COALESCE(MAX(CASE WHEN FunctionID = N'WE' THEN PartnerID END), @sCteEntregaSAP),
                    @sCtePagadorSAP = COALESCE(MAX(CASE WHEN FunctionID = N'RE' THEN PartnerID END), @sCtePagadorSAP),
                    @sCteFacturaSAP = COALESCE(
                        MAX(CASE WHEN FunctionID = N'RE' THEN PartnerID END),
                        MAX(CASE WHEN FunctionID = N'RSA' THEN PartnerID END),
                        @sCteFacturaSAP)
                FROM Partners;

                SELECT TOP (1)
                    @sFechaVencimiento = X.H.value('(Date/text())[1]', 'nvarchar(50)')
                FROM @xmlContent.nodes('/Invoice/Message/HeaderDate') X(H)
                WHERE X.H.value('(Qualifier/text())[1]', 'nvarchar(20)') = N'028';

                SELECT
                    @sPedidoV3 = COALESCE(MAX(CASE WHEN Qualifier = N'001' THEN UPPER(DocumentValue) END), @sPedidoV3),
                    @sPedidoSAP = COALESCE(MAX(CASE WHEN Qualifier = N'002' THEN DocumentValue END), @sPedidoSAP),
                    @sFechaFactura = COALESCE(MAX(CASE WHEN Qualifier = N'009' THEN DateValue END), @sFechaFactura),
                    @sHoraFactura = COALESCE(MAX(CASE WHEN Qualifier = N'009' THEN TimeValue END), @sHoraFactura),
                    @sFacturaV3 = COALESCE(MAX(CASE WHEN Qualifier = N'017' THEN DocumentValue END), @sFacturaV3)
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
                    @sValor_IVA = COALESCE(MAX(CASE WHEN Qualifier = N'005' THEN SummaryValue END), @sValor_IVA),
                    @sValor_Subt = COALESCE(MAX(CASE WHEN Qualifier = N'011' THEN SummaryValue END), @sValor_Subt)
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
                        @sDetValor_Subt = COALESCE(MAX(CASE WHEN Qualifier = N'003' THEN ValueAmount END), @sDetValor_Subt),
                        @sPrecioUnitario = COALESCE(MAX(CASE WHEN Qualifier = N'003' THEN PriceItem END), @sPrecioUnitario),
                        @sDetBonif_Subt = COALESCE(MAX(CASE WHEN Qualifier = N'007' THEN ValueAmount END), @sDetBonif_Subt)
                    FROM
                    (
                        SELECT
                            X.T.value('(Qualifier/text())[1]', 'nvarchar(50)') AS Qualifier,
                            X.T.value('(ValueAmount/text())[1]', 'nvarchar(50)') AS ValueAmount,
                            X.T.value('(PriceItem/text())[1]', 'nvarchar(50)') AS PriceItem
                        FROM @itemXML.nodes('/ItemData/ItemTerms') X(T)
                    ) ItemTerms;

                    SELECT
                        @sCondZFSISign = COALESCE(MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') THEN ConditionSign END), @sCondZFSISign),
                        @sCondZFSIValue = COALESCE(MAX(CASE WHEN ConditionType IN (N'ZFSI', N'ZDN3') THEN ConditionValue END), @sCondZFSIValue),
                        @sCondZFSKSign = COALESCE(MAX(CASE WHEN ConditionType = N'ZFSK' THEN ConditionSign END), @sCondZFSKSign),
                        @sCondZFSKValue = COALESCE(MAX(CASE WHEN ConditionType = N'ZFSK' THEN ConditionValue END), @sCondZFSKValue),
                        @sCondZT21Sign = COALESCE(MAX(CASE WHEN ConditionType = N'ZT21' THEN ConditionSign END), @sCondZT21Sign),
                        @sCondZT21Value = COALESCE(MAX(CASE WHEN ConditionType = N'ZT21' THEN ConditionValue END), @sCondZT21Value),
                        @sDetBonif_Subt = COALESCE(MAX(CASE WHEN ConditionType = N'ZDNV' THEN ConditionValue END), @sDetBonif_Subt),
                        @sCondZPROValue = COALESCE(MAX(CASE WHEN ConditionType = N'ZPR0' THEN ConditionValue END), @sCondZPROValue),
                        @sCondZEXSValue = COALESCE(MAX(CASE WHEN ConditionType = N'ZEXS' THEN ConditionValue END), @sCondZEXSValue),
                        @sCondZEXCValue = COALESCE(MAX(CASE WHEN ConditionType IN (N'ZEXC', N'ZEXJ') THEN ConditionValue END), @sCondZEXCValue),
                        @sCondZEXOValue = COALESCE(MAX(CASE WHEN ConditionType = N'ZEXO' THEN ConditionValue END), @sCondZEXOValue)
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

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

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

        /* Igual que Oracle y el procedimiento SQL Server actual, el error se
           registra para que el consumidor de la cola decida el reintento. */
    END CATCH;
END;
GO
