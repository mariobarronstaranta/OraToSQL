/*
    Procedimiento : EAI_OWNER.RECV_INVOICE_INTERCOMPANY
    Origen        : EAI_OWNER.RECV_TO_SEND_V3.RECV_INVOICE_INTERCOMPANY (Oracle)
    Proposito     : Coordinar facturas intercompany y ejecutar el proceso general
                    T3 al terminar el lote.

    Seleccion del lote
    ------------------
    Cola Invoice-Intercompany, ventana de cinco dias y Processed NULL.
    El componente asociado es 409.

    Flujo
    -----
    1. Valida instancia y bandera SalesForceOn.
    2. Delega cada factura permitida a SF_PROC_PREINVOICE_INTER.
    3. Cierra el componente y RF_PROCESOS_LOG.
    4. Ejecuta T3.PROC_T3_OT_GENERAL una vez terminado el lote.

    Dependencia posterior al lote
    ----------------------------
    T3.PROC_T3_OT_GENERAL esta definido sin parametros, por lo que su firma es
    compatible con esta llamada. OBJECT_ID se conserva para detectar un orden de
    despliegue incorrecto antes de ejecutar el paso final.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_INVOICE_INTERCOMPANY]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 409
        , @nRecords BIGINT = 0
        , @sSalesForceOn VARCHAR(30)
        , @nPID NUMERIC(10,0) = NULL
        , @sInstanceChk VARCHAR(5) = NULL
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Snapshot del lote para mantener una ejecucion estable y reproducible.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @sSalesForceOn = [EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn');
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

        -- Item reemplaza ROWNUM en la llamada al procedimiento SF.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'Invoice-Intercompany'
          AND R.CREATED > DATEADD(DAY, -5, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- Procesamiento fila por fila para conservar efectos y errores individuales.
        WHILE @i <= (SELECT COUNT_BIG(*) FROM @Records)
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;
            SET @sInstanceChk = [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName);

            IF @sInstanceChk = 'YES'
            BEGIN
                IF UPPER(@sSalesForceOn) = 'YES'
                    EXEC [EAI_OWNER].[SF_PROC_PREINVOICE_INTER]
                         @sRow_ID = @RowID, @nRowNum = @i, @nOutput = 0, @nPID = @nPID;
            END
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Cierra el componente antes de iniciar el proceso general T3.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;

        SET @sInstanceChk = 'T3';

        -- Falla de manera explicita si la dependencia aun no fue migrada.
        IF OBJECT_ID(N'[T3].[PROC_T3_OT_GENERAL]', N'P') IS NULL
            THROW 50021, 'Falta migrar el procedimiento T3.PROC_T3_OT_GENERAL.', 1;

        EXEC [T3].[PROC_T3_OT_GENERAL];
    END TRY
    BEGIN CATCH
        -- @sInstanceChk='T3' permite distinguir fallos del paso posterior al lote.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', @sInstanceChk, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_INVOICE_INTERCOMPANY',
             LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO
