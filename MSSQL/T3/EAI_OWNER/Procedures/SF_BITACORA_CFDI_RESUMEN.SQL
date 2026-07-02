CREATE OR ALTER PROCEDURE [dbo].[SF_BITACORA_CFDI_RESUMEN]
    @pFecha_Inicio VARCHAR(30) = NULL,
    @pFecha_Final  VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Variables
    DECLARE @v_ID                VARCHAR(50);
    DECLARE @sErrorCode          VARCHAR(30);
    DECLARE @sMsg                VARCHAR(300);
    DECLARE @nPID                NUMERIC(8);
    DECLARE @nProceso            NUMERIC(8) = 802;
    DECLARE @nProceso1           NUMERIC(8) = 0;
    DECLARE @nProceso2           NUMERIC(8) = 0;
    DECLARE @nProceso3           NUMERIC(8) = 0;
    DECLARE @nProceso4           NUMERIC(8) = 0;
    DECLARE @nCount              NUMERIC(10) = 0;
    DECLARE @sFecha_Inicio       VARCHAR(30);
    DECLARE @sFecha_Final        VARCHAR(30);
    DECLARE @sAgrupada           VARCHAR(30);

    BEGIN TRY
        -- Log inicio
        SET @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID_Seq];
        
        INSERT INTO [T3].[RF_PROCESOS_LOG] (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES (@nPID, @nProceso, NULL, GETDATE());

        PRINT '-----------------------------';
        PRINT 'Proc_T3_CFDI_Resumen';
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);

        -- Determinar rango de fechas
        IF @pFecha_Inicio IS NULL
        BEGIN
            SELECT 
                @sFecha_Inicio = CONVERT(VARCHAR, DATEADD(MONTH, -1, CAST(Start_Date AS DATE)), 112),
                @sFecha_Final  = CONVERT(VARCHAR, CAST(GETDATE() AS DATE), 112)
            FROM [EAI].[FC__Time_WINDOW];
        END
        ELSE
        BEGIN
            SET @sFecha_Inicio = @pFecha_Inicio;
            SET @sFecha_Final  = @pFecha_Final;
        END;

        -- Limpiar e inicializar
        UPDATE [EAI].[CONTROL_REPORTE] 
        SET INICIO = GETDATE(), FIN = NULL
        WHERE REPORTE = 'BITACORA CFDI';

        DELETE FROM [EAI].[CFDI_Informe];

        -- ========== CURSOR 1: PROMPT (Factura General) ==========
        INSERT INTO [EAI].[CFDI_Informe] 
            (Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio, ID_Confirmacion,
             Nombre_Cliente, LP, Doctos, Terr, Tipo_Docto, Factor, Folio_Fiscal, 
             Status, Monto_T3In, Valor_Subt, Valor_IVA, Valor)
        SELECT 
            'MX06' AS Sociedad,
            HDoc.Nota_Venta_CFDI AS Folio_Interno,
            HDoc.Fecha_Factura AS Fecha,
            HDoc.Ctro,
            Paso.RFC_Factura AS RFC,
            PAC.ID_Envio,
            PAC.ID_Confirmacion,
            Cte.Nombre AS Nombre_Cliente,
            Cte.Lista_Precio AS LP,
            1 AS Doctos,
            SUBSTRING(FG.Ubicacion, 15, 4) AS Terr,
            FG.Tipo_Docto,
            CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END AS Factor,
            PAC.Folio_Fiscal,
            PAC.Status,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt + PAC.Valor_IVA
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_Subt + FG.Valor_IVA
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END AS Monto_T3In,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_Subt
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END AS Valor_Subt,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_IVA
                ELSE 0
            END * CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END AS Valor_IVA,
            (CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END) 
            * (CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt + PAC.Valor_IVA
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_Subt + FG.Valor_IVA
                ELSE 0
              END) AS Valor
        FROM [T3].[CFDI_Historia_Docto_PAC] HDoc
        INNER JOIN [T3].[CFDI_Documento_Paso] Paso ON HDoc.Nota_Venta = Paso.Factura
        INNER JOIN [T3].[Factura_General] FG ON HDoc.Nota_Venta = FG.Factura
        INNER JOIN [T3].[CFDI_Documentos] PAC ON HDoc.Nota_Venta = PAC.Nota_Venta
        INNER JOIN [T3].[Cliente] Cte ON FG.Cliente_SAP = Cte.Cliente_SAP
        WHERE CONVERT(VARCHAR, HDoc.Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
          AND HDoc.Nota_Venta = HDoc.Nota_Venta_CFDI
          AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig;

        SET @nProceso1 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso1;
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);

        -- ========== CURSOR 2: PREVENTA ==========
        INSERT INTO [EAI].[CFDI_Informe] 
            (Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio, ID_Confirmacion,
             Nombre_Cliente, LP, Doctos, Terr, Tipo_Docto, Factor, Folio_Fiscal, 
             Status, Monto_T3In, Valor_Subt, Valor_IVA, Valor)
        SELECT 
            CASE WHEN PG.Clase_Factura IN ('C020', 'C021', 'C022') THEN 'MX01' ELSE 'MX06' END AS Sociedad,
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
            CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END AS Factor,
            PAC.Folio_Fiscal,
            PAC.Status,
            CASE 
                WHEN PG.Fecha_Cancelacion IS NOT NULL THEN 0
                WHEN YEAR(PG.Fecha_Proc_BATMD) = 2999 THEN 0
                ELSE (ISNULL(PG.Valor_Subt, 0) + ISNULL(PG.Valor_IVA, 0)) 
                     * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END
            END AS Monto_T3In,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN PG.Valor_Subt
                ELSE 0
            END * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN PG.Valor_IVA
                ELSE 0
            END * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END,
            CASE 
                WHEN PG.Fecha_Cancelacion IS NOT NULL THEN 0
                WHEN YEAR(PG.Fecha_Proc_BATMD) = 2999 THEN 0
                ELSE (ISNULL(PG.Valor_Subt, 0) + ISNULL(PG.Valor_IVA, 0)) 
                     * CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END
            END
        FROM [T3].[CFDI_Historia_Docto_PAC] HDoc
        INNER JOIN [T3].[Preventa_General] PG ON HDoc.Nota_Venta = PG.Factura
        INNER JOIN [T3].[CFDI_Documentos] PAC ON HDoc.Nota_Venta = PAC.Nota_Venta
        INNER JOIN [T3].[Cliente] Cte ON PG.Cliente_SAP = Cte.Cliente_SAP
        LEFT JOIN [T3].[Entrega] E ON PG.Factura = E.Factura
        WHERE CONVERT(VARCHAR, HDoc.Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
          AND HDoc.Nota_Venta = HDoc.Nota_Venta_CFDI
          AND PG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig;

        SET @nProceso2 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso2;
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);

        -- ========== CURSOR 3: AGRUPADO ==========
        WITH CTE_AgrupDoc AS (
            SELECT 
                HDoc.CTRO, 
                HDoc.FECHA_FACTURA, 
                HDoc.NOTA_VENTA_CFDI,
                SUM(FD.VALOR_SUBT + FD.VALOR_IVA + ISNULL(FD.ENVIO_SUBT, 0) 
                    + ISNULL(FD.ENVIO_IVA, 0) + ISNULL(FD.Credito_Subt, 0) 
                    + ISNULL(FD.Credito_IVA, 0)) AS Total_T3In
            FROM (
                SELECT DISTINCT Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI
                FROM [T3].[CFDI_Historia_Docto_PAC]
                WHERE CONVERT(VARCHAR, Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
            ) HDoc
            INNER JOIN [T3].[Factura_General] FG ON HDoc.Nota_Venta = FG.Factura
            INNER JOIN [T3].[Factura_Detalle] FD ON HDoc.Nota_Venta = FD.Factura
            WHERE CONVERT(VARCHAR, HDoc.Fecha_Factura, 112) BETWEEN @sFecha_Inicio AND @sFecha_Final
              AND HDoc.Nota_Venta != HDoc.Nota_Venta_CFDI
            GROUP BY HDoc.Ctro, HDoc.Fecha_Factura, HDoc.Nota_Venta_CFDI
        ),
        CTE_AgrResumen AS (
            SELECT 
                AGR.CTRO,
                SUBSTRING(AGR.CLIENTE_SAP, 2, 5) AS TERR,
                AGR.TIPO_DOCTO,
                AGR.NOTA_VENTA_CFDI,
                CAST(AGR.FECHA_DOCUMENTO AS DATE) AS FECHA,
                MAX(AGR.DOCTOS) AS DOCTOS,
                SUM(DET.VALOR_SUBT + ISNULL(DET.ENVIO_SUBT, 0) + ISNULL(DET.CREDITO_SUBT, 0)) AS VALOR_SUBT,
                SUM(DET.Valor_IVA + ISNULL(DET.Envio_IVA, 0) + ISNULL(DET.Credito_IVA, 0)) AS Valor_IVA
            FROM [T3].[CFDI_Agrupado] AGR
            INNER JOIN [T3].[CFDI_Agrupado_Detalle] DET ON AGR.Nota_Venta_CFDI = DET.Nota_Venta_CFDI
            GROUP BY AGR.Ctro, SUBSTRING(AGR.CLIENTE_SAP, 2, 5), AGR.Tipo_Docto,
                     AGR.Nota_Venta_CFDI, CAST(AGR.FECHA_DOCUMENTO AS DATE)
        )
        INSERT INTO [EAI].[CFDI_Informe] 
            (Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio, ID_Confirmacion,
             Nombre_Cliente, Doctos, Terr, Tipo_Docto, Factor, Folio_Fiscal, 
             Status, Monto_T3In, Valor_Subt, Valor_IVA, Valor)
        SELECT 
            'MX06',
            Doc.Nota_Venta_CFDI,
            Doc.FECHA_FACTURA,
            Doc.CTRO,
            'XAXX010101000',
            PAC.ID_Envio,
            PAC.ID_Confirmacion,
            'CLIENTE AGRUPADOR VENTAS DIA',
            FG.DOCTOS,
            FG.TERR,
            FG.TIPO_DOCTO,
            CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END,
            PAC.Folio_Fiscal,
            PAC.Status,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt + PAC.Valor_IVA
                WHEN PAC.Status = 'PENDING' THEN FG.VALOR_SUBT + FG.Valor_IVA
                ELSE 0
            END * CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                WHEN PAC.Status = 'PENDING' THEN FG.VALOR_SUBT
                ELSE 0
            END * CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END,
            CASE 
                WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                WHEN PAC.Status = 'PENDING' THEN FG.Valor_IVA
                ELSE 0
            END * CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END,
            Doc.Total_T3In * CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END
        FROM CTE_AgrupDoc Doc
        INNER JOIN CTE_AgrResumen FG ON Doc.Nota_Venta_CFDI = FG.NOTA_VENTA_CFDI
        INNER JOIN [T3].[CFDI_Documentos] PAC ON Doc.Nota_Venta_CFDI = PAC.Nota_Venta;

        SET @nProceso3 = @@ROWCOUNT;
        SET @nCount = @nCount + @nProceso3;
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);
        PRINT 'Registros : ' + CAST(@nCount AS VARCHAR);
        PRINT '-----------------------------';

        -- ========== UPDATE CIGARRILLOS (Individual) ==========
        SET @nCount = 0;
        SET @v_ID = 'ScrCIG_Individual';

        UPDATE ci
        SET 
            CIGARRILLOS = cig.Cigarrillos,
            ENVIO_SUBT = ci.FACTOR * cig.ENVIO_SUBT,
            ENVIO_IVA = ci.FACTOR * cig.ENVIO_IVA,
            CREDITO_SUBT = ci.FACTOR * cig.CREDITO_SUBT,
            CREDITO_IVA = ci.FACTOR * cig.CREDITO_IVA,
            Monto_T3In = Monto_T3In + (ci.Factor * (cig.Envio_Subt + cig.Envio_IVA 
                        + cig.Credito_Subt + cig.Credito_IVA) * cig.Sumar_Envio)
        FROM [EAI].[CFDI_Informe] ci
        INNER JOIN (
            SELECT 
                CFD.ID AS CFD_ID, -- Asume que CFDI_Informe tiene columna ID como PK
                RF.Factura,
                SUM(CFD.Factor * RFD.Cantidad_Vta 
                    * CASE WHEN Prod.Unidad_Med_Vta = 'CAJ' THEN ISNULL(Prod.Cig_x_CLL, 1)
                           ELSE ISNULL(Prod.Cig_x_PAQ, 1) END) AS Cigarrillos,
                MAX(CASE WHEN RF.Tipo_Docto IN ('C005', 'C006') THEN 0 ELSE 1 END) AS Sumar_Envio,
                SUM(ISNULL(RFD.ENVIO_SUBT, 0)) AS ENVIO_SUBT,
                SUM(ISNULL(RFD.ENVIO_IVA, 0)) AS ENVIO_IVA,
                SUM(ISNULL(RFD.CREDITO_SUBT, 0)) AS CREDITO_SUBT,
                SUM(ISNULL(RFD.Credito_IVA, 0)) AS CREDITO_IVA
            FROM [EAI].[CFDI_Informe] CFD
            INNER JOIN [T3].[Registro_Fiscal] RF ON CFD.Folio_Interno = RF.Factura
            INNER JOIN [T3].[Registro_Fiscal_Detalle] RFD ON CFD.Folio_Interno = RFD.Factura
            INNER JOIN [T3].[Material] Prod ON RFD.Material = Prod.Material
            GROUP BY CFD.ID, RF.Factura
        ) cig ON ci.ID = cig.CFD_ID;

        SET @nCount = @@ROWCOUNT;
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);
        PRINT 'Actualizados : ' + CAST(@nCount AS VARCHAR);
        PRINT '-----------------------------';

        -- ========== UPDATE CIGARRILLOS (Agrupado) ==========
        SET @nCount = 0;
        SET @v_ID = 'ScrCIG_Agrupado';

        UPDATE ci
        SET 
            CIGARRILLOS = cig.Cigarrillos,
            ENVIO_SUBT = ci.FACTOR * cig.ENVIO_SUBT,
            ENVIO_IVA = ci.FACTOR * cig.ENVIO_IVA,
            CREDITO_SUBT = ci.FACTOR * cig.CREDITO_SUBT,
            CREDITO_IVA = ci.FACTOR * cig.CREDITO_IVA
        FROM [EAI].[CFDI_Informe] ci
        INNER JOIN (
            SELECT 
                CFD.ID AS CFD_ID,
                RF.Nota_Venta_CFDI,
                SUM(CFD.Factor * RFD.Cantidad_Vta 
                    * CASE WHEN Prod.Unidad_Med_Vta = 'CAJ' THEN ISNULL(Prod.Cig_x_CLL, 1)
                           ELSE ISNULL(Prod.Cig_x_PAQ, 1) END) AS Cigarrillos,
                SUM(ISNULL(RFD.ENVIO_SUBT, 0)) AS ENVIO_SUBT,
                SUM(ISNULL(RFD.Envio_IVA, 0)) AS ENVIO_IVA,
                SUM(ISNULL(RFD.CREDITO_SUBT, 0)) AS CREDITO_SUBT,
                SUM(ISNULL(RFD.Credito_IVA, 0)) AS CREDITO_IVA
            FROM [EAI].[CFDI_Informe] CFD
            INNER JOIN [T3].[CFDI_Agrupado] RF ON CFD.Folio_Interno = RF.Nota_Venta_CFDI
            INNER JOIN [T3].[CFDI_Agrupado_Detalle] RFD ON CFD.Folio_Interno = RFD.Nota_Venta_CFDI
            INNER JOIN [T3].[Material] Prod ON RFD.Material = Prod.Material
            GROUP BY CFD.ID, RF.Nota_Venta_CFDI
        ) cig ON ci.ID = cig.CFD_ID;

        SET @nCount = @@ROWCOUNT;
        PRINT CONVERT(VARCHAR, GETDATE(), 112) + ' ' + CONVERT(VARCHAR, GETDATE(), 108);
        PRINT 'Actualizados : ' + CAST(@nCount AS VARCHAR);
        PRINT '-----------------------------';

        -- ========== UPDATE Lista Precio Agrupada ==========
        SET @nCount = 0;
        SET @v_ID = 'ScrComplementoAGR';

        UPDATE [EAI].[CFDI_Informe]
        SET LP = lp_agr.Grupo_Precio
        FROM [EAI].[CFDI_Informe] ci
        INNER JOIN (
            SELECT DISTINCT 
                ci_temp.ID,
                doc.Grupo_Precio
            FROM [EAI].[CFDI_Informe] ci_temp
            INNER JOIN [T3].[CFDI_Historia_Docto_PAC] HDP ON ci_temp.Folio_Interno = HDP.Nota_Venta_CFDI
            CROSS APPLY (
                SELECT TOP 1 Grupo_Precio
                FROM [T3].[Fact_T3]
                WHERE Factura = HDP.Nota_Venta
                UNION ALL
                SELECT TOP 1 Grupo_Precio
                FROM [T3].[Nota_T3]
                WHERE Factura = HDP.Nota_Venta
            ) doc
            WHERE ci_temp.LP IS NULL
              AND ci_temp.Nombre_Cliente = 'CLIENTE AGRUPADOR VENTAS DIA'
        ) lp_agr ON ci.ID = lp_agr.ID;

        SET @nCount = @@ROWCOUNT;
        PRINT 'Lista Precio Actualizado: ' + CAST(@nCount AS VARCHAR);

        -- ========== AJUSTES POR DIFERENCIAS ==========
        SET @v_ID = 'ScrAgrupadoDiferencia';
        UPDATE ci
        SET Valor_IVA = Valor_IVA + dif.Ajuste, 
            Valor = Valor + dif.Ajuste
        FROM [EAI].[CFDI_Informe] ci
        INNER JOIN [T3].[CFDI_Agrupado_DIF] dif ON ci.Folio_Interno = dif.Nota_Venta_CFDI
        WHERE ci.Folio_Interno LIKE 'G-%'
          AND dif.Ajuste != 0;

        SET @nProceso4 = @@ROWCOUNT;

        SET @v_ID = 'ScrIndividualDiferencia';
        UPDATE ci
        SET Valor_IVA = Valor_IVA + dif.Ajuste, 
            Valor = Valor + dif.Ajuste
        FROM [EAI].[CFDI_Informe] ci
        INNER JOIN [T3].[CFDI_Agrupado_DIF] dif ON ci.Folio_Interno = dif.Nota_Venta_CFDI
        WHERE ci.Folio_Interno NOT LIKE 'G-%'
          AND dif.Ajuste != 0;

        SET @nProceso4 = @nProceso4 + @@ROWCOUNT;

        -- ========== ACTUALIZAR ADDENDA ==========
        SET @v_ID = 'Updating Addenda';
        UPDATE [EAI].[CFDI_Informe]
        SET Addenda = 'SI'
        WHERE RFC IN (SELECT RFC FROM [T3].[CFDI_Addenda]);

        UPDATE [EAI].[CFDI_Informe]
        SET Addenda = 'NO'
        WHERE Addenda IS NULL;

        -- ========== VALIDAR VALORES PUBLICADOS ==========
        UPDATE [EAI].[CFDI_Informe]
        SET Valor = Monto_T3In
        WHERE Status = 'PUBLICADO'
          AND Valor != Monto_T3In;

        -- ========== FINALIZAR ==========
        UPDATE [EAI].[CONTROL_REPORTE]
        SET FIN = GETDATE()
        WHERE REPORTE = 'BITACORA CFDI';

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

        PRINT 'Proceso completado exitosamente.';

    END TRY
    BEGIN CATCH
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(30));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);
        SET @v_ID = ISNULL(@v_ID, 'Unknown');

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME, 
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES 
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error', 'BITACORA_CFDI_RESUMEN_1', 
             @sMsg, 'T-SQL Procedure', @sErrorCode, NULL, NULL, NULL);

        PRINT '*********** Mensaje ************************';
        PRINT '****** Error en BITACORA_CFDI_RESUMEN ***** ';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
