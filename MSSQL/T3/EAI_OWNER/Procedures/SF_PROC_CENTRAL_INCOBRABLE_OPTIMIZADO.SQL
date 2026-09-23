/*
    Despliegue de EAI_OWNER.SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO.

    Esta version convive con el procedimiento original. No cambie el job 889
    hasta completar las pruebas funcionales y de rendimiento descritas en
    SF_PROC_CENTRAL_INCOBRABLE_NOTES.MD.

    El archivo incluye indices idempotentes requeridos por la nueva estrategia.
    Su creacion puede consumir espacio y bloquear durante el despliegue; debe
    ejecutarse en una ventana controlada por el DBA.
*/
USE [T3QA];
GO

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

/* Preflight: evita crear un procedimiento que falle posteriormente porque el
   ambiente no contiene todos los objetos requeridos. */
IF SCHEMA_ID(N'EAI_OWNER') IS NULL
    THROW 51701, 'No existe el esquema EAI_OWNER.', 1;
IF SCHEMA_ID(N'T3') IS NULL
    THROW 51702, 'No existe el esquema T3.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[ProcessID]', N'SO') IS NULL
    THROW 51703, 'No existe la secuencia EAI_OWNER.ProcessID.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[LOG_START]', N'P') IS NULL
    THROW 51704, 'No existe EAI_OWNER.LOG_START.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[SF_GET_INVOICE_DATA]', N'P') IS NULL
    THROW 51705, 'No existe EAI_OWNER.SF_GET_INVOICE_DATA.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[SF_GET_CREDIT_DATA]', N'P') IS NULL
    THROW 51706, 'No existe EAI_OWNER.SF_GET_CREDIT_DATA.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]', N'U') IS NULL
    THROW 51707, 'No existe EAI_OWNER.TMP_ACCOUNT_HEADER.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TMP_INCO_HEADER]', N'U') IS NULL
    THROW 51708, 'No existe EAI_OWNER.TMP_INCO_HEADER.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[TRACE_EAI_OWNER]', N'U') IS NULL
    THROW 51709, 'No existe EAI_OWNER.TRACE_EAI_OWNER.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[MX_COMPONENTS]', N'U') IS NULL
    THROW 51710, 'No existe EAI_OWNER.MX_COMPONENTS.', 1;
IF OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]', N'U') IS NULL
    THROW 51711, 'No existe EAI_OWNER.MX_EAI_MESSAGE_LOG.', 1;
IF OBJECT_ID(N'[T3].[MOV_CLIENTE]', N'U') IS NULL
    THROW 51712, 'No existe T3.MOV_CLIENTE.', 1;
IF OBJECT_ID(N'[T3].[PAGO]', N'U') IS NULL
    THROW 51713, 'No existe T3.PAGO.', 1;
IF OBJECT_ID(N'[T3].[ASIGNACION_PAGO]', N'U') IS NULL
    THROW 51714, 'No existe T3.ASIGNACION_PAGO.', 1;
IF OBJECT_ID(N'[T3].[RF_PROCESOS_LOG]', N'U') IS NULL
    THROW 51715, 'No existe T3.RF_PROCESOS_LOG.', 1;
GO

/* Cubre la seleccion del lote y la lectura de sus IDocs. */
IF OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
         AND name = N'IX_TMP_ACCOUNT_HEADER_INCO_PROCESS'
   )
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TMP_ACCOUNT_HEADER_INCO_PROCESS]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [CLEARINGDOCNUMBER], [CREATED], [CLEARINGDATE]
    )
    INCLUDE
    (
        [IDOCNUMBER], [CUSTOMERNUMBER], [AMOUNTDOCCURRENCY],
        [REFERENCEDOCNUMBER], [STATUS], [PROCESSED]
    );
END;
GO

/* Cubre ROW_NUMBER/COUNT usados para localizar la referencia duplicada mayor. */
IF OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
         AND name = N'IX_TMP_ACCOUNT_HEADER_INCO_DUPLICATE'
   )
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TMP_ACCOUNT_HEADER_INCO_DUPLICATE]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [CLEARINGDOCNUMBER], [CLEARINGDATE],
        [REFERENCEDOCNUMBER], [IDOCNUMBER]
    );
END;
GO

/* Acelera la deteccion y actualizacion de encabezados ya procesados. */
IF OBJECT_ID(N'[EAI_OWNER].[TMP_INCO_HEADER]', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_INCO_HEADER]')
         AND name = N'IX_TMP_INCO_HEADER_DOCUMENT_DATE'
   )
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TMP_INCO_HEADER_DOCUMENT_DATE]
    ON [EAI_OWNER].[TMP_INCO_HEADER]
    (
        [CLEARINGDOCNUMBER], [CLEARINGDATE]
    )
    INCLUDE ([LAST_UPDATED], [PROCESSED], [RECORDS]);
END;
GO

/* El repositorio no contenia un indice para el join por Cliente_SAP. */
IF OBJECT_ID(N'[T3].[MOV_CLIENTE]', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'[T3].[MOV_CLIENTE]')
         AND name = N'IX_MOV_CLIENTE_CLIENTE_SAP_INCO'
   )
BEGIN
    CREATE NONCLUSTERED INDEX [IX_MOV_CLIENTE_CLIENTE_SAP_INCO]
    ON [T3].[MOV_CLIENTE] ([CLIENTE_SAP])
    INCLUDE ([CLIENTE_V3], [CTRO], [DIST_VENTA], [RFC]);
END;
GO

CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO]
(
    @nDays              INT         = 28,
    @sClearingDocument  VARCHAR(30) = 'EMPTY',
    @nInsert            INT         = 0,
    @pOutput            INT         = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @nDays IS NULL OR @nDays < 0
        THROW 51700, '@nDays debe ser mayor o igual que cero.', 1;

    DECLARE
        @Now                    DATETIME2(0) = SYSDATETIME(),
        @FromDate               DATE,
        @Cutoff                 DATETIME2(0),
        @ClearingFilter         VARCHAR(30),
        @sMsg                   VARCHAR(500),
        @v_ID                   VARCHAR(30),
        @sErrorCode             VARCHAR(20),
        @sReferenceID           VARCHAR(40),
        @sClearingDocNumber     VARCHAR(20),
        @sPago_ID               VARCHAR(20),
        @nDocuments             INT = 0,
        @nRecords               INT = 0,
        @nInserts               INT = 0,
        @nValor_Pago            DECIMAL(15,4),
        @dtFecha_Asignacion     DATE,
        @nMontoMaximo           DECIMAL(15,4) = 500000,
        @nPID                   BIGINT,
        @nProceso               INT = 888,
        @sInvDoc_Num            VARCHAR(30),
        @sInvCustomer           VARCHAR(30),
        @nInvAmount             DECIMAL(15,2),
        @nInvPending            DECIMAL(15,2),
        @nPaid                  DECIMAL(15,2),
        @sNCDoc_Num             VARCHAR(30),
        @sNCCustomer            VARCHAR(30),
        @nNCAmount              DECIMAL(15,2),
        @nNCPending             DECIMAL(15,2),
        @nNCPaid                DECIMAL(15,2),
        @sCliente_SAP           VARCHAR(30),
        @sCtro                  VARCHAR(30),
        @sCliente_V3            VARCHAR(30),
        @nDistribuidor          INT,
        @Det_IdocNumber         VARCHAR(30),
        @Det_ClearingDocNumber  VARCHAR(20),
        @Det_Cliente_SAP        VARCHAR(30),
        @Det_AmountDocCurrency DECIMAL(15,4),
        @Det_ClearingDate       VARCHAR(20),
        @Det_ReferenceDocNumber VARCHAR(40);

    SET @FromDate = DATEADD(DAY, -@nDays, CAST(@Now AS DATE));
    SET @Cutoff = DATEADD(HOUR, -2, @Now);
    SET @ClearingFilter = NULLIF(LTRIM(RTRIM(@sClearingDocument)), '');
    IF @ClearingFilter = 'EMPTY' SET @ClearingFilter = NULL;

    CREATE TABLE #Groups
    (
        ClearingDocNumber VARCHAR(20) NOT NULL,
        ClearingDate      VARCHAR(20) NOT NULL,
        IdocCount         INT NOT NULL,
        ProcessGroup      BIT NOT NULL DEFAULT (0),
        PRIMARY KEY (ClearingDocNumber, ClearingDate)
    );

    CREATE TABLE #WorkItems
    (
        WorkId            BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdocNumber        VARCHAR(30) NULL,
        ClearingDocNumber VARCHAR(20) NOT NULL,
        CustomerNumber    VARCHAR(30) NULL,
        AmountDocCurrency DECIMAL(15,4) NULL,
        ClearingDate      VARCHAR(20) NOT NULL,
        ReferenceDocNumber VARCHAR(40) NULL
    );

    CREATE TABLE #Trace
    (
        TraceId         BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        Created         DATETIME2(0) NOT NULL,
        ObjectReference VARCHAR(50) NULL,
        Description     VARCHAR(1000) NULL
    );

    /* Se materializa el conjunto una sola vez y fuera de la transaccion. La
       opcion RECOMPILE permite adaptar el plan al numero de dias y al filtro. */
    INSERT INTO #Groups (ClearingDocNumber, ClearingDate, IdocCount)
    SELECT
        A.ClearingDocNumber,
        A.ClearingDate,
        COUNT(A.IdocNumber)
    FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS A
    WHERE A.Created > @FromDate
      AND A.Created < @Cutoff
      AND A.ClearingDocNumber LIKE '11%'
      AND (@ClearingFilter IS NULL OR A.ClearingDocNumber = @ClearingFilter)
      AND A.ClearingDocNumber IS NOT NULL
      AND A.ClearingDate IS NOT NULL
    GROUP BY A.ClearingDocNumber, A.ClearingDate
    OPTION (RECOMPILE);

    SELECT @nDocuments = COUNT(*) FROM #Groups;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES (@nPID, @nProceso, NULL, @Now);

        IF @pOutput > 0
            INSERT #Trace (Created, ObjectReference, Description)
            VALUES
            (
                @Now,
                CONCAT
                (
                    CONVERT(CHAR(8), @Now, 112),
                    REPLACE(CONVERT(CHAR(5), @Now, 108), ':', '')
                ),
                'Begin'
            );

        /* Los grupos existentes se tocan una sola vez y no se reprocesan. */
        UPDATE H
           SET H.Last_Updated = @Now
        FROM [EAI_OWNER].[TMP_INCO_HEADER] AS H
        INNER JOIN #Groups AS G
            ON G.ClearingDocNumber = H.ClearingDocNumber
           AND G.ClearingDate = H.ClearingDate;

        /* HOLDLOCK protege la decision de alta durante esta transaccion. El
           indice document/date evita un recorrido completo de la tabla. */
        UPDATE G
           SET ProcessGroup = 1
        FROM #Groups AS G
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM [EAI_OWNER].[TMP_INCO_HEADER] AS H WITH (UPDLOCK, HOLDLOCK)
            WHERE H.ClearingDocNumber = G.ClearingDocNumber
              AND H.ClearingDate = G.ClearingDate
        );

        /* Conserva las restricciones que imponian el INSERT y TO_DATE del
           flujo original, pero devuelve errores reconocibles. */
        IF EXISTS
        (
            SELECT 1 FROM #Groups
            WHERE ProcessGroup = 1 AND LEN(ClearingDocNumber) > 10
        )
            THROW 51716, 'ClearingDocNumber excede los 10 caracteres permitidos por TMP_INCO_HEADER.', 1;

        IF EXISTS
        (
            SELECT 1 FROM #Groups
            WHERE ProcessGroup = 1 AND IdocCount > 999999
        )
            THROW 51717, 'La cantidad de IDocs excede la capacidad de TMP_INCO_HEADER.RECORDS.', 1;

        IF EXISTS
        (
            SELECT 1 FROM #Groups
            WHERE ProcessGroup = 1
              AND TRY_CONVERT(DATE, ClearingDate, 112) IS NULL
        )
            THROW 51718, 'ClearingDate no contiene una fecha valida con formato YYYYMMDD.', 1;

        INSERT INTO [EAI_OWNER].[TMP_INCO_HEADER]
            (ClearingDocNumber, ClearingDate, Created, Records)
        SELECT ClearingDocNumber, ClearingDate, @Now, IdocCount
        FROM #Groups
        WHERE ProcessGroup = 1;

        /* Marca en una sola operacion solamente el IdocNumber mayor por cada
           referencia repetida, conservando la regla funcional de Oracle. */
        ;WITH Ranked AS
        (
            SELECT
                A.ClearingDocNumber,
                A.ClearingDate,
                A.ReferenceDocNumber,
                A.IdocNumber,
                COUNT(A.IdocNumber) OVER
                (
                    PARTITION BY A.ClearingDocNumber, A.ClearingDate,
                                 A.ReferenceDocNumber
                ) AS ReferenceCount,
                ROW_NUMBER() OVER
                (
                    PARTITION BY A.ClearingDocNumber, A.ClearingDate,
                                 A.ReferenceDocNumber
                    ORDER BY A.IdocNumber DESC
                ) AS DuplicateOrder
            FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS A
            INNER JOIN #Groups AS G
                ON G.ClearingDocNumber = A.ClearingDocNumber
               AND G.ClearingDate = A.ClearingDate
               AND G.ProcessGroup = 1
            WHERE A.ReferenceDocNumber IS NOT NULL
        )
        UPDATE A
           SET A.Status = 'Duplicated', A.Processed = @Now
        FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS A
        INNER JOIN Ranked AS R
            ON R.ClearingDocNumber = A.ClearingDocNumber
           AND R.ClearingDate = A.ClearingDate
           AND R.ReferenceDocNumber = A.ReferenceDocNumber
           AND R.IdocNumber = A.IdocNumber
        WHERE R.ReferenceCount > 1
          AND R.DuplicateOrder = 1;

        /* El INNER JOIN conserva la regla que excluye clientes sin Mov_Cliente.
           Se usa la misma ventana en grupos y detalle para evitar incorporar
           filas nuevas después de haber formado el lote. */
        INSERT INTO #WorkItems
        (
            IdocNumber, ClearingDocNumber, CustomerNumber,
            AmountDocCurrency, ClearingDate, ReferenceDocNumber
        )
        SELECT
            A.IdocNumber, A.ClearingDocNumber, A.CustomerNumber,
            A.AmountDocCurrency, A.ClearingDate, A.ReferenceDocNumber
        FROM [EAI_OWNER].[TMP_ACCOUNT_HEADER] AS A
        INNER JOIN #Groups AS G
            ON G.ClearingDocNumber = A.ClearingDocNumber
           AND G.ClearingDate = A.ClearingDate
           AND G.ProcessGroup = 1
        INNER JOIN [T3].[MOV_CLIENTE] AS MC
            ON MC.Cliente_SAP = A.CustomerNumber
        WHERE A.Created > @FromDate
          AND A.Created < @Cutoff
          AND (A.Status IS NULL OR A.Status <> 'Duplicated');

        /* Se conserva un solo cursor porque las rutinas SF_GET_* devuelven
           parametros escalares y la decision factura/credito es secuencial. */
        DECLARE curWorkItems CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                IdocNumber, ClearingDocNumber, CustomerNumber,
                AmountDocCurrency, ClearingDate, ReferenceDocNumber
            FROM #WorkItems
            ORDER BY ClearingDate, ClearingDocNumber, IdocNumber, WorkId;

        OPEN curWorkItems;
        FETCH NEXT FROM curWorkItems INTO
            @Det_IdocNumber, @Det_ClearingDocNumber, @Det_Cliente_SAP,
            @Det_AmountDocCurrency, @Det_ClearingDate,
            @Det_ReferenceDocNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @v_ID = @Det_ClearingDocNumber;
            SET @sClearingDocNumber = @Det_ClearingDocNumber;
            SET @dtFecha_Asignacion = CONVERT(DATE, @Det_ClearingDate, 112);
            SET @sPago_ID = CONCAT('11', @Det_IdocNumber);
            SET @sReferenceID = @Det_ReferenceDocNumber;
            SET @nValor_Pago = @Det_AmountDocCurrency;
            SET @nRecords += 1;

            IF @pOutput > 1
                INSERT #Trace (Created, ObjectReference, Description)
                VALUES
                (
                    SYSDATETIME(), @sClearingDocNumber,
                    CONCAT(@sReferenceID, ',', @Det_Cliente_SAP, ',',
                           @nValor_Pago, ' (', @Det_IdocNumber, ')')
                );

            IF @nValor_Pago < @nMontoMaximo
            BEGIN
                SELECT
                    @sInvDoc_Num = NULL, @sInvCustomer = NULL,
                    @nInvAmount = 0, @nInvPending = 0, @nPaid = 0;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @sReferenceID, @sInvDoc_Num OUTPUT,
                    @sInvCustomer OUTPUT, @nInvAmount OUTPUT,
                    @nInvPending OUTPUT, @nPaid OUTPUT;

                IF COALESCE(@nInvAmount, 0) > 0
                BEGIN
                    IF @pOutput > 1
                        INSERT #Trace (Created, ObjectReference, Description)
                        VALUES
                        (
                            SYSDATETIME(), @sClearingDocNumber,
                            CONCAT(COALESCE(@sInvDoc_Num, @sReferenceID),
                                   ' pendiente ', @nInvPending)
                        );

                    IF COALESCE(@nInvPending, 0) >= @nValor_Pago
                    BEGIN
                        SET @nInserts += 1;

                        IF @nInsert > 0
                        BEGIN
                            SELECT
                                @sCliente_SAP = @sInvCustomer,
                                @sCliente_V3 = NULL,
                                @sCtro = NULL,
                                @nDistribuidor = NULL;

                            SELECT TOP (1)
                                @sCliente_V3 = MC.Cliente_V3,
                                @sCtro = MC.Ctro,
                                @nDistribuidor = MC.Dist_Venta
                            FROM [T3].[MOV_CLIENTE] AS MC
                            WHERE MC.Cliente_SAP = @sCliente_SAP;

                            INSERT INTO [T3].[PAGO]
                            (
                                Pago_ID, Fecha_Trn, Distribuidor, Fecha_Pago,
                                Cliente_V3, Cliente_SAP, Rep_ID, Tipo_Pago,
                                Metodo_Pago, Valor_Pago, Ctro
                            )
                            VALUES
                            (
                                @sPago_ID, @Now, @nDistribuidor,
                                @dtFecha_Asignacion, @sCliente_V3,
                                @sCliente_SAP, 'CENTRAL', 'PAYMENT', 'I',
                                @nValor_Pago, @sCtro
                            );

                            INSERT INTO [T3].[ASIGNACION_PAGO]
                            (
                                Pago_ID, Asignacion_ID, Fecha_Trn, Factura,
                                Distribuidor, Ctro, Cliente_V3, Cliente_SAP,
                                Rep_ID, Fecha_Asignacion, Valor_Pago
                            )
                            VALUES
                            (
                                @sPago_ID, @sPago_ID, @Now, @sInvDoc_Num,
                                @nDistribuidor, @sCtro, @sCliente_V3,
                                @sCliente_SAP, 'CENTRAL',
                                @dtFecha_Asignacion, @nValor_Pago
                            );

                            UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                               SET Status = 'Processed', Processed = @Now
                             WHERE IdocNumber = @Det_IdocNumber
                               AND Status IS NULL;
                        END;

                        IF @pOutput > 1
                            INSERT #Trace (Created, ObjectReference, Description)
                            VALUES (SYSDATETIME(), @sClearingDocNumber,
                                    CONCAT(@sInvDoc_Num, ' -> Procesado'));
                    END
                    ELSE
                    BEGIN
                        UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                           SET Status = 'Discarded', Processed = @Now
                         WHERE IdocNumber = @Det_IdocNumber
                           AND Status IS NULL;

                        IF @pOutput > 1
                            INSERT #Trace (Created, ObjectReference, Description)
                            VALUES (SYSDATETIME(), @sClearingDocNumber,
                                    CONCAT(@sInvDoc_Num, ' -> Discarded'));
                    END;
                END
                ELSE
                BEGIN
                    SELECT
                        @sNCDoc_Num = NULL, @sNCCustomer = NULL,
                        @nNCAmount = 0, @nNCPending = 0, @nNCPaid = 0;

                    EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                        @sReferenceID, @sNCDoc_Num OUTPUT,
                        @sNCCustomer OUTPUT, @nNCAmount OUTPUT,
                        @nNCPending OUTPUT, @nNCPaid OUTPUT;

                    IF @pOutput > 1
                        INSERT #Trace (Created, ObjectReference, Description)
                        VALUES
                        (
                            SYSDATETIME(), @sClearingDocNumber,
                            CONCAT(COALESCE(@sNCDoc_Num, @sReferenceID),
                                   ' pendiente ', @nNCPending)
                        );

                    IF COALESCE(@nNCAmount, 0) > 0
                    BEGIN
                        IF COALESCE(@nNCPending, 0) >= @nValor_Pago
                        BEGIN
                            SET @nInserts += 1;

                            IF @nInsert > 0
                            BEGIN
                                SELECT
                                    @sCliente_SAP = @sNCCustomer,
                                    @sCliente_V3 = NULL,
                                    @sCtro = NULL,
                                    @nDistribuidor = NULL;

                                SELECT TOP (1)
                                    @sCliente_V3 = MC.Cliente_V3,
                                    @sCtro = MC.Ctro,
                                    @nDistribuidor = MC.Dist_Venta
                                FROM [T3].[MOV_CLIENTE] AS MC
                                WHERE MC.Cliente_SAP = @sCliente_SAP;

                                INSERT INTO [T3].[ASIGNACION_PAGO]
                                (
                                    Pago_ID, Asignacion_ID, Fecha_Trn,
                                    Factura, Nota_Credito, Distribuidor,
                                    Ctro, Cliente_V3, Cliente_SAP, Rep_ID,
                                    Fecha_Asignacion, Valor_Pago
                                )
                                VALUES
                                (
                                    @sPago_ID, @sPago_ID, @Now,
                                    'INCOBRABLE', @sNCDoc_Num,
                                    @nDistribuidor, @sCtro, @sCliente_V3,
                                    @sCliente_SAP, 'CENTRAL',
                                    @dtFecha_Asignacion, @nValor_Pago
                                );

                                UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                                   SET Status = 'Processed', Processed = @Now
                                 WHERE IdocNumber = @Det_IdocNumber
                                   AND Status IS NULL;
                            END;

                            IF @pOutput > 1
                                INSERT #Trace (Created, ObjectReference, Description)
                                VALUES (SYSDATETIME(), @sClearingDocNumber,
                                        CONCAT(@sNCDoc_Num, ' -> Procesado'));
                        END
                        ELSE
                        BEGIN
                            UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                               SET Status = 'Discarded', Processed = @Now
                             WHERE IdocNumber = @Det_IdocNumber
                               AND Status IS NULL;

                            IF @pOutput > 1
                                INSERT #Trace (Created, ObjectReference, Description)
                                VALUES (SYSDATETIME(), @sClearingDocNumber,
                                        CONCAT(@sNCDoc_Num, ' -> Discarded'));
                        END;
                    END;
                END;
            END
            ELSE
            BEGIN
                UPDATE [EAI_OWNER].[TMP_ACCOUNT_HEADER]
                   SET Status = 'Max Amount exceeded', Processed = @Now
                 WHERE IdocNumber = @Det_IdocNumber
                   AND Status IS NULL;
            END;

            FETCH NEXT FROM curWorkItems INTO
                @Det_IdocNumber, @Det_ClearingDocNumber, @Det_Cliente_SAP,
                @Det_AmountDocCurrency, @Det_ClearingDate,
                @Det_ReferenceDocNumber;
        END;

        CLOSE curWorkItems;
        DEALLOCATE curWorkItems;

        UPDATE H
           SET H.Processed = @Now
        FROM [EAI_OWNER].[TMP_INCO_HEADER] AS H
        INNER JOIN #Groups AS G
            ON G.ClearingDocNumber = H.ClearingDocNumber
           AND G.ClearingDate = H.ClearingDate
           AND G.ProcessGroup = 1;

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = SYSDATETIME(), Proceso_1 = @nDocuments,
               Proceso_2 = @nInserts, Proceso_3 = 0, Proceso_4 = 0
         WHERE PID = @nPID;

        IF @pOutput > 0
        BEGIN
            INSERT #Trace (Created, ObjectReference, Description)
            VALUES
                (SYSDATETIME(),
                 CONCAT
                 (
                     CONVERT(CHAR(8), SYSDATETIME(), 112),
                     REPLACE(CONVERT(CHAR(5), SYSDATETIME(), 108), ':', '')
                 ),
                 CONCAT('Documents -> ',
                        RIGHT(REPLICATE(' ', 6) + CAST(@nDocuments AS VARCHAR(20)), 6))),
                (SYSDATETIME(), CONVERT(CHAR(8), @Now, 112),
                 CONCAT('Records   -> ',
                        RIGHT(REPLICATE(' ', 6) + CAST(@nRecords AS VARCHAR(20)), 6))),
                (SYSDATETIME(), CONVERT(CHAR(8), @Now, 112),
                 CONCAT('Inserts   -> ',
                        RIGHT(REPLICATE(' ', 6) + CAST(@nInserts AS VARCHAR(20)), 6))),
                (SYSDATETIME(), CONVERT(CHAR(8), @Now, 112), 'End');

            INSERT INTO [EAI_OWNER].[TRACE_EAI_OWNER]
                (Created, Object_Type, Object_Reference, Description)
            SELECT Created, 'SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO',
                   ObjectReference, Description
            FROM #Trace;
        END;

        COMMIT TRANSACTION;

        SELECT
            @nDocuments AS Documents_Found,
            @nRecords AS Records_Evaluated,
            @nInserts AS Valid_Candidates,
            @nInsert AS Insert_Mode,
            @pOutput AS Output_Level;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curWorkItems') >= 0
            CLOSE curWorkItems;
        IF CURSOR_STATUS('local', 'curWorkItems') >= -1
            DEALLOCATE curWorkItems;
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
            STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
            SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, SYSDATETIME(), NULL, NULL,
            'Error', 'SF_PROC_CENTRAL_INCO_OPT', @sMsg,
            'T-SQL', @sErrorCode, NULL, NULL, NULL
        );

        THROW;
    END CATCH;
END;
GO
