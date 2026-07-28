/*
    Procedure : EAI_OWNER.INVOICE_TO_OTROS
    Objetivo  : Migrar facturas que no siguen el flujo estándar hacia las tablas
                T3.Otros_General, Otros_Detalle y Otros_Condiciones.
    Entrada   : @sInvoiceID identifica el documento temporal.
    Reglas    : Excluye ZI02, ZI04 e IVS; aplica datos fiscales CCE cuando la
                referencia bancaria lo indica y ejecuta homologación SAT al final.
    Errores   : Se usa autocommit para conservar el límite transaccional de Oracle;
                el error se registra y no se propaga al integrador.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_OTROS
(
    @sInvoiceID VARCHAR(30)
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE
        @sMsg NVARCHAR(500),
        @sErrorCode NVARCHAR(100),
        @v_ID VARCHAR(30),
        @sProcesar VARCHAR(2),
        @sFacturaV3 VARCHAR(20),
        @sHora_Factura VARCHAR(10),
        @sMetodoDePago VARCHAR(60),
        @sNumCtaPago VARCHAR(60);

    SET @v_ID = @sInvoiceID;

    BEGIN TRY

        -- El cursor mantiene el procesamiento documento por documento de Oracle
        -- y permite aplicar reglas fiscales particulares a cada encabezado.
        DECLARE curGeneral CURSOR LOCAL FAST_FORWARD FOR

        SELECT
              Head.FacturaSAP,
              Head.ReferenceID,
              Head.PedidoSAP,
              Head.CompanyCode,
              Head.DeliveryType,

              CASE
                   WHEN Head.RFC IS NULL THEN
                        CASE
                             WHEN Head.Pais IN ('MX','MEXICO')
                                  THEN 'XAXX010101000'
                             ELSE 'XEXX010101000'
                        END
                   ELSE Head.RFC
              END RFC,

              Head.NIF,
              Head.Moneda,
              Head.Tipo_Cambio,
              Head.CondicionPago,
              Head.Valor_Subt,
              Head.Valor_IVA,

              CONVERT
              (
                   DATE,
                   LEFT(Head.DocumentDate,8),
                   112
              ) AS FechaFactura,

              GETDATE(),

              Head.Cust_to_SAP,
              Head.Bill_to_SAP,
              Head.NombreCliente,
              Head.Direccion,
              Head.Colonia,
              Head.Ciudad,
              Head.Estado,

              EAI_OWNER.GETCONV('ECC_T3 Country',Head.Pais),

              Head.CodigoPostal,

              COALESCE(Head.MetodoPago,'No identificado'),
              COALESCE(Head.ReferenciaBancaria,'No identificado'),

              Head.Observaciones,

              CASE
                   WHEN Head.Pais IN ('MX','MEXICO')
                        THEN ''
                   ELSE Head.Incoterms
              END,

              SUBSTRING(Head.DocumentDate,10,2) + ':' +
              SUBSTRING(Head.DocumentDate,12,2) + ':' +
              SUBSTRING(Head.DocumentDate,14,2),

              CONVERT(VARCHAR(8),GETDATE(),108)

        FROM EAI_OWNER.Tmp_Document_Header Head
        WHERE Head.ReferenceID = @sInvoiceID
        AND ISNULL(Head.DeliveryType,'NULO')
            NOT IN ('ZI02','ZI04','IVS');

        DECLARE
            @Factura VARCHAR(20),
            @ReferenceID VARCHAR(50),
            @PedidoSAP VARCHAR(50),
            @Sociedad VARCHAR(10),
            @ClaseFactura VARCHAR(20),
            @RFC VARCHAR(20),
            @NIF VARCHAR(50),
            @Moneda VARCHAR(10),
            @TipoCambio DECIMAL(18,6),
            @CondicionPago INT,
            @ValorSubt DECIMAL(22,7),
            @ValorIVA DECIMAL(22,7),
            @FechaFactura DATE,
            @FechaTRN DATETIME,
            @ClienteSAP VARCHAR(30),
            @ClteFacturaSAP VARCHAR(30),
            @Nombre VARCHAR(200),
            @Direccion VARCHAR(500),
            @Colonia VARCHAR(200),
            @Ciudad VARCHAR(200),
            @Estado VARCHAR(200),
            @Pais VARCHAR(100),
            @CodigoPostal VARCHAR(20),
            @MetodoPago VARCHAR(60),
            @ReferenciaBancaria VARCHAR(60),
            @Observaciones VARCHAR(500),
            @Incoterms VARCHAR(50),
            @HoraFactura VARCHAR(10),
            @HoraDefault VARCHAR(10);

        OPEN curGeneral;

        FETCH NEXT FROM curGeneral INTO
            @Factura,@ReferenceID,@PedidoSAP,@Sociedad,
            @ClaseFactura,@RFC,@NIF,@Moneda,@TipoCambio,
            @CondicionPago,@ValorSubt,@ValorIVA,
            @FechaFactura,@FechaTRN,@ClienteSAP,
            @ClteFacturaSAP,@Nombre,@Direccion,
            @Colonia,@Ciudad,@Estado,@Pais,
            @CodigoPostal,@MetodoPago,@ReferenciaBancaria,
            @Observaciones,@Incoterms,@HoraFactura,@HoraDefault;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @sFacturaV3 = @Factura;
            -- Una asignación SELECT sin filas conserva el valor anterior en
            -- SQL Server. Se reinicia para imitar el cursor ScrValida de Oracle.
            SET @sProcesar = NULL;

            SELECT
                @sProcesar =
                    CASE
                        WHEN Fecha_Proc_BATMD IS NULL
                            THEN 'SI'
                        ELSE 'NO'
                    END
            FROM T3.Otros_General
            WHERE Factura = @sFacturaV3;

            IF @sProcesar IS NULL
                SET @sProcesar = 'SI';

            IF @sProcesar = 'SI'
            BEGIN

                -- Se reconstruye el documento completo para evitar combinar la
                -- versión nueva con detalles o condiciones de una carga anterior.
                DELETE T3.Otros_General
                WHERE Factura=@sFacturaV3;

                DELETE T3.Otros_Detalle
                WHERE Factura=@sFacturaV3;

                DELETE T3.Otros_Condiciones
                WHERE Factura=@sFacturaV3;

                DELETE T3.RF_Complemento
                WHERE Factura=@sFacturaV3;

                SET @sHora_Factura =
                    CASE
                        WHEN @HoraFactura='::'
                            THEN @HoraDefault
                        ELSE @HoraFactura
                    END;

                INSERT INTO T3.RF_Complemento
                (
                    Factura,
                    Hora_Factura,
                    Sociedad,
                    Dias_Pago
                )
                VALUES
                (
                    @Factura,
                    @sHora_Factura,
                    @Sociedad,
                    @CondicionPago
                );

                INSERT INTO T3.Otros_General
                (
                    Factura,
                    FacturaSAP,
                    PedidoSAP,
                    Sociedad,
                    Clase_Factura,
                    Cliente_SAP,
                    Clte_Factura_SAP,
                    NIF,
                    RFC,
                    Moneda,
                    TipoCambio,
                    CondicionPago,
                    Valor_Subt,
                    Valor_IVA,
                    Fecha_Factura,
                    Fecha_TRN,
                    Nombre,
                    Direccion,
                    Colonia,
                    Ciudad,
                    Estado,
                    Pais,
                    Incoterms,
                    CodigoPostal,
                    MetodoPago,
                    ReferenciaBancaria,
                    Observaciones
                )
                VALUES
                (
                    @Factura,
                    @ReferenceID,
                    @PedidoSAP,
                    @Sociedad,
                    @ClaseFactura,
                    @ClienteSAP,
                    @ClteFacturaSAP,
                    @NIF,
                    @RFC,
                    @Moneda,
                    @TipoCambio,
                    @CondicionPago,
                    @ValorSubt,
                    @ValorIVA,
                    @FechaFactura,
                    @FechaTRN,
                    @Nombre,
                    @Direccion,
                    @Colonia,
                    @Ciudad,
                    @Estado,
                    @Pais,
                    @Incoterms,
                    @CodigoPostal,
                    @MetodoPago,
                    @ReferenciaBancaria,
                    @Observaciones
                );

                /*
                    Complemento de comercio exterior (CCE). Oracle reemplaza
                    método y referencia bancaria con los valores configurados;
                    omitirlo cambia datos fiscales de salida.
                */
                IF TRIM(UPPER(@ReferenciaBancaria)) = 'CCE'
                BEGIN
                    SET @sMetodoDePago = EAI_OWNER.GETCONV(
                        'TMD_PAC Payment Method', 'Import/Export');
                    SET @sNumCtaPago = EAI_OWNER.GETCONV(
                        'TMD_PAC Payment Method', 'Import/Export Ref Banco');

                    UPDATE T3.Otros_General
                       SET MetodoPago = @sMetodoDePago,
                           ReferenciaBancaria = @sNumCtaPago,
                           Incoterms = '',
                           Complemento_CE = 'CCE'
                     WHERE Factura = @Factura;
                END;

                INSERT INTO T3.Otros_Detalle
                (
                    Factura,
                    Num_Linea,
                    Material,
                    MaterialDescripcion,
                    Cantidad,
                    UnidadMedida,
                    PrecioUnitario,
                    Valor_Subt,
                    Valor_IVA,
                    Leyenda_EN,
                    Leyenda_ES
                )
                SELECT
                    Head.FacturaSAP,
                    Det.ItemID,
                    Det.Material,
                    Det.MaterialDescripcion,
                    Det.Cantidad,
                    Det.UnidadMedida,

                    -- Oracle no sustituye una cantidad cero: la división debe
                    -- fallar y quedar registrada, evitando fabricar un precio 0.
                    Det.Valor_Subt / Det.Cantidad,

                    Det.Valor_Subt,
                    Det.Valor_IVA,
                    Det.Leyenda_EN,
                    Det.Leyenda_ES
                FROM EAI_OWNER.Tmp_Document_Detail Det
                INNER JOIN EAI_OWNER.Tmp_Document_Header Head
                    ON Head.ReferenceID=Det.ReferenceID
                WHERE Head.ReferenceID=@sInvoiceID;

                INSERT INTO T3.Otros_Condiciones
                (
                    Factura,
                    Num_Linea,
                    Condicion,
                    Total_Condicion,
                    Total_Monto,
                    Moneda,
                    Condicion_Texto,
                    Precio,
                    Condicion_ID,
                    Unidad_Medida,
                    Cantidad
                )
                SELECT
                    Head.FacturaSAP,
                    Det.ItemID,
                    Det.Condition,
                    Det.TotalCondition,
                    Det.TotalAmount,
                    Det.Currency,
                    Det.ConditionText,
                    Det.UnitPrice,
                    Det.ConditionID,
                    Det.UnitMeasure,
                    Det.Quantity
                FROM EAI_OWNER.Tmp_Document_Conditions Det
                INNER JOIN EAI_OWNER.Tmp_Document_Header Head
                    ON Head.ReferenceID=Det.ReferenceID
                WHERE Head.ReferenceID=@sInvoiceID;

                UPDATE EAI_OWNER.Tmp_Document_Header
                SET Procesado = GETDATE()
                WHERE ReferenceID = @sInvoiceID;
            END

            FETCH NEXT FROM curGeneral INTO
                @Factura,@ReferenceID,@PedidoSAP,@Sociedad,
                @ClaseFactura,@RFC,@NIF,@Moneda,@TipoCambio,
                @CondicionPago,@ValorSubt,@ValorIVA,
                @FechaFactura,@FechaTRN,@ClienteSAP,
                @ClteFacturaSAP,@Nombre,@Direccion,
                @Colonia,@Ciudad,@Estado,@Pais,
                @CodigoPostal,@MetodoPago,@ReferenciaBancaria,
                @Observaciones,@Incoterms,@HoraFactura,@HoraDefault;
        END

        CLOSE curGeneral;
        DEALLOCATE curGeneral;

        -- Enriquecimientos posteriores: claves SAT, retenciones y corrección de
        -- partners. El orden coincide con el procedimiento Oracle.
        EXEC EAI_OWNER.INVOICE_TO_OTROS_V33 @sInvoiceID;
        EXEC EAI_OWNER.INVOICE_TO_OTROS_RETENTION @sInvoiceID;
        EXEC EAI_OWNER.INVOICE_TO_OTROS_PARTNERS @sInvoiceID;

    END TRY

    BEGIN CATCH

        IF CURSOR_STATUS('local', 'curGeneral') >= 0 CLOSE curGeneral;
        IF CURSOR_STATUS('local', 'curGeneral') > -3 DEALLOCATE curGeneral;

        SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT
            (
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
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Sending to T3',
            @v_ID,
            GETDATE(),
            NULL,
            'Error',
            'Invoice to T3',
            @sMsg,
            'XML',
            @sErrorCode
        );

        -- Oracle confirma lo ejecutado antes del error, registra la incidencia
        -- y no la propaga. El modo autocommit de SQL Server conserva ese límite.

    END CATCH

END;
GO
