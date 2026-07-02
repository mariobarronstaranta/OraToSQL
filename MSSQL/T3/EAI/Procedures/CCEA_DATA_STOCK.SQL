CREATE OR ALTER PROCEDURE dbo.CCEA_DATA_STOCK
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @v_ID VARCHAR(50),
        @sMsg VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @nPID BIGINT,
        @nProceso INT,
        @nProceso3 INT,
        @nProceso4 INT;

    BEGIN TRY

        SET @nProceso = 722;

        SET @nPID =
            NEXT VALUE FOR EAI_OWNER.ProcessID;

        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
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
            GETDATE()
        );

        SET @nProceso3 = 0;
        SET @nProceso4 = 0;

        TRUNCATE TABLE EAI.CC_DATA_STOCK;

        INSERT INTO EAI.CC_DATA_STOCK
        (
            PLANT,
            TERRITORY,
            STOCK_PARTNER,
            PARTNER_NAME,
            MATERIAL,
            UOM,
            SAP_QTY,
            ACTUAL_QTY,
            UMB,
            UOM_1,
            UOM_2
        )
        SELECT
            LTRIM(RTRIM(T1.Planta)),
            SUBSTRING(T1.Partner_Name,15,4),
            RIGHT('0000000000' + T1.Partner_ID,10),
            LTRIM(RTRIM(T1.Partner_Name)),
            LTRIM(RTRIM(T1.Material)),
            LTRIM(RTRIM(Mat.Unidad_Med_Vta)),
            LTRIM(RTRIM(CAST(T1.Libre_Utilizacion AS VARCHAR(50)))),

            CASE
                WHEN T1.UMB = 'TH' THEN
                    CAST(
                        ISNULL(T1.Libre_Utilizacion,0) * 1000.0 /
                        NULLIF(
                            CASE
                                WHEN Mat.Unidad_Med_Vta = 'CAJ'
                                    THEN ISNULL(Mat.Cig_x_CLL,1)
                                ELSE ISNULL(Mat.Cig_x_PAQ,1)
                            END,
                        0)
                    AS VARCHAR(50))

                WHEN T1.UMB IN ('PC','EA') THEN
                    CAST(
                        ISNULL(T1.Libre_Utilizacion,0) /
                        NULLIF(
                            CASE
                                WHEN Mat.Unidad_Med_Vta = 'CAJ'
                                    THEN ISNULL(Mat.Cig_x_CLL,1)
                                ELSE ISNULL(Mat.Cig_x_PAQ,1)
                            END,
                        0)
                    AS VARCHAR(50))

                ELSE
                    CAST(ISNULL(T1.Stock_NO_Libre,0) AS VARCHAR(50))
            END,

            CAST(T1.UMB AS VARCHAR(50)),
            CAST(ISNULL(Mat.Cig_x_CLL,1) AS VARCHAR(50)),
            CAST(ISNULL(Mat.Cig_x_PAQ,1) AS VARCHAR(50))

        FROM EAI.T3R_REPORTE_STOCK_TAO T1
        LEFT JOIN T3.Material Mat
            ON T1.Material = Mat.Material;

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin        = GETDATE(),
               Proceso_1  = 0,
               Proceso_2  = 0,
               Proceso_3  = @nProceso3,
               Proceso_4  = @nProceso4
         WHERE PID = @nPID;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-', ERROR_NUMBER());

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
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'CCEA_DATA_STOCK',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH
END;
GO
