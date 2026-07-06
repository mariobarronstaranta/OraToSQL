CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @nDist           INT;
    DECLARE @sCtro           VARCHAR(4);
    DECLARE @sTerr           VARCHAR(4);
    DECLARE @sFecha          VARCHAR(8);
    DECLARE @dtFecha         DATETIME;
    DECLARE @sError          VARCHAR(250);
    DECLARE @sResp           VARCHAR(30);
    DECLARE @sFactura        VARCHAR(20);
    DECLARE @sNULL           VARCHAR(10);
    DECLARE @sMsg            VARCHAR(500);
    DECLARE @nItems          INT;
    DECLARE @v_ID            VARCHAR(50);
    DECLARE @sErrorCode      VARCHAR(20);
    DECLARE @dtInicio        DATETIME;
    DECLARE @nPID            INT;
    DECLARE @nProceso        INT;
    DECLARE @nProceso1       INT = 0;
    DECLARE @nProceso2       INT = 0;
    DECLARE @nProceso3       INT = 0;
    DECLARE @nProceso4       INT = 0;

    BEGIN TRY
        -- Inicio
        SET @dtInicio = GETDATE();
        SET @nProceso = 801;
        SET @nPID = (SELECT ISNULL(MAX(PID), 0) + 1 FROM [T3].[RF_PROCESOS_LOG]); -- Simulación de secuencia
        SET @sNULL = '     ';
        SET @v_ID = 'CEDIS.Clean';

        UPDATE [EAI].[CONTROL_REPORTE]
        SET INICIO = GETDATE(), FIN = NULL
        WHERE REPORTE = 'BITACORA CFDI - DETALLE';

        SET @v_ID = 'CFDI_Bitacora';

        -- Etapa 0: Cargar datos iniciales
        IF (@nEtapa <= 0)
        BEGIN
            DELETE FROM [EAI].[CFDI_Bitacora];

            INSERT INTO [EAI].[CFDI_Bitacora]
            (CTRO, DOC_NUM, FACTURA_SAP, NOTA_VENTA_CFDI, CLIENTE_SAP, CLTE_FACTURA_SAP, INVC_DT, TIPO_VTA, 
             FECHA_TRN, FECHA_PROC_BATMD, Valor_Subt, Valor_IVA, Bonif_Subt, Envio_Subt, Envio_IVA, Credito_Subt, Credito_Iva)
            SELECT 
                Info.Ctro,
                Info.Factura,
                Info.Factura_SAP,
                Info.Nota_Venta_CFDI,
                Info.Cliente_SAP,
                Info.Clte_Factura_SAP,
                Info.Fecha_Documento,
                Info.Tipo_Docto,
                Info.Fecha_Trn,
                Info.Fecha_Proc_BATMD,
                SUM(Info.Valor_Subt),
                SUM(Info.Valor_IVA),
                SUM(Info.Bonif_Subt),
                SUM(Info.ENVIO_SUBT),
                SUM(Info.ENVIO_IVA),
                SUM(Info.CREDITO_SUBT),
                SUM(Info.Credito_IVA)
            FROM (
                -- Primera parte UNION
                SELECT 
                    FG.Ctro,
                    FG.Factura,
                    FG.Entrega AS Factura_SAP,
                    HDP.Nota_Venta_CFDI,
                    FG.Cliente_SAP,
                    FG.Clte_Factura_SAP,
                    CAST(FG.Fecha_Factura AS DATE) AS Fecha_Documento,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 'Vta' ELSE 'Dev' END AS Tipo_Docto,
                    FG.Fecha_Trn,
                    FG.Fecha_Proc_BATMD,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Valor_Subt, 0) AS Valor_Subt,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Valor_IVA, 0) AS Valor_IVA,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Bonif_Subt, 0) AS Bonif_Subt,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Envio_Subt, 0) AS Envio_Subt,
                    CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.ENVIO_IVA, 0) AS ENVIO_IVA,
                    CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Credito_Subt, 0) AS Credito_Subt,
                    CASE WHEN FG.TIPO_DOCTO = 'C003' THEN 1 ELSE -1 END * ISNULL(FD.Credito_IVA, 0) AS Credito_IVA
                FROM [T3].[Factura_General] FG
                INNER JOIN [EAI].[FC__TIME_WINDOW] TW ON 1 = 1
                INNER JOIN [T3].[Factura_Detalle] FD ON FG.Factura = FD.Factura
                LEFT JOIN [T3].[CFDI_Historia_Docto_PAC] HDP ON FG.Factura = HDP.Nota_Venta
                WHERE FG.Fecha_Factura >= CONVERT(DATE, TW.Start_Date, 103)

                UNION ALL

                -- Segunda parte UNION
                SELECT 
                    FG.Ctro,
                    FG.Factura,
                    FG.Entrega AS Factura_SAP,
                    FG.Factura AS Nota_Venta_CFDI,
                    FG.Cliente_SAP,
                    FG.Cliente_SAP AS Clte_Factura_SAP,
                    CAST(FG.Fecha_Factura AS DATE) AS Fecha_Documento,
                    CASE WHEN FG.Clase_Factura = 'C005' THEN 'Vta' ELSE 'Dev' END AS Clase_Factura,
                    FG.Fecha_Trn,
                    FG.Fecha_Proc_BATMD,
                    CASE WHEN FG.Clase_Factura = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Valor_Subt, 0) AS Valor_Subt,
                    CASE WHEN FG.Clase_Factura = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Valor_IVA, 0) AS Valor_IVA,
                    CASE WHEN FG.Clase_Factura = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Bonif_Subt, 0) AS Bonif_Subt,
                    CASE WHEN FG.Clase_Factura = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Envio_Subt, 0) AS Envio_Subt,
                    CASE WHEN FG.CLASE_FACTURA = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Envio_IVA, 0) AS ENVIO_IVA,
                    CASE WHEN FG.CLASE_FACTURA = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Credito_Subt, 0) AS Credito_Subt,
                    CASE WHEN FG.CLASE_FACTURA = 'C005' THEN 1 ELSE -1 END * ISNULL(FD.Credito_IVA, 0) AS Credito_IVA
                FROM [T3].[Preventa_General] FG
                INNER JOIN [EAI].[FC__TIME_WINDOW] TW ON 1 = 1
                INNER JOIN [T3].[Preventa_Detalle] FD ON FG.Factura = FD.Factura
                WHERE FG.Fecha_Factura >= CONVERT(DATE, TW.Start_Date, 103)
                  AND FG.Fecha_Proc_BATMD IS NOT NULL
                  AND FG.Clase_Factura IN ('C005', 'C006', 'C025')
                  AND FG.Fecha_Cancelacion IS NULL
            ) Info
            GROUP BY Info.Ctro, Info.Factura, Info.Factura_SAP, Info.Nota_Venta_CFDI, Info.Cliente_SAP, 
                     Info.Clte_Factura_SAP, Info.Fecha_Documento, Info.Tipo_Docto, Info.Fecha_Trn, Info.Fecha_Proc_BATMD;

            -- Actualizar Tipo_Vta != 'Vta'
            UPDATE [EAI].[CFDI_Bitacora]
            SET Credit_Days = 0
            WHERE Tipo_Vta != 'Vta';

            -- Actualizar bonificaciones
            UPDATE [EAI].[CFDI_Bitacora]
            SET Bonif_Subt = (
                SELECT SUM(ISNULL(RFD.Bonif_Subt, 0) + ISNULL(RFD.Bonif_IVA, 0))
                FROM [T3].[Registro_Fiscal_Detalle] RFD
                INNER JOIN [EAI].[FC__TIME_Window] TW ON 1 = 1
                WHERE [EAI].[CFDI_Bitacora].Doc_Num = RFD.Factura
                  AND [EAI].[CFDI_Bitacora].Invc_dt >= DATEADD(MONTH, -1, CONVERT(DATE, TW.Start_Date, 103))
                HAVING SUM(ISNULL(RFD.Bonif_Subt, 0)) > 0
            )
            WHERE EXISTS (
                SELECT 1
                FROM [T3].[Registro_Fiscal_Detalle] RFD
                INNER JOIN [EAI].[FC__TIME_Window] TW ON 1 = 1
                WHERE [EAI].[CFDI_Bitacora].Doc_Num = RFD.Factura
                  AND [EAI].[CFDI_Bitacora].Invc_dt >= DATEADD(MONTH, -1, CONVERT(DATE, TW.Start_Date, 103))
                GROUP BY RFD.Factura
                HAVING SUM(ISNULL(RFD.Bonif_Subt, 0)) > 0
            );
        END

        -- Etapa 10: ScrPrompt
        SET @v_ID = 'ScrPrompt';
        IF (@nEtapa <= 10)
        BEGIN
            SET @sFecha = '010';
            UPDATE CB
            SET CB.Ctro = SP.Ctro,
                CB.Terr = SP.Terr
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROWID AS Bit_RowID,
                       FG.Ctro,
                       FG.Fecha_Trn,
                       FG.Fecha_Proc_BATMD,
                       SUBSTRING(FG.Ubicacion, 15, 4) AS Terr,
                       FG.Valor_Subt,
                       FG.Valor_IVA
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [T3].[Factura_General] FG ON Bit.Doc_Num = FG.Factura
            ) SP ON CB.ROWID = SP.Bit_RowID;

            SET @nProceso1 = @@ROWCOUNT;
        END

        -- Etapa 20: ScrPresales
        SET @v_ID = 'ScrPresales';
        IF (@nEtapa <= 20)
        BEGIN
            SET @sFecha = '020';
            UPDATE CB
            SET CB.Terr = SP.Terr
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROW_ID AS Bit_RowID,
                       FG.Ctro,
                       E.Fecha_Trn,
                       FG.Fecha_Proc_BATMD,
                       ISNULL(E.Ubicacion, FG.Ubicacion) AS Terr
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [T3].[Preventa_General] FG ON Bit.Doc_Num = FG.Factura
                INNER JOIN [T3].[Entrega] E ON Bit.Doc_Num = E.Factura
                WHERE FG.Fecha_Cancelacion IS NULL
                  AND YEAR(ISNULL(FG.Fecha_Proc_BATMD, DATEADD(DAY, 366, GETDATE()))) = YEAR(GETDATE())
            ) SP ON CB.ROW_ID = SP.Bit_RowID;

            SET @nProceso2 = @@ROWCOUNT;
        END

        -- Etapa 30: ScrIndividual
        SET @v_ID = 'ScrIndividual';
        IF (@nEtapa <= 30)
        BEGIN
            SET @sFecha = '030';
            UPDATE CB
            SET CB.Nota_Venta_CFDI = SI.Nota_Venta,
                CB.Fecha_Venta = CB.Invc_dt,
                CB.Fecha_Liberacion = SI.Fecha_Liberacion,
                CB.Fecha_Envio = SI.Fecha_Envio,
                CB.Fecha_Timbre = SI.Fecha_Timbre,
                CB.Fecha_CFD = SI.Fecha_CFD,
                CB.Status = SI.Status,
                CB.Total_CFD = SI.Total_CFD,
                CB.Docto_Ind = 1
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROW_ID AS Bit_RowID,
                       Doc.Nota_Venta,
                       Doc.Fecha_Liberacion,
                       Doc.Fecha_Envio,
                       Doc.Fecha_Timbre,
                       Doc.Fecha_CFD,
                       Doc.Status,
                       ISNULL(Doc.Valor_Subt, 0) + ISNULL(Doc.Valor_IVA, 0) AS Total_CFD
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [T3].[CFDI_Documentos] Doc ON Bit.Doc_Num = Doc.Nota_Venta
                WHERE Bit.Fecha_Proc_BATMD IS NOT NULL
            ) SI ON CB.ROW_ID = SI.Bit_RowID;
        END

        -- Etapa 40: ScrAgrupado
        SET @v_ID = 'ScrAgrupado';
        IF (@nEtapa <= 40)
        BEGIN
            SET @sFecha = '040';
            SET @nItems = 0;

            UPDATE CB
            SET CB.Fecha_Venta = SA.Fecha_Documento,
                CB.Fecha_Liberacion = SA.Fecha_Liberacion,
                CB.Fecha_Envio = SA.Fecha_Envio,
                CB.Fecha_Timbre = SA.Fecha_Timbre,
                CB.Fecha_CFD = SA.Fecha_CFD,
                CB.Status = SA.Status,
                CB.Total_CFD = SA.Total_CFD,
                CB.Docto_SAT = CASE WHEN CHARINDEX(SA.Nota_Venta, CB.Doc_Num) = 0 THEN 0 ELSE 1 END,
                CB.Doctos = CASE WHEN CHARINDEX(SA.Nota_Venta, CB.Doc_Num) = 0 THEN 0 ELSE SA.Doctos END
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROW_ID AS Bit_RowID,
                       Agr.Fecha_Documento,
                       Agr.Doctos,
                       Doc.Nota_Venta,
                       Doc.Fecha_Liberacion,
                       Doc.Fecha_Envio,
                       Doc.Fecha_Timbre,
                       Doc.Fecha_CFD,
                       Doc.Status,
                       ISNULL(Doc.Valor_Subt, 0) + ISNULL(Doc.Valor_IVA, 0) AS Total_CFD
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [T3].[CFDI_Historia_Docto_PAC] HDP ON Bit.Doc_Num = HDP.Nota_Venta
                INNER JOIN [T3].[CFDI_Agrupado] Agr ON HDP.Nota_Venta_CFDI = Agr.Nota_Venta_CFDI
                INNER JOIN [T3].[CFDI_Documentos] Doc ON HDP.Nota_Venta_CFDI = Doc.Nota_Venta
                WHERE Bit.Fecha_Proc_BATMD IS NOT NULL
                  AND HDP.Nota_Venta_CFDI != HDP.Nota_Venta
            ) SA ON CB.ROW_ID = SA.Bit_RowID;

            SET @nProceso3 = @@ROWCOUNT;
        END

        -- Etapa 80: ScrVolumen
        SET @v_ID = 'ScrVolumen';
        IF (@nEtapa <= 80)
        BEGIN
            UPDATE CB
            SET CB.Primer_Categoria = SV.Sticks,
                CB.Segunda_Categoria = SV.Segunda_Cat
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Info.Bit_ROWID,
                       SUM(Info.Sticks) AS Sticks,
                       SUM(Info.Segunda_Cat) AS Segunda_Cat
                FROM (
                    SELECT Bit.ROW_ID AS Bit_ROWID,
                           RFD.Material,
                           RFD.Cantidad_Vta,
                           CASE WHEN SUBSTRING(LTRIM(RFD.Material), 1, 1) = '1' 
                                THEN 1 
                                ELSE 0 
                           END * RFD.Cantidad_Vta * 
                           CASE WHEN SKU.Unidad_Med_Vta = 'CAJ' 
                                THEN SKU.Cig_x_CLL 
                                ELSE SKU.Cig_x_PAQ 
                           END AS Sticks,
                           CASE WHEN SUBSTRING(LTRIM(RFD.Material), 1, 1) = '1' 
                                THEN 0 
                                ELSE 1 
                           END * RFD.Cantidad_Vta AS Segunda_Cat
                    FROM [EAI].[CFDI_Bitacora] Bit
                    INNER JOIN [T3].[Registro_Fiscal] RF ON Bit.Doc_Num = RF.Factura
                    INNER JOIN [T3].[Registro_Fiscal_Detalle] RFD ON Bit.Doc_Num = RFD.Factura
                    INNER JOIN [T3].[Material] SKU ON RFD.Material = SKU.Material
                ) Info
                GROUP BY Info.Bit_ROWID
            ) SV ON CB.ROW_ID = SV.Bit_ROWID;
        END

        -- Etapa 90: SAP_Amount
        SET @v_ID = 'SAP_Amount';
        IF (@nEtapa <= 90)
        BEGIN
            UPDATE CB
            SET CB.SAP_Amount = SA.SAP_Amount
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROW_ID AS Bit_ROWID,
                       Bit.Doc_Num,
                       Bit.Factura_SAP,
                       CASE WHEN Bit.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END *
                       (SAP.Doc_NetAmt + SAP.Doc_TaxAmt) AS SAP_Amount
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [EAI].[T3R_Sales_Docs_Old] SAP ON Bit.Doc_Num = SAP.Doc_Num_Ref2
                WHERE SAP.Doc_Status NOT IN ('D', 'E')
            ) SA ON CB.ROW_ID = SA.Bit_ROWID;
        END

        -- Etapa 90: DESC_Amount
        SET @v_ID = 'DESC_Amount';
        IF (@nEtapa <= 90)
        BEGIN
            UPDATE CB
            SET CB.SAP_Amount = DA.SAP_Amount * -1 / 100
            FROM [EAI].[CFDI_Bitacora] CB
            INNER JOIN (
                SELECT Bit.ROW_ID AS Bit_ROWID,
                       Bit.Doc_Num,
                       SUM(Det.Valor_Subt + Det.Valor_IVA) AS SAP_Amount
                FROM [EAI].[CFDI_Bitacora] Bit
                INNER JOIN [EAI_Owner].[tmp_Document_Detail] Det ON Bit.Factura_SAP = Det.ReferenceID
                WHERE Bit.Doc_Num LIKE 'DESC%'
                GROUP BY Bit.ROW_ID, Bit.Doc_Num
            ) DA ON CB.ROW_ID = DA.Bit_ROWID;
        END

        -- Actualizar RFC
        UPDATE CB
        SET CB.RFC = (
            SELECT C.RFC
            FROM [T3].[Cliente] C
            WHERE C.Cliente_SAP = CB.Cliente_SAP
              AND CB.Invc_dt BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
        )
        FROM [EAI].[CFDI_Bitacora] CB
        WHERE EXISTS (
            SELECT 1
            FROM [T3].[Cliente] C
            WHERE C.Cliente_SAP = CB.Cliente_SAP
              AND CB.Invc_dt BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
        );

        -- Actualizar BackOffice
        UPDATE CB
        SET CB.Ctro = CASE 
                        WHEN BO.Tipo_Vta = 'Vta' THEN BO.Vta_Ctro
                        WHEN BO.Tipo_Vta = 'Dev' THEN BO.Dev_Ctro
                        ELSE CB.Ctro
                      END
        FROM [EAI].[CFDI_Bitacora] CB
        INNER JOIN (
            SELECT Bit.Ctro, Bit.Doc_Num, Bit.RFC, Bit.Cliente_SAP, Bit.Invc_dt, Bit.Tipo_Vta,
                   Back.Ctro_HUB AS Vta_Ctro,
                   Back.Ctro_Customer AS Dev_Ctro
            FROM [EAI].[CFDI_Bitacora] Bit
            INNER JOIN [EAI_Owner].[TAO_Cedis_Valid] Back ON Bit.Cliente_SAP = Back.Accnt_ID
               AND Bit.Cliente_SAP = Back.Loc
        ) BO ON CB.Doc_Num = BO.Doc_Num
        WHERE (BO.Tipo_Vta = 'Vta' AND CB.Ctro != BO.Vta_Ctro)
           OR (BO.Tipo_Vta = 'Dev' AND CB.Ctro != BO.Dev_Ctro);

        -- Finalizar
        UPDATE [CONTROL_REPORTE]
        SET FIN = GETDATE()
        WHERE REPORTE = 'BITACORA CFDI - DETALLE';

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
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT @ErrorMessage = ERROR_MESSAGE(),
               @ErrorSeverity = ERROR_SEVERITY(),
               @ErrorState = ERROR_STATE(),
               @sErrorCode = 'ORA-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg = SUBSTRING(@sErrorCode + '-' + @ErrorMessage, 1, 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, 
         SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
        ('Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error', 'SF_BITACORA_CFDI_1', @sMsg, 
         'SQL SERVER', @sErrorCode, NULL, NULL, NULL);

        PRINT '------------------------------------';
        PRINT '**** Error en BITACORA_CFDI *****';
        PRINT @sMsg;

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
