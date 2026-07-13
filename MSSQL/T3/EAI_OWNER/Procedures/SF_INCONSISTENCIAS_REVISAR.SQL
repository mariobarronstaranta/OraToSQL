CREATE OR ALTER PROCEDURE EAI_OWNER.SF_INCONSISTENCIAS
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg            NVARCHAR(500),
        @sErrorCode      NVARCHAR(20),
        @nPID            BIGINT,
        @nProceso        INT,
        @nProceso3       INT,
        @nProceso4       INT;

    BEGIN TRY

        SET @nProceso  = 1111;
        SET @nProceso3 = 0;
        SET @nProceso4 = 0;

        SET @nPID = NEXT VALUE FOR dbo.ProcessID;

        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
        (
            PID,
            PROCESO,
            FECHA_PROC_BATMD,
            INICIO
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            GETDATE()
        );

        BEGIN TRANSACTION;

        ----------------------------------------------------------
        -- BLOQUE 1
        -- Diferencia Entre Encabezado De Factura Y Pedido
        ----------------------------------------------------------

        INSERT INTO EAI_OWNER.INCONSISTENCIAS_TOTALES
        (
            INCONSISTENCIA,
            REGION,
            AREA,
            TERRITORIO,
            RECURSO,
            CTE_SAP,
            FACTURA,
            FECHA,
            DELIVERY_STATUS,
            INVC_STATUS,
            NUM_PEDIDO,
            ORDER_STATUS,
            PAID_AMT,
            TTL_INVC_AMT,
            FACT_DET_AMT,
            TOTAL_PEDIDO,
            TOTAL_DET_PED,
            FECHA_CREACION
        )
        SELECT
            'Diferencia Entre Encabezado De Factura Y Encabezado De Pedido',
            R.Region,
            R.Area,
            R.Territorio,
            R.Resource_Name,
            F.Cte_Sap,
            F.Doc_Num,
            TRY_CONVERT(date,F.Invc_Dt,23),
            F.Delivery_Status,
            F.Invc_Status,
            F.Num_Pedido,
            P.Order_Status,
            NULL,
            TRY_CONVERT(decimal(18,2),F.Ttl_Invc_Amt),
            NULL,
            P.Order_Amt,
            NULL,
            GETDATE()
        FROM EAI_OWNER.FACTURAS F
        INNER JOIN EAI_OWNER.PEDIDOS P
            ON P.Name = F.Num_Pedido
        INNER JOIN EAI_OWNER.RECURSO_TERRITORIO R
            ON SUBSTRING(F.Doc_Num,2,4)
             = SUBSTRING(R.Territorio,17,4)
        WHERE F.Id <> 'ID'
          AND P.Id <> 'ID'
          AND TRY_CONVERT(date,F.Invc_Dt,23)
                > DATEFROMPARTS(YEAR(GETDATE()),
                                MONTH(GETDATE()),
                                1)
          AND TRY_CONVERT(date,F.Invc_Dt,23)
                < CAST(GETDATE() AS DATE)
          AND F.Delivery_Status='Delivered'
          AND F.Tipo <> 'Pre Sales'
          AND P.Order_Status='Invoiced'
          AND COALESCE(
                TRY_CONVERT(decimal(18,2),
                F.Ttl_Invc_Amt),0)
              <>
              COALESCE(P.Order_Amt,0)
          AND R.Territorio <> 'NAME';

        ----------------------------------------------------------
        -- RESTO DE BLOQUES
        -- Migrar usando el mismo patrón
        ----------------------------------------------------------

        COMMIT TRANSACTION;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin        = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
        WHERE PID = @nPID;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(ERROR_MESSAGE(),250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
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
            NULL,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'SF_INCONSISTENCIAS',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END
GO