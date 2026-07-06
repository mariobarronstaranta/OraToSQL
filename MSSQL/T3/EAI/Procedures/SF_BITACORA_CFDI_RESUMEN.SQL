CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI_RESUMEN]
    @pFecha_Inicio VARCHAR(30) = NULL,
    @pFecha_Final  VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID          VARCHAR(50) = NULL,
        @sErrorCode    VARCHAR(30),
        @sMsg          VARCHAR(300),
        @nPID          BIGINT,
        @nProceso      INT = 802,
        @nProceso1     INT = 0,
        @nProceso2     INT = 0,
        @nProceso3     INT = 0,
        @nProceso4     INT = 0,
        @nCount        INT = 0,
        @sFecha_Inicio VARCHAR(30),
        @sFecha_Final  VARCHAR(30);

    BEGIN TRY
        SET @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;
        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
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
            GETDATE()
        );

        PRINT '-----------------------------';
        PRINT 'Proc_T3_CFDI_Resumen';
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        IF @pFecha_Inicio IS NULL
        BEGIN
            SELECT
                @sFecha_Inicio = CONVERT(VARCHAR(8), DATEADD(MONTH, -1, TRY_CONVERT(DATE, Start_Date, 103)), 112),
                @sFecha_Final = CONVERT(VARCHAR(8), GETDATE(), 112)
            FROM EAI.FC__Time_WINDOW;
        END
        ELSE
        BEGIN
            SET @sFecha_Inicio = @pFecha_Inicio;
            SET @sFecha_Final = @pFecha_Final;
        END;

        SET @v_ID = 'Inicializar CFDI_Informe';

        UPDATE EAI.CONTROL_REPORTE
           SET INICIO = GETDATE(),
               FIN = NULL
         WHERE REPORTE = 'BITACORA CFDI';

        DELETE FROM EAI.CFDI_Informe;

        SET @v_ID = 'ScrPrompt';

        INSERT INTO EAI.CFDI_Informe
        (
            Sociedad,
            Folio_Interno,
            Fecha,
            Ctro,
            RFC,
            ID_Envio,
            ID_Confirmacion,
            Nombre_Cliente,
            LP,
            Doctos,
            Terr,
            Tipo_Docto,
            Factor,
            Folio_Fiscal,
            Status,
            Monto_T3In,
            Valor_Subt,
            Valor_IVA,
            Valor
        )
        SELECT
            'MX06',
            HDoc.Nota_Venta_CFDI,
            HDoc.Fecha_Factura,
            HDoc.Ctro,
            Paso.RFC_Factura,
            PAC.ID_Envio,
            PAC.ID_Confirmacion,
            Cte.Nombre,
            Cte.Lista_Precio,
            1,
            SUBSTRING(FG.Ubicacion, 15, 4),
            FG.Tipo_Docto,
            CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            PAC.Folio_Fiscal,
            PAC.Status,
            (ISNULL(FG.Valor_Subt, 0) + ISNULL(FG.Valor_IVA, 0))
                * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0)
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(FG.Valor_Subt, 0)
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_IVA, 0)
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(FG.Valor_IVA, 0)
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0) + ISNULL(PAC.Valor_IVA, 0)
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(FG.Valor_Subt, 0) + ISNULL(FG.Valor_IVA, 0)
                    ELSE 0
                END
            ) * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END
        FROM T3.CFDI_Historia_Docto_PAC AS HDoc
        INNER JOIN T3.CFDI_Documento_Paso AS Paso
            ON HDoc.Nota_Venta = Paso.Factura
        INNER JOIN T3.Factura_General AS FG
            ON HDoc.Nota_Venta = FG.Factura
        INNER JOIN T3.CFDI_Documentos AS PAC
            ON HDoc.Nota_Venta = PAC.Nota_Venta
        INNER JOIN T3.Cliente AS Cte
            ON FG.Cliente_SAP = Cte.Cliente_SAP
           AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
        WHERE CONVERT(VARCHAR(8), HDoc.Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
          AND HDoc.Nota_Venta = HDoc.Nota_Venta_CFDI;

        SET @nProceso1 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso1;
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        SET @v_ID = 'ScrPreventa';

        INSERT INTO EAI.CFDI_Informe
        (
            Sociedad,
            Folio_Interno,
            Fecha,
            Ctro,
            RFC,
            ID_Envio,
            ID_Confirmacion,
            Nombre_Cliente,
            LP,
            Doctos,
            Terr,
            Tipo_Docto,
            Factor,
            Folio_Fiscal,
            Status,
            Monto_T3In,
            Valor_Subt,
            Valor_IVA,
            Valor
        )
        SELECT
            CASE WHEN PG.Clase_Factura IN ('C020', 'C021', 'C022') THEN 'MX01' ELSE 'MX06' END,
            HDoc.Nota_Venta_CFDI,
            HDoc.Fecha_Factura,
            HDoc.Ctro,
            Cte.RFC,
            PAC.ID_Envio,
            PAC.ID_Confirmacion,
            Cte.Nombre,
            Cte.Lista_Precio,
            1,
            ISNULL(E.Ubicacion, PG.Ubicacion),
            PG.Clase_Factura,
            CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            PAC.Folio_Fiscal,
            PAC.Status,
            CASE
                WHEN PG.Fecha_Cancelacion IS NOT NULL THEN 0
                WHEN CONVERT(VARCHAR(4), PG.Fecha_Proc_BATMD, 112) = '2999' THEN 0
                ELSE ISNULL(PG.Valor_Subt, 0) + ISNULL(PG.Valor_IVA, 0)
            END * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0)
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(PG.Valor_Subt, 0)
                ELSE 0
            END * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_IVA, 0)
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(PG.Valor_IVA, 0)
                ELSE 0
            END * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0) + ISNULL(PAC.Valor_IVA, 0)
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN ISNULL(PG.Valor_Subt, 0) + ISNULL(PG.Valor_IVA, 0)
                    ELSE 0
                END
            ) * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END
        FROM T3.CFDI_Historia_Docto_PAC AS HDoc
        INNER JOIN T3.Preventa_General AS PG
            ON HDoc.Nota_Venta = PG.Factura
        INNER JOIN T3.CFDI_Documentos AS PAC
            ON HDoc.Nota_Venta = PAC.Nota_Venta
        INNER JOIN T3.Cliente AS Cte
            ON PG.Cliente_SAP = Cte.Cliente_SAP
           AND PG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
        LEFT JOIN T3.Entrega AS E
            ON HDoc.Nota_Venta = E.Factura
        WHERE CONVERT(VARCHAR(8), HDoc.Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
          AND HDoc.Nota_Venta = HDoc.Nota_Venta_CFDI;

        SET @nProceso2 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso2;
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        SET @v_ID = 'ScrAgrupado';

        WITH Doc AS
        (
            SELECT
                HDoc.Ctro,
                HDoc.Fecha_Factura,
                HDoc.Nota_Venta_CFDI,
                SUM(ISNULL(FD.Valor_Subt, 0) + ISNULL(FD.Valor_IVA, 0)
                    + ISNULL(FD.Envio_Subt, 0) + ISNULL(FD.Envio_IVA, 0)) AS Total_T3In
            FROM
            (
                SELECT DISTINCT
                    Nota_Venta,
                    Ctro,
                    Fecha_Factura,
                    Nota_Venta_CFDI
                FROM T3.CFDI_Historia_Docto_PAC
                WHERE CONVERT(VARCHAR(8), Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
            ) AS HDoc
            INNER JOIN T3.Factura_General AS FG
                ON HDoc.Nota_Venta = FG.Factura
            INNER JOIN T3.Factura_Detalle AS FD
                ON HDoc.Nota_Venta = FD.Factura
            WHERE HDoc.Nota_Venta <> HDoc.Nota_Venta_CFDI
            GROUP BY HDoc.Ctro, HDoc.Fecha_Factura, HDoc.Nota_Venta_CFDI
        ),
        FG AS
        (
            SELECT
                Agr.Ctro,
                SUBSTRING(Agr.Cliente_SAP, 2, 5) AS Terr,
                Agr.Tipo_Docto,
                Agr.Nota_Venta_CFDI,
                CAST(Agr.Fecha_Documento AS DATE) AS Fecha,
                MAX(Agr.Doctos) AS Doctos,
                SUM(ISNULL(Det.Valor_Subt, 0) + ISNULL(Det.Envio_Subt, 0) + ISNULL(Det.Credito_Subt, 0)) AS Valor_Subt,
                SUM(ISNULL(Det.Valor_IVA, 0) + ISNULL(Det.Envio_IVA, 0) + ISNULL(Det.Credito_IVA, 0)) AS Valor_IVA
            FROM T3.CFDI_Agrupado AS Agr
            INNER JOIN T3.CFDI_Agrupado_Detalle AS Det
                ON Agr.Nota_Venta_CFDI = Det.Nota_Venta_CFDI
            GROUP BY
                Agr.Ctro,
                SUBSTRING(Agr.Cliente_SAP, 2, 5),
                Agr.Tipo_Docto,
                Agr.Nota_Venta_CFDI,
                CAST(Agr.Fecha_Documento AS DATE)
        )
        INSERT INTO EAI.CFDI_Informe
        (
            Sociedad,
            Folio_Interno,
            Fecha,
            Ctro,
            RFC,
            ID_Envio,
            ID_Confirmacion,
            Nombre_Cliente,
            Doctos,
            Terr,
            Tipo_Docto,
            Factor,
            Folio_Fiscal,
            Status,
            Monto_T3In,
            Valor_Subt,
            Valor_IVA,
            Valor
        )
        SELECT
            'MX06',
            Doc.Nota_Venta_CFDI,
            Doc.Fecha_Factura,
            Doc.Ctro,
            'XAXX010101000',
            PAC.ID_Envio,
            PAC.ID_Confirmacion,
            'CLIENTE AGRUPADOR VENTAS DIA',
            FG.Doctos,
            FG.Terr,
            FG.Tipo_Docto,
            CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            PAC.Folio_Fiscal,
            PAC.Status,
            Doc.Total_T3In * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0)
                WHEN PAC.Status = 'PENDING' THEN ISNULL(FG.Valor_Subt, 0)
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            CASE
                WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_IVA, 0)
                WHEN PAC.Status = 'PENDING' THEN ISNULL(FG.Valor_IVA, 0)
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END,
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN ISNULL(PAC.Valor_Subt, 0) + ISNULL(PAC.Valor_IVA, 0)
                    WHEN PAC.Status = 'PENDING' THEN ISNULL(FG.Valor_Subt, 0) + ISNULL(FG.Valor_IVA, 0)
                    ELSE 0
                END
            ) * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END
        FROM Doc
        INNER JOIN FG
            ON Doc.Nota_Venta_CFDI = FG.Nota_Venta_CFDI
        INNER JOIN T3.CFDI_Documentos AS PAC
            ON Doc.Nota_Venta_CFDI = PAC.Nota_Venta;

        SET @nProceso3 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso3;
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);
        PRINT 'Registros : ' + CAST(@nCount AS VARCHAR(20));
        PRINT '-----------------------------';

        SET @v_ID = 'ScrCIG_Individual';

        UPDATE Info
           SET Cigarrillos = Cig.Cigarrillos,
               Envio_Subt = Info.Factor * Cig.Envio_Subt,
               Envio_IVA = Info.Factor * Cig.Envio_IVA,
               Credito_Subt = Info.Factor * Cig.Credito_Subt,
               Credito_IVA = Info.Factor * Cig.Credito_IVA,
               Monto_T3In = Info.Monto_T3In
                          + (Info.Factor * (Cig.Envio_Subt + Cig.Envio_IVA + Cig.Credito_Subt + Cig.Credito_IVA) * Cig.Sumar_Envio)
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN
        (
            SELECT
                CFD.Folio_Interno,
                SUM(CFD.Factor * RFD.Cantidad_Vta
                    * CASE
                          WHEN Prod.Unidad_Med_Vta = 'CAJ' THEN ISNULL(Prod.Cig_x_CLL, 1)
                          ELSE ISNULL(Prod.Cig_x_PAQ, 1)
                      END) AS Cigarrillos,
                MAX(CASE WHEN RF.Tipo_Docto IN ('C005', 'C006') THEN 0 ELSE 1 END) AS Sumar_Envio,
                SUM(ISNULL(RFD.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(RFD.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(RFD.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(RFD.Credito_IVA, 0)) AS Credito_IVA
            FROM EAI.CFDI_Informe AS CFD
            INNER JOIN T3.Registro_Fiscal AS RF
                ON CFD.Folio_Interno = RF.Factura
            INNER JOIN T3.Registro_Fiscal_Detalle AS RFD
                ON CFD.Folio_Interno = RFD.Factura
            INNER JOIN T3.Material AS Prod
                ON RFD.Material = Prod.Material
            GROUP BY CFD.Folio_Interno
        ) AS Cig
            ON Info.Folio_Interno = Cig.Folio_Interno;

        SET @nCount = @@ROWCOUNT;
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);
        PRINT 'Actualizados : ' + CAST(@nCount AS VARCHAR(20));
        PRINT '-----------------------------';

        SET @v_ID = 'ScrCIG_Agrupado';

        UPDATE Info
           SET Cigarrillos = Cig.Cigarrillos,
               Envio_Subt = Info.Factor * Cig.Envio_Subt,
               Envio_IVA = Info.Factor * Cig.Envio_IVA,
               Credito_Subt = Info.Factor * Cig.Credito_Subt,
               Credito_IVA = Info.Factor * Cig.Credito_IVA
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN
        (
            SELECT
                CFD.Folio_Interno,
                SUM(CFD.Factor * RFD.Cantidad_Vta
                    * CASE
                          WHEN Prod.Unidad_Med_Vta = 'CAJ' THEN ISNULL(Prod.Cig_x_CLL, 1)
                          ELSE ISNULL(Prod.Cig_x_PAQ, 1)
                      END) AS Cigarrillos,
                SUM(ISNULL(RFD.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(RFD.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(RFD.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(RFD.Credito_IVA, 0)) AS Credito_IVA
            FROM EAI.CFDI_Informe AS CFD
            INNER JOIN T3.CFDI_Agrupado AS RF
                ON CFD.Folio_Interno = RF.Nota_Venta_CFDI
            INNER JOIN T3.CFDI_Agrupado_Detalle AS RFD
                ON CFD.Folio_Interno = RFD.Nota_Venta_CFDI
            INNER JOIN T3.Material AS Prod
                ON RFD.Material = Prod.Material
            GROUP BY CFD.Folio_Interno
        ) AS Cig
            ON Info.Folio_Interno = Cig.Folio_Interno;

        SET @nCount = @@ROWCOUNT;
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);
        PRINT 'Actualizados : ' + CAST(@nCount AS VARCHAR(20));
        PRINT '-----------------------------';

        SET @v_ID = 'ScrComplementoAGR';

        WITH LpAgr AS
        (
            SELECT
                SourceLp.Nota_Venta_CFDI,
                MAX(Grupo_Precio) AS Grupo_Precio
            FROM
            (
                SELECT HDP.Nota_Venta_CFDI, Doc.Grupo_Precio
                FROM T3.CFDI_Historia_Docto_PAC AS HDP
                INNER JOIN T3.Fact_T3 AS Doc
                    ON HDP.Nota_Venta = Doc.Factura
                UNION ALL
                SELECT HDP.Nota_Venta_CFDI, Doc.Grupo_Precio
                FROM T3.CFDI_Historia_Docto_PAC AS HDP
                INNER JOIN T3.Nota_T3 AS Doc
                    ON HDP.Nota_Venta = Doc.Factura
            ) AS SourceLp
            GROUP BY SourceLp.Nota_Venta_CFDI
        )
        UPDATE Info
           SET LP = LpAgr.Grupo_Precio
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN T3.CFDI_Agrupado AS Agr
            ON Info.Folio_Interno = Agr.Nota_Venta_CFDI
        INNER JOIN LpAgr
            ON Info.Folio_Interno = LpAgr.Nota_Venta_CFDI
        WHERE Info.LP IS NULL;

        SET @v_ID = 'ScrAgrupadoDiferencia';

        UPDATE Info
           SET Valor_IVA = Info.Valor_IVA + Dif.Ajuste,
               Valor = Info.Valor + Dif.Ajuste
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN T3.CFDI_Agrupado_DIF AS Dif
            ON Info.Folio_Interno = Dif.Nota_Venta_CFDI
        WHERE Info.Folio_Interno LIKE 'G-%'
          AND Dif.Ajuste <> 0;

        SET @nProceso4 = @@ROWCOUNT;

        SET @v_ID = 'ScrIndividualDiferencia';

        UPDATE Info
           SET Valor_IVA = Info.Valor_IVA + Dif.Ajuste,
               Valor = Info.Valor + Dif.Ajuste
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN T3.CFDI_Agrupado_DIF AS Dif
            ON Info.Folio_Interno = Dif.Nota_Venta_CFDI
        WHERE Info.Folio_Interno NOT LIKE 'G-%'
          AND Dif.Ajuste <> 0;

        SET @nProceso4 = @nProceso4 + @@ROWCOUNT;

        SET @v_ID = 'ScrCentavos_CFD';

        UPDATE Info
           SET Valor_IVA = Info.Valor_IVA - Dif.Diferencia,
               Valor = Info.Valor - Dif.Diferencia,
               Diferencia = Dif.Diferencia
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN
        (
            SELECT
                CFD.Folio_Interno,
                CFD.Valor - CFD.Monto_T3In AS Diferencia
            FROM EAI.CFDI_Informe AS CFD
            CROSS JOIN EAI.FC__Time_Window AS TW
            WHERE CFD.Valor <> CFD.Monto_T3In
              AND CFD.Folio_Interno NOT LIKE 'G-%'
              AND ABS(CFD.Valor - CFD.Monto_T3In) < 0.06
              AND CFD.Fecha >= TRY_CONVERT(DATE, TW.Start_Date, 103)
        ) AS Dif
            ON Info.Folio_Interno = Dif.Folio_Interno;

        SET @v_ID = 'Updating Addenda';

        UPDATE EAI.CFDI_Informe
           SET Addenda = 'SI'
         WHERE RFC IN (SELECT RFC FROM T3.CFDI_Addenda);

        UPDATE EAI.CFDI_Informe
           SET Addenda = 'NO'
         WHERE Addenda IS NULL;

        UPDATE EAI.CFDI_Informe
           SET Valor = Monto_T3In
         WHERE Status = 'PUBLICADO'
           AND Valor <> Monto_T3In;

        SET @v_ID = 'ScrFactCentral';

        UPDATE Bita
           SET SF_Amount = Bita.SAP_Amount,
               Origen = 'SAP'
        FROM EAI.CFDI_Bitacora AS Bita
        INNER JOIN EAI_OWNER.WA_VENTA_CENTRALIZADA AS Ctrl
            ON Bita.Cliente_SAP = Ctrl.Cliente_SAP
           AND Bita.Invc_dt BETWEEN Ctrl.Fecha_Ini_Vig AND Ctrl.Fecha_Fin_Vig
        LEFT JOIN EAI.CFDI_Informe AS Info
            ON Bita.Doc_Num = Info.Folio_Interno;

        UPDATE Info
           SET Origen = 'SAP'
        FROM EAI.CFDI_Informe AS Info
        INNER JOIN EAI.CFDI_Bitacora AS Bita
            ON Info.Folio_Interno = Bita.Doc_Num
        INNER JOIN EAI_OWNER.WA_VENTA_CENTRALIZADA AS Ctrl
            ON Bita.Cliente_SAP = Ctrl.Cliente_SAP
           AND Bita.Invc_dt BETWEEN Ctrl.Fecha_Ini_Vig AND Ctrl.Fecha_Fin_Vig;

        UPDATE EAI.CONTROL_REPORTE
           SET FIN = GETDATE()
         WHERE REPORTE = 'BITACORA CFDI';

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE(),
               Proceso_1 = @nProceso1,
               Proceso_2 = @nProceso2,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;

        PRINT 'Proceso completado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(30));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);
        SET @v_ID = ISNULL(@v_ID, 'Unknown');

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            'SF_BITACORA_CFDI_RESUMEN',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT '*********** Mensaje ************************';
        PRINT '****** Error en BITACORA_CFDI_RESUMEN ***** ';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
GO
