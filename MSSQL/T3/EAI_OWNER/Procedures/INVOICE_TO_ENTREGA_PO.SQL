/*
    Procedure : EAI_OWNER.INVOICE_TO_ENTREGA_PO
    Objetivo  : Asociar el pedido bancario recibido con el folio de interfaz.
    Entrada   : @sInvoiceID identifica el documento; @nOutput habilita trazas.
    Reglas    : Se excluyen referencias iguales al pedido y prefijos OV/OD.
                CreadoPor determina si corresponde UPDATE o INSERT, tal como
                lo hace NVL(FE.CreadoPor,'INSERT') en Oracle.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_ENTREGA_PO
(
      @sInvoiceID VARCHAR(30),
      @nOutput    INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @v_ID VARCHAR(30);
    DECLARE @sMsg VARCHAR(500);
    DECLARE @sErrorCode VARCHAR(500);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        -------------------------------------------------------------------
        -- TRACE BEGIN
        -------------------------------------------------------------------

        IF @nOutput > 0
        BEGIN
            INSERT INTO EAI_Owner.Trace_EAI_Owner
            (
                Created,
                Object_Type,
                Object_Reference,
                Description
            )
            VALUES
            (
                GETDATE(),
                'INVOICE_TO_ENTREGA_PO',
                @v_ID,
                'Begin'
            );
        END

        -------------------------------------------------------------------
        -- UPDATE EXISTENTES
        -------------------------------------------------------------------

        -- Filas con CreadoPor informado ya existen y sólo actualizan el pedido.
        UPDATE FE
           SET FE.Pedido       = DOC.ReferenciaBancaria,
               FE.Modificacion = GETDATE()
        FROM EAI.IFC_Folios_FE FE
        INNER JOIN EAI_Owner.tmp_Document_Header DOC
            ON DOC.PedidoV3 = FE.Var_1
        WHERE DOC.ReferenceID = @sInvoiceID
          AND DOC.ReferenciaBancaria IS NOT NULL
          AND DOC.ReferenciaBancaria <> DOC.PedidoV3
          AND DOC.ReferenciaBancaria NOT LIKE 'OV%'
          AND DOC.ReferenciaBancaria NOT LIKE 'OD%'
          -- Oracle usa NVL(FE.CreadoPor,'INSERT') para decidir la operación.
          AND FE.CreadoPor IS NOT NULL;

        IF @@ROWCOUNT > 0
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO EAI_Owner.Trace_EAI_Owner
                (
                    Created,
                    Object_Type,
                    Object_Reference,
                    Description
                )
                VALUES
                (
                    GETDATE(),
                    'INVOICE_TO_ENTREGA_PO',
                    @v_ID,
                    'Already inserted'
                );
            END
        END

        -------------------------------------------------------------------
        -- INSERT NUEVOS
        -------------------------------------------------------------------

        -- Una coincidencia sin CreadoPor se considera INSERT por compatibilidad
        -- con Oracle; si existe una restricción duplicada, el error se registra.
        INSERT INTO EAI.IFC_Folios_FE
        (
            Row_ID,
            Pedido,
            CreadoPor,
            Creacion,
            Var_1
        )
        SELECT
            DOC.ReferenceID,
            DOC.ReferenciaBancaria,
            'INTERFACE',
            GETDATE(),
            DOC.PedidoV3
        FROM EAI_Owner.tmp_Document_Header DOC
        LEFT JOIN EAI.IFC_Folios_FE FE
               ON FE.Var_1 = DOC.PedidoV3
        WHERE DOC.ReferenceID = @sInvoiceID
          AND DOC.ReferenciaBancaria IS NOT NULL
          AND DOC.ReferenciaBancaria <> DOC.PedidoV3
          AND DOC.ReferenciaBancaria NOT LIKE 'OV%'
          AND DOC.ReferenciaBancaria NOT LIKE 'OD%'
          AND FE.CreadoPor IS NULL;

        IF @@ROWCOUNT > 0
        BEGIN
            IF @nOutput > 0
            BEGIN
                INSERT INTO EAI_Owner.Trace_EAI_Owner
                (
                    Created,
                    Object_Type,
                    Object_Reference,
                    Description
                )
                VALUES
                (
                    GETDATE(),
                    'INVOICE_TO_ENTREGA_PO',
                    @v_ID,
                    'Insert EAI.IFC_Folios_FE'
                );
            END
        END

        -------------------------------------------------------------------
        -- TRACE END
        -------------------------------------------------------------------

        IF @nOutput > 0
        BEGIN
            INSERT INTO EAI_Owner.Trace_EAI_Owner
            (
                Created,
                Object_Type,
                Object_Reference,
                Description
            )
            VALUES
            (
                GETDATE(),
                'INVOICE_TO_ENTREGA_PO',
                @v_ID,
                'End'
            );
        END

    END TRY

    BEGIN CATCH

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT(
                CAST(ERROR_NUMBER() AS VARCHAR(20))
                + '-'
                + ERROR_MESSAGE(),
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
            'Sending to T3',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'Delivery to T3',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Se conserva el contrato Oracle: registrar el error y finalizar.

    END CATCH

END
GO
