ALTER PROCEDURE EAI_OWNER.INVOICE_TO_FACTURA
    @sInvoiceID VARCHAR(30),
    @pFolioFiscal VARCHAR(30) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Variables locales
        DECLARE @sMsg VARCHAR(500) = NULL;
        DECLARE @sErrorCode VARCHAR(500) = NULL;
        DECLARE @v_ID VARCHAR(30) = @sInvoiceID;
        DECLARE @sAccnt_ID VARCHAR(30) = NULL;
        DECLARE @sProcesar VARCHAR(2) = 'NO';
        DECLARE @sFacturaV3 VARCHAR(30) = NULL;
        DECLARE @nBonif_Subt NUMERIC(22,7) = 0;
        DECLARE @nBonif_IVA NUMERIC(22,7) = 0;
        DECLARE @nBonif_Porc NUMERIC(22,7) = 0;
        DECLARE @sUbicacion VARCHAR(4) = NULL;
        DECLARE @sMaterial VARCHAR(18) = NULL;
        DECLARE @nFact_Subt NUMERIC(22,7) = 0;
        DECLARE @nFact_IVA NUMERIC(22,7) = 0;
        DECLARE @nDet_Subt NUMERIC(22,7) = 0;
        DECLARE @nDet_IVA NUMERIC(22,7) = 0;
        DECLARE @nDet_EnvioSubt NUMERIC(22,7) = 0;
        DECLARE @nDet_EnvioIVA NUMERIC(22,7) = 0;
        DECLARE @nDet_CrediSubt NUMERIC(22,7) = 0;
        DECLARE @nDet_CrediIVA NUMERIC(22,7) = 0;
        DECLARE @nDet_Bonif NUMERIC(22,7) = 0;
        DECLARE @nDet_BonifIVA NUMERIC(22,7) = 0;
        DECLARE @nCantidad_Vta NUMERIC(22,7) = 0;
        DECLARE @nDet_PrecioUnit NUMERIC(22,7) = 0;
        DECLARE @nDet_ValorTot NUMERIC(22,7) = 0;
        DECLARE @sRF_Comp VARCHAR(2) = 'NO';
        DECLARE @nDias INT = 0;
        DECLARE @nFactorDiv INT = 1;
        DECLARE @sUnidad_Med_Vta VARCHAR(10) = NULL;
        DECLARE @nItmTasa_IVA NUMERIC(22,7) = 0;
        
        -- Variables para cursores
        DECLARE @Factura VARCHAR(30);
        DECLARE @Prefijo VARCHAR(30);
        DECLARE @Centro VARCHAR(30);
        DECLARE @Distribuidor VARCHAR(30);
        DECLARE @Entrega VARCHAR(30);
        DECLARE @Fecha_Factura DATE;
        DECLARE @Fecha_Pago DATE;
        DECLARE @Clase_Factura VARCHAR(10);
        DECLARE @Cliente_V3 VARCHAR(30);
        DECLARE @Cliente_SAP VARCHAR(30);
        DECLARE @Cliente_Pagador_SAP VARCHAR(30);
        DECLARE @Clte_Factura_SAP VARCHAR(30);
        DECLARE @Ubicacion VARCHAR(30);
        DECLARE @Pedido VARCHAR(30);
        DECLARE @Fecha_Est_Ent DATE;
        DECLARE @Valor_Subt NUMERIC(22,7);
        DECLARE @Valor_IVA NUMERIC(22,7);
        DECLARE @Status_Contable VARCHAR(10);
        DECLARE @Referencia VARCHAR(30);
        DECLARE @Valor_ISSA NUMERIC(22,7);
        DECLARE @Ctro VARCHAR(30);
        DECLARE @Tasa_IVA NUMERIC(22,7);
        DECLARE @Hora_Factura VARCHAR(10);
        DECLARE @CompanyCode VARCHAR(10);
        
        -- Variables para detalle
        DECLARE @Num_Linea VARCHAR(30);
        DECLARE @Material_Det VARCHAR(18);
        DECLARE @Unidad_Med_Vta_Det VARCHAR(10);
        DECLARE @Status_Prod VARCHAR(2);
        DECLARE @Tasa_IEPS NUMERIC(22,7);
        DECLARE @Cantidad_Vta_Det NUMERIC(22,7);
        DECLARE @Valor_Subt_Det NUMERIC(22,7);
        DECLARE @Valor_IVA_Det NUMERIC(22,7);
        DECLARE @Valor_ISSA_Det NUMERIC(22,7);
        DECLARE @Bonif_Subt_Det NUMERIC(22,7);
        DECLARE @Bonif_Vol NUMERIC(22,7);
        DECLARE @Envio_Subt NUMERIC(22,7);
        DECLARE @Credito_Subt NUMERIC(22,7);
        
        -- =============================================
        -- CURSOR 1: ScrGeneral - Encabezado de Factura
        -- =============================================
        DECLARE ScrGeneral CURSOR LOCAL STATIC READ_ONLY FOR
        SELECT 
            Head.FacturaSAP,
            SUBSTRING(Head.FacturaSAP, 1, 3),
            Head.ShippingPoint,
            dbo.CONV_PLANT_TO_DIST(Head.ShippingPoint),
            Head.ReferenceID,
            TRY_CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            TRY_CONVERT(DATE, SUBSTRING(Head.Fecha_Vencimiento, 1, 8), 112),
            CASE 
                WHEN Head.DeliveryType = 'C005' THEN 'C003'
                WHEN Head.DeliveryType = 'C006' THEN 'C004'
                ELSE Head.DeliveryType 
            END,
            dbo.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP),
            Head.Cust_to_SAP,
            Head.Cust_to_SAP,
            ISNULL(Head.Bill_to_SAP, Head.Cust_to_SAP),
            'NULL',
            Head.PedidoSAP,
            TRY_CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            ISNULL(Head.Valor_Subt, 0),
            ISNULL(Head.Valor_IVA, 0),
            '11',
            Head.PedidoV3,
            0,
            Head.ShippingPoint,
            CASE
                WHEN ISNULL(Head.Valor_Subt, 0) = 0 THEN 0
                ELSE ROUND(ISNULL(Head.Valor_IVA, 0) * 100.0 / ISNULL(Head.Valor_Subt, 0), 0)
            END,
            SUBSTRING(Head.DocumentDate, 10, 2) + ':' + 
            SUBSTRING(Head.DocumentDate, 12, 2) + ':' + 
            SUBSTRING(Head.DocumentDate, 14, 2),
            Head.CompanyCode
        FROM EAI_Owner.Tmp_Document_Header Head
        WHERE Head.ReferenceID = @sInvoiceID;
        
        OPEN ScrGeneral;
        FETCH NEXT FROM ScrGeneral INTO
            @Factura, @Prefijo, @Centro, @Distribuidor, @Entrega, @Fecha_Factura, @Fecha_Pago,
            @Clase_Factura, @Cliente_V3, @Cliente_SAP, @Cliente_Pagador_SAP, @Clte_Factura_SAP,
            @Ubicacion, @Pedido, @Fecha_Est_Ent, @Valor_Subt, @Valor_IVA, @Status_Contable,
            @Referencia, @Valor_ISSA, @Ctro, @Tasa_IVA, @Hora_Factura, @CompanyCode;
            
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Determinar factor divisor según clase de factura
            SET @nFactorDiv = CASE 
                WHEN @Clase_Factura IN ('C005', 'C006', 'C003', 'C004') THEN 100 
                ELSE 1 
            END;
            
            SET @sFacturaV3 = @Referencia;
            
            -- =============================================
            -- CURSOR 2: ScrValida - Validar si procesar
            -- =============================================
            DECLARE ScrValida CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT CASE
                WHEN fg.Fecha_Proc_BATMD IS NULL THEN 'SI'
                WHEN fg.Fecha_Proc_BATMD > '29990101' THEN 'SI'
                ELSE 'NO'
            END
            FROM T3.Factura_General fg
            WHERE fg.Factura = @sFacturaV3;
            
            OPEN ScrValida;
            FETCH NEXT FROM ScrValida INTO @sProcesar;
            IF @@FETCH_STATUS <> 0
                SET @sProcesar = 'SI';
            CLOSE ScrValida;
            DEALLOCATE ScrValida;
            
            IF @sProcesar = 'SI'
            BEGIN
                -- Validar ubicación
                IF @sUbicacion IS NULL OR LEN(@sUbicacion) = 0
                    SET @sUbicacion = 'TBD';
                
                -- Calcular bonificación subtotal
                SELECT @nBonif_Subt = ISNULL(SUM(ISNULL(Det.Bonif_Subt, 0) / @nFactorDiv), 0)
                FROM EAI_Owner.Tmp_Document_Detail Det
                WHERE Det.ReferenceID = @sInvoiceID;
                
                -- Calcular bonificación IVA
                SET @nBonif_IVA = ROUND(@nBonif_Subt * @Tasa_IVA / 100.0, 2);
                
                -- Calcular porcentaje de bonificación (CORREGIDO: Inicializar primero)
                SET @nBonif_Porc = 0;
                IF @Valor_Subt > 0
                    SET @nBonif_Porc = ROUND((@nBonif_Subt * 100.0) / @Valor_Subt, 2);
                
                -- Calcular subtotal e IVA de factura
                SET @nFact_Subt = ROUND(ISNULL(@Valor_Subt, 0) / @nFactorDiv, 2);
                SET @nFact_IVA = ROUND(ISNULL(@Valor_IVA, 0) / @nFactorDiv, 2);
                
                -- Ajuste para ciertos tipos de factura
                IF @Clase_Factura IN ('C003', 'C004', 'C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031')
                    SET @nFact_Subt = @nFact_Subt - @nFact_IVA;
                
                -- Limpiar registros previos
                DELETE FROM T3.Factura_General WHERE Factura = @sFacturaV3;
                DELETE FROM T3.Factura_Detalle WHERE Factura = @sFacturaV3;
                DELETE FROM T3.RF_Complemento WHERE Factura = @sFacturaV3;
                
                -- Insertar complemento fiscal
                SET @sRF_Comp = CASE WHEN @CompanyCode = 'MX10' THEN 'SI' ELSE 'NO' END;
                
                INSERT INTO T3.RF_Complemento 
                    (Factura, Hora_Factura, Anio_Aprob, Folio_Aprob, Order_Num, Rep_ID, 
                     X_DelRep_Invloc, Volumen, Sociedad, Cadena_Original, Sello_Digital, Dias_Pago)
                VALUES 
                    (@sFacturaV3, FORMAT(GETDATE(), 'HH:mm:ss'), 'Error', 'Error', '', 'U00000000', 
                     '', NULL, 'MX06', 'CFDI - Documento', 'CFDI - Documento', 
                     DATEDIFF(DAY, @Fecha_Factura, @Fecha_Pago));
                
                -- Insertar encabezado de factura
                INSERT INTO T3.Factura_General
                    (Factura, Entrega, Distribuidor, Cliente_V3, Fecha_Factura, Ubicacion, 
                     Fecha_Pago, Row_ID, Fecha_TRN, Tipo_Docto, Cliente_SAP, Clte_Factura_SAP, 
                     Pedido, Valor_Subt, Valor_IVA, Referencia, Valor_ISSA, Ctro, 
                     Bonif_Subt, Bonif_IVA, Bonif_Porc, Bonif_Vol)
                VALUES
                    (@sFacturaV3, @Entrega, @Distribuidor, @Cliente_V3, @Fecha_Factura, @sUbicacion, 
                     @Fecha_Pago, @Entrega, GETDATE(), @Clase_Factura, @Cliente_SAP, @Clte_Factura_SAP, 
                     @Pedido, @nFact_Subt, @nFact_IVA, @Referencia, @Valor_ISSA, @Ctro, 
                     @nBonif_Subt, @nBonif_IVA, @nBonif_Porc, 0);
                
                -- =============================================
                -- CURSOR 3: ScrDetalle - Líneas de Detalle
                -- =============================================
                DECLARE ScrDetalle CURSOR LOCAL STATIC READ_ONLY FOR
                SELECT 
                    Factura, Prefijo, Num_Linea, Material, Unidad_Med_Vta, Status_Prod,
                    MAX(Tasa_IEPS) AS Tasa_IEPS,
                    SUM(Cantidad_Vta) AS Cantidad_Vta,
                    SUM(Valor_Subt) AS Valor_Subt,
                    SUM(Valor_IVA) AS Valor_IVA,
                    SUM(Valor_ISSA) AS Valor_ISSA,
                    SUM(Bonif_Subt) AS Bonif_Subt,
                    SUM(Bonif_Vol) AS Bonif_Vol,
                    SUM(Envio_Subt) AS Envio_Subt,
                    SUM(Credito_Subt) AS Credito_Subt
                FROM (
                    SELECT 
                        Head.FacturaSAP AS Factura,
                        SUBSTRING(Head.FacturaSAP, 1, 3) AS Prefijo,
                        Det.ItemID AS Num_Linea,
                        CAST(TRIM(Det.Material) AS VARCHAR(18)) AS Material,
                        ISNULL(Det.UnidadMedida, 'UA') AS Unidad_Med_Vta,
                        CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END AS Status_Prod,
                        0 AS Tasa_IEPS,
                        CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE Det.Cantidad END AS Cantidad_Vta,
                        ISNULL(Det.Valor_Subt, 0) AS Valor_Subt,
                        ISNULL(Det.Valor_IVA, 0) AS Valor_IVA,
                        0 AS Valor_ISSA,
                        ISNULL(Det.Bonif_Subt, 0) AS Bonif_Subt,
                        0 AS Bonif_Vol,
                        ISNULL(Det.Envio_Subt, 0) AS Envio_Subt,
                        ISNULL(Det.Credito_Subt, 0) AS Credito_Subt,
                        CASE
                            WHEN ISNULL(Det.Valor_Subt, 0) = 0 THEN 0
                            ELSE ROUND(ISNULL(Det.Valor_IVA, 0) * 100.0 / ISNULL(Det.Valor_Subt, 0), 0)
                        END AS Tasa_IVA
                    FROM EAI_Owner.Tmp_Document_Header Head
                    INNER JOIN EAI_Owner.Tmp_Document_Detail Det ON Head.ReferenceID = Det.ReferenceID
                    LEFT JOIN T3.Material Mat ON CAST(TRIM(Det.Material) AS VARCHAR(18)) = Mat.Material
                    WHERE Head.ReferenceID = @sInvoiceID
                ) DetailAgg
                GROUP BY Factura, Prefijo, Num_Linea, Material, Unidad_Med_Vta, Status_Prod;
                
                OPEN ScrDetalle;
                FETCH NEXT FROM ScrDetalle INTO
                    @Factura, @Prefijo, @Num_Linea, @Material_Det, @Unidad_Med_Vta_Det, 
                    @Status_Prod, @Tasa_IEPS, @Cantidad_Vta_Det, @Valor_Subt_Det, 
                    @Valor_IVA_Det, @Valor_ISSA_Det, @Bonif_Subt_Det, @Bonif_Vol, 
                    @Envio_Subt, @Credito_Subt;
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @nCantidad_Vta = @Cantidad_Vta_Det;
                    SET @nDet_Subt = ROUND(ISNULL(@Valor_Subt_Det, 0) / @nFactorDiv, 2);
                    SET @nDet_IVA = ROUND(ISNULL(@Valor_IVA_Det, 0) / @nFactorDiv, 2);
                    SET @nDet_Bonif = ROUND(ISNULL(@Bonif_Subt_Det, 0) / @nFactorDiv, 2);
                    SET @nDet_Bonif = ROUND((@nDet_Bonif * (100 + @Tasa_IEPS)) / 100.0, 2);
                    SET @nDet_EnvioSubt = ROUND(ISNULL(@Envio_Subt, 0) / @nFactorDiv, 2);
                    SET @nDet_CrediSubt = ROUND(ISNULL(@Credito_Subt, 0) / @nFactorDiv, 2);
                    
                    -- Calcular tasa IVA del item
                    SET @nItmTasa_IVA = CASE
                        WHEN ISNULL(@Valor_Subt_Det, 0) = 0 THEN 0
                        ELSE ROUND(ISNULL(@Valor_IVA_Det, 0) * 100.0 / ISNULL(@Valor_Subt_Det, 0), 0)
                    END;
                    
                    SET @nDet_BonifIVA = ROUND(@nDet_Bonif * @nItmTasa_IVA / 100.0, 2);
                    
                    -- Calcular porcentaje de bonificación
                    SET @nBonif_Porc = CASE
                        WHEN @Valor_Subt_Det > 0 
                            THEN ROUND((@Bonif_Subt_Det * 100.0) / (@Bonif_Subt_Det + @Valor_Subt_Det), 2)
                        ELSE 0
                    END;
                    
                    -- Calcular IVA de envío
                    SET @nDet_EnvioIVA = CASE
                        WHEN @nDet_EnvioSubt > 0 
                            THEN ROUND(@nDet_EnvioSubt * @nItmTasa_IVA / 100.0, 2)
                        ELSE 0
                    END;
                    
                    -- Calcular IVA de crédito
                    SET @nDet_CrediIVA = CASE
                        WHEN @nDet_CrediSubt > 0 
                            THEN ROUND(@nDet_CrediSubt * @nItmTasa_IVA / 100.0, 2)
                        ELSE 0
                    END;
                    
                    -- Ajustar subtotal
                    SET @nDet_Subt = @nDet_Subt - @nDet_EnvioSubt - @nDet_CrediSubt;
                    
                    -- Ajustar IVA para tipos específicos de factura
                    IF @Clase_Factura IN ('C005', 'C006', 'C003', 'C004')
                        SET @nDet_IVA = @nDet_IVA - @nDet_EnvioIVA - @nDet_CrediIVA;
                    
                    -- Preparar material
                    SET @sMaterial = TRIM(@Material_Det);
                    
                    -- Convertir unidad de medida
                    SET @sUnidad_Med_Vta = @Unidad_Med_Vta_Det;
                    EXEC @sUnidad_Med_Vta = EAI_OWNER.GETCONV @p1='ECC_V3 UOM', @p2=@sUnidad_Med_Vta OUTPUT;
                    
                    -- Workaround para ciertos tipos de factura
                    IF @Clase_Factura IN ('C030', 'C031')
                        EXEC EAI_Owner.WA_Cantidad_UMV @sMaterial, @Cantidad_Vta_Det, @Unidad_Med_Vta_Det, 
                                                  @nCantidad_Vta OUTPUT, @sUnidad_Med_Vta OUTPUT;
                    
                    -- Recalcular IVA para tipos específicos
                    IF @Clase_Factura IN ('C025', 'C019')
                        SET @nDet_IVA = ROUND(@nDet_Subt * @nItmTasa_IVA / 100.0, 2);
                    
                    -- Calcular valores totales
                    SET @nDet_ValorTot = (ISNULL(@nDet_Subt, 0) + ISNULL(@nDet_IVA, 0));
                    SET @nDet_PrecioUnit = ROUND((ISNULL(@nDet_Subt, 0)) / NULLIF(@nCantidad_Vta, 0), 2);
                    
                    -- Insertar detalle de factura
                    INSERT INTO T3.Factura_Detalle 
                        (Factura, Num_Linea, Material, Cantidad_Vta, Unidad_Med_Vta, 
                         Status_Prod, Valor_Subt, Valor_IVA, Valor_ISSA, 
                         Envio_Subt, Envio_IVA, Precio_Unit, Valor_Tot, 
                         Credito_Subt, Credito_IVA, Bonif_Subt, Bonif_IVA, Bonif_Porc, Bonif_Vol)
                    VALUES
                        (@sFacturaV3, @Num_Linea, @sMaterial, @nCantidad_Vta, @sUnidad_Med_Vta, 
                         @Status_Prod, @nDet_Subt, @nDet_IVA, @Valor_ISSA_Det, 
                         @nDet_EnvioSubt, @nDet_EnvioIVA, @nDet_PrecioUnit, @nDet_ValorTot, 
                         @nDet_CrediSubt, @nDet_CrediIVA, @nDet_Bonif, @nDet_BonifIVA, @nBonif_Porc, @Bonif_Vol);
                    
                    FETCH NEXT FROM ScrDetalle INTO
                        @Factura, @Prefijo, @Num_Linea, @Material_Det, @Unidad_Med_Vta_Det, 
                        @Status_Prod, @Tasa_IEPS, @Cantidad_Vta_Det, @Valor_Subt_Det, 
                        @Valor_IVA_Det, @Valor_ISSA_Det, @Bonif_Subt_Det, @Bonif_Vol, 
                        @Envio_Subt, @Credito_Subt;
                END;
                
                CLOSE ScrDetalle;
                DEALLOCATE ScrDetalle;
            END;
            
            FETCH NEXT FROM ScrGeneral INTO
                @Factura, @Prefijo, @Centro, @Distribuidor, @Entrega, @Fecha_Factura, @Fecha_Pago,
                @Clase_Factura, @Cliente_V3, @Cliente_SAP, @Cliente_Pagador_SAP, @Clte_Factura_SAP,
                @Ubicacion, @Pedido, @Fecha_Est_Ent, @Valor_Subt, @Valor_IVA, @Status_Contable,
                @Referencia, @Valor_ISSA, @Ctro, @Tasa_IVA, @Hora_Factura, @CompanyCode;
        END;
        
        CLOSE ScrGeneral;
        DEALLOCATE ScrGeneral;
        
        -- =============================================
        -- Actualizar totales desde detalle
        -- =============================================
        UPDATE PG
        SET 
            Bonif_Subt = PD_Agg.Bonif_Subt,
            Bonif_IVA = PD_Agg.Bonif_IVA,
            Valor_Subt = PD_Agg.Valor_Subt,
            Valor_IVA = PD_Agg.Valor_IVA,
            Envio_Subt = PD_Agg.Envio_Subt,
            Envio_IVA = PD_Agg.Envio_IVA,
            Credito_Subt = PD_Agg.Credito_Subt,
            Credito_IVA = PD_Agg.Credito_IVA
        FROM T3.Factura_General PG
        INNER JOIN (
            SELECT 
                PD.Factura,
                SUM(ISNULL(PD.Bonif_Subt, 0)) AS Bonif_Subt,
                SUM(ISNULL(PD.Bonif_IVA, 0)) AS Bonif_IVA,
                SUM(ISNULL(PD.Valor_Subt, 0)) AS Valor_Subt,
                SUM(ISNULL(PD.Valor_IVA, 0)) AS Valor_IVA,
                SUM(ISNULL(PD.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(PD.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(PD.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(PD.Credito_IVA, 0)) AS Credito_IVA
            FROM T3.Factura_Detalle PD
            GROUP BY PD.Factura
        ) PD_Agg ON PG.Factura = PD_Agg.Factura
        WHERE PG.Factura = @sFacturaV3;
        
        -- Marcar como procesado
        UPDATE EAI_Owner.Tmp_Document_Header  
        SET Procesado = GETDATE()
        WHERE ReferenceID = @sInvoiceID;
        
        -- Llamar a stored procedure relacionado
        EXEC EAI_OWNER.INVOICE_TO_ENTREGA_PO @sInvoiceID, 0;
        
        -- Retornar folio fiscal
        SET @pFolioFiscal = @sFacturaV3;
        
    END TRY
    BEGIN CATCH
        -- Manejo de errores
        SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE();
        SET @sMsg = SUBSTRING(@sMsg, 1, 250);
        
        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
            (DIRECTION, REFERENCE, CREATED, MESSAGE, STATUS, QUEUE_NAME, 
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES 
            ('Sending to T3', @v_ID, GETDATE(), NULL, 'Error', 'Invoice to T3', 
             @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);
        
        COMMIT TRANSACTION;
        THROW;
    END CATCH;
END;