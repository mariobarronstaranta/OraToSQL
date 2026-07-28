/*
    Procedure : EAI_OWNER.INVOICE_TO_OTROS_RETENTION
    Objetivo  : Completar claves SAT y calcular la retención de IVA de una
                factura del flujo Otros.
    Entrada   : @sInvoiceID identifica la factura.
    Fuentes   : OTROS_PRODSERV_RETENTION aporta catálogo y tasas; GETCONV aporta
                la configuración del caso especial por sociedad y RFC.
    Integridad: El total del encabezado sólo se recalcula si al menos un detalle
                recibió retención, evitando sobrescribir importes existentes.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_OTROS_RETENTION
(
    @sInvoiceID VARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg          VARCHAR(500),
        @sErrorCode    VARCHAR(500),
        @v_ID          VARCHAR(30),
        @nItems        INT = 0,
        @nUpdated      INT = 0,
        @sRetCode      VARCHAR(30),
        @sRetDesc      VARCHAR(30),
        @sBillInfo     VARCHAR(50),
        @nRetRate      DECIMAL(6,2);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        -----------------------------------------------------------------
        -- Obtener Configuración
        -----------------------------------------------------------------

        SELECT
            @sRetCode =
                EAI_OWNER.GETCONV('CFG Settings','RetentionVAT-Code'),

            @sRetDesc =
                EAI_OWNER.GETCONV('CFG Settings','RetentionVAT-Description'),

            @nRetRate =
                CONVERT(
                    DECIMAL(6,2),
                    EAI_OWNER.GETCONV('CFG Settings','RetentionVAT-Rate')
                ),

            @sBillInfo =
                EAI_OWNER.GETCONV('CFG Settings','RetentionVAT-CompanyCode')
                + '-'
                + EAI_OWNER.GETCONV('CFG Settings','RetentionVAT-TaxID');

        -----------------------------------------------------------------
        -- Actualizar SAT
        -----------------------------------------------------------------

        -- Primera fase: enriquecer el producto con sus claves SAT. Esta fase no
        -- implica por sí sola que exista una retención monetaria.
        UPDATE OD
           SET
               SAT_ProdID = SAT.SAT_CLAVE,
               SAT_UM     = SAT.SAT_UNIDADMEDIDA
        FROM T3.Otros_Detalle OD
        INNER JOIN EAI_OWNER.OTROS_PRODSERV_RETENTION SAT
            ON SAT.MATERIAL = OD.Material
        WHERE OD.Factura = @sInvoiceID
          AND SAT.SAT_CLAVE IS NOT NULL;

        -----------------------------------------------------------------
        -- Retención por catálogo SAT
        -----------------------------------------------------------------

        -- Segunda fase: aplicar la tasa del catálogo cuando su descripción está
        -- contenida en la leyenda o descripción del detalle.
        UPDATE OD
           SET Retencion_IVA =
               ROUND(
                   OD.Valor_Subt *
                   COALESCE(SAT.RETENCION_TASA,0) / 100.0,
                   2
               )
        FROM T3.Otros_Detalle OD
        INNER JOIN EAI_OWNER.OTROS_PRODSERV_RETENTION SAT
            ON SAT.MATERIAL = OD.Material
        INNER JOIN T3.Otros_General OG
            ON OG.Factura = OD.Factura
        WHERE OD.Factura = @sInvoiceID
          AND CHARINDEX(
                UPPER(SAT.DESCRIPCION),
                UPPER(
                    COALESCE(
                        OD.Leyenda_ES,
                        COALESCE(
                            OD.Leyenda_EN,
                            OD.MaterialDescripcion
                        )
                    )
                )
              ) > 0;

        SET @nUpdated = @@ROWCOUNT;

        -----------------------------------------------------------------
        -- Retención especial configurable
        -----------------------------------------------------------------

        UPDATE OD
           SET Retencion_IVA =
               ROUND(
                   OD.Valor_Subt * @nRetRate / 100.0,
                   2
               )
        FROM T3.Otros_Detalle OD
        INNER JOIN T3.Otros_General OG
            ON OG.Factura = OD.Factura
        WHERE OD.Factura = @sInvoiceID
          AND OD.Material = @sRetCode
          AND CONCAT(OG.Sociedad,'-',OG.RFC) = @sBillInfo;

        SET @nUpdated += @@ROWCOUNT;

        -----------------------------------------------------------------
        -- Actualización única del encabezado
        -----------------------------------------------------------------

        -- Oracle recalcula el encabezado únicamente cuando al menos un detalle
        -- recibió retención; así no se sobrescribe un valor previo por accidente.
        IF @nUpdated > 0
        UPDATE OG
           SET Retencion_IVA =
               (
                    SELECT SUM(COALESCE(OD.Retencion_IVA,0))
                    FROM T3.Otros_Detalle OD
                    WHERE OD.Factura = @sInvoiceID
               )
        FROM T3.Otros_General OG
        WHERE OG.Factura = @sInvoiceID;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
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
            'Retention VAT',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'Invoice to T3',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END;
GO
