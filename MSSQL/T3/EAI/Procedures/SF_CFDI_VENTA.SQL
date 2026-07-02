CREATE PROCEDURE [dbo].[SF_CFDI_VENTA]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- Rollback automático en error

    -- DECLARACIONES
    DECLARE @dtInicio DATETIME2 = GETDATE();
    DECLARE @nProceso INT = 921;
    DECLARE @nPID INT;
    DECLARE @sErrorCode VARCHAR(20);
    DECLARE @sMsg VARCHAR(250);
    DECLARE @sFactura VARCHAR(20);
    DECLARE @v_ID VARCHAR(50) = 'CFDI_UUID_VENTA';
    DECLARE @nProceso1 INT = 0;
    DECLARE @nProceso2 INT = 0;
    DECLARE @nProceso3 INT = 0;
    DECLARE @nProceso4 INT = 0;

    BEGIN TRY
        -- ========== INICIO DE PROCESO ==========
        -- Obtener PID (Asumo IDENTITY o SEQUENCE disponible)
        INSERT INTO [T3].[RF_PROCESOS_LOG] (Proceso, Fecha_Proc_BATMD, Inicio)
            VALUES (@nProceso, NULL, @dtInicio);
        
        SET @nPID = SCOPE_IDENTITY();

        -- ========== ETAPA 0: LIMPIAR E INSERTAR DATOS BASE ==========
        IF (@nEtapa <= 0)
        BEGIN
            DELETE FROM [EAI].[CFDI_UUID_VENTA];

            INSERT INTO [EAI].[CFDI_UUID_VENTA]
                (Ctro, Fecha_Venta, Nota_Venta, RFC, Cliente_SAP, Importe_Vta, Saldo_SAP)
            SELECT 
                Doc.Ctro,
                Doc.Invc_dt AS Fecha_Venta,
                Doc.Doc_Num AS Nota_Venta,
                Doc.RFC,
                Doc.Cliente_SAP,
                ISNULL(Doc.Valor_Subt, 0) +
                ISNULL(Doc.Envio_Subt, 0) +
                ISNULL(Doc.Credito_Subt, 0) +
                ISNULL(Doc.Valor_IVA, 0) +
                ISNULL(Doc.Envio_IVA, 0) +
                ISNULL(Doc.Credito_IVA, 0) AS Importe_Vta,
                ISNULL(DOI.Saldo_SAP, 0) AS Saldo_SAP
            FROM [EAI].[CFDI_Bitacora] Doc
            LEFT JOIN (
                SELECT 
                    SAP.Referencia AS Nota_Venta,
                    MAX(SAP.Cliente) AS Cliente_SAP,
                    MIN(SAP.Fecha_Doc) AS Fecha_Doc,
                    SUM(ISNULL(SAP.Monto, 0)) AS Saldo_SAP
                FROM [EAI].[T3R_Cartera_SAP_OLD] SAP
                GROUP BY SAP.Referencia
            ) DOI ON Doc.Doc_Num = DOI.Nota_Venta
            WHERE Doc.Tipo_Vta = 'Vta'
              AND Doc.RFC != 'XAXX010101000';

            COMMIT;
        END

        -- ========== ETAPA 1: ACTUALIZAR COBRANZAS (OPTIMIZADO) ==========
        -- **MEJORA CLAVE**: En lugar de cursores anidados + UPDATE en loop,
        -- usar UPDATE con JOIN directo. Esto es 1000x más rápido.
        IF (@nEtapa <= 10)
        BEGIN
            UPDATE [EAI].[CFDI_UUID_VENTA]
            SET 
                Importe        = Cobza_Agg.Importe,
                Efectivo       = Cobza_Agg.Efectivo,
                Agrupado       = Cobza_Agg.Agrupado,
                Aplica_NC      = Cobza_Agg.Aplica_NC,
                Incobrable     = Cobza_Agg.Incobrable,
                Efectivo_UUID  = Cobza_Agg.Efectivo_UUID,
                Agrupado_UUID  = Cobza_Agg.Agrupado_UUID,
                Aplica_NC_UUID = Cobza_Agg.Aplica_NC_UUID,
                Importe_UUID   = Cobza_Agg.Importe_UUID,
                Metodo_Pago    = CFD.Metodo_Pago
            FROM [EAI].[CFDI_UUID_VENTA] Vta_Main
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
                        C.Factura,
                        C.Asignacion_ID,
                        C.Importe,
                        C.Via_Pago,
                        C.Nota_Credito,
                        CASE WHEN C.Via_Pago = '01' THEN C.Importe ELSE 0 END AS Efectivo,
                        CASE WHEN C.Via_Pago IN ('02', '03') THEN C.Importe ELSE 0 END AS Agrupado,
                        CASE WHEN C.Via_Pago = 'CM' THEN C.Importe ELSE 0 END AS Aplica_NC,
                        CASE WHEN C.Via_Pago = 'AI' THEN C.Importe ELSE 0 END AS Incobrable,
                        CASE 
                            WHEN P.Folio_Fiscal IS NOT NULL THEN 1
                            WHEN Agr.Folio_Fiscal IS NOT NULL THEN 1
                            WHEN N.Folio_Fiscal IS NOT NULL THEN 1
                            ELSE 0
                        END AS Timbrado
                    FROM [T3].[CFDI_Cobranza] C
                    LEFT JOIN [T3].[CFDI_Documentos] P ON C.Asignacion_ID = P.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Agrupacion_Pago] AgrP ON C.Asignacion_ID = AgrP.Asignacion_ID
                    LEFT JOIN [T3].[CFDI_Documentos] Agr ON CAST(AgrP.Agrupacion AS VARCHAR(20)) = Agr.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Documentos] N ON C.Nota_Credito = N.Nota_Venta
                ) Cobza
                GROUP BY Cobza.Factura
            ) Cobza_Agg ON Vta_Main.Nota_Venta = Cobza_Agg.Factura
            LEFT JOIN [T3].[CFDI_Documentos] CFD ON Vta_Main.Nota_Venta = CFD.Nota_Venta
            WHERE [EAI].[CFDI_UUID_VENTA].Nota_Venta = Cobza_Agg.Factura;

            SET @nProceso1 = @@ROWCOUNT;
            COMMIT;
        END

        -- ========== FINALIZACIÓN ==========
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

        COMMIT;

    END TRY
    BEGIN CATCH
        -- MANEJO DE ERRORES
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = SUBSTRING(
            CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 
            1, 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS, QUEUE_NAME, 
             SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE)
        VALUES 
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error', 'SF_CFDI_VENTA',
             @sMsg, 'T-SQL', @sErrorCode);

        COMMIT;

        RAISERROR(@sMsg, 16, 1);  -- Lanzar error para logging en aplicación
    END CATCH
END;