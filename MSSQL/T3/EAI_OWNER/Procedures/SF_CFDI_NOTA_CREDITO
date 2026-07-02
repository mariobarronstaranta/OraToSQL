CREATE PROCEDURE [dbo].[SF_CFDI_NOTA_CREDITO]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @nPID         INT;
    DECLARE @nProceso     INT = 922;
    DECLARE @dtInicio     DATETIME2 = GETDATE();
    DECLARE @sErrorCode   VARCHAR(20);
    DECLARE @sMsg         VARCHAR(250);
    DECLARE @nProceso1    INT = 0;
    DECLARE @nProceso2    INT = 0;
    DECLARE @nProceso3    INT = 0;
    DECLARE @nProceso4    INT = 0;
    DECLARE @v_ID         VARCHAR(50);
    
    BEGIN TRY
        -- Inicialización del proceso
        SELECT @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID];
        EXEC [EAI_Owner].[Log_Start] @nProceso;
        
        INSERT INTO [T3].[RF_PROCESOS_LOG] 
            ([PID], [Proceso], [Fecha_Proc_BATMD], [Inicio])
        VALUES 
            (@nPID, @nProceso, NULL, @dtInicio);
        
        SET @v_ID = 'CFDI_UUID_VENTA';
        
        -- ETAPA 0: Carga inicial de notas de crédito
        IF ISNULL(@nEtapa, 0) <= 0
        BEGIN
            DELETE FROM [EAI].[CFDI_UUID_NOTA_CREDITO];
            
            INSERT INTO [EAI].[CFDI_UUID_NOTA_CREDITO]
                ([Ctro], [Fecha_Venta], [Nota_Venta], [RFC], [Cliente_SAP], 
                 [Importe_Vta], [Saldo_SAP], [Folio_Fiscal])
            SELECT 
                Nota.[Ctro],
                Nota.[Fecha_Venta],
                Nota.[Nota_Venta],
                Nota.[RFC],
                Nota.[Cliente_SAP],
                Nota.[Importe_Venta],
                ABS(ISNULL(DOI.[Saldo_SAP], 0)),
                CFD.[Folio_Fiscal]
            FROM (
                -- Subconsulta principal: Agrupa facturas y preventas
                SELECT 
                    Nota.[Ctro],
                    Nota.[Fecha_Venta],
                    Nota.[Nota_Venta],
                    Nota.[Cliente_SAP],
                    Nota.[RFC],
                    SUM(Nota.[Importe_Item]) AS [Importe_Venta]
                FROM (
                    -- UNION: Facturas generales
                    SELECT  
                        FG.[Ctro],
                        FG.[Fecha_Factura] AS [Fecha_Venta],
                        FG.[Factura] AS [Nota_Venta],
                        FD.[Material],
                        FG.[Cliente_SAP],
                        Cte.[RFC],
                        ISNULL(FD.[Valor_Subt], 0) +
                        ISNULL(FD.[Valor_IVA], 0) +
                        ISNULL(FD.[Envio_Subt], 0) +
                        ISNULL(FD.[Envio_IVA], 0) AS [Importe_Item]
                    FROM [T3].[Factura_General] FG
                    INNER JOIN [T3].[Factura_Detalle] FD 
                        ON FG.[Factura] = FD.[Factura]
                    INNER JOIN [T3].[Cliente] Cte 
                        ON FG.[Cliente_SAP] = Cte.[Cliente_SAP]
                    WHERE FG.[Fecha_Factura] >= CONVERT(DATE, '20230101', 112)
                      AND FG.[Tipo_Docto] = 'C004'
                      AND FG.[Fecha_Factura] BETWEEN Cte.[Fecha_Ini_Vig] AND Cte.[Fecha_Fin_Vig]
                      AND Cte.[RFC] <> 'XAXX010101000'
                    
                    UNION ALL
                    
                    -- UNION: Preventas
                    SELECT  
                        FG.[Ctro],
                        FG.[Fecha_Factura] AS [Fecha_Venta],
                        FG.[Factura] AS [Nota_Venta],
                        FD.[Material],
                        FG.[Cliente_SAP],
                        Cte.[RFC],
                        ISNULL(FD.[Valor_Subt], 0) +
                        ISNULL(FD.[Valor_IVA], 0) +
                        ISNULL(FD.[Envio_Subt], 0) +
                        ISNULL(FD.[Envio_IVA], 0) AS [Importe_Item]
                    FROM [T3].[Preventa_General] FG
                    INNER JOIN [T3].[Preventa_Detalle] FD 
                        ON FG.[Factura] = FD.[Factura]
                    INNER JOIN [T3].[Cliente] Cte 
                        ON FG.[Cliente_SAP] = Cte.[Cliente_SAP]
                    WHERE FG.[Fecha_Factura] >= CONVERT(DATE, '20230101', 112)
                      AND FG.[Clase_Factura] IN ('C006', 'C019', 'C025')
                      AND FG.[Fecha_Proc_BATMD] IS NOT NULL
                      AND FG.[Fecha_Cancelacion] IS NULL
                      AND FG.[Fecha_Factura] BETWEEN Cte.[Fecha_Ini_Vig] AND Cte.[Fecha_Fin_Vig]
                      AND Cte.[RFC] <> 'XAXX010101000'
                ) Nota
                GROUP BY Nota.[Ctro], Nota.[Fecha_Venta], Nota.[Nota_Venta], 
                         Nota.[Cliente_SAP], Nota.[RFC]
            ) Nota
            LEFT JOIN (
                -- Saldos desde SAP
                SELECT 
                    SAP.[Referencia] AS [Nota_Venta],
                    MAX(SAP.[Cliente]) AS [Cliente_SAP],
                    MIN(SAP.[Fecha_Doc]) AS [Fecha_Doc],
                    SUM(ISNULL(SAP.[Monto], 0)) AS [Saldo_SAP]
                FROM [EAI].[T3R_Cartera_SAP_OLD] SAP
                GROUP BY SAP.[Referencia]
            ) DOI 
                ON Nota.[Nota_Venta] = DOI.[Nota_Venta]
            LEFT JOIN [T3].[CFDI_Documentos] CFD 
                ON Nota.[Nota_Venta] = CFD.[Nota_Venta];
            
            COMMIT TRANSACTION;
        END
        
        -- ETAPA 1: Actualiza cobranzas aplicadas (OPTIMIZACIÓN: set-based en lugar de cursores)
        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            SET @v_ID = 'ScrPrompt';
            
            -- Elimina approach de cursores - usa update set-based
            UPDATE nc
            SET 
                nc.[Aplica_NC] = Cobza.[Aplicaciones],
                nc.[Importe_NC] = Cobza.[Importe_Aplicado],
                nc.[Fecha_Aplicacion] = Cobza.[Fecha_Asignacion],
                nc.[Incobrable] = Cobza.[Incobrable],
                @nProceso1 = @nProceso1 + 1
            FROM [EAI].[CFDI_UUID_NOTA_CREDITO] nc
            INNER JOIN (
                SELECT 
                    Cobza.[Nota_Credito],
                    COUNT(Cobza.[Asignacion_ID]) AS [Aplicaciones],
                    SUM(ISNULL(Cobza.[Importe], 0)) AS [Importe_Aplicado],
                    MAX(Cobza.[Fecha_Asignacion]) AS [Fecha_Asignacion],
                    SUM(CASE 
                        WHEN Cobza.[Via_Pago] = 'AI' THEN Cobza.[Importe] 
                        ELSE 0 
                    END) AS [Incobrable]
                FROM [T3].[CFDI_Cobranza] Cobza
                GROUP BY Cobza.[Nota_Credito]
            ) Cobza 
                ON nc.[Nota_Venta] = Cobza.[Nota_Credito];
            
            COMMIT TRANSACTION;
        END
        
        -- Actualización de control de procesos
        UPDATE [EAI_OWNER].[MX_COMPONENTS] 
        SET [Status] = 1
        WHERE [Component] = @nProceso;
        
        UPDATE [T3].[RF_PROCESOS_LOG] 
        SET 
            [Fin] = GETDATE(),
            [Proceso_1] = @nProceso1,
            [Proceso_2] = @nProceso2,
            [Proceso_3] = @nProceso3,
            [Proceso_4] = @nProceso4
        WHERE [PID] = @nPID;
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Manejo de errores
        SELECT 
            @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10)),
            @sMsg = CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + SUBSTRING(ERROR_MESSAGE(), 1, 250);
        
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            ([DIRECTION], [REFERENCE], [CREATED], [MESSAGE], [JOB_PID],
             [STATUS], [QUEUE_NAME], [SIEBEL_ERROR_MESSAGE], [SOURCE],
             [SIEBEL_ERROR_CODE], [RETRY_COUNT], [SEQUENCE], [PARENT_ROW_ID])
        VALUES
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID,
             'Error', 'SF_CFDI_NOTA_CREDITO', @sMsg, 'T-SQL',
             @sErrorCode, NULL, NULL, NULL);
        
        COMMIT TRANSACTION;
        
        PRINT '-----------------------------------';
        PRINT '** Error en SF_CFDI_NOTA_CREDITO **';
        PRINT @sMsg;
        
        THROW;
        
    END CATCH;
END;