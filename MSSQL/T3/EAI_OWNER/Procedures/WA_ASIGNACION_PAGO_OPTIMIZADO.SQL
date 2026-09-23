/*
    Procedure : EAI_OWNER.WA_ASIGNACION_PAGO_OPTIMIZADO
    Objetivo  : Enriquecer, validar y liberar asignaciones entre facturas y
                notas de credito cargadas en EAI_OWNER.X_ASIGNACION_PAGO.

    Optimizaciones:
    - Calcula la informacion fiscal de facturas y notas en una sola lectura.
    - Acumula los saldos obtenidos por procedures OUTPUT y los aplica en bloque.
    - Usa un semi-join para detectar asignaciones previamente aplicadas.
    - Materializa una sola vez las filas que se liberaran.

    El procedimiento original permanece sin cambios para permitir comparacion
    y despliegue controlado.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNACION_PAGO_OPTIMIZADO]
(
    @pLevel INT = 0,
    @pDays  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle confirma en EXCEPTION el trabajo anterior al error. XACT_ABORT
        permanece OFF para conservar esa regla cuando la transaccion siga en
        estado confirmable.
    */
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode              VARCHAR(30),
        @sMsg                    VARCHAR(300),
        @nPID                    INT,
        @sReference              VARCHAR(50),
        @sStepPLSQL              VARCHAR(50),
        @releaseDateTime         DATETIME2(0),
        @paymentPrefix           VARCHAR(7),
        @Factura                 VARCHAR(50),
        @NotaCredito             VARCHAR(50),
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
        @workRowCount            BIGINT,
        @factPendingApplyStarted BIT = 0,
        @credPendingApplyStarted BIT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @sStepPLSQL = 'ScrFacturas';

        SELECT @workRowCount = COUNT_BIG(*)
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO];

        -------------------------------------------------------------------
        -- Importes fiscales y RFC
        -------------------------------------------------------------------
        IF ISNULL(@pLevel, 0) <= 10
        BEGIN
            /*
                En cargas pequenas el costo fijo de tempdb supera el ahorro de
                compartir la agregacion. Esta ruta conserva las dos consultas
                set-based del original y evita crear objetos temporales.
            */
            IF @workRowCount <= 50
            BEGIN
                ;WITH InvoiceFiscal AS
                (
                    SELECT
                        RFD.Factura,
                        C.RFC,
                        SUM
                        (
                            ISNULL(RFD.Valor_Subt, 0)
                          + ISNULL(RFD.Valor_IVA, 0)
                          + ISNULL(RFD.Envio_Subt, 0)
                          + ISNULL(RFD.Envio_IVA, 0)
                          + ISNULL(RFD.Credito_Subt, 0)
                          + ISNULL(RFD.Credito_IVA, 0)
                        ) AS Amount
                    FROM
                    (
                        SELECT DISTINCT Factura
                        FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
                        WHERE Factura IS NOT NULL
                    ) AS A
                    INNER JOIN [T3].[Registro_Fiscal] AS RF
                        ON RF.Factura = A.Factura
                    INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                        ON RFD.Factura = RF.Factura
                    INNER JOIN [T3].[Cliente] AS C
                        ON C.Cliente_SAP = RF.Cliente_SAP
                       AND RF.Fecha_Factura BETWEEN C.Fecha_Ini_Vig
                                                AND C.Fecha_Fin_Vig
                    GROUP BY RFD.Factura, C.RFC
                )
                UPDATE A
                   SET A.Fact_Importe = F.Amount,
                       A.Fact_RFC = F.RFC
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN InvoiceFiscal AS F
                    ON F.Factura = A.Factura;

                SET @sStepPLSQL = 'ScrNotas';

                ;WITH CreditFiscal AS
                (
                    SELECT
                        RFD.Factura,
                        C.RFC,
                        SUM
                        (
                            ISNULL(RFD.Valor_Subt, 0)
                          + ISNULL(RFD.Valor_IVA, 0)
                          + ISNULL(RFD.Envio_Subt, 0)
                          + ISNULL(RFD.Envio_IVA, 0)
                          + ISNULL(RFD.Credito_Subt, 0)
                          + ISNULL(RFD.Credito_IVA, 0)
                        ) AS Amount
                    FROM
                    (
                        SELECT DISTINCT Nota_Credito
                        FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
                        WHERE Nota_Credito IS NOT NULL
                    ) AS A
                    INNER JOIN [T3].[Registro_Fiscal] AS RF
                        ON RF.Factura = A.Nota_Credito
                    INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                        ON RFD.Factura = RF.Factura
                    INNER JOIN [T3].[Cliente] AS C
                        ON C.Cliente_SAP = RF.Cliente_SAP
                       AND RF.Fecha_Factura BETWEEN C.Fecha_Ini_Vig
                                                AND C.Fecha_Fin_Vig
                    GROUP BY RFD.Factura, C.RFC
                )
                UPDATE A
                   SET A.Cred_Importe = F.Amount,
                       A.Cred_RFC = F.RFC
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN CreditFiscal AS F
                    ON F.Factura = A.Nota_Credito;
            END
            ELSE
            BEGIN
            /*
                Facturas y notas comparten las mismas tablas fiscales. UNION
                forma el catalogo de documentos requerido y evita agregar dos
                veces el detalle cuando un documento aparece en ambos roles.
            */
            CREATE TABLE #FiscalDocument
            (
                DocumentNumber VARCHAR(30) NOT NULL,
                RFC            VARCHAR(15) NULL,
                Amount         DECIMAL(15,2) NULL
            );

            ;WITH RequestedDocument AS
            (
                SELECT Factura AS DocumentNumber
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
                WHERE Factura IS NOT NULL

                UNION

                SELECT Nota_Credito
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
                WHERE Nota_Credito IS NOT NULL
            )
            INSERT INTO #FiscalDocument (DocumentNumber, RFC, Amount)
            SELECT
                RFD.Factura,
                C.RFC,
                CONVERT
                (
                    DECIMAL(15,2),
                    SUM
                    (
                        ISNULL(RFD.Valor_Subt, 0)
                      + ISNULL(RFD.Valor_IVA, 0)
                      + ISNULL(RFD.Envio_Subt, 0)
                      + ISNULL(RFD.Envio_IVA, 0)
                      + ISNULL(RFD.Credito_Subt, 0)
                      + ISNULL(RFD.Credito_IVA, 0)
                    )
                )
            FROM RequestedDocument AS D
            INNER JOIN [T3].[Registro_Fiscal] AS RF
                ON RF.Factura = D.DocumentNumber
            INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                ON RFD.Factura = RF.Factura
            INNER JOIN [T3].[Cliente] AS C
                ON C.Cliente_SAP = RF.Cliente_SAP
               AND RF.Fecha_Factura BETWEEN C.Fecha_Ini_Vig
                                        AND C.Fecha_Fin_Vig
            GROUP BY RFD.Factura, C.RFC;

            CREATE INDEX IX_FiscalDocument_DocumentNumber
                ON #FiscalDocument (DocumentNumber);

            SET @sStepPLSQL = 'ScrFacturas';

            UPDATE A
               SET A.Fact_Importe = F.Amount,
                   A.Fact_RFC = F.RFC
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
            INNER JOIN #FiscalDocument AS F
                ON F.DocumentNumber = A.Factura;

            SET @sStepPLSQL = 'ScrNotas';

            UPDATE A
               SET A.Cred_Importe = F.Amount,
                   A.Cred_RFC = F.RFC
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
            INNER JOIN #FiscalDocument AS F
                ON F.DocumentNumber = A.Nota_Credito;
            END;
        END;

        -------------------------------------------------------------------
        -- Saldos pendientes
        -------------------------------------------------------------------
        IF ISNULL(@pLevel, 0) <= 100
        BEGIN
            IF @workRowCount > 50
            BEGIN
                CREATE TABLE #FactPending
                (
                    Factura  VARCHAR(50) NULL,
                    Pending  DECIMAL(15,2) NULL
                );

                CREATE TABLE #CreditPending
                (
                    Nota_Credito VARCHAR(50) NULL,
                    Amount       DECIMAL(15,2) NULL,
                    Pending      DECIMAL(15,2) NULL
                );
            END;

            /*
                Los procedures de consulta devuelven valores OUTPUT y deben
                conservar una llamada por documento distinto. El cursor solo
                recolecta resultados; la tabla de carga se actualiza una vez.
            */
            SET @sStepPLSQL = 'ScrFactPend';

            DECLARE cFactPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Factura
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO];

            OPEN cFactPend;
            FETCH NEXT FROM cFactPend INTO @Factura;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sReference = @Factura;

                SELECT
                    @sInvDoc_Num = NULL,
                    @sInvCustomer = NULL,
                    @nInvAmount = 0,
                    @nInvPending = 0,
                    @nPaid = 0;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @pInvoiceRef = @Factura,
                    @rtDoc_Num = @sInvDoc_Num OUTPUT,
                    @rtCliente_SAP = @sInvCustomer OUTPUT,
                    @rtAmount = @nInvAmount OUTPUT,
                    @rtPending = @nInvPending OUTPUT,
                    @rtPaid = @nPaid OUTPUT;

                IF @workRowCount <= 50
                BEGIN
                    UPDATE [EAI_OWNER].[X_ASIGNACION_PAGO]
                       SET Fact_Pendiente = @nInvPending
                     WHERE Factura = @Factura;
                END
                ELSE
                BEGIN
                    INSERT INTO #FactPending (Factura, Pending)
                    VALUES (@Factura, @nInvPending);
                END;

                FETCH NEXT FROM cFactPend INTO @Factura;
            END;

            CLOSE cFactPend;
            DEALLOCATE cFactPend;

            IF @workRowCount > 50
            BEGIN
                CREATE INDEX IX_FactPending_Factura
                    ON #FactPending (Factura);

                /*
                    La bandera se activa antes del UPDATE. Si ese UPDATE falla,
                    el CATCH no intenta ejecutar nuevamente la instruccion.
                */
                SET @factPendingApplyStarted = 1;

                UPDATE A
                   SET A.Fact_Pendiente = P.Pending
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN #FactPending AS P
                    ON P.Factura = A.Factura;
            END;

            SET @sStepPLSQL = 'ScrCredPend';

            DECLARE cCredPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Nota_Credito
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO];

            OPEN cCredPend;
            FETCH NEXT FROM cCredPend INTO @NotaCredito;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sReference = @NotaCredito;

                SELECT
                    @sNCDoc_Num = NULL,
                    @sNCCustomer = NULL,
                    @nNCAmount = 0,
                    @nNCPending = 0,
                    @nNCPaid = 0;

                EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                    @pInvoiceRef = @NotaCredito,
                    @rtDoc_Num = @sNCDoc_Num OUTPUT,
                    @rtCliente_SAP = @sNCCustomer OUTPUT,
                    @rtAmount = @nNCAmount OUTPUT,
                    @rtPending = @nNCPending OUTPUT,
                    @rtPaid = @nNCPaid OUTPUT;

                IF @workRowCount <= 50
                BEGIN
                    UPDATE [EAI_OWNER].[X_ASIGNACION_PAGO]
                       SET Cred_Importe = @nNCAmount,
                           Cred_Pendiente = @nNCPending
                     WHERE Nota_Credito = @NotaCredito;
                END
                ELSE
                BEGIN
                    INSERT INTO #CreditPending (Nota_Credito, Amount, Pending)
                    VALUES (@NotaCredito, @nNCAmount, @nNCPending);
                END;

                FETCH NEXT FROM cCredPend INTO @NotaCredito;
            END;

            CLOSE cCredPend;
            DEALLOCATE cCredPend;

            IF @workRowCount > 50
            BEGIN
                CREATE INDEX IX_CreditPending_NotaCredito
                    ON #CreditPending (Nota_Credito);

                SET @credPendingApplyStarted = 1;

                UPDATE A
                   SET A.Cred_Importe = P.Amount,
                       A.Cred_Pendiente = P.Pending
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN #CreditPending AS P
                    ON P.Nota_Credito = A.Nota_Credito;
            END;
        END;

        -------------------------------------------------------------------
        -- Asignaciones previamente aplicadas
        -------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrDuplicidad';

        UPDATE A
           SET A.Duplicada = 'X',
               A.Status_Asignacion = 'Asignacion ya aplicada'
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
        WHERE EXISTS
        (
            SELECT 1
            FROM [T3].[Asignacion_Pago] AS AP
            WHERE AP.Factura = A.Factura
              AND AP.Nota_Credito = A.Nota_Credito
              AND AP.Valor_Pago = A.Importe
        );

        -------------------------------------------------------------------
        -- Estado de RFC, liberacion e importes
        -------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_Asig';

        UPDATE A
           SET A.Status_Asignacion = S.NewStatus
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
        LEFT JOIN [T3].[CFDI_Documentos] AS CFD
            ON CFD.Nota_Venta = A.Nota_Credito
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN ISNULL(A.Fact_RFC, 'XAXX010101000')
                       <> ISNULL(A.Cred_RFC, 'XAXX010101000')
                        THEN 'Revisar RFC'
                    WHEN CFD.Fecha_Liberacion IS NOT NULL
                        THEN 'Documento ya liberado'
                    WHEN ISNULL(A.Importe, 0) > 0
                     AND ISNULL(A.Fact_Pendiente, 0) >= A.Importe
                     AND ISNULL(A.Cred_Pendiente, 0) >= A.Importe
                        THEN 'Ok'
                    ELSE 'Revisar Asignacion'
                END
            )
        ) AS S(NewStatus)
        -- Igual que Oracle, las filas validas no se escriben con estado Ok.
        WHERE S.NewStatus <> 'Ok';

        -------------------------------------------------------------------
        -- Duplicidad interna
        -------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_AsigDup';

        ;WITH PairDuplicate AS
        (
            SELECT Nota_Credito, Factura, COUNT(*) AS DuplicateCount
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
            GROUP BY Nota_Credito, Factura
            HAVING COUNT(*) > 1
        )
        UPDATE A
           SET A.Status_Asignacion = CONCAT
               (
                   'Duplicidad de Asignacion ( ',
                   D.DuplicateCount,
                   ' )'
               )
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
        INNER JOIN PairDuplicate AS D
            ON D.Nota_Credito = A.Nota_Credito
           AND D.Factura = A.Factura;

        -------------------------------------------------------------------
        -- Excedentes por nota de credito y por factura
        -------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_CredExc';

        ;WITH CreditExcess AS
        (
            SELECT Nota_Credito
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Cred_Pendiente)
        )
        UPDATE A
           SET A.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
        INNER JOIN CreditExcess AS E
            ON E.Nota_Credito = A.Nota_Credito;

        SET @sStepPLSQL = 'ScrStatus_FactExc';

        ;WITH InvoiceExcess AS
        (
            SELECT Factura
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE A
           SET A.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
        INNER JOIN InvoiceExcess AS E
            ON E.Factura = A.Factura;

        -------------------------------------------------------------------
        -- Liberacion
        -------------------------------------------------------------------
        IF ISNULL(@pLevel, 0) >= 1000
        BEGIN
            SET @sStepPLSQL = 'ScrLiberacion';
            SET @releaseDateTime = SYSDATETIME();
            SET @paymentPrefix =
                  RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @releaseDateTime)), 2)
                + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @releaseDateTime)), 3)
                + RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, @releaseDateTime)), 2);

            CREATE TABLE #ReleaseRow
            (
                Pago_ID         VARCHAR(50) NOT NULL,
                Factura         VARCHAR(30) NULL,
                Nota_Credito    VARCHAR(30) NULL,
                Importe         DECIMAL(15,2) NULL,
                Distribuidor    DECIMAL(4,0) NULL,
                Ctro            VARCHAR(4) NULL,
                Cliente_V3      VARCHAR(15) NULL,
                Cliente_SAP     VARCHAR(10) NULL
            );

            ;WITH Eligible AS
            (
                SELECT
                    A.Factura,
                    A.Nota_Credito,
                    A.Importe,
                    RF.Distribuidor,
                    RF.Ctro,
                    RF.Cliente_V3,
                    RF.Cliente_SAP,
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON RF.Factura = A.Factura
                WHERE ISNULL(A.Duplicada, ' ') <> 'X'
                  AND
                  (
                      A.Status_Asignacion IS NULL
                      OR
                      (
                          A.Status_Asignacion = 'Documento ya liberado'
                          AND A.Fact_RFC = 'XAXX010101000'
                          AND A.Cred_RFC = 'XAXX010101000'
                      )
                  )
                  AND ISNULL(A.Importe, 0) > 0
                  AND ISNULL(A.Fact_Pendiente, 0) >= A.Importe
                  AND ISNULL(A.Cred_Pendiente, 0) >= A.Importe
            )
            INSERT INTO #ReleaseRow
            (
                Pago_ID, Factura, Nota_Credito, Importe, Distribuidor,
                Ctro, Cliente_V3, Cliente_SAP
            )
            SELECT
                @paymentPrefix
                + CASE
                    WHEN LEN(CONVERT(VARCHAR(20), 2500 + RN)) >= 5
                        THEN LEFT(CONVERT(VARCHAR(20), 2500 + RN), 5)
                    ELSE RIGHT('00000' + CONVERT(VARCHAR(20), 2500 + RN), 5)
                  END,
                Factura,
                Nota_Credito,
                Importe,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP
            FROM Eligible;

            CREATE INDEX IX_ReleaseRow_Factura
                ON #ReleaseRow (Factura);

            INSERT INTO [T3].[Asignacion_Pago]
            (
                Pago_ID, Asignacion_ID, Fecha_Trn, Factura, Nota_Credito,
                Distribuidor, Ctro, Cliente_V3, Cliente_SAP, Rep_ID,
                Fecha_Asignacion, Valor_Pago
            )
            SELECT
                R.Pago_ID,
                R.Pago_ID,
                @releaseDateTime,
                R.Factura,
                R.Nota_Credito,
                R.Distribuidor,
                R.Ctro,
                R.Cliente_V3,
                R.Cliente_SAP,
                'CENTRAL',
                CAST(DATEADD(DAY, -ISNULL(@pDays, 0), @releaseDateTime) AS DATE),
                R.Importe
            FROM #ReleaseRow AS R;

            /*
                Se conserva el predicado completo de Oracle. #ReleaseRow evita
                consultar de nuevo Registro_Fiscal solo para comprobar que la
                factura participo en la liberacion.
            */
            UPDATE A
               SET A.[Status] = CONCAT
                   (
                       'Insertada ',
                       CONVERT(CHAR(8), @releaseDateTime, 112),
                       ' ',
                       CONVERT(CHAR(8), @releaseDateTime, 108)
                   )
            FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
            WHERE ISNULL(A.Duplicada, ' ') <> 'X'
              AND
              (
                  A.Status_Asignacion IS NULL
                  OR
                  (
                      A.Status_Asignacion = 'Documento ya liberado'
                      AND A.Fact_RFC = 'XAXX010101000'
                      AND A.Cred_RFC = 'XAXX010101000'
                  )
              )
              AND ISNULL(A.Importe, 0) > 0
              AND ISNULL(A.Fact_Pendiente, 0) >= A.Importe
              AND ISNULL(A.Cred_Pendiente, 0) >= A.Importe
              AND EXISTS
                  (
                      SELECT 1
                      FROM #ReleaseRow AS R
                      WHERE R.Factura = A.Factura
                  );
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        IF CURSOR_STATUS('local', 'cFactPend') >= 0
            CLOSE cFactPend;
        IF CURSOR_STATUS('local', 'cFactPend') > -2
            DEALLOCATE cFactPend;

        IF CURSOR_STATUS('local', 'cCredPend') >= 0
            CLOSE cCredPend;
        IF CURSOR_STATUS('local', 'cCredPend') > -2
            DEALLOCATE cCredPend;

        /*
            Si una consulta OUTPUT falla despues de documentos exitosos, se
            aplican los resultados ya recolectados antes del COMMIT del error.
            Esto conserva el trabajo previo que Oracle deja confirmado.
        */
        IF XACT_STATE() = 1
        BEGIN
            IF OBJECT_ID('tempdb..#FactPending') IS NOT NULL
               AND @factPendingApplyStarted = 0
            BEGIN
                SET @factPendingApplyStarted = 1;

                UPDATE A
                   SET A.Fact_Pendiente = P.Pending
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN #FactPending AS P
                    ON P.Factura = A.Factura;
            END;

            IF OBJECT_ID('tempdb..#CreditPending') IS NOT NULL
               AND @credPendingApplyStarted = 0
            BEGIN
                SET @credPendingApplyStarted = 1;

                UPDATE A
                   SET A.Cred_Importe = P.Amount,
                       A.Cred_Pendiente = P.Pending
                FROM [EAI_OWNER].[X_ASIGNACION_PAGO] AS A
                INNER JOIN #CreditPending AS P
                    ON P.Nota_Credito = A.Nota_Credito;
            END;
        END;

        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
            QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
            RETRY_COUNT, [Sequence], PARENT_ROW_ID
        )
        VALUES
        (
            'Workaround', @sReference, GETDATE(), NULL, @nPID, 'Error',
            'WA_ASIGNACION_PAGO', @sMsg, 'TSQL', @sErrorCode,
            NULL, NULL, NULL
        );

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        PRINT REPLICATE('-', 80);
        PRINT 'Problemas en la ejecucion del Procedimiento';
        PRINT 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :';
        PRINT 'Procedimiento : WA_ASIGNACION_PAGO_OPTIMIZADO';
        PRINT CONCAT('Fecha         : ', CONVERT(CHAR(8), SYSDATETIME(), 112),
                     ' ', CONVERT(CHAR(8), SYSDATETIME(), 108));
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, 'NULL'));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, 'NULL'));
        PRINT CONCAT('Error         : ', @sMsg);
        PRINT REPLICATE('-', 80);

        -- Igual que Oracle y el procedure SQL original, no relanza el error.
        RETURN;
    END CATCH;
END;
GO
