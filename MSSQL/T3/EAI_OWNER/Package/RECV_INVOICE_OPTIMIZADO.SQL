/*
    Procedimiento: EAI_OWNER.RECV_INVOICE_OPTIMIZADO

    Ejecutar en la base destino seleccionada por el operador (sin USE fijo).
    Crea una version independiente; no modifica RECV_INVOICE ni el job 550.

    Optimizaciones conservadoras:
    - Cuenta el lote una sola vez, en lugar de agregarlo en cada iteracion.
    - Normaliza SalesForceOn una sola vez.
    - Incluye al final un bloque opcional para el indice de pendientes.

    Contrato conservado:
    - Cola Invoice, ventana desde medianoche de hace cinco dias, Processed NULL.
    - Orden CREATED, ROW_ID; mismo nRowNum y conteo de registros recorridos.
    - FN_CHECK_INSTANCE se evalua por mensaje, respetando cambios de configuracion
      durante la ejecucion; no se introduce una cache de permisos de instancia.
    - Mantiene SF_PROC_PREINVOICE_IFC como delegado. No activa automaticamente
      la version alternativa ni modifica transacciones, reintentos o estados.
    - Con SalesForceOn distinto de YES, aun cierra instancias rechazadas.
    - Conserva el contrato de errores y el identificador RECV_INVOICE en bitacora.

    Activacion tras validar en QA:
      Cambiar el paso del job de EXEC EAI_OWNER.RECV_INVOICE;
      a EXEC EAI_OWNER.RECV_INVOICE_OPTIMIZADO;
    Reversa: restaurar la llamada original. No ejecutar ambas versiones juntas.

    Validacion: comparar orden de llamadas, estados, PROCESO_4 y errores para
    lote vacio, instancias aceptadas/rechazadas y SalesForceOn YES/NO/NULL.
    Medir por separado seleccion del lote y procedimientos delegados.
    Este cambio no garantiza resolver esperas o lentitud dentro del delegado.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [EAI_OWNER].[RECV_INVOICE_OPTIMIZADO]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @nComponent INT = 405
        , @nRecords BIGINT = 0
        , @TotalRecords BIGINT = 0
        , @sSalesForceOn VARCHAR(30)
        , @nPID NUMERIC(10,0) = NULL
        , @i BIGINT = 1
        , @RowID VARCHAR(32)
        , @InstanceName VARCHAR(300);

    -- Lote fijo que reemplaza el cursor implícito del package Oracle.
    DECLARE @Records TABLE
    (
          Item BIGINT PRIMARY KEY
        , Row_ID VARCHAR(32) NOT NULL
        , InstanceName VARCHAR(300) NULL
    );

    BEGIN TRY
        EXEC [EAI_OWNER].[LOG_START] @nComponent = @nComponent;
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
        SET @sSalesForceOn = UPPER([EAI_OWNER].[GETCONV]('CFG Settings', 'SalesForceOn'));

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, PROCESO, FECHA_PROC_BATMD, INICIO)
        VALUES (@nPID, @nComponent, NULL, SYSDATETIME());

        -- El numero de fila se utiliza como nRowNum en el procedimiento delegado.
        INSERT INTO @Records (Item, Row_ID, InstanceName)
        SELECT ROW_NUMBER() OVER (ORDER BY R.CREATED, R.ROW_ID), R.ROW_ID,
               R.XML_CONTENT.value('(/*/Header/Sender/System/SystemName/text())[1]', 'varchar(300)')
        FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS R
        WHERE R.QUEUE_NAME = 'Invoice'
          AND R.CREATED > DATEADD(DAY, -5, CONVERT(DATETIME2(0), CONVERT(DATE, SYSDATETIME())))
          AND R.PROCESSED IS NULL;

        -- El lote permanece fijo: contar una sola vez evita repetir la agregacion.
        SELECT @TotalRecords = COUNT_BIG(*) FROM @Records;

        -- La delegacion individual aisla el estado de cada factura.
        WHILE @i <= @TotalRecords
        BEGIN
            SELECT @RowID = Row_ID, @InstanceName = InstanceName
            FROM @Records WHERE Item = @i;

            SET @nRecords += 1;

            IF [EAI_OWNER].[FN_CHECK_INSTANCE](@InstanceName) = 'YES'
            BEGIN
                IF @sSalesForceOn = 'YES'
                    EXEC [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
                         @sRow_ID = @RowID, @nRowNum = @i, @nOutput = 0, @nPID = @nPID;
            END
            ELSE
                UPDATE [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
                   SET STATUS = 'PI Issue', PROCESSED = SYSDATETIME()
                 WHERE ROW_ID = @RowID;

            SET @i += 1;
        END;

        -- Marca disponible el componente y conserva metricas del lote.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET STATUS = 1 WHERE COMPONENT = @nComponent;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET FIN = SYSDATETIME(), PROCESO_1 = 0, PROCESO_2 = 0,
               PROCESO_3 = 0, PROCESO_4 = @nRecords
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- Error general del job; los detalles por factura pertenecen al delegado.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
             QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
             RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', NULL, SYSDATETIME(), NULL, @nPID, 'Error',
             'RECV_INVOICE', LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250),
             'T-SQL', CONCAT('MSSQL-', ERROR_NUMBER()), NULL, NULL, NULL);
    END CATCH;
END;
GO

/* Opcional: cambiar a 1 despues de revisar indices y plan en la base destino.
   La creacion puede consumir tiempo, espacio y bloquear otras sesiones.
   No se incluye XML_CONTENT para evitar ampliar el indice con los documentos.
   PROCESSED se incluye para permitir el uso del filtro IS NULL.
   No se eliminan indices existentes. El indice tambien beneficia al original.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO
DECLARE @CrearIndicePendientes BIT = 0;

IF @CrearIndicePendientes = 1
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes AS I
        WHERE I.object_id = OBJECT_ID(N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG')
          AND I.type IN (1, 2)
          AND I.is_disabled = 0
          AND I.is_hypothetical = 0
          AND I.has_filter = 1
          AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
              UPPER(I.filter_definition), N'[', N''), N']', N''),
              N'(', N''), N')', N''), N' ', N''), CHAR(9), N'')
              = N'PROCESSEDISNULL'
          AND EXISTS
          (
              SELECT 1 FROM sys.index_columns AS IC
              INNER JOIN sys.columns AS C
                ON C.object_id = IC.object_id AND C.column_id = IC.column_id
              WHERE IC.object_id = I.object_id AND IC.index_id = I.index_id
                AND IC.key_ordinal = 1 AND C.name = N'QUEUE_NAME'
          )
          AND EXISTS
          (
              SELECT 1 FROM sys.index_columns AS IC
              INNER JOIN sys.columns AS C
                ON C.object_id = IC.object_id AND C.column_id = IC.column_id
              WHERE IC.object_id = I.object_id AND IC.index_id = I.index_id
                AND IC.key_ordinal = 2 AND C.name = N'CREATED'
                AND IC.is_descending_key = 0
          )
          AND EXISTS
          (
              SELECT 1 FROM sys.index_columns AS IC
              INNER JOIN sys.columns AS C
                ON C.object_id = IC.object_id AND C.column_id = IC.column_id
              WHERE IC.object_id = I.object_id AND IC.index_id = I.index_id
                AND IC.key_ordinal = 3 AND C.name = N'ROW_ID'
                AND IC.is_descending_key = 0
          )
          AND EXISTS
          (
              SELECT 1 FROM sys.index_columns AS IC
              INNER JOIN sys.columns AS C
                ON C.object_id = IC.object_id AND C.column_id = IC.column_id
              WHERE IC.object_id = I.object_id AND IC.index_id = I.index_id
                AND C.name = N'PROCESSED'
          )
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG')
              AND name = N'IX_MX_RECEIVE_PENDING'
        )
            THROW 51820, 'IX_MX_RECEIVE_PENDING existe con otra definicion o estado. Revisarlo antes de continuar.', 1;

        CREATE NONCLUSTERED INDEX IX_MX_RECEIVE_PENDING
        ON EAI_OWNER.MX_RECEIVE_MESSAGE_LOG (QUEUE_NAME, CREATED, ROW_ID)
        INCLUDE (PROCESSED)
        WHERE PROCESSED IS NULL;
    END;
END;
GO

