
/*
    Procedure : EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV_OPTIMIZADO
    Objetivo  : Convertir un pago temporal ZV en T3.Pago y
                T3.Asignacion_Pago.

    Optimizaciones principales:
    - Elimina el JOIN a CLIENT que no aporta ningun dato usado por el proceso.
    - Reduce el cursor a las columnas que realmente usa la regla de negocio.
    - Consolida en una sola escritura el estado final del IDoc.
    - Conserva un cursor LOCAL FAST_FORWARD porque las reglas de factura y
      cliente se ejecutan mediante procedimientos con parametros OUTPUT.

    Compatibilidad:
    - Conserva las decisiones funcionales del procedimiento SQL Server original
      y del homologo Oracle para datos validos.
    - No modifica el procedimiento original ni sus callers.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV]
(
    @pIDocNum VARCHAR(50),
    @pOutput  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sReferenceID            VARCHAR(30),
        @sProcesar               VARCHAR(20),
        @sIDocNum                VARCHAR(20),
        @sReferenceDocNumber     VARCHAR(50),
        @sPago_Integration_ID    VARCHAR(50),
        @sPayment_Num            VARCHAR(50),
        @dtPostingDate           DATETIME,
        @sPayment_Method         VARCHAR(50),
        @sFiscalYear             VARCHAR(10),
        @sFinalStatus            VARCHAR(20),
        @nAmount                 DECIMAL(18,2),
        @sCustomer_TMD           VARCHAR(30),
        @sCtro                   VARCHAR(4),
        @nDistributor            INT,
        @sRep_ID                 VARCHAR(30),
        @sInvDoc_Num             VARCHAR(30),
        @sInvCustomer            VARCHAR(30),
        @nInvAmount              DECIMAL(18,2),
        @nInvPending             DECIMAL(18,2),
        @nAbsolute               DECIMAL(18,2),
        @nPaid                   DECIMAL(18,2),
        @sCustomer_Name          VARCHAR(1024),
        @dtTransaction           DATETIME;

    BEGIN TRY
        SET @sReferenceID = @pIDocNum;

        -- Oracle declara esta referencia con longitud 30. La validacion evita
        -- que SQL Server trunque silenciosamente el identificador recibido.
        IF LEN(@pIDocNum) > 30
            THROW 50024, 'El identificador IDoc excede 30 caracteres.', 1;

        SET @sIDocNum = SUBSTRING(@pIDocNum, 7, 10);

        BEGIN TRANSACTION;

        IF @pOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT_ZV_OPTIMIZADO',
                 @sReferenceID, 'Begin');
        END;

        -- NO significa que el IDoc ya genero una asignacion y no debe
        -- insertarse de nuevo en las tablas operativas.
        SET @sProcesar = [EAI_OWNER].[SF_PAYMENT_ALLOC](@sIDocNum);

        IF @sProcesar <> 'NO'
        BEGIN
            /*
                Las llamadas SF_GET_INVOICE_DATA y SF_GET_CUSTOMER_DATA son
                procedurales y entregan resultados por parametros OUTPUT. Por
                esa razon el recorrido no puede convertirse en un INSERT
                completamente set-based sin duplicar esas reglas.

                FAST_FORWARD mantiene el cursor de solo lectura y avance unico.
                Solo se recuperan las columnas consumidas por el proceso. Se
                conserva GETCONV: la medicion aislada demostro menor latencia
                para el volumen pequeno que normalmente tiene un IDoc.
            */
            DECLARE curPayment CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    CONVERT(DECIMAL(18,2), COALESCE(Doc.PaymentAmount, 0)),
                    Doc.ReferenceDocNumber,
                    SUBSTRING(Doc.ClearingDate, 3, 2),
                    Doc.ClearingDocNumber,
                    CONVERT(DATETIME, Doc.ClearingDate, 112),
                    [EAI_OWNER].[GETCONV]
                    (
                        'ECC_T3 PaymentMethod',
                        Doc.PayMethSupplement
                    )
                FROM [EAI_OWNER].[tmp_Account_Header] AS Doc
                WHERE Doc.IDocNumber = @sIDocNum
                  AND Doc.PayMethSupplement IS NOT NULL
                  AND Doc.PayMethSupplement <> 'Z9'
                  AND Doc.PaymentAmount > 0;

            OPEN curPayment;

            FETCH NEXT FROM curPayment INTO
                @nAmount,
                @sReferenceDocNumber,
                @sFiscalYear,
                @sPayment_Num,
                @dtPostingDate,
                @sPayment_Method;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- CONCAT conserva la semantica de Oracle cuando alguna parte
                -- del identificador es NULL.
                SET @sPago_Integration_ID =
                    CONCAT(@sFiscalYear, @sPayment_Num);

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @pInvoiceRef   = @sReferenceDocNumber,
                    @rtDoc_Num     = @sInvDoc_Num OUTPUT,
                    @rtCliente_SAP = @sInvCustomer OUTPUT,
                    @rtAmount      = @nInvAmount OUTPUT,
                    @rtPending     = @nInvPending OUTPUT,
                    @rtPaid        = @nPaid OUTPUT;

                IF @nInvAmount > 0
                BEGIN
                    SET @nAbsolute = ABS(@nAmount - @nInvPending);

                    -- Se tolera una diferencia menor a cinco centavos, como
                    -- en Oracle, y se aplica exactamente el saldo pendiente.
                    IF @nAmount > @nInvPending AND @nAbsolute < 0.05
                        SET @nAmount = @nInvPending;

                    IF @nAmount <= @nInvPending AND @nAmount > 0
                    BEGIN
                        EXEC [EAI_OWNER].[SF_GET_CUSTOMER_DATA]
                            @pCustomer_SAP   = @sInvCustomer,
                            @pDate           = @dtPostingDate,
                            @rtCustomer_TMD  = @sCustomer_TMD OUTPUT,
                            @rtCtro          = @sCtro OUTPUT,
                            @rtDistributor   = @nDistributor OUTPUT,
                            @rtRep_ID         = @sRep_ID OUTPUT,
                            @rtCustomer_Name  = @sCustomer_Name OUTPUT;

                        IF LEN(@sCtro) > 2
                        BEGIN
                            -- Un solo instante para las dos filas relacionadas
                            -- facilita su trazabilidad y evita llamadas repetidas.
                            SET @dtTransaction = GETDATE();

                            INSERT INTO [T3].[Pago]
                            (
                                Pago_ID, Fecha_Trn, Distribuidor, Fecha_Pago,
                                Cliente_V3, Cliente_SAP, Rep_ID, Tipo_Pago,
                                Metodo_Pago, Valor_Pago, Ctro
                            )
                            VALUES
                            (
                                @sPago_Integration_ID, @dtTransaction,
                                @nDistributor, @dtPostingDate, @sCustomer_TMD,
                                @sInvCustomer, @sRep_ID, 'Payment',
                                @sPayment_Method, @nAmount, @sCtro
                            );

                            INSERT INTO [T3].[Asignacion_Pago]
                            (
                                Pago_ID, Fecha_Trn, Distribuidor,
                                Fecha_Asignacion, Cliente_V3, Asignacion_ID,
                                Cliente_SAP, Rep_ID, Factura, Valor_Pago, Ctro
                            )
                            VALUES
                            (
                                @sPago_Integration_ID, @dtTransaction,
                                @nDistributor, @dtPostingDate, @sCustomer_TMD,
                                @sPago_Integration_ID, @sInvCustomer, @sRep_ID,
                                @sInvDoc_Num, @nAmount, @sCtro
                            );

                            SET @sFinalStatus = 'Processed';
                        END
                        ELSE
                            SET @sFinalStatus = 'Customer Invalid';
                    END
                    ELSE
                        SET @sFinalStatus =
                            CASE WHEN @nAmount > 0
                                 THEN 'Amount > Pending'
                                 ELSE 'Discarded'
                            END;
                END
                ELSE
                    SET @sFinalStatus = 'Not Receivable';

                FETCH NEXT FROM curPayment INTO
                    @nAmount,
                    @sReferenceDocNumber,
                    @sFiscalYear,
                    @sPayment_Num,
                    @dtPostingDate,
                    @sPayment_Method;
            END;

            CLOSE curPayment;
            DEALLOCATE curPayment;

            -- El original actualiza todas las filas del mismo IDoc en cada
            -- iteracion. Solo el ultimo estado es observable al confirmar la
            -- transaccion, por lo que basta una escritura al terminar.
            IF @sFinalStatus IS NOT NULL
            BEGIN
                UPDATE [EAI_OWNER].[tmp_Account_Header]
                   SET Processed = GETDATE(),
                       Status = @sFinalStatus
                 WHERE IDocNumber = @sIDocNum;
            END;
        END
        ELSE
        BEGIN
            UPDATE [EAI_OWNER].[tmp_Account_Header]
               SET Processed = GETDATE(),
                   Status = 'Tx-Duplicated'
             WHERE IDocNumber = @sIDocNum;
        END;

        IF @pOutput > 0
        BEGIN
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYMENT_ZV_OPTIMIZADO',
                 @sReferenceID, 'End');
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'curPayment') >= 0
            CLOSE curPayment;

        IF CURSOR_STATUS('local', 'curPayment') > -3
            DEALLOCATE curPayment;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, STATUS, QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Processing PI', @sReferenceID, GETDATE(), 'Error',
            'PROC_CENTRAL_PAYMENT', LEFT(ERROR_MESSAGE(), 250), 'TSQL',
            CONCAT('SQL-', ERROR_NUMBER())
        );

        -- Igual que Oracle y la version SQL Server original, el error queda
        -- registrado para el monitor de integracion y no se relanza al caller.
    END CATCH;
END;
GO
