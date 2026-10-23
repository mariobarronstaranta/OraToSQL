/*
    Procedimiento: EAI.SF_CFDI_NOTA_CREDITO
    Objetivo: reconstruir y enriquecer EAI.CFDI_UUID_NOTA_CREDITO con el
    importe de las notas, saldo SAP, UUID y aplicaciones de cobranza.

    Guia de entrada para desarrolladores
    -----------------------------------
    @nEtapa indica desde donde ejecutar; no es el numero de una etapa aislada:
      NULL, 0 o negativo: reconstruye el reporte y calcula aplicaciones.
      1 a 10: conserva las filas y recalcula solamente sus aplicaciones.
      Mayor que 10: ejecuta apertura/cierre de auditoria sin cambiar el reporte.
    El resultado queda en tablas; no hay parametros OUTPUT ni SELECT final.

    Fuentes y reglas principales
    ---------------------------
    Factura_General/Detalle: notas C004 desde el 01/01/2023.
    Preventa_General/Detalle: C006, C019 y C025 procesadas y no canceladas.
    Cliente: RFC y vigencia a la fecha de factura; se excluye RFC generico.
    T3R_Cartera_SAP_OLD: saldo agrupado por referencia, convertido a absoluto.
    CFDI_Documentos: UUID opcional; no se exige un estado de timbrado.
    CFDI_Cobranza: cantidad, importe, ultima fecha e incobrables aplicados.
    La fecha minima es fija: este procedimiento no usa FC__TIME_WINDOW.

    Alias usados en las consultas
    -----------------------------
    FG/FD = cabecera/detalle de factura o preventa, segun la rama.
    Cte = cliente vigente; Nota = movimientos consolidados; DOI = saldo SAP.
    CFD = documento fiscal; nc = fila destino; Cobza = aplicaciones por nota.

    Contrato transaccional y mantenimiento
    --------------------------------------
    Una ejecucion independiente confirma carga, aplicaciones y auditoria juntas.
    Con transaccion externa usa savepoint y deja la decision final al llamador.
    Oracle confirma parcialmente y absorbe la excepcion; MSSQL revierte segun
    propiedad/estado de la transaccion y relanza el error. No son equivalentes
    bajo fallo. No introducir COMMIT dentro de las etapas.
    La etapa 0 elimina el reporte completo: no es una carga incremental.

    Revision Oracle: 2026-10-08. Detalle y limites en SF_CFDI_NOTA_CREDITO.MD.
    Pruebas locales: tests/SF_CFDI_NOTA_CREDITO/Run.ps1.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [EAI].[SF_CFDI_NOTA_CREDITO]
    @nEtapa INT = 0
AS
BEGIN
    -- NOCOUNT evita mensajes por sentencia; no altera los conteos de negocio.
    SET NOCOUNT ON;
    -- Los errores de ejecucion pueden invalidar una transaccion externa;
    -- el CATCH comprueba XACT_STATE antes de revertir o intentar escribir el log.
    SET XACT_ABORT ON;

    -- Si el llamador ya tiene una transaccion, no debemos confirmarla nosotros.
    -- El savepoint permite deshacer solo esta rutina cuando SQL Server lo permite.
    DECLARE @TranCountInicial INT = @@TRANCOUNT;
    DECLARE @SavepointCreado BIT = 0;
    
    -- PID identifica la corrida; proceso 922 identifica este componente.
    -- Proceso1 cuenta filas recorridas en etapa 10, no asignaciones ni importes.
    -- Proceso2..4 quedan en cero por contrato con RF_PROCESOS_LOG.
    -- v_ID identifica la seccion activa y se guarda como referencia del error.
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
        -- La carga, las aplicaciones y el cierre se confirman como una unidad.
        IF @TranCountInicial = 0
            BEGIN TRANSACTION;
        ELSE
        BEGIN
            SAVE TRANSACTION SF_CFDI_NC;
            SET @SavepointCreado = 1;
        END;

        -- Apertura de auditoria: reservar PID, marcar componente en ejecucion
        -- y registrar el inicio. En transaccion propia estas marcas tambien
        -- se revierten si alguna etapa falla; el log de error se intenta despues.
        SELECT @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID];
        EXEC [EAI_Owner].[Log_Start] @nProceso;
        
        INSERT INTO [T3].[RF_PROCESOS_LOG] 
            ([PID], [Proceso], [Fecha_Proc_BATMD], [Inicio])
        VALUES 
            (@nPID, @nProceso, NULL, @dtInicio);
        
        SET @v_ID = 'CFDI_UUID_NOTA_CREDITO';
        
        -- ETAPA 0: reconstruccion completa del universo de notas de credito.
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
                -- Consolidar por centro, fecha, nota, cliente y RFC, no solo
                -- por folio. Conservar la multiplicidad de los JOIN de Oracle.
                SELECT 
                    Nota.[Ctro],
                    Nota.[Fecha_Venta],
                    Nota.[Nota_Venta],
                    Nota.[Cliente_SAP],
                    Nota.[RFC],
                    SUM(Nota.[Importe_Item]) AS [Importe_Venta]
                FROM (
                    -- Rama de facturas: C004 con detalle y cliente vigente.
                    -- Cada importe nulo vale cero. No sumar credito/bonificacion
                    -- ni aplicar signo negativo o ABS al importe de la nota.
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
                      AND NULLIF(Cte.[RFC], '') <> 'XAXX010101000'
                    
                    -- ALL conserva todos los movimientos, aun si una nota
                    -- aparece en ambas fuentes o hay detalles iguales.
                    UNION ALL
                    
                    -- Rama de preventas: mismas cuatro partidas monetarias;
                    -- ademas requiere fecha de proceso y ausencia de cancelacion.
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
                      AND NULLIF(Cte.[RFC], '') <> 'XAXX010101000'
                ) Nota
                GROUP BY Nota.[Ctro], Nota.[Fecha_Venta], Nota.[Nota_Venta], 
                         Nota.[Cliente_SAP], Nota.[RFC]
            ) Nota
            LEFT JOIN (
                -- SAP se agrega SOLO por Referencia; no restringir por cliente.
                -- ABS se aplica fuera, despues de sumar cargos y abonos.
                -- MAX(Cliente)/MIN(Fecha_Doc) vienen del original; no se utilizan
                -- en el resultado ni cambian la clave de agrupacion.
                SELECT 
                    SAP.[Referencia] AS [Nota_Venta],
                    MAX(SAP.[Cliente]) AS [Cliente_SAP],
                    MIN(SAP.[Fecha_Doc]) AS [Fecha_Doc],
                    SUM(ISNULL(SAP.[Monto], 0)) AS [Saldo_SAP]
                FROM [EAI].[T3R_Cartera_SAP_OLD] SAP
                GROUP BY SAP.[Referencia]
            ) DOI 
                ON Nota.[Nota_Venta] = DOI.[Nota_Venta]
            -- La nota permanece aunque no tenga UUID. Varios documentos fiscales
            -- generan varias filas destino, igual que Oracle: no deduplicar aqui.
            LEFT JOIN [T3].[CFDI_Documentos] CFD
                ON Nota.[Nota_Venta] = CFD.[Nota_Venta];
            
        END
        
        -- ETAPA 10: recalcular aplicaciones por conjunto, equivalente a recorrer
        -- ScrPrompt y consultar el agregado escalar ScrCobza para cada nota.
        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            SET @v_ID = 'ScrPrompt';
            
            -- Oracle cuenta todas las filas del cursor, aun sin cobranza o
            -- con Nota_Venta NULL. No cuenta solo las coincidencias del JOIN.
            SELECT @nProceso1 = COUNT(*) FROM [EAI].[CFDI_UUID_NOTA_CREDITO];

            -- ScrCobza es un agregado SIN GROUP BY: aun sin coincidencias
            -- devuelve COUNT=0 y SUM/MAX=NULL. LEFT JOIN reproduce ese caso.
            -- No convertir Importe_NC/Incobrable a cero cuando falta cobranza:
            -- la etapa 10 tambien debe limpiar valores de aplicaciones eliminadas.
            UPDATE nc
            SET 
                nc.[Aplica_NC] = ISNULL(Cobza.[Aplicaciones], 0),
                nc.[Importe_NC] = Cobza.[Importe_Aplicado],
                nc.[Fecha_Aplicacion] = Cobza.[Fecha_Asignacion],
                nc.[Incobrable] = Cobza.[Incobrable]
            FROM [EAI].[CFDI_UUID_NOTA_CREDITO] nc
            LEFT JOIN (
                SELECT 
                    Cobza.[Nota_Credito],
                    -- Cuenta IDs no nulos, sin DISTINCT. Un ID repetido cuenta
                    -- de nuevo; uno nulo/vacio puede aportar importe sin contar.
                    -- Destino Aplica_NC es NUMERIC(4,0): mas de 9999 desborda.
                    COUNT(NULLIF(Cobza.[Asignacion_ID], '')) AS [Aplicaciones],
                    -- Todas las vias participan, no solamente CM o AI.
                    SUM(ISNULL(Cobza.[Importe], 0)) AS [Importe_Aplicado],
                    MAX(Cobza.[Fecha_Asignacion]) AS [Fecha_Asignacion],
                    -- AI usa Importe sin ISNULL para conservar SUM de Oracle:
                    -- si todas las filas son AI con importe NULL, queda NULL.
                    SUM(CASE 
                        WHEN Cobza.[Via_Pago] = 'AI' THEN Cobza.[Importe] 
                        ELSE 0 
                    END) AS [Incobrable]
                FROM [T3].[CFDI_Cobranza] Cobza
                -- Filtrar al universo del reporte sin multiplicar cobranzas
                -- cuando varias filas destino comparten Nota_Venta.
                WHERE EXISTS
                (
                    SELECT 1 FROM [EAI].[CFDI_UUID_NOTA_CREDITO] AS N
                    WHERE N.Nota_Venta = Cobza.Nota_Credito
                )
                GROUP BY Cobza.[Nota_Credito]
            ) Cobza 
                ON nc.[Nota_Venta] = Cobza.[Nota_Credito]
            -- En Oracle WHERE Nota_Venta = NULL nunca actualiza una fila.
            WHERE NULLIF(nc.[Nota_Venta], '') IS NOT NULL;
            
        END
        
        -- Cierre: estado disponible del componente y contadores de esta corrida.
        -- Tambien se ejecuta para @nEtapa > 10, con los contadores en cero.
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
        
        -- Solo confirmamos la transaccion que abrio este procedimiento.
        IF @TranCountInicial = 0
            COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        -- Capturar el error original antes de rollback y del TRY/CATCH del log.
        -- El limite de 250 caracteres mantiene el contrato de la bitacora.
        SELECT 
            @sErrorCode = 'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(10)),
            @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- Primero revertir: asi no queda una reconstruccion parcial y, en una
        -- ejecucion independiente, la bitacora de error queda fuera del rollback.
        IF @TranCountInicial = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreado = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION SF_CFDI_NC;

        -- Una transaccion externa condenada (XACT_STATE = -1) no permite
        -- escribir ni volver a un savepoint. El llamador debe hacer ROLLBACK.
        -- En una transaccion externa valida, este log depende de su commit.
        IF XACT_STATE() <> -1
        BEGIN TRY
        
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            ([DIRECTION], [REFERENCE], [CREATED], [MESSAGE], [JOB_PID],
             [STATUS], [QUEUE_NAME], [SIEBEL_ERROR_MESSAGE], [SOURCE],
             [SIEBEL_ERROR_CODE], [RETRY_COUNT], [SEQUENCE], [PARENT_ROW_ID])
        VALUES
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID,
             'Error', 'SF_CFDI_NOTA_CREDITO', @sMsg, 'T-SQL',
             @sErrorCode, NULL, NULL, NULL);
        
        END TRY
        BEGIN CATCH
            -- Un fallo de la bitacora no debe ocultar el error funcional original.
            PRINT CONCAT('No se pudo registrar el error: ', ERROR_MESSAGE());
        END CATCH;
        
        PRINT '-----------------------------------';
        PRINT '** Error en SF_CFDI_NOTA_CREDITO **';
        PRINT @sMsg;
        
        THROW;
        
    END CATCH;
END;
