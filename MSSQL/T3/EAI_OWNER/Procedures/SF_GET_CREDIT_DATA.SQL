CREATE OR ALTER PROCEDURE EAI_OWNER.SF_GET_CREDIT_DATA
(
      @pInvoiceRef      VARCHAR(500)
    , @rtDoc_Num        VARCHAR(50) OUTPUT
    , @rtCliente_SAP    VARCHAR(50) OUTPUT
    , @rtAmount         DECIMAL(18,3) OUTPUT
    , @rtPending        DECIMAL(18,3) OUTPUT
    , @rtPaid           DECIMAL(18,3) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @v_ID                 VARCHAR(30)
        , @sDoc_Num             VARCHAR(50)
        , @sCliente_SAP         VARCHAR(50)
        , @nAmount              DECIMAL(18,3)
        , @nPending             DECIMAL(18,3)
        , @nPaid                DECIMAL(18,3)
        , @nTaxIssue            DECIMAL(18,2)
        , @sDocType             VARCHAR(30)
        , @dtFecha_Proc_BATMD   DATETIME
        , @dtFechaCancelacion   DATETIME;

    SELECT
          @v_ID = @pInvoiceRef
        , @nAmount = 0
        , @nPending = 0
        , @nPaid = 0
        , @sDocType = 'None';

    BEGIN TRY

        ------------------------------------------------------------------
        -- PROMPT SALES
        ------------------------------------------------------------------

        SELECT TOP(1)
              @sDoc_Num           = X.Factura
            , @sCliente_SAP       = X.Cliente_SAP
            , @dtFecha_Proc_BATMD = X.Fecha_Proc_BATMD
            , @sDocType           = 'Prompt'
        FROM
        (
            SELECT
                  FG.Factura
                , FG.Cliente_SAP
                , FG.Fecha_Proc_BATMD
            FROM T3.Factura_General FG
            INNER JOIN T3.Tipo_Documento TD
                ON TD.Tipo_Documento = FG.Tipo_Docto
            WHERE FG.Factura = @pInvoiceRef
              AND TD.Cargo_Credito <> 1
              AND TD.Comercial = 1

            UNION

            SELECT
                  FG.Factura
                , FG.Cliente_SAP
                , FG.Fecha_Factura
            FROM T3.Registro_Fiscal FG
            INNER JOIN T3.Tipo_Documento TD
                ON TD.Tipo_Documento = FG.Tipo_Docto
            WHERE FG.Entrega = @pInvoiceRef
              AND FG.Tipo_Docto = 'C004'
              AND TD.Cargo_Credito <> 1
              AND TD.Comercial = 1
        ) X;

        ------------------------------------------------------------------
        -- PRESALES
        ------------------------------------------------------------------

        IF @sDocType = 'None'
        BEGIN
            SELECT TOP(1)
                  @sDoc_Num = X.Factura
                , @sCliente_SAP = X.Cliente_SAP
                , @dtFecha_Proc_BATMD = X.Fecha_Proc_BATMD
                , @dtFechaCancelacion = X.Fecha_Cancelacion
                , @sDocType = 'Presales'
            FROM
            (
                SELECT
                      FG.Factura
                    , FG.Cliente_SAP
                    , FG.Fecha_Proc_BATMD
                    , FG.Fecha_Cancelacion
                FROM T3.Preventa_General FG
                INNER JOIN T3.Tipo_Documento TD
                    ON TD.Tipo_Documento = FG.Clase_Factura
                WHERE FG.Factura = @pInvoiceRef
                  AND TD.Cargo_Credito <> 1
                  AND TD.Comercial = 1

                UNION

                SELECT
                      FG.Factura
                    , FG.Cliente_SAP
                    , FG.Fecha_Proc_BATMD
                    , FG.Fecha_Cancelacion
                FROM T3.Preventa_General FG
                INNER JOIN T3.Tipo_Documento TD
                    ON TD.Tipo_Documento = FG.Clase_Factura
                WHERE FG.Entrega = @pInvoiceRef
                  AND TD.Cargo_Credito <> 1
                  AND TD.Comercial = 1

                UNION

                SELECT
                      FG.Factura
                    , FG.Cliente_SAP
                    , FG.Fecha_Proc_BATMD
                    , FG.Fecha_Cancelacion
                FROM T3.Preventa_General FG
                INNER JOIN T3.Tipo_Documento TD
                    ON TD.Tipo_Documento = FG.Clase_Factura
                WHERE FG.Referencia = @pInvoiceRef
                  AND TD.Cargo_Credito <> 1
                  AND TD.Comercial = 1
            ) X;
        END

        ------------------------------------------------------------------
        -- IMPORTE
        ------------------------------------------------------------------

        IF @sDocType = 'Prompt'
        BEGIN
            SELECT
                @nAmount =
                COALESCE(
                    SUM(
                        COALESCE(Valor_Subt,0)
                      + COALESCE(Valor_IVA,0)
                      + COALESCE(Envio_Subt,0)
                      + COALESCE(Envio_IVA,0)
                    ),0)
            FROM T3.Factura_Detalle
            WHERE Factura = @sDoc_Num;
        END
        ELSE IF @sDocType = 'Presales'
        BEGIN
            SELECT
                @nAmount =
                COALESCE(
                    SUM(
                        COALESCE(Valor_Subt,0)
                      + COALESCE(Valor_IVA,0)
                      + COALESCE(Envio_Subt,0)
                      + COALESCE(Envio_IVA,0)
                    ),0)
            FROM T3.Preventa_Detalle
            WHERE Factura = @sDoc_Num;
        END

        ------------------------------------------------------------------
        -- AJUSTE IVA
        ------------------------------------------------------------------

        SET @nTaxIssue = COALESCE(dbo.FN_GET_TAX_ISSUE(@pInvoiceRef),0);

        SET @nAmount += @nTaxIssue;

        ------------------------------------------------------------------
        -- COBRANZA
        ------------------------------------------------------------------

        IF @nAmount > 0
        BEGIN
            SELECT
                @nPaid = COALESCE(SUM(Importe),0)
            FROM T3.CFDI_Cobranza
            WHERE Nota_Credito = @sDoc_Num;

            SET @nPending = @nAmount - @nPaid;
        END

        ------------------------------------------------------------------
        -- OUTPUT
        ------------------------------------------------------------------

        SELECT
              @rtDoc_Num = @sDoc_Num
            , @rtCliente_SAP = @sCliente_SAP
            , @rtAmount = @nAmount
            , @rtPending = @nPending
            , @rtPaid = @nPaid;

    END TRY
    BEGIN CATCH

        SELECT
              @rtDoc_Num = NULL
            , @rtCliente_SAP = NULL
            , @rtAmount = 0
            , @rtPending = 0
            , @rtPaid = 0;

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
            'Getting Info',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'GET_CREDIT_DATA',
            LEFT(ERROR_MESSAGE(),250),
            'XML',
            CONCAT('SQL-',ERROR_NUMBER()),
            NULL,
            NULL,
            NULL
        );

    END CATCH
END;
GO