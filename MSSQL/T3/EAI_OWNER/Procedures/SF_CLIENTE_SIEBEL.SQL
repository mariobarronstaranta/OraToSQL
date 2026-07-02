CREATE OR ALTER PROCEDURE dbo.SF_CLIENTE_SIEBEL
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID            VARCHAR(50),
        @sErrorCode      VARCHAR(30),
        @sMsg            VARCHAR(300),
        @nPID            BIGINT,
        @nProceso        INT,
        @nProceso1       INT,
        @nProceso2       INT,
        @nProceso4       INT;

    BEGIN TRY

        SET @nProceso = 816;

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

        SET @nProceso1 = 0;
        SET @nProceso2 = 0;

        BEGIN TRANSACTION;

        -----------------------------------------------------
        -- Inicio Reporte
        -----------------------------------------------------

        UPDATE CONTROL_REPORTE
           SET Inicio = GETDATE(),
               Fin = NULL
         WHERE REPORTE = 'REPORTE CLIENTE_SIEBEL';

        -----------------------------------------------------
        -- Recarga completa
        -----------------------------------------------------

        TRUNCATE TABLE EAI.CLIENTE_SIEBEL;

        INSERT INTO EAI.CLIENTE_SIEBEL
        (
            Cliente_V3,
            Cliente_SAP,
            Dias_Cdto,
            RFC,
            Lista_IVA,
            Lista_Precio,
            Territorio,
            Tipo_Territorio,
            Territorio_Delivery,
            Tipo_Territorio_Delivery,
            Dist_Cobza,
            Forma_Pago,
            Canal
        )
        SELECT
            MC.Cliente_V3,
            MC.Cliente_SAP,
            COALESCE(MC.Dias_Cdto,0),
            MC.RFC,
            MC.Lista_IVA,
            MC.Lista_Precio,
            MC.Territorio,
            MC.Tipo_Territorio,
            MC.Territorio,
            MC.Tipo_Territorio,
            '00',
            CASE
                WHEN PC.Branch_Number IS NOT NULL
                     THEN 'Pago Central'
                WHEN AD.RFC IS NOT NULL
                     THEN 'Pago Central'
                ELSE 'Pago Directo'
            END,
            '00'
        FROM T3.MOV_CLIENTE MC

        LEFT JOIN
        (
            SELECT DISTINCT
                   BRANCH_NUMBER
            FROM EAI.TAO_CARTERA_SAP_LDR
            WHERE BRANCH_NUMBER IS NOT NULL
        ) PC
            ON MC.Cliente_SAP = PC.Branch_Number

        LEFT JOIN T3.CFDI_ADDENDA AD
            ON MC.RFC = AD.RFC

        WHERE MC.Cliente_SAP IS NOT NULL
          AND LEN(MC.Cliente_SAP) = 10
          AND
          (
              COALESCE(MC.Siebel_Loc,MC.Cliente_V3)
                  <> MC.Cliente_V3
              OR
              MC.Fecha_Syncr >
                  CAST('2020-09-21' AS DATE)
          );

        SET @nProceso4 = @@ROWCOUNT;

        -----------------------------------------------------
        -- Fin Reporte
        -----------------------------------------------------

        UPDATE CONTROL_REPORTE
           SET Fin = GETDATE()
         WHERE REPORTE = 'REPORTE CLIENTE_SIEBEL';

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin        = GETDATE(),
               Proceso_1  = @nProceso1,
               Proceso_2  = @nProceso2,
               Proceso_3  = 0,
               Proceso_4  = @nProceso4
         WHERE PID = @nPID;

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(
                CONCAT(
                    ERROR_NUMBER(),
                    '-',
                    ERROR_MESSAGE()
                ),
                250
            );

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
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'SF_CLIENTE_SIEBEL',
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