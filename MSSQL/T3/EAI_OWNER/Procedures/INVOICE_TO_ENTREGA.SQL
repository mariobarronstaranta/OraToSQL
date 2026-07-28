/*
    Procedure : EAI_OWNER.INVOICE_TO_ENTREGA
    Objetivo  : Crear la entrega y su complemento fiscal a partir de la
                preventa relacionada con el documento recibido.
    Entradas  : @sInvoiceID identifica el mensaje; @sBillingDoc permite una
                búsqueda alternativa; @nOutput habilita trazas de diagnóstico.
    Efectos   : Actualiza T3.Entrega, T3.RF_Complemento e IFC_Folios_FE.
    Compatibilidad: La bandera @sProcesar permanece activa después de encontrar
                    la primera entrega faltante, como ocurre en Oracle.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_ENTREGA
(
      @sInvoiceID  VARCHAR(30),
      @nOutput     INT = 0,
      @sBillingDoc VARCHAR(30) = 'NOBILL'
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
        @v_ID VARCHAR(30),
        @sFacturaV3 VARCHAR(30),
        @sClienteV3 VARCHAR(30),
        @sProcesar VARCHAR(2) = 'NO';

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        IF @nOutput > 0
        BEGIN
            INSERT INTO EAI_OWNER.Trace_EAI_OWNER
            (
                Created,
                Object_Type,
                Object_Reference,
                Description
            )
            VALUES
            (
                GETDATE(),
                'INVOICE_TO_ENTREGA',
                @v_ID,
                'Begin'
            );
        END;

        -- Se reproducen las dos rutas del cursor Oracle: por Order_Num del
        -- mensaje principal y por PedidoV3 del documento de facturación.
        ;WITH ScrEntrega AS
        (
            SELECT
                Doc.Cust_to_SAP,
                Doc.Order_Num,
                PG.Factura,
                Ent.Entrega,
                PG.Fecha_Proc_BATMD,
                PG.Fecha_Factura,
                CONVERT(date,LEFT(Head.Fecha_Vencimiento,8),112) Fecha_Pago,
                EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP) Cliente_V3
            FROM EAI_OWNER.tmp_Document_Header Doc
            INNER JOIN T3.Preventa_General PG
                ON Doc.Order_Num = PG.Referencia
            INNER JOIN EAI_OWNER.tmp_Document_Header Head
                ON PG.Entrega = Head.ReferenceID
            LEFT JOIN T3.Entrega Ent
                ON PG.Factura = Ent.Factura
            WHERE Doc.ReferenceID = @sInvoiceID

            UNION

            SELECT
                Doc.Cust_to_SAP,
                Doc.PedidoV3,
                PG.Factura,
                Ent.Entrega,
                PG.Fecha_Proc_BATMD,
                PG.Fecha_Factura,
                CONVERT(date,LEFT(Head.Fecha_Vencimiento,8),112),
                EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP)
            FROM EAI_OWNER.tmp_Document_Header Doc
            INNER JOIN T3.Preventa_General PG
                ON Doc.PedidoV3 = PG.Referencia
            INNER JOIN EAI_OWNER.tmp_Document_Header Head
                ON PG.Entrega = Head.ReferenceID
            LEFT JOIN T3.Entrega Ent
                ON PG.Factura = Ent.Factura
            WHERE Doc.ReferenceID = @sBillingDoc
        )

        SELECT *
        INTO #ScrEntrega
        FROM ScrEntrega;

        DECLARE curEntrega CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Factura,
            Cliente_V3,
            Entrega,
            Fecha_Pago,
            Fecha_Factura
        FROM #ScrEntrega;

        DECLARE
            @Factura VARCHAR(30),
            @ClienteV3 VARCHAR(30),
            @Entrega VARCHAR(30),
            @FechaPago DATE,
            @FechaFactura DATETIME;

        OPEN curEntrega;

        FETCH NEXT FROM curEntrega
        INTO
            @Factura,
            @ClienteV3,
            @Entrega,
            @FechaPago,
            @FechaFactura;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            IF @nOutput > 0
                INSERT INTO EAI_OWNER.Trace_EAI_OWNER
                    (Created, Object_Type, Object_Reference, Description)
                VALUES (GETDATE(), 'INVOICE_TO_ENTREGA', @v_ID, 'ScrEntrega');

            IF @Entrega IS NULL
                SET @sProcesar = 'SI';

            -- En Oracle la bandera permanece en SI después de la primera entrega
            -- faltante; se conserva ese comportamiento entre filas del cursor.
            IF @sProcesar = 'SI'
            BEGIN
                IF @nOutput > 0
                    INSERT INTO EAI_OWNER.Trace_EAI_OWNER
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES (GETDATE(), 'INVOICE_TO_ENTREGA', @Factura, 'Insert T3.Entrega');

                -- Se reemplazan los datos de la factura para que complemento y
                -- entrega queden sincronizados y no sobrevivan filas antiguas.
                DELETE FROM T3.RF_Complemento
                WHERE Factura = @Factura;

                DELETE FROM T3.Entrega
                WHERE Factura = @Factura;

                INSERT INTO T3.RF_Complemento
                (
                    Factura,
                    Hora_Factura,
                    Anio_Aprob,
                    Folio_Aprob,
                    Order_Num,
                    Rep_ID,
                    X_DelRep_Invloc,
                    Volumen,
                    Sociedad,
                    Cadena_Original,
                    Sello_Digital,
                    Dias_Pago
                )
                VALUES
                (
                    @Factura,
                    CONVERT(VARCHAR(8),GETDATE(),108),
                    'Error',
                    'Error',
                    '',
                    'U00000000',
                    '',
                    NULL,
                    'MX06',
                    'CFDI - Documento',
                    'CFDI - Documento',
                    DATEDIFF(DAY,@FechaFactura,@FechaPago)
                );

                INSERT INTO T3.Entrega
                (
                    Factura,
                    Entrega,
                    Fecha_Trn,
                    Status_Entrega,
                    Ubicacion,
                    Rep_ID,
                    Fecha_Entrega,
                    Cliente_V3,
                    Cliente_SAP
                )
                SELECT
                    PG.Factura,
                    PG.Entrega,
                    GETDATE(),
                    '1',
                    '0000',
                    'U00000000',
                    PG.Fecha_Factura,
                    @ClienteV3,
                    PG.Cliente_SAP
                FROM T3.Preventa_General PG
                WHERE PG.Factura = @Factura;
            END
            ELSE IF @nOutput > 0
                INSERT INTO EAI_OWNER.Trace_EAI_OWNER
                    (Created, Object_Type, Object_Reference, Description)
                VALUES (GETDATE(), 'INVOICE_TO_ENTREGA', @v_ID, 'Discarded');

            FETCH NEXT FROM curEntrega
            INTO
                @Factura,
                @ClienteV3,
                @Entrega,
                @FechaPago,
                @FechaFactura;
        END

        CLOSE curEntrega;
        DEALLOCATE curEntrega;

        -- Oracle decide INSERT/UPDATE mediante NVL(FE.CreadoPor,'INSERT').
        -- Se separan ambas operaciones para conservar también el caso NULL.
        UPDATE FE
           SET Entrada = Doc.ReferenciaBancaria,
               Modificacion = GETDATE()
        FROM EAI.IFC_Folios_FE FE
        INNER JOIN EAI_OWNER.tmp_Document_Header Doc
          ON Doc.Order_Num = FE.Var_1
        WHERE Doc.ReferenceID = @sInvoiceID
          AND Doc.ReferenciaBancaria IS NOT NULL
          AND Doc.MetodoPago = 'Van Replenishment'
          AND FE.CreadoPor IS NOT NULL;

        INSERT INTO EAI.IFC_Folios_FE (Row_ID, Entrada, CreadoPor, Creacion, Var_1)
        SELECT Doc.ReferenceID, Doc.ReferenciaBancaria, 'INTERFACE', GETDATE(), Doc.Order_Num
        FROM EAI_OWNER.tmp_Document_Header Doc
        LEFT JOIN EAI.IFC_Folios_FE FE ON FE.Var_1 = Doc.Order_Num
        WHERE Doc.ReferenceID = @sInvoiceID
          AND Doc.ReferenciaBancaria IS NOT NULL
          AND Doc.MetodoPago = 'Van Replenishment'
          AND FE.CreadoPor IS NULL;

        IF @nOutput > 0
        BEGIN
            INSERT INTO EAI_OWNER.Trace_EAI_OWNER
            (
                Created,
                Object_Type,
                Object_Reference,
                Description
            )
            VALUES
            (
                GETDATE(),
                'INVOICE_TO_ENTREGA',
                @v_ID,
                'End'
            );
        END

    END TRY

    BEGIN CATCH

        IF CURSOR_STATUS('local', 'curEntrega') >= 0 CLOSE curEntrega;
        IF CURSOR_STATUS('local', 'curEntrega') > -3 DEALLOCATE curEntrega;

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
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Sending to T3',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'Delivery to T3',
            LEFT(ERROR_MESSAGE(),250),
            'XML',
            CONCAT('SQL-',ERROR_NUMBER())
        );

        -- Oracle registra el error y no lo propaga al caller.

    END CATCH

END;
GO
