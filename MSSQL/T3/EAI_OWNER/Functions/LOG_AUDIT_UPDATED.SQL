CREATE OR ALTER FUNCTION [EAI_OWNER].[LOG_AUDIT_UPDATED]
(
    @sObjectName VARCHAR(128),
    @sActionMode VARCHAR(20),
    @sROWID      VARCHAR(200),
    @sReturnType VARCHAR(20)
)
RETURNS VARCHAR(2000)
AS
BEGIN
    DECLARE
        @sReturn          VARCHAR(2000),
        @sReferenceKey    VARCHAR(2000) = '',
        @sReferenceUpdate VARCHAR(2000) = '';

    -- Oracle filtra por ROWID; las tablas log migradas exponen TICKET_REFERENCIA como identificador disponible.
    IF @sObjectName = 'PRICELIST_DETALLE_LOG'
    BEGIN
        SELECT
            @sReferenceKey =
                CASE
                    WHEN @sActionMode = 'Delete'
                        THEN CONCAT(Reg.Old_PriceListID, '-', Reg.Old_Matnr, '-', Reg.Old_Effective)
                    ELSE CONCAT(Reg.New_PriceListID, '-', Reg.New_Matnr, '-', Reg.New_Effective)
                END,
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_PriceListID, 'Empty') <> ISNULL(Reg.New_PriceListID, 'Empty') THEN CONCAT('PLID:', ISNULL(Reg.Old_PriceListID, 'Empty'), '->', ISNULL(Reg.New_PriceListID, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Effective, 'Empty') <> ISNULL(Reg.New_Effective, 'Empty') THEN CONCAT('Effective:', ISNULL(Reg.Old_Effective, 'Empty'), '->', ISNULL(Reg.New_Effective, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Expiration, 'Empty') <> ISNULL(Reg.New_Expiration, 'Empty') THEN CONCAT('Expiration:', ISNULL(Reg.Old_Expiration, 'Empty'), '->', ISNULL(Reg.New_Expiration, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_MATNR, 'Empty') <> ISNULL(Reg.New_MATNR, 'Empty') THEN CONCAT('SKU:', ISNULL(Reg.Old_MATNR, 'Empty'), '->', ISNULL(Reg.New_MATNR, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Value, 0) <> ISNULL(Reg.New_Value, 0) THEN CONCAT('Price:', ISNULL(Reg.Old_Value, 0), '->', ISNULL(Reg.New_Value, 0), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Costo_Envio, 0) <> ISNULL(Reg.New_Costo_Envio, 0) THEN CONCAT('Route66:', ISNULL(Reg.Old_Costo_Envio, 0), '->', ISNULL(Reg.New_Costo_Envio, 0), '. ') ELSE '' END
            )
        FROM [T3].[PRICELIST_DETALLE_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END
    ELSE IF @sObjectName = 'MX_CFDI_PRODSERV_LOG'
    BEGIN
        SELECT
            @sReferenceKey =
                CASE
                    WHEN @sActionMode = 'Delete'
                        THEN CONCAT(Reg.Old_Modulo, '-', Reg.Old_Material)
                    ELSE CONCAT(Reg.New_Modulo, '-', Reg.New_Material)
                END,
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_Modulo, 'Empty') <> ISNULL(Reg.New_Modulo, 'Empty') THEN CONCAT('Module:', ISNULL(Reg.Old_Modulo, 'Empty'), '->', ISNULL(Reg.New_Modulo, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Material, 'Empty') <> ISNULL(Reg.New_Material, 'Empty') THEN CONCAT('SKU:', ISNULL(Reg.Old_Material, 'Empty'), '->', ISNULL(Reg.New_Material, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_NombreMaterial, 'Empty') <> ISNULL(Reg.New_NombreMaterial, 'Empty') THEN CONCAT('Name:', ISNULL(Reg.Old_NombreMaterial, 'Empty'), '->', ISNULL(Reg.New_NombreMaterial, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_UnidadMedida, 'Empty') <> ISNULL(Reg.New_UnidadMedida, 'Empty') THEN CONCAT('UoM:', ISNULL(Reg.Old_UnidadMedida, 'Empty'), '->', ISNULL(Reg.New_UnidadMedida, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_SAT_Clave, 'Empty') <> ISNULL(Reg.New_SAT_Clave, 'Empty') THEN CONCAT('SAT ID:', ISNULL(Reg.Old_SAT_Clave, 'Empty'), '->', ISNULL(Reg.New_SAT_Clave, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_SAT_UnidadMedida, 'Empty') <> ISNULL(Reg.New_SAT_UnidadMedida, 'Empty') THEN CONCAT('SAT UoM:', ISNULL(Reg.Old_SAT_UnidadMedida, 'Empty'), '->', ISNULL(Reg.New_SAT_UnidadMedida, 'Empty'), '. ') ELSE '' END
            )
        FROM [EAI_OWNER].[MX_CFDI_PRODSERV_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END
    ELSE IF @sObjectName = 'MX_HASHTABLE_LOG'
    BEGIN
        SELECT
            @sReferenceKey =
                CASE
                    WHEN @sActionMode = 'Delete'
                        THEN CONCAT(Reg.Old_Type, '-', Reg.Old_Source)
                    ELSE CONCAT(Reg.New_Type, '-', Reg.New_Source)
                END,
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_Type, 'Empty') <> ISNULL(Reg.New_Type, 'Empty') THEN CONCAT('Type:', ISNULL(Reg.Old_Type, 'Empty'), '->', ISNULL(Reg.New_Type, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Source, 'Empty') <> ISNULL(Reg.New_Source, 'Empty') THEN CONCAT('Source:', ISNULL(Reg.Old_Source, 'Empty'), '->', ISNULL(Reg.New_Source, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Target, 'Empty') <> ISNULL(Reg.New_Target, 'Empty') THEN CONCAT('Target:', ISNULL(Reg.Old_Target, 'Empty'), '->', ISNULL(Reg.New_Target, 'Empty'), '. ') ELSE '' END
            )
        FROM [EAI_OWNER].[MX_HASHTABLE_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END
    ELSE IF @sObjectName = 'MX_USOCFDI_CLIENTE_LOG'
    BEGIN
        SELECT
            @sReferenceKey =
                CASE
                    WHEN @sActionMode = 'Delete' THEN Reg.Old_Cliente
                    ELSE Reg.New_Cliente
                END,
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_Cliente, 'Empty') <> ISNULL(Reg.New_Cliente, 'Empty') THEN CONCAT('Customer:', ISNULL(Reg.Old_Cliente, 'Empty'), '->', ISNULL(Reg.New_Cliente, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Uso_Vta, 'Empty') <> ISNULL(Reg.New_Uso_Vta, 'Empty') THEN CONCAT('Sale Usage:', ISNULL(Reg.Old_Uso_Vta, 'Empty'), '->', ISNULL(Reg.New_Uso_Vta, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Uso_Dev, 'Empty') <> ISNULL(Reg.New_Uso_Dev, 'Empty') THEN CONCAT('Return Usage:', ISNULL(Reg.Old_Uso_Dev, 'Empty'), '->', ISNULL(Reg.New_Uso_Dev, 'Empty'), '. ') ELSE '' END
            )
        FROM [EAI_OWNER].[MX_USOCFDI_CLIENTE_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END
    ELSE IF @sObjectName = 'MX_CONDITION_HAWA_LOG'
    BEGIN
        SELECT
            @sReferenceKey =
                CASE
                    WHEN @sActionMode = 'Delete'
                        THEN CONCAT(Reg.Old_LP, '-', Reg.Old_SKU)
                    ELSE CONCAT(Reg.New_LP, '-', Reg.New_SKU)
                END,
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_LP, 'Empty') <> ISNULL(Reg.New_LP, 'Empty') THEN CONCAT('PriceList:', ISNULL(Reg.Old_LP, 'Empty'), '->', ISNULL(Reg.New_LP, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_SKU, 'Empty') <> ISNULL(Reg.New_SKU, 'Empty') THEN CONCAT('SKU:', ISNULL(Reg.Old_SKU, 'Empty'), '->', ISNULL(Reg.New_SKU, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Cond, 'Empty') <> ISNULL(Reg.New_Cond, 'Empty') THEN CONCAT('Condition:', ISNULL(Reg.Old_Cond, 'Empty'), '->', ISNULL(Reg.New_Cond, 'Empty'), '. ') ELSE '' END
            )
        FROM [EAI_OWNER].[MX_CONDITION_HAWA_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END
    ELSE IF @sObjectName = 'OTROS_DETALLE_LOG'
    BEGIN
        SELECT
            @sReferenceKey = CONCAT(Reg.Factura, '-', Reg.Num_Linea),
            @sReferenceUpdate = CONCAT(
                @sReferenceUpdate,
                CASE WHEN ISNULL(Reg.Old_Material, 'Empty') <> ISNULL(Reg.New_Material, 'Empty') THEN CONCAT('SKU:', ISNULL(Reg.Old_Material, 'Empty'), '->', ISNULL(Reg.New_Material, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_MaterialDescripcion, 'Empty') <> ISNULL(Reg.New_MaterialDescripcion, 'Empty') THEN CONCAT('Name:', ISNULL(Reg.Old_MaterialDescripcion, 'Empty'), '->', ISNULL(Reg.New_MaterialDescripcion, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_UnidadMedida, 'Empty') <> ISNULL(Reg.New_UnidadMedida, 'Empty') THEN CONCAT('UoM:', ISNULL(Reg.Old_UnidadMedida, 'Empty'), '->', ISNULL(Reg.New_UnidadMedida, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_SAT_ProdID, 'Empty') <> ISNULL(Reg.New_SAT_ProdID, 'Empty') THEN CONCAT('SAT ID:', ISNULL(Reg.Old_SAT_ProdID, 'Empty'), '->', ISNULL(Reg.New_SAT_ProdID, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_SAT_UM, 'Empty') <> ISNULL(Reg.New_SAT_UM, 'Empty') THEN CONCAT('SAT UoM:', ISNULL(Reg.Old_SAT_UM, 'Empty'), '->', ISNULL(Reg.New_SAT_UM, 'Empty'), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Cantidad, 0) <> ISNULL(Reg.New_Cantidad, 0) THEN CONCAT('Qty:', ISNULL(Reg.Old_Cantidad, 0), '->', ISNULL(Reg.New_Cantidad, 0), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_PrecioUnitario, 0) <> ISNULL(Reg.New_PrecioUnitario, 0) THEN CONCAT('Price:', ISNULL(Reg.Old_PrecioUnitario, 0), '->', ISNULL(Reg.New_PrecioUnitario, 0), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Valor_Subt, 0) <> ISNULL(Reg.New_Valor_Subt, 0) THEN CONCAT('Subt:', ISNULL(Reg.Old_Valor_Subt, 0), '->', ISNULL(Reg.New_Valor_Subt, 0), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Valor_IVA, 0) <> ISNULL(Reg.New_Valor_IVA, 0) THEN CONCAT('Tax:', ISNULL(Reg.Old_Valor_IVA, 0), '->', ISNULL(Reg.New_Valor_IVA, 0), '. ') ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Leyenda_EN, 'Empty') <> ISNULL(Reg.New_Leyenda_EN, 'Empty') THEN 'Text Leyend' ELSE '' END,
                CASE WHEN ISNULL(Reg.Old_Leyenda_ES, 'Empty') <> ISNULL(Reg.New_Leyenda_ES, 'Empty') THEN 'Text Leyend' ELSE '' END
            )
        FROM [T3].[OTROS_DETALLE_LOG] AS Reg
        WHERE Reg.TICKET_REFERENCIA = @sROWID;
    END;

    IF @sReturnType = 'PK'
        SET @sReturn = @sReferenceKey;
    ELSE
        SET @sReturn = @sReferenceUpdate;

    RETURN LEFT(ISNULL(@sReturn, ''), 2000);
END;
GO
