CREATE PROCEDURE dbo.CC_DEBT_LDR_TO_CIFRAS
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @nProceso INT = 711;
    DECLARE @nPID BIGINT;
    DECLARE @v_ID VARCHAR(15) = 'FROM Ldr to CC';

    BEGIN TRY

        BEGIN TRAN;

        SELECT @nPID =
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

        UPDATE EAI.CONTROL_REPORTE
        SET
            Inicio = GETDATE(),
            Fin = NULL
        WHERE Reporte IN
        (
            'Preparacion Cartera SAP',
            'REPORTE DE CARTERA'
        );

        TRUNCATE TABLE EAI.T3R_CARTERA_SAP_OLD;

        INSERT INTO EAI.T3R_CARTERA_SAP_OLD
        (
            Cliente,
            Fecha_Doc,
            Tipo_Doc,
            Monto,
            Asignacion,
            Referencia
        )
        SELECT
            ISNULL(Ldr.Branch_Number,Ldr.Cliente),
            Ldr.Fecha_Doc,
            Ldr.Tipo_Doc,
            CASE
                WHEN Ldr.Cargo='S'
                THEN TRY_CONVERT(DECIMAL(18,2),LTRIM(RTRIM(ISNULL(Ldr.Monto,'0'))))
                ELSE TRY_CONVERT(DECIMAL(18,2),LTRIM(RTRIM(ISNULL(Ldr.Monto,'0')))) * -1
            END,
            Ldr.Asignacion,
            COALESCE
            (
                PG.Factura,
                FG.Factura,
                Ldr.Referencia
            )
        FROM EAI.TAO_CARTERA_SAP_LDR Ldr
        LEFT JOIN T3.Preventa_General PG
            ON Ldr.Asignacion = PG.Entrega
        LEFT JOIN T3.Factura_General FG
            ON Ldr.Referencia = FG.Factura;

        UPDATE EAI.T3R_CARTERA_SAP_OLD
           SET Tipo_Doc='ZM'
        WHERE Referencia LIKE '%CSC%';

        UPDATE EAI.T3R_CARTERA_SAP_OLD
           SET Tipo_Doc='ZM'
        WHERE Referencia LIKE 'ZM%';

        UPDATE EAI.T3R_CARTERA_SAP_OLD
           SET Tipo_Doc='Z4'
        WHERE Referencia LIKE 'Z4%';

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE()
        WHERE PID = @nPID;

        UPDATE EAI.CONTROL_REPORTE
           SET Fin = GETDATE()
        WHERE Reporte IN
        (
            'Preparacion Cartera SAP',
            'REPORTE DE CARTERA'
        );

        COMMIT;

    END TRY
    BEGIN CATCH

        IF XACT_STATE() <> 0
            ROLLBACK;

        DECLARE @ErrorCode VARCHAR(50);
        DECLARE @Msg VARCHAR(250);

        SET @ErrorCode =
            CAST(ERROR_NUMBER() AS VARCHAR(50));

        SET @Msg =
            LEFT(ERROR_MESSAGE(),250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
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
            'CifrasControl',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'CC_DEBT_LDR_TO_CIFRAS',
            @Msg,
            'TSQL',
            @ErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO
