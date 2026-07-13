CREATE OR ALTER PROCEDURE [EAI_OWNER].[SF_PROC_CENTRAL_PAYALLOC]
(
    @pIDocNumber         VARCHAR(50),
    @pClearingDocNumber  VARCHAR(50),
    @pClearingDate       VARCHAR(50),
    @pPostingDate        DATE = NULL,
    @pOutPut             INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        SF_PROC_CENTRAL_PAYALLOC
        ========================
        Homologo T-SQL del procedimiento Oracle que procesa una compensacion
        formada por una factura (DC_Indicator = 'S') y, opcionalmente, una
        nota de credito (DC_Indicator = 'H').

        Reglas conservadas del origen:
        - Solo se procesa automaticamente cuando el outer join produce una
          unica combinacion factura/nota de credito.
        - El importe asignable es el menor entre factura y nota de credito;
          cuando no existe nota de credito, el importe de factura se conserva.
        - Se validan existencia y saldo pendiente de factura y nota de credito.
        - Se tolera una diferencia absoluta menor a 0.05 para la nota de credito.
        - La asignacion usa los dos caracteres centrales de ClearingDate mas
          ClearingDocNumber como Pago_ID y Asignacion_ID.
        - Se mantienen literalmente los estados operativos del Oracle.
        - pOutPut habilita la traza detallada en Trace_EAI_Owner.

        La llamada a SF_PROC_CENTRAL_PAYMENT_ZV permanece sin ejecutar porque
        tambien esta comentada en el fuente Oracle. No debe habilitarse sin una
        regla funcional aprobada.
    */

    DECLARE
        @sMsg                    VARCHAR(500),
        @sErrorCode              VARCHAR(50),
        @sReferenceID            VARCHAR(30),
        @sProcesar               VARCHAR(20),
        @nRecords                INT,
        @sInvReference           VARCHAR(50),
        @sCMReference            VARCHAR(50),
        @nPaymentAmount          DECIMAL(18,2),
        @nCNPaymentAmount        DECIMAL(18,2),
        @nInvPaymentAmount       DECIMAL(18,2),
        @nStep                   INT,
        @nAbsolute               DECIMAL(15,4),

        @sPago_Integration_ID    VARCHAR(50),
        @dtPostingDate           DATE,

        @sCustomer_TMD           VARCHAR(30),
        @sCtro                   VARCHAR(4),
        @nDistributor            INT,
        @sRep_ID                 VARCHAR(30),
        @sInvDoc_Num             VARCHAR(30),
        @sInvCustomer            VARCHAR(30),
        @nInvAmount              DECIMAL(15,2),
        @nInvPending             DECIMAL(15,2),
        @sNCDoc_Num              VARCHAR(30),
        @sNCCustomer             VARCHAR(30),
        @nNCAmount               DECIMAL(15,2),
        @nNCPending              DECIMAL(15,2),
        @nPaid                   DECIMAL(15,2),
        @nNCPaid                 DECIMAL(15,2),
        @sCustomer_Name          VARCHAR(1024),

        @StartedTran             BIT = 0;

    DECLARE @ScrData TABLE
    (
        Inv_DocumentType   VARCHAR(50) NULL,
        Inv_BillingDoc     VARCHAR(50) NULL,
        Inv_ReferenceDoc   VARCHAR(50) NULL,
        Inv_PMS            VARCHAR(50) NULL,
        Inv_PaymentAmt     DECIMAL(18,2) NULL,
        Inv_PaymentMethod  VARCHAR(50) NULL,
        CM_DocumentType    VARCHAR(50) NULL,
        CM_BillingDoc      VARCHAR(50) NULL,
        CM_ReferenceDoc    VARCHAR(50) NULL,
        CM_PMS             VARCHAR(50) NULL,
        CM_PaymentAmt      DECIMAL(18,2) NULL,
        CM_PaymentMethod   VARCHAR(50) NULL
    );

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRAN;
            SET @StartedTran = 1;
        END

        SET @sProcesar     = 'YES';
        SET @nRecords      = 0;
        SET @sReferenceID  = @pIDocNumber;
        SET @nNCAmount     = 0;
        SET @nNCPending    = 0;
        SET @dtPostingDate = COALESCE(@pPostingDate, CAST(GETDATE() AS DATE));
        SET @nStep         = 0;

        IF (@pOutPut > 0)
        BEGIN
            SET @nStep += 1;

            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                (Created, Object_Type, Object_Reference, Description)
            VALUES
                (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                 CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Begin'));
        END;

        IF (@sProcesar <> 'NO')
        BEGIN
            INSERT INTO @ScrData
            (
                Inv_DocumentType,
                Inv_BillingDoc,
                Inv_ReferenceDoc,
                Inv_PMS,
                Inv_PaymentAmt,
                Inv_PaymentMethod,
                CM_DocumentType,
                CM_BillingDoc,
                CM_ReferenceDoc,
                CM_PMS,
                CM_PaymentAmt,
                CM_PaymentMethod
            )
            SELECT
                IDoc.DocumentType,
                IDoc.BillingDoc,
                IDoc.ReferenceDoc,
                IDoc.PMS,
                IDoc.PaymentAmt,
                IDoc.PaymentMethod,
                Cred.DocumentType,
                Cred.BillingDoc,
                COALESCE(Cred.ReferenceDoc, ''),
                Cred.PMS,
                Cred.PaymentAmt,
                Cred.PaymentMethod
            FROM
            (
                SELECT
                    IDoc.DocumentType,
                    IDoc.ClearingDocNumber AS ClearingDoc,
                    IDoc.Assignment AS BillingDoc,
                    IDoc.ReferenceDocNumber AS ReferenceDoc,
                    IDoc.PayMethSupplement AS PMS,
                    COALESCE(IDoc.PaymentAmount, 0) AS PaymentAmt,
                    IDoc.PaymentMethod
                FROM [EAI_OWNER].[tmp_Account_Header] IDoc
                WHERE IDoc.ClearingDocNumber = @pClearingDocNumber
                  AND IDoc.ClearingDate      = @pClearingDate
                  AND IDoc.DC_Indicator      = 'S'
                  AND IDoc.PaymentAmount IS NOT NULL
            ) IDoc
            LEFT JOIN
            (
                SELECT
                    Cred.DocumentType,
                    Cred.ClearingDocNumber AS ClearingDoc,
                    Cred.Assignment AS BillingDoc,
                    Cred.ReferenceDocNumber AS ReferenceDoc,
                    Cred.PayMethSupplement AS PMS,
                    COALESCE(Cred.PaymentAmount, 0) AS PaymentAmt,
                    Cred.PaymentMethod
                FROM [EAI_OWNER].[tmp_Account_Header] Cred
                WHERE Cred.ClearingDocNumber = @pClearingDocNumber
                  AND Cred.ClearingDate      = @pClearingDate
                  AND Cred.DC_Indicator      = 'H'
                  AND Cred.PaymentAmount IS NOT NULL
            ) Cred
                ON IDoc.ClearingDoc = Cred.ClearingDoc;

            SELECT @nRecords = COUNT(1)
            FROM @ScrData;

            IF (@nRecords = 1)
            BEGIN
                SELECT TOP (1)
                    @sInvReference     = Inv_ReferenceDoc,
                    @sCMReference      = CM_ReferenceDoc,
                    @nPaymentAmount    = Inv_PaymentAmt,
                    @nInvPaymentAmount = Inv_PaymentAmt,
                    @nCNPaymentAmount  = CM_PaymentAmt
                FROM @ScrData;

                -- El subquery Oracle aplica NVL solo al importe de factura y
                -- al importe de una nota existente. Si el LEFT JOIN no tiene
                -- nota, CM_PaymentAmt debe seguir NULL: NULL < importe es
                -- UNKNOWN y por tanto se conserva el importe de factura.
                SET @nPaymentAmount = COALESCE(@nPaymentAmount, 0);
                SET @nInvPaymentAmount = COALESCE(@nInvPaymentAmount, 0);
                SET @sCMReference = COALESCE(@sCMReference, '');

                IF (@nCNPaymentAmount < @nPaymentAmount)
                    SET @nPaymentAmount = @nCNPaymentAmount;

                IF (@pOutPut > 0)
                BEGIN
                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                         CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'InvReference   : ', @sInvReference));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                         CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'CMReference    : ', @sCMReference));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                         CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Invoice Amount : ', @nInvPaymentAmount));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        (Created, Object_Type, Object_Reference, Description)
                    VALUES
                        (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                         CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Credit Amount  : ', @nCNPaymentAmount));
                END;

                EXEC [EAI_OWNER].[SF_GET_INVOICE_DATA]
                    @sInvReference,
                    @sInvDoc_Num OUTPUT,
                    @sInvCustomer OUTPUT,
                    @nInvAmount OUTPUT,
                    @nInvPending OUTPUT,
                    @nPaid OUTPUT;

                SET @nInvAmount = COALESCE(@nInvAmount, 0);
                SET @nInvPending = COALESCE(@nInvPending, 0);

                IF (@pOutPut > 0)
                BEGIN
                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Invoice Information'));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Reference : ', @sInvReference));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Invoice   : ', @sInvDoc_Num));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Customer  : ', @sInvCustomer));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Amount    : ', @nInvAmount));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Pending   : ', @nInvPending));
                END;

                IF (LEN(@sCMReference) > 1)
                BEGIN
                    EXEC [EAI_OWNER].[SF_GET_CREDIT_DATA]
                        @sCMReference,
                        @sNCDoc_Num OUTPUT,
                        @sNCCustomer OUTPUT,
                        @nNCAmount OUTPUT,
                        @nNCPending OUTPUT,
                        @nNCPaid OUTPUT;

                    SET @nNCAmount = COALESCE(@nNCAmount, 0);
                    SET @nNCPending = COALESCE(@nNCPending, 0);

                    IF (@pOutPut > 0)
                    BEGIN
                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Credit Note Information'));

                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Reference : ', @sCMReference));

                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'CreditNote: ', @sNCDoc_Num));

                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Customer  : ', @sNCCustomer));

                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Amount    : ', @nNCAmount));

                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Pending   : ', @nNCPending));
                    END;
                END;

                EXEC [EAI_OWNER].[SF_GET_CUSTOMER_DATA]
                    @sInvCustomer,
                    @dtPostingDate,
                    @sCustomer_TMD OUTPUT,
                    @sCtro OUTPUT,
                    @nDistributor OUTPUT,
                    @sRep_ID OUTPUT,
                    @sCustomer_Name OUTPUT;

                IF (@pOutPut > 0)
                BEGIN
                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Customer Information'));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Customer_TMD : ', @sCustomer_TMD));

                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Ctro         : ', @sCtro));
                END;

                IF (@nInvAmount > 0)
                BEGIN
                    IF (@nInvPending >= @nPaymentAmount)
                    BEGIN
                        IF (@nNCAmount = 0)
                        BEGIN
                            IF (LEN(@sCMReference) > 2)
                            BEGIN
                                IF (@pOutPut > 0)
                                BEGIN
                                    SET @nStep += 1;
                                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Credit Note NOT Found'));
                                END;

                                UPDATE [EAI_OWNER].[tmp_Account_Header]
                                SET Processed = GETDATE(),
                                    Status = 'CN NOT Found'
                                WHERE IDocNumber = @pIDocNumber;
                            END
                            ELSE
                            BEGIN
                                -- Payment Collection.
                                -- En Oracle estaba comentado:
                                -- EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV(LPAD(pIDocNumber, 16, '0'));
                                -- En SQL Server equivalente:
                                -- EXEC [EAI_OWNER].[SF_PROC_CENTRAL_PAYMENT_ZV]
                                --      RIGHT(REPLICATE('0', 16) + @pIDocNumber, 16);

                                SET @nRecords = @nRecords + 0;
                            END;
                        END
                        ELSE
                        BEGIN
                            SET @nAbsolute = ABS(@nNCPending - @nPaymentAmount);

                            IF (((@nNCPending >= @nPaymentAmount) OR (@nAbsolute < 0.05))
                                AND (@nPaymentAmount > 0))
                            BEGIN
                                SET @sPago_Integration_ID =
                                    CONCAT(SUBSTRING(@pClearingDate, 3, 2), @pClearingDocNumber);

                                INSERT INTO [T3].[Asignacion_Pago]
                                (
                                    Pago_ID,
                                    Fecha_Trn,
                                    Distribuidor,
                                    Fecha_Asignacion,
                                    Cliente_V3,
                                    Asignacion_ID,
                                    Nota_Credito,
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
                                    @sNCDoc_Num,
                                    @sInvCustomer,
                                    'CENTRAL',
                                    @sInvDoc_Num,
                                    @nPaymentAmount,
                                    @sCtro
                                );

                                IF (@pOutPut > 0)
                                BEGIN
                                    SET @nStep += 1;
                                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Processed'));
                                END;

                                UPDATE [EAI_OWNER].[tmp_Account_Header]
                                SET Processed = GETDATE(),
                                    Status = 'Processed'
                                WHERE ClearingDocNumber = @pClearingDocNumber
                                  AND ClearingDate      = @pClearingDate;
                            END
                            ELSE
                            BEGIN
                                IF (@pOutPut > 0)
                                BEGIN
                                    SET @nStep += 1;
                                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Payement higher than credit note pending'));
                                END;

                                UPDATE [EAI_OWNER].[tmp_Account_Header]
                                SET Processed = GETDATE(),
                                    Status = 'CN exceeded'
                                WHERE IDocNumber = @pIDocNumber;
                            END;
                        END;
                    END
                    ELSE
                    BEGIN
                        IF (@pOutPut > 0)
                        BEGIN
                            SET @nStep += 1;
                            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                            VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                    CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Payment higher than invoice pending'));
                        END;

                        UPDATE [EAI_OWNER].[tmp_Account_Header]
                        SET Processed = GETDATE(),
                            Status = 'Payment exceeded'
                        WHERE IDocNumber = @pIDocNumber;
                    END;
                END
                ELSE
                BEGIN
                    IF (@pOutPut > 0)
                    BEGIN
                        SET @nStep += 1;
                        INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                        VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                                CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Invoice does not exist'));
                    END;

                    UPDATE [EAI_OWNER].[tmp_Account_Header]
                    SET Processed = GETDATE(),
                        Status = 'Inv NOT Found'
                    WHERE IDocNumber = @pIDocNumber;
                END;
            END
            ELSE
            BEGIN
                IF (@pOutPut > 0)
                BEGIN
                    SET @nStep += 1;
                    INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                    VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                            CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'More than two items on Clearing Document'));
                END;

                UPDATE [EAI_OWNER].[tmp_Account_Header]
                SET Processed = GETDATE(),
                    Status = 'Tx-MoreItems'
                WHERE IDocNumber = @pIDocNumber;
            END;
        END
        ELSE
        BEGIN
            IF (@pOutPut > 0)
            BEGIN
                SET @nStep += 1;
                INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
                VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                        CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'Tx-Discarded'));
            END;

            UPDATE [EAI_OWNER].[tmp_Account_Header]
            SET Processed = GETDATE(),
                Status = 'Tx-Discarded'
            WHERE IDocNumber = @pIDocNumber;
        END;

        IF (@pOutPut > 0)
        BEGIN
            SET @nStep += 1;
            INSERT INTO [EAI_OWNER].[Trace_EAI_Owner]
            VALUES (GETDATE(), 'SF_PROC_CENTRAL_PAYALLOC', @pIDocNumber,
                    CONCAT(RIGHT('0000' + CAST(@nStep AS VARCHAR(10)), 4), 'End'));
        END;

        IF (@StartedTran = 1 AND XACT_STATE() = 1)
            COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF (XACT_STATE() <> 0 AND @StartedTran = 1)
            ROLLBACK TRAN;

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION,
            REFERENCE,
            CREATED,
            MESSAGE,
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
            'Processing PI',
            @sReferenceID,
            GETDATE(),
            NULL,
            'Error',
            'PROC_CENTRAL_PAYMENT',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        /*
            A diferencia del WHEN OTHERS Oracle, T-SQL vuelve a propagar el
            error despues de registrarlo. Esto evita reportar exito al caller
            cuando la asignacion no pudo completarse y sigue la convencion de
            manejo de errores del proyecto.
        */
        THROW;
    END CATCH;
END;
GO
