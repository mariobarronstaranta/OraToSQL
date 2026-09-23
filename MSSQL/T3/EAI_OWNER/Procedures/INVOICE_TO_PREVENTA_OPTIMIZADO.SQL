/*
    Procedimiento : EAI_OWNER.INVOICE_TO_PREVENTA_OPTIMIZADO

    Propósito
    ---------
    Convierte la información temporal de una factura, identificada por
    ReferenceID, en las tablas operativas de preventa del esquema T3.

    Flujo general
    -------------
    1. Lee la cabecera desde EAI_OWNER.Tmp_Document_Header.
    2. Determina el folio que utilizará T3 según la clase de factura.
    3. Verifica si la factura puede reconstruirse.
    4. Elimina una preventa anterior con el mismo folio.
    5. Inserta cabecera, condiciones y detalles recalculados.
    6. Genera la entrega, marca como procesada la cabecera temporal y ejecuta
       el proceso complementario de entrega OXXO.

    Consideraciones importantes
    ----------------------------
    - Este procedimiento no abre una transacción propia. Si el llamador ya
      tiene una transacción, sus cambios forman parte de esa misma unidad.
    - XACT_ABORT ON hace que un error de ejecución invalide la transacción.
    - Los importes de ciertas clases llegan en centavos; @nFactorDiv controla
      su conversión a la unidad monetaria utilizada por T3.
    - @pFolioFiscal es OUTPUT y devuelve el folio finalmente utilizado.
    - Las clases distintas de C030/C031 insertan el detalle por conjunto.
    - C030/C031 conservan el cursor porque WA_CANTIDAD_UMV usa parámetros OUTPUT.
    - El LEFT JOIN a T3.Material es obligatorio por regla de negocio y se conserva.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[INVOICE_TO_PREVENTA_OPTIMIZADO]
(
    @sInvoiceID   VARCHAR(30),        -- ReferenceID del documento temporal.
    @pFolioFiscal VARCHAR(30) OUTPUT  -- Folio generado o seleccionado para T3.
)
AS
BEGIN
    -- Evita mensajes "N filas afectadas" que pueden confundir a integraciones.
    SET NOCOUNT ON;

    -- Si una sentencia falla, SQL Server debe detener el resto del lote.
    SET XACT_ABORT ON;

    ---------------------------------------------------------------------------
    -- Variables de control, cálculos monetarios y conversión de detalle
    ---------------------------------------------------------------------------
    DECLARE
        @sMsg              VARCHAR(500),               -- Mensaje para bitácora.
        @sErrorCode        VARCHAR(500),               -- Código SQL-<número>.
        @v_ID              VARCHAR(30) = @sInvoiceID,  -- Referencia para errores.
        @sProcesar         VARCHAR(2) = 'NO',          -- SI permite reconstruir.
        @sFacturaV3        VARCHAR(30),                -- Folio definitivo en T3.
        @nBonif_Subt       NUMERIC(22,7),
        @nBonif_IVA        NUMERIC(22,7),
        @nBonif_Porc       NUMERIC(22,7),
        @sUbicacion        VARCHAR(4),                 -- TBD cuando no hay valor.
        @sMaterial         VARCHAR(18),                -- Material normalizado.
        @nFact_Subt        NUMERIC(22,7),
        @nFact_IVA         NUMERIC(22,7),
        @nDet_Subt         NUMERIC(22,7),
        @nDet_IVA          NUMERIC(22,7),
        @nDet_EnvioSubt    NUMERIC(22,7),
        @nDet_EnvioIVA     NUMERIC(22,7),
        @nDet_Bonif        NUMERIC(22,7),
        @nDet_BonifIVA     NUMERIC(22,7),
        @nCantidad_Vta     NUMERIC(22,7),
        @sRF_Comp          VARCHAR(4) = 'NO',          -- Generar RF_Complemento.
        @nFactorDiv        INT,                        -- 100 para importes en centavos.
        @sUnidad_Med_Vta   VARCHAR(10),                -- UOM convertida a catálogo T3.
        @nItmTasa_IVA      NUMERIC(22,7);              -- Tasa calculada por partida.

    ---------------------------------------------------------------------------
    -- Variables que reciben una fila de Tmp_Document_Header
    -- El prefijo Doc_ indica datos de cabecera del documento.
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- ETAPA 1: Obtener la cabecera temporal
    --
    -- LOCAL       : el cursor sólo existe durante esta ejecución.
    -- FAST_FORWARD: recorrido únicamente hacia adelante y de sólo lectura.
    --
    -- Aunque normalmente ReferenceID representa una cabecera, se conserva el
    -- recorrido para respetar el comportamiento del procedimiento migrado.
    ---------------------------------------------------------------------------
    DECLARE ScrGeneral CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Head.FacturaSAP,                         -- Folio recibido desde SAP.
            SUBSTRING(Head.FacturaSAP, 1, 3),       -- Prefijo del folio SAP.
            Head.ShippingPoint,                     -- Centro/punto de expedición.
            Head.ReferenceID,                      -- Referencia de integración.
            TRY_CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            TRY_CONVERT(DATE, SUBSTRING(Head.Fecha_Vencimiento, 1, 8), 112),
            -- C004 se transforma en C006 para la preventa.
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
            -- Calcula la tasa de IVA de la cabecera; evita división entre cero.
            CASE
                WHEN ISNULL(Head.Valor_Subt, 0) = 0 THEN 0
                ELSE ROUND(ISNULL(Head.Valor_IVA, 0) * 100.0 / ISNULL(Head.Valor_Subt, 0), 0)
            END,
            -- DocumentDate contiene fecha y hora como texto; aquí se arma HH:mm:ss.
            SUBSTRING(Head.DocumentDate, 10, 2) + ':' +
            SUBSTRING(Head.DocumentDate, 12, 2) + ':' +
            SUBSTRING(Head.DocumentDate, 14, 2),
            Head.CompanyCode,
            ISNULL(Lib.LiberaAuto, 'TBC')
        FROM [EAI_Owner].[Tmp_Document_Header] AS Head
        -- PDV A51 indica si el cliente tiene una regla de liberación automática.
        LEFT JOIN
        (
            SELECT [Source] AS Cliente_SAP,
                   ISNULL([Target], 'NO') AS LiberaAuto
            FROM [EAI_Owner].[MX_HashTable]
            WHERE [Type] = 'PDV A51'
        ) AS Lib
            ON Head.Cust_to_SAP = Lib.Cliente_SAP
        WHERE Head.ReferenceID = @sInvoiceID;

    ---------------------------------------------------------------------------
    -- ETAPA 2: Procesar cada cabecera encontrada
    ---------------------------------------------------------------------------
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
            -- Cada cabecera debe recalcular estas banderas desde su estado inicial.
            SET @sRF_Comp = 'NO';

            -- Estas clases manejan importes recibidos en centavos.
            SET @nFactorDiv = CASE
                                  WHEN @Doc_Clase_Factura IN ('C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031') THEN 100
                                  ELSE 1
                              END;

            -------------------------------------------------------------------
            -- ETAPA 3: Determinar el folio que identificará la preventa
            -------------------------------------------------------------------
            IF @Doc_Clase_Factura IN ('C020', 'C021', 'C022')
            BEGIN
                -- El folio se genera mediante la regla central de facturación.
                EXEC [EAI_Owner].[WA_FOLIO_FACTURA]
                    @Doc_Factura, @Doc_Centro, @Doc_Clase_Factura, @Doc_Fecha_Factura, 0, @sFacturaV3 OUTPUT;
            END
            ELSE IF @Doc_Clase_Factura IN ('C005', 'C006')
            BEGIN
                -- Para estas clases la referencia ya contiene el folio; se
                -- elimina el segmento técnico "-O-".
                SET @sFacturaV3 = REPLACE(@Doc_Referencia, '-O-', '-');
            END
            ELSE IF @Doc_Clase_Factura IN ('C019', 'C0FX', 'C025')
            BEGIN
                -- Además de usar la referencia, estas clases generan complemento RF.
                SET @sRF_Comp = 'SI';
                SET @sFacturaV3 = @Doc_Referencia;
            END
            ELSE IF @Doc_Clase_Factura IN ('C030', 'C031')
            BEGIN
                -- Requieren complemento RF y un folio calculado.
                SET @sRF_Comp = 'SI';
                EXEC [EAI_Owner].[WA_FOLIO_FACTURA]
                    @Doc_Factura, @Doc_Centro, @Doc_Clase_Factura, @Doc_Fecha_Factura, 0, @sFacturaV3 OUTPUT;
            END
            ELSE
            BEGIN
                -- Regla general: se conserva el número de factura SAP.
                SET @sFacturaV3 = @Doc_Factura;
            END;

            -------------------------------------------------------------------
            -- ETAPA 4: Verificar si el folio puede volver a procesarse
            --
            -- Si no existe en Preventa_General, se procesa.
            -- Si existe, sólo se procesa cuando Fecha_Proc_BATMD está pendiente
            -- o contiene la fecha centinela posterior al año 2999.
            -------------------------------------------------------------------
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
                ----------------------------------------------------------------
                -- ETAPA 5: Calcular totales de cabecera
                ----------------------------------------------------------------
                -- TBD significa "To Be Determined" y evita una ubicación vacía.
                IF @sUbicacion IS NULL OR LEN(@sUbicacion) = 0
                    SET @sUbicacion = 'TBD';

                -- Suma las bonificaciones de todas las partidas de la referencia.
                SELECT @nBonif_Subt = ISNULL(SUM(ISNULL(Det.Bonif_Subt, 0) / @nFactorDiv), 0)
                FROM [EAI_Owner].[Tmp_Document_Detail] AS Det
                WHERE Det.ReferenceID = @sInvoiceID;

                -- Calcula IVA y porcentaje de bonificación a nivel documento.
                SET @nBonif_IVA = ROUND(@nBonif_Subt * @Doc_Tasa_IVA / 100.0, 2);

                IF @Doc_Valor_Subt > 0
                    SET @nBonif_Porc = ROUND((@nBonif_Subt * 100.0) / @Doc_Valor_Subt, 2);
                ELSE
                    SET @nBonif_Porc = 0;

                -- Convierte los importes a la escala monetaria esperada por T3.
                SET @nFact_Subt = ROUND(ISNULL(@Doc_Valor_Subt, 0) / @nFactorDiv, 2);
                SET @nFact_IVA = ROUND(ISNULL(@Doc_Valor_IVA, 0) / @nFactorDiv, 2);

                -- Para estas clases el subtotal recibido incluye el IVA.
                IF @Doc_Clase_Factura IN ('C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031')
                    SET @nFact_Subt = @nFact_Subt - @nFact_IVA;

                ----------------------------------------------------------------
                -- ETAPA 6: Reconstruir la preventa de forma idempotente
                --
                -- Primero elimina cualquier versión anterior del mismo folio.
                -- Así se evita duplicar información durante un reproceso.
                ----------------------------------------------------------------
                DELETE FROM [T3].[Preventa_General] WHERE Factura = @sFacturaV3;
                DELETE FROM [T3].[Preventa_Detalle] WHERE Factura = @sFacturaV3;
                DELETE FROM [T3].[Preventa_Condiciones] WHERE Factura = @sFacturaV3;

                -- La sociedad MX10 siempre requiere información complementaria RF.
                IF @Doc_CompanyCode = 'MX10'
                    SET @sRF_Comp = 'SI';

                IF @sRF_Comp = 'SI'
                BEGIN
                    -- RF_Complemento guarda hora, sociedad y días de crédito.
                    DELETE FROM [T3].[RF_Complemento] WHERE Factura = @sFacturaV3;

                    INSERT INTO [T3].[RF_Complemento]
                        (Factura, Hora_Factura, Sociedad, Dias_Pago)
                    VALUES
                        (@sFacturaV3, CONVERT(VARCHAR(8), GETDATE(), 108), @Doc_CompanyCode,
                         DATEDIFF(DAY, @Doc_Fecha_Factura, @Doc_Fecha_Pago));
                END;

                -- Inserta una sola cabecera operativa para el folio calculado.
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

                -- Copia las condiciones temporales conservando número de línea,
                -- tipo de condición e importe.
                INSERT INTO [T3].[Preventa_Condiciones]
                    (Factura, Num_Linea, Condicion, Importe)
                SELECT @sFacturaV3,
                       ItemID,
                       [Condition],
                       Amount
                FROM [EAI_Owner].[tmp_Document_Detail_Cond]
                WHERE ReferenceID = @sInvoiceID;

                ----------------------------------------------------------------
                -- Variables de una partida
                -- El prefijo Itm_ identifica valores obtenidos por ScrDetalle.
                ----------------------------------------------------------------
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

                ----------------------------------------------------------------
                -- ETAPA 7: Agrupar y procesar las partidas
                --
                -- El origen puede contener varias filas para la misma combinación
                -- de factura, línea, material, UOM y estado. El GROUP BY las
                -- consolida antes de calcular los importes finales.
                ----------------------------------------------------------------
                IF @Doc_Clase_Factura NOT IN ('C030', 'C031')
                BEGIN
                    ----------------------------------------------------------------
                    -- RUTA RÁPIDA: cálculo e inserción por conjunto.
                    --
                    -- El LEFT JOIN a T3.Material se conserva intencionalmente.
                    -- Aunque no se proyectan columnas de Mat, su participación
                    -- forma parte de la regla de negocio vigente.
                    ----------------------------------------------------------------
                    ;WITH DetailData AS
                    (
                        SELECT
                            SUBSTRING(Head.FacturaSAP, 1, 3) AS Prefijo,
                            Det.ItemID AS Num_Linea,
                            COALESCE
                            (
                                CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))
                            ) AS Material,
                            ISNULL(Det.UnidadMedida, 'UA') AS Unidad_Med_Vta,
                            CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END AS Status_Prod,
                            MAX(CONVERT(NUMERIC(22,7), 0)) AS Tasa_IEPS,
                            SUM(CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE Det.Cantidad END) AS Cantidad_Vta,
                            SUM(ISNULL(Det.Valor_Subt, 0)) AS Valor_Subt,
                            SUM(ISNULL(Det.Valor_IVA, 0)) AS Valor_IVA,
                            SUM(CONVERT(NUMERIC(22,7), 0)) AS Valor_ISSA,
                            SUM(ISNULL(Det.Bonif_Subt, 0)) AS Bonif_Subt,
                            SUM(CONVERT(NUMERIC(22,7), 0)) AS Bonif_Vol,
                            SUM(ISNULL(Det.Envio_Subt, 0)) AS Envio_Subt
                        FROM [EAI_Owner].[Tmp_Document_Header] AS Head
                        INNER JOIN [EAI_Owner].[Tmp_Document_Detail] AS Det
                            ON Head.ReferenceID = Det.ReferenceID
                        LEFT JOIN [T3].[Material] AS Mat
                            ON COALESCE
                               (
                                   CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                   LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))
                               ) = Mat.Material
                        WHERE Head.ReferenceID = @sInvoiceID
                        GROUP BY
                            SUBSTRING(Head.FacturaSAP, 1, 3),
                            Det.ItemID,
                            COALESCE
                            (
                                CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))
                            ),
                            ISNULL(Det.UnidadMedida, 'UA'),
                            CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END
                    ),
                    BaseCalc AS
                    (
                        SELECT
                            D.Prefijo,
                            D.Num_Linea,
                            LTRIM(RTRIM(D.Material)) AS Material,
                            D.Cantidad_Vta,
                            D.Unidad_Med_Vta,
                            D.Status_Prod,
                            D.Valor_ISSA,
                            D.Bonif_Vol,
                            ROUND(ISNULL(D.Valor_Subt, 0) / @nFactorDiv, 2) AS Det_Subt,
                            ROUND(ISNULL(D.Valor_IVA, 0) / @nFactorDiv, 2) AS Det_IVA,
                            ROUND
                            (
                                ROUND(ISNULL(D.Bonif_Subt, 0) / @nFactorDiv, 2)
                                * (100 + D.Tasa_IEPS) / 100.0,
                                2
                            ) AS Det_Bonif,
                            ROUND(ISNULL(D.Envio_Subt, 0) / @nFactorDiv, 2) AS Det_EnvioSubt,
                            CASE
                                WHEN ISNULL(D.Valor_Subt, 0) = 0 THEN CONVERT(NUMERIC(22,7), 0)
                                ELSE ROUND(ISNULL(D.Valor_IVA, 0) * 100.0 / ISNULL(D.Valor_Subt, 0), 0)
                            END AS Tasa_IVA,
                            CASE
                                WHEN D.Valor_Subt > 0
                                    THEN ROUND((D.Bonif_Subt * 100.0) / D.Valor_Subt, 2)
                                ELSE CONVERT(NUMERIC(22,7), 0)
                            END AS Bonif_Porc
                        FROM DetailData AS D
                    ),
                    LineCalc AS
                    (
                        SELECT
                            B.*,
                            CASE
                                WHEN B.Det_EnvioSubt > 0
                                    THEN ROUND(B.Det_EnvioSubt * B.Tasa_IVA / 100.0, 2)
                                ELSE CONVERT(NUMERIC(22,7), 0)
                            END AS Det_EnvioIVA,
                            ROUND(B.Det_Bonif * B.Tasa_IVA / 100.0, 2) AS Det_BonifIVA,
                            B.Det_Subt - B.Det_EnvioSubt AS Det_Subt_Neto
                        FROM BaseCalc AS B
                    ),
                    ClassCalc AS
                    (
                        SELECT
                            L.*,
                            CASE
                                WHEN @Doc_Clase_Factura IN ('C005', 'C006')
                                    THEN L.Det_IVA - L.Det_EnvioIVA
                                ELSE L.Det_IVA
                            END AS IVA_Clase
                        FROM LineCalc AS L
                    ),
                    ReleaseCalc AS
                    (
                        SELECT
                            C.*,
                            CASE
                                WHEN @Doc_LiberaAuto <> 'TBC' AND C.IVA_Clase > 0
                                    THEN ROUND(C.Det_Subt_Neto * 0.16, 2)
                                ELSE C.IVA_Clase
                            END AS IVA_Liberacion
                        FROM ClassCalc AS C
                    )
                    INSERT INTO [T3].[Preventa_Detalle]
                    (
                        Factura, Prefijo, Num_Linea, Material, Cantidad_Vta,
                        Unidad_Med_Vta, Referencia_Pedido, Status_Prod, Valor_Subt,
                        Valor_IVA, Valor_ISSA, Envio_Subt, Envio_IVA, Bonif_Subt,
                        Bonif_IVA, Bonif_Porc, Bonif_Vol
                    )
                    SELECT
                        @sFacturaV3,
                        R.Prefijo,
                        R.Num_Linea,
                        R.Material,
                        R.Cantidad_Vta,
                        [EAI_OWNER].[GETCONV]('ECC_V3 UOM', R.Unidad_Med_Vta),
                        R.Cantidad_Vta,
                        R.Status_Prod,
                        R.Det_Subt_Neto,
                        CASE
                            WHEN @Doc_Clase_Factura IN ('C025', 'C019')
                                THEN ROUND(R.Det_Subt_Neto * R.Tasa_IVA / 100.0, 2)
                            ELSE R.IVA_Liberacion
                        END,
                        R.Valor_ISSA,
                        R.Det_EnvioSubt,
                        R.Det_EnvioIVA,
                        R.Det_Bonif,
                        R.Det_BonifIVA,
                        CASE WHEN R.Bonif_Porc > 100 THEN 100 ELSE R.Bonif_Porc END,
                        R.Bonif_Vol
                    FROM ReleaseCalc AS R;
                END
                ELSE
                BEGIN
                    ----------------------------------------------------------------
                    -- RUTA ESPECIAL C030/C031.
                    -- Se conserva el recorrido original porque cada partida llama
                    -- WA_CANTIDAD_UMV y recibe cantidad/UOM mediante OUTPUT.
                    ----------------------------------------------------------------
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
                                -- Si el material es numérico elimina formato sobrante;
                                -- si no lo es, conserva el texto sin espacios laterales.
                                COALESCE(CONVERT(VARCHAR(18), TRY_CONVERT(NUMERIC(18,0), Det.Material)),
                                         LTRIM(RTRIM(CONVERT(VARCHAR(18), Det.Material)))) AS Material,
                                -- C019 fuerza cantidad uno por regla de negocio.
                                CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE Det.Cantidad END AS Cantidad_Vta,
                                -- UA es la unidad predeterminada si el XML no la informó.
                                ISNULL(Det.UnidadMedida, 'UA') AS Unidad_Med_Vta,
                                -- Un producto marcado MALO pasa a estatus Q.
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
                        -----------------------------------------------------------
                        -- ETAPA 8: Calcular importes de la partida actual
                        -----------------------------------------------------------
                        SET @nCantidad_Vta = @Itm_Cantidad_Vta;
    
                        -- Normaliza importes y redondea a dos decimales monetarios.
                        SET @nDet_Subt = ROUND(ISNULL(@Itm_Valor_Subt, 0) / @nFactorDiv, 2);
                        SET @nDet_IVA = ROUND(ISNULL(@Itm_Valor_IVA, 0) / @nFactorDiv, 2);
                        SET @nDet_Bonif = ROUND(ISNULL(@Itm_Bonif_Subt, 0) / @nFactorDiv, 2);
                        -- La bonificación incorpora la tasa IEPS de la partida.
                        SET @nDet_Bonif = ROUND((@nDet_Bonif * (100 + @Itm_Tasa_IEPS)) / 100.0, 2);
                        SET @nDet_EnvioSubt = ROUND(ISNULL(@Itm_Envio_Subt, 0) / @nFactorDiv, 2);
    
                        -- Obtiene la tasa efectiva de IVA sin dividir entre cero.
                        IF ISNULL(@Itm_Valor_Subt, 0) = 0
                            SET @nItmTasa_IVA = 0;
                        ELSE
                            SET @nItmTasa_IVA = ROUND(ISNULL(@Itm_Valor_IVA, 0) * 100.0 / ISNULL(@Itm_Valor_Subt, 0), 0);
    
                        -- Calcula el IVA asociado a la bonificación.
                        SET @nDet_BonifIVA = ROUND(@nDet_Bonif * @nItmTasa_IVA / 100.0, 2);
    
                        IF @Itm_Valor_Subt > 0
                            SET @nBonif_Porc = ROUND((@Itm_Bonif_Subt * 100.0) / @Itm_Valor_Subt, 2);
                        ELSE
                            SET @nBonif_Porc = 0;
    
                        -- El costo de envío también genera IVA cuando es positivo.
                        IF @nDet_EnvioSubt > 0
                            SET @nDet_EnvioIVA = ROUND(@nDet_EnvioSubt * @nItmTasa_IVA / 100.0, 2);
                        ELSE
                            SET @nDet_EnvioIVA = 0;
    
                        -- Separa el envío del subtotal de mercancía.
                        SET @nDet_Subt = @nDet_Subt - @nDet_EnvioSubt;
    
                        -- C005/C006 reciben el IVA de envío incluido en el IVA total.
                        IF @Doc_Clase_Factura IN ('C005', 'C006')
                            SET @nDet_IVA = @nDet_IVA - @nDet_EnvioIVA;
    
                        -- Cuando existe regla de liberación automática, recalcula
                        -- IVA al 16 % para valores positivos.
                        IF @Doc_LiberaAuto <> 'TBC' AND @nDet_IVA > 0
                            SET @nDet_IVA = ROUND(@nDet_Subt * 0.16, 2);
    
                        -- Normaliza material y traduce la UOM de ECC al catálogo V3.
                        SET @sMaterial = LTRIM(RTRIM(@Itm_Material));
                        SET @sUnidad_Med_Vta = [EAI_OWNER].[GETCONV]('ECC_V3 UOM', @Itm_Unidad_Med_Vta);
    
                        -- Estas clases requieren conversión especial de cantidad y UOM.
                        IF @Doc_Clase_Factura IN ('C030', 'C031')
                        BEGIN
                            EXEC [EAI_OWNER].[WA_CANTIDAD_UMV]
                                @sMaterial, @Itm_Cantidad_Vta, @Itm_Unidad_Med_Vta,
                                @nCantidad_Vta OUTPUT, @sUnidad_Med_Vta OUTPUT;
                        END;
    
                        -- Para C025/C019 el IVA se recalcula desde el subtotal neto.
                        IF @Doc_Clase_Factura IN ('C025', 'C019')
                            SET @nDet_IVA = ROUND(@nDet_Subt * @nItmTasa_IVA / 100.0, 2);
    
                        -- Una bonificación nunca puede superar el 100 % de la línea.
                        IF @nBonif_Porc > 100
                            SET @nBonif_Porc = 100;
    
                        -- Persiste la partida ya normalizada en el modelo operativo T3.
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
                END
            END;

            -- Continúa con otra cabecera si la referencia devolvió más de una.
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

        -----------------------------------------------------------------------
        -- ETAPA 9: Recalcular los totales definitivos desde el detalle insertado
        --
        -- El detalle es la fuente final porque ya contiene redondeos, descuentos
        -- y separación de envío. OUTER APPLY permite devolver ceros aun cuando
        -- no existan partidas para el folio.
        -----------------------------------------------------------------------
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

        -----------------------------------------------------------------------
        -- ETAPA 10: Procesos posteriores y cierre
        -----------------------------------------------------------------------
        -- Genera/actualiza la entrega asociada a la referencia temporal.
        EXEC [EAI_OWNER].[INVOICE_TO_ENTREGA_PO] @sInvoiceID, 0;

        -- Marca la cabecera temporal para que no vuelva a seleccionarse como pendiente.
        UPDATE [EAI_Owner].[Tmp_Document_Header]
           SET Procesado = GETDATE()
         WHERE ReferenceID = @sInvoiceID;

        -- Devuelve al llamador el folio realmente utilizado en las tablas T3.
        SET @pFolioFiscal = @sFacturaV3;

        -- Ejecuta las reglas complementarias de entrega para OXXO.
        EXEC [T3].[DELIVERY_WA_OXXO] @sFacturaV3, 1, 0;
    END TRY
    BEGIN CATCH
        -----------------------------------------------------------------------
        -- MANEJO DE ERRORES
        --
        -- Libera ScrGeneral si el error ocurrió durante su recorrido, registra
        -- el detalle y relanza la excepción. El THROW permite que el llamador
        -- decida si debe revertir su transacción o reintentar el mensaje.
        -----------------------------------------------------------------------
        -- ScrDetalle sólo existe en la ruta especial C030/C031.
        IF CURSOR_STATUS('local', 'ScrDetalle') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'ScrDetalle') > -1
                CLOSE ScrDetalle;
            DEALLOCATE ScrDetalle;
        END;

        IF CURSOR_STATUS('local', 'ScrGeneral') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'ScrGeneral') > -1
                CLOSE ScrGeneral;
            DEALLOCATE ScrGeneral;
        END;

        -- Formato estándar utilizado por las bitácoras de integración.
        SET @sErrorCode = 'SQL-' + CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(20), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, STATUS, QUEUE_NAME,
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT,
             SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Sending to T3', @v_ID, GETDATE(), NULL, 'Error', 'Invoice to T3',
             @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL);

        -- Conserva número, severidad y línea del error original.
        THROW;
    END CATCH;
END;
GO




