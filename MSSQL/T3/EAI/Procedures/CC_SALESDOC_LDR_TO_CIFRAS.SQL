CREATE PROCEDURE EAI.CC_SALESDOC_LDR_TO_CIFRAS
(
      @pTruncate VARCHAR(1) = 'N'
    , @pOutput   BIT = 0
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @nProceso INT = 701;
    DECLARE @nPID BIGINT;
    DECLARE @dtStarting DATETIME = GETDATE();

    BEGIN TRY

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

        IF ISNULL(@pTruncate,'N')='Y'
        BEGIN
            TRUNCATE TABLE EAI.T3R_SALES_DOCS_OLD;
            TRUNCATE TABLE EAI.T3R_SALES_DOCS_LDR_MX01;
        END

        UPDATE EAI.CONTROL_REPORTE
        SET
            INICIO = GETDATE(),
            FIN = NULL
        WHERE REPORTE='LOAD CIFRAS VENTAS';

        /*
           Aquí se recomienda reemplazar completamente
           el cursor Oracle por operaciones SET-BASED.
        */

        UPDATE T2
        SET
            T2.Doc_TaxAmt = T1.Doc_TaxAmt,
            T2.Doc_Status = T1.Doc_Status
        FROM EAI.TAO_SALES_DOCS_LDR T1
        INNER JOIN EAI.T3R_SALES_DOCS_OLD T2
            ON T1.Doc_Num_R3=T2.Doc_Num_R3
        WHERE
            T2.Doc_Status='F'
            AND T1.Doc_TaxAmt>0
            AND T2.Doc_TaxAmt=0;

        UPDATE CONTROL_REPORTE
        SET FIN = GETDATE()
        WHERE REPORTE='LOAD CIFRAS VENTAS';

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET STATUS=1
        WHERE COMPONENT=@nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET
            FIN=GETDATE()
        WHERE PID=@nPID;

    END TRY
    BEGIN CATCH

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
            CREATED,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE,
            JOB_PID
        )
        VALUES
        (
            'CifrasControl',
            NULL,
            GETDATE(),
            'Error',
            'CC_SALESDOC_LDR_TO_CIFRAS',
            ERROR_MESSAGE(),
            'TSQL',
            ERROR_NUMBER(),
            @nPID
        );

        THROW;

    END CATCH

END
GO
