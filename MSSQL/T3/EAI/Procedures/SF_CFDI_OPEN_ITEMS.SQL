CREATE PROCEDURE [EAI].[SF_CFDI_OPEN_ITEMS]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg       VARCHAR(500),
        @v_ID       VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode VARCHAR(20),
        @dtInicio   DATETIME2(0),
        @nPID       BIGINT,
        @nProceso   INT = 923,
        @nProceso1  INT = 0,
        @nProceso2  INT = 0,
        @nProceso3  INT = 0,
        @nProceso4  INT = 0;

    BEGIN TRY
        SET @dtInicio = SYSDATETIME();
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
        (
            PID,
            Proceso,
            Fecha_Proc_BATMD,
            Inicio
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            @dtInicio
        );

        SET @v_ID = 'CFDI_OPEN_ITEMS';

        IF ISNULL(@nEtapa, 0) <= 0
        BEGIN
            DELETE FROM [EAI].[CFDI_OPEN_ITEMS];

            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
            (
                Nota_Venta,
                Cliente_SAP,
                Fecha_Venta,
                Tipo_Docto,
                Saldo_SAP,
                Last_Updated
            )
            SELECT
                DOI.Nota_Venta,
                DOI.Cliente_SAP,
                TRY_CONVERT(DATE, DOI.Fecha_Doc, 112),
                CASE
                    WHEN DOI.Tipo_Docto IN ('C003', 'C005') THEN 'Vta'
                    WHEN DOI.Tipo_Docto IN ('C004', 'C006', 'C019', 'C025') THEN 'Dev'
                    WHEN DOI.Saldo_SAP = ABS(DOI.Saldo_SAP) THEN 'Vta'
                    ELSE 'Dev'
                END,
                CASE
                    WHEN DOI.Tipo_Docto IN ('C003', 'C005') THEN DOI.Saldo_SAP
                    ELSE ABS(DOI.Saldo_SAP)
                END,
                GETDATE()
            FROM
            (
                SELECT
                    SAP.Referencia AS Nota_Venta,
                    ISNULL(RF.Tipo_Docto, 'NULL') AS Tipo_Docto,
                    MAX(SAP.Asignacion) AS Asignacion,
                    MAX(SAP.Cliente) AS Cliente_SAP,
                    MIN(SAP.Fecha_Doc) AS Fecha_Doc,
                    SUM(ISNULL(SAP.Monto, 0)) AS Saldo_SAP
                FROM
                (
                    SELECT
                        SAP.Cliente,
                        ISNULL(Conv.Docto_T3MX, SAP.Referencia) AS Referencia,
                        SAP.Fecha_Doc,
                        SAP.Tipo_Doc,
                        SAP.Monto,
                        SAP.Asignacion
                    FROM [EAI].[T3R_Cartera_SAP_OLD] AS SAP
                    LEFT JOIN
                    (
                        SELECT Docto_SAP, Docto_T3MX
                        FROM [T3].[CFDI_Refoleo]
                        WHERE Tipo_Registro = 'DOI'
                    ) AS Conv
                        ON SAP.Referencia = Conv.Docto_SAP
                ) AS SAP
                LEFT JOIN [T3].[Registro_Fiscal] AS RF
                    ON SAP.Referencia = RF.Factura
                WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM [T3].[Otros_General] AS OG
                        WHERE OG.Factura = SAP.Referencia
                    )
                GROUP BY SAP.Referencia, ISNULL(RF.Tipo_Docto, 'NULL')
            ) AS DOI;

            SET @nProceso1 = @@ROWCOUNT;
        END;

        SET @v_ID = 'Historico';

        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
            (
                Ctro,
                Nota_Venta,
                Cliente_SAP,
                Clte_Factura_SAP,
                Fecha_Venta,
                Tipo_Docto,
                Importe_Vta,
                Last_Updated
            )
            SELECT
                Vta.Ctro,
                Vta.Nota_Venta,
                Vta.Cliente_SAP,
                Vta.Cliente_SAP,
                Vta.Fecha_Venta,
                CASE WHEN Vta.Clase_Factura IN ('C003', 'C005') THEN 'Vta' ELSE 'Dev' END,
                Vta.Importe_Venta,
                GETDATE()
            FROM
            (
                SELECT
                    Nota.Ctro,
                    Nota.Fecha_Venta,
                    Nota.Clase_Factura,
                    Nota.Nota_Venta,
                    Nota.Cliente_SAP,
                    Nota.RFC,
                    SUM(Nota.Importe_Item) AS Importe_Venta
                FROM
                (
                    SELECT
                        FG.Ctro,
                        FG.Fecha_Factura AS Fecha_Venta,
                        FG.Tipo_Docto AS Clase_Factura,
                        FG.Factura AS Nota_Venta,
                        FG.Cliente_SAP,
                        Cte.RFC,
                        ISNULL(FD.Valor_Subt, 0)
                      + ISNULL(FD.Valor_IVA, 0)
                      + ISNULL(FD.Credito_Subt, 0)
                      + ISNULL(FD.Credito_IVA, 0)
                      + ISNULL(FD.Envio_Subt, 0)
                      + ISNULL(FD.Envio_IVA, 0) AS Importe_Item
                    FROM [T3].[Factura_General] AS FG
                    INNER JOIN [T3].[Factura_Detalle] AS FD
                        ON FG.Factura = FD.Factura
                    INNER JOIN [T3].[Cliente] AS Cte
                        ON FG.Cliente_SAP = Cte.Cliente_SAP
                       AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                    WHERE FG.Fecha_Factura >= CONVERT(DATE, '20230101', 112)
                      AND FG.Tipo_Docto IN ('C003', 'C004')

                    UNION ALL

                    SELECT
                        PG.Ctro,
                        PG.Fecha_Factura AS Fecha_Venta,
                        PG.Clase_Factura,
                        PG.Factura AS Nota_Venta,
                        PG.Cliente_SAP,
                        Cte.RFC,
                        ISNULL(PD.Valor_Subt, 0)
                      + ISNULL(PD.Valor_IVA, 0)
                      + ISNULL(PD.Credito_Subt, 0)
                      + ISNULL(PD.Credito_IVA, 0)
                      + ISNULL(PD.Envio_Subt, 0)
                      + ISNULL(PD.Envio_IVA, 0) AS Importe_Item
                    FROM [T3].[Preventa_General] AS PG
                    INNER JOIN [T3].[Preventa_Detalle] AS PD
                        ON PG.Factura = PD.Factura
                    INNER JOIN [T3].[Cliente] AS Cte
                        ON PG.Cliente_SAP = Cte.Cliente_SAP
                       AND PG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                    WHERE PG.Fecha_Factura >= CONVERT(DATE, '20230101', 112)
                      AND PG.Clase_Factura IN ('C005', 'C006', 'C019', 'C025')
                      AND PG.Fecha_Proc_BATMD IS NOT NULL
                      AND PG.Fecha_Cancelacion IS NULL
                ) AS Nota
                GROUP BY
                    Nota.Ctro,
                    Nota.Fecha_Venta,
                    Nota.Clase_Factura,
                    Nota.Nota_Venta,
                    Nota.Cliente_SAP,
                    Nota.RFC
            ) AS Vta
            LEFT JOIN [EAI].[CFDI_OPEN_ITEMS] AS DOI
                ON Vta.Nota_Venta = DOI.Nota_Venta
            WHERE DOI.Nota_Venta IS NULL
              AND ABS
                  (
                      ISNULL(Vta.Importe_Venta, 0)
                    - ISNULL
                      (
                          CASE
                              WHEN Vta.Clase_Factura IN ('C003', 'C005')
                                  THEN [T3].[FN_Cobza_Pay](Vta.Nota_Venta)
                              ELSE [T3].[FN_COBZA_CM_UUID](Vta.Nota_Venta)
                          END,
                          0
                      )
                  ) > 0.05;

            SET @nProceso4 = @@ROWCOUNT;
        END;

        SET @v_ID = 'ScrVenta';

        IF ISNULL(@nEtapa, 0) <= 20
        BEGIN
            UPDATE DOI
               SET Importe = Cobza.Importe,
                   Efectivo = Cobza.Efectivo,
                   Agrupado = Cobza.Agrupado,
                   Aplica_NC = Cobza.Aplica_NC,
                   Efectivo_UUID = Cobza.Efectivo_UUID,
                   Agrupado_UUID = Cobza.Agrupado_UUID,
                   Aplica_NC_UUID = Cobza.Aplica_NC_UUID,
                   Importe_UUID = Cobza.Importe_UUID,
                   Incobrable = Cobza.Incobrable,
                   Metodo_Pago = CFD.Metodo_Pago,
                   Tipo_Docto = 'Vta',
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                ON DOI.Nota_Venta = CFD.Nota_Venta
            INNER JOIN
            (
                SELECT
                    Cobza.Factura,
                    SUM(Cobza.Importe) AS Importe,
                    SUM(Cobza.Efectivo) AS Efectivo,
                    SUM(Cobza.Agrupado) AS Agrupado,
                    SUM(Cobza.Aplica_NC) AS Aplica_NC,
                    SUM(Cobza.Incobrable) AS Incobrable,
                    SUM(Cobza.Efectivo * Cobza.Timbrado) AS Efectivo_UUID,
                    SUM(Cobza.Agrupado * Cobza.Timbrado) AS Agrupado_UUID,
                    SUM(Cobza.Aplica_NC * Cobza.Timbrado) AS Aplica_NC_UUID,
                    SUM(Cobza.Importe * Cobza.Timbrado) AS Importe_UUID
                FROM
                (
                    SELECT
                        C.Factura,
                        C.Asignacion_ID,
                        ISNULL(C.Importe, 0) AS Importe,
                        C.Via_Pago,
                        C.Nota_Credito,
                        CASE WHEN C.Via_Pago = '01' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Efectivo,
                        CASE WHEN C.Via_Pago IN ('02', '03') THEN ISNULL(C.Importe, 0) ELSE 0 END AS Agrupado,
                        CASE WHEN C.Via_Pago = 'CM' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Aplica_NC,
                        CASE WHEN C.Via_Pago = 'AI' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Incobrable,
                        CASE WHEN Pago.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                      + CASE WHEN Agr.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                      + CASE WHEN Nota.Folio_Fiscal IS NULL THEN 0 ELSE 1 END AS Timbrado
                    FROM [T3].[CFDI_Cobranza] AS C
                    LEFT JOIN [T3].[CFDI_Documentos] AS Pago
                        ON C.Asignacion_ID = Pago.Nota_Venta
                    LEFT JOIN
                    (
                        SELECT CAP.Agrupacion, CAP.Fecha_Pago, CAP.Asignacion_Id
                        FROM [T3].[CFDI_Agrupacion_Pago] AS CAP
                        INNER JOIN [T3].[CFDI_Agrupacion_Ctrl] AS CAC
                            ON CAP.Agrupacion = CAC.Agrupacion
                        WHERE ISNULL(CAC.Importe, 0) <> 0
                    ) AS AgrP
                        ON C.Asignacion_ID = AgrP.Asignacion_Id
                    LEFT JOIN [T3].[CFDI_Documentos] AS Agr
                        ON CONVERT(VARCHAR(30), AgrP.Agrupacion) = Agr.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Documentos] AS Nota
                        ON C.Nota_Credito = Nota.Nota_Venta
                ) AS Cobza
                GROUP BY Cobza.Factura
            ) AS Cobza
                ON DOI.Nota_Venta = Cobza.Factura
            WHERE DOI.Tipo_Docto = 'Vta';

            SET @nProceso2 = @@ROWCOUNT;
        END;

        SET @v_ID = 'ScrDevolucion';

        IF ISNULL(@nEtapa, 0) <= 30
        BEGIN
            UPDATE DOI
               SET Importe_NC = CreditMemo.Importe_Aplicado,
                   Incobrable = CreditMemo.Incobrable,
                   Fecha_Aplicacion = CreditMemo.Fecha_Asignacion,
                   Tipo_Docto = 'Dev',
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT
                    C.Nota_Credito,
                    COUNT(C.Asignacion_ID) AS Aplicaciones,
                    SUM(ISNULL(C.Importe, 0) * CASE WHEN C.Via_Pago = 'CM' THEN 1 ELSE 0 END) AS Importe_Aplicado,
                    SUM(ISNULL(C.Importe, 0) * CASE WHEN C.Via_Pago = 'AI' THEN 1 ELSE 0 END) AS Incobrable,
                    MAX(C.Fecha_Asignacion) AS Fecha_Asignacion
                FROM [T3].[CFDI_Cobranza] AS C
                GROUP BY C.Nota_Credito
            ) AS CreditMemo
                ON DOI.Nota_Venta = CreditMemo.Nota_Credito
            WHERE DOI.Tipo_Docto = 'Dev';

            SET @nProceso2 = @nProceso2 + @@ROWCOUNT;
        END;

        SET @v_ID = 'ImporteVenta';

        IF ISNULL(@nEtapa, 0) <= 60
        BEGIN
            UPDATE DOI
               SET Ctro = ImporteVta.Ctro,
                   RFC = ImporteVta.RFC,
                   Importe_Vta = ImporteVta.Importe_Vta,
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT
                    RF.Factura AS Nota_Venta,
                    RF.Ctro,
                    MC.RFC,
                    SUM
                    (
                        ISNULL(RFD.Valor_Subt, 0)
                      + ISNULL(RFD.Valor_IVA, 0)
                      + ISNULL(RFD.Envio_Subt, 0)
                      + ISNULL(RFD.Envio_IVA, 0)
                      + ISNULL(RFD.Credito_Subt, 0)
                      + ISNULL(RFD.Credito_IVA, 0)
                    ) AS Importe_Vta
                FROM [T3].[Registro_Fiscal] AS RF
                INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                    ON RF.Factura = RFD.Factura
                LEFT JOIN [T3].[Mov_Cliente] AS MC
                    ON RF.Cliente_SAP = MC.Cliente_SAP
                GROUP BY RF.Factura, RF.Ctro, MC.RFC
            ) AS ImporteVta
                ON DOI.Nota_Venta = ImporteVta.Nota_Venta;

            SET @nProceso3 = @@ROWCOUNT;

            UPDATE DOI
               SET Ctro = Debit.Ctro,
                   RFC = Debit.RFC,
                   Importe_Vta = Debit.Importe,
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT
                    DOI_Inner.Nota_Venta,
                    DN.Total_Amt AS Importe,
                    DN.Document_Date AS Fecha_Docto,
                    DN.Created AS Fecha_Creacion,
                    MC.RFC,
                    MC.Ctro
                FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
                INNER JOIN [T3].[DEBIT_NOTE_IFC] AS DN
                    ON DOI_Inner.Nota_Venta = DN.Debit_Note
                INNER JOIN [T3].[Mov_Cliente] AS MC
                    ON DN.Cust_to_SAP = MC.Cliente_SAP
            ) AS Debit
                ON DOI.Nota_Venta = Debit.Nota_Venta;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        SET @v_ID = 'Fiscal';

        IF ISNULL(@nEtapa, 0) <= 70
        BEGIN
            UPDATE DOI
               SET Nota_Venta_CFDI = Fiscal.Nota_Venta_CFDI,
                   Folio_Fiscal = Fiscal.Folio_Fiscal,
                   Metodo_Pago = Fiscal.Metodo_Pago,
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT
                    DOI_Inner.Nota_Venta,
                    HDP.Nota_Venta_CFDI,
                    CFD.Fecha_Liberacion,
                    CFD.Folio_Fiscal,
                    CFD.Metodo_Pago
                FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
                INNER JOIN [T3].[CFDI_Historia_Docto_PAC] AS HDP
                    ON DOI_Inner.Nota_Venta = HDP.Nota_Venta
                LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                    ON HDP.Nota_Venta_CFDI = CFD.Nota_Venta
            ) AS Fiscal
                ON DOI.Nota_Venta = Fiscal.Nota_Venta;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        SET @v_ID = 'ScrUUID_Creditos';

        IF ISNULL(@nEtapa, 0) <= 80
        BEGIN
            UPDATE DOI
               SET Importe_NC_UUID = Creditos.Timbrado * ISNULL(DOI.Importe_NC, 0),
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT
                    DOI_Inner.Nota_Venta,
                    ISNULL(HDP.Nota_Venta_CFDI, DOI_Inner.Nota_Venta) AS Nota_Venta_CFDI,
                    CFD.Fecha_Liberacion,
                    CASE WHEN CFD.Folio_Fiscal IS NULL THEN 0 ELSE 1 END AS Timbrado
                FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
                LEFT JOIN [T3].[CFDI_Historia_Docto_PAC] AS HDP
                    ON DOI_Inner.Nota_Venta = HDP.Nota_Venta
                INNER JOIN [T3].[CFDI_Documentos] AS CFD
                    ON ISNULL(HDP.Nota_Venta_CFDI, DOI_Inner.Nota_Venta) = CFD.Nota_Venta
                WHERE DOI_Inner.Tipo_Docto = 'Dev'
            ) AS Creditos
                ON DOI.Nota_Venta = Creditos.Nota_Venta;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        SET @v_ID = 'ScrClte_Factura_SAP';

        IF ISNULL(@nEtapa, 0) <= 90
        BEGIN
            UPDATE DOI
               SET Clte_Factura_SAP = ClteFactura.Clte_Factura_SAP,
                   Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
            INNER JOIN
            (
                SELECT DOI_Inner.Nota_Venta, PG.Clte_Factura_SAP
                FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
                INNER JOIN [T3].[Preventa_General] AS PG
                    ON DOI_Inner.Nota_Venta = PG.Factura
                WHERE PG.Clte_Factura_SAP IS NOT NULL
                  AND PG.Cliente_SAP <> PG.Clte_Factura_SAP

                UNION ALL

                SELECT DOI_Inner.Nota_Venta, FG.Clte_Factura_SAP
                FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
                INNER JOIN [T3].[Factura_General] AS FG
                    ON DOI_Inner.Nota_Venta = FG.Factura
                WHERE FG.Clte_Factura_SAP IS NOT NULL
                  AND FG.Cliente_SAP <> FG.Clte_Factura_SAP
            ) AS ClteFactura
                ON DOI.Nota_Venta = ClteFactura.Nota_Venta;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        SET @v_ID = 'Final';

        UPDATE DOI
           SET RFC = MC_Data.RFC,
               Ctro = MC_Data.Ctro
        FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
        INNER JOIN
        (
            SELECT
                DOI_Inner.Nota_Venta,
                MAX(MC.RFC) AS RFC,
                MAX(MC.Ctro) AS Ctro
            FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI_Inner
            INNER JOIN [T3].[Mov_Cliente] AS MC
                ON MC.Cliente_SAP = DOI_Inner.Cliente_SAP
            WHERE DOI_Inner.RFC IS NULL
            GROUP BY DOI_Inner.Nota_Venta
        ) AS MC_Data
            ON DOI.Nota_Venta = MC_Data.Nota_Venta
        WHERE DOI.RFC IS NULL;

        UPDATE DOI
           SET Importe_Vta = ISNULL(Importe_Vta, 0) + ISNULL([EAI_OWNER].[Fn_Get_Tax_Issue](DOI.Nota_Venta), 0)
        FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
        WHERE DOI.Tipo_Docto = 'Dev';

        UPDATE DOI
           SET PedidoSAP = RF.Pedido,
               FacturaSAP = RF.Entrega
        FROM [EAI].[CFDI_OPEN_ITEMS] AS DOI
        INNER JOIN [T3].[Registro_Fiscal] AS RF
            ON DOI.Nota_Venta = RF.Factura;

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = GETDATE(),
               Proceso_1 = @nProceso1,
               Proceso_2 = @nProceso2,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(20));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(20)) + '-' + ERROR_MESSAGE(), 1, 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
            JOB_PID,
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
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'SF_CFDI_OPEN_ITEMS',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT '--------------------------------------';
        PRINT '**** Error en SF_CFDI_OPEN_ITEMS *****';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
GO
