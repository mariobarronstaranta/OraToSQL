CREATE OR ALTER PROCEDURE [EAI_Owner].[WA_ASIGNACION_PAGO_INSERT]
(
    @pLevel INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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
                FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
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
        -- Inconsistencias: asignación excedente
        -- En Oracle actualiza X_Asignacion_Pago; aquí se usa XP_Asignacion_Pago.
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrStatus_FactExc';
        PRINT @sStepPLSQL;

        ;WITH FactExc AS
        (
            SELECT
                Factura,
                SUM(COALESCE(Importe, 0)) AS Importe,
                COUNT(*) AS Duplicidad,
                MAX(COALESCE(Fact_Pendiente, 0)) AS Fact_Pendiente
            FROM [EAI_Owner].[XP_Asignacion_Pago]
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(COALESCE(Importe, 0)) > MAX(COALESCE(Fact_Pendiente, 0))
        )
        UPDATE Asig
           SET Asig.Status_Asignacion = 'Asignacion Excedente'
        FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
        INNER JOIN FactExc
            ON Asig.Factura = FactExc.Factura;

        ---------------------------------------------------------------------
        -- Inconsistencias: clearing ya procesado
        -- En Oracle actualiza X_Asignacion_Pago; aquí se usa XP_Asignacion_Pago.
        ---------------------------------------------------------------------
        SET @sStepPLSQL = 'ScrPagoDuplicated';
        PRINT @sStepPLSQL;

        UPDATE XAP
           SET XAP.Duplicada = 'X',
               XAP.Status_Asignacion = 'Clearing ya procesado'
        FROM [EAI_Owner].[XP_Asignacion_Pago] AS XAP
        INNER JOIN [T3].[Asignacion_Pago] AS AP
            ON CONCAT(SUBSTRING(XAP.Fecha_Asignacion, 3, 2), XAP.Clearing_Document) = AP.Pago_ID;

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
                Pago_ID           VARCHAR(100) NOT NULL,
                Fecha_Trn         DATETIME NOT NULL,
                Factura           VARCHAR(50) NOT NULL,
                Nota_Credito      VARCHAR(50) NULL,
                Distribuidor      VARCHAR(50) NULL,
                Ctro              VARCHAR(50) NULL,
                Cliente_V3        VARCHAR(50) NULL,
                Cliente_SAP       VARCHAR(50) NULL,
                Rep_ID            VARCHAR(50) NOT NULL,
                Tipo_Pago         VARCHAR(50) NOT NULL,
                Metodo_Pago       VARCHAR(10) NOT NULL,
                Fecha_Asignacion  DATE NULL,
                Valor_Pago        DECIMAL(15,2) NOT NULL,
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
                CONCAT(SUBSTRING(Asig.Fecha_Asignacion, 3, 2), Asig.Clearing_Document) AS Pago_ID,
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
                TRY_CONVERT(DATE, Asig.Fecha_Asignacion, 112) AS Fecha_Asignacion,
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
              AND COALESCE(Asig.Fact_Pendiente, 0) >= Asig.Importe
              AND TRY_CONVERT(DATE, Asig.Fecha_Asignacion, 112) IS NOT NULL;

            -----------------------------------------------------------------
            -- Insertar encabezado de pago.
            -- Mejora: evita duplicar Pago_ID si ya existe.
            -----------------------------------------------------------------
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
                L.Pago_ID,
                MAX(L.Fecha_Trn) AS Fecha_Trn,
                MAX(L.Distribuidor) AS Distribuidor,
                MAX(L.Fecha_Asignacion) AS Fecha_Pago,
                MAX(L.Cliente_V3) AS Cliente_V3,
                MAX(L.Cliente_SAP) AS Cliente_SAP,
                MAX(L.Rep_ID) AS Rep_ID,
                MAX(L.Tipo_Pago) AS Tipo_Pago,
                MAX(L.Metodo_Pago) AS Metodo_Pago,
                SUM(L.Valor_Pago) AS Valor_Pago,
                MAX(L.Ctro) AS Ctro
            FROM @Liberacion AS L
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [T3].[Pago] AS P
                WHERE P.Pago_ID = L.Pago_ID
            )
            GROUP BY L.Pago_ID;

            -----------------------------------------------------------------
            -- Insertar detalle de asignación de pago.
            -- Mejora: evita duplicar la misma factura para el mismo pago.
            -----------------------------------------------------------------
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
                L.Pago_ID,
                L.Pago_ID AS Asignacion_ID,
                L.Fecha_Trn,
                L.Factura,
                L.Nota_Credito,
                L.Distribuidor,
                L.Ctro,
                L.Cliente_V3,
                L.Cliente_SAP,
                L.Rep_ID,
                L.Fecha_Asignacion,
                L.Valor_Pago
            FROM @Liberacion AS L
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [T3].[Asignacion_Pago] AS AP
                WHERE AP.Pago_ID = L.Pago_ID
                  AND AP.Factura = L.Factura
                  AND AP.Valor_Pago = L.Valor_Pago
            );

            -----------------------------------------------------------------
            -- Marcar staging como insertada
            -----------------------------------------------------------------
            UPDATE Asig
               SET Asig.Status = CONCAT('Insertada ', CONVERT(VARCHAR(19), GETDATE(), 120))
            FROM [EAI_Owner].[XP_Asignacion_Pago] AS Asig
            INNER JOIN @Liberacion AS L
                ON Asig.Factura = L.Factura
               AND Asig.Clearing_Document = L.Clearing_Document
               AND Asig.Importe = L.Valor_Pago;
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

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
            'WA_ASIGNACION_PAGO_INSERT',
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
        PRINT 'Procedimiento : WA_ASIGNACION_PAGO_INSERT';
        PRINT CONCAT('Fecha         : ', CONVERT(VARCHAR(19), GETDATE(), 120));
        PRINT CONCAT('Referencia    : ', COALESCE(@sReference, ''));
        PRINT CONCAT('Secuencia     : ', COALESCE(@sStepPLSQL, ''));
        PRINT CONCAT('Error         : ', COALESCE(@sMsg, ''));
        PRINT REPLICATE('-', 80);

        THROW;
    END CATCH;
END;
GO