CREATE OR ALTER PROCEDURE [dbo].[SF_BITACORA_CFDI_VENTA_SF]
    @nEtapa INT = 0,
    @sPeriod VARCHAR(10) = ''
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @nDist                 INT;
    DECLARE @sCtro                 VARCHAR(4);
    DECLARE @sTerr                 VARCHAR(4);
    DECLARE @sFecha                VARCHAR(8);
    DECLARE @dtFecha               DATETIME;
    DECLARE @sError                VARCHAR(250);
    DECLARE @sResp                 VARCHAR(30);
    DECLARE @sFactura              VARCHAR(20);
    DECLARE @sPeriodo              VARCHAR(20);
    DECLARE @sNULL                 VARCHAR(10) = '     ';
    DECLARE @sMsg                  VARCHAR(500);
    DECLARE @nItems                INT;
    
    DECLARE @v_ID                  VARCHAR(50) = 'CEDIS.Clean';
    DECLARE @sErrorCode            VARCHAR(20);
    DECLARE @dtInicio              DATETIME;
    DECLARE @nPID                  INT;
    DECLARE @nProceso              INT = 826;
    DECLARE @nProceso1             INT = 0;
    DECLARE @nProceso2             INT = 0;
    DECLARE @nProceso3             INT = 0;
    DECLARE @nProceso4             INT = 0;

    -- Determinar período
    IF LEN(ISNULL(@sPeriod, '')) < 4
    BEGIN
        SET @sPeriodo = '';
        IF DAY(GETDATE()) IN (1, 2)
            SET @sPeriodo = FORMAT(DATEADD(DAY, -3, GETDATE()), 'yyyyMM');
    END
    ELSE
    BEGIN
        SET @sPeriodo = @sPeriod;
    END

    SET @dtInicio = GETDATE();

    -- Obtener Next PID (asume secuencia SQL Server 2012+)
    -- Si no existe, usar IDENTITY. Ej: SET @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID];
    -- Para versiones < 2012, usar tabla de control
    BEGIN TRY
        SET @nPID = (SELECT NEXT VALUE FOR [EAI_Owner].[ProcessID]);
    END TRY
    BEGIN CATCH
        -- Fallback: usar tabla control
        INSERT INTO [EAI_Owner].[PID_Counter] DEFAULT VALUES;
        SET @nPID = SCOPE_IDENTITY();
    END CATCH

    -- Log inicio
    INSERT INTO [T3].[RF_PROCESOS_LOG] (PID, Proceso, Fecha_Proc_BATMD, Inicio)
    VALUES (@nPID, @nProceso, NULL, @dtInicio);

    BEGIN TRY
        -- ==================== PROCESAR VENTAS SALESFORCE ====================
        -- Usar tabla temporal en lugar de cursor
        DECLARE @ScrVentaSalesforce TABLE (
            SF_Factura VARCHAR(20),
            SF_Fecha_Factura VARCHAR(10),
            SF_Cliente_SAP VARCHAR(20),
            SF_Importe_TMD DECIMAL(15,2),
            SF_Tipo_Doc VARCHAR(5),
            Delivery_Status VARCHAR(50),
            Bitacora_RowID BIGINT,
            Bitacora_DocNum VARCHAR(20),
            Ctro VARCHAR(4),
            Nombre_Cliente VARCHAR(100)
        );

        INSERT INTO @ScrVentaSalesforce
        SELECT 
            SF.Factura AS SF_Factura,
            SF.Fecha_Factura AS SF_Fecha_Factura,
            SF.Cliente_SAP AS SF_Cliente_SAP,
            SF.Importe_TMD AS SF_Importe_TMD,
            SF.Tipo_Doc AS SF_Tipo_Doc,
            SF.Delivery_Status,
            CAST(ROW_NUMBER() OVER (ORDER BY SF.Factura) AS BIGINT) AS Bitacora_RowID,
            ISNULL(Bit.Doc_Num, 'INSERT') AS Bitacora_DocNum,
            MC.Ctro,
            MC.Nombre
        FROM (
            -- Facturaciones
            SELECT 
                Inv.Doc_Num AS Factura,
                FORMAT(Inv.Invc_dt, 'yyyy-MM-dd') AS Fecha_Factura,
                Inv.Cte_SAP AS Cliente_SAP,
                Inv.Ttl_Invc_Amt AS Importe_TMD,
                'Vta' AS Tipo_Doc,
                Inv.Delivery_Status
            FROM [EAI_Owner].[Facturas_B] Inv
            INNER JOIN [EAI].[FC__Time_Window] TW ON 1=1  -- Cross join lógico
            WHERE Inv.Invc_Status NOT IN ('Cancelled', 'Invalid')
              AND Inv.Invc_dt IS NOT NULL
              AND Inv.Doc_Num NOT IN (SELECT Referencia FROM [EAI_Owner].[Doctos_Cancelled])
              AND CAST(Inv.Invc_dt AS DATE) < CAST(GETDATE() AS DATE)
              AND CAST(Inv.Invc_dt AS DATE) >= CAST(DATEADD(DAY, -45, 
                  TRY_CONVERT(DATE, TW.Start_Date, 103)) AS DATE)  -- 103 = DD/MM/YYYY

            UNION ALL

            -- Devoluciones
            SELECT 
                Dev.SR_Invoice_Key AS Factura,
                FORMAT(Dev.SRI_Date, 'yyyy-MM-dd') AS Fecha_Factura,
                Dev.SAP_CustomerID AS Cliente_SAP,
                Dev.Total_Amount * -1 AS Importe_TMD,
                'Dev' AS Tipo_Doc,
                ISNULL(Dev.Received_Status, 'Empty')
            FROM [EAI_Owner].[SR_Invoice] Dev
            INNER JOIN [EAI].[FC__Time_Window] TW ON 1=1
            WHERE Dev.SRI_Date IS NOT NULL
              AND Dev.SR_Invoice_Key NOT IN (SELECT Referencia FROM [EAI_Owner].[Doctos_Cancelled])
              AND CAST(Dev.SRI_Date AS DATE) < CAST(GETDATE() AS DATE)
              AND CAST(Dev.SRI_Date AS DATE) >= CAST(DATEADD(DAY, -45, 
                  TRY_CONVERT(DATE, TW.Start_Date, 103)) AS DATE)

            UNION ALL

            -- Notas de Crédito
            SELECT 
                CN.Reference_NO AS Factura,
                FORMAT(CN.Fecha, 'yyyy-MM-dd') AS Fecha_Factura,
                CN.Cte_SAP AS Cliente_SAP,
                ISNULL(CN.Amount, 0) * -1 AS Importe_TMD,
                'Dev' AS Tipo_Doc,
                'CreditMemo' AS Delivery_Status
            FROM [EAI_OWNER].[CREDIT_NOTES] CN
            INNER JOIN [EAI].[FC__Time_Window] TW ON 1=1
            WHERE (CN.Reference_NO LIKE 'DESC%' OR CN.Reference_NO LIKE 'CONECT%')
              AND CAST(CN.Fecha AS DATE) < CAST(GETDATE() AS DATE)
              AND CAST(CN.Fecha AS DATE) >= CAST(DATEADD(DAY, -45, 
                  TRY_CONVERT(DATE, TW.Start_Date, 103)) AS DATE)

        ) SF
        LEFT JOIN [EAI].[CFDI_Bitacora] Bit ON SF.Factura = Bit.Doc_Num
        LEFT JOIN [T3].[Mov_Cliente] MC ON SF.Cliente_SAP = MC.Cliente_SAP;

        -- Procesar resultados
        DECLARE @SF_Factura VARCHAR(20), @SF_Importe_TMD DECIMAL(15,2), 
                @Bitacora_RowID BIGINT, @Bitacora_DocNum VARCHAR(20),
                @Delivery_Status VARCHAR(50), @Ctro VARCHAR(4), 
                @SF_Tipo_Doc VARCHAR(5), @Nombre_Cliente VARCHAR(100),
                @SF_Cliente_SAP VARCHAR(20), @SF_Fecha_Factura VARCHAR(10);

        DECLARE venta_cursor CURSOR FAST_FORWARD FOR
            SELECT SF_Factura, SF_Importe_TMD, Bitacora_RowID, Bitacora_DocNum,
                   Delivery_Status, Ctro, SF_Tipo_Doc, Nombre_Cliente, 
                   SF_Cliente_SAP, SF_Fecha_Factura
            FROM @ScrVentaSalesforce;

        OPEN venta_cursor;
        FETCH NEXT FROM venta_cursor INTO @SF_Factura, @SF_Importe_TMD, @Bitacora_RowID,
                                          @Bitacora_DocNum, @Delivery_Status, @Ctro,
                                          @SF_Tipo_Doc, @Nombre_Cliente, @SF_Cliente_SAP,
                                          @SF_Fecha_Factura;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @SF_Factura = @Bitacora_DocNum
            BEGIN
                IF @Delivery_Status != 'Unsuccessful-X'
                BEGIN
                    SET @nProceso1 = @nProceso1 + 1;
                    UPDATE [EAI].[CFDI_Bitacora]
                    SET SF_AMOUNT = @SF_Importe_TMD
                    WHERE Doc_Num = @SF_Factura;
                END
                ELSE
                BEGIN
                    SET @nProceso2 = @nProceso2 + 1;
                END
            END
            ELSE
            BEGIN
                SET @nProceso3 = @nProceso3 + 1;
                INSERT INTO [EAI].[CFDI_Bitacora]
                    (Row_ID, Doc_Num, Nota_Venta_CFDI, Invc_Dt, Fecha_Trn,
                     Ctro, Terr, Tipo_Vta, Docto_Ind, Fecha_Venta,
                     Nombre_Cliente, Cliente_SAP, Clte_Factura_SAP, SF_Amount)
                VALUES
                    (@SF_Factura, @SF_Factura, @SF_Factura,
                     TRY_CONVERT(DATE, @SF_Fecha_Factura, 120), GETDATE(),
                     @Ctro, '0000', @SF_Tipo_Doc, 1, TRY_CONVERT(DATE, @SF_Fecha_Factura, 120),
                     @Nombre_Cliente, @SF_Cliente_SAP, @SF_Cliente_SAP, @SF_Importe_TMD);
            END

            FETCH NEXT FROM venta_cursor INTO @SF_Factura, @SF_Importe_TMD, @Bitacora_RowID,
                                              @Bitacora_DocNum, @Delivery_Status, @Ctro,
                                              @SF_Tipo_Doc, @Nombre_Cliente, @SF_Cliente_SAP,
                                              @SF_Fecha_Factura;
        END

        CLOSE venta_cursor;
        DEALLOCATE venta_cursor;

        -- ==================== ACTUALIZAR INFORMACIÓN SAP ====================
        DECLARE @Doc_Num VARCHAR(20), @Monto_SAP DECIMAL(15,2),
                @Factor_SAP INT, @Documento_SAP VARCHAR(20);

        DECLARE sap_cursor CURSOR FAST_FORWARD FOR
            SELECT 
                Bita.Doc_Num,
                CASE WHEN Bita.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END AS Factor_SAP,
                SAP.Doc_Num_R3,
                ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0) AS Monto_SAP
            FROM [EAI].[CFDI_Bitacora] Bita
            INNER JOIN [EAI].[T3R_Sales_Docs_Old] SAP ON Bita.Doc_Num = SAP.Doc_Num_ref2
            WHERE Bita.Row_ID IS NOT NULL
              AND SAP.Doc_Status = 'C';

        OPEN sap_cursor;
        FETCH NEXT FROM sap_cursor INTO @Doc_Num, @Factor_SAP, @Documento_SAP, @Monto_SAP;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @nProceso4 = @nProceso4 + 1;
            UPDATE [EAI].[CFDI_Bitacora]
            SET SAP_Amount = @Monto_SAP * @Factor_SAP,
                Factura_SAP = @Documento_SAP
            WHERE Doc_Num = @Doc_Num;

            FETCH NEXT FROM sap_cursor INTO @Doc_Num, @Factor_SAP, @Documento_SAP, @Monto_SAP;
        END

        CLOSE sap_cursor;
        DEALLOCATE sap_cursor;

        -- ==================== WORKAROUND CREDIT MEMO ====================
        DELETE FROM [EAI].[CFDI_Bitacora]
        WHERE Doc_Num IN (
            SELECT Bita.Doc_Num
            FROM [EAI].[CFDI_Bitacora] Bita
            INNER JOIN [T3].[Preventa_General] PG ON Bita.Doc_Num = PG.Factura
            WHERE (Bita.Doc_Num LIKE 'DESC%' OR Bita.Doc_Num LIKE 'CONECT%')
              AND (CAST(Bita.Invc_dt AS DATE) - CAST(PG.Fecha_Factura AS DATE)) >= 35
        );

        -- Actualizar Notas de Crédito
        UPDATE [EAI].[CFDI_Bitacora]
        SET SF_Amount = ISNULL(SAP_Amount, 0)
        WHERE (Doc_Num LIKE 'DESC%' OR Doc_Num LIKE 'CONECT%')
          AND ISNULL(SAP_Amount, 0) != ISNULL(SF_Amount, 0)
          AND ISNULL(SF_Amount, 0) != 0
          AND Invc_dt > DATEADD(DAY, -45, GETDATE());

        -- ==================== ACTUALIZAR CFDI_INFORME ====================
        UPDATE [EAI].[CFDI_Informe]
        SET Status = CFD.Status,
            Folio_Fiscal = CFD.Folio_Fiscal,
            Valor_Subt = CFD.Valor_Subt * Info.Factor,
            Valor_IVA = CFD.Valor_IVA * Info.Factor
        FROM [EAI].[CFDI_Informe] Info
        INNER JOIN [T3].[CFDI_Documentos] CFD ON Info.Folio_Interno = CFD.Nota_Venta
        WHERE Info.Folio_Fiscal IS NULL
          AND CFD.Folio_Fiscal IS NOT NULL;

        -- ==================== PROCESOS MENSUALES ====================
        IF LEN(@sPeriodo) > 4
        BEGIN
            -- Mes Anterior
            UPDATE [EAI].[CFDI_Bitacora]
            SET SF_Amount = [T3].[FN_TOTAL_FACT](Doc_Num) * 
                            CASE WHEN Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
            WHERE Doc_Num IN (
                SELECT Bita.Doc_Num
                FROM [EAI].[CFDI_Bitacora] Bita
                INNER JOIN [T3].[Factura_General] FG ON Bita.Doc_Num = FG.Factura
                WHERE ISNULL(Bita.SF_Amount, 0) = 0
                  AND FORMAT(Bita.Invc_dt, 'yyyyMM') = @sPeriodo
                UNION ALL
                SELECT Bita.Doc_Num
                FROM [EAI].[CFDI_Bitacora] Bita
                INNER JOIN [T3].[Preventa_General] FG ON Bita.Doc_Num = FG.Factura
                WHERE ISNULL(Bita.SF_Amount, 0) = 0
                  AND FORMAT(Bita.Invc_dt, 'yyyyMM') = @sPeriodo
                  AND FG.Fecha_Proc_BATMD < GETDATE()
                  AND FG.Fecha_Cancelacion IS NULL
            );

            -- Mes Siguiente
            UPDATE [EAI].[CFDI_Bitacora]
            SET Invc_dt = FG.Fecha_Factura
            FROM [EAI].[CFDI_Bitacora] Bita
            INNER JOIN [T3].[Factura_General] FG ON Bita.Doc_Num = FG.Factura
            WHERE FORMAT(Bita.Invc_dt, 'yyyyMM') != FORMAT(FG.Fecha_Factura, 'yyyyMM')
              AND FORMAT(Bita.Invc_dt, 'yyyyMM') = @sPeriodo;

            -- LOB Inicio de Mes
            INSERT INTO [EAI].[CFDI_Bitacora]
                (Row_ID, Doc_Num, Nota_Venta_CFDI, Invc_Dt, Fecha_Trn, Factura_SAP,
                 Ctro, Terr, Tipo_Vta, Docto_Ind, Fecha_Venta,
                 Nombre_Cliente, Cliente_SAP, Clte_Factura_SAP, SF_Amount, SAP_Amount)
            SELECT 
                PG.Factura, PG.Factura, PG.Factura,
                PG.Fecha_Factura, PG.Fecha_Trn, PG.Entrega,
                PG.Ctro, '0000',
                CASE WHEN PG.Clase_Factura = 'C005' THEN 'Vta' ELSE 'Dev' END,
                1, PG.Fecha_Factura,
                MC.Nombre, PG.Cliente_SAP, PG.Cliente_SAP,
                (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0)) * 
                    CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END,
                (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0)) * 
                    CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END
            FROM [T3].[Preventa_General] PG
            LEFT JOIN [EAI].[CFDI_Bitacora] Bita ON PG.Factura = Bita.Doc_Num
            LEFT JOIN [T3].[Mov_Cliente] MC ON PG.Cliente_SAP = MC.Cliente_SAP
            LEFT JOIN [EAI].[FC__Time_Window] TW ON 1=1
            LEFT JOIN [EAI].[T3R_Sales_Docs_Old] SAP ON PG.Entrega = SAP.Doc_Num_R3
            WHERE PG.Clase_Factura IN ('C005', 'C006')
              AND PG.Fecha_Cancelacion IS NOT NULL
              AND PG.Fecha_Proc_BATMD < GETDATE()
              AND ISNULL(Bita.Doc_Num, 'INSERT') = 'INSERT'
              AND PG.Fecha_Factura >= TRY_CONVERT(DATE, TW.Start_DAte, 103);

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END

        -- ==================== ELIMINAR CHEQUES DEVUELTOS ====================
        DELETE FROM [EAI].[CFDI_Bitacora]
        WHERE Doc_Num LIKE 'CHP%';

        -- ==================== FINALIZAR ====================
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

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SET @sErrorCode = 'ORA-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + 
                              ERROR_MESSAGE(), 1, 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
             STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
             SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', @v_ID, GETDATE(), NULL, @nPID,
             'Error', 'SF_BITACORA_CFDI_VENTA_SF', @sMsg, 'T-SQL',
             @sErrorCode, NULL, NULL, NULL);

        PRINT '---------------------------------------------';
        PRINT '**** Error en SF_BITACORA_CFDI_VENTA_SF *****';
        PRINT @sMsg;

        -- Re-throw para que quede registrado en SQL Agent
        THROW;
    END CATCH
END;