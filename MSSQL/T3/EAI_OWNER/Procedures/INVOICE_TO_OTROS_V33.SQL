CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_OTROS_V33
(
    @sInvoiceID VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sMsg        VARCHAR(500);
    DECLARE @sErrorCode  VARCHAR(500);
    DECLARE @v_ID        VARCHAR(30);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        /* =====================================================
           PRIORIDAD 1
           CFDI_PRODSERV_WA POR SOCIEDAD
        ===================================================== */

        UPDATE OD
        SET
            SAT_ProdID = SAT.SAT_Clave,
            SAT_UM     = SAT.SAT_UnidadMedida
        FROM T3.Otros_Detalle OD
        INNER JOIN T3.Otros_General OG
            ON OG.Factura = OD.Factura
        INNER JOIN T3.CFDI_PRODSERV_WA SAT
            ON SAT.Material = OD.Material
           AND SAT.Sociedad = OG.Sociedad
        WHERE OD.Factura = @sInvoiceID
          AND OD.SAT_ProdID IS NULL
          AND LEN(ISNULL(SAT.SAT_Clave,'')) > 4
          AND (
                 UPPER(OD.MaterialDescripcion)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.Leyenda_EN)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.Leyenda_ES)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.MaterialDescripcion)
                     = UPPER(ISNULL(SAT.NombreMaterial,
                                    OD.MaterialDescripcion))
              );

        /* =====================================================
           PRIORIDAD 2
           CFDI_PRODSERV_WA GENERAL
        ===================================================== */

        UPDATE OD
        SET
            SAT_ProdID = SAT.SAT_Clave,
            SAT_UM     = SAT.SAT_UnidadMedida
        FROM T3.Otros_Detalle OD
        INNER JOIN T3.Otros_General OG
            ON OG.Factura = OD.Factura
        INNER JOIN T3.CFDI_PRODSERV_WA SAT
            ON SAT.Material = OD.Material
        WHERE OD.Factura = @sInvoiceID
          AND SAT.Sociedad IS NULL
          AND OD.SAT_ProdID IS NULL
          AND LEN(ISNULL(SAT.SAT_Clave,'')) > 4
          AND (
                 UPPER(OD.MaterialDescripcion)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.Leyenda_EN)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.Leyenda_ES)
                     LIKE '%' + UPPER(ISNULL(SAT.NombreMaterial,'NULL')) + '%'
              OR UPPER(OD.MaterialDescripcion)
                     = UPPER(ISNULL(SAT.NombreMaterial,
                                    OD.MaterialDescripcion))
              );

        /* =====================================================
           PRIORIDAD 3
           CFDI_PRODSERV
        ===================================================== */

        UPDATE OD
        SET
            SAT_ProdID = SAT.SAT_Clave,
            SAT_UM     = SAT.SAT_UnidadMedida
        FROM T3.Otros_Detalle OD
        LEFT JOIN T3.CFDI_PRODSERV SAT
            ON SAT.Material = OD.Material
        WHERE OD.Factura = @sInvoiceID
          AND OD.SAT_ProdID IS NULL
          AND LEN(ISNULL(SAT.SAT_Clave,'')) > 4;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-' +
                ERROR_MESSAGE(),
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
            'Sending to T3 V33',
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