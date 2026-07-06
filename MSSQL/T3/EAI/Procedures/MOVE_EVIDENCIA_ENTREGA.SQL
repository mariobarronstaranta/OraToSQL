CREATE OR ALTER PROCEDURE EAI.MOVE_EVIDENCIA_ENTREGA
(
      @nDias NUMERIC(10,0) = 30
)
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @v_ID           VARCHAR(50);
    DECLARE @sMsg           VARCHAR(500);
    DECLARE @sErrorCode     VARCHAR(20);

    DECLARE @nPID           NUMERIC(8,0);
    DECLARE @nProceso       NUMERIC(8,0);

    DECLARE @nProceso1      NUMERIC(8,0)=0;
    DECLARE @nProceso2      NUMERIC(8,0)=0;
    DECLARE @nProceso3      NUMERIC(8,0)=0;
    DECLARE @nProceso4      NUMERIC(8,0)=0;

    BEGIN TRY

        BEGIN TRAN;

        SET @nProceso = 929;

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

        ;WITH ScrEvidencia AS
        (
            SELECT
                Ldr.ItemInternalId,
                Ldr.Fecha,
                Ldr.Tienda,
                Ldr.Folio_Recepcion,
                Ldr.Volumen_Ticket,
                Ldr.Volumen_Nota,
                Ldr.Folio_Interno,
                Ldr.CoincideVolumen,
                ISNULL(Hist.Folio_Interno,'INSERT') AS Insert_Hist,
                Suc.Entrega,
                Suc.Cliente_SAP,
                Suc.X_EM_Field_5,
                ISNULL(IFC.Var_1,'INSERT') AS Insert_IFC
            FROM EAI.LDR_EVIDENCIAS_ENTREGA Ldr
            LEFT JOIN EAI.HIST_EVIDENCIAS_ENTREGA Hist
                ON Hist.Folio_Interno = Ldr.Folio_Interno
            LEFT JOIN EAI.IFC_Folios_FE IFC
                ON IFC.Var_1 = Ldr.Folio_Interno
            LEFT JOIN
            (
                SELECT
                    FG.Factura,
                    FG.Cliente_SAP,
                    FG.Entrega,
                    Suc.X_EM_Field_5
                FROM T3.FACTURA_GENERAL FG
                LEFT JOIN T3.TMD_EMAIL Suc
                    ON FG.Cliente_SAP = Suc.Cliente_SAP
                WHERE FG.Fecha_Trn >
                      DATEADD(DAY,-ISNULL(@nDias,90),GETDATE())

                UNION

                SELECT
                    PG.Factura,
                    PG.Cliente_SAP,
                    PG.Entrega,
                    Suc.X_EM_Field_5
                FROM T3.PREVENTA_GENERAL PG
                LEFT JOIN T3.TMD_EMAIL Suc
                    ON PG.Cliente_SAP = Suc.Cliente_SAP
                WHERE PG.Fecha_Trn >
                      DATEADD(DAY,-ISNULL(@nDias,90),GETDATE())
                  AND PG.Clase_Factura IN ('C005','C006')
            ) Suc
                ON Suc.Factura = Ldr.Folio_Interno
        )

        INSERT INTO EAI.HIST_EVIDENCIAS_ENTREGA
        (
            ItemInternalId,
            Fecha,
            Tienda,
            Folio_Recepcion,
            Volumen_Ticket,
            Folio_Interno,
            Volumen_Nota,
            CoincideVolumen,
            INSERT_TS
        )
        SELECT
            ItemInternalId,
            Fecha,
            Tienda,
            Folio_Recepcion,
            Volumen_Ticket,
            Folio_Interno,
            Volumen_Nota,
            CoincideVolumen,
            GETDATE()
        FROM ScrEvidencia
        WHERE Insert_Hist='INSERT';

        SET @nProceso1 = @@ROWCOUNT;

        UPDATE H
        SET UPDATE_TS = GETDATE()
        FROM EAI.HIST_EVIDENCIAS_ENTREGA H
        INNER JOIN ScrEvidencia S
            ON S.Folio_Interno = H.Folio_Interno
        WHERE S.Insert_Hist <> 'INSERT';

        SET @nProceso2 = @@ROWCOUNT;

        INSERT INTO EAI.IFC_Folios_FE
        (
            Row_ID,
            Entrada,
            CreadoPor,
            Creacion,
            Var_1
        )
        SELECT
            Entrega,
            Folio_Recepcion,
            'MODULE',
            GETDATE(),
            Folio_Interno
        FROM ScrEvidencia
        WHERE UPPER(CoincideVolumen)='SI'
          AND Entrega IS NOT NULL
          AND Insert_IFC='INSERT';

        SET @nProceso3 = @@ROWCOUNT;

        UPDATE T
        SET X_EM_Field_5 = S.Tienda
        FROM T3.TMD_EMAIL T
        INNER JOIN ScrEvidencia S
            ON S.Cliente_SAP = T.Cliente_SAP
        WHERE UPPER(S.CoincideVolumen)='SI'
          AND S.Cliente_SAP IS NOT NULL
          AND S.Tienda IS NOT NULL
          AND S.X_EM_Field_5 IS NULL;

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET Fin        = GETDATE(),
            Proceso_1  = @nProceso1,
            Proceso_2  = @nProceso2,
            Proceso_3  = @nProceso3,
            Proceso_4  = @nProceso4
        WHERE PID = @nPID;

        COMMIT;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

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
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'MOVE_EVIDENCIA_ENTREGA',
            @sMsg,
            'TSQL',
            @sErrorCode
        );

    END CATCH

END;
GO