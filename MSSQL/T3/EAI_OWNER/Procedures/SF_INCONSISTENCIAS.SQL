CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_INCONSISTENCIAS]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg          VARCHAR(500),
        @sErrorCode    VARCHAR(20),
        @nPID          BIGINT,
        @nProceso      INT = 1111,
        @nProceso3     INT = 0,
        @nProceso4     INT = 0,
        @Today         DATE = CAST(GETDATE() AS DATE),
        @StartOfMonth  DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);

    /*
        Developer notes:
        - Conversion from ORA/T3/EAI_OWNER/Procedures/SF_INCONSISTENCIAS.SQL.
        - The Oracle procedure commits after each INSERT. This SQL Server version
          intentionally does not wrap all rules in one transaction, preserving that
          behavior: completed rules remain persisted if a later rule fails.
        - Oracle TO_DATE/TO_NUMBER/NVL were converted to TRY_CONVERT/COALESCE so
          malformed operational rows do not abort rules that were tolerant in reports.
        - Oracle outer joins "(+)" were converted to LEFT JOIN.
        - The commented Oracle rules for invoice/order detail differences remain
          omitted because they are disabled in the source procedure.
    */

    BEGIN TRY
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG] (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES (@nPID, @nProceso, NULL, GETDATE());

        /*
            Common target column order for INCONSISTENCIAS_TOTALES.
            Every rule below uses explicit columns to avoid Oracle positional
            alias mistakes from leaking into SQL Server.
        */

        -- 1. Invoice header amount differs from order header amount.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Diferencia Entre Encabezado De Factura Y Encabezado De Pedido',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        WHERE F.Id <> 'ID'
          AND P.Id <> 'ID'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND P.Order_Status = 'Invoiced'
          AND P.Tipo <> 'Pre Sales'
          AND COALESCE(TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), 0)
              <> COALESCE(TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), 0)
          AND R.Territorio <> 'NAME';

        -- 2. Delivered invoice without matching order.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Factura Sin Pedido',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND R.Territorio <> 'NAME'
          AND P.Name IS NULL;

        -- 3. Invoice has order, but the order is not Invoiced.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Factura Con Pedido En Estatus Diferente A Invoiced',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND P.Order_Status <> 'Invoiced'
          AND R.Territorio <> 'NAME';

        -- 4. Oracle source checks NULL fiscal invoice number; the territory join preserves the original no-match behavior.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Factura Sin Folio Fiscal',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND F.Doc_Num IS NULL
          AND R.Territorio <> 'NAME';

        -- 5. More than one delivered invoice for the same order.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'N Facturas 1 Pedido',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN (
            SELECT Num_Pedido
            FROM [EAI_OWNER].[Facturas]
            WHERE TRY_CONVERT(DATE, Invc_Dt, 23) > @StartOfMonth
              AND TRY_CONVERT(DATE, Invc_Dt, 23) < @Today
              AND Delivery_Status = 'Delivered'
            GROUP BY Num_Pedido
            HAVING COUNT(*) > 1
        ) AS D
            ON D.Num_Pedido = F.Num_Pedido
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Tipo <> 'Pre Sales'
          AND R.Territorio <> 'NAME';

        -- 6. Duplicate payments by payment date, amount, DOI and customer.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Pagos duplicados',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, GETDATE()
        FROM (
            SELECT
                TRY_CONVERT(DATE, payment_dt, 23) AS fecha,
                TRY_CONVERT(DECIMAL(18, 2), Payment_Amt) AS monto,
                doi_name,
                Cte_Sap
            FROM [EAI_OWNER].[Pagos]
            WHERE TRY_CONVERT(DATE, payment_dt, 23) > @StartOfMonth
            GROUP BY TRY_CONVERT(DATE, payment_dt, 23), TRY_CONVERT(DECIMAL(18, 2), Payment_Amt), doi_name, Cte_Sap
            HAVING COUNT(*) > 1
        ) AS D
        INNER JOIN [EAI_OWNER].[Pagos] AS P
            ON P.doi_name = D.doi_name
           AND TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt) = D.monto
           AND TRY_CONVERT(DATE, P.payment_dt, 23) = D.fecha
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME';

        -- 7. Fully applied payment duplicated across more than one invoice.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Pagos Totalmente Aplicados A Mas De Una Factura',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, GETDATE()
        FROM [EAI_OWNER].[Pagos] AS P
        INNER JOIN (
            SELECT Id
            FROM [EAI_OWNER].[Pagos]
            WHERE Id <> 'NAME'
              AND Doi_Status = 'Closed'
            GROUP BY Id
            HAVING COUNT(*) > 1
        ) AS D
            ON D.Id = P.Id
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME';

        -- 8. Closed payments with zero amount.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Pagos Con Importe Total 0',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, GETDATE()
        FROM [EAI_OWNER].[Pagos] AS P
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND COALESCE(TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), 0) = 0
          AND P.Doi_Status = 'Closed'
          AND DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(P.Created_Date, CONVERT(VARCHAR(19), GETDATE(), 120)), 19), 'T', ' '), 120)) > @StartOfMonth;

        -- 9. Payment amount greater than DOI amount.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'DOI Pagado en Exceso',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(D.Created_Date, P.Created_Date), 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Pagos] AS P
        INNER JOIN [EAI_OWNER].[Debit_Open_Item] AS D
            ON D.Name = P.Doi_Name
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt) > TRY_CONVERT(DECIMAL(18, 2), D.Amount)
          AND DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(D.Created_Date, CONVERT(VARCHAR(19), GETDATE(), 120)), 19), 'T', ' '), 120)) > @StartOfMonth
          AND P.Doi_Status = 'Closed';

        -- 10. DOI assigned amount is lower than the sum of its payments, current month.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT DISTINCT
            'Debit Open Item Cuyo Importe Asociado Es Menor A La SUMa De Sus Pagos',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(D.Created_Date, P.Created_Date), 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            A.Total_Pagos, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM (
            SELECT
                Doi_Name,
                SUM(TRY_CONVERT(DECIMAL(18, 2), Payment_Amt)) AS Total_Pagos,
                TRY_CONVERT(DECIMAL(18, 2), Doi_Paid_Amt) AS Importe_Asignado
            FROM [EAI_OWNER].[Pagos]
            WHERE Id <> 'NAME'
              AND DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(Created_Date, CONVERT(VARCHAR(19), GETDATE(), 120)), 19), 'T', ' '), 120)) > @StartOfMonth
            GROUP BY Doi_Name, TRY_CONVERT(DECIMAL(18, 2), Doi_Paid_Amt)
        ) AS A
        INNER JOIN [EAI_OWNER].[Pagos] AS P
            ON P.Doi_Name = A.Doi_Name
        LEFT JOIN [EAI_OWNER].[Debit_Open_Item] AS D
            ON D.Name = P.Doi_Name
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND A.Importe_Asignado < A.Total_Pagos
          AND DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(P.Created_Date, CONVERT(VARCHAR(19), GETDATE(), 120)), 19), 'T', ' '), 120)) > @StartOfMonth
          AND P.Doi_Status = 'Closed';

        -- 11. DOI assigned amount is greater than the sum of its payments.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT DISTINCT
            'Debit Open Item Cuyo Importe Asociado Es Menor A La SUMa De Sus Pagos',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(D.Created_Date, P.Created_Date), 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            A.Total_Pagos, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM (
            SELECT
                Doi_Name,
                SUM(TRY_CONVERT(DECIMAL(18, 2), Payment_Amt)) AS Total_Pagos,
                TRY_CONVERT(DECIMAL(18, 2), Doi_Paid_Amt) AS Importe_Asignado
            FROM [EAI_OWNER].[Pagos]
            WHERE Id <> 'NAME'
            GROUP BY Doi_Name, TRY_CONVERT(DECIMAL(18, 2), Doi_Paid_Amt)
        ) AS A
        INNER JOIN [EAI_OWNER].[Pagos] AS P
            ON P.Doi_Name = A.Doi_Name
        LEFT JOIN [EAI_OWNER].[Debit_Open_Item] AS D
            ON D.Name = P.Doi_Name
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND A.Importe_Asignado > A.Total_Pagos
          AND P.Doi_Status = 'Closed';

        -- 12. Paid DOI with incorrect status and delayed extraction.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT DISTINCT
            'Debit Open Item pagada y con estatus incorrecto',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, P.Doi_Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(COALESCE(D.Created_Date, P.Created_Date), 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM (
            SELECT
                Doi_Name,
                SUM(TRY_CONVERT(DECIMAL(18, 2), Payment_Amt)) AS Total_Pagos
            FROM [EAI_OWNER].[Pagos]
            WHERE Id <> 'NAME'
            GROUP BY Doi_Name, Doi_Paid_Amt
        ) AS A
        INNER JOIN [EAI_OWNER].[Pagos] AS P
            ON P.Doi_Name = A.Doi_Name
        INNER JOIN [EAI_OWNER].[Debit_Open_Item] AS D
            ON D.Name = P.Doi_Name
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND TRY_CONVERT(DECIMAL(18, 2), P.Doi_Amt) = A.Total_Pagos
          AND TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120) > @StartOfMonth
          AND D.Status <> 'Closed'
          AND DATEDIFF(DAY,
                TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(D.LAST_MOD_DT, 19), 'T', ' '), 120),
                TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(D.EXTRACT_DT, 19), 'T', ' '), 120)) > 2;

        -- 13. Collected invoices without assigned amount.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas Collected Sin Asignacion',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            NULL, NULL, TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt),
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt) = 0
          AND F.Invc_Status = 'Collected'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 14. Payments without customer.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Pagos Sin Cliente',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, GETDATE()
        FROM [EAI_OWNER].[Pagos] AS P
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Id <> 'NAME'
          AND COALESCE(CONVERT(VARCHAR(50), P.Cte_Sap), '0') = '0';

        -- 15. Delivered invoices with zero amount.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas En 0',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND COALESCE(TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), 0) = 0
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 16. Delivered invoices without a DOI after extraction tolerance.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas sin Debit Open Item',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND F.Tipo <> 'Pre Sales'
          AND F.Delivery_Status = 'Delivered'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today
          AND NOT EXISTS (
              SELECT 1
              FROM [EAI_OWNER].[DEBIT_OPEN_ITEM] AS D
              WHERE D.DOC_NUM = F.Doc_Num
          )
          AND DATEDIFF(DAY, TRY_CONVERT(DATE, F.Invc_Dt, 23), TRY_CONVERT(DATE, LEFT(F.EXTRACT_DT, 10), 23)) > 1;

        -- 17. Invoice paid amount is greater than invoice total.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas Con Importe Asociado Mayor Al Total De La Factura',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt),
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt) > 0
          AND TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt) > TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt)
          AND F.Tipo <> 'Pre Sales'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 18. Invoice fully paid but status is not Collected.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas Con Importe Asociado Igual Al Total De La Factura Con Estatus Diferente De Collected',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt),
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt) > 0
          AND TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt) > 0
          AND F.Invc_Status <> 'Collected'
          AND TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt) = TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt)
          AND F.Tipo <> 'Pre Sales'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 19. Delivered invoice without customer.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas Sin Cliente',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt),
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND COALESCE(CONVERT(VARCHAR(50), F.Cte_Sap), '0') = '0'
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 20. Delivered invoice without resource.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas Sin Recurso Asociado',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, TRY_CONVERT(DECIMAL(18, 2), F.Paid_Amt),
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL,
            TRY_CONVERT(DECIMAL(18, 2), P.Order_Amt), NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON SUBSTRING(F.Doc_Num, 2, 4) = SUBSTRING(R.Territorio, 17, 4)
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE F.Id <> 'ID'
          AND COALESCE(CONVERT(VARCHAR(50), F.Recurso), '0') = '0'
          AND F.Delivery_Status = 'Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, F.Invc_Dt, 23) < @Today;

        -- 21. Payments without invoice in DOI.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Pagos Sin Factura',
            R.Region, R.Area, R.Territorio, R.Resource_Name, P.Cte_Sap, P.Invc_Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            P.Id, P.mobile_id,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(P.Created_Date, 19), 'T', ' '), 120)),
            TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt), P.Doi_Name,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, GETDATE()
        FROM [EAI_OWNER].[Pagos] AS P
        LEFT JOIN [EAI_OWNER].[Debit_Open_Item] AS D
            ON D.Name = P.DOI_Name
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON P.territorio = R.Territorio
        WHERE P.Doi_Status <> 'Open'
          AND COALESCE(D.doc_num, '0') = '0'
          AND TRY_CONVERT(DECIMAL(18, 2), P.Payment_Amt) > 0;

        -- 22. Closed DOI has paid amount but no payment rows.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Debit Open Item Con Importe Asociado Sin Pago',
            R.Region, R.Area, R.Territorio, R.Resource_Name, D.Cliente_Sap, D.Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, D.Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(D.Created_Date, 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Debit_Open_Item] AS D
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON D.territorio = R.Territorio
        WHERE COALESCE(TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount), 0) > 0
          AND D.Status = 'Closed'
          AND TRY_CONVERT(DATE, LEFT(D.Created_Date, 10), 23) > @StartOfMonth
          AND TRY_CONVERT(DATE, LEFT(D.LAST_MOD_DT, 10), 23) < @Today
          AND NOT EXISTS (
              SELECT 1
              FROM [EAI_OWNER].[Pagos] AS P
              WHERE P.Doi_Name = D.Name
          );

        -- 23. Closed DOI has no outstanding amount even though total is greater than paid.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Debit Open Item En Estatus Closed Con Monto Total Mayor Al Asociado Y Sin Monto Restante',
            R.Region, R.Area, R.Territorio, R.Resource_Name, D.Cliente_Sap, D.Doc_Num,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, D.Name,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(D.Created_Date, 19), 'T', ' '), 120)),
            D.Status, TRY_CONVERT(DECIMAL(18, 2), D.Amount), TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Debit_Open_Item] AS D
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON D.territorio = R.Territorio
        WHERE COALESCE(TRY_CONVERT(DECIMAL(18, 2), D.Amount), 0) > COALESCE(TRY_CONVERT(DECIMAL(18, 2), D.Paid_Amount), 0)
          AND COALESCE(TRY_CONVERT(DECIMAL(18, 2), D.OutstANDing_Amount), 0) = 0
          AND D.Status = 'Closed'
          AND TRY_CONVERT(DATE, LEFT(D.Created_Date, 10), 23) > @StartOfMonth;

        -- 24-27. Credit note consistency rules.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            C.Inconsistencia,
            R.Region, R.Area, R.Territorio, R.Resource_Name, C.CTE_Sap, NULL,
            DATEADD(HOUR, -5, TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(C.Created_Date, 19), 'T', ' '), 120)),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            C.NAME, C.CN_KEY, C.STATUS, C.IS_USED, C.SR_ORDER_NAME,
            TRY_CONVERT(DECIMAL(18, 2), C.AMOUNT),
            TRY_CONVERT(DECIMAL(18, 2), C.APP_AMT),
            TRY_CONVERT(DECIMAL(18, 2), C.ACTUAL_AMT),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM (
            SELECT
                CN.*,
                'Credit Note con monto aplicado y monto restante mayor a 0 y sin flag de IS_USED' AS Inconsistencia
            FROM [EAI_OWNER].[Credit_Notes] AS CN
            WHERE CN.Status = 'Confirmed'
              AND UPPER(CN.Is_Used) = 'FALSE'
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.ACTUAL_AMT), 0), 2) > 0
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.APP_AMT), 0), 2) > 0
            UNION ALL
            SELECT
                CN.*,
                'Credit Note con monto total y monto restante iguales, CON flag de IS_USED y sin monto aplicado'
            FROM [EAI_OWNER].[Credit_Notes] AS CN
            WHERE CN.Status = 'Confirmed'
              AND UPPER(CN.Is_Used) = 'TRUE'
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.ACTUAL_AMT), 0), 2) = ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.AMOUNT), 0), 2)
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.APP_AMT), 0), 2) = 0
            UNION ALL
            SELECT
                CN.*,
                'Credit Note con monto total y monto aplicado iguales, CON flag de IS_USED y con monto restante > 0'
            FROM [EAI_OWNER].[Credit_Notes] AS CN
            WHERE CN.Status = 'Confirmed'
              AND UPPER(CN.Is_Used) = 'TRUE'
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.APP_AMT), 0), 2) = ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.AMOUNT), 0), 2)
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.ACTUAL_AMT), 0), 2) > 0
              AND TRY_CONVERT(DATE, CN.FECHA, 23) < @Today
            UNION ALL
            SELECT
                CN.*,
                'Credit Note SIN USAR y con asignaciones'
            FROM [EAI_OWNER].[Credit_Notes] AS CN
            WHERE CN.Status = 'Confirmed'
              AND UPPER(CN.Is_Used) = 'FALSE'
              AND ROUND(COALESCE(TRY_CONVERT(DECIMAL(18, 2), CN.APP_AMT), 0), 2) = 0
              AND EXISTS (
                  SELECT 1
                  FROM [EAI_OWNER].[PAGOS] AS P
                  WHERE P.CN_KEY = CN.CN_KEY
              )
        ) AS C
        LEFT JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON C.Territorio = R.territorio;

        -- 28. SKUs with zero price in the price list.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'SKUs sin precio en LP',
            NULL, NULL, NULL, NULL, NULL, NULL, TRY_CONVERT(DATE, VALID_TO, 23),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, SKU, PRICE_LIST, SKU_NAME,
            TRY_CONVERT(DECIMAL(18, 2), PRICE_ON_UOM_1), GETDATE()
        FROM [EAI_OWNER].[PRECIOS]
        WHERE COALESCE(ROUND(TRY_CONVERT(DECIMAL(18, 2), PRICE_ON_UOM_1), 2), 0) = 0;

        -- 29. Gap in fiscal mask sequence for invoices.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT DISTINCT
            'Desfase en la secuencia de la mascara fiscal (Invoices)',
            R.Region, R.Area, R.Territorio, R.Resource_Name, NULL, S.DOC_NUM,
            S.Fecha, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            S.SUFIJO_ANTERIOR, S.SUFIJO,
            CASE
                WHEN ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO), 0) - COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO_ANTERIOR), 0)) - 1 > 15
                    THEN 'Posible Cambio de Transaction Secuence'
                ELSE 'Posible perdida de facturas en la sincronizacion'
            END,
            CASE
                WHEN ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO), 0) - COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO_ANTERIOR), 0)) - 1 > 15
                    THEN 'Posible Cambio de Transaction Secuence'
                ELSE CONVERT(VARCHAR(50), ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO), 0) - COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO_ANTERIOR), 0)) - 1)
            END,
            NULL, NULL, NULL, NULL, GETDATE()
        FROM (
            SELECT
                B.RECURSO,
                B.DOC_NUM,
                TRY_CONVERT(DATETIME2(0), REPLACE(LEFT(B.Created_Date, 19), 'T', ' '), 120) AS Fecha,
                LAG(SUBSTRING(B.DOC_NUM, 7, LEN(B.DOC_NUM)), 1, SUBSTRING(B.DOC_NUM, 7, LEN(B.DOC_NUM)))
                    OVER (
                        PARTITION BY SUBSTRING(B.DOC_NUM, 1, 5)
                        ORDER BY SUBSTRING(B.DOC_NUM, 1, 6), SUBSTRING(B.DOC_NUM, 7, LEN(B.DOC_NUM))
                    ) AS SUFIJO_ANTERIOR,
                SUBSTRING(B.DOC_NUM, 7, LEN(B.DOC_NUM)) AS SUFIJO
            FROM [EAI_OWNER].[FACTURAS_B] AS B
            WHERE SUBSTRING(B.DOC_NUM, 1, 1) IN ('V', 'D')
              AND SUBSTRING(B.DOC_NUM, 1, 1) NOT IN ('VP', 'DP')
              AND SUBSTRING(B.DOC_NUM, 6, 1) <> 'A'
              AND SUBSTRING(B.DOC_NUM, 7, LEN(B.DOC_NUM)) NOT LIKE '%TESTING%'
              AND B.Tipo <> 'Pre Sales'
              AND TRY_CONVERT(DATE, B.Invc_Dt, 23) > @StartOfMonth
              AND TRY_CONVERT(DATE, B.Invc_Dt, 23) < @Today
              AND B.DOC_NUM NOT LIKE '%-A' AND B.DOC_NUM NOT LIKE '%[_]A'
              AND B.DOC_NUM NOT LIKE '%-B' AND B.DOC_NUM NOT LIKE '%[_]B'
              AND B.DOC_NUM NOT LIKE '%-C' AND B.DOC_NUM NOT LIKE '%[_]C'
              AND B.DOC_NUM NOT LIKE '%-D' AND B.DOC_NUM NOT LIKE '%[_]D'
              AND B.DOC_NUM NOT LIKE '%-E' AND B.DOC_NUM NOT LIKE '%[_]E'
              AND B.DOC_NUM NOT LIKE '%-F' AND B.DOC_NUM NOT LIKE '%[_]F'
        ) AS S
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON S.recurso = R.resource_name
        WHERE ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO), 0) - COALESCE(TRY_CONVERT(DECIMAL(18, 2), S.SUFIJO_ANTERIOR), 0)) > 1;

        -- 30. Pre-sales invoices not delivered or rescheduled for more than four days.
        INSERT INTO [EAI_OWNER].[INCONSISTENCIAS_TOTALES]
        (
            INCONSISTENCIA, REGION, AREA, TERRITORIO, RECURSO, CTE_SAP, FACTURA, FECHA,
            DELIVERY_STATUS, INVC_STATUS, NUM_PEDIDO, ORDER_STATUS, PAID_AMT,
            TTL_INVC_AMT, FACT_DET_AMT, TOTAL_PEDIDO, TOTAL_DET_PED, PAGO_NAME,
            PAGO_MOBILE_ID, FECHA_PAGO, IMPORTE_PAGO, DOI, FECHA_DOI, STATUS_DOI,
            MONTO_DOI, MONTO_APLICADO_DOI, SUMA_PAGOS, CN_NAME, CN_KEY, CN_STATUS,
            CN_IS_USED_FLG, SR_ORDER_NAME, CN_AMOUNT, CN_APP_AMT, CN_MONTO_RESTANTE,
            CONSECUTIVO_INICIAL, CONSECUTIVO_FINAL, POSIBLE_FALLA, FOLIOS_PERDIDOS,
            SKU, PRICE_LIST, SKU_NAME, PRICE_UOM1, FECHA_DETECCION
        )
        SELECT
            'Facturas No Entregadas o Re-Programadas hace 4 dias',
            R.Region, R.Area, R.Territorio, R.Resource_Name, F.Cte_Sap, F.Doc_Num,
            TRY_CONVERT(DATE, F.Invc_Dt, 23), F.Delivery_Status, F.Invc_Status,
            F.Num_Pedido, P.Order_Status, NULL,
            TRY_CONVERT(DECIMAL(18, 2), F.Ttl_Invc_Amt), NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL, NULL, NULL, GETDATE()
        FROM [EAI_OWNER].[Facturas] AS F
        INNER JOIN [EAI_OWNER].[Recurso_Territorio] AS R
            ON F.Delivery_Terr = R.Territorio
        LEFT JOIN [EAI_OWNER].[Pedidos] AS P
            ON P.Name = F.Num_Pedido
        WHERE R.Territorio <> 'NAME'
          AND F.tipo = 'Pre Sales'
          AND F.delivery_status IN ('Not delivered', 'Reschedule Requested')
          AND TRY_CONVERT(DATE, F.invc_dt, 23) < DATEADD(DAY, -4, @Today);

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, ID, CREATED, MESSAGE, JOB_PID,
            STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
            SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', NULL, GETDATE(), NULL, @nPID,
            'Error', 'SF_INCONSISTENCIAS', @sMsg, 'TSQL',
            @sErrorCode, NULL, NULL, NULL
        );
    END CATCH;
END;
GO
