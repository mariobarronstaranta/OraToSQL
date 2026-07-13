CREATE OR ALTER PROCEDURE [EAI_OWNER].[PROC_RECEIVE_REFERENCE]
(
    @sQUEUE_NAME VARCHAR(100) = 'All',
    @nLog        INT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID         VARCHAR(50) = NULL,
        @sErrorCode   VARCHAR(500),
        @sMsg         VARCHAR(500),
        @nPID         BIGINT,
        @nProceso     INT = 852,
        @nProceso1    INT = 0,
        @nProceso2    INT = 0,
        @nProceso3    INT = 0,
        @nProceso4    INT = 0,
        @v_Regs       INT = 0;

    /*
        Developer notes
        ---------------
        Oracle original recorre MX_RECEIVE_MESSAGE_LOG y llena Reference desde
        distintos nodos XML segun Queue_Name. Esta version conserva el objetivo
        con updates set-based:

        - Solo procesa mensajes con DocNum LIKE '000%' y Reference IS NULL.
        - Product, Price, Customer, Invoice, Intercompany y Order toman una ruta
          XML fija.
        - Customer y Customer Credit descartan el mensaje cuando la referencia
          extraida es NULL/vacia, igual que el Oracle.
        - Replenishment busca el primer PurchaseOrderNumber con Qualifier 001 o
          999 dentro de DeliveryLineReference.

        Nota de compatibilidad:
        El cursor Oracle de Customer Credit filtra Queue_Name = 'Customer',
        aunque el bloque se ejecuta con sQUEUE_NAME = 'Customer Credit'. Para no
        perder mensajes migrados con cualquiera de las dos convenciones, esta
        conversion procesa Queue_Name IN ('Customer Credit', 'Customer') pero
        solo cuando el XML contiene raiz CustomerCredit. Asi evita que el bloque
        Customer normal descarte accidentalmente un XML de credito.
    */

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
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

        IF @nLog > 0
            PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        IF @sQUEUE_NAME IN ('Product', 'All')
        BEGIN
            UPDATE Msg
               SET Reference = NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                       '(/Product/Message/GeneralData/MaterialNumber/text())[1]',
                       'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'Product'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            SET @v_Regs = @@ROWCOUNT;
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Product' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Price Master', 'All')
        BEGIN
            UPDATE Msg
               SET Reference = NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                       '(/PriceMaster/Message/PriceHeader/MaterialNumber/text())[1]',
                       'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'Price Master'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            SET @v_Regs = @@ROWCOUNT;
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Price Master' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Customer', 'All')
        BEGIN
            DECLARE @CustomerRows TABLE
            (
                Row_ID VARCHAR(50) NOT NULL PRIMARY KEY,
                CustomerNumber VARCHAR(50) NULL
            );

            INSERT INTO @CustomerRows
            (
                Row_ID,
                CustomerNumber
            )
            SELECT
                Msg.Row_ID,
                NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                    '(/Customer/Message/GeneralData/V3CustomerNumber/text())[1]',
                    'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'Customer'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL
              AND Msg.XML_Content.exist('/Customer') = 1;

            UPDATE Msg
               SET Reference = Rows.CustomerNumber
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            INNER JOIN @CustomerRows AS Rows
                ON Rows.Row_ID = Msg.Row_ID;

            UPDATE Msg
               SET Processed = GETDATE(),
                   Status = 'Discard',
                   Reference = 'NULL'
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            INNER JOIN @CustomerRows AS Rows
                ON Rows.Row_ID = Msg.Row_ID
            WHERE Rows.CustomerNumber IS NULL;

            SET @v_Regs = (SELECT COUNT(*) FROM @CustomerRows);
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Customer' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Customer Credit', 'All')
        BEGIN
            DECLARE @CreditRows TABLE
            (
                Row_ID VARCHAR(50) NOT NULL PRIMARY KEY,
                CustomerNumber VARCHAR(50) NULL
            );

            INSERT INTO @CreditRows
            (
                Row_ID,
                CustomerNumber
            )
            SELECT
                Msg.Row_ID,
                NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                    '(/CustomerCredit/Message/PartnerData/V3CustomerNumber/text())[1]',
                    'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name IN ('Customer Credit', 'Customer')
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL
              AND Msg.XML_Content.exist('/CustomerCredit') = 1;

            UPDATE Msg
               SET Reference = Rows.CustomerNumber
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            INNER JOIN @CreditRows AS Rows
                ON Rows.Row_ID = Msg.Row_ID;

            UPDATE Msg
               SET Processed = GETDATE(),
                   Status = 'Discard',
                   Reference = 'NULL'
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            INNER JOIN @CreditRows AS Rows
                ON Rows.Row_ID = Msg.Row_ID
            WHERE Rows.CustomerNumber IS NULL;

            SET @v_Regs = (SELECT COUNT(*) FROM @CreditRows);
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Customer Credit' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Invoice', 'All')
        BEGIN
            UPDATE Msg
               SET Reference = NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                       '(/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1]',
                       'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'Invoice'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            SET @v_Regs = @@ROWCOUNT;
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Invoice' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Invoice-Intercompany', 'All')
        BEGIN
            UPDATE Msg
               SET Reference = NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                       '(/InvoiceIntercompany/Message/InvoiceHeader/DocumentNumber/text())[1]',
                       'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'Invoice-Intercompany'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            SET @v_Regs = @@ROWCOUNT;
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Invoice Intercompany' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Order', 'All')
        BEGIN
            UPDATE Msg
               SET Reference = NULLIF(LTRIM(RTRIM(Msg.XML_Content.value(
                       '(/OrderAcknowledge/Message/ReferenceData/DocumentNumber/text())[1]',
                       'varchar(50)'))), '')
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            WHERE Msg.Queue_Name = 'OrderAcknowledge'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            SET @v_Regs = @@ROWCOUNT;
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Order' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @sQUEUE_NAME IN ('Replenishment', 'All')
        BEGIN
            DECLARE @ReplenishmentRows TABLE
            (
                Row_ID VARCHAR(50) NOT NULL PRIMARY KEY,
                PurchaseOrderNumber VARCHAR(500) NULL
            );

            INSERT INTO @ReplenishmentRows
            (
                Row_ID,
                PurchaseOrderNumber
            )
            SELECT
                Msg.Row_ID,
                Ref.PurchaseOrderNumber
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            OUTER APPLY
            (
                SELECT TOP (1)
                    NULLIF(LTRIM(RTRIM(LineRef.Node.value(
                        '(PurchaseOrderNumber/text())[1]',
                        'varchar(500)'))), '') AS PurchaseOrderNumber
                FROM Msg.XML_Content.nodes(
                    '/VanReplenishment/Message/DeliveryHeader/DeliveryLineItem/DeliveryLineReference'
                ) AS LineRef(Node)
                WHERE LineRef.Node.value('(Qualifier/text())[1]', 'varchar(10)') IN ('001', '999')
                ORDER BY CASE LineRef.Node.value('(Qualifier/text())[1]', 'varchar(10)')
                             WHEN '001' THEN 1
                             WHEN '999' THEN 2
                             ELSE 3
                         END
            ) AS Ref
            WHERE Msg.Queue_Name = 'VanReplenishment'
              AND Msg.DocNum LIKE '000%'
              AND Msg.Reference IS NULL;

            UPDATE Msg
               SET Reference = Rows.PurchaseOrderNumber
            FROM [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG] AS Msg
            INNER JOIN @ReplenishmentRows AS Rows
                ON Rows.Row_ID = Msg.Row_ID
            WHERE Rows.PurchaseOrderNumber IS NOT NULL;

            SET @v_Regs = (SELECT COUNT(*) FROM @ReplenishmentRows);
            SET @nProceso4 += @v_Regs;

            IF @nLog > 0
                PRINT LEFT('Replenishment' + REPLICATE(' ', 30), 30) + ' -> ' + CONVERT(VARCHAR(20), @v_Regs);
        END;

        IF @nLog > 0
            PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
        WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = GETDATE(),
               Proceso_1 = @nProceso1,
               Proceso_2 = @nProceso2,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
        WHERE PID = @nPID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @sErrorCode = 'SQL-' + CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(20), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
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
            SIEBEL_ERROR_CODE,
            RETRY_COUNT,
            SEQUENCE,
            PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'PROC_RECEIVE_REFERENCE',
            @sMsg,
            'XML',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        THROW;
    END CATCH;
END;
GO
