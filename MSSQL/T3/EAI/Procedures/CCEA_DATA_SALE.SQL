CREATE OR ALTER PROCEDURE dbo.CCEA_DATA_SALE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @v_ID         VARCHAR(50),
        @sMsg         VARCHAR(500),
        @sErrorCode   VARCHAR(20),
        @nPID         BIGINT,
        @nProceso     INT = 702,
        @nProceso3    INT = 0,
        @nProceso4    INT = 0;

    BEGIN TRY

        SET @nPID = NEXT VALUE FOR EAI_OWNER.ProcessID;

        EXEC EAI_OWNER.Log_Start @nProceso;

        INSERT INTO T3.RF_PROCESOS_LOG
        (
            PID,
            Proceso,
            Fecha_Proc_BATMD,
            Inicio
        )
        VALUES
        (
            @nPID,
            @nProceso,
            NULL,
            GETDATE()
        );

        TRUNCATE TABLE EAI.CC_DATA_SALE;

        ------------------------------------------------------------------
        -- Carga principal
        ------------------------------------------------------------------

        INSERT INTO EAI.CC_DATA_SALE
        (
            PLANT,
            INVOICE_DATE,
            DOCUMENT_TYPE,
            SAP_CUSTOMER,
            SFDC_REFERENCE,
            SAP_ORDER_NUMBER,
            PAC_ORDER_NUMBER,
            SAP_SALES_AMOUNT,
            T3_SALES_AMOUNT,
            PAC_SALES_AMOUNT,
            PAC_FISCAL_UUID,
            TERRITORY
        )
        SELECT
            B.Ctro,
            CONVERT(VARCHAR(10), B.Invc_dt, 23),
            CASE
                WHEN PG.Entrega IS NULL THEN 'Prompt'
                ELSE 'Presales'
            END,
            B.Cliente_SAP,
            LTRIM(RTRIM(B.Doc_Num)),
            LTRIM(RTRIM(B.Doc_Num)),
            LTRIM(RTRIM(B.Nota_Venta_CFDI)),
            CAST(
                (
                    B.Valor_Subt +
                    B.Valor_IVA +
                    B.Envio_Subt +
                    B.Envio_IVA +
                    B.Credito_Subt +
                    B.Credito_IVA
                ) AS VARCHAR(30)
            ),
            CAST(
                (
                    B.Valor_Subt +
                    B.Valor_IVA +
                    B.Envio_Subt +
                    B.Envio_IVA +
                    B.Credito_Subt +
                    B.Credito_IVA
                ) AS VARCHAR(30)
            ),
            CASE
                WHEN B.Doc_Num = B.Nota_Venta_CFDI
                     AND I.Folio_Fiscal IS NOT NULL
                THEN CAST(I.Valor_Subt + I.Valor_IVA AS VARCHAR(30))

                WHEN LEFT(B.Nota_Venta_CFDI,2) = 'G-'
                THEN CAST(
                        B.Valor_Subt +
                        B.Valor_IVA +
                        B.Envio_Subt +
                        B.Envio_IVA +
                        B.Credito_Subt +
                        B.Credito_IVA
                     AS VARCHAR(30))
                ELSE '0'
            END,
            I.Folio_Fiscal,
            '0000'
        FROM EAI.CFDI_Bitacora B
        LEFT JOIN T3.Preventa_General PG
            ON B.Doc_Num = PG.Factura
        LEFT JOIN EAI.CFDI_Informe I
            ON B.Nota_Venta_CFDI = I.Folio_Interno
        CROSS JOIN EAI.FC__TIME_WINDOW TW
        WHERE CAST(B.Invc_dt AS DATE)
              >= CONVERT(DATE,TW.Start_Date,103)
          AND CAST(B.Invc_dt AS DATE)
              < CAST(GETDATE() AS DATE)
          AND B.Invc_dt >= '20200921'
          AND B.Doc_Num NOT LIKE 'DESC-%';

        SET @nProceso4 = @@ROWCOUNT;

        ------------------------------------------------------------------
        -- Segunda carga
        ------------------------------------------------------------------

        INSERT INTO EAI.CC_DATA_SALE
        (
            PLANT,
            INVOICE_DATE,
            DOCUMENT_TYPE,
            SAP_CUSTOMER,
            SFDC_REFERENCE,
            SAP_ORDER_NUMBER,
            PAC_ORDER_NUMBER,
            SAP_SALES_AMOUNT,
            T3_SALES_AMOUNT,
            PAC_SALES_AMOUNT,
            PAC_FISCAL_UUID,
            TERRITORY
        )
        SELECT
            Info.Distributor,
            Info.Doc_Date_Str,
            'Prompt',
            RIGHT('0000000000' + Info.Customer,10),
            Info.Doc_Num_Ref2,
            Info.Doc_Num_Ref2,
            '',
            Info.Amount,
            '0',
            '0',
            '',
            '0000'
        FROM
        (
            SELECT
                SAP.Distributor,
                SAP.Doc_Num_Ref2,
                SAP.Customer,
                (SAP.Doc_NetAmt + SAP.Doc_TaxAmt) Amount,
                CONVERT(VARCHAR(10),
                        CONVERT(DATE,SAP.Doc_Date,112),23) Doc_Date_Str,
                CASE
                    WHEN FG.Entrega IS NOT NULL THEN 'Prompt'
                    WHEN PG.Entrega IS NOT NULL THEN 'Presale'
                    ELSE NULL
                END Tipo_Documento
            FROM EAI.T3R_Sales_Docs_Old SAP
            LEFT JOIN T3.Factura_General FG
                ON SAP.Doc_Num_R3 = FG.Entrega
            LEFT JOIN T3.Preventa_General PG
                ON SAP.Doc_Num_R3 = PG.Entrega
            CROSS JOIN EAI.FC__TIME_WINDOW TW
            WHERE SAP.Doc_Date >=
                  CONVERT(VARCHAR(8),
                          CONVERT(DATE,TW.Start_Date,103),112)
              AND SAP.Doc_Date >= '20200921'
              AND SAP.Doc_Status = 'C'
              AND SAP.Customer NOT IN
              (
                  SELECT Target
                  FROM EAI_OWNER.MX_HashTable
                  WHERE Type = 'CifrasControl'
                  AND Source = 'Discarding Customer'
              )
        ) Info
        WHERE Info.Tipo_Documento IS NULL;

        SET @nProceso3 = @@ROWCOUNT;

        UPDATE EAI_OWNER.MX_COMPONENTS
           SET Status = 1
        WHERE Component = @nProceso;

        UPDATE T3.RF_PROCESOS_LOG
           SET Fin = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
        WHERE PID = @nPID;

    END TRY
    BEGIN CATCH

        SET @sErrorCode =
            CONCAT('SQL-',ERROR_NUMBER());

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
            'CCEA_DATA_SALE_1',
            @sMsg,
            'TSQL',
            @sErrorCode
        );

        THROW;
    END CATCH
END;
GO
