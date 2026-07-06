CREATE PROCEDURE EAI.CCEA_DATA_UNLOAD
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID VARCHAR(50),
        @sMsg NVARCHAR(500),
        @sErrorCode VARCHAR(20),
        @nPID BIGINT,
        @nProceso INT,
        @nProceso3 INT,
        @nProceso4 INT;

    BEGIN TRY

        SET @nProceso = 727;

        SELECT @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

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

        TRUNCATE TABLE EAI.CC_DATA_UNLOAD;

        INSERT INTO EAI.CC_DATA_UNLOAD
        (
            PLANT,
            TERRITORY,
            UNLOAD_DATE,
            UNLOAD_REF_NUMBER,
            MATERIAL,
            UOM,
            SAP_QTY,
            ACTUAL_QTY,
            UMB,
            UOM_1,
            UOM_2
        )
        SELECT
            Doc.ShippingPoint,
            SUBSTRING(Cte.Nombre,15,4),

            CONVERT(VARCHAR(10),
                TRY_CONVERT(DATE, Doc.DocumentDate, 112),
                23
            ),

            Det.MaterialDescripcion,
            Det.Material,
            Det.UnidadMedida,

            LTRIM(RTRIM(CAST(
                (
                    (Det.Cantidad * Mat.Cig_x_CLL)
                    /
                    NULLIF(
                        ISNULL(Conv.SAP_UM_Conv,1000),
                        0
                    )
                ) AS VARCHAR(50)
            ))),

            LTRIM(RTRIM(CAST(
                Det.Cantidad AS VARCHAR(50)
            ))),

            ISNULL(Conv.SAP_UM_Base,'TH'),

            LTRIM(RTRIM(CAST(
                ISNULL(Mat.Cig_x_CLL,0)
                AS VARCHAR(50)
            ))),

            LTRIM(RTRIM(CAST(
                ISNULL(Mat.Cig_x_PAQ,0)
                AS VARCHAR(50)
            )))
        FROM
        (
            SELECT
                FORMAT(
                    DATEADD
                    (
                        MONTH,
                        -1,
                        CONVERT(DATE,Start_Date,103)
                    ),
                    'yyyyMM'
                ) AS Begins
            FROM EAI.FC__Time_Window
        ) TW
        INNER JOIN EAI_OWNER.tmp_Document_Header Doc
            ON SUBSTRING(Doc.DocumentDate,1,6) >= TW.Begins
        INNER JOIN EAI_OWNER.tmp_Document_Detail Det
            ON Doc.ReferenceID = Det.ReferenceID
        INNER JOIN T3.Material Mat
            ON Det.Material = Mat.Material
        LEFT JOIN T3.Material_SAP Conv
            ON Det.Material = Conv.Material
        INNER JOIN T3.Mov_Cliente Cte
            ON Doc.Cust_to_SAP = Cte.Cliente_SAP
        WHERE
            Doc.DocumentDate >= '20200917'
            AND Doc.MetodoPago = 'Van Replenishment'
            AND Doc.DeliveryType = 'Stock Discard'
            AND Doc.Cust_to_SAP LIKE '009%'
            AND Cte.Nombre LIKE 'VAN%';

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET
            Fin = GETDATE(),
            Proceso_1 = 0,
            Proceso_2 = 0,
            Proceso_3 = @nProceso3,
            Proceso_4 = @nProceso4
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
            'CCEA_DATA_UNLOAD',
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
