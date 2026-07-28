/*
    Procedure : EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV
    Objetivo  : Convertir un pago temporal ZV en T3.Pago y T3.Asignacion_Pago.
    Entrada   : @pIDocNum contiene el identificador completo; @pOutput habilita
                trazas para diagnóstico.
    Controles : Rechaza duplicados, documentos no cobrables, clientes inválidos
                e importes superiores al saldo pendiente.
*/
CREATE OR ALTER PROCEDURE EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV
(
    @pIDocNum VARCHAR(50),
    @pOutput  INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sMsg NVARCHAR(500),
        @sErrorCode VARCHAR(20),
        @sReferenceID VARCHAR(30),
        @sProcesar VARCHAR(20),
        @sIDocNum VARCHAR(20),

        @sReferenceDocNumber VARCHAR(50),
        @sPago_Integration_ID VARCHAR(50),
        @sPayment_Num VARCHAR(50),
        @dtPostingDate DATETIME,
        @sCustomerPayer VARCHAR(50),
        @sIDocNumber VARCHAR(50),
        @sPayment_Method VARCHAR(50),

        @nAmount DECIMAL(18,2),
        @sCustomer_TMD VARCHAR(30),
        @sCtro VARCHAR(4),
        @nDistributor INT,
        @sRep_ID VARCHAR(30),
        @sInvDoc_Num VARCHAR(30),
        @sInvCustomer VARCHAR(30),
        @nInvAmount DECIMAL(18,2),
        @nInvPending DECIMAL(18,2),
        @nAbsolute DECIMAL(18,2),
        @nPaid DECIMAL(18,2),
        @sCustomer_Name VARCHAR(1024);

    BEGIN TRY

        -- Pago, asignación y estado temporal deben quedar juntos. Esto impide
        -- conservar un Pago huérfano si falla la inserción de su asignación.
        BEGIN TRANSACTION;

        SET @sReferenceID = @pIDocNum;

        -- La referencia de trabajo es VARCHAR2(30) en Oracle. No se permite que
        -- SQL Server recorte el valor y procese un IDoc distinto.
        IF LEN(@pIDocNum) > 30
            THROW 50024, 'El identificador IDoc excede 30 caracteres.', 1;

        SET @sIDocNum     = SUBSTRING(@pIDocNum,7,10);

        IF @pOutput > 0
        BEGIN
            INSERT INTO EAI_Owner.Trace_EAI_Owner
                (Created, Object_Type, Object_Reference, Description)
            VALUES(GETDATE(),
                   'SF_PROC_CENTRAL_PAYMENT_ZV',
                   @sReferenceID,
                   'Begin');
        END

        -- La función devuelve NO cuando la transacción ya fue asignada. Esta
        -- validación ocurre antes de insertar Pago o Asignacion_Pago.
        SET @sProcesar = EAI_Owner.SF_PAYMENT_ALLOC(@sIDocNum);

        IF @sProcesar <> 'NO'
        BEGIN

            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR

            SELECT
                COALESCE(Doc.PaymentAmount,0),
                Doc.ReferenceDocNumber,
                SUBSTRING(Doc.ClearingDate,3,2),
                Doc.ClearingDocNumber,
                CONVERT(DATETIME,Doc.ClearingDate,112),
                Doc.CustomerNumber,
                Doc.IDocNumber,
                EAI_Owner.GetConv(
                    'ECC_T3 PaymentMethod',
                    Doc.PayMethSupplement
                )
            FROM EAI_Owner.tmp_Account_Header Doc
            LEFT JOIN EAI_Owner.Client Cte
                ON Doc.CustomerNumber = Cte.Cliente_SAP
            WHERE Doc.IDocNumber=@sIDocNum
              AND Doc.PayMethSupplement IS NOT NULL
              AND Doc.PayMethSupplement<>'Z9'
              AND COALESCE(Doc.PaymentAmount,0)>0;

            DECLARE @FiscalYear VARCHAR(10);

            OPEN cur;

            FETCH NEXT FROM cur INTO
                @nAmount,
                @sReferenceDocNumber,
                @FiscalYear,
                @sPayment_Num,
                @dtPostingDate,
                @sCustomerPayer,
                @sIDocNumber,
                @sPayment_Method;

            WHILE @@FETCH_STATUS = 0
            BEGIN

                -- CONCAT reproduce el operador || de Oracle: si una parte es
                -- NULL conserva la otra, en vez de volver NULL todo el ID.
                SET @sPago_Integration_ID =
                    CONCAT(@FiscalYear, @sPayment_Num);

                EXEC EAI_Owner.SF_GET_INVOICE_DATA
                    @sReferenceDocNumber,
                    @sInvDoc_Num OUTPUT,
                    @sInvCustomer OUTPUT,
                    @nInvAmount OUTPUT,
                    @nInvPending OUTPUT,
                    @nPaid OUTPUT;

                IF @nInvAmount > 0
                BEGIN

                    SET @nAbsolute =
                        ABS(@nAmount - @nInvPending);

                    -- Oracle tolera diferencias menores a cinco centavos y usa
                    -- el saldo pendiente para no sobreaplicar el pago.
                    IF @nAmount > @nInvPending
                       AND @nAbsolute < 0.05
                    BEGIN
                        SET @nAmount = @nInvPending;
                    END

                    IF @nAmount <= @nInvPending
                       AND @nAmount > 0
                    BEGIN

                        EXEC EAI_Owner.SF_GET_CUSTOMER_DATA
                            @sInvCustomer,
                            @dtPostingDate,
                            @sCustomer_TMD OUTPUT,
                            @sCtro OUTPUT,
                            @nDistributor OUTPUT,
                            @sRep_ID OUTPUT,
                            @sCustomer_Name OUTPUT;

                        IF LEN(@sCtro) > 2
                        BEGIN

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
                            VALUES
                            (
                                @sPago_Integration_ID,
                                GETDATE(),
                                @nDistributor,
                                @dtPostingDate,
                                @sCustomer_TMD,
                                @sInvCustomer,
                                @sRep_ID,
                                'Payment',
                                @sPayment_Method,
                                @nAmount,
                                @sCtro
                            );

                            INSERT INTO T3.Asignacion_Pago
                            (
                                Pago_ID,
                                Fecha_Trn,
                                Distribuidor,
                                Fecha_Asignacion,
                                Cliente_V3,
                                Asignacion_ID,
                                Cliente_SAP,
                                Rep_ID,
                                Factura,
                                Valor_Pago,
                                Ctro
                            )
                            VALUES
                            (
                                @sPago_Integration_ID,
                                GETDATE(),
                                @nDistributor,
                                @dtPostingDate,
                                @sCustomer_TMD,
                                @sPago_Integration_ID,
                                @sInvCustomer,
                                @sRep_ID,
                                @sInvDoc_Num,
                                @nAmount,
                                @sCtro
                            );

                            UPDATE EAI_Owner.tmp_Account_Header
                               SET Processed = GETDATE(),
                                   Status='Processed'
                             WHERE IDocNumber=@sIDocNum;
                        END
                        ELSE
                        BEGIN
                            UPDATE EAI_Owner.tmp_Account_Header
                               SET Processed=GETDATE(),
                                   Status='Customer Invalid'
                             WHERE IDocNumber=@sIDocNum;
                        END
                    END
                    ELSE
                    BEGIN
                        UPDATE EAI_Owner.tmp_Account_Header
                           SET Processed=GETDATE(),
                               Status=
                               CASE
                                   WHEN @nAmount>0
                                   THEN 'Amount > Pending'
                                   ELSE 'Discarded'
                               END
                         WHERE IDocNumber=@sIDocNum;
                    END
                END
                ELSE
                BEGIN
                    UPDATE EAI_Owner.tmp_Account_Header
                       SET Processed=GETDATE(),
                           Status='Not Receivable'
                     WHERE IDocNumber=@sIDocNum;
                END

                FETCH NEXT FROM cur INTO
                    @nAmount,
                    @sReferenceDocNumber,
                    @FiscalYear,
                    @sPayment_Num,
                    @dtPostingDate,
                    @sCustomerPayer,
                    @sIDocNumber,
                    @sPayment_Method;
            END

            CLOSE cur;
            DEALLOCATE cur;
        END
        ELSE
        BEGIN

            UPDATE EAI_Owner.tmp_Account_Header
               SET Processed=GETDATE(),
                   Status='Tx-Duplicated'
             WHERE IDocNumber=@sIDocNum;

        END

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF CURSOR_STATUS('local', 'cur') >= 0 CLOSE cur;
        IF CURSOR_STATUS('local', 'cur') > -3 DEALLOCATE cur;

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Processing PI',
            @sReferenceID,
            GETDATE(),
            'Error',
            'PROC_CENTRAL_PAYMENT',
            LEFT(ERROR_MESSAGE(), 250),
            'TSQL',
            CONCAT('SQL-', ERROR_NUMBER())
        );

        -- Oracle registra el error y no lo devuelve como excepción al caller.

    END CATCH
END
GO
