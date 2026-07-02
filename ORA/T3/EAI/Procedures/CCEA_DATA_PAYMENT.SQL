CREATE OR ALTER PROCEDURE dbo.CCEA_DATA_PAYMENT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID VARCHAR(50),
        @sMsg VARCHAR(500),
        @sErrorCode VARCHAR(20),
        @nPID BIGINT,
        @nProceso INT = 731,
        @nProceso3 INT = 0,
        @nProceso4 INT = 0;

    BEGIN TRY

        BEGIN TRAN;

        SET @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
        (
            PID,
            PROCESO,
            FECHA_PROC_BATMD,
            INICIO
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            GETDATE()
        );

        TRUNCATE TABLE EAI.CC_DATA_PAYMENT;

        INSERT INTO EAI.CC_DATA_PAYMENT
        (
            PLANT,
            TERRITORY,
            STOCK_PARTNER,
            SFCD_CUSTOMER,
            SAP_CUSTOMER,
            CUSTOMER_NAME,
            TAX_ID,
            CUSTOMER_PAYMENT_METHOD,
            CUSTOMER_PAYMENT_TYPE,
            REPORT_DATE,
            DOCUMENT_TYPE,
            INVOICE_DATE,
            SFDC_REFERENCE,
            PAC_REFERENCE,
            DOCUMENT_TAX_ID,
            INVOICE_UUID,
            INVOICE_DUE_DATE,
            INVOICE_AMOUNT,
            INVOICE_PREVIOUS_BALANCE,
            PAYMENT_METHOD,
            PAYMENT_DATE,
            PAYMENT_ID,
            ASSIGNMENT_ID,
            PAYMENT_NUMBER,
            COLLECTION_FOR_CASH,
            COLLECTION_FOR_CREDIT,
            CREDITMEMO_RELATED,
            CREDITMEMO,
            CREDITMEMO_ALLOCATED,
            INVOICE_NEW_BALANCE,
            INVOICE_PAYMENT_METHOD,
            PAYMENT_FISCAL_ID,
            PAYMENT_RELEASE,
            PAYMENT_FISCAL_UUID
        )
        SELECT
            COALESCE(Cobza.Ctro,Pay.Ctro),
            SUBSTRING(CS.Territorio_Delivery,17,4),
            SB.Stock_Partner,
            LTRIM(RTRIM(MC.Cliente_V3)),
            MC.Cliente_SAP,
            dbo.FN_TRIM_CIFRAS(MC.Nombre),
            LTRIM(RTRIM(MC.RFC)),
            EAI_OWNER.GETCONV('CifrasControl Payment Type',MC.Metodo_Pago),
            EAI_OWNER.GETCONV('TMD_Cifras Payment Type',CS.Forma_Pago),
            CONVERT(VARCHAR(10),GETDATE(),23),

            CASE
                WHEN ISNULL(Cobza.Status,'Invoice')='Debit Note'
                    THEN 'Debit Note'
                ELSE 'Invoice'
            END,

            CONVERT(VARCHAR(10),Cobza.Fecha_Factura,23),
            LTRIM(RTRIM(Cobza.Factura)),
            LTRIM(RTRIM(Cobza.Nota_Venta)),
            LTRIM(RTRIM(Cobza.RFC)),
            LTRIM(RTRIM(Cobza.UUID_Venta)),

            CONVERT
            (
                VARCHAR(10),
                DATEADD(DAY,ISNULL(Cobza.Dias_Cdto,0),Cobza.Fecha_Factura),
                23
            ),

            CAST(Cobza.Importe_Factura AS VARCHAR(50)),
            CAST(Cobza.Saldo_Anterior AS VARCHAR(50)),

            EAI_OWNER.GETCONV('TMD_Cifras',Cobza.Via_Pago),

            CONVERT(VARCHAR(10),Cobza.Fecha_Asignacion,23),

            Cobza.Pago_ID,
            Cobza.Asignacion_ID,
            Cobza.Numero_Pago,

            CASE
                WHEN CAST(Cobza.Fecha_Asignacion AS DATE)=CAST(Cobza.Fecha_Factura AS DATE)
                THEN CAST(Cobza.Importe AS VARCHAR(50))
                ELSE '0'
            END,

            CASE
                WHEN CAST(Cobza.Fecha_Asignacion AS DATE)=CAST(Cobza.Fecha_Factura AS DATE)
                THEN '0'
                ELSE CAST(Cobza.Importe AS VARCHAR(50))
            END,

            Cobza.Nota_Credito,
            CONVERT(VARCHAR(10),RF.Fecha_Factura,23),

            CASE
                WHEN Cobza.Nota_Credito IS NULL
                THEN ''
                ELSE CAST(Cobza.Importe AS VARCHAR(50))
            END,

            CAST(Cobza.Saldo_Anterior - Cobza.Importe AS VARCHAR(50)),
            Inv.Metodo_Pago,
            P.PayReference,

            CASE
                WHEN Pay.Fecha_Liberacion IS NULL
                    THEN ''
                ELSE CONVERT(VARCHAR(10),Pay.Fecha_Liberacion,23)
            END,

            ISNULL(Pay.Folio_Fiscal,'')
        FROM T3.CFDI_COBRANZA Cobza
        INNER JOIN T3.MOV_CLIENTE MC
            ON Cobza.Cliente_SAP = MC.Cliente_SAP

        LEFT JOIN EAI.CLIENTE_SIEBEL CS
            ON MC.Cliente_V3 = CS.Cliente_V3

        LEFT JOIN
        (
            SELECT DISTINCT
                Territorio,
                Stock_Partner
            FROM SiebelETL.Vans_Vigentes
        ) SB
            ON CS.Territorio_Delivery = SB.Territorio

        LEFT JOIN T3.CFDI_DOCUMENTOS Inv
            ON Cobza.Nota_Venta = Inv.Nota_Venta

        LEFT JOIN T3.REGISTRO_FISCAL RF
            ON Cobza.Nota_Credito = RF.Factura

        CROSS APPLY
        (
            SELECT EAI_OWNER.FN_GET_PAY_REFERENCE
            (
                Cobza.Asignacion_ID
            ) AS PayReference
        ) P

        LEFT JOIN T3.CFDI_DOCUMENTOS Pay
            ON P.PayReference = Pay.Nota_Venta

        WHERE
            ISNULL(CONVERT(VARCHAR(8),Cobza.FECHA_ENVIO,112),'null')
                LIKE '202%'
            AND CAST(Cobza.Fecha_Proceso AS DATE) >=
                CONVERT
                (
                    DATE,
                    EAI_OWNER.GETCONV('TMD_Cifras','Fecha Pago'),
                    112
                )
            AND
            (
                ISNULL(Cobza.RFC,'XAXX010101000') <> 'XAXX010101000'
                OR
                ISNULL(MC.RFC,'XAXX010101000') <> 'XAXX010101000'
            );

        SET @nProceso4 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
        SET STATUS = 1
        WHERE COMPONENT = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
        SET
            FIN = GETDATE(),
            PROCESO_1 = 0,
            PROCESO_2 = 0,
            PROCESO_3 = @nProceso3,
            PROCESO_4 = @nProceso4
        WHERE PID = @nPID;

        COMMIT;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        SET @sErrorCode = CONCAT('SQL-',ERROR_NUMBER());

        SET @sMsg =
            LEFT(ERROR_MESSAGE(),250);

        INSERT INTO EAI_OWNER.MX_EAI_MESSAGE_LOG
        (
            DIRECTION,
            ID,
            CREATED,
            MESSAGE,
            JOB_PID,
            STATUS,
            QUEUE_NAME,
            SIEBEL_ERROR_MESSAGE,
            SOURCE,
            SIEBEL_ERROR_CODE
        )
        VALUES
        (
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'CCEA_DATA_PAYMENT',
            @sMsg,
            'TSQL',
            @sErrorCode
        );

    END CATCH
END;
GO