CREATE PROCEDURE dbo.CCEA_DATA_OPENITEM
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @v_ID VARCHAR(50),
        @sMsg VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @nPID BIGINT,
        @nProceso INT = 712,
        @nProceso3 INT = 0,
        @nProceso4 INT = 0;

    BEGIN TRY

        BEGIN TRAN;

        SET @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

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

        TRUNCATE TABLE EAI.CC_DATA_OPENITEM;

        INSERT INTO EAI.CC_DATA_OPENITEM
        (
            PLANT,
            SFDC_CUSTOMER,
            SAP_CUSTOMER,
            HEAD_OFFICE,
            PAYMENT_SOURCE,
            SAP_REFERENCE,
            DOCUMENT_DATE,
            DOCUMENT_TYPE,
            SFDC_REFERENCE,
            SAP_AMOUNT
        )
        SELECT
            ISNULL(MC.Ctro,'MXAD'),
            LTRIM(RTRIM(MC.Cliente_V3)),
            Ldr.Head_Office,
            Ldr.Head_Office,
            ISNULL(CS.Forma_Pago,'Central Payment'),
            LTRIM(RTRIM(Ldr.SAP_Reference)),
            TRY_CONVERT(date,Ldr.Document_Date),
            LTRIM(RTRIM(Ldr.Document_Type)),
            Ldr.SFDC_Reference,
            Ldr.SAP_Amount
        FROM
        (
            SELECT
                ISNULL(Branch_Number, Cliente) AS SAP_Customer,
                Cliente AS Head_Office,
                Asignacion AS SAP_Assignment,
                AccountDocument AS SAP_Reference,

                CONVERT(date, Fecha_Doc, 112) AS Document_Date,

                CASE
                    WHEN Tipo_Doc IN ('KP','Z2','ZD')
                        THEN 'Debit Note'
                    WHEN Tipo_Doc IN ('RV','CR')
                        THEN 'Invoice'
                    WHEN Tipo_Doc = 'CG'
                        THEN 'Pending Allocation'
                    ELSE Tipo_Doc
                END AS Document_Type,

                Referencia AS SFDC_Reference,

                CASE
                    WHEN Cargo = 'S' THEN 1
                    ELSE -1
                END
                *
                CAST(ISNULL(NULLIF(LTRIM(RTRIM(Monto)),''),'0') AS DECIMAL(18,2))
                AS SAP_Amount

            FROM EAI.TAO_CARTERA_SAP_LDR

            WHERE Fecha_Doc >= '20190101'

              AND Referencia NOT IN
              (
                    SELECT Referencia
                    FROM EAI_OWNER.TAO_EXCLUDE_ITEMS
              )

              AND Cliente NOT IN
              (
                    SELECT Target
                    FROM EAI_OWNER.MX_HASHTABLE
                    WHERE Type='CifrasControl'
                      AND Source='Discarding Customer'
              )

        ) Ldr

        LEFT JOIN T3.MOV_CLIENTE MC
            ON Ldr.Head_Office = MC.Cliente_SAP

        LEFT JOIN EAI.CLIENTE_SIEBEL CS
            ON Ldr.Head_Office = CS.Cliente_SAP;

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
        WHERE PID = @nPID;

        COMMIT;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(ERROR_NUMBER(),'-',ERROR_MESSAGE()),
                250
            );

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
            'CCEA_DATA_OPENITEM',
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
