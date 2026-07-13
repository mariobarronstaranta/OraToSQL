CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNA_NOTACARGO]
(
    @pLevel    INT = 0,
    @pDays     INT = 0,
    @nSequence INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        WA_ASIGNA_NOTACARGO
        ===================
        Valida aplicaciones de notas de cargo y, con nivel 1000, libera dos
        movimientos: una asignacion contra 'INCOBRABLE' y otra contra factura
        que crea tanto Pago como Asignacion_Pago.

        X_APLICA_NOTACARGO no contiene ROWID en SQL Server. Se usan las claves
        logicas Factura + Nota_Credito + Importe; las duplicidades se excluyen
        antes de llegar a la liberacion.
    */

    DECLARE
        @nAplicaciones INT = 0,
        @sErrorCode VARCHAR(30),
        @sMsg VARCHAR(300),
        -- Oracle declara nPID pero no le asigna valor en este procedimiento.
        @nPID INT = NULL,
        @sReference VARCHAR(50),
        @sStepPLSQL VARCHAR(50),
        @sInvDoc_Num VARCHAR(30),
        @sInvCustomer VARCHAR(30),
        @nInvAmount DECIMAL(15,2),
        @nInvPending DECIMAL(15,2),
        @nPaid DECIMAL(15,2),
        @sNCDoc_Num VARCHAR(30),
        @sNCCustomer VARCHAR(30),
        @nNCAmount DECIMAL(15,2),
        @nNCPending DECIMAL(15,2),
        @nNCPaid DECIMAL(15,2),
        @Now DATETIME2(0) = SYSDATETIME(),
        @FechaAsignacion DATE,
        @PagoPrefix VARCHAR(7);

    SET @pLevel = COALESCE(@pLevel, 0);
    SET @pDays = COALESCE(@pDays, 0);
    SET @nSequence = COALESCE(@nSequence, 0);
    SET @FechaAsignacion = CAST(DATEADD(DAY, -@pDays, @Now) AS DATE);
    SET @PagoPrefix =
          RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @Now)), 2)
        + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @Now)), 3)
        + RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, @Now)), 2);

    BEGIN TRY
        BEGIN TRAN;

        ---------------------------------------------------------------------
        -- Paso 1: Actualiza importes y RFC de facturas y notas de crédito
        ---------------------------------------------------------------------
        IF @pLevel <= 10
        BEGIN
            SET @sStepPLSQL = 'ScrFacturas';

            ;WITH ScrFacturas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        COALESCE(RFD.Valor_Subt, 0) +
                        COALESCE(RFD.Valor_IVA, 0) +
                        COALESCE(RFD.Envio_Subt, 0) +
                        COALESCE(RFD.Envio_IVA, 0) +
                        COALESCE(RFD.Credito_Subt, 0) +
                        COALESCE(RFD.Credito_IVA, 0)
                    ) AS Importe
                FROM
                (
                    SELECT DISTINCT Factura
                    FROM [EAI_OWNER].[X_Aplica_NotaCargo]
                    WHERE Factura IS NOT NULL
                ) Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Factura = RF.Factura
                INNER JOIN T3.Registro_Fiscal_Detalle RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN T3.Cliente Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                   AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY RFD.Factura, Cte.RFC
            )
            UPDATE Asig
               SET Asig.Fact_Importe = F.Importe,
                   Asig.Fact_RFC     = F.RFC
            FROM EAI_OWNER.X_Aplica_NotaCargo Asig
            INNER JOIN ScrFacturas F
                ON Asig.Factura = F.Factura;

            SET @sStepPLSQL = 'ScrNotas';

            ;WITH ScrNotas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        COALESCE(RFD.Valor_Subt, 0) +
                        COALESCE(RFD.Valor_IVA, 0) +
                        COALESCE(RFD.Envio_Subt, 0) +
                        COALESCE(RFD.Envio_IVA, 0) +
                        COALESCE(RFD.Credito_Subt, 0) +
                        COALESCE(RFD.Credito_IVA, 0)
                    ) AS Importe
                FROM
                (
                    SELECT DISTINCT Nota_Credito
                    FROM [EAI_OWNER].[X_Aplica_NotaCargo]
                    WHERE Nota_Credito IS NOT NULL
                ) Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Nota_Credito = RF.Factura
                INNER JOIN T3.Registro_Fiscal_Detalle RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN T3.Cliente Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                   AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY RFD.Factura, Cte.RFC
            )
            UPDATE Asig
               SET Asig.Cred_Importe = N.Importe,
                   Asig.Cred_RFC     = N.RFC
            FROM EAI_OWNER.X_Aplica_NotaCargo Asig
            INNER JOIN ScrNotas N
                ON Asig.Nota_Credito = N.Factura;
        END;

        ---------------------------------------------------------------------
        -- Paso 2: Obtiene saldo pendiente de facturas y notas
        -- Se conserva cursor porque depende de procedures externos por documento.
        ---------------------------------------------------------------------
        IF @pLevel <= 100
        BEGIN
            SET @sStepPLSQL = 'ScrFactPend';

            DECLARE curFactPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Factura
                FROM EAI_OWNER.X_Aplica_NotaCargo
                WHERE Factura IS NOT NULL;

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

                UPDATE EAI_OWNER.X_Aplica_NotaCargo
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @sReference;

                FETCH NEXT FROM curFactPend INTO @sReference;
            END;

            CLOSE curFactPend;
            DEALLOCATE curFactPend;

            SET @sStepPLSQL = 'ScrCredPend';

            DECLARE curCredPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Nota_Credito
                FROM EAI_OWNER.X_Aplica_NotaCargo
                WHERE Nota_Credito IS NOT NULL;

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

                UPDATE EAI_OWNER.X_Aplica_NotaCargo
                   SET Cred_Importe   = @nNCAmount,
                       Cred_Pendiente = @nNCPending
                 WHERE Nota_Credito = @sReference;

                FETCH NEXT FROM curCredPend INTO @sReference;
            END;

            CLOSE curCredPend;
            DEALLOCATE curCredPend;
        END;

        ---------------------------------------------------------------------
        -- Paso 3: Marca asignaciones ya aplicadas
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrDuplicidad';

        UPDATE Asig
           SET Asig.Duplicada = 'X',
               Asig.Status_Asignacion = 'Asignacion ya aplicada'
        FROM EAI_OWNER.X_Aplica_NotaCargo Asig
        INNER JOIN T3.Asignacion_Pago AP
            ON Asig.Factura = AP.Factura
           AND Asig.Nota_Credito = AP.Nota_Credito
           AND Asig.Importe = AP.Valor_Pago;

        ---------------------------------------------------------------------
        -- Paso 4: Inconsistencias generales
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_Asig';

        UPDATE Asig
           SET Asig.Status_Asignacion =
               CASE
                   WHEN CFD.Fecha_Liberacion IS NOT NULL THEN 'Documento ya liberado'
                   ELSE 'Revisar Asignacion'
               END
        FROM [EAI_OWNER].[X_Aplica_NotaCargo] Asig
        LEFT JOIN [T3].[CFDI_Documentos] CFD
            ON Asig.Nota_Credito = CFD.Nota_Venta
        WHERE Asig.Nota_Credito IS NOT NULL
          AND NOT
              (
                  CFD.Fecha_Liberacion IS NULL
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
              );

        ---------------------------------------------------------------------
        -- Paso 5: Duplicidad por nota/factura
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_AsigDup';

        ;WITH Dup AS
        (
            SELECT
                Nota_Credito,
                Factura,
                SUM(Importe) AS Importe,
                COUNT(*) AS Duplicidad,
                MAX(Fact_RFC) AS Fact_RFC,
                MAX(Cred_RFC) AS Cred_RFC,
                MAX(Fact_Pendiente) AS Fact_Pendiente,
                MAX(Cred_Pendiente) AS Cred_Pendiente
            FROM EAI_OWNER.X_Aplica_NotaCargo
            GROUP BY Nota_Credito, Factura
            HAVING COUNT(*) > 1
        ),
        ScrStatus_AsigDup AS
        (
            SELECT
                Dup.Nota_Credito,
                Dup.Factura,
                CONCAT('Duplicidad de Asignacion ( ', CONVERT(VARCHAR(20), Dup.Duplicidad), ' )') AS Status_Asignacion
            FROM Dup
            LEFT JOIN T3.CFDI_Documentos CFD
                ON Dup.Nota_Credito = CFD.Nota_Venta
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = D.Status_Asignacion
        FROM EAI_OWNER.X_Aplica_NotaCargo Asig
        INNER JOIN ScrStatus_AsigDup D
            ON Asig.Nota_Credito = D.Nota_Credito
           AND Asig.Factura = D.Factura;

        ---------------------------------------------------------------------
        -- Paso 6: Asignación excedente por nota de crédito
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_CredExc';

        ;WITH CredExc AS
        (
            SELECT
                Nota_Credito,
                SUM(Importe) AS Importe,
                COUNT(*) AS Duplicidad,
                MAX(Cred_Pendiente) AS Cred_Pendiente
            FROM EAI_OWNER.X_Aplica_NotaCargo
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Cred_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM EAI_OWNER.X_Aplica_NotaCargo Asig
        INNER JOIN CredExc C
            ON Asig.Nota_Credito = C.Nota_Credito;

        ---------------------------------------------------------------------
        -- Paso 7: Asignación excedente por factura
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_FactExc';

        ;WITH FactExc AS
        (
            SELECT
                Factura,
                SUM(Importe) AS Importe,
                COUNT(*) AS Duplicidad,
                MAX(Fact_Pendiente) AS Fact_Pendiente
            FROM EAI_OWNER.X_Aplica_NotaCargo
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM EAI_OWNER.X_Aplica_NotaCargo Asig
        INNER JOIN FactExc F
            ON Asig.Factura = F.Factura;

        ---------------------------------------------------------------------
        -- Paso 8: Inserción de liberaciones sólo si @pLevel >= 1000
        ---------------------------------------------------------------------
        IF @pLevel >= 1000
        BEGIN
            -----------------------------------------------------------------
            -- ScrLiberacion: inserta en T3.Asignacion_Pago usando factura INCOBRABLE
            -----------------------------------------------------------------
            SET @sStepPLSQL = 'ScrLiberacion';

            ;WITH Src AS
            (
                SELECT
                    ROW_NUMBER() OVER
                    (
                        ORDER BY Asig.Nota_Credito, Asig.Factura, Asig.Importe
                    ) AS RN,
                    @Now AS Fecha_Trn,
                    'INCOBRABLE' AS Factura,
                    Asig.Nota_Credito,
                    RF.Distribuidor,
                    RF.Ctro,
                    RF.Cliente_V3,
                    RF.Cliente_SAP,
                    'CENTRAL' AS Rep_ID,
                    @FechaAsignacion AS Fecha_Asignacion,
                    Asig.Importe AS Valor_Pago
                FROM EAI_OWNER.X_Aplica_NotaCargo Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Nota_Credito = RF.Factura
                WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
                  AND (
                        Asig.Status_Asignacion IS NULL
                        OR Asig.Status_Asignacion = 'Documento ya liberado'
                      )
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
            ),
            Prep AS
            (
                SELECT
                    CONCAT(@PagoPrefix, RIGHT('00000' + CONVERT(VARCHAR(5), @nSequence + RN), 5)) AS Pago_ID,
                    *
                FROM Src
            )
            INSERT INTO T3.Asignacion_Pago
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
            FROM Prep;

            SET @nAplicaciones = @@ROWCOUNT;

            UPDATE Asig
               SET Asig.Status = CONCAT('Insertada ', CONVERT(VARCHAR(19), @Now, 120))
            FROM [EAI_OWNER].[X_Aplica_NotaCargo] Asig
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND (Asig.Status_Asignacion IS NULL OR Asig.Status_Asignacion = 'Documento ya liberado')
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
              AND EXISTS
                  (SELECT 1 FROM [T3].[Registro_Fiscal] RF WHERE RF.Factura = Asig.Nota_Credito);

            -----------------------------------------------------------------
            -- ScrLiberacionFact: inserta en T3.Pago y T3.Asignacion_Pago
            -----------------------------------------------------------------
            SET @sStepPLSQL = 'ScrLiberacionFact';

            ;WITH Src AS
            (
                SELECT
                    ROW_NUMBER() OVER
                    (
                        ORDER BY Asig.Factura, Asig.Nota_Credito, Asig.Importe
                    ) AS RN,
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
                FROM EAI_OWNER.X_Aplica_NotaCargo Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Factura = RF.Factura
                WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
                  AND (
                        Asig.Status_Asignacion IS NULL
                        OR Asig.Status_Asignacion = 'Documento ya liberado'
                      )
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
            ),
            Prep AS
            (
                SELECT
                    CONCAT(@PagoPrefix, RIGHT('00000' + CONVERT(VARCHAR(5), @nSequence + @nAplicaciones + RN), 5)) AS Pago_ID,
                    *
                FROM Src
            )
            INSERT INTO T3.Pago
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
            FROM Prep;

            ;WITH Src AS
            (
                SELECT
                    ROW_NUMBER() OVER
                    (
                        ORDER BY Asig.Factura, Asig.Nota_Credito, Asig.Importe
                    ) AS RN,
                    @Now AS Fecha_Trn,
                    Asig.Factura,
                    Asig.Nota_Credito,
                    RF.Distribuidor,
                    RF.Ctro,
                    RF.Cliente_V3,
                    RF.Cliente_SAP,
                    'CENTRAL' AS Rep_ID,
                    @FechaAsignacion AS Fecha_Asignacion,
                    Asig.Importe AS Valor_Pago
                FROM EAI_OWNER.X_Aplica_NotaCargo Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Factura = RF.Factura
                WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
                  AND (
                        Asig.Status_Asignacion IS NULL
                        OR Asig.Status_Asignacion = 'Documento ya liberado'
                      )
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
            ),
            Prep AS
            (
                SELECT
                    CONCAT(@PagoPrefix, RIGHT('00000' + CONVERT(VARCHAR(5), @nSequence + @nAplicaciones + RN), 5)) AS Pago_ID,
                    *
                FROM Src
            )
            INSERT INTO T3.Asignacion_Pago
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
            FROM Prep;

            UPDATE Asig
               SET Asig.Status = CONCAT('Insertada ', CONVERT(VARCHAR(19), @Now, 120))
            FROM [EAI_OWNER].[X_Aplica_NotaCargo] Asig
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND (Asig.Status_Asignacion IS NULL OR Asig.Status_Asignacion = 'Documento ya liberado')
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
              AND EXISTS
                  (SELECT 1 FROM [T3].[Registro_Fiscal] RF WHERE RF.Factura = Asig.Factura);
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

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
            'Workaround',
            @sReference,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_ASIGNACION_NOTACARGO',
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
        PRINT 'Procedimiento : WA_ASIGNA_NOTACARGO';
        PRINT 'Fecha         : ' + CONVERT(VARCHAR(19), GETDATE(), 120);
        PRINT 'Referencia    : ' + COALESCE(@sReference, '');
        PRINT 'Secuencia     : ' + COALESCE(@sStepPLSQL, '');
        PRINT 'Error         : ' + COALESCE(@sMsg, '');
        PRINT REPLICATE('-', 80);

        THROW;
    END CATCH;
END;
GO
