/*
    Homologo SQL Server de EAI_OWNER.WA_ASIGNA_INCOBRABLE (Oracle).

    Objetivo funcional:
      1. Enriquecer las aplicaciones incobrables con importes, RFC y saldos.
      2. Detectar aplicaciones ya realizadas, duplicadas o excedidas.
      3. Con @pLevel >= 1000, generar dos clases de movimiento:
         - Por nota de credito: Asignacion_Pago con factura 'INCOBRABLE'.
         - Por factura: Pago con tipo PAYMENT/metodo I y su Asignacion_Pago.

    Niveles conservados del procedure Oracle:
      - @pLevel <= 10  : calcula importes fiscales y RFC.
      - @pLevel <= 100 : consulta saldos pendientes.
      - Todos          : ejecuta validaciones de negocio.
      - @pLevel >= 1000: libera las aplicaciones elegibles.

    SQL Server no conserva el ROWID de Oracle. Los conjuntos de liberacion se
    materializan antes de insertar y las actualizaciones usan Factura,
    Nota_Credito e Importe como identificadores logicos. El DDL migrado no
    ofrece una llave fisica mas precisa.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNA_INCOBRABLE]
(
    @pLevel    INT = 0,
    @pDays     INT = 0,
    @nSequence INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    -- Oracle confirma en EXCEPTION tanto el trabajo previo como la bitacora.
    -- OFF permite conservarlo si SQL Server aun considera confirmable la transaccion.
    SET XACT_ABORT OFF;

    DECLARE
        @nAplicaciones INT = 0,
        @sErrorCode    VARCHAR(30),
        @sMsg          VARCHAR(300),
        @nPID          INT = NULL,
        @sReference    VARCHAR(50) = NULL,
        @sStepPLSQL    VARCHAR(50) = NULL,
        @Now           DATETIME2(0),
        @FechaAsignacion DATE,
        @PagoPrefix     VARCHAR(7);

    DECLARE
        @sInvDoc_Num   VARCHAR(30),
        @sInvCustomer  VARCHAR(30),
        @nInvAmount    DECIMAL(15,2),
        @nInvPending   DECIMAL(15,2),
        @nPaid         DECIMAL(15,2),
        @sNCDoc_Num    VARCHAR(30),
        @sNCCustomer   VARCHAR(30),
        @nNCAmount     DECIMAL(15,2),
        @nNCPending    DECIMAL(15,2),
        @nNCPaid       DECIMAL(15,2);

    SET @pLevel = COALESCE(@pLevel, 0);
    SET @pDays = COALESCE(@pDays, 0);
    SET @nSequence = COALESCE(@nSequence, 0);

    BEGIN TRY
        BEGIN TRAN;

        -- Oracle asigna esta etapa antes de evaluar el primer nivel.
        SET @sStepPLSQL = 'ScrFacturas';

        /* ============================================================
           1. Actualiza importes y RFC de facturas / notas
           ============================================================ */
        IF @pLevel <= 10
        BEGIN
            SET @sStepPLSQL = 'ScrFacturas';

            ;WITH Facturas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                          COALESCE(RFD.Valor_Subt,   0)
                        + COALESCE(RFD.Valor_IVA,    0)
                        + COALESCE(RFD.Envio_Subt,   0)
                        + COALESCE(RFD.Envio_IVA,    0)
                        + COALESCE(RFD.Credito_Subt, 0)
                        + COALESCE(RFD.Credito_IVA,  0)
                    ) AS Importe
                FROM
                (
                    SELECT DISTINCT Factura
                    FROM [EAI_OWNER].[X_Aplica_Incobrable]
                    WHERE Factura IS NOT NULL
                ) Asig
                INNER JOIN [T3].[Registro_Fiscal] RF
                    ON Asig.Factura = RF.Factura
                INNER JOIN [T3].[Registro_Fiscal_Detalle] RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN [T3].[Cliente] Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                   AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY RFD.Factura, Cte.RFC
            )
            UPDATE Asig
               SET Asig.Fact_Importe = F.Importe,
                   Asig.Fact_RFC     = F.RFC
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN Facturas F
                ON Asig.Factura = F.Factura;

            SET @sStepPLSQL = 'ScrNotas';

            ;WITH Notas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                          COALESCE(RFD.Valor_Subt,   0)
                        + COALESCE(RFD.Valor_IVA,    0)
                        + COALESCE(RFD.Envio_Subt,   0)
                        + COALESCE(RFD.Envio_IVA,    0)
                        + COALESCE(RFD.Credito_Subt, 0)
                        + COALESCE(RFD.Credito_IVA,  0)
                    ) AS Importe
                FROM
                (
                    SELECT DISTINCT Nota_Credito
                    FROM [EAI_OWNER].[X_Aplica_Incobrable]
                    WHERE Nota_Credito IS NOT NULL
                ) Asig
                INNER JOIN [T3].[Registro_Fiscal] RF
                    ON Asig.Nota_Credito = RF.Factura
                INNER JOIN [T3].[Registro_Fiscal_Detalle] RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN [T3].[Cliente] Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                   AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY RFD.Factura, Cte.RFC
            )
            UPDATE Asig
               SET Asig.Cred_Importe = N.Importe,
                   Asig.Cred_RFC     = N.RFC
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN Notas N
                ON Asig.Nota_Credito = N.Factura;
        END;

        /* ============================================================
           2. Actualiza pendientes usando procedures externos
              Se conserva cursor porque cada documento llama a una rutina externa.
           ============================================================ */
        IF @pLevel <= 100
        BEGIN
            SET @sStepPLSQL = 'ScrFactPend';

            DECLARE curFactPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Factura
                FROM [EAI_OWNER].[X_Aplica_Incobrable];

            OPEN curFactPend;
            FETCH NEXT FROM curFactPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sInvDoc_Num = NULL;
                SET @sInvCustomer = NULL;
                SET @nInvAmount = NULL;
                SET @nInvPending = NULL;
                SET @nPaid = NULL;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @pInvoiceRef = @sReference,
                    @rtDoc_Num = @sInvDoc_Num OUTPUT,
                    @rtCliente_SAP = @sInvCustomer OUTPUT,
                    @rtAmount = @nInvAmount OUTPUT,
                    @rtPending = @nInvPending OUTPUT,
                    @rtPaid = @nPaid OUTPUT;

                UPDATE [EAI_OWNER].[X_Aplica_Incobrable]
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @sReference;

                FETCH NEXT FROM curFactPend INTO @sReference;
            END;

            CLOSE curFactPend;
            DEALLOCATE curFactPend;

            SET @sStepPLSQL = 'ScrCredPend';

            DECLARE curCredPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Nota_Credito
                FROM [EAI_OWNER].[X_Aplica_Incobrable];

            OPEN curCredPend;
            FETCH NEXT FROM curCredPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sNCDoc_Num = NULL;
                SET @sNCCustomer = NULL;
                SET @nNCAmount = NULL;
                SET @nNCPending = NULL;
                SET @nNCPaid = NULL;

                EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                    @pInvoiceRef = @sReference,
                    @rtDoc_Num = @sNCDoc_Num OUTPUT,
                    @rtCliente_SAP = @sNCCustomer OUTPUT,
                    @rtAmount = @nNCAmount OUTPUT,
                    @rtPending = @nNCPending OUTPUT,
                    @rtPaid = @nNCPaid OUTPUT;

                UPDATE [EAI_OWNER].[X_Aplica_Incobrable]
                   SET Cred_Importe   = @nNCAmount,
                       Cred_Pendiente = @nNCPending
                 WHERE Nota_Credito = @sReference;

                FETCH NEXT FROM curCredPend INTO @sReference;
            END;

            CLOSE curCredPend;
            DEALLOCATE curCredPend;
        END;

        /* ============================================================
           3. Marca duplicidades ya aplicadas
           ============================================================ */
        SET @sStepPLSQL = 'ScrDuplicidad';

        UPDATE Asig
           SET Asig.Duplicada = 'X',
               Asig.Status_Asignacion = 'Asignacion ya aplicada'
        FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
        INNER JOIN [T3].[Asignacion_Pago] AP
            ON Asig.Factura      = AP.Factura
           AND Asig.Nota_Credito = AP.Nota_Credito
           AND Asig.Importe      = AP.Valor_Pago;

        /* ============================================================
           4. Inconsistencias: Documento liberado / revisar asignación
           ============================================================ */
        SET @sStepPLSQL = 'ScrStatus_Asig';

        UPDATE Asig
           SET Asig.Status_Asignacion =
               CASE
                   WHEN CFD.Fecha_Liberacion IS NOT NULL THEN 'Documento ya liberado'
                   ELSE 'Revisar Asignacion'
               END
        FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
        LEFT JOIN [T3].[CFDI_Documentos] CFD
            ON Asig.Nota_Credito = CFD.Nota_Venta
        WHERE Asig.Nota_Credito IS NOT NULL
          AND NOT
              (
                  CFD.Fecha_Liberacion IS NULL
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
              );

        /* ============================================================
           5. Duplicidad de asignación
           ============================================================ */
        SET @sStepPLSQL = 'ScrStatus_AsigDup';

        ;WITH Dup AS
        (
            SELECT
                Nota_Credito,
                Factura,
                COUNT(*) AS Duplicidad
            FROM [EAI_OWNER].[X_Aplica_Incobrable]
            GROUP BY Nota_Credito, Factura
            HAVING COUNT(*) > 1
        )
        UPDATE Asig
           SET Asig.Status_Asignacion =
               CONCAT('Duplicidad de Asignacion ( ', CONVERT(VARCHAR(30), Dup.Duplicidad), ' )')
        FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
        INNER JOIN Dup
            ON Asig.Nota_Credito = Dup.Nota_Credito
           AND Asig.Factura = Dup.Factura;

        /* ============================================================
           6. Asignación excedente por nota crédito
           ============================================================ */
        SET @sStepPLSQL = 'ScrStatus_CredExc';

        ;WITH CredExc AS
        (
            SELECT
                Nota_Credito
            FROM [EAI_OWNER].[X_Aplica_Incobrable]
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               -- No se agrega COALESCE: Oracle compara SUM y MAX con su
               -- semantica nativa de NULL dentro del HAVING.
               AND SUM(Importe) > MAX(Cred_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
        INNER JOIN CredExc C
            ON Asig.Nota_Credito = C.Nota_Credito;

        /* ============================================================
           7. Asignación excedente por factura
           ============================================================ */
        SET @sStepPLSQL = 'ScrStatus_FactExc';

        ;WITH FactExc AS
        (
            SELECT
                Factura
            FROM [EAI_OWNER].[X_Aplica_Incobrable]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
        INNER JOIN FactExc F
            ON Asig.Factura = F.Factura;

        /* ============================================================
           8. Liberación real sólo si @pLevel >= 1000
           ============================================================ */
        IF @pLevel >= 1000
        BEGIN
            SET @sStepPLSQL = 'ScrLiberacion';

            -- SYSDATE se evalua al iniciar la liberacion, no al entrar al
            -- procedure. Esto evita usar una hora obsoleta si las validaciones
            -- anteriores tardan varios minutos.
            SET @Now = SYSDATETIME();
            SET @FechaAsignacion = CAST(DATEADD(DAY, -@pDays, @Now) AS DATE);

            -- Equivalente de TO_CHAR(SYSDATE, 'YYDDDHH24'):
            -- anio corto + dia del anio (3 posiciones) + hora (2 posiciones).
            SET @PagoPrefix =
                  RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @Now)), 2)
                + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @Now)), 3)
                + RIGHT('00'  + CONVERT(VARCHAR(2), DATEPART(HOUR, @Now)), 2);

            DECLARE @Liberacion TABLE
            (
                RowNum           INT IDENTITY(1,1),
                Pago_ID          VARCHAR(30),
                Fecha_Trn        DATETIME2(0),
                Factura          VARCHAR(30),
                Nota_Credito     VARCHAR(30),
                Distribuidor     VARCHAR(30),
                Ctro             VARCHAR(30),
                Cliente_V3       VARCHAR(30),
                Cliente_SAP      VARCHAR(30),
                Rep_ID           VARCHAR(30),
                Fecha_Asignacion DATE,
                Valor_Pago       DECIMAL(15,2),
                Source_Factura   VARCHAR(30)
            );

            INSERT INTO @Liberacion
            (
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago,
                Source_Factura
            )
            SELECT
                @Now AS Fecha_Trn,
                'INCOBRABLE' AS Factura,
                Asig.Nota_Credito,
                RF.Distribuidor,
                RF.Ctro,
                RF.Cliente_V3,
                RF.Cliente_SAP,
                'CENTRAL' AS Rep_ID,
                @FechaAsignacion AS Fecha_Asignacion,
                Asig.Importe AS Valor_Pago,
                Asig.Factura AS Source_Factura
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN [T3].[Registro_Fiscal] RF
                ON Asig.Nota_Credito = RF.Factura
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND (
                    Asig.Status_Asignacion IS NULL
                    OR Asig.Status_Asignacion = 'Documento ya liberado'
                  )
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe;

            -- Oracle usa ROWNUM sin ORDER BY. La identidad conserva esa falta
            -- de prioridad de negocio. LPAD rellena valores cortos y, cuando
            -- exceden cinco posiciones, conserva sus primeros cinco caracteres.
            UPDATE L
               SET Pago_ID = @PagoPrefix
                   + CASE
                         WHEN LEN(S.SequenceText) >= 5 THEN LEFT(S.SequenceText, 5)
                         ELSE RIGHT('00000' + S.SequenceText, 5)
                     END
            FROM @Liberacion AS L
            CROSS APPLY
            (
                SELECT CONVERT(VARCHAR(20), @nSequence + L.RowNum)
            ) AS S(SequenceText);

            INSERT INTO [T3].[Asignacion_Pago]
            (
                Pago_ID,
                Asignacion_ID,
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago
            )
            SELECT
                Pago_ID,
                Pago_ID,
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago
            FROM @Liberacion;

            UPDATE Asig
               SET Asig.Status = CONCAT
                   (
                       'Insertada ',
                       CONVERT(CHAR(8), @Now, 112),
                       ' ',
                       CONVERT(CHAR(8), @Now, 108)
                   )
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN @Liberacion L
                ON Asig.Nota_Credito = L.Nota_Credito
               AND Asig.Importe = L.Valor_Pago
               AND
                  (
                      Asig.Factura = L.Source_Factura
                      OR (Asig.Factura IS NULL AND L.Source_Factura IS NULL)
                  );

            SELECT @nAplicaciones = COUNT(*) FROM @Liberacion;

            /* ========================================================
               9. Liberación contra factura: inserta Pago y Asignacion_Pago
               ======================================================== */
            SET @sStepPLSQL = 'ScrLiberacionFact';

            -- Oracle abre un segundo cursor y vuelve a evaluar SYSDATE.
            SET @Now = SYSDATETIME();
            SET @FechaAsignacion = CAST(DATEADD(DAY, -@pDays, @Now) AS DATE);
            SET @PagoPrefix =
                  RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @Now)), 2)
                + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @Now)), 3)
                + RIGHT('00'  + CONVERT(VARCHAR(2), DATEPART(HOUR, @Now)), 2);

            DECLARE @LiberacionFact TABLE
            (
                RowNum           INT IDENTITY(1,1),
                Pago_ID          VARCHAR(30),
                Fecha_Trn        DATETIME2(0),
                Factura          VARCHAR(30),
                Tipo_Pago        VARCHAR(30),
                Metodo_Pago      VARCHAR(5),
                Nota_Credito     VARCHAR(30),
                Distribuidor     VARCHAR(30),
                Ctro             VARCHAR(30),
                Cliente_V3       VARCHAR(30),
                Cliente_SAP      VARCHAR(30),
                Rep_ID           VARCHAR(30),
                Fecha_Asignacion DATE,
                Valor_Pago       DECIMAL(15,2)
            );

            INSERT INTO @LiberacionFact
            (
                Fecha_Trn,
                Factura,
                Tipo_Pago,
                Metodo_Pago,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago
            )
            SELECT
                @Now AS Fecha_Trn,
                Asig.Factura,
                'PAYMENT' AS Tipo_Pago,
                'I' AS Metodo_Pago,
                Asig.Nota_Credito,
                RF.Distribuidor,
                RF.Ctro,
                RF.Cliente_V3,
                RF.Cliente_SAP,
                'CENTRAL' AS Rep_ID,
                @FechaAsignacion AS Fecha_Asignacion,
                Asig.Importe AS Valor_Pago
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN [T3].[Registro_Fiscal] RF
                ON Asig.Factura = RF.Factura
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND (
                    Asig.Status_Asignacion IS NULL
                    OR Asig.Status_Asignacion = 'Documento ya liberado'
                  )
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe;

            -- nAplicaciones desplaza el consecutivo de esta segunda fase para
            -- que no repita Pago_ID usados por las notas de credito.
            UPDATE LF
               SET Pago_ID = @PagoPrefix
                   + CASE
                         WHEN LEN(S.SequenceText) >= 5 THEN LEFT(S.SequenceText, 5)
                         ELSE RIGHT('00000' + S.SequenceText, 5)
                     END
            FROM @LiberacionFact AS LF
            CROSS APPLY
            (
                SELECT CONVERT
                (
                    VARCHAR(20),
                    @nSequence + @nAplicaciones + LF.RowNum
                )
            ) AS S(SequenceText);

            INSERT INTO [T3].[Pago]
            (
                Pago_ID,
                Fecha_Trn,
                Distribuidor,
                Fecha_Pago,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Tipo_Pago,
                Metodo_Pago,
                Valor_Pago,
                Ctro
            )
            SELECT
                Pago_ID,
                Fecha_Trn,
                Distribuidor,
                Fecha_Asignacion,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Tipo_Pago,
                Metodo_Pago,
                Valor_Pago,
                Ctro
            FROM @LiberacionFact;

            INSERT INTO [T3].[Asignacion_Pago]
            (
                Pago_ID,
                Asignacion_ID,
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago
            )
            SELECT
                Pago_ID,
                Pago_ID,
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Fecha_Asignacion,
                Valor_Pago
            FROM @LiberacionFact;

            UPDATE Asig
               SET Asig.Status = CONCAT
                   (
                       'Insertada ',
                       CONVERT(CHAR(8), @Now, 112),
                       ' ',
                       CONVERT(CHAR(8), @Now, 108)
                   )
            FROM [EAI_OWNER].[X_Aplica_Incobrable] Asig
            INNER JOIN @LiberacionFact LF
                ON Asig.Factura = LF.Factura
               AND Asig.Importe = LF.Valor_Pago
               AND
                  (
                      Asig.Nota_Credito = LF.Nota_Credito
                      OR (Asig.Nota_Credito IS NULL AND LF.Nota_Credito IS NULL)
                  );
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- CLOSE solo aplica a cursores abiertos; DEALLOCATE tambien acepta uno
        -- cerrado. Separar ambas operaciones evita ocultar el error original.
        IF CURSOR_STATUS('local', 'curFactPend') >= 0
            CLOSE curFactPend;

        IF CURSOR_STATUS('local', 'curFactPend') >= -1
            DEALLOCATE curFactPend;

        IF CURSOR_STATUS('local', 'curCredPend') >= 0
            CLOSE curCredPend;

        IF CURSOR_STATUS('local', 'curCredPend') >= -1
            DEALLOCATE curCredPend;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- Oracle hace COMMIT dentro de WHEN OTHERS. Si la transaccion quedo
        -- inutilizable, SQL Server obliga a revertirla; la bitacora se inserta
        -- despues en autocommit. Si sigue valida, se confirma junto con el log.
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
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
            [Sequence],
            PARENT_ROW_ID
        )
        VALUES
        (
            'Workaround',
            @sReference,
            SYSDATETIME(),
            NULL,
            @nPID,
            'Error',
            'WA_ASIGNACION_PAGO',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT REPLICATE('-', 80);
        PRINT 'Problemas en la ejecucion del Procedimiento';
        PRINT 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :';
        PRINT 'Procedimiento : WA_ASIGNA_INCOBRABLE';
        PRINT CONCAT
        (
            'Fecha         : ',
            CONVERT(CHAR(8), SYSDATETIME(), 112),
            ' ',
            CONVERT(CHAR(8), SYSDATETIME(), 108)
        );
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, ''));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', COALESCE(@sMsg, ''));
        PRINT REPLICATE('-', 80);

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- El Oracle registra el error y termina sin RAISE.
        RETURN;
    END CATCH;
END;
GO
