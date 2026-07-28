/*
    Procedure : EAI_OWNER.SF_GET_CREDIT_DATA
    Objetivo  : Localizar una nota de crédito en ventas o preventas y devolver
                documento, cliente, importe total, saldo pendiente y pagado.
    Salidas   : Todos los parámetros OUTPUT se asignan también en error para no
                devolver valores anteriores proporcionados por el caller.
*/
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

        -- Oracle copia la referencia a v_ID VARCHAR2(30); una referencia mayor
        -- es inválida. Se rechaza explícitamente para que SQL Server no la
        -- trunque y termine consultando un documento diferente.
        IF LEN(@pInvoiceRef) > 30
            THROW 50020, 'La referencia de factura excede 30 caracteres.', 1;

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

        -- Ajuste conocido de diferencias de IVA calculado por la función del
        -- esquema EAI_OWNER.
        SET @nTaxIssue = COALESCE(EAI_OWNER.FN_GET_TAX_ISSUE(@pInvoiceRef),0);

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
