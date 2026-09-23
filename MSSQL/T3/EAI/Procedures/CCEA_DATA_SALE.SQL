/*
    Procedure : EAI.CCEA_DATA_SALE_OPTIMIZADO
    Objetivo  : Reconstruir EAI.CC_DATA_SALE para el modulo Cifras Control,
                conciliando importes de T3, PAC y documentos SAP sin origen T3.

    Guia para desarrolladores JR:
    - La carga es completa: CC_DATA_SALE se vacia con TRUNCATE y se reconstruye.
    - Primera carga: documentos existentes en CFDI_BITACORA (fuente T3/PAC).
    - Segunda carga: documentos SAP que todavia no existen como factura o
      preventa en T3.
    - Las fechas del destino son VARCHAR con formato ISO YYYY-MM-DD.
    - Este archivo crea una version paralela; no reemplaza el original.

    Alias frecuentes:
    - B   = CFDI_BITACORA, origen operativo T3.
    - I   = CFDI_INFORME, datos fiscales confirmados por el PAC.
    - SAP = T3R_Sales_Docs_Old, documentos provenientes de SAP.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[CCEA_DATA_SALE]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @v_ID          VARCHAR(50) = 'Inicio',
        @sMsg          VARCHAR(500),
        @sErrorCode    VARCHAR(20),
        @nPID          BIGINT,
        @nProceso      INT = 702,
        @nProceso3     INT = 0,
        @nProceso4     INT = 0,
        @dVentana      DATE,
        @dFechaMinima  DATE = CONVERT(DATE, '20200921', 112),
        @dFechaInicio  DATE,
        @dHoy          DATE = CONVERT(DATE, GETDATE());

    BEGIN TRY
        -------------------------------------------------------------------
        -- 1. Validar la ventana antes de vaciar la tabla destino
        -------------------------------------------------------------------
        -- Start_Date esta configurada como texto DD/MM/YYYY (estilo 103).
        SELECT @dVentana = TRY_CONVERT(DATE, TW.Start_Date, 103)
        FROM [EAI].[FC__TIME_WINDOW] AS TW;

        IF @dVentana IS NULL
            THROW 54601, 'FC__TIME_WINDOW.Start_Date no contiene una fecha DD/MM/YYYY valida.', 1;

        -- Nunca se cargan datos anteriores al inicio historico 21/09/2020.
        SET @dFechaInicio = CASE WHEN @dVentana > @dFechaMinima
                                 THEN @dVentana ELSE @dFechaMinima END;

        -------------------------------------------------------------------
        -- 2. Abrir auditoria del componente 702
        -------------------------------------------------------------------
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, GETDATE());

        SET @v_ID = 'Inicializar CC_DATA_SALE';

        -- El proceso publica una fotografia completa, no una carga incremental.
        TRUNCATE TABLE [EAI].[CC_DATA_SALE];

        -------------------------------------------------------------------
        -- 3. Carga principal desde CFDI_BITACORA
        -------------------------------------------------------------------
        SET @v_ID = 'Carga T3 y PAC';

        /*
            Informe reduce CFDI_INFORME a una fila por folio. Esto evita que una
            anomalia duplicada multiplique ventas en el archivo de Cifras Control.
            En datos normales MAX devuelve exactamente el valor de la unica fila.
        */
        ;WITH Informe AS
        (
            SELECT
                I.Folio_Interno,
                MAX(I.Folio_Fiscal) AS Folio_Fiscal,
                MAX(I.Valor_Subt) AS Valor_Subt,
                MAX(I.Valor_IVA) AS Valor_IVA
            FROM [EAI].[CFDI_INFORME] AS I
            GROUP BY I.Folio_Interno
        )
        INSERT INTO [EAI].[CC_DATA_SALE]
        (
            Plant, Invoice_Date, Document_Type, SAP_Customer,
            SFDC_Reference, SAP_Order_Number, PAC_Order_Number,
            SAP_Sales_Amount, T3_Sales_Amount, PAC_Sales_Amount,
            PAC_Fiscal_UUID, Territory
        )
        SELECT
            B.Ctro,
            CONVERT(VARCHAR(10), B.Invc_dt, 23),
            CASE WHEN EXISTS
                 (
                     SELECT 1
                     FROM [T3].[Preventa_General] AS PG
                     WHERE PG.Factura = B.Doc_Num
                       -- Oracle clasifica como preventa solo si existe Entrega.
                       AND PG.Entrega IS NOT NULL
                 )
                 THEN 'Presales' ELSE 'Prompt' END,
            B.Cliente_SAP,
            LTRIM(RTRIM(B.Doc_Num)),
            LTRIM(RTRIM(B.Doc_Num)),
            LTRIM(RTRIM(B.Nota_Venta_CFDI)),
            CONVERT(VARCHAR(30), A.Importe_T3),
            CONVERT(VARCHAR(30), A.Importe_T3),
            CASE
                -- Individual timbrado: usar subtotal e IVA reportados por PAC.
                WHEN B.Doc_Num = B.Nota_Venta_CFDI AND I.Folio_Fiscal IS NOT NULL
                    THEN CONVERT(VARCHAR(30), I.Valor_Subt + I.Valor_IVA)
                -- Agrupado G-: Oracle utiliza el importe operativo de T3.
                WHEN LEFT(B.Nota_Venta_CFDI, 2) = 'G-'
                    THEN CONVERT(VARCHAR(30), A.Importe_T3)
                ELSE '0'
            END,
            LTRIM(RTRIM(I.Folio_Fiscal)),
            '0000'
        FROM [EAI].[CFDI_BITACORA] AS B
        LEFT JOIN Informe AS I ON I.Folio_Interno = B.Nota_Venta_CFDI
        CROSS APPLY
        (
            /*
                Oracle permite credito NULL tratandolo como cero. Los valores
                base y de envio conservan su comportamiento original.
            */
            VALUES
            (
                B.Valor_Subt + B.Valor_IVA + B.Envio_Subt + B.Envio_IVA
                + ISNULL(B.Credito_Subt, 0) + ISNULL(B.Credito_IVA, 0)
            )
        ) AS A(Importe_T3)
        WHERE B.Invc_dt >= @dFechaInicio
          AND B.Invc_dt < @dHoy
          -- Ambas exclusiones existen en el procedimiento Oracle.
          AND B.Doc_Num NOT LIKE 'CONEC%'
          AND B.Doc_Num NOT LIKE 'DESC-%';

        SET @nProceso4 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 4. Carga de documentos SAP que no tienen documento T3
        -------------------------------------------------------------------
        SET @v_ID = 'Carga exclusiva SAP';

        /*
            Factura_General y Preventa_General solo se usaban para decidir si el
            documento ya existe en T3. NOT EXISTS expresa esa intencion, evita
            duplicados y permite busquedas directas por Entrega.
        */
        INSERT INTO [EAI].[CC_DATA_SALE]
        (
            Plant, Invoice_Date, Document_Type, SAP_Customer,
            SFDC_Reference, SAP_Order_Number, PAC_Order_Number,
            SAP_Sales_Amount, T3_Sales_Amount, PAC_Sales_Amount,
            PAC_Fiscal_UUID, Territory
        )
        SELECT
            SAP.Distributor,
            CONVERT(VARCHAR(10), D.Doc_Date, 23),
            'Prompt',
            RIGHT('0000000000' + SAP.Customer, 10),
            SAP.Doc_Num_Ref2,
            SAP.Doc_Num_Ref2,
            '',
            SAP.Doc_NetAmt + SAP.Doc_TaxAmt,
            '0',
            '0',
            '',
            '0000'
        FROM [EAI].[T3R_Sales_Docs_Old] AS SAP
        -- Doc_Date es VARCHAR YYYYMMDD. Una fecha invalida produce NULL y se excluye.
        CROSS APPLY (VALUES (TRY_CONVERT(DATE, SAP.Doc_Date, 112))) AS D(Doc_Date)
        WHERE D.Doc_Date >= @dFechaInicio
          AND SAP.Doc_Status = 'C'
          AND NOT EXISTS
          (
              SELECT 1 FROM [T3].[Factura_General] AS FG
              WHERE FG.Entrega = SAP.Doc_Num_R3
          )
          AND NOT EXISTS
          (
              SELECT 1 FROM [T3].[Preventa_General] AS PG
              WHERE PG.Entrega = SAP.Doc_Num_R3
          )
          /*
              Se conserva NOT IN porque reproduce exactamente la regla Oracle.
              El catalogo MX_HashTable no debe contener Target NULL para este tipo.
          */
          AND SAP.Customer NOT IN
          (
              SELECT H.Target
              FROM [EAI_OWNER].[MX_HashTable] AS H
              WHERE H.Type = 'CifrasControl'
                AND H.Source = 'Discarding Customer'
          );

        SET @nProceso3 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 5. Cerrar auditoria
        -------------------------------------------------------------------
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
         WHERE Component = @nProceso;

        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = GETDATE(),
               Proceso_1 = 0,
               Proceso_2 = 0,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        /*
            @v_ID indica la etapa que fallo. THROW propaga el error para que el
            caller pueda detectar que la fotografia quedo incompleta.
        */
        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction, ID, Created, Message, Job_PID, Status,
            Queue_Name, Siebel_Error_Message, Source, Siebel_Error_Code
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error',
            'CCEA_DATA_SALE_1', @sMsg, 'TSQL', @sErrorCode
        );

        THROW;
    END CATCH;
END;
GO
