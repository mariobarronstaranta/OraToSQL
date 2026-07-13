CREATE OR ALTER PROCEDURE [EAI_Owner].[WA_ASIGNACION_PAGO_RFC]
(
    @pLevel INT = 0,
    @pDays  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         NVARCHAR(300),
        @nPID         INT = NULL,
        @sReference   VARCHAR(50) = NULL,
        @sStepPLSQL   VARCHAR(50) = NULL,

        @sInvDoc_Num  VARCHAR(30),
        @sInvCustomer VARCHAR(30),
        @nInvAmount   DECIMAL(15,2),
        @nInvPending  DECIMAL(15,2),
        @nPaid        DECIMAL(15,2),

        @sNCDoc_Num   VARCHAR(30),
        @sNCCustomer  VARCHAR(30),
        @nNCAmount    DECIMAL(15,2),
        @nNCPending   DECIMAL(15,2),
        @nNCPaid      DECIMAL(15,2);

    BEGIN TRY
        BEGIN TRAN;

        ---------------------------------------------------------------------
        -- 1. Actualiza importe y RFC de facturas
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrFacturas';

        IF COALESCE(@pLevel, 0) <= 10
        BEGIN
            ;WITH ScrFacturas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        COALESCE(RFD.Valor_Subt,   0) +
                        COALESCE(RFD.Valor_IVA,    0) +
                        COALESCE(RFD.Envio_Subt,   0) +
                        COALESCE(RFD.Envio_IVA,    0) +
                        COALESCE(RFD.Credito_Subt, 0) +
                        COALESCE(RFD.Credito_IVA,  0)
                    ) AS Importe
                FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON Asig.Factura = RF.Factura
                INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN [T3].[Mov_Cliente] AS Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                -- Regla Oracle original comentada:
                -- AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY
                    RFD.Factura,
                    Cte.RFC
            )
            UPDATE Asig
               SET Asig.Fact_Importe = F.Importe,
                   Asig.Fact_RFC     = F.RFC
            FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
            INNER JOIN ScrFacturas AS F
                ON Asig.Factura = F.Factura;

            -----------------------------------------------------------------
            -- 2. Actualiza importe y RFC de notas de crédito
            -----------------------------------------------------------------
            SET @sStepPLSQL = 'ScrNotas';

            ;WITH ScrNotas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        COALESCE(RFD.Valor_Subt,   0) +
                        COALESCE(RFD.Valor_IVA,    0) +
                        COALESCE(RFD.Envio_Subt,   0) +
                        COALESCE(RFD.Envio_IVA,    0) +
                        COALESCE(RFD.Credito_Subt, 0) +
                        COALESCE(RFD.Credito_IVA,  0)
                    ) AS Importe
                FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON Asig.Nota_Credito = RF.Factura
                INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN [T3].[Mov_Cliente] AS Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                -- Regla Oracle original comentada:
                -- AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY
                    RFD.Factura,
                    Cte.RFC
            )
            UPDATE Asig
               SET Asig.Cred_Importe = N.Importe,
                   Asig.Cred_RFC     = N.RFC
            FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
            INNER JOIN ScrNotas AS N
                ON Asig.Nota_Credito = N.Factura;
        END;

        ---------------------------------------------------------------------
        -- 3. Consulta pendientes de facturas y notas.
        --    Se mantiene cursor porque los procedimientos externos devuelven
        --    valores por OUTPUT. Si esos procedures pueden convertirse a TVF,
        --    esta sección debería rediseñarse set-based.
        ---------------------------------------------------------------------
        IF COALESCE(@pLevel, 0) <= 100
        BEGIN
            SET @sStepPLSQL = 'ScrFactPend';

            DECLARE curFactPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Factura
                FROM [EAI_Owner].[X_Asignacion_Pago]
                WHERE Factura IS NOT NULL;

            OPEN curFactPend;
            FETCH NEXT FROM curFactPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sInvDoc_Num  = NULL;
                SET @sInvCustomer = NULL;
                SET @nInvAmount   = NULL;
                SET @nInvPending  = NULL;
                SET @nPaid        = NULL;

                EXEC [EAI_Owner].[SF_GET_INVOICE_DATA]
                    @sReference,
                    @sInvDoc_Num  OUTPUT,
                    @sInvCustomer OUTPUT,
                    @nInvAmount   OUTPUT,
                    @nInvPending  OUTPUT,
                    @nPaid        OUTPUT;

                UPDATE [EAI_Owner].[X_Asignacion_Pago]
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @sReference;

                FETCH NEXT FROM curFactPend INTO @sReference;
            END;

            CLOSE curFactPend;
            DEALLOCATE curFactPend;

            SET @sStepPLSQL = 'ScrCredPend';

            DECLARE curCredPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Nota_Credito
                FROM [EAI_Owner].[X_Asignacion_Pago]
                WHERE Nota_Credito IS NOT NULL;

            OPEN curCredPend;
            FETCH NEXT FROM curCredPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sNCDoc_Num  = NULL;
                SET @sNCCustomer = NULL;
                SET @nNCAmount   = NULL;
                SET @nNCPending  = NULL;
                SET @nNCPaid     = NULL;

                EXEC [EAI_Owner].[SF_GET_CREDIT_DATA]
                    @sReference,
                    @sNCDoc_Num  OUTPUT,
                    @sNCCustomer OUTPUT,
                    @nNCAmount   OUTPUT,
                    @nNCPending  OUTPUT,
                    @nNCPaid     OUTPUT;

                UPDATE [EAI_Owner].[X_Asignacion_Pago]
                   SET Cred_Importe   = @nNCAmount,
                       Cred_Pendiente = @nNCPending
                 WHERE Nota_Credito = @sReference;

                FETCH NEXT FROM curCredPend INTO @sReference;
            END;

            CLOSE curCredPend;
            DEALLOCATE curCredPend;
        END;

        ---------------------------------------------------------------------
        -- 4. Marca duplicidad contra T3.Asignacion_Pago ya aplicada
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrDuplicidad';

        UPDATE Asig
           SET Asig.Duplicada = 'X',
               Asig.Status_Asignacion = 'Asignacion ya aplicada'
        FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
        INNER JOIN [T3].[Asignacion_Pago] AS AP
            ON  Asig.Factura      = AP.Factura
            AND Asig.Nota_Credito = AP.Nota_Credito
            AND Asig.Importe      = AP.Valor_Pago;

        ---------------------------------------------------------------------
        -- 5. Inconsistencias generales
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_Asig';

        ;WITH ScrStatus_Asig AS
        (
            SELECT
                Asig.Factura,
                Asig.Nota_Credito,
                Asig.Importe,
                CASE
                    WHEN COALESCE(Asig.Fact_RFC, 'XAXX010101000')
                       <> COALESCE(Asig.Cred_RFC, 'XAXX010101000')
                        THEN 'Revisar RFC'

                    WHEN CFD.Fecha_Liberacion IS NOT NULL
                        THEN 'Documento ya liberado'

                    WHEN COALESCE(Asig.Importe, 0) > 0
                     AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
                     AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
                        THEN 'Ok'

                    ELSE 'Revisar Asignacion'
                END AS Status_Asignacion
            FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
            LEFT JOIN [T3].[Registro_Fiscal] AS RF
                ON Asig.Factura = RF.Factura
            LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                ON Asig.Nota_Credito = CFD.Nota_Venta
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = S.Status_Asignacion
        FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
        INNER JOIN ScrStatus_Asig AS S
            ON  COALESCE(Asig.Factura, '')      = COALESCE(S.Factura, '')
            AND COALESCE(Asig.Nota_Credito, '') = COALESCE(S.Nota_Credito, '')
            AND COALESCE(Asig.Importe, 0)       = COALESCE(S.Importe, 0)
        WHERE S.Status_Asignacion <> 'Ok';

        ---------------------------------------------------------------------
        -- 6. Duplicidad interna por factura + nota crédito
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_AsigDup';

        ;WITH Dup AS
        (
            SELECT
                Nota_Credito,
                Factura,
                COUNT(*) AS Duplicidad
            FROM [EAI_Owner].[X_Asignacion_Pago]
            GROUP BY Nota_Credito, Factura
            HAVING COUNT(*) > 1
        )
        UPDATE Asig
           SET Asig.Status_Asignacion =
               CONCAT('Duplicidad de Asignacion ( ', CONVERT(VARCHAR(20), Dup.Duplicidad), ' )')
        FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
        INNER JOIN Dup
            ON  Asig.Nota_Credito = Dup.Nota_Credito
            AND Asig.Factura      = Dup.Factura;

        ---------------------------------------------------------------------
        -- 7. Excedente por nota de crédito
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_CredExc';

        ;WITH CredExc AS
        (
            SELECT
                Nota_Credito,
                SUM(COALESCE(Importe, 0)) AS ImporteTotal,
                MAX(COALESCE(Cred_Pendiente, 0)) AS Cred_Pendiente,
                COUNT(*) AS Duplicidad
            FROM [EAI_Owner].[X_Asignacion_Pago]
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               AND SUM(COALESCE(Importe, 0)) > MAX(COALESCE(Cred_Pendiente, 0))
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
        INNER JOIN CredExc AS CE
            ON Asig.Nota_Credito = CE.Nota_Credito;

        ---------------------------------------------------------------------
        -- 8. Excedente por factura
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_FactExc';

        ;WITH FactExc AS
        (
            SELECT
                Factura,
                SUM(COALESCE(Importe, 0)) AS ImporteTotal,
                MAX(COALESCE(Fact_Pendiente, 0)) AS Fact_Pendiente,
                COUNT(*) AS Duplicidad
            FROM [EAI_Owner].[X_Asignacion_Pago]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(COALESCE(Importe, 0)) > MAX(COALESCE(Fact_Pendiente, 0))
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
        INNER JOIN FactExc AS FE
            ON Asig.Factura = FE.Factura;

        ---------------------------------------------------------------------
        -- 9. Liberación / inserción final
        ---------------------------------------------------------------------
        IF COALESCE(@pLevel, 0) >= 1000
        BEGIN
            SET @sStepPLSQL = 'ScrLiberacion';

            ;WITH LiberacionBase AS
            (
                SELECT
                    CONCAT(
                        FORMAT(GETDATE(), 'yy'),
                        RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, GETDATE())), 3),
                        FORMAT(GETDATE(), 'HH'),
                        RIGHT(
                            '00000' + CONVERT(
                                VARCHAR(5),
                                ROW_NUMBER() OVER
                                (
                                    ORDER BY
                                        Asig.Factura,
                                        Asig.Nota_Credito,
                                        Asig.Importe
                                )
                            ),
                            5
                        )
                    ) AS Pago_ID,
                    GETDATE() AS Fecha_Trn,
                    Asig.Factura,
                    Asig.Nota_Credito,
                    RF.Distribuidor,
                    RF.Ctro,
                    RF.Cliente_V3,
                    RF.Cliente_SAP,
                    'CENTRAL' AS Rep_ID,
                    CAST(DATEADD(DAY, -COALESCE(@pDays, 0), GETDATE()) AS DATE) AS Fecha_Asignacion,
                    Asig.Importe AS Valor_Pago
                FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON Asig.Factura = RF.Factura
                WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
                  AND
                  (
                        Asig.Status_Asignacion IS NULL
                     OR (
                            Asig.Status_Asignacion = 'Documento ya liberado'
                        AND Asig.Fact_RFC = 'XAXX010101000'
                        AND Asig.Cred_RFC = 'XAXX010101000'
                        )
                  )
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
                  AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe
            )
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
                Pago_ID AS Asignacion_ID,
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
            FROM LiberacionBase;

            UPDATE Asig
               SET Asig.Status =
                   CONCAT('Insertada ', FORMAT(GETDATE(), 'yyyyMMdd HH:mm:ss'))
            FROM [EAI_Owner].[X_Asignacion_Pago] AS Asig
            INNER JOIN [T3].[Registro_Fiscal] AS RF
                ON Asig.Factura = RF.Factura
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND
              (
                    Asig.Status_Asignacion IS NULL
                 OR (
                        Asig.Status_Asignacion = 'Documento ya liberado'
                    AND Asig.Fact_RFC = 'XAXX010101000'
                    AND Asig.Cred_RFC = 'XAXX010101000'
                    )
              )
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
              AND COALESCE(Asig.Cred_Pendiente, 0) >= Asig.Importe;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(
            CONCAT(
                ERROR_NUMBER(),
                '-',
                ERROR_MESSAGE(),
                ' | Proc: ',
                COALESCE(ERROR_PROCEDURE(), 'WA_ASIGNACION_PAGO_RFC'),
                ' | Line: ',
                ERROR_LINE()
            ),
            250
        );

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
        PRINT 'Procedimiento : WA_ASIGNACION_PAGO_RFC';
        PRINT CONCAT('Fecha         : ', FORMAT(GETDATE(), 'yyyyMMdd HH:mm:ss'));
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, ''));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', COALESCE(@sMsg, ''));
        PRINT REPLICATE('-', 80);

        THROW;
    END CATCH;
END;
GO