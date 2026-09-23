SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
    Procedure : EAI_OWNER.INVOICE_TO_FACTURA

    Objetivo
    --------
    Transformar el encabezado y los detalles temporales de una factura en las
    tablas definitivas T3. Esta version conserva las reglas del procedimiento
    original, pero elimina sus tres cursores y procesa el detalle por conjuntos.

    Guia rapida para un developer Jr
    ---------------------------------
    1. Leer el encabezado temporal identificado por @sInvoiceID.
    2. Validar si la factura puede reconstruirse.
    3. Calcular e insertar encabezado y complemento fiscal.
    4. Agrupar, convertir y calcular todas las lineas en una sola operacion.
    5. Recalcular los totales del encabezado desde el detalle insertado.
    6. Marcar el temporal como procesado y generar la entrega relacionada.

    La version original EAI_OWNER.INVOICE_TO_FACTURA no es modificada por este
    script. El cambio del llamador debe realizarse solo despues del benchmark.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.INVOICE_TO_FACTURA
    @sInvoiceID    VARCHAR(30),
    @pFolioFiscal VARCHAR(30) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Oracle inicia los parametros OUT en NULL. Se replica expresamente.
    SET @pFolioFiscal = NULL;

    BEGIN TRY
        DECLARE
            @sMsg                VARCHAR(500) = NULL,
            @sErrorCode          VARCHAR(500) = NULL,
            @v_ID                VARCHAR(30) = @sInvoiceID,
            @sProcesar           VARCHAR(2) = 'NO',
            @sFacturaV3          VARCHAR(30) = NULL,
            @nBonif_Subt         NUMERIC(22,7) = 0,
            @nBonif_IVA          NUMERIC(22,7) = 0,
            @nBonif_Porc         NUMERIC(22,7) = 0,
            @sUbicacion          VARCHAR(4) = NULL,
            @nFact_Subt          NUMERIC(22,7) = 0,
            @nFact_IVA           NUMERIC(22,7) = 0,
            @nFactorDiv          INT = 1,
            @Distribuidor        VARCHAR(30) = NULL,
            @Entrega             VARCHAR(30) = NULL,
            @Fecha_Factura       DATE = NULL,
            @Fecha_Pago          DATE = NULL,
            @Clase_Factura       VARCHAR(10) = NULL,
            @Cliente_V3          VARCHAR(30) = NULL,
            @Cliente_SAP         VARCHAR(30) = NULL,
            @Clte_Factura_SAP    VARCHAR(30) = NULL,
            @Pedido              VARCHAR(30) = NULL,
            @Valor_Subt          NUMERIC(22,7) = NULL,
            @Valor_IVA           NUMERIC(22,7) = NULL,
            @Referencia          VARCHAR(30) = NULL,
            @Valor_ISSA          NUMERIC(22,7) = 0,
            @Ctro                VARCHAR(30) = NULL,
            @Tasa_IVA            NUMERIC(22,7) = 0,
            @HeaderRows          INT = 0;

        -----------------------------------------------------------------------
        -- 1. Encabezado
        -----------------------------------------------------------------------
        /*
            ScrGeneral normalmente devuelve una sola fila por ReferenceID.
            La asignacion directa elimina el cursor sin crear una tabla temporal.
            Las funciones escalares se ejecutan una sola vez por encabezado.
        */
        SELECT
            @Distribuidor     = EAI.CONV_PLANT_TO_DIST(Head.ShippingPoint),
            @Entrega          = Head.ReferenceID,
            @Fecha_Factura    = CONVERT(DATE, SUBSTRING(Head.DocumentDate, 1, 8), 112),
            @Fecha_Pago       = CONVERT(DATE, SUBSTRING(Head.Fecha_Vencimiento, 1, 8), 112),
            @Clase_Factura    = CASE
                                    WHEN Head.DeliveryType = 'C005' THEN 'C003'
                                    WHEN Head.DeliveryType = 'C006' THEN 'C004'
                                    ELSE Head.DeliveryType
                                END,
            @Cliente_V3       = EAI_OWNER.FN_GET_CLIENTE_TMD(Head.Cust_to_SAP),
            @Cliente_SAP      = Head.Cust_to_SAP,
            @Clte_Factura_SAP = ISNULL(Head.Bill_to_SAP, Head.Cust_to_SAP),
            @Pedido           = Head.PedidoSAP,
            @Valor_Subt       = ISNULL(Head.Valor_Subt, 0),
            @Valor_IVA        = ISNULL(Head.Valor_IVA, 0),
            @Referencia       = Head.PedidoV3,
            @Ctro             = Head.ShippingPoint,
            @Tasa_IVA         = CASE
                                    WHEN ISNULL(Head.Valor_Subt, 0) = 0 THEN 0
                                    ELSE ROUND(ISNULL(Head.Valor_IVA, 0) * 100.0
                                               / ISNULL(Head.Valor_Subt, 0), 0)
                                END
        FROM EAI_OWNER.TMP_DOCUMENT_HEADER AS Head
        WHERE Head.ReferenceID = @sInvoiceID;

        SET @HeaderRows = @@ROWCOUNT;

        IF @HeaderRows > 0
        BEGIN
            SET @nFactorDiv = CASE
                                  WHEN @Clase_Factura IN ('C005', 'C006', 'C003', 'C004') THEN 100
                                  ELSE 1
                              END;
            SET @sFacturaV3 = @Referencia;

            -------------------------------------------------------------------
            -- 2. Validacion de reejecucion
            -------------------------------------------------------------------
            /*
                El cursor ScrValida devolvia SI cuando la factura no existia,
                no habia sido procesada o conservaba la fecha centinela 2999.
            */
            SET @sProcesar = 'SI';

            SELECT
                @sProcesar = CASE
                                WHEN FG.Fecha_Proc_BATMD IS NULL THEN 'SI'
                                WHEN FG.Fecha_Proc_BATMD > CONVERT(DATE, '29990101', 112) THEN 'SI'
                                ELSE 'NO'
                             END
            FROM T3.Factura_General AS FG
            WHERE FG.Factura = @sFacturaV3;

            IF @sProcesar = 'SI'
            BEGIN
                -- Oracle utiliza TBD porque sUbicacion no recibe otro valor.
                IF @sUbicacion IS NULL OR LEN(@sUbicacion) = 0
                    SET @sUbicacion = 'TBD';

                SELECT
                    @nBonif_Subt = ISNULL(SUM(ISNULL(Det.Bonif_Subt, 0) / @nFactorDiv), 0)
                FROM EAI_OWNER.TMP_DOCUMENT_DETAIL AS Det
                WHERE Det.ReferenceID = @sInvoiceID;

                SET @nBonif_IVA = ROUND(@nBonif_Subt * @Tasa_IVA / 100.0, 2);
                SET @nBonif_Porc = CASE
                                       WHEN @Valor_Subt > 0
                                           THEN ROUND((@nBonif_Subt * 100.0) / @Valor_Subt, 2)
                                       ELSE 0
                                   END;
                SET @nFact_Subt = ROUND(ISNULL(@Valor_Subt, 0) / @nFactorDiv, 2);
                SET @nFact_IVA  = ROUND(ISNULL(@Valor_IVA, 0) / @nFactorDiv, 2);

                IF @Clase_Factura IN ('C003', 'C004', 'C005', 'C006', 'C019', 'C0FX', 'C025', 'C030', 'C031')
                    SET @nFact_Subt = @nFact_Subt - @nFact_IVA;

                ----------------------------------------------------------------
                -- 3. Reconstruccion del documento
                ----------------------------------------------------------------
                DELETE FROM T3.Factura_General WHERE Factura = @sFacturaV3;
                DELETE FROM T3.Factura_Detalle WHERE Factura = @sFacturaV3;
                DELETE FROM T3.RF_Complemento  WHERE Factura = @sFacturaV3;

                INSERT INTO T3.RF_Complemento
                (
                    Factura, Hora_Factura, Anio_Aprob, Folio_Aprob, Order_Num,
                    Rep_ID, X_DelRep_Invloc, Volumen, Sociedad, Cadena_Original,
                    Sello_Digital, Dias_Pago
                )
                VALUES
                (
                    @sFacturaV3, CONVERT(VARCHAR(8), GETDATE(), 108), 'Error',
                    'Error', '', 'U00000000', '', NULL, 'MX06',
                    'CFDI - Documento', 'CFDI - Documento',
                    DATEDIFF(DAY, @Fecha_Factura, @Fecha_Pago)
                );

                INSERT INTO T3.Factura_General
                (
                    Factura, Entrega, Distribuidor, Cliente_V3, Fecha_Factura,
                    Ubicacion, Fecha_Pago, Row_ID, Fecha_TRN, Tipo_Docto,
                    Cliente_SAP, Clte_Factura_SAP, Pedido, Valor_Subt, Valor_IVA,
                    Referencia, Valor_ISSA, Ctro, Bonif_Subt, Bonif_IVA,
                    Bonif_Porc, Bonif_Vol
                )
                VALUES
                (
                    @sFacturaV3, @Entrega, @Distribuidor, @Cliente_V3,
                    @Fecha_Factura, @sUbicacion, @Fecha_Pago, @Entrega, GETDATE(),
                    @Clase_Factura, @Cliente_SAP, @Clte_Factura_SAP, @Pedido,
                    @nFact_Subt, @nFact_IVA, @Referencia, @Valor_ISSA, @Ctro,
                    @nBonif_Subt, @nBonif_IVA, @nBonif_Porc, 0
                );

                ----------------------------------------------------------------
                -- 4. Detalle set-based
                ----------------------------------------------------------------
                /*
                    DetailBase conserva el JOIN a T3.Material del original. Ademas
                    utiliza Unidad_Med_Vta y Cig_x_CLL para integrar en la misma
                    consulta la regla de WA_CANTIDAD_UMV aplicada a C030/C031.
                */
                ;WITH DetailBase AS
                (
                    SELECT
                        Det.ItemID AS Num_Linea,
                        CONVERT(VARCHAR(18), CONVERT(NUMERIC(38,0), TRIM(Det.Material))) AS Material,
                        ISNULL(Det.UnidadMedida, 'UA') AS Unidad_Med_Vta,
                        CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END AS Status_Prod,
                        CAST(0 AS NUMERIC(22,7)) AS Tasa_IEPS,
                        SUM(CASE WHEN @Clase_Factura = 'C019' THEN 1 ELSE Det.Cantidad END) AS Cantidad_Vta,
                        SUM(ISNULL(Det.Valor_Subt, 0)) AS Valor_Subt,
                        SUM(ISNULL(Det.Valor_IVA, 0)) AS Valor_IVA,
                        CAST(0 AS NUMERIC(22,7)) AS Valor_ISSA,
                        SUM(ISNULL(Det.Bonif_Subt, 0)) AS Bonif_Subt,
                        CAST(0 AS NUMERIC(22,7)) AS Bonif_Vol,
                        SUM(ISNULL(Det.Envio_Subt, 0)) AS Envio_Subt,
                        SUM(ISNULL(Det.Credito_Subt, 0)) AS Credito_Subt,
                        MAX(Mat.Unidad_Med_Vta) AS Material_UMV,
                        MAX(Mat.Cig_x_CLL) AS Material_PackSize
                    FROM EAI_OWNER.TMP_DOCUMENT_HEADER AS Head
                    INNER JOIN EAI_OWNER.TMP_DOCUMENT_DETAIL AS Det
                        ON Det.ReferenceID = Head.ReferenceID
                    LEFT JOIN T3.Material AS Mat
                        ON Mat.Material = CONVERT(VARCHAR(18), CONVERT(NUMERIC(38,0), TRIM(Det.Material)))
                    WHERE Head.ReferenceID = @sInvoiceID
                    GROUP BY
                        Det.ItemID,
                        CONVERT(VARCHAR(18), CONVERT(NUMERIC(38,0), TRIM(Det.Material))),
                        ISNULL(Det.UnidadMedida, 'UA'),
                        CASE WHEN Det.Status_Producto = 'MALO' THEN 'Q' ELSE ' ' END
                ),
                DetailMapped AS
                (
                    SELECT
                        B.*,
                        COALESCE(UOM.Target, B.Unidad_Med_Vta) AS Unidad_Mapeada
                    FROM DetailBase AS B
                    OUTER APPLY
                    (
                        SELECT TOP (1) HT.Target
                        FROM EAI_OWNER.MX_HashTable AS HT
                        WHERE HT.Type = 'ECC_V3 UOM'
                          AND HT.Source = B.Unidad_Med_Vta
                    ) AS UOM
                ),
                DetailConverted AS
                (
                    SELECT
                        M.*,
                        CASE
                            WHEN @Clase_Factura IN ('C030', 'C031')
                             AND M.Unidad_Med_Vta = 'MIL'
                             AND ISNULL(M.Material_PackSize, 0) > 0
                                THEN M.Cantidad_Vta * 1000.0 / M.Material_PackSize
                            WHEN @Clase_Factura IN ('C030', 'C031')
                             AND M.Unidad_Med_Vta IN ('PZ', 'PCE')
                             AND ISNULL(M.Material_PackSize, 0) > 0
                                THEN M.Cantidad_Vta / M.Material_PackSize
                            ELSE M.Cantidad_Vta
                        END AS Cantidad_Final,
                        CASE
                            WHEN @Clase_Factura IN ('C030', 'C031')
                             AND M.Unidad_Med_Vta IN ('MIL', 'PZ', 'PCE')
                             AND ISNULL(M.Material_PackSize, 0) > 0
                                THEN M.Material_UMV
                            ELSE M.Unidad_Mapeada
                        END AS Unidad_Final,
                        ROUND(ISNULL(M.Valor_Subt, 0) / @nFactorDiv, 2) AS Subt_Inicial,
                        ROUND(ISNULL(M.Valor_IVA, 0) / @nFactorDiv, 2) AS IVA_Inicial,
                        ROUND(
                            ROUND(ISNULL(M.Bonif_Subt, 0) / @nFactorDiv, 2)
                            * (100 + M.Tasa_IEPS) / 100.0, 2) AS Bonif_Final,
                        ROUND(ISNULL(M.Envio_Subt, 0) / @nFactorDiv, 2) AS Envio_Final,
                        ROUND(ISNULL(M.Credito_Subt, 0) / @nFactorDiv, 2) AS Credito_Final,
                        CASE
                            WHEN ISNULL(M.Valor_Subt, 0) = 0 THEN 0
                            ELSE ROUND(ISNULL(M.Valor_IVA, 0) * 100.0
                                       / ISNULL(M.Valor_Subt, 0), 0)
                        END AS Tasa_IVA_Item
                    FROM DetailMapped AS M
                ),
                DetailCalculated AS
                (
                    SELECT
                        C.*,
                        C.Subt_Inicial - C.Envio_Final - C.Credito_Final AS Subt_Final,
                        ROUND(C.Bonif_Final * C.Tasa_IVA_Item / 100.0, 2) AS Bonif_IVA_Final,
                        CASE
                            WHEN C.Valor_Subt > 0
                                THEN ROUND(C.Bonif_Subt * 100.0
                                           / (C.Bonif_Subt + C.Valor_Subt), 2)
                            ELSE 0
                        END AS Bonif_Porc_Final,
                        CASE WHEN C.Envio_Final > 0
                             THEN ROUND(C.Envio_Final * C.Tasa_IVA_Item / 100.0, 2)
                             ELSE 0 END AS Envio_IVA_Final,
                        CASE WHEN C.Credito_Final > 0
                             THEN ROUND(C.Credito_Final * C.Tasa_IVA_Item / 100.0, 2)
                             ELSE 0 END AS Credito_IVA_Final
                    FROM DetailConverted AS C
                ),
                DetailFinal AS
                (
                    SELECT
                        C.*,
                        CASE
                            WHEN @Clase_Factura IN ('C025', 'C019')
                                THEN ROUND(C.Subt_Final * C.Tasa_IVA_Item / 100.0, 2)
                            WHEN @Clase_Factura IN ('C005', 'C006', 'C003', 'C004')
                                THEN C.IVA_Inicial - C.Envio_IVA_Final - C.Credito_IVA_Final
                            ELSE C.IVA_Inicial
                        END AS IVA_Final
                    FROM DetailCalculated AS C
                )
                INSERT INTO T3.Factura_Detalle
                (
                    Factura, Num_Linea, Material, Cantidad_Vta, Unidad_Med_Vta,
                    Status_Prod, Valor_Subt, Valor_IVA, Valor_ISSA, Envio_Subt,
                    Envio_IVA, Precio_Unit, Valor_Tot, Credito_Subt, Credito_IVA,
                    Bonif_Subt, Bonif_IVA, Bonif_Porc, Bonif_Vol
                )
                SELECT
                    @sFacturaV3,
                    D.Num_Linea,
                    TRIM(D.Material),
                    D.Cantidad_Final,
                    D.Unidad_Final,
                    D.Status_Prod,
                    D.Subt_Final,
                    D.IVA_Final,
                    D.Valor_ISSA,
                    D.Envio_Final,
                    D.Envio_IVA_Final,
                    -- NVL(cantidad, 1) de Oracle: NULL usa 1; cero conserva el error.
                    ROUND(ISNULL(D.Subt_Final, 0) / ISNULL(D.Cantidad_Final, 1), 2),
                    ISNULL(D.Subt_Final, 0) + ISNULL(D.IVA_Final, 0),
                    D.Credito_Final,
                    D.Credito_IVA_Final,
                    D.Bonif_Final,
                    D.Bonif_IVA_Final,
                    D.Bonif_Porc_Final,
                    D.Bonif_Vol
                FROM DetailFinal AS D;
            END;
        END;

        -----------------------------------------------------------------------
        -- 5. Totales finales
        -----------------------------------------------------------------------
        UPDATE FG
        SET
            Bonif_Subt    = Tot.Bonif_Subt,
            Bonif_IVA     = Tot.Bonif_IVA,
            Valor_Subt    = Tot.Valor_Subt,
            Valor_IVA     = Tot.Valor_IVA,
            Envio_Subt    = Tot.Envio_Subt,
            Envio_IVA     = Tot.Envio_IVA,
            Credito_Subt  = Tot.Credito_Subt,
            Credito_IVA   = Tot.Credito_IVA
        FROM T3.Factura_General AS FG
        CROSS APPLY
        (
            SELECT
                SUM(ISNULL(FD.Bonif_Subt, 0)) AS Bonif_Subt,
                SUM(ISNULL(FD.Bonif_IVA, 0)) AS Bonif_IVA,
                SUM(ISNULL(FD.Valor_Subt, 0)) AS Valor_Subt,
                SUM(ISNULL(FD.Valor_IVA, 0)) AS Valor_IVA,
                SUM(ISNULL(FD.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(FD.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(FD.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(FD.Credito_IVA, 0)) AS Credito_IVA
            FROM T3.Factura_Detalle AS FD
            WHERE FD.Factura = FG.Factura
        ) AS Tot
        WHERE FG.Factura = @sFacturaV3;

        -- Solo se marca procesado despues de completar todas las escrituras.
        UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER
        SET Procesado = GETDATE()
        WHERE ReferenceID = @sInvoiceID;

        EXEC EAI_OWNER.INVOICE_TO_ENTREGA_PO @sInvoiceID, 0;

        SET @pFolioFiscal = @sFacturaV3;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = LEFT(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, STATUS, QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
            RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Sending to T3', @v_ID, GETDATE(), NULL, 'Error', 'Invoice to T3',
            @sMsg, 'XML', @sErrorCode, NULL, NULL, NULL
        );

        -- Igual que Oracle y la version MSSQL actual, el error se registra y
        -- no se propaga al proceso integrador.
    END CATCH;
END;
GO
