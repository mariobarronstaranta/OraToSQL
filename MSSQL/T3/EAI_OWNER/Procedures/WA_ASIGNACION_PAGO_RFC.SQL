/*
    Homologo SQL Server de EAI_OWNER.WA_ASIGNACION_PAGO_RFC (Oracle).

    Objetivo funcional:
      1. Completar importes y RFC de factura y nota de credito.
      2. Consultar saldos pendientes mediante los procedures auxiliares.
      3. Detectar asignaciones aplicadas, inconsistentes, duplicadas o excedidas.
      4. Con @pLevel >= 1000, liberar las asignaciones validas.

    Niveles conservados del procedure Oracle:
      - @pLevel <= 10  : actualiza importes fiscales y RFC.
      - @pLevel <= 100 : actualiza saldos pendientes.
      - Todos          : ejecuta las validaciones de negocio.
      - @pLevel >= 1000: inserta en T3.Asignacion_Pago.

    X_ASIGNACION_PAGO no tiene una llave equivalente al ROWID de Oracle. Las
    actualizaciones usan las llaves de negocio del origen. Durante la liberacion,
    OUTPUT conserva el conjunto realmente insertado para no marcar como insertada
    una asignacion que no llego al destino.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNACION_PAGO_RFC]
(
    @pLevel INT = 0,
    @pDays  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    -- Oracle confirma en EXCEPTION el trabajo realizado antes del error.
    -- OFF permite confirmar la transaccion si SQL Server aun la considera valida.
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode   VARCHAR(30),
        @sMsg         VARCHAR(300),
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
        @nNCAmount      DECIMAL(15,2),
        @nNCPending     DECIMAL(15,2),
        @nNCPaid        DECIMAL(15,2),
        @releaseDateTime DATETIME2(0),
        @paymentPrefix   VARCHAR(7);

    -- Sustituto operativo del ROWID utilizado por el cursor Oracle durante
    -- la liberacion. Solo contiene filas que el INSERT acepto realmente.
    DECLARE @Released TABLE
    (
        Factura       VARCHAR(30)   NULL,
        Nota_Credito  VARCHAR(30)   NULL,
        Valor_Pago    DECIMAL(15,2) NULL
    );

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
                FROM
                (
                    -- Oracle agrupa por ROWID. DISTINCT evita multiplicar el
                    -- detalle cuando una factura se repite en staging.
                    SELECT DISTINCT Factura
                    FROM [EAI_OWNER].[X_Asignacion_Pago]
                    WHERE Factura IS NOT NULL
                ) AS Asig
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
            FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
                FROM
                (
                    SELECT DISTINCT Nota_Credito
                    FROM [EAI_OWNER].[X_Asignacion_Pago]
                    WHERE Nota_Credito IS NOT NULL
                ) AS Asig
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
            FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
                FROM [EAI_OWNER].[X_Asignacion_Pago];

            OPEN curFactPend;
            FETCH NEXT FROM curFactPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sInvDoc_Num  = NULL;
                SET @sInvCustomer = NULL;
                SET @nInvAmount   = NULL;
                SET @nInvPending  = NULL;
                SET @nPaid        = NULL;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @sReference,
                    @sInvDoc_Num  OUTPUT,
                    @sInvCustomer OUTPUT,
                    @nInvAmount   OUTPUT,
                    @nInvPending  OUTPUT,
                    @nPaid        OUTPUT;

                UPDATE [EAI_OWNER].[X_Asignacion_Pago]
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @sReference;

                FETCH NEXT FROM curFactPend INTO @sReference;
            END;

            CLOSE curFactPend;
            DEALLOCATE curFactPend;

            SET @sStepPLSQL = 'ScrCredPend';

            DECLARE curCredPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Nota_Credito
                FROM [EAI_OWNER].[X_Asignacion_Pago];

            OPEN curCredPend;
            FETCH NEXT FROM curCredPend INTO @sReference;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sNCDoc_Num  = NULL;
                SET @sNCCustomer = NULL;
                SET @nNCAmount   = NULL;
                SET @nNCPending  = NULL;
                SET @nNCPaid     = NULL;

                EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                    @sReference,
                    @sNCDoc_Num  OUTPUT,
                    @sNCCustomer OUTPUT,
                    @nNCAmount   OUTPUT,
                    @nNCPending  OUTPUT,
                    @nNCPaid     OUTPUT;

                UPDATE [EAI_OWNER].[X_Asignacion_Pago]
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
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
        INNER JOIN [T3].[Asignacion_Pago] AS AP
            ON  Asig.Factura      = AP.Factura
            AND Asig.Nota_Credito = AP.Nota_Credito
            AND Asig.Importe      = AP.Valor_Pago;

        ---------------------------------------------------------------------
        -- 5. Inconsistencias generales
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_Asig';

        UPDATE Asig
           SET Asig.Status_Asignacion =
               CASE
                   WHEN COALESCE(Asig.Fact_RFC, 'XAXX010101000')
                      <> COALESCE(Asig.Cred_RFC, 'XAXX010101000')
                       THEN 'Revisar RFC'
                   WHEN CFD.Fecha_Liberacion IS NOT NULL
                       THEN 'Documento ya liberado'
                   ELSE 'Revisar Asignacion'
               END
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
        LEFT JOIN [T3].[Registro_Fiscal] AS RF
            ON Asig.Factura = RF.Factura
        LEFT JOIN [T3].[CFDI_Documentos] AS CFD
            ON Asig.Nota_Credito = CFD.Nota_Venta
        WHERE
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
            END <> 'Ok';

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
            FROM [EAI_OWNER].[X_Asignacion_Pago]
            GROUP BY Nota_Credito, Factura
            HAVING COUNT(*) > 1
        )
        UPDATE Asig
           SET Asig.Status_Asignacion =
               CONCAT('Duplicidad de Asignacion ( ', CONVERT(VARCHAR(20), Dup.Duplicidad), ' )')
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
                SUM(Importe) AS ImporteTotal,
                MAX(Cred_Pendiente) AS Cred_Pendiente,
                COUNT(*) AS Duplicidad
            FROM [EAI_OWNER].[X_Asignacion_Pago]
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Cred_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
                SUM(Importe) AS ImporteTotal,
                MAX(Fact_Pendiente) AS Fact_Pendiente,
                COUNT(*) AS Duplicidad
            FROM [EAI_OWNER].[X_Asignacion_Pago]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
        INNER JOIN FactExc AS FE
            ON Asig.Factura = FE.Factura;

        ---------------------------------------------------------------------
        -- 9. Liberación / inserción final
        ---------------------------------------------------------------------
        IF COALESCE(@pLevel, 0) >= 1000
        BEGIN
            SET @sStepPLSQL = 'ScrLiberacion';

            SET @releaseDateTime = SYSDATETIME();
            SET @paymentPrefix =
                  RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @releaseDateTime)), 2)
                + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @releaseDateTime)), 3)
                + RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, @releaseDateTime)), 2);

            -- Se usa una sola fecha para que Pago_ID, Fecha_Trn,
            -- Fecha_Asignacion y el texto de Status sean consistentes.
            ;WITH Eligible AS
            (
                SELECT
                    Asig.Factura,
                    Asig.Nota_Credito,
                    RF.Distribuidor,
                    RF.Ctro,
                    RF.Cliente_V3,
                    RF.Cliente_SAP,
                    'CENTRAL' AS Rep_ID,
                    Asig.Importe AS Valor_Pago,
                    -- Oracle usa ROWNUM sin ORDER BY. No se inventa aqui una
                    -- prioridad de negocio que el procedure original no posee.
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RN
                FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
            ),
            LiberacionBase AS
            (
                SELECT
                    -- LPAD tambien recorta cuando el valor excede 5 caracteres;
                    -- LEFT conserva ese comportamiento poco evidente de Oracle.
                    @paymentPrefix
                    + CASE
                        WHEN LEN(S.SequenceText) >= 5 THEN LEFT(S.SequenceText, 5)
                        ELSE RIGHT('00000' + S.SequenceText, 5)
                      END AS Pago_ID,
                    @releaseDateTime AS Fecha_Trn,
                    E.Factura,
                    E.Nota_Credito,
                    E.Distribuidor,
                    E.Ctro,
                    E.Cliente_V3,
                    E.Cliente_SAP,
                    E.Rep_ID,
                    CAST(DATEADD(DAY, -COALESCE(@pDays, 0), @releaseDateTime) AS DATE)
                        AS Fecha_Asignacion,
                    E.Valor_Pago
                FROM Eligible E
                CROSS APPLY
                (
                    SELECT SequenceText = CONVERT(VARCHAR(20), E.RN)
                ) S
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
            OUTPUT
                INSERTED.Factura,
                INSERTED.Nota_Credito,
                INSERTED.Valor_Pago
            INTO @Released
            (
                Factura,
                Nota_Credito,
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

            -- Oracle actualiza por ROWID despues de cada INSERT. Al no existir
            -- ROWID en SQL Server, @Released limita la marca al conjunto que
            -- efectivamente se inserto y se repite la elegibilidad completa.
            UPDATE Asig
               SET Asig.Status =
                   CONCAT('Insertada ', CONVERT(CHAR(8), @releaseDateTime, 112),
                          ' ', CONVERT(CHAR(8), @releaseDateTime, 108))
            FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
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
              AND EXISTS
                  (
                      SELECT 1
                      FROM @Released AS R
                      WHERE R.Factura = Asig.Factura
                        -- Oracle permite que Nota_Credito sea NULL en esta
                        -- etapa; la segunda condicion emula esa igualdad.
                        AND
                        (
                               R.Nota_Credito = Asig.Nota_Credito
                            OR (R.Nota_Credito IS NULL AND Asig.Nota_Credito IS NULL)
                        )
                        AND R.Valor_Pago = Asig.Importe
                  );
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', CONVERT(VARCHAR(20), ERROR_NUMBER()));
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        IF CURSOR_STATUS('local', 'curFactPend') >= 0
            CLOSE curFactPend;
        IF CURSOR_STATUS('local', 'curFactPend') > -2
            DEALLOCATE curFactPend;

        IF CURSOR_STATUS('local', 'curCredPend') >= 0
            CLOSE curCredPend;
        IF CURSOR_STATUS('local', 'curCredPend') > -2
            DEALLOCATE curCredPend;

        -- Oracle confirma el trabajo previo en WHEN OTHERS. Solo una
        -- transaccion no confirmable (estado -1) obliga a hacer ROLLBACK.
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
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'WA_ASIGNACION_PAGO',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT REPLICATE('-', 80);
        PRINT 'Problemas en la ejecucion del Procedimiento';
        PRINT 'FAVOR DE ESCALAR LOS SIGUIENTES DATOS :';
        -- El texto Oracle usa WA_ASIGNACION_PAGO, aunque el objeto termina RFC.
        PRINT 'Procedimiento : WA_ASIGNACION_PAGO';
        PRINT CONCAT('Fecha         : ', CONVERT(CHAR(8), SYSDATETIME(), 112),
                     ' ', CONVERT(CHAR(8), SYSDATETIME(), 108));
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, ''));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', COALESCE(@sMsg, ''));
        PRINT REPLICATE('-', 80);

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle registra el error y finaliza sin RAISE.
        RETURN;
    END CATCH;
END;
GO
