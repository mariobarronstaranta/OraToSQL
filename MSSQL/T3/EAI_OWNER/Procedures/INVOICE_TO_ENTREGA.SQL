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
        @sClienteV3 VARCHAR(30);

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
                dbo.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP) Cliente_V3
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
                dbo.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP)
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

            IF @Entrega IS NULL
            BEGIN

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

        MERGE EAI.IFC_Folios_FE AS T
        USING
        (
            SELECT
                Doc.ReferenceID AS Row_ID,
                Doc.ReferenciaBancaria AS Entrada,
                'INTERFACE' AS CreadoPor,
                GETDATE() AS Creacion,
                Doc.Order_Num AS Var_1
            FROM EAI_OWNER.tmp_Document_Header Doc
            WHERE Doc.ReferenceID = @sInvoiceID
              AND Doc.ReferenciaBancaria IS NOT NULL
              AND Doc.MetodoPago = 'Van Replenishment'
        ) S
        ON T.Var_1 = S.Var_1

        WHEN MATCHED THEN
            UPDATE SET
                Entrada = S.Entrada,
                Modificacion = GETDATE()

        WHEN NOT MATCHED THEN
            INSERT
            (
                Row_ID,
                Entrada,
                CreadoPor,
                Creacion,
                Var_1
            )
            VALUES
            (
                S.Row_ID,
                S.Entrada,
                S.CreadoPor,
                S.Creacion,
                S.Var_1
            );

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

        THROW;

    END CATCH

END;
GO