/*
    Homologo SQL Server de EAI_OWNER.WA_ASIGNACION_PAGO_INSERT (Oracle).

    Objetivo:
      Enriquecer y validar pagos cargados en XP_ASIGNACION_PAGO y, cuando el
      nivel lo permite, crear el encabezado en T3.Pago y su asignacion a factura.

    Los cambios de tabla que parecen inusuales (algunas incidencias se escriben
    en X_ASIGNACION_PAGO) se conservan porque forman parte del codigo Oracle.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNACION_PAGO_INSERT]
(
    @pLevel INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    -- Oracle confirma el trabajo previo dentro de WHEN OTHERS. OFF permite
    -- conservarlo si la transaccion continua en estado confirmable.
    SET XACT_ABORT OFF;

    DECLARE
        @sErrorCode      VARCHAR(30),
        @sMsg            VARCHAR(300),
        @nPID            INT = NULL,
        @sReference      VARCHAR(50) = NULL,
        @sStepPLSQL      VARCHAR(50) = NULL,

        @sInvDoc_Num     VARCHAR(30),
        @sInvCustomer    VARCHAR(30),
        @nInvAmount      DECIMAL(15,2),
        @nInvPending     DECIMAL(15,2),
        @nPaid           DECIMAL(15,2);

    BEGIN TRY
        BEGIN TRAN;

        ---------------------------------------------------------------------
        -- Paso 10: Actualizar importe fiscal, RFC y cliente SAP de factura
        ---------------------------------------------------------------------
        IF (COALESCE(@pLevel, 0) <= 10)
        BEGIN
            SET @sStepPLSQL = 'ScrFacturas';
            PRINT @sStepPLSQL;

            ;WITH Facturas AS
            (
                SELECT
                    RFD.Factura,
                    RF.Cliente_SAP,
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
                    -- Oracle agrupa por ROWID: cada asignacion ve el detalle
                    -- fiscal una sola vez. DISTINCT evita multiplicar importes
                    -- cuando la misma factura aparece varias veces en staging.
                    SELECT DISTINCT Factura
                    FROM [EAI_OWNER].[XP_Asignacion_Pago]
                    WHERE Factura IS NOT NULL
                ) AS Asig
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON Asig.Factura = RF.Factura
                INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN [T3].[Cliente] AS Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                   AND RF.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
                GROUP BY
                    RFD.Factura,
                    RF.Cliente_SAP,
                    Cte.RFC
            )
            UPDATE Asig
               SET Asig.Fact_Importe = F.Importe,
                   Asig.Fact_RFC     = F.RFC,
                   Asig.Cliente_SAP  = F.Cliente_SAP
            FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
            INNER JOIN Facturas AS F
                ON Asig.Factura = F.Factura;
        END;

        ---------------------------------------------------------------------
        -- Paso 100: Actualizar pendiente de factura usando SF_GET_INVOICE_DATA
        -- Se mantiene cursor porque el procedimiento dependiente devuelve OUTPUTs.
        ---------------------------------------------------------------------
        IF (COALESCE(@pLevel, 0) <= 100)
        BEGIN
            SET @sStepPLSQL = 'ScrFactPend';
            PRINT @sStepPLSQL;

            DECLARE curFactPend CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT Factura
                FROM [EAI_Owner].[XP_Asignacion_Pago];

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

                UPDATE [EAI_Owner].[XP_Asignacion_Pago]
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @sReference;

                FETCH NEXT FROM curFactPend INTO @sReference;
            END;

            CLOSE curFactPend;
            DEALLOCATE curFactPend;
        END;

        ---------------------------------------------------------------------
        -- Detectar asignaciones ya aplicadas
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrDuplicidad';
        PRINT @sStepPLSQL;

        UPDATE Asig
           SET Asig.Duplicada = 'X',
               Asig.Status_Asignacion = 'Asignacion ya aplicada'
        FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
        INNER JOIN [T3].[Asignacion_Pago] AS AP
            ON Asig.Factura = AP.Factura
           AND Asig.Importe = AP.Valor_Pago
           AND CONCAT(SUBSTRING(Asig.Fecha_Asignacion, 3, 2), Asig.Clearing_Document) = AP.Asignacion_ID;

        ---------------------------------------------------------------------
        -- Inconsistencias: validar asignación contra pendiente
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_Asig';
        PRINT @sStepPLSQL;

        UPDATE Asig
           SET Asig.Status_Asignacion = 'Revisar Asignacion'
        FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
        LEFT JOIN [T3].[Registro_Fiscal] AS RF
            ON Asig.Factura = RF.Factura
        WHERE NOT (
                    COALESCE(Asig.Importe, 0) > 0
                AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
              );

        ---------------------------------------------------------------------
        -- Inconsistencias: facturas duplicadas en staging
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_AsigDup';
        PRINT @sStepPLSQL;

        ;WITH Dup AS
        (
            SELECT
                Factura,
                COUNT(*) AS Duplicidad
            FROM [EAI_Owner].[XP_Asignacion_Pago]
            GROUP BY Factura
            HAVING COUNT(*) > 1
        )
        UPDATE Asig
           SET Asig.Status_Asignacion =
               CONCAT('Duplicidad de Asignacion ( ', CONVERT(VARCHAR(20), Dup.Duplicidad), ' )')
        FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
        INNER JOIN Dup
            ON Asig.Factura = Dup.Factura;

        ---------------------------------------------------------------------
        -- Inconsistencias: asignacion excedente.
        -- Oracle calcula desde XP_Asignacion_Pago y actualiza X_Asignacion_Pago.
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_FactExc';
        PRINT @sStepPLSQL;

        ;WITH FactExc AS
        (
            SELECT
                Factura,
                SUM(Importe) AS Importe,
                COUNT(*) AS Duplicidad,
                MAX(Fact_Pendiente) AS Fact_Pendiente
            FROM [EAI_Owner].[XP_Asignacion_Pago]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS Asig
        INNER JOIN FactExc
            ON Asig.Factura = FactExc.Factura;

        ---------------------------------------------------------------------
        -- Inconsistencias: clearing ya procesado.
        -- El cursor lee XP_Asignacion_Pago, pero Oracle actualiza X por factura.
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrPagoDuplicated';
        PRINT @sStepPLSQL;

        UPDATE X
           SET X.Duplicada = 'X',
               X.Status_Asignacion = 'Clearing ya procesado'
        FROM [EAI_OWNER].[X_Asignacion_Pago] AS X
        WHERE EXISTS
        (
            SELECT 1
            FROM [EAI_OWNER].[XP_Asignacion_Pago] AS XAP
            INNER JOIN [T3].[Asignacion_Pago] AS AP
                ON CONCAT(SUBSTRING(XAP.Fecha_Asignacion, 3, 2),
                          XAP.Clearing_Document) = AP.Pago_ID
            WHERE XAP.Factura = X.Factura
        );

        ---------------------------------------------------------------------
        -- Liberación: insertar en T3.Pago y T3.Asignacion_Pago
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'Revisando si necesita INSERTAR';
        PRINT @sStepPLSQL;

        IF (COALESCE(@pLevel, 0) >= 1000)
        BEGIN
            SET @sStepPLSQL = 'ScrLiberacion';
            PRINT @sStepPLSQL;

            DECLARE @Liberacion TABLE
            (
                Pago_ID           VARCHAR(100) NULL,
                Fecha_Trn         DATETIME NULL,
                Factura           VARCHAR(50) NULL,
                Nota_Credito      VARCHAR(50) NULL,
                Distribuidor      VARCHAR(50) NULL,
                Ctro              VARCHAR(50) NULL,
                Cliente_V3        VARCHAR(50) NULL,
                Cliente_SAP       VARCHAR(50) NULL,
                Rep_ID            VARCHAR(50) NULL,
                Tipo_Pago         VARCHAR(50) NULL,
                Metodo_Pago       VARCHAR(10) NULL,
                Fecha_Asignacion  VARCHAR(8) NULL,
                Valor_Pago        DECIMAL(15,2) NULL,
                Clearing_Document VARCHAR(100) NULL
            );

            INSERT INTO @Liberacion
            (
                Pago_ID,
                Fecha_Trn,
                Factura,
                Nota_Credito,
                Distribuidor,
                Ctro,
                Cliente_V3,
                Cliente_SAP,
                Rep_ID,
                Tipo_Pago,
                Metodo_Pago,
                Fecha_Asignacion,
                Valor_Pago,
                Clearing_Document
            )
            SELECT
                CASE
                    -- En Oracle NULL || NULL produce NULL; con un solo valor
                    -- presente, la concatenacion devuelve ese valor.
                    WHEN SUBSTRING(Asig.Fecha_Asignacion, 3, 2) IS NULL
                     AND Asig.Clearing_Document IS NULL
                        THEN NULL
                    ELSE CONCAT(SUBSTRING(Asig.Fecha_Asignacion, 3, 2),
                                Asig.Clearing_Document)
                END AS Pago_ID,
                GETDATE() AS Fecha_Trn,
                Asig.Factura,
                CAST(NULL AS VARCHAR(50)) AS Nota_Credito,
                RF.Distribuidor,
                RF.Ctro,
                RF.Cliente_V3,
                RF.Cliente_SAP,
                'CENTRAL' AS Rep_ID,
                'PAYMENT' AS Tipo_Pago,
                CASE
                    WHEN Asig.Via_Pago IS NULL THEN 'T'
                    WHEN Asig.Via_Pago = '01' THEN 'E'
                    WHEN Asig.Via_Pago = '02' THEN 'D'
                    WHEN Asig.Via_Pago = '03' THEN 'T'
                    ELSE 'D'
                END AS Metodo_Pago,
                -- La fecha se conserva como texto hasta procesar cada fila;
                -- asi un YYYYMMDD invalido falla en la misma etapa que Oracle.
                Asig.Fecha_Asignacion,
                Asig.Importe AS Valor_Pago,
                Asig.Clearing_Document
            FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
            INNER JOIN [T3].[Registro_Fiscal] AS RF
                ON Asig.Factura = RF.Factura
            WHERE COALESCE(Asig.Duplicada, ' ') <> 'X'
              AND (
                    Asig.Status_Asignacion IS NULL
                    OR (
                           Asig.Status_Asignacion = 'Documento ya liberado'
                       AND Asig.Fact_RFC = 'XAXX010101000'
                    )
                  )
              AND COALESCE(Asig.Importe, 0) > 0
              AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe;

            /*
                Se mantiene el cursor porque Oracle ejecuta tres efectos por
                fila en este orden: Pago, Asignacion_Pago y estado del staging.
                No se agrupan importes ni se omiten identificadores existentes.
            */
            DECLARE
                @LPago_ID          VARCHAR(100),
                @LFecha_Trn        DATETIME,
                @LFactura          VARCHAR(50),
                @LNota_Credito     VARCHAR(50),
                @LDistribuidor     VARCHAR(50),
                @LCtro             VARCHAR(50),
                @LCliente_V3       VARCHAR(50),
                @LCliente_SAP      VARCHAR(50),
                @LRep_ID           VARCHAR(50),
                @LTipo_Pago        VARCHAR(50),
                @LMetodo_Pago      VARCHAR(10),
                @LFecha_Asignacion VARCHAR(8),
                @LValor_Pago       DECIMAL(15,2),
                @LClearing         VARCHAR(100);

            DECLARE curLiberacion CURSOR LOCAL FAST_FORWARD FOR
                SELECT Pago_ID, Fecha_Trn, Factura, Nota_Credito,
                       Distribuidor, Ctro, Cliente_V3, Cliente_SAP,
                       Rep_ID, Tipo_Pago, Metodo_Pago, Fecha_Asignacion,
                       Valor_Pago, Clearing_Document
                FROM @Liberacion;

            OPEN curLiberacion;
            FETCH NEXT FROM curLiberacion INTO
                @LPago_ID, @LFecha_Trn, @LFactura, @LNota_Credito,
                @LDistribuidor, @LCtro, @LCliente_V3, @LCliente_SAP,
                @LRep_ID, @LTipo_Pago, @LMetodo_Pago, @LFecha_Asignacion,
                @LValor_Pago, @LClearing;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sReference = @LFactura;

                INSERT INTO [T3].[Pago]
                    (Pago_ID, Fecha_Trn, Distribuidor, Fecha_Pago, Cliente_V3,
                     Cliente_SAP, Rep_ID, Tipo_Pago, Metodo_Pago, Valor_Pago, Ctro)
                VALUES
                    (@LPago_ID, @LFecha_Trn, @LDistribuidor,
                     CONVERT(DATE, @LFecha_Asignacion, 112),
                     @LCliente_V3, @LCliente_SAP, @LRep_ID, @LTipo_Pago,
                     @LMetodo_Pago, @LValor_Pago, @LCtro);

                INSERT INTO [T3].[Asignacion_Pago]
                    (Pago_ID, Asignacion_ID, Fecha_Trn, Factura, Nota_Credito,
                     Distribuidor, Ctro, Cliente_V3, Cliente_SAP, Rep_ID,
                     Fecha_Asignacion, Valor_Pago)
                VALUES
                    (@LPago_ID, @LPago_ID, @LFecha_Trn, @LFactura,
                     @LNota_Credito, @LDistribuidor, @LCtro, @LCliente_V3,
                     @LCliente_SAP, @LRep_ID,
                     CONVERT(DATE, @LFecha_Asignacion, 112), @LValor_Pago);

                UPDATE Asig
                   SET Asig.Status = CONCAT('Insertada ', CONVERT(VARCHAR(19), GETDATE(), 120))
                FROM [EAI_OWNER].[XP_Asignacion_Pago] AS Asig
                WHERE Asig.Factura = @LFactura
                  AND Asig.Clearing_Document = @LClearing
                  AND Asig.Importe = @LValor_Pago
                  AND COALESCE(Asig.Duplicada, ' ') <> 'X'
                  AND
                  (
                        Asig.Status_Asignacion IS NULL
                        OR
                        (
                            Asig.Status_Asignacion = 'Documento ya liberado'
                            AND Asig.Fact_RFC = 'XAXX010101000'
                        )
                  )
                  AND COALESCE(Asig.Importe, 0) > 0
                  AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe;

                FETCH NEXT FROM curLiberacion INTO
                    @LPago_ID, @LFecha_Trn, @LFactura, @LNota_Credito,
                    @LDistribuidor, @LCtro, @LCliente_V3, @LCliente_SAP,
                    @LRep_ID, @LTipo_Pago, @LMetodo_Pago, @LFecha_Asignacion,
                    @LValor_Pago, @LClearing;
            END;

            CLOSE curLiberacion;
            DEALLOCATE curLiberacion;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- El cursor puede quedar abierto si falla la consulta dependiente.
        IF CURSOR_STATUS('local', 'curFactPend') >= 0
            CLOSE curFactPend;
        IF CURSOR_STATUS('local', 'curFactPend') > -2
            DEALLOCATE curFactPend;

        IF CURSOR_STATUS('local', 'curLiberacion') >= 0
            CLOSE curLiberacion;
        IF CURSOR_STATUS('local', 'curLiberacion') > -2
            DEALLOCATE curLiberacion;

        /*
            Oracle registra la excepcion y hace COMMIT sin ROLLBACK. SQL Server
            solo puede imitarlo cuando la transaccion es confirmable (estado 1).
            En estado -1 es obligatorio revertir antes de escribir el log.
        */
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
            'WA_ASIGNACION_PAGO_INSERT',
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
        PRINT 'Procedimiento : WA_ASIGNACION_PAGO_INSERT';
        PRINT CONCAT('Fecha         : ', CONVERT(VARCHAR(19), GETDATE(), 120));
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, ''));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', COALESCE(@sMsg, ''));
        PRINT REPLICATE('-', 80);

        IF XACT_STATE() = 1
            COMMIT TRANSACTION;

        -- Oracle finaliza despues de registrar el error, sin RAISE.
        RETURN;
    END CATCH;
END;
GO
