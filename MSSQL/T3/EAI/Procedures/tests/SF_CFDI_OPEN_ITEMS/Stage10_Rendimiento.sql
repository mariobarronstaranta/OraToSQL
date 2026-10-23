        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            DECLARE @PasoInicio datetime2(3) = SYSDATETIME(), @Filas int, @Ms int;
            -- Materializar cabeceras elegibles ANTES de expandir sus detalles.
            -- No usar DISTINCT aqui: cabeceras duplicadas y vigencias solapadas
            -- participan en las sumas del procedimiento MSSQL de referencia.
            SELECT FG.Ctro, FG.Fecha_Factura, FG.Tipo_Docto, FG.Factura, FG.Cliente_SAP
            INTO #OIFactura
            FROM T3.Factura_General AS FG
            WHERE FG.Fecha_Factura >= @FechaInicio
              AND FG.Tipo_Docto IN ('C003', 'C004')
              AND NOT EXISTS (SELECT 1 FROM EAI.CFDI_OPEN_ITEMS AS OI
                              WHERE OI.Nota_Venta = FG.Factura)
            OPTION (RECOMPILE);
            SET @Filas = @@ROWCOUNT;
            CREATE CLUSTERED INDEX IX_OIFactura ON #OIFactura(Factura);
            SET @Ms = DATEDIFF(millisecond, @PasoInicio, SYSDATETIME());
            IF @Diagnostico = 1 RAISERROR('Historico: cabeceras Factura = %d; ms = %d', 10, 1, @Filas, @Ms) WITH NOWAIT;

            SET @PasoInicio = SYSDATETIME();
            SELECT PG.Ctro, PG.Fecha_Factura, PG.Clase_Factura, PG.Factura, PG.Cliente_SAP
            INTO #OIPreventa
            FROM T3.Preventa_General AS PG
            WHERE PG.Fecha_Factura >= @FechaInicio
              AND PG.Clase_Factura IN ('C005', 'C006', 'C019', 'C025')
              AND PG.Fecha_Proc_BATMD IS NOT NULL
              AND PG.Fecha_Cancelacion IS NULL
              AND NOT EXISTS (SELECT 1 FROM EAI.CFDI_OPEN_ITEMS AS OI
                              WHERE OI.Nota_Venta = PG.Factura)
            OPTION (RECOMPILE);
            SET @Filas = @@ROWCOUNT;
            CREATE CLUSTERED INDEX IX_OIPreventa ON #OIPreventa(Factura);
            SET @Ms = DATEDIFF(millisecond, @PasoInicio, SYSDATETIME());
            IF @Diagnostico = 1 RAISERROR('Historico: cabeceras Preventa = %d; ms = %d', 10, 1, @Filas, @Ms) WITH NOWAIT;

            SET @PasoInicio = SYSDATETIME();
            ;WITH HistoricItem AS
            (
                SELECT FG.Ctro, FG.Fecha_Factura AS Fecha_Venta,
                       FG.Tipo_Docto AS Clase_Factura, FG.Factura AS Nota_Venta,
                       FG.Cliente_SAP, C.RFC,
                       ISNULL(FD.Valor_Subt, 0) + ISNULL(FD.Valor_IVA, 0)
                     + ISNULL(FD.Credito_Subt, 0) + ISNULL(FD.Credito_IVA, 0)
                     + ISNULL(FD.Envio_Subt, 0) + ISNULL(FD.Envio_IVA, 0) AS Importe_Item
                FROM #OIFactura AS FG
                INNER JOIN T3.Factura_Detalle AS FD ON FD.Factura = FG.Factura
                INNER JOIN T3.Cliente AS C ON C.Cliente_SAP = FG.Cliente_SAP
                    AND FG.Fecha_Factura BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
                UNION ALL
                SELECT PG.Ctro, PG.Fecha_Factura, PG.Clase_Factura, PG.Factura,
                       PG.Cliente_SAP, C.RFC,
                       ISNULL(PD.Valor_Subt, 0) + ISNULL(PD.Valor_IVA, 0)
                     + ISNULL(PD.Credito_Subt, 0) + ISNULL(PD.Credito_IVA, 0)
                     + ISNULL(PD.Envio_Subt, 0) + ISNULL(PD.Envio_IVA, 0)
                FROM #OIPreventa AS PG
                INNER JOIN T3.Preventa_Detalle AS PD ON PD.Factura = PG.Factura
                INNER JOIN T3.Cliente AS C ON C.Cliente_SAP = PG.Cliente_SAP
                    AND PG.Fecha_Factura BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
            )
            SELECT Ctro, Fecha_Venta, Clase_Factura, Nota_Venta, Cliente_SAP, RFC,
                   SUM(Importe_Item) AS Importe_Venta
            INTO #OIHistoric
            FROM HistoricItem
            GROUP BY Ctro, Fecha_Venta, Clase_Factura, Nota_Venta, Cliente_SAP, RFC
            OPTION (RECOMPILE);
            SET @Filas = @@ROWCOUNT;
            CREATE CLUSTERED INDEX IX_OIHistoric ON #OIHistoric(Nota_Venta);
            DROP TABLE #OIFactura, #OIPreventa;
            SET @Ms = DATEDIFF(millisecond, @PasoInicio, SYSDATETIME());
            IF @Diagnostico = 1 RAISERROR('Historico: grupos de detalle = %d; ms = %d', 10, 1, @Filas, @Ms) WITH NOWAIT;

            SET @PasoInicio = SYSDATETIME();
            -- Una clave por folio Y tipo: el mismo folio puede aparecer como
            -- venta y devolucion. Estas claves no deben multiplicar cobranza.
            SELECT DISTINCT Nota_Venta,
                CASE WHEN Clase_Factura IN ('C003','C005') THEN 'Vta' ELSE 'Dev' END AS Tipo
            INTO #OIKeys FROM #OIHistoric;
            CREATE UNIQUE CLUSTERED INDEX IX_OIKeys ON #OIKeys(Tipo, Nota_Venta);

            -- Equivalencia con FN_COBZA_PAY y FN_COBZA_CM_UUID suministradas:
            -- ventas: toda cobranza por Factura, sin filtro de Via_Pago/UUID.
            -- devoluciones: por Nota_Credito, con Historia y documento con UUID.
            -- NO convertir los JOIN de devolucion a EXISTS ni deduplicar PAC:
            -- cada coincidencia contribuye a SUM, igual que la funcion original.
            -- El CAST conserva precision y error de desbordamiento de las UDF.
            SELECT K.Nota_Venta, K.Tipo,
                   CONVERT(numeric(15,2), SUM(ISNULL(C.Importe, 0))) AS Cobrado
            INTO #OIPaid
            FROM #OIKeys AS K
            INNER JOIN T3.CFDI_Cobranza AS C ON C.Factura = K.Nota_Venta
            WHERE K.Tipo = 'Vta'
            GROUP BY K.Nota_Venta, K.Tipo
            UNION ALL
            SELECT K.Nota_Venta, K.Tipo,
                   CONVERT(numeric(15,2), SUM(ISNULL(C.Importe, 0)))
            FROM #OIKeys AS K
            INNER JOIN T3.CFDI_Cobranza AS C ON C.Nota_Credito = K.Nota_Venta
            INNER JOIN T3.CFDI_Historia_Docto_PAC AS H ON H.Nota_Venta = C.Nota_Credito
            INNER JOIN T3.CFDI_Documentos AS D ON D.Nota_Venta = H.Nota_Venta_CFDI
            WHERE K.Tipo = 'Dev' AND D.Folio_Fiscal IS NOT NULL
            GROUP BY K.Nota_Venta, K.Tipo
            OPTION (RECOMPILE);
            SET @Filas = @@ROWCOUNT;
            CREATE UNIQUE CLUSTERED INDEX IX_OIPaid ON #OIPaid(Tipo, Nota_Venta);
            SET @Ms = DATEDIFF(millisecond, @PasoInicio, SYSDATETIME());
            IF @Diagnostico = 1 RAISERROR('Historico: grupos de cobranza = %d; ms = %d', 10, 1, @Filas, @Ms) WITH NOWAIT;

            INSERT INTO EAI.CFDI_OPEN_ITEMS
                (Ctro, Nota_Venta, Cliente_SAP, Clte_Factura_SAP,
                 Fecha_Venta, Tipo_Docto, Importe_Vta, Last_Updated)
            SELECT H.Ctro, H.Nota_Venta, H.Cliente_SAP, H.Cliente_SAP,
                   H.Fecha_Venta,
                   CASE WHEN H.Clase_Factura IN ('C003','C005') THEN 'Vta' ELSE 'Dev' END,
                   H.Importe_Venta, GETDATE()
            FROM #OIHistoric AS H
            LEFT JOIN #OIPaid AS P ON P.Nota_Venta = H.Nota_Venta
                AND P.Tipo = CASE WHEN H.Clase_Factura IN ('C003','C005') THEN 'Vta' ELSE 'Dev' END
            WHERE NOT EXISTS (SELECT 1 FROM EAI.CFDI_OPEN_ITEMS AS OI
                              WHERE OI.Nota_Venta = H.Nota_Venta)
              AND ABS(ISNULL(H.Importe_Venta, 0) - ISNULL(P.Cobrado, 0)) > 0.05;
            SET @nProceso4 = @@ROWCOUNT;
            IF @Diagnostico = 1 RAISERROR('Historico: documentos insertados = %d', 10, 1, @nProceso4) WITH NOWAIT;
            DROP TABLE #OIHistoric, #OIKeys, #OIPaid;
        END;

