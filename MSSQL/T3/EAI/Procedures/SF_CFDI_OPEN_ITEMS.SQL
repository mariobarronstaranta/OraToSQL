-- ============================================================================
-- PROCEDURE: SF_CFDI_OPEN_ITEMS (Oracle → SQL Server)
-- Descripción: Procesa items abiertos de CFDI, reconcilia con SAP y calcula 
--              importes aplicados, efectivo, crédito memo e información fiscal
-- Migrado: Junio 2026 | Versión 2.0 SQL Server (optimizado)
-- ============================================================================

CREATE OR ALTER PROCEDURE [dbo].[SF_CFDI_OPEN_ITEMS]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @nDist               INT;
    DECLARE @sCtro               NVARCHAR(4);
    DECLARE @dtFecha             DATETIME2;
    DECLARE @sError              NVARCHAR(250);
    DECLARE @sResp               NVARCHAR(30);
    DECLARE @sFactura            NVARCHAR(20);
    DECLARE @sNULL               NVARCHAR(10);
    DECLARE @sMsg                NVARCHAR(500);
    DECLARE @nItems              INT;
    DECLARE @v_ID                NVARCHAR(50);
    DECLARE @sErrorCode          NVARCHAR(20);
    DECLARE @dtInicio            DATETIME2;
    DECLARE @nPID                INT;
    DECLARE @nProceso            INT;
    DECLARE @nProceso1           INT = 0;
    DECLARE @nProceso2           INT = 0;
    DECLARE @nProceso3           INT = 0;
    DECLARE @nProceso4           INT = 0;
    DECLARE @nImporte_Aplicado   NUMERIC(16, 2);
    DECLARE @nImporte_Timbrado   NUMERIC(16, 2);
    
    -- TABLA TEMPORAL PARA LOGS DE ERRORES
    CREATE TABLE #ErrorLog (
        ErrorCode NVARCHAR(20),
        ErrorMsg NVARCHAR(500),
        ContextID NVARCHAR(50),
        LogTime DATETIME2
    );
    
    BEGIN TRY
        -- ====== INICIO ======
        SET @dtInicio = GETDATE();
        SET @nProceso = 923;
        SET @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID_Seq];  -- O usar IDENTITY si aplica
        SET @v_ID = 'CFDI_OPEN_ITEMS';
        SET @sNULL = '     ';
        
        EXEC [EAI_Owner].[Log_Start] @nProceso;
        
        INSERT INTO [T3].[RF_PROCESOS_LOG] (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES (@nPID, @nProceso, NULL, @dtInicio);
        
        -- ====== ETAPA 000: LIMPIEZA E INSERCIÓN INICIAL ======
        IF (COALESCE(@nEtapa, 0) <= 0)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa000';
            
            DELETE FROM [EAI].[CFDI_OPEN_ITEMS];
            
            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
                (Nota_Venta, Cliente_SAP, Fecha_Venta, Tipo_Docto, Saldo_SAP, Last_Updated)
            SELECT
                DOI.Nota_Venta,
                DOI.Cliente_SAP,
                DOI.Fecha_Venta,
                DOI.Tipo_Docto,
                DOI.Saldo_SAP,
                GETDATE()
            FROM (
                SELECT 
                    SAP.Referencia AS Nota_Venta,
                    COALESCE(RF.Tipo_Docto, 'NULL') AS Tipo_Docto,
                    MAX(SAP.Asignacion) AS Asignacion,
                    MAX(SAP.Cliente) AS Cliente_SAP,
                    MIN(SAP.Fecha_Doc) AS Fecha_Doc,
                    SUM(COALESCE(SAP.Monto, 0)) AS Saldo_SAP
                FROM (
                    SELECT 
                        SAP.Cliente,
                        COALESCE(Conv.Docto_T3MX, SAP.Referencia) AS Referencia,
                        SAP.Fecha_Doc,
                        SAP.Tipo_Doc,
                        SAP.Monto,
                        SAP.Asignacion,
                        CAST(SAP.Fecha_Doc AS DATE) AS Fecha_Venta
                    FROM [EAI].[T3R_Cartera_SAP_OLD] SAP
                    LEFT JOIN (
                        SELECT Docto_SAP, Docto_T3MX 
                        FROM [T3].[CFDI_Refoleo] 
                        WHERE Tipo_Registro = 'DOI'
                    ) Conv ON SAP.Referencia = Conv.Docto_SAP
                ) SAP
                LEFT JOIN [T3].[Registro_Fiscal] RF ON SAP.Referencia = RF.Factura
                WHERE SAP.Referencia NOT IN (SELECT Factura FROM [T3].[Otros_General])
                GROUP BY SAP.Referencia, COALESCE(RF.Tipo_Docto, 'NULL')
            ) DOI
            WHERE 
                CASE
                    WHEN DOI.Tipo_Docto IN ('C003', 'C005') THEN 'Vta'
                    WHEN DOI.Tipo_Docto IN ('C004', 'C006', 'C019', 'C025') THEN 'Dev'
                    ELSE CASE WHEN DOI.Saldo_SAP = ABS(DOI.Saldo_SAP) THEN 'Vta' ELSE 'Dev' END
                END IS NOT NULL;
            
            SET @nProceso1 = @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 010: HISTÓRICO Y RECONCILIACIÓN ======
        IF (COALESCE(@nEtapa, 0) <= 10)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa010';
            
            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
                (Ctro, Nota_Venta, Cliente_SAP, Clte_Factura_SAP, Fecha_Venta, Tipo_Docto, Importe_Vta, Last_Updated)
            SELECT
                Vta.Ctro,
                Vta.Nota_Venta,
                Vta.Cliente_SAP,
                Vta.Cliente_SAP,
                Vta.Fecha_Venta,
                Vta.Clase_Factura,
                Vta.Importe_Venta,
                GETDATE()
            FROM (
                SELECT 
                    Nota.Ctro,
                    Nota.Fecha_Venta,
                    Nota.Clase_Factura,
                    Nota.Nota_Venta,
                    Nota.Cliente_SAP,
                    Nota.RFC,
                    SUM(Nota.Importe_Item) AS Importe_Venta
                FROM (
                    -- UNIÓN: Facturas + Preventas
                    SELECT  
                        FG.Ctro,
                        FG.Fecha_Factura AS Fecha_Venta,
                        FG.Tipo_Docto AS Clase_Factura,
                        FG.Factura AS Nota_Venta,
                        FD.Material,
                        FG.Cliente_SAP,
                        Cte.RFC,
                        (COALESCE(FD.Valor_Subt, 0) +
                         COALESCE(FD.Valor_IVA, 0) +
                         COALESCE(FD.Credito_Subt, 0) +
                         COALESCE(FD.Credito_IVA, 0) +
                         COALESCE(FD.Envio_Subt, 0) +
                         COALESCE(FD.Envio_IVA, 0)) AS Importe_Item
                    FROM [T3].[Factura_General] FG
                    INNER JOIN [T3].[Factura_Detalle] FD ON FG.Factura = FD.Factura
                    INNER JOIN [T3].[Cliente] Cte ON FG.Cliente_SAP = Cte.Cliente_SAP
                    WHERE FG.Fecha_Factura >= CAST('20230101' AS DATE)
                      AND FG.Tipo_Docto IN ('C003', 'C004')
                      AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                    
                    UNION ALL
                    
                    SELECT  
                        FG.Ctro,
                        FG.Fecha_Factura AS Fecha_Venta,
                        FG.Clase_Factura,
                        FG.Factura AS Nota_Venta,
                        FD.Material,
                        FG.Cliente_SAP,
                        Cte.RFC,
                        (COALESCE(FD.Valor_Subt, 0) +
                         COALESCE(FD.Valor_IVA, 0) +
                         COALESCE(FD.Credito_Subt, 0) +
                         COALESCE(FD.Credito_IVA, 0) +
                         COALESCE(FD.Envio_Subt, 0) +
                         COALESCE(FD.Envio_IVA, 0)) AS Importe_Item
                    FROM [T3].[Preventa_General] FG
                    INNER JOIN [T3].[Preventa_Detalle] FD ON FG.Factura = FD.Factura
                    INNER JOIN [T3].[Cliente] Cte ON FG.Cliente_SAP = Cte.Cliente_SAP
                    WHERE FG.Fecha_Factura >= CAST('20230101' AS DATE)
                      AND FG.Clase_Factura IN ('C005', 'C006', 'C019', 'C025')
                      AND FG.Fecha_Proc_BATMD IS NOT NULL
                      AND FG.Fecha_Cancelacion IS NULL
                      AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                ) Nota
                GROUP BY Nota.Ctro, Nota.Fecha_Venta, Nota.Clase_Factura, 
                         Nota.Nota_Venta, Nota.Cliente_SAP, Nota.RFC
            ) Vta
            LEFT JOIN [EAI].[CFDI_OPEN_ITEMS] DOI ON Vta.Nota_Venta = DOI.Nota_Venta
            WHERE DOI.Last_Updated IS NULL
              AND ABS(COALESCE(Vta.Importe_Venta, 0) - 
                  COALESCE((CASE 
                      WHEN Vta.Clase_Factura IN ('C003', 'C005') 
                      THEN [T3].[FN_Cobza_Pay](Vta.Nota_Venta)
                      ELSE [T3].[FN_COBZA_CM_UUID](Vta.Nota_Venta)
                  END), 0)) > 0.05;
            
            SET @nProceso4 = @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 020: ACTUALIZACION DE VENTAS (ScrVenta) ======
        IF (COALESCE(@nEtapa, 0) <= 20)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa020';
            
            UPDATE DOI
            SET 
                DOI.Importe = Cobza.Importe,
                DOI.Efectivo = Cobza.Efectivo,
                DOI.Agrupado = Cobza.Agrupado,
                DOI.Aplica_NC = Cobza.Aplica_NC,
                DOI.Efectivo_UUID = Cobza.Efectivo_UUID,
                DOI.Agrupado_UUID = Cobza.Agrupado_UUID,
                DOI.Aplica_NC_UUID = Cobza.Aplica_NC_UUID,
                DOI.Importe_UUID = Cobza.Importe_UUID,
                DOI.Incobrable = Cobza.Incobrable,
                DOI.Metodo_Pago = CFD.Metodo_Pago,
                DOI.Tipo_Docto = 'Vta',
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN [T3].[CFDI_Documentos] CFD ON DOI.Nota_Venta = CFD.Nota_Venta
            INNER JOIN (
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
                FROM (
                    SELECT 
                        Cobza.Factura,
                        Cobza.Asignacion_ID,
                        Cobza.Importe,
                        Cobza.Via_Pago,
                        Cobza.Nota_Credito,
                        CASE WHEN Cobza.Via_Pago = '01' THEN Cobza.Importe ELSE 0 END AS Efectivo,
                        CASE WHEN Cobza.Via_Pago IN ('02', '03') THEN Cobza.Importe ELSE 0 END AS Agrupado,
                        CASE WHEN Cobza.Via_Pago = 'CM' THEN Cobza.Importe ELSE 0 END AS Aplica_NC,
                        CASE WHEN Cobza.Via_Pago = 'AI' THEN Cobza.Importe ELSE 0 END AS Incobrable,
                        (CASE WHEN Pago.Folio_Fiscal IS NOT NULL THEN 1 ELSE 0 END +
                         CASE WHEN Agr.Folio_Fiscal IS NOT NULL THEN 1 ELSE 0 END +
                         CASE WHEN Nota.Folio_Fiscal IS NOT NULL THEN 1 ELSE 0 END) AS Timbrado
                    FROM [T3].[CFDI_Cobranza] Cobza
                    LEFT JOIN [T3].[CFDI_Documentos] Pago ON Cobza.Asignacion_ID = Pago.Nota_Venta
                    LEFT JOIN (
                        SELECT DISTINCT CAP.Agrupacion, CAP.Fecha_Pago, CAP.Asignacion_Id
                        FROM [T3].[CFDI_Agrupacion_Pago] CAP
                        INNER JOIN [T3].[CFDI_Agrupacion_Ctrl] CAC ON CAP.Agrupacion = CAC.Agrupacion
                        WHERE COALESCE(CAC.Importe, 0) <> 0
                    ) AgrP ON Cobza.Asignacion_ID = AgrP.Asignacion_Id
                    LEFT JOIN [T3].[CFDI_Documentos] Agr ON CAST(AgrP.Agrupacion AS NVARCHAR) = Agr.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Documentos] Nota ON Cobza.Nota_Credito = Nota.Nota_Venta
                ) Cobza
                GROUP BY Cobza.Factura
            ) Cobza ON DOI.Nota_Venta = Cobza.Factura
            WHERE DOI.Tipo_Docto = 'Vta';
            
            SET @nProceso2 = @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 030: ACTUALIZACIÓN DE DEVOLUCIONES (ScrDevolucion) ======
        IF (COALESCE(@nEtapa, 0) <= 30)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa030';
            
            UPDATE DOI
            SET 
                DOI.Importe_NC = CreditMemo.Importe_Aplicado,
                DOI.Incobrable = CreditMemo.Incobrable,
                DOI.Fecha_Aplicacion = CreditMemo.Fecha_Asignacion,
                DOI.Tipo_Docto = 'Dev',
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    Cobza.Nota_Credito,
                    COUNT(Cobza.Asignacion_ID) AS Aplicaciones,
                    SUM(COALESCE(Cobza.Importe, 0) * CASE WHEN Cobza.Via_Pago = 'CM' THEN 1 ELSE 0 END) AS Importe_Aplicado,
                    SUM(COALESCE(Cobza.Importe, 0) * CASE WHEN Cobza.Via_Pago = 'AI' THEN 1 ELSE 0 END) AS Incobrable,
                    MAX(Cobza.Fecha_Asignacion) AS Fecha_Asignacion
                FROM [T3].[CFDI_Cobranza] Cobza
                GROUP BY Cobza.Nota_Credito
            ) CreditMemo ON DOI.Nota_Venta = CreditMemo.Nota_Credito
            WHERE DOI.Tipo_Docto = 'Dev';
            
            SET @nProceso2 = @nProceso2 + @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 060: ACTUALIZACIÓN DE IMPORTES (ScrImporteVenta + ScrImporteDebitNote) ======
        IF (COALESCE(@nEtapa, 0) <= 60)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa060';
            
            -- Actualización desde Registro Fiscal
            UPDATE DOI
            SET 
                DOI.Ctro = ImporteVta.Ctro,
                DOI.RFC = ImporteVta.RFC,
                DOI.Importe_Vta = ImporteVta.Importe_Vta,
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    FG.Factura AS Nota_Venta,
                    FG.Ctro,
                    MC.RFC,
                    SUM(
                        COALESCE(FD.Valor_Subt, 0) +
                        COALESCE(FD.Valor_IVA, 0) +
                        COALESCE(FD.Envio_Subt, 0) +
                        COALESCE(FD.Envio_IVA, 0) +
                        COALESCE(FD.Credito_Subt, 0) +
                        COALESCE(FD.Credito_IVA, 0)
                    ) AS Importe_Vta
                FROM [T3].[Registro_Fiscal] FG
                INNER JOIN [T3].[Registro_Fiscal_Detalle] FD ON FG.Factura = FD.Factura
                LEFT JOIN [T3].[Mov_Cliente] MC ON FG.Cliente_SAP = MC.Cliente_SAP
                GROUP BY FG.Factura, FG.Ctro, MC.RFC
            ) ImporteVta ON DOI.Nota_Venta = ImporteVta.Nota_Venta;
            
            SET @nProceso3 = @@ROWCOUNT;
            
            -- Actualización desde Debit Notes
            UPDATE DOI
            SET 
                DOI.Ctro = ImporteDebit.Ctro,
                DOI.RFC = ImporteDebit.RFC,
                DOI.Importe_Vta = ImporteDebit.Importe,
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    DOI_Inner.Nota_Venta,
                    DN.Total_Amt AS Importe,
                    DN.Document_Date AS Fecha_Docto,
                    DN.Created AS Fecha_Creacion,
                    MC.RFC,
                    MC.Ctro
                FROM [EAI].[CFDI_Open_Items] DOI_Inner
                INNER JOIN [T3].[DEBIT_NOTE_IFC] DN ON DOI_Inner.Nota_Venta = DN.Debit_Note
                INNER JOIN [T3].[Mov_Cliente] MC ON DN.Cust_to_SAP = MC.Cliente_SAP
            ) ImporteDebit ON DOI.Nota_Venta = ImporteDebit.Nota_Venta;
            
            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 070: ACTUALIZACIÓN DE INFORMACIÓN FISCAL ======
        IF (COALESCE(@nEtapa, 0) <= 70)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa070';
            
            UPDATE DOI
            SET 
                DOI.Nota_Venta_CFDI = Fiscal.Nota_Venta_CFDI,
                DOI.Folio_Fiscal = Fiscal.Folio_Fiscal,
                DOI.Metodo_Pago = Fiscal.Metodo_Pago,
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    DOI_Inner.Nota_Venta,
                    HDP.Nota_Venta_CFDI,
                    CFD.Fecha_Liberacion,
                    CFD.Folio_Fiscal,
                    CFD.Metodo_Pago
                FROM [EAI].[CFDI_OPEN_ITEMS] DOI_Inner
                INNER JOIN [T3].[CFDI_Historia_Docto_PAC] HDP ON DOI_Inner.Nota_Venta = HDP.Nota_Venta
                LEFT JOIN [T3].[CFDI_Documentos] CFD ON HDP.Nota_Venta_CFDI = CFD.Nota_Venta
            ) Fiscal ON DOI.Nota_Venta = Fiscal.Nota_Venta;
            
            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 080: ACTUALIZACIÓN DE UUID CRÉDITOS ======
        IF (COALESCE(@nEtapa, 0) <= 80)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa080';
            
            UPDATE DOI
            SET 
                DOI.Importe_NC_UUID = (Creditos.Timbrado * COALESCE(DOI.Importe_NC, 0)),
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    DOI_Inner.Nota_Venta,
                    COALESCE(HDP.Nota_Venta_CFDI, DOI_Inner.Nota_Venta) AS Nota_Venta_CFDI,
                    CFD.Fecha_Liberacion,
                    CASE WHEN CFD.Folio_Fiscal IS NOT NULL THEN 1 ELSE 0 END AS Timbrado
                FROM [EAI].[CFDI_OPEN_ITEMS] DOI_Inner
                LEFT JOIN [T3].[CFDI_Historia_Docto_PAC] HDP ON DOI_Inner.Nota_Venta = HDP.Nota_Venta
                INNER JOIN [T3].[CFDI_Documentos] CFD 
                    ON COALESCE(HDP.Nota_Venta_CFDI, DOI_Inner.Nota_Venta) = CFD.Nota_Venta
                WHERE DOI_Inner.Tipo_Docto = 'Dev'
            ) Creditos ON DOI.Nota_Venta = Creditos.Nota_Venta;
            
            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ETAPA 090: ACTUALIZACIÓN DE CLIENTE FACTURACIÓN ======
        IF (COALESCE(@nEtapa, 0) <= 90)
        BEGIN
            SET @v_ID = 'CFDI_OPEN_ITEMS.Etapa090';
            
            UPDATE DOI
            SET 
                DOI.Clte_Factura_SAP = ClteFactura.Clte_Factura_SAP,
                DOI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] DOI
            INNER JOIN (
                SELECT 
                    DOI_Inner.Nota_Venta,
                    COALESCE(PG.Clte_Factura_SAP, FG.Clte_Factura_SAP) AS Clte_Factura_SAP
                FROM [EAI].[CFDI_OPEN_ITEMS] DOI_Inner
                LEFT JOIN [T3].[Preventa_General] PG 
                    ON DOI_Inner.Nota_Venta = PG.Factura 
                    AND PG.Clte_Factura_SAP IS NOT NULL
                    AND PG.Cliente_SAP != PG.Clte_Factura_SAP
                LEFT JOIN [T3].[Factura_General] FG 
                    ON DOI_Inner.Nota_Venta = FG.Factura 
                    AND FG.Clte_Factura_SAP IS NOT NULL
                    AND FG.Cliente_SAP != FG.Clte_Factura_SAP
                WHERE COALESCE(PG.Clte_Factura_SAP, FG.Clte_Factura_SAP) IS NOT NULL
            ) ClteFactura ON DOI.Nota_Venta = ClteFactura.Nota_Venta;
            
            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
            COMMIT TRANSACTION;
        END;
        
        -- ====== ACTUALIZACIONES FINALES ======
        SET @v_ID = 'CFDI_OPEN_ITEMS.Final';
        
        -- Actualizar RFC y Ctro desde Mov_Cliente
        UPDATE DOI
        SET 
            DOI.RFC = MC_RFC.RFC,
            DOI.Ctro = MC_RFC.Ctro
        FROM [EAI].[CFDI_Open_Items] DOI
        INNER JOIN (
            SELECT 
                DOI_Inner.Nota_Venta,
                MAX(MC.RFC) AS RFC,
                MAX(MC.Ctro) AS Ctro
            FROM [EAI].[CFDI_Open_Items] DOI_Inner
            INNER JOIN [T3].[Mov_Cliente] MC ON MC.Cliente_SAP = DOI_Inner.Cliente_SAP
            WHERE DOI_Inner.RFC IS NULL
            GROUP BY DOI_Inner.Nota_Venta
        ) MC_RFC ON DOI.Nota_Venta = MC_RFC.Nota_Venta
        WHERE DOI.RFC IS NULL;
        
        -- Actualizar Importe_Vta con impuestos para devoluciones
        UPDATE DOI
        SET Importe_Vta = Importe_Vta + [EAI_Owner].[Fn_Get_Tax_Issue](DOI.Nota_Venta)
        WHERE DOI.Tipo_Docto = 'Dev';
        
        -- Actualizar referencias SAP (Pedido y Entrega)
        UPDATE DOI
        SET 
            DOI.PedidoSAP = RF_Data.Pedido,
            DOI.FacturaSAP = RF_Data.Entrega
        FROM [EAI].[CFDI_OPEN_ITEMS] DOI
        INNER JOIN (
            SELECT 
                RF.Factura,
                RF.Pedido,
                RF.Entrega
            FROM [T3].[Registro_Fiscal] RF
        ) RF_Data ON DOI.Nota_Venta = RF_Data.Factura;
        
        -- Actualizar estado del proceso
        UPDATE [EAI_OWNER].[MX_COMPONENTS] 
        SET Status = 1
        WHERE Component = @nProceso;
        
        -- Registrar logs finales
        UPDATE [T3].[RF_PROCESOS_LOG] 
        SET 
            Fin = GETDATE(),
            Proceso_1 = @nProceso1,
            Proceso_2 = @nProceso2,
            Proceso_3 = @nProceso3,
            Proceso_4 = @nProceso4
        WHERE PID = @nPID;
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS NVARCHAR(20)) + '-' + ERROR_MESSAGE(), 1, 250);
        
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME, 
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES 
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error', 'SF_CFDI_OPEN_ITEMS', 
             @sMsg, 'T-SQL', @sErrorCode, NULL, NULL, NULL);
        
        -- Log en tabla temporal para revisión
        INSERT INTO #ErrorLog (ErrorCode, ErrorMsg, ContextID, LogTime)
        VALUES (@sErrorCode, @sMsg, @v_ID, GETDATE());
        
        RAISERROR(@sMsg, 16, 1);
        
    END CATCH;
    
    -- Limpiar tabla temporal
    DROP TABLE IF EXISTS #ErrorLog;
    
    SET NOCOUNT OFF;
END;
GO