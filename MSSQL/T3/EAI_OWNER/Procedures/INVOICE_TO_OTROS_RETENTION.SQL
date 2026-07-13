CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_OTROS_RETENTION
(
    @sInvoiceID VARCHAR(50)
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
                dbo.getConv('CFG Settings','RetentionVAT-Code'),

            @sRetDesc =
                dbo.getConv('CFG Settings','RetentionVAT-Description'),

            @nRetRate =
                TRY_CONVERT(
                    DECIMAL(6,2),
                    dbo.getConv('CFG Settings','RetentionVAT-Rate')
                ),

            @sBillInfo =
                dbo.getConv('CFG Settings','RetentionVAT-CompanyCode')
                + '-'
                + dbo.getConv('CFG Settings','RetentionVAT-TaxID');

        -----------------------------------------------------------------
        -- Actualizar SAT
        -----------------------------------------------------------------

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

        -----------------------------------------------------------------
        -- Actualización única del encabezado
        -----------------------------------------------------------------

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

        THROW;
    END CATCH
END;
GO