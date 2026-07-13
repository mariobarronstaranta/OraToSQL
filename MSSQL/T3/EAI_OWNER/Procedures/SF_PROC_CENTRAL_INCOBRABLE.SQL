CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE]
(
    @nDays              INT           = 28,
    @sClearingDocument  VARCHAR(30)   = 'EMPTY',
    @nInsert            INT           = 0,
    @pOutput            INT           = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        SF_PROC_CENTRAL_INCOBRABLE
        ==========================
        Procesa documentos de compensacion cuyo numero comienza con "11".
        Para cada IDoc intenta localizar primero una factura y, si no existe,
        una nota de credito. Solo genera registros de Pago/Asignacion_Pago
        cuando @nInsert > 0; con @nInsert = 0 funciona como simulacion.

        Parametros de control:
        - @nDays: limita la antiguedad de los documentos candidatos.
        - @sClearingDocument: se conserva por compatibilidad con Oracle, pero
          el procedimiento original no lo utiliza para filtrar.
        - @nInsert: 0 simula; un valor mayor que 0 permite insertar.
        - @pOutput: > 0 genera resumen y > 1 genera detalle por IDoc.

        Nota para mantenimiento:
        Oracle asigna nMargen, pero su cursor usa de forma fija SYSDATE-2/24.
        Por eso el equivalente correcto conserva un corte fijo de dos horas.
    */

    DECLARE
        @sMsg                    VARCHAR(500),
        @v_ID                    VARCHAR(30),
        @sErrorCode              VARCHAR(20),
        @sReferenceID            VARCHAR(30),
        @sClearingDocNumber      VARCHAR(20),
        @sPago_ID                VARCHAR(20),
        @nDocuments              INT,
        @nRecords                INT,
        @nInserts                INT,
        @nSQLCount               INT,
        @nValor_Pago             DECIMAL(15,4),
        @dtFecha_Asignacion      DATE,
        @nMontoMaximo            DECIMAL(15,4),
        @nPID                    INT,
        @nProceso                INT,

        @sInvDoc_Num             VARCHAR(30),
        @sInvCustomer            VARCHAR(30),
        @nInvAmount              DECIMAL(15,2),
        @nInvPending             DECIMAL(15,2),
        @nPaid                   DECIMAL(15,2),

        @sNCDoc_Num              VARCHAR(30),
        @sNCCustomer             VARCHAR(30),
        @nNCAmount               DECIMAL(15,2),
        @nNCPending              DECIMAL(15,2),
        @nNCPaid                 DECIMAL(15,2),

        @sCliente_SAP            VARCHAR(30),
        @sCtro                   VARCHAR(30),
        @sCliente_V3             VARCHAR(30),
        @nDistribuidor           INT,

        @Rec_ClearingDocNumber   VARCHAR(20),
        @Rec_ClearingDate        VARCHAR(20),
        @Rec_Cnt_Idocs           INT,

        @Det_IdocNumber          VARCHAR(30),
        @Det_ClearingDocNumber   VARCHAR(20),
        @Det_Cliente_SAP         VARCHAR(30),
        @Det_AmountDocCurrency   DECIMAL(15,4),
        @Det_ClearingDate        VARCHAR(20),
        @Det_ReferenceDocNumber  VARCHAR(30),
        @Det_Created             DATETIME,
        @Det_Ctro                VARCHAR(30),
        @Det_Cliente_V3          VARCHAR(30),
        @Det_Distribuidor        INT;

    BEGIN TRY
        /*
            SQL Server procesa el lote como una sola unidad de trabajo.
            Si ocurre un error, se revierten encabezados, duplicados, pagos y
            asignaciones para evitar un documento parcialmente procesado.
            El Oracle tenia COMMIT intermedios; no se replican porque impedirian
            recuperar consistentemente el lote ante una falla posterior.
        */
        BEGIN TRAN;

        SET @nProceso = 888;
        SET @nPID = NEXT VALUE FOR [EAI_Owner].[ProcessID];

        EXEC [EAI_Owner].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, GETDATE());

        SET @nDocuments   = 0;
        SET @nRecords     = 0;
        SET @nInserts     = 0;
        SET @nMontoMaximo = 500000;

        IF (@pOutput > 0)
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_INCOBRABLE',
                 FORMAT(GETDATE(), 'yyyyMMddHHmm'),
                 'Begin');
        END;

        /*
            Cursor principal (ScrData en Oracle).
            Agrupa por documento y fecha de compensacion. No se filtra por
            @sClearingDocument porque el parametro tampoco se usa en Oracle.
        */
        DECLARE curData CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                tmp.ClearingDocNumber,
                tmp.ClearingDate,
                COUNT(tmp.IdocNumber) AS Cnt_Idocs
            FROM [EAI_Owner].[tmp_Account_Header] tmp
            WHERE tmp.Created > CAST(DATEADD(DAY, -@nDays, GETDATE()) AS DATE)
              AND tmp.Created < DATEADD(HOUR, -2, GETDATE())
              AND tmp.ClearingDocNumber LIKE '11%'
            GROUP BY
                tmp.ClearingDocNumber,
                tmp.ClearingDate
            ORDER BY
                tmp.ClearingDate,
                tmp.ClearingDocNumber;

        OPEN curData;

        FETCH NEXT FROM curData
        INTO @Rec_ClearingDocNumber, @Rec_ClearingDate, @Rec_Cnt_Idocs;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @nDocuments = @nDocuments + 1;
            SET @v_ID = @Rec_ClearingDocNumber;

            UPDATE [EAI_Owner].[tmp_Inco_Header]
               SET Last_Updated = GETDATE()
             WHERE ClearingDocNumber = @Rec_ClearingDocNumber
               AND ClearingDate      = @Rec_ClearingDate;

            SET @nSQLCount = @@ROWCOUNT;

            IF (@nSQLCount = 0)
            BEGIN
                INSERT INTO [EAI_Owner].[tmp_Inco_Header]
                    (ClearingDocNumber, ClearingDate, Created, Records)
                VALUES
                    (@Rec_ClearingDocNumber, @Rec_ClearingDate, GETDATE(), @Rec_Cnt_Idocs);

                SET @sClearingDocNumber = @Rec_ClearingDocNumber;
                -- TO_DATE de Oracle genera error si YYYYMMDD es invalido.
                -- CONVERT conserva esa validacion; TRY_CONVERT la ocultaria.
                SET @dtFecha_Asignacion = CONVERT(DATE, @Rec_ClearingDate, 112);
                SET @sPago_ID = CONCAT('11', @sClearingDocNumber);

                /*
                    ScrDuplicated de Oracle:
                    por cada referencia repetida se marca solamente el IDoc
                    con valor MAX como "Duplicated". El otro IDoc queda
                    disponible para continuar con la evaluacion.
                */
                ;WITH Duplicados AS
                (
                    SELECT
                        ReferenceDocNumber,
                        MAX(IdocNumber) AS Max_IdocNumber
                    FROM [EAI_Owner].[tmp_Account_Header]
                    WHERE ClearingDocNumber = @sClearingDocNumber
                    GROUP BY ReferenceDocNumber
                    HAVING COUNT(IdocNumber) > 1
                )
                UPDATE AH
                   SET AH.Status = 'Duplicated',
                       AH.Processed = GETDATE()
                FROM [EAI_Owner].[tmp_Account_Header] AH
                INNER JOIN Duplicados D
                    ON D.Max_IdocNumber = AH.IdocNumber;

                /*
                    ScrWorkAround de Oracle:
                    el INNER JOIN con Mov_Cliente descarta IDocs cuyo cliente
                    SAP no tenga correspondencia. No debe cambiarse a LEFT JOIN
                    sin confirmar primero la regla con el negocio.
                */
                DECLARE curWorkAround CURSOR LOCAL FAST_FORWARD FOR
                    SELECT
                        Inco.IdocNumber,
                        Inco.ClearingDocNumber,
                        Inco.CustomerNumber,
                        Inco.AmountDocCurrency,
                        Inco.ClearingDate,
                        Inco.ReferenceDocNumber,
                        Inco.Created,
                        MC.Ctro,
                        MC.Cliente_V3,
                        MC.Dist_Venta
                    FROM [EAI_Owner].[tmp_Account_Header] Inco
                    INNER JOIN [T3].[Mov_Cliente] MC
                        ON Inco.CustomerNumber = MC.Cliente_SAP
                    WHERE Inco.Created > CAST(DATEADD(DAY, -@nDays, GETDATE()) AS DATE)
                      AND Inco.ClearingDocNumber = @sClearingDocNumber
                      AND COALESCE(Inco.Status, 'NULO') <> 'Duplicated';

                OPEN curWorkAround;

                FETCH NEXT FROM curWorkAround
                INTO
                    @Det_IdocNumber,
                    @Det_ClearingDocNumber,
                    @Det_Cliente_SAP,
                    @Det_AmountDocCurrency,
                    @Det_ClearingDate,
                    @Det_ReferenceDocNumber,
                    @Det_Created,
                    @Det_Ctro,
                    @Det_Cliente_V3,
                    @Det_Distribuidor;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @sPago_ID      = CONCAT('11', @Det_IdocNumber);
                    SET @nRecords      = @nRecords + 1;
                    SET @sReferenceID  = @Det_ReferenceDocNumber;
                    SET @nValor_Pago   = @Det_AmountDocCurrency;

                    SET @sCliente_SAP  = '';
                    SET @sCliente_V3   = '';
                    SET @sCtro         = '';
                    SET @nDistribuidor = 0;

                    IF (@pOutput > 1)
                    BEGIN
                        INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                            (Created, Object_Type, Object_Reference, Description)
                        VALUES
                            (GETDATE(),
                             'SF_PROC_CENTRAL_INCOBRABLE',
                             @sClearingDocNumber,
                             CONCAT(@sReferenceID, ',', @Det_Cliente_SAP, ',', @nValor_Pago, ' (', @Det_IdocNumber, ')'));
                    END;

                    IF (@nValor_Pago < @nMontoMaximo)
                    BEGIN
                        /*
                            Paso 1: buscar la referencia como factura.
                            Los valores se reinician antes del EXEC para evitar
                            reutilizar datos del IDoc procesado anteriormente.
                        */
                        SET @sInvDoc_Num  = NULL;
                        SET @sInvCustomer = NULL;
                        SET @nInvAmount   = 0;
                        SET @nInvPending  = 0;
                        SET @nPaid        = 0;

                        EXEC [EAI_Owner].[SF_GET_INVOICE_DATA]
                            @sReferenceID,
                            @sInvDoc_Num  OUTPUT,
                            @sInvCustomer OUTPUT,
                            @nInvAmount   OUTPUT,
                            @nInvPending  OUTPUT,
                            @nPaid        OUTPUT;

                        IF (COALESCE(@nInvAmount, 0) > 0)
                        BEGIN
                            IF (@pOutput > 1)
                            BEGIN
                                INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                    (Created, Object_Type, Object_Reference, Description)
                                VALUES
                                    (GETDATE(),
                                     'SF_PROC_CENTRAL_INCOBRABLE',
                                     @sClearingDocNumber,
                                     CONCAT(COALESCE(@sInvDoc_Num, @sReferenceID), ' pendiente ', @nInvPending));
                            END;

                            -- Solo es asignable si el saldo pendiente cubre
                            -- completamente el importe del documento incobrable.
                            IF (COALESCE(@nInvPending, 0) >= @nValor_Pago)
                            BEGIN
                                SET @nInserts = @nInserts + 1;

                                IF (@pOutput > 1)
                                BEGIN
                                    INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                        (Created, Object_Type, Object_Reference, Description)
                                    VALUES
                                        (GETDATE(),
                                         'SF_PROC_CENTRAL_INCOBRABLE',
                                         @sClearingDocNumber,
                                         CONCAT(@sInvDoc_Num, ' -> Procesado'));
                                END;

                                /*
                                    @nInserts cuenta candidatos validos incluso
                                    durante una simulacion. Las escrituras reales
                                    se habilitan exclusivamente con @nInsert > 0.
                                */
                                IF (@nInsert > 0)
                                BEGIN
                                    SET @sCliente_SAP = @sInvCustomer;

                                    SELECT TOP (1)
                                        @sCliente_V3   = MC.Cliente_V3,
                                        @sCtro         = MC.Ctro,
                                        @nDistribuidor = MC.Dist_Venta
                                    FROM [T3].[Mov_Cliente] MC
                                    WHERE MC.Cliente_SAP = @sCliente_SAP;

                                    INSERT INTO [T3].[Pago]
                                        (Pago_ID, Fecha_Trn, Distribuidor, Fecha_Pago,
                                         Cliente_V3, Cliente_SAP, Rep_ID,
                                         Tipo_Pago, Metodo_Pago, Valor_Pago, Ctro)
                                    VALUES
                                        (@sPago_ID, GETDATE(), @nDistribuidor, @dtFecha_Asignacion,
                                         @sCliente_V3, @sCliente_SAP, 'CENTRAL',
                                         'PAYMENT', 'I', @nValor_Pago, @sCtro);

                                    INSERT INTO [T3].[Asignacion_Pago]
                                        (Pago_ID, Asignacion_ID, Fecha_Trn, Factura,
                                         Distribuidor, Ctro, Cliente_V3, Cliente_SAP,
                                         Rep_ID, Fecha_Asignacion, Valor_Pago)
                                    VALUES
                                        (@sPago_ID, @sPago_ID, GETDATE(), @sInvDoc_Num,
                                         @nDistribuidor, @sCtro, @sCliente_V3, @sCliente_SAP,
                                         'CENTRAL', @dtFecha_Asignacion, @nValor_Pago);

                                    UPDATE [EAI_Owner].[tmp_Account_Header]
                                       SET Status = 'Processed',
                                           Processed = GETDATE()
                                     WHERE IdocNumber = @Det_IdocNumber
                                       AND Status IS NULL;
                                END;
                            END
                            ELSE
                            BEGIN
                                UPDATE [EAI_Owner].[tmp_Account_Header]
                                   SET Status = 'Discarded',
                                       Processed = GETDATE()
                                 WHERE IdocNumber = @Det_IdocNumber
                                   AND Status IS NULL;

                                IF (@pOutput > 1)
                                BEGIN
                                    INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                        (Created, Object_Type, Object_Reference, Description)
                                    VALUES
                                        (GETDATE(),
                                         'SF_PROC_CENTRAL_INCOBRABLE',
                                         @sClearingDocNumber,
                                         CONCAT(@sInvDoc_Num, ' -> Discarded'));
                                END;
                            END;
                        END
                        ELSE
                        BEGIN
                            /*
                                Paso 2: si la referencia no corresponde a una
                                factura, intentar localizarla como nota de credito.
                            */
                            SET @sNCDoc_Num  = NULL;
                            SET @sNCCustomer = NULL;
                            SET @nNCAmount   = 0;
                            SET @nNCPending  = 0;
                            SET @nNCPaid     = 0;

                            EXEC [EAI_Owner].[SF_GET_CREDIT_DATA]
                                @sReferenceID,
                                @sNCDoc_Num  OUTPUT,
                                @sNCCustomer OUTPUT,
                                @nNCAmount   OUTPUT,
                                @nNCPending  OUTPUT,
                                @nNCPaid     OUTPUT;

                            IF (@pOutput > 1)
                            BEGIN
                                INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                    (Created, Object_Type, Object_Reference, Description)
                                VALUES
                                    (GETDATE(),
                                     'SF_PROC_CENTRAL_INCOBRABLE',
                                     @sClearingDocNumber,
                                     CONCAT(COALESCE(@sNCDoc_Num, @sReferenceID), ' pendiente ', @nNCPending));
                            END;

                            IF (COALESCE(@nNCAmount, 0) > 0)
                            BEGIN
                                IF (COALESCE(@nNCPending, 0) >= @nValor_Pago)
                                BEGIN
                                    SET @nInserts = @nInserts + 1;

                                    IF (@pOutput > 1)
                                    BEGIN
                                        INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                            (Created, Object_Type, Object_Reference, Description)
                                        VALUES
                                            (GETDATE(),
                                             'SF_PROC_CENTRAL_INCOBRABLE',
                                             @sClearingDocNumber,
                                             CONCAT(@sNCDoc_Num, ' -> Procesado'));
                                    END;

                                    -- Una nota de credito genera asignacion, pero
                                    -- no genera una fila independiente en T3.Pago.
                                    IF (@nInsert > 0)
                                    BEGIN
                                        SET @sCliente_SAP = @sNCCustomer;

                                        SELECT TOP (1)
                                            @sCliente_V3   = MC.Cliente_V3,
                                            @sCtro         = MC.Ctro,
                                            @nDistribuidor = MC.Dist_Venta
                                        FROM [T3].[Mov_Cliente] MC
                                        WHERE MC.Cliente_SAP = @sCliente_SAP;

                                        INSERT INTO [T3].[Asignacion_Pago]
                                            (Pago_ID, Asignacion_ID, Fecha_Trn, Factura,
                                             Nota_Credito, Distribuidor, Ctro, Cliente_V3,
                                             Cliente_SAP, Rep_ID, Fecha_Asignacion, Valor_Pago)
                                        VALUES
                                            (@sPago_ID, @sPago_ID, GETDATE(), 'INCOBRABLE',
                                             @sNCDoc_Num, @nDistribuidor, @sCtro, @sCliente_V3,
                                             @sCliente_SAP, 'CENTRAL', @dtFecha_Asignacion, @nValor_Pago);

                                        UPDATE [EAI_Owner].[tmp_Account_Header]
                                           SET Status = 'Processed',
                                               Processed = GETDATE()
                                         WHERE IdocNumber = @Det_IdocNumber
                                           AND Status IS NULL;
                                    END;
                                END
                                ELSE
                                BEGIN
                                    UPDATE [EAI_Owner].[tmp_Account_Header]
                                       SET Status = 'Discarded',
                                           Processed = GETDATE()
                                     WHERE IdocNumber = @Det_IdocNumber
                                       AND Status IS NULL;

                                    IF (@pOutput > 1)
                                    BEGIN
                                        INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                                            (Created, Object_Type, Object_Reference, Description)
                                        VALUES
                                            (GETDATE(),
                                             'SF_PROC_CENTRAL_INCOBRABLE',
                                             @sClearingDocNumber,
                                             CONCAT(@sNCDoc_Num, ' -> Discarded'));
                                    END;
                                END;
                            END;
                        END;
                    END
                    ELSE
                    BEGIN
                        -- Proteccion del Oracle: importes de 500,000 o mayores
                        -- no se asignan automaticamente.
                        UPDATE [EAI_Owner].[tmp_Account_Header]
                           SET Status = 'Max Amount exceeded',
                               Processed = GETDATE()
                         WHERE IdocNumber = @Det_IdocNumber
                           AND Status IS NULL;
                    END;

                    FETCH NEXT FROM curWorkAround
                    INTO
                        @Det_IdocNumber,
                        @Det_ClearingDocNumber,
                        @Det_Cliente_SAP,
                        @Det_AmountDocCurrency,
                        @Det_ClearingDate,
                        @Det_ReferenceDocNumber,
                        @Det_Created,
                        @Det_Ctro,
                        @Det_Cliente_V3,
                        @Det_Distribuidor;
                END;

                CLOSE curWorkAround;
                DEALLOCATE curWorkAround;

                UPDATE [EAI_Owner].[tmp_Inco_Header]
                   SET Processed = GETDATE()
                 WHERE ClearingDocNumber = @Rec_ClearingDocNumber
                   AND ClearingDate      = @Rec_ClearingDate;
            END;

            FETCH NEXT FROM curData
            INTO @Rec_ClearingDocNumber, @Rec_ClearingDate, @Rec_Cnt_Idocs;
        END;

        CLOSE curData;
        DEALLOCATE curData;

        UPDATE [EAI_Owner].[MX_COMPONENTS]
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin       = GETDATE(),
               Proceso_1 = @nDocuments,
               Proceso_2 = @nInserts,
               Proceso_3 = 0,
               Proceso_4 = 0
         WHERE PID = @nPID;

        IF (@pOutput > 0)
        BEGIN
            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_INCOBRABLE',
                 FORMAT(GETDATE(), 'yyyyMMddHHmm'),
                 CONCAT('Documents -> ', RIGHT(REPLICATE(' ', 6) + CAST(@nDocuments AS VARCHAR(20)), 6)));

            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_INCOBRABLE',
                 FORMAT(GETDATE(), 'yyyyMMdd'),
                 CONCAT('Records   -> ', RIGHT(REPLICATE(' ', 6) + CAST(@nRecords AS VARCHAR(20)), 6)));

            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_INCOBRABLE',
                 FORMAT(GETDATE(), 'yyyyMMdd'),
                 CONCAT('Inserts   -> ', RIGHT(REPLICATE(' ', 6) + CAST(@nInserts AS VARCHAR(20)), 6)));

            INSERT INTO [EAI_Owner].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(),
                 'SF_PROC_CENTRAL_INCOBRABLE',
                 FORMAT(GETDATE(), 'yyyyMMdd'),
                 'End');
        END;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        -- CLOSE solo es valido para un cursor abierto (estado 0 o 1).
        IF CURSOR_STATUS('local', 'curWorkAround') >= 0
            CLOSE curWorkAround;

        -- Un cursor cerrado aun debe liberarse con DEALLOCATE (estado -1).
        IF CURSOR_STATUS('local', 'curWorkAround') >= -1
        BEGIN
            DEALLOCATE curWorkAround;
        END;

        IF CURSOR_STATUS('local', 'curData') >= 0
            CLOSE curData;

        IF CURSOR_STATUS('local', 'curData') >= -1
        BEGIN
            DEALLOCATE curData;
        END;

        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_Owner].[MX_EAI_MESSAGE_LOG]
            (DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID,
             STATUS, QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE,
             SIEBEL_ERROR_CODE, RETRY_COUNT, SEQUENCE, PARENT_ROW_ID)
        VALUES
            ('Job Logging', @v_ID, GETDATE(), NULL, NULL,
             'Error', 'SF_PROC_CENTRAL_INCOBRABLE', @sMsg, 'T-SQL',
             @sErrorCode, NULL, NULL, NULL);

        THROW;
    END CATCH;
END;
GO
