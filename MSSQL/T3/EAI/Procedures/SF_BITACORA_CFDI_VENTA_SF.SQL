CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI_VENTA_SF]
    @nEtapa  INT = 0,
    @sPeriod VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sPeriodo   VARCHAR(20),
        @sMsg       VARCHAR(500),
        @v_ID       VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode VARCHAR(20),
        @dtInicio   DATETIME2(0),
        @nPID       BIGINT,
        @nProceso   INT = 826,
        @nProceso1  INT = 0,
        @nProceso2  INT = 0,
        @nProceso3  INT = 0,
        @nProceso4  INT = 0;

    BEGIN TRY
        IF LEN(ISNULL(@sPeriod, '')) < 4
        BEGIN
            SET @sPeriodo = '';

            IF DAY(GETDATE()) IN (1, 2)
                SET @sPeriodo = CONVERT(CHAR(6), DATEADD(DAY, -3, GETDATE()), 112);
        END
        ELSE
        BEGIN
            SET @sPeriodo = @sPeriod;
        END;

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

        SET @v_ID = 'ScrVentaSalesforce';

        IF OBJECT_ID('tempdb..#ScrVentaSalesforce') IS NOT NULL
            DROP TABLE #ScrVentaSalesforce;

        CREATE TABLE #ScrVentaSalesforce
        (
            SF_Factura        VARCHAR(30)    NULL,
            SF_Fecha_Factura  DATE           NULL,
            SF_Cliente_SAP    VARCHAR(20)    NULL,
            SF_Importe_TMD    NUMERIC(15, 2) NULL,
            SF_Tipo_Doc       VARCHAR(4)     NULL,
            Delivery_Status   VARCHAR(50)    NULL,
            Bitacora_DocNum   VARCHAR(30)    NULL,
            Ctro              VARCHAR(4)     NULL,
            Nombre_Cliente    VARCHAR(100)   NULL
        );

        INSERT INTO #ScrVentaSalesforce
        (
            SF_Factura,
            SF_Fecha_Factura,
            SF_Cliente_SAP,
            SF_Importe_TMD,
            SF_Tipo_Doc,
            Delivery_Status,
            Bitacora_DocNum,
            Ctro,
            Nombre_Cliente
        )
        SELECT
            SF.Factura,
            SF.Fecha_Factura,
            SF.Cliente_SAP,
            SF.Importe_TMD,
            SF.Tipo_Doc,
            SF.Delivery_Status,
            ISNULL(Bit.Doc_Num, 'INSERT'),
            MC.Ctro,
            MC.Nombre
        FROM
        (
            SELECT
                Inv.Doc_Num AS Factura,
                TRY_CONVERT(DATE, Inv.Invc_dt, 23) AS Fecha_Factura,
                Inv.Cte_SAP AS Cliente_SAP,
                CAST(Inv.Ttl_Invc_Amt AS NUMERIC(15, 2)) AS Importe_TMD,
                'Vta' AS Tipo_Doc,
                Inv.Delivery_Status AS Delivery_Status
            FROM [EAI_OWNER].[Facturas_B] AS Inv
            CROSS JOIN [EAI].[FC__Time_Window] AS TW
            WHERE Inv.Invc_Status NOT IN ('Cancelled', 'Invalid')
              AND Inv.Invc_dt IS NOT NULL
              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM [EAI_OWNER].[Doctos_Cancelled] AS C
                      WHERE C.Referencia = Inv.Doc_Num
                  )
              AND TRY_CONVERT(DATE, Inv.Invc_dt, 23) < CAST(GETDATE() AS DATE)
              AND TRY_CONVERT(DATE, Inv.Invc_dt, 23) >= DATEADD(DAY, -45, TRY_CONVERT(DATE, TW.Start_Date, 103))

            UNION ALL

            SELECT
                Dev.SR_Invoice_Key AS Factura,
                TRY_CONVERT(DATE, Dev.SRI_Date, 23) AS Fecha_Factura,
                Dev.SAP_CustomerID AS Cliente_SAP,
                CAST(Dev.Total_Amount * -1 AS NUMERIC(15, 2)) AS Importe_TMD,
                'Dev' AS Tipo_Doc,
                ISNULL(Dev.Received_Status, 'Empty') AS Delivery_Status
            FROM [EAI_OWNER].[SR_Invoice] AS Dev
            CROSS JOIN [EAI].[FC__Time_Window] AS TW
            WHERE Dev.SRI_Date IS NOT NULL
              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM [EAI_OWNER].[Doctos_Cancelled] AS C
                      WHERE C.Referencia = Dev.SR_Invoice_Key
                  )
              AND TRY_CONVERT(DATE, Dev.SRI_Date, 23) < CAST(GETDATE() AS DATE)
              AND TRY_CONVERT(DATE, Dev.SRI_Date, 23) >= DATEADD(DAY, -45, TRY_CONVERT(DATE, TW.Start_Date, 103))

            UNION ALL

            SELECT
                CN.Reference_NO AS Factura,
                TRY_CONVERT(DATE, CN.Fecha, 23) AS Fecha_Factura,
                CN.Cte_SAP AS Cliente_SAP,
                CAST(ISNULL(CN.Amount, 0) * -1 AS NUMERIC(15, 2)) AS Importe_TMD,
                'Dev' AS Tipo_Doc,
                'CreditMemo' AS Delivery_Status
            FROM [EAI_OWNER].[Credit_Notes] AS CN
            CROSS JOIN [EAI].[FC__Time_Window] AS TW
            WHERE (CN.Reference_NO LIKE 'DESC%' OR CN.Reference_NO LIKE 'CONECT%')
              AND TRY_CONVERT(DATE, CN.Fecha, 23) < CAST(GETDATE() AS DATE)
              AND TRY_CONVERT(DATE, CN.Fecha, 23) >= DATEADD(DAY, -45, TRY_CONVERT(DATE, TW.Start_Date, 103))
        ) AS SF
        LEFT JOIN [EAI].[CFDI_Bitacora] AS Bit
            ON SF.Factura = Bit.Doc_Num
        LEFT JOIN [T3].[Mov_Cliente] AS MC
            ON SF.Cliente_SAP = MC.Cliente_SAP;

        UPDATE Bit
           SET SF_Amount = SF.SF_Importe_TMD
        FROM [EAI].[CFDI_Bitacora] AS Bit
        INNER JOIN #ScrVentaSalesforce AS SF
            ON Bit.Doc_Num = SF.SF_Factura
           AND SF.SF_Factura = SF.Bitacora_DocNum
        WHERE ISNULL(SF.Delivery_Status, '') <> 'Unsuccessful-X';

        SET @nProceso1 = @@ROWCOUNT;

        SELECT @nProceso2 = COUNT(*)
        FROM #ScrVentaSalesforce AS SF
        WHERE SF.SF_Factura = SF.Bitacora_DocNum
          AND ISNULL(SF.Delivery_Status, '') = 'Unsuccessful-X';

        INSERT INTO [EAI].[CFDI_Bitacora]
        (
            Row_ID,
            Doc_Num,
            Nota_Venta_CFDI,
            Invc_Dt,
            Fecha_Trn,
            Ctro,
            Terr,
            Tipo_Vta,
            Docto_Ind,
            Fecha_Venta,
            Nombre_Cliente,
            Cliente_SAP,
            Clte_Factura_SAP,
            SF_Amount
        )
        SELECT
            SF.SF_Factura,
            SF.SF_Factura,
            SF.SF_Factura,
            SF.SF_Fecha_Factura,
            GETDATE(),
            SF.Ctro,
            '0000',
            SF.SF_Tipo_Doc,
            1,
            SF.SF_Fecha_Factura,
            SF.Nombre_Cliente,
            SF.SF_Cliente_SAP,
            SF.SF_Cliente_SAP,
            SF.SF_Importe_TMD
        FROM #ScrVentaSalesforce AS SF
        WHERE SF.Bitacora_DocNum = 'INSERT';

        SET @nProceso3 = @@ROWCOUNT;

        SET @v_ID = 'ScrInfoSAP';

        UPDATE Bita
           SET SAP_Amount = (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0))
                            * CASE WHEN Bita.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END,
               Factura_SAP = SAP.Doc_Num_R3
        FROM [EAI].[CFDI_Bitacora] AS Bita
        INNER JOIN [EAI].[T3R_Sales_Docs_Old] AS SAP
            ON Bita.Doc_Num = SAP.Doc_Num_ref2
        WHERE Bita.Row_ID IS NOT NULL
          AND SAP.Doc_Status = 'C';

        SET @nProceso4 = @@ROWCOUNT;

        SET @v_ID = 'ScrCreditMemoDelete';

        DELETE Bita
        FROM [EAI].[CFDI_Bitacora] AS Bita
        INNER JOIN [T3].[Preventa_General] AS PG
            ON Bita.Doc_Num = PG.Factura
        WHERE (Bita.Doc_Num LIKE 'DESC%' OR Bita.Doc_Num LIKE 'CONECT%')
          AND DATEDIFF(DAY, PG.Fecha_Factura, Bita.Invc_dt) >= 35;

        UPDATE Bita
           SET SF_Amount = ISNULL(Bita.SAP_Amount, 0)
        FROM [EAI].[CFDI_Bitacora] AS Bita
        WHERE (Bita.Doc_Num LIKE 'DESC%' OR Bita.Doc_Num LIKE 'CONECT%')
          AND ISNULL(Bita.SAP_Amount, 0) <> ISNULL(Bita.SF_Amount, 0)
          AND ISNULL(Bita.SF_Amount, 0) <> 0
          AND Bita.Invc_dt > DATEADD(DAY, -45, GETDATE());

        SET @v_ID = 'Actualizar CFDI_Informe';

        UPDATE Info
           SET Status = CFD.Status,
               Folio_Fiscal = CFD.Folio_Fiscal,
               Valor_Subt = CFD.Valor_Subt * Info.Factor,
               Valor_IVA = CFD.Valor_IVA * Info.Factor
        FROM [EAI].[CFDI_Informe] AS Info
        INNER JOIN [T3].[CFDI_Documentos] AS CFD
            ON Info.Folio_Interno = CFD.Nota_Venta
        WHERE Info.Folio_Fiscal IS NULL
          AND CFD.Folio_Fiscal IS NOT NULL;

        IF LEN(@sPeriodo) > 4
        BEGIN
            SET @v_ID = 'ScrWA_MesAnterior';

            UPDATE Bita
               SET SF_Amount = [T3].[FN_TOTAL_FACT](Bita.Doc_Num)
                               * CASE WHEN Bita.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
            FROM [EAI].[CFDI_Bitacora] AS Bita
            INNER JOIN [T3].[Factura_General] AS FG
                ON Bita.Doc_Num = FG.Factura
            WHERE ISNULL(Bita.SF_Amount, 0) = 0
              AND CONVERT(CHAR(6), Bita.Invc_dt, 112) = @sPeriodo;

            UPDATE Bita
               SET SF_Amount = [T3].[FN_TOTAL_FACT](Bita.Doc_Num)
                               * CASE WHEN Bita.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
            FROM [EAI].[CFDI_Bitacora] AS Bita
            INNER JOIN [T3].[Preventa_General] AS PG
                ON Bita.Doc_Num = PG.Factura
            WHERE ISNULL(Bita.SF_Amount, 0) = 0
              AND CONVERT(CHAR(6), Bita.Invc_dt, 112) = @sPeriodo
              AND PG.Fecha_Proc_BATMD < GETDATE()
              AND PG.Fecha_Cancelacion IS NULL;

            SET @v_ID = 'ScrWA_MesSiguiente';

            UPDATE Bita
               SET Invc_dt = FG.Fecha_Factura
            FROM [EAI].[CFDI_Bitacora] AS Bita
            INNER JOIN [T3].[Factura_General] AS FG
                ON Bita.Doc_Num = FG.Factura
            WHERE CONVERT(CHAR(6), Bita.Invc_dt, 112) <> CONVERT(CHAR(6), FG.Fecha_Factura, 112)
              AND CONVERT(CHAR(6), Bita.Invc_dt, 112) = @sPeriodo;

            SET @v_ID = 'ScrWA_LOBInicioMes';

            INSERT INTO [EAI].[CFDI_Bitacora]
            (
                Row_ID,
                Doc_Num,
                Nota_Venta_CFDI,
                Invc_Dt,
                Fecha_Trn,
                Factura_SAP,
                Ctro,
                Terr,
                Tipo_Vta,
                Docto_Ind,
                Fecha_Venta,
                Nombre_Cliente,
                Cliente_SAP,
                Clte_Factura_SAP,
                SF_Amount,
                SAP_Amount
            )
            SELECT
                PG.Factura,
                PG.Factura,
                PG.Factura,
                PG.Fecha_Factura,
                PG.Fecha_Trn,
                PG.Entrega,
                PG.Ctro,
                '0000',
                CASE WHEN PG.Clase_Factura = 'C005' THEN 'Vta' ELSE 'Dev' END,
                1,
                PG.Fecha_Factura,
                MC.Nombre,
                PG.Cliente_SAP,
                PG.Cliente_SAP,
                (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0))
                    * CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END,
                (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0))
                    * CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END
            FROM [T3].[Preventa_General] AS PG
            LEFT JOIN [EAI].[CFDI_Bitacora] AS Bita
                ON PG.Factura = Bita.Doc_Num
            INNER JOIN [T3].[Mov_Cliente] AS MC
                ON PG.Cliente_SAP = MC.Cliente_SAP
            CROSS JOIN [EAI].[FC__Time_Window] AS TW
            LEFT JOIN [EAI].[T3R_Sales_Docs_Old] AS SAP
                ON PG.Entrega = SAP.Doc_Num_R3
            WHERE PG.Clase_Factura IN ('C005', 'C006')
              AND PG.Fecha_Cancelacion IS NOT NULL
              AND PG.Fecha_Proc_BATMD < GETDATE()
              AND Bita.Doc_Num IS NULL
              AND PG.Fecha_Factura >= TRY_CONVERT(DATE, TW.Start_Date, 103);

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        DELETE FROM [EAI].[CFDI_Bitacora]
        WHERE Doc_Num LIKE 'CHP%';

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
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);

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
            'SF_BITACORA_CFDI_VENTA_SF',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT '---------------------------------------------';
        PRINT '**** Error en SF_BITACORA_CFDI_VENTA_SF *****';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
GO
