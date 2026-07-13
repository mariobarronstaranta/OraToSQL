CREATE OR ALTER PROCEDURE EAI_OWNER.SF_GET_INVOICE_DATA
(
      @pInvoiceRef      VARCHAR(500),
      @rtDoc_Num        VARCHAR(50) OUTPUT,
      @rtCliente_SAP    VARCHAR(50) OUTPUT,
      @rtAmount         DECIMAL(18,3) OUTPUT,
      @rtPending        DECIMAL(18,3) OUTPUT,
      @rtPaid           DECIMAL(18,3) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @v_ID                VARCHAR(30)
        , @sDoc_Num            VARCHAR(50)
        , @sCliente_SAP        VARCHAR(50)
        , @nAmount             DECIMAL(18,3)
        , @nPending            DECIMAL(18,3)
        , @nPaid               DECIMAL(18,3)
        , @sDocType            VARCHAR(30)
        , @dtFecha_Proc_BATMD  DATETIME
        , @dtFechaCancelacion  DATETIME
        , @nSAT_Amount         DECIMAL(18,3)
        , @sRFC                VARCHAR(30)
        , @nReq_SAT_Amt        INT
        , @sMsg                VARCHAR(250)
        , @sErrorCode          VARCHAR(50);

    BEGIN TRY

        SELECT
            @v_ID = @pInvoiceRef,
            @sDoc_Num = NULL,
            @sCliente_SAP = NULL,
            @nAmount = 0,
            @nPending = 0,
            @nPaid = 0,
            @sDocType = 'None',
            @sRFC = '',
            @nSAT_Amount = 0,
            @nReq_SAT_Amt = 0;

        ---------------------------------------------------
        -- PROMPT SALES
        ---------------------------------------------------

        ;WITH PromptData AS
        (
            SELECT TOP(1)
                   FG.Factura,
                   FG.Cliente_SAP,
                   FG.Fecha_Proc_BATMD,
                   MC.RFC,
                   COALESCE(CFD.Valor_Subt,0)
                 + COALESCE(CFD.Valor_IVA,0) AS Importe_SAT
            FROM T3.Factura_General FG
            INNER JOIN T3.Tipo_Documento TD
                ON FG.Tipo_Docto = TD.Tipo_Documento
            INNER JOIN T3.Mov_Cliente MC
                ON FG.Cliente_SAP = MC.Cliente_SAP
            LEFT JOIN T3.CFDI_Documentos CFD
                ON FG.Factura = CFD.Nota_Venta
            WHERE FG.Factura = @pInvoiceRef
              AND TD.Cargo_Credito = 1
              AND TD.Comercial = 1

            UNION

            SELECT TOP(1)
                   FG.Factura,
                   FG.Cliente_SAP,
                   FG.Fecha_Factura,
                   MC.RFC,
                   COALESCE(CFD.Valor_Subt,0)
                 + COALESCE(CFD.Valor_IVA,0)
            FROM T3.Registro_Fiscal FG
            INNER JOIN T3.Tipo_Documento TD
                ON FG.Tipo_Docto = TD.Tipo_Documento
            INNER JOIN T3.Mov_Cliente MC
                ON FG.Cliente_SAP = MC.Cliente_SAP
            LEFT JOIN T3.CFDI_Documentos CFD
                ON FG.Factura = CFD.Nota_Venta
            WHERE FG.Entrega = @pInvoiceRef
              AND FG.Tipo_Docto = 'C003'
              AND TD.Cargo_Credito = 1
              AND TD.Comercial = 1
        )
        SELECT TOP(1)
               @sDocType='Prompt',
               @sDoc_Num=Factura,
               @sCliente_SAP=Cliente_SAP,
               @dtFecha_Proc_BATMD=Fecha_Proc_BATMD,
               @sRFC=RFC,
               @nSAT_Amount=Importe_SAT
        FROM PromptData;

        ---------------------------------------------------
        -- PRESALES
        ---------------------------------------------------

        IF @sDocType='None'
        BEGIN

            SELECT TOP(1)
                   @sDocType='Presales',
                   @sDoc_Num=FG.Factura,
                   @sCliente_SAP=FG.Cliente_SAP,
                   @dtFecha_Proc_BATMD=FG.Fecha_Proc_BATMD,
                   @dtFechaCancelacion=FG.Fecha_Cancelacion,
                   @sRFC=MC.RFC,
                   @nSAT_Amount=
                        COALESCE(CFD.Valor_Subt,0)
                      + COALESCE(CFD.Valor_IVA,0)
            FROM T3.Preventa_General FG
            INNER JOIN T3.Tipo_Documento TD
                ON FG.Clase_Factura = TD.Tipo_Documento
            INNER JOIN T3.Mov_Cliente MC
                ON FG.Cliente_SAP = MC.Cliente_SAP
            LEFT JOIN T3.CFDI_Documentos CFD
                ON FG.Factura = CFD.Nota_Venta
            WHERE
                (
                    FG.Factura=@pInvoiceRef
                    OR FG.Entrega=@pInvoiceRef
                    OR FG.Referencia=@pInvoiceRef
                )
                AND TD.Cargo_Credito=1
                AND TD.Comercial=1;

        END

        ---------------------------------------------------
        -- CANCELACION DE PAGO
        ---------------------------------------------------

        IF @sDocType='None'
        BEGIN

            SELECT TOP(1)
                   @sDocType='CancPago',
                   @sDoc_Num=Debit_Note,
                   @sCliente_SAP=Cust_to_SAP,
                   @dtFecha_Proc_BATMD=DATEADD(DAY,-1,GETDATE()),
                   @nAmount=Total_Amt
            FROM T3.DEBIT_NOTE_IFC
            WHERE Debit_Note=@pInvoiceRef;

        END

        ---------------------------------------------------
        -- IMPORTE
        ---------------------------------------------------

        IF @sDocType='Prompt'
        BEGIN

            SELECT
                @nAmount =
                COALESCE(SUM(
                    COALESCE(Valor_Subt,0)
                  + COALESCE(Valor_IVA,0)
                  + COALESCE(Envio_Subt,0)
                  + COALESCE(Envio_IVA,0)
                  + COALESCE(Credito_Subt,0)
                  + COALESCE(Credito_IVA,0)
                ),0)
            FROM T3.Factura_Detalle
            WHERE Factura=@sDoc_Num;

        END
        ELSE IF @sDocType='Presales'
        BEGIN

            SELECT
                @nAmount =
                COALESCE(SUM(
                    COALESCE(Valor_Subt,0)
                  + COALESCE(Valor_IVA,0)
                  + COALESCE(Envio_Subt,0)
                  + COALESCE(Envio_IVA,0)
                  + COALESCE(Credito_Subt,0)
                  + COALESCE(Credito_IVA,0)
                ),0)
            FROM T3.Preventa_Detalle
            WHERE Factura=@sDoc_Num;

        END

        ---------------------------------------------------
        -- REGLA SAT
        ---------------------------------------------------

        IF LEN(@sRFC) > 0
           AND @sRFC <> 'XAXX010101000'
        BEGIN

            SELECT
                @nReq_SAT_Amt =
                MAX(CAST(COALESCE(Target,'0') AS INT))
            FROM EAI_OWNER.MX_HashTable
            WHERE Type='SAT Amount Invoice'
              AND Source=@sRFC;

            IF COALESCE(@nReq_SAT_Amt,0) > 1
               AND @nSAT_Amount > 0
            BEGIN
                SET @nAmount = @nSAT_Amount;
            END
        END

        ---------------------------------------------------
        -- PAGOS
        ---------------------------------------------------

        IF @nAmount > 0
        BEGIN

            SELECT
                @nPaid =
                COALESCE(SUM(Importe),0)
            FROM T3.CFDI_Cobranza
            WHERE Factura=@sDoc_Num;

            SET @nPending = @nAmount - @nPaid;

        END

        SELECT
              @rtDoc_Num     = @sDoc_Num
            , @rtCliente_SAP = @sCliente_SAP
            , @rtAmount      = @nAmount
            , @rtPending     = @nPending
            , @rtPaid        = COALESCE(@nPaid,0);

    END TRY

    BEGIN CATCH

        SET @rtDoc_Num     = NULL;
        SET @rtCliente_SAP = NULL;
        SET @rtAmount      = 0;
        SET @rtPending     = 0;
        SET @rtPaid        = 0;

        SET @sErrorCode = CONCAT('SQL-',ERROR_NUMBER());

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
            'Getting Info',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'GET_INVOICE_DATA',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

    END CATCH
END
GO