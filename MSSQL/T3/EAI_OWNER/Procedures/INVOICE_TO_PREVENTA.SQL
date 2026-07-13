CREATE OR ALTER PROCEDURE [EAI_OWNER].[INVOICE_TO_PREVENTA]
(
    @sInvoiceID   VARCHAR(30),
    @pFolioFiscal VARCHAR(30) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg              VARCHAR(500),
        @sErrorCode        VARCHAR(500),
        @v_ID              VARCHAR(30) = @sInvoiceID,
        @sProcesar         VARCHAR(2) = 'NO',
        @sFacturaV3        VARCHAR(30),
        @nBonif_Subt       NUMERIC(22,7),
        @nBonif_IVA        NUMERIC(22,7),
        @nBonif_Porc       NUMERIC(22,7),
        @sUbicacion        VARCHAR(4),
        @sMaterial         VARCHAR(18),
        @nFact_Subt        NUMERIC(22,7),
        @nFact_IVA         NUMERIC(22,7),
        @nDet_Subt         NUMERIC(22,7),
        @nDet_IVA          NUMERIC(22,7),
        @nDet_EnvioSubt    NUMERIC(22,7),
        @nDet_EnvioIVA     NUMERIC(22,7),
        @nDet_Bonif        NUMERIC(22,7),
        @nDet_BonifIVA     NUMERIC(22,7),
        @nCantidad_Vta     NUMERIC(22,7),
        @sRF_Comp          VARCHAR(4) = 'NO',
        @nFactorDiv        INT,
        @sUnidad_Med_Vta   VARCHAR(10),
        @nItmTasa_IVA      NUMERIC(22,7);

    DECLARE
        @Doc_Factura             VARCHAR(30),
        @Doc_Prefijo             VARCHAR(3),
        @Doc_Centro              VARCHAR(4),
        @Doc_Entrega             VARCHAR(30),
        @Doc_Fecha_Factura       DATE,
        @Doc_Fecha_Pago          DATE,
        @Doc_Clase_Factura       VARCHAR(4),
        @Doc_Cliente_SAP         VARCHAR(30),
        @Doc_Cliente_Pagador_SAP VARCHAR(30),
        @Doc_Clte_Factura_SAP    VARCHAR(30),
        @Doc_Pedido              VARCHAR(30),
        @Doc_Fecha_Est_Ent       DATE,
        @Doc_Valor_Subt          NUMERIC(22,7),
        @Doc_Valor_IVA           NUMERIC(22,7),
        @Doc_Status_Contable     VARCHAR(2),
        @Doc_Referencia          VARCHAR(30),
        @Doc_Valor_ISSA          NUMERIC(22,7),
        @Doc_Ctro                VARCHAR(4),
        @Doc_Tasa_IVA            NUMERIC(22,7),
        @Doc_Hora_Factura        VARCHAR(8),
        @Doc_CompanyCode         VARCHAR(4),
        @Doc_LiberaAuto          VARCHAR(30);

    DECLARE ScrGeneral CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Head.FacturaSAP,
            SUBSTRING(Head.FacturaSAP, 1, 3),
            Head.ShippingPoint,
            Head.ReferenceID,
            TRY_CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            TRY_CONVERT(DATE, SUBSTRING(Head.Fecha_Vencimiento, 1, 8), 112),
            CASE WHEN Head.DeliveryType = 'C004' THEN 'C006' ELSE Head.DeliveryType END,
            Head.Cust_to_SAP,
            Head.Cust_to_SAP,
            ISNULL(Head.Bill_to_SAP, Head.Cust_to_SAP),
            Head.PedidoSAP,
            TRY_CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            ISNULL(Head.Valor_Subt, 0),
            ISNULL(Head.Valor_IVA, 0),
            '11',
            UPPER(Head.PedidoV3),
            0,
            Head.ShippingPoint,
            CASE
                WHEN ISNULL(Head.Valor_Subt, 0) = 0 THEN 0
                ELSE ROUND(ISNULL(Head.Valor_IVA, 0) * 100.0 / ISNULL(Head.Valor_Subt, 0), 0)
            END,
            SUBSTRING(Head.DocumentDate, 10, 2) + ':' +
            SUBSTRING(Head.DocumentDate, 12, 2) + ':' +
            SUBSTRING(Head.DocumentDate, 14, 2),
            Head.CompanyCode,
            ISNULL(Lib.LiberaAuto, 'TBC')
        FROM [EAI_Owner].[Tmp_Document_Header] AS Head
        LEFT JOIN
        (
            SELECT [Source] AS Cliente_SAP,
                   ISNULL([Target], 'NO') AS LiberaAuto
            FROM [EAI_Owner].[MX_HashTable]
            WHERE [Type] = 'PDV A51'
        ) AS Lib
            ON Head.Cust_to_SAP = Lib.Cliente_SAP
        WHERE Head.ReferenceID = @sInvoiceID;

    BEGIN TRY
        OPEN ScrGeneral;

        FETCH NEXT FROM ScrGeneral INTO
            @Doc_Factura, @Doc_Prefijo, @Doc_Centro, @Doc_Entrega,
            @Doc_Fecha_Factura, @Doc_Fecha_Pago, @Doc_Clase_Factura,
            @Doc_Cliente_SAP, @Doc_Cliente_Pagador_SAP, @Doc_Clte_Factura_SAP,
            @Doc_Pedido, @Doc_Fecha_Est_Ent, @Doc_Valor_Subt, @Doc_Valor_IVA,
            @Doc_Status_Contable, @Doc_Referencia, @Doc_Valor_ISSA, @Doc_Ctro,
            @Doc_Tasa_IVA, @Doc_Hora_Factura, @Doc_CompanyCode, @Doc_LiberaAuto;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sRF_Comp = 'NO';
            SET @nFactorDiv = CASE
                                  WHEN @Doc_Clase_Factura IN ('C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031') THEN 100
                                  ELSE 1
                              END;

            IF @Doc_Clase_Factura IN ('C020', 'C021', 'C022')
            BEGIN
                EXEC [EAI_Owner].[WA_FOLIO_FACTURA]
                    @Doc_Factura, @Doc_Centro, @Doc_Clase_Factura, @Doc_Fecha_Factura, 0, @sFacturaV3 OUTPUT;
            END
            ELSE IF @Doc_Clase_Factura IN ('C005', 'C006')
            BEGIN
                SET @sFacturaV3 = REPLACE(@Doc_Referencia, '-O-', '-');
            END
            ELSE IF @Doc_Clase_Factura IN ('C019', 'C0FX', 'C025')
            BEGIN
                SET @sRF_Comp = 'SI';
                SET @sFacturaV3 = @Doc_Referencia;
            END
            ELSE IF @Doc_Clase_Factura IN ('C030', 'C031')
            BEGIN
                SET @sRF_Comp = 'SI';
                EXEC [EAI_Owner].[WA_FOLIO_FACTURA]
                    @Doc_Factura, @Doc_Centro, @Doc_Clase_Factura, @Doc_Fecha_Factura, 0, @sFacturaV3 OUTPUT;
            END
            ELSE
            BEGIN
                SET @sFacturaV3 = @Doc_Factura;
            END;

            SELECT TOP (1)
                @sProcesar = CASE
                                  WHEN Fecha_Proc_BATMD IS NULL THEN 'SI'
                                  WHEN Fecha_Proc_BATMD > CONVERT(DATE, '29990101', 112) THEN 'SI'
                                  ELSE 'NO'
                              END
            FROM [T3].[Preventa_General]
            WHERE Factura = @sFacturaV3;

            IF @@ROWCOUNT = 0
                SET @sProcesar = 'SI';

            IF @sProcesar = 'SI'
            BEGIN
                IF @sUbicacion IS NULL OR LEN(@sUbicacion) = 0
                    SET @sUbicacion = 'TBD';

                SELECT @nBonif_Subt = ISNULL(SUM(ISNULL(Det.Bonif_Subt, 0) / @nFactorDiv), 0)
                FROM [EAI_Owner].[Tmp_Document_Detail] AS Det
                WHERE Det.ReferenceID = @sInvoiceID;

                SET @nBonif_IVA = ROUND(@nBonif_Subt * @Doc_Tasa_IVA / 100.0, 2);

                IF @Doc_Valor_Subt > 0
                    SET @nBonif_Porc = ROUND((@nBonif_Subt * 100.0) / @Doc_Valor_Subt, 2);
                ELSE
                    SET @nBonif_Porc = 0;

                SET @nFact_Subt = ROUND(ISNULL(@Doc_Valor_Subt, 0) / @nFactorDiv, 2);
                SET @nFact_IVA = ROUND(ISNULL(@Doc_Valor_IVA, 0) / @nFactorDiv, 2);

                IF @Doc_Clase_Factura IN ('C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031')
                    SET @nFact_Subt = @nFact_Subt - @nFact_IVA;

                DELETE FROM [T3].[Preventa_General] WHERE Factura = @sFacturaV3;
                DELETE FROM [T3].[Preventa_Detalle] WHERE Factura = @sFacturaV3;
                DELETE FROM [T3].[Preventa_Condiciones] WHERE Factura = @sFacturaV3;

                IF @Doc_CompanyCode = 'MX10'
                    SET @sRF_Comp = 'SI';

                IF @sRF_Comp = 'SI'
                BEGIN
                    DELETE FROM [T3].[RF_Complemento] WHERE Factura = @sFacturaV3;

                    INSERT INTO [T3].[RF_Complemento]
                        (Factura, Hora_Factura, Sociedad, Dias_Pago)
                    VALUES
                        (@sFacturaV3, CONVERT(VARCHAR(8), GETDATE(), 108), @Doc_CompanyCode,
                         DATEDIFF(DAY, @Doc_Fecha_Factura, @Doc_Fecha_Pago));
                END;

                INSERT INTO [T3].[Preventa_General]
                    (Factura, Prefijo, Centro, Entrega, Fecha_Factura, Ubicacion,
                     Clte_Factura_SAP, Fecha_TRN, Clase_Factura, Cliente_SAP,
                     Cliente_Pagador_SAP, Pedido, Fecha_Est_Ent, Valor_Subt,
                     Valor_IVA, Status_Contable, Referencia, Valor_ISSA, Ctro,
                     Bonif_Subt, Bonif_IVA, Bonif_Porc, Bonif_Vol)
                VALUES
                    (@sFacturaV3, @Doc_Prefijo, @Doc_Centro, @Doc_Entrega, @Doc_Fecha_Factura,
                     @sUbicacion, @Doc_Clte_Factura_SAP, GETDATE(), @Doc_Clase_Factura,
                     @Doc_Cliente_SAP, @Doc_Cliente_Pagador_SAP, @Doc_Pedido, @Doc_Fecha_Est_Ent,
                     @nFact_Subt, @nFact_IVA, @Doc_Status_Contable, @Doc_Referencia,
                     @Doc_Valor_ISSA, @Doc_Ctro, @nBonif_Subt, @nBonif_IVA, @nBonif_Porc, 0);

                INSERT INTO [T3].[Preventa_Condiciones]
                    (Factura, Num_Linea, Condicion, Importe)
                SELECT @sFacturaV3,
                       ItemID,
                       [Condition],
                       Amount
                FROM [EAI_Owner].[tmp_Document_Detail_Cond]
                WHERE ReferenceID = @sInvoiceID;

                DECLARE
                    @Itm_Factura        VARCHAR(30),
                    @Itm_Prefijo        VARCHAR(3),
                    @Itm_Num_Linea      VARCHAR(30),
                    @Itm_Material       VARCHAR(18),
                    @Itm_Unidad_Med_Vta VARCHAR(10),
                    @Itm_Status_Prod    VARCHAR(1),
                    @Itm_Tasa_IEPS      NUMERIC(22,7),
                    @Itm_Cantidad_Vta   NUMERIC(22,7),
                    @Itm_Valor_Subt     NUMERIC(22,7),
                    @Itm_Valor_IVA      NUMERIC(22,7),
                    @Itm_Valor_ISSA     NUMERIC(22,7),
                    @Itm_Bonif_Subt     NUMERIC(22,7),
                    @Itm_Bonif_Vol      NUMERIC(22,7),
                    @Itm_Envio_Subt     NUMERIC(22,7);

                DECLARE ScrDetalle CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        Factura, Prefijo, Num_Linea, Material, Unidad_Med_Vta, Status_Prod,
                        MAX(Tasa_IEPS),
                        SUM(Cantidad_Vta),
                        SUM(Valor_Subt),
                        SUM(Valor_IVA),
                        SUM(Valor_ISSA),
                        SUM(Bonif_Subt),
                        SUM(Bonif_Vol),
                        SUM(Envio_Subt)
                    FROM
                    (
                        SELECT
                            Head.FacturaSAP AS Factura,
                            SUBSTRING(Head.FacturaSAP, 1, 3) AS Prefijo,
                            Det.ItemID AS Num_Linea,
                            COALESCE(CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                     LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))) AS Material,
                            CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE Det.Cantidad END AS Cantidad_Vta,
                            ISNULL(Det.UnidadMedida, 'UA') AS Unidad_Med_Vta,
                            CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END AS Status_Prod,
                            ISNULL(Det.Valor_Subt, 0) AS Valor_Subt,
                            ISNULL(Det.Valor_IVA, 0) AS Valor_IVA,
                            0 AS Valor_ISSA,
                            ISNULL(Det.Bonif_Subt, 0) AS Bonif_Subt,
                            0 AS Bonif_Vol,
                            ISNULL(Det.Envio_Subt, 0) AS Envio_Subt,
                            0 AS Tasa_IEPS
                        FROM [EAI_Owner].[Tmp_Document_Header] AS Head
                        INNER JOIN [EAI_Owner].[Tmp_Document_Detail] AS Det
                            ON Head.ReferenceID = Det.ReferenceID
                        LEFT JOIN [T3].[Material] AS Mat
                            ON COALESCE(CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                        LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))) = Mat.Material
                        WHERE Head.ReferenceID = @sInvoiceID
                    ) AS DetailData
                    GROUP BY Factura, Prefijo, Num_Linea, Material, Unidad_Med_Vta, Status_Prod;

                OPEN ScrDetalle;
                FETCH NEXT FROM ScrDetalle INTO
                    @Itm_Factura, @Itm_Prefijo, @Itm_Num_Linea, @Itm_Material,
                    @Itm_Unidad_Med_Vta, @Itm_Status_Prod, @Itm_Tasa_IEPS,
                    @Itm_Cantidad_Vta, @Itm_Valor_Subt, @Itm_Valor_IVA,
                    @Itm_Valor_ISSA, @Itm_Bonif_Subt, @Itm_Bonif_Vol, @Itm_Envio_Subt;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @nCantidad_Vta = @Itm_Cantidad_Vta;
                    SET @nDet_Subt = ROUND(ISNULL(@Itm_Valor_Subt, 0) / @nFactorDiv, 2);
                    SET @nDet_IVA = ROUND(ISNULL(@Itm_Valor_IVA, 0) / @nFactorDiv, 2);
                    SET @nDet_Bonif = ROUND(ISNULL(@Itm_Bonif_Subt, 0) / @nFactorDiv, 2);
                    SET @nDet_Bonif = ROUND((@nDet_Bonif * (100 + @Itm_Tasa_IEPS)) / 100.0, 2);
                    SET @nDet_EnvioSubt = ROUND(ISNULL(@Itm_Envio_Subt, 0) / @nFactorDiv, 2);

                    IF ISNULL(@Itm_Valor_Subt, 0) = 0
                        SET @nItmTasa_IVA = 0;
                    ELSE
                        SET @nItmTasa_IVA = ROUND(ISNULL(@Itm_Valor_IVA, 0) * 100.0 / ISNULL(@Itm_Valor_Subt, 0), 0);

                    SET @nDet_BonifIVA = ROUND(@nDet_Bonif * @nItmTasa_IVA / 100.0, 2);

                    IF @Itm_Valor_Subt > 0
                        SET @nBonif_Porc = ROUND((@Itm_Bonif_Subt * 100.0) / @Itm_Valor_Subt, 2);
                    ELSE
                        SET @nBonif_Porc = 0;

                    IF @nDet_EnvioSubt > 0
                        SET @nDet_EnvioIVA = ROUND(@nDet_EnvioSubt * @nItmTasa_IVA / 100.0, 2);
                    ELSE
                        SET @nDet_EnvioIVA = 0;

                    SET @nDet_Subt = @nDet_Subt - @nDet_EnvioSubt;

                    IF @Doc_Clase_Factura IN ('C005', 'C006')
                        SET @nDet_IVA = @nDet_IVA - @nDet_EnvioIVA;

                    IF @Doc_LiberaAuto <> 'TBC' AND @nDet_IVA > 0
                        SET @nDet_IVA = ROUND(@nDet_Subt * 0.16, 2);

                    SET @sMaterial = LTRIM(RTRIM(@Itm_Material));
                    SET @sUnidad_Med_Vta = [EAI_OWNER].[GETCONV]('ECC_V3 UOM', @Itm_Unidad_Med_Vta);

                    IF @Doc_Clase_Factura IN ('C030', 'C031')
                    BEGIN
                        EXEC [EAI_OWNER].[WA_CANTIDAD_UMV]
                            @sMaterial, @Itm_Cantidad_Vta, @Itm_Unidad_Med_Vta,
                            @nCantidad_Vta OUTPUT, @sUnidad_Med_Vta OUTPUT;
                    END;

                    IF @Doc_Clase_Factura IN ('C025', 'C019')
                        SET @nDet_IVA = ROUND(@nDet_Subt * @nItmTasa_IVA / 100.0, 2);

                    IF @nBonif_Porc > 100
                        SET @nBonif_Porc = 100;

                    INSERT INTO [T3].[Preventa_Detalle]
                        (Factura, Prefijo, Num_Linea, Material, Cantidad_Vta,
                         Unidad_Med_Vta, Referencia_Pedido, Status_Prod, Valor_Subt,
                         Valor_IVA, Valor_ISSA, Envio_Subt, Envio_IVA, Bonif_Subt,
                         Bonif_IVA, Bonif_Porc, Bonif_Vol)
                    VALUES
                        (@sFacturaV3, @Itm_Prefijo, @Itm_Num_Linea, @sMaterial,
                         @nCantidad_Vta, @sUnidad_Med_Vta, @Itm_Cantidad_Vta,
                         @Itm_Status_Prod, @nDet_Subt, @nDet_IVA, @Itm_Valor_ISSA,
                         @nDet_EnvioSubt, @nDet_EnvioIVA, @nDet_Bonif,
                         @nDet_BonifIVA, @nBonif_Porc, @Itm_Bonif_Vol);

                    FETCH NEXT FROM ScrDetalle INTO
                        @Itm_Factura, @Itm_Prefijo, @Itm_Num_Linea, @Itm_Material,
                        @Itm_Unidad_Med_Vta, @Itm_Status_Prod, @Itm_Tasa_IEPS,
                        @Itm_Cantidad_Vta, @Itm_Valor_Subt, @Itm_Valor_IVA,
                        @Itm_Valor_ISSA, @Itm_Bonif_Subt, @Itm_Bonif_Vol, @Itm_Envio_Subt;
                END;

                CLOSE ScrDetalle;
                DEALLOCATE ScrDetalle;
            END;

            FETCH NEXT FROM ScrGeneral INTO
                @Doc_Factura, @Doc_Prefijo, @Doc_Centro, @Doc_Entrega,
                @Doc_Fecha_Factura, @Doc_Fecha_Pago, @Doc_Clase_Factura,
                @Doc_Cliente_SAP, @Doc_Cliente_Pagador_SAP, @Doc_Clte_Factura_SAP,
                @Doc_Pedido, @Doc_Fecha_Est_Ent, @Doc_Valor_Subt, @Doc_Valor_IVA,
                @Doc_Status_Contable, @Doc_Referencia, @Doc_Valor_ISSA, @Doc_Ctro,
                @Doc_Tasa_IVA, @Doc_Hora_Factura, @Doc_CompanyCode, @Doc_LiberaAuto;
        END;

        CLOSE ScrGeneral;
        DEALLOCATE ScrGeneral;

        UPDATE PG
           SET PG.Bonif_Subt = ISNULL(PD.Bonif_Subt, 0),
               PG.Bonif_IVA  = ISNULL(PD.Bonif_IVA, 0),
               PG.Valor_Subt = ISNULL(PD.Valor_Subt, 0),
               PG.Valor_IVA  = ISNULL(PD.Valor_IVA, 0)
        FROM [T3].[Preventa_General] AS PG
        OUTER APPLY
        (
            SELECT
                SUM(ISNULL(Det.Bonif_Subt, 0)) AS Bonif_Subt,
                SUM(ISNULL(Det.Bonif_IVA, 0)) AS Bonif_IVA,
                SUM(ISNULL(Det.Valor_Subt, 0) + ISNULL(Det.Envio_Subt, 0)) AS Valor_Subt,
                SUM(ISNULL(Det.Valor_IVA, 0) + ISNULL(Det.Envio_IVA, 0)) AS Valor_IVA
            FROM [T3].[Preventa_Detalle] AS Det
            WHERE Det.Factura = PG.Factura
        ) AS PD
        WHERE PG.Factura = @sFacturaV3;

        EXEC [EAI_OWNER].[INVOICE_TO_ENTREGA_PO] @sInvoiceID, 0;

        UPDATE [EAI_Owner].[Tmp_Document_Header]
           SET Procesado = GETDATE()
         WHERE ReferenceID = @sInvoiceID;

        SET @pFolioFiscal = @sFacturaV3;

        EXEC [T3].[DELIVERY_WA_OXXO] @sFacturaV3, 1, 0;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'ScrGeneral') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'ScrGeneral') > -1
                CLOSE ScrGeneral;
            DEALLOCATE ScrGeneral;
        END;

        SET @sErrorCode = 'SQL-' + CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(20), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Sending to T3', @v_ID, GETDATE(), NULL, 'Error', 'Invoice to T3',
             @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);

        THROW;
    END CATCH;
END;
GO
