CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_ASIGNACION_PAGO]
(
      @pLevel INT = 0,
      @pDays  INT = 0
)
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        WA_ASIGNACION_PAGO
        ==================
        Prepara, valida y opcionalmente libera asignaciones entre facturas y
        notas de credito cargadas en EAI_OWNER.X_ASIGNACION_PAGO.

        Niveles de ejecucion:
        - @pLevel <= 10: calcula importes fiscales y RFC.
        - @pLevel <= 100: consulta saldos pendientes actuales.
        - Todos los niveles: revisa aplicadas, duplicadas e inconsistencias.
        - @pLevel >= 1000: inserta asignaciones validas en T3.Asignacion_Pago.

        @pDays desplaza Fecha_Asignacion hacia atras durante la liberacion.
    */

    -------------------------------------------------------------------
    -- Variables Oracle
    -------------------------------------------------------------------

    DECLARE @sErrorCode       VARCHAR(30);
    DECLARE @sMsg             VARCHAR(300);
    DECLARE @nPID             INT;
    DECLARE @sReference       VARCHAR(50);
    DECLARE @sStepPLSQL       VARCHAR(50);
    DECLARE @releaseDateTime  DATETIME2(0);
    DECLARE @paymentPrefix    VARCHAR(7);

    DECLARE @sInvDoc_Num      VARCHAR(30);
    DECLARE @sInvCustomer     VARCHAR(30);
    DECLARE @nInvAmount       DECIMAL(15,2);
    DECLARE @nInvPending      DECIMAL(15,2);
    DECLARE @nPaid            DECIMAL(15,2);

    DECLARE @sNCDoc_Num       VARCHAR(30);
    DECLARE @sNCCustomer      VARCHAR(30);
    DECLARE @nNCAmount        DECIMAL(15,2);
    DECLARE @nNCPending       DECIMAL(15,2);
    DECLARE @nNCPaid          DECIMAL(15,2);

    BEGIN TRY

        BEGIN TRANSACTION;

        -------------------------------------------------------------------
        -- ScrFacturas
        -------------------------------------------------------------------

        IF ISNULL(@pLevel,0) <= 10
        BEGIN

            SET @sStepPLSQL='ScrFacturas';

            ;WITH Facturas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        ISNULL(RFD.Valor_Subt,0)
                      + ISNULL(RFD.Valor_IVA,0)
                      + ISNULL(RFD.Envio_Subt,0)
                      + ISNULL(RFD.Envio_IVA,0)
                      + ISNULL(RFD.Credito_Subt,0)
                      + ISNULL(RFD.Credito_IVA,0)
                    ) AS Importe
                /*
                    Usar referencias distintas evita multiplicar el detalle
                    fiscal cuando una factura aparece varias veces en la carga.
                    Oracle agrupaba por ROWID y obtenia el mismo importe por fila.
                */
                FROM
                (
                    SELECT DISTINCT Factura
                    FROM [EAI_OWNER].[X_Asignacion_Pago]
                    WHERE Factura IS NOT NULL
                ) Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Factura = RF.Factura
                INNER JOIN T3.Registro_Fiscal_Detalle RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN T3.Cliente Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                WHERE RF.Fecha_Factura
                      BETWEEN Cte.Fecha_Ini_Vig
                          AND Cte.Fecha_Fin_Vig
                GROUP BY
                    RFD.Factura,
                    Cte.RFC
            )

            UPDATE AP
               SET Fact_Importe = F.Importe,
                   Fact_RFC     = F.RFC
            FROM EAI_OWNER.X_Asignacion_Pago AP
            INNER JOIN Facturas F
                    ON AP.Factura = F.Factura;

            ---------------------------------------------------------------
            -- ScrNotas
            ---------------------------------------------------------------

            SET @sStepPLSQL='ScrNotas';

            ;WITH Notas AS
            (
                SELECT
                    RFD.Factura,
                    Cte.RFC,
                    SUM(
                        ISNULL(RFD.Valor_Subt,0)
                      + ISNULL(RFD.Valor_IVA,0)
                      + ISNULL(RFD.Envio_Subt,0)
                      + ISNULL(RFD.Envio_IVA,0)
                      + ISNULL(RFD.Credito_Subt,0)
                      + ISNULL(RFD.Credito_IVA,0)
                    ) AS Importe
                FROM
                (
                    SELECT DISTINCT Nota_Credito
                    FROM [EAI_OWNER].[X_Asignacion_Pago]
                    WHERE Nota_Credito IS NOT NULL
                ) Asig
                INNER JOIN T3.Registro_Fiscal RF
                    ON Asig.Nota_Credito = RF.Factura
                INNER JOIN T3.Registro_Fiscal_Detalle RFD
                    ON RF.Factura = RFD.Factura
                INNER JOIN T3.Cliente Cte
                    ON RF.Cliente_SAP = Cte.Cliente_SAP
                WHERE RF.Fecha_Factura
                      BETWEEN Cte.Fecha_Ini_Vig
                          AND Cte.Fecha_Fin_Vig
                GROUP BY
                    RFD.Factura,
                    Cte.RFC
            )

            UPDATE AP
               SET Cred_Importe = N.Importe,
                   Cred_RFC     = N.RFC
            FROM EAI_OWNER.X_Asignacion_Pago AP
            INNER JOIN Notas N
                    ON AP.Nota_Credito = N.Factura;

        END;

        -------------------------------------------------------------------
        -- Facturas pendientes
        -------------------------------------------------------------------

        IF ISNULL(@pLevel,0) <= 100
        BEGIN

            SET @sStepPLSQL='ScrFactPend';

            DECLARE cFactPend CURSOR LOCAL FAST_FORWARD
            FOR
            SELECT DISTINCT Factura
            FROM EAI_OWNER.X_Asignacion_Pago;

            DECLARE @Factura VARCHAR(50);

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

                UPDATE EAI_OWNER.X_Asignacion_Pago
                   SET Fact_Pendiente = @nInvPending
                 WHERE Factura = @Factura;

                FETCH NEXT FROM cFactPend INTO @Factura;
            END

            CLOSE cFactPend;
            DEALLOCATE cFactPend;

            -----------------------------------------------------------

            SET @sStepPLSQL='ScrCredPend';

            DECLARE cCredPend CURSOR LOCAL FAST_FORWARD
            FOR
            SELECT DISTINCT Nota_Credito
            FROM EAI_OWNER.X_Asignacion_Pago;

            DECLARE @NotaCredito VARCHAR(50);

            OPEN cCredPend;

            FETCH NEXT FROM cCredPend INTO @NotaCredito;

            WHILE @@FETCH_STATUS = 0
            BEGIN

                SET @sReference=@NotaCredito;

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

                UPDATE EAI_OWNER.X_Asignacion_Pago
                   SET Cred_Importe   = @nNCAmount,
                       Cred_Pendiente = @nNCPending
                 WHERE Nota_Credito = @NotaCredito;

                FETCH NEXT FROM cCredPend INTO @NotaCredito;
            END

            CLOSE cCredPend;
            DEALLOCATE cCredPend;

        END;

        -------------------------------------------------------------------
        -- ScrDuplicidad
        -------------------------------------------------------------------

        SET @sStepPLSQL='ScrDuplicidad';

        UPDATE A
           SET Duplicada = 'X',
               Status_Asignacion = 'Asignacion ya aplicada'
        FROM EAI_OWNER.X_Asignacion_Pago A
        INNER JOIN T3.Asignacion_Pago AP
                ON A.Factura      = AP.Factura
               AND A.Nota_Credito = AP.Nota_Credito
               AND A.Importe      = AP.Valor_Pago;

        -------------------------------------------------------------------
        -- ScrStatus_Asig
        -------------------------------------------------------------------

        SET @sStepPLSQL='ScrStatus_Asig';

        /*
            Oracle solo escribe los estados distintos de 'Ok'. Una fila valida
            debe conservar Status_Asignacion NULL para que ScrLiberacion pueda
            seleccionarla posteriormente.
        */

        UPDATE A
           SET Status_Asignacion =
               CASE

                  WHEN ISNULL(A.Fact_RFC,'XAXX010101000')
                     <>
                     ISNULL(A.Cred_RFC,'XAXX010101000')
                  THEN 'Revisar RFC'

                  WHEN CFD.Fecha_Liberacion IS NOT NULL
                  THEN 'Documento ya liberado'

                  WHEN ISNULL(A.Importe,0) > 0
                   AND ISNULL(A.Fact_Pendiente,0) >= A.Importe
                   AND ISNULL(A.Cred_Pendiente,0) >= A.Importe
                  THEN 'Ok'

                  ELSE 'Revisar Asignacion'

               END
        FROM EAI_OWNER.X_Asignacion_Pago A
        LEFT JOIN T3.CFDI_Documentos CFD
               ON A.Nota_Credito = CFD.Nota_Venta
        WHERE
            CASE
                WHEN ISNULL(A.Fact_RFC,'XAXX010101000')
                     <> ISNULL(A.Cred_RFC,'XAXX010101000')
                    THEN 'Revisar RFC'
                WHEN CFD.Fecha_Liberacion IS NOT NULL
                    THEN 'Documento ya liberado'
                WHEN ISNULL(A.Importe,0) > 0
                 AND ISNULL(A.Fact_Pendiente,0) >= A.Importe
                 AND ISNULL(A.Cred_Pendiente,0) >= A.Importe
                    THEN 'Ok'
                ELSE 'Revisar Asignacion'
            END <> 'Ok';

        -------------------------------------------------------------------
        -- Duplicidad interna
        -------------------------------------------------------------------

        SET @sStepPLSQL='ScrStatus_AsigDup';

        ;WITH Dup AS
        (
            SELECT
                Nota_Credito,
                Factura,
                COUNT(*) AS Duplicidad
            FROM EAI_OWNER.X_Asignacion_Pago
            GROUP BY
                Nota_Credito,
                Factura
            HAVING COUNT(*) > 1
        )
        UPDATE AP
           SET Status_Asignacion =
               'Duplicidad de Asignacion ( '
               + CAST(D.Duplicidad AS VARCHAR(10))
               + ' )'
        FROM EAI_OWNER.X_Asignacion_Pago AP
        INNER JOIN Dup D
                ON AP.Nota_Credito=D.Nota_Credito
               AND AP.Factura=D.Factura;

        -------------------------------------------------------------------
        -- Excedente Nota Crédito
        -------------------------------------------------------------------

        SET @sStepPLSQL='ScrStatus_CredExc';

        ;WITH CTE AS
        (
            SELECT
                Nota_Credito
            FROM EAI_OWNER.X_Asignacion_Pago
            GROUP BY Nota_Credito
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Cred_Pendiente)
        )
        UPDATE AP
           SET Status_Asignacion='Asignacion Excedente'
        FROM EAI_OWNER.X_Asignacion_Pago AP
        INNER JOIN CTE
                ON AP.Nota_Credito=CTE.Nota_Credito;

        -------------------------------------------------------------------
        -- Excedente Factura
        -------------------------------------------------------------------

        SET @sStepPLSQL='ScrStatus_FactExc';

        ;WITH CTE AS
        (
            SELECT
                Factura
            FROM EAI_OWNER.X_Asignacion_Pago
            GROUP BY Factura
            HAVING COUNT(*) > 1
               AND SUM(Importe) > MAX(Fact_Pendiente)
        )
        UPDATE AP
           SET Status_Asignacion='Asignacion Excedente'
        FROM EAI_OWNER.X_Asignacion_Pago AP
        INNER JOIN CTE
                ON AP.Factura=CTE.Factura;

        -------------------------------------------------------------------
        -- Liberación
        -------------------------------------------------------------------

        IF ISNULL(@pLevel,0) >= 1000
        BEGIN

            SET @sStepPLSQL='ScrLiberacion';

            /*
                Oracle forma Pago_ID con YY + dia del anio (DDD) + hora (HH)
                y un consecutivo iniciado en 2501. FORMAT('yyDDDHH') no es una
                equivalencia segura en .NET, por eso se arma explicitamente.
            */
            SET @releaseDateTime = SYSDATETIME();
            SET @paymentPrefix =
                  RIGHT(CONVERT(CHAR(4), DATEPART(YEAR, @releaseDateTime)), 2)
                + RIGHT('000' + CONVERT(VARCHAR(3), DATEPART(DAYOFYEAR, @releaseDateTime)), 3)
                + RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, @releaseDateTime)), 2);

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

                @paymentPrefix +
                RIGHT(
                    '00000'
                    + CAST(2500 +
                      ROW_NUMBER() OVER
                      (ORDER BY A.Factura)
                      AS VARCHAR(10))
                ,5),

                @paymentPrefix +
                RIGHT(
                    '00000'
                    + CAST(2500 +
                      ROW_NUMBER() OVER
                      (ORDER BY A.Factura)
                      AS VARCHAR(10))
                ,5),

                @releaseDateTime,
                A.Factura,
                A.Nota_Credito,
                RF.Distribuidor,
                RF.Ctro,
                RF.Cliente_V3,
                RF.Cliente_SAP,
                'CENTRAL',
                CAST(DATEADD(DAY,-ISNULL(@pDays,0),@releaseDateTime) AS DATE),
                A.Importe

            FROM EAI_OWNER.X_Asignacion_Pago A
            INNER JOIN T3.Registro_Fiscal RF
                ON A.Factura = RF.Factura
            WHERE ISNULL(A.Duplicada,' ') <> 'X'
              AND
              (
                    A.Status_Asignacion IS NULL
                    OR
                    (
                        A.Status_Asignacion='Documento ya liberado'
                        AND A.Fact_RFC='XAXX010101000'
                        AND A.Cred_RFC='XAXX010101000'
                    )
              )
              AND ISNULL(A.Importe,0) > 0
              AND ISNULL(A.Fact_Pendiente,0) >= A.Importe
              AND ISNULL(A.Cred_Pendiente,0) >= A.Importe;

            /*
                El cursor Oracle marca cada fila liberada despues del INSERT.
                Repetir exactamente el predicado evita marcar filas rechazadas.
            */
            UPDATE A
               SET [Status] = CONCAT
                   (
                       'Insertada ',
                       CONVERT(CHAR(8), @releaseDateTime, 112),
                       ' ',
                       CONVERT(CHAR(8), @releaseDateTime, 108)
                   )
            FROM [EAI_OWNER].[X_Asignacion_Pago] A
            WHERE ISNULL(A.Duplicada,' ') <> 'X'
              AND
              (
                    A.Status_Asignacion IS NULL
                    OR
                    (
                        A.Status_Asignacion='Documento ya liberado'
                        AND A.Fact_RFC='XAXX010101000'
                        AND A.Cred_RFC='XAXX010101000'
                    )
              )
              AND ISNULL(A.Importe,0) > 0
              AND ISNULL(A.Fact_Pendiente,0) >= A.Importe
              AND ISNULL(A.Cred_Pendiente,0) >= A.Importe
              AND EXISTS
                  (
                      SELECT 1
                      FROM [T3].[Registro_Fiscal] RF
                      WHERE RF.Factura = A.Factura
                  );

        END;

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode =
            'SQL-' + CAST(ERROR_NUMBER() AS VARCHAR(20));

        SET @sMsg =
            LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

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
            'WA_ASIGNACION_PAGO',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;

    END CATCH

END
GO
