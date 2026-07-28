/*
    Procedure : EAI_OWNER.INVOICE_FIX_TAX
    Objetivo  : Corregir redondeos de IVA en detalles de preventa para las
                clases de factura autorizadas y recalcular el encabezado.
    Entrada   : @sInvoiceID es el folio de la factura/preventa.
    Integridad: El encabezado sólo se recalcula cuando al menos un detalle
                necesitó corrección; una división entre cero se registra como
                error en vez de ocultarse con un valor inventado.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_FIX_TAX
(
    @sInvoiceID VARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg NVARCHAR(500),
        @sErrorCode NVARCHAR(500),
        @v_ID VARCHAR(30),
        @nItems INT;

    SET @v_ID = @sInvoiceID;
    SET @nItems = 0;

    BEGIN TRY

        --------------------------------------------------
        -- Validar tipo de factura
        --------------------------------------------------

        IF EXISTS
        (
            SELECT 1
            FROM T3.Preventa_General
            WHERE Factura = @sInvoiceID
              AND Clase_Factura IN ('C020','C021','C022','C025')
        )
        BEGIN

            --------------------------------------------------
            -- Detectar registros incorrectos
            --------------------------------------------------

            -- Primero contamos diferencias para saber si es necesario tocar
            -- los acumulados del encabezado.
            SELECT
                @nItems = COUNT(*)
            FROM T3.Preventa_Detalle
            WHERE Factura = @sInvoiceID
              AND Valor_IVA <>
                    ROUND
                    (
                        Valor_Subt *
                        ROUND
                        (
                            Valor_IVA * 100.0 /
                            Valor_Subt,
                            0
                        )
                        /100.0,
                        2
                    );

            --------------------------------------------------
            -- Corrección masiva
            --------------------------------------------------

            -- La tasa se obtiene del propio detalle, se redondea al porcentaje
            -- entero y luego se vuelve a aplicar sobre el subtotal.
            UPDATE PD
               SET Valor_IVA =
                   ROUND
                   (
                       PD.Valor_Subt *
                       ROUND
                       (
                           PD.Valor_IVA * 100.0 /
                           PD.Valor_Subt,
                           0
                       )
                       /100.0,
                       2
                   )
            FROM T3.Preventa_Detalle PD
            WHERE PD.Factura = @sInvoiceID
              AND PD.Valor_IVA <>
                  ROUND
                  (
                      PD.Valor_Subt *
                      ROUND
                      (
                          PD.Valor_IVA * 100.0 /
                          PD.Valor_Subt,
                          0
                      )
                      /100.0,
                      2
                  );

            --------------------------------------------------
            -- Recalcular encabezado
            --------------------------------------------------

            IF @nItems > 0
            BEGIN

                UPDATE PG
                   SET Valor_Subt = X.Valor_Subt,
                       Valor_IVA  = X.Valor_IVA
                FROM T3.Preventa_General PG
                CROSS APPLY
                (
                    SELECT
                        SUM
                        (
                            COALESCE(PD.Valor_Subt,0)
                            +
                            COALESCE(PD.Envio_Subt,0)
                        ) AS Valor_Subt,

                        SUM
                        (
                            COALESCE(PD.Valor_IVA,0)
                            +
                            COALESCE(PD.Envio_IVA,0)
                        ) AS Valor_IVA
                    FROM T3.Preventa_Detalle PD
                    WHERE PD.Factura = PG.Factura
                ) X
                WHERE PG.Factura = @sInvoiceID;

            END
        END

    END TRY

    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT
            (
                CONCAT
                (
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
            'INVOICE_FIX_TAX',
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

        -- Oracle registra la incidencia y no propaga la excepción al caller.

    END CATCH
END
GO
