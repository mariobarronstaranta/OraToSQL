/*
    Homologo SQL Server de EAI_OWNER.WA_DIF_IVA_SAP_T3 (Oracle).

    Objetivo:
      Comparar el IVA almacenado en T3 contra el IVA recibido de SAP para las
      facturas C025 recientes y registrar las diferencias en NDC_ISSUE_IVA.

    Regla importante heredada de Oracle:
      Si la diferencia previamente registrada es cero (o no existe registro),
      se inserta una incidencia. Si es distinta de cero, se actualiza.
*/
CREATE OR ALTER PROCEDURE [EAI_OWNER].[WA_DIF_IVA_SAP_T3]
    @pDias INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @nPedidos INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /*
            Primero se materializa el resultado. Esto permite usar el mismo
            conjunto tanto para UPDATE como para INSERT; un CTE de SQL Server
            solamente puede ser consumido por la sentencia inmediata.
        */
        ;WITH Info AS
        (
            SELECT
                PG.Factura,
                PG.Entrega,
                PG.Fecha_Factura,
                SUM(ISNULL(PD.Valor_Subt, 0)) AS Valor_Subt,
                SUM(ISNULL(PD.Valor_IVA, 0))  AS Valor_IVA
            FROM [T3].[Preventa_General] PG
            INNER JOIN [T3].[Preventa_Detalle] PD
                ON PD.Factura = PG.Factura
            WHERE PG.Clase_Factura = 'C025'
              AND PG.Fecha_Factura > DATEADD(DAY, -ISNULL(@pDias, 30), SYSDATETIME())
            GROUP BY
                PG.Factura,
                PG.Entrega,
                PG.Fecha_Factura
        ),
        Diff AS
        (
            SELECT
                I.Factura,
                I.Valor_IVA,
                -- SAP almacena estos importes en centavos; por eso se divide
                -- entre 100 antes de comparar contra los importes de T3.
                SUM(ISNULL(D.Valor_Subt, 0) / 100.0) AS SAP_Valor_Subt,
                SUM(ISNULL(D.Valor_IVA, 0) / 100.0) AS SAP_Valor_IVA
            FROM Info I
            INNER JOIN [EAI_OWNER].[tmp_Document_Detail] D
                ON D.ReferenceID = I.Entrega
            GROUP BY
                I.Factura,
                I.Entrega,
                I.Fecha_Factura,
                I.Valor_Subt,
                I.Valor_IVA
        )
        SELECT
            D.Factura,
            D.SAP_Valor_IVA - D.Valor_IVA AS Diferencia,
            ISNULL(Issue.Diferencia, 0) AS Diff_Issue
        INTO #Ajustes
        FROM Diff D
        LEFT JOIN [T3].[NDC_ISSUE_IVA] Issue
            ON Issue.Factura = D.Factura
        WHERE D.Valor_IVA <> D.SAP_Valor_IVA;

        /* Una incidencia previa distinta de cero se refresca, no se duplica. */
        UPDATE Issue
        SET
            Issue.Diferencia  = A.Diferencia,
            Issue.Fecha_Update = SYSDATETIME()
        FROM [T3].[NDC_ISSUE_IVA] Issue
        INNER JOIN #Ajustes A
            ON A.Factura = Issue.Factura
        WHERE A.Diff_Issue <> 0;

        /*
            Oracle incrementa el contador unicamente en esta rama. Se captura
            @@ROWCOUNT inmediatamente despues del INSERT para conservarlo.
        */
        INSERT INTO [T3].[NDC_ISSUE_IVA]
            (Factura, Diferencia, Fecha_Insert)
        SELECT
            A.Factura,
            A.Diferencia,
            SYSDATETIME()
        FROM #Ajustes A
        WHERE A.Diff_Issue = 0;

        SET @nPedidos = @@ROWCOUNT;

        PRINT CONCAT('Documentos -> ', @nPedidos);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        DECLARE
            @sErrorCode VARCHAR(30),
            @sMsg       VARCHAR(300);

        SET @sErrorCode = CONCAT('SQL-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- Se revierte el trabajo parcial antes de registrar el error. El
        -- INSERT siguiente queda fuera de la transaccion y puede persistir.
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

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
            'WA Payment',
            NULL,
            SYSDATETIME(),
            NULL,
            'Error',
            'WA_DIF_IVA_SAP_T3',
            @sMsg,
            'TSQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        -- Oracle registra la excepcion y termina sin relanzarla. Se conserva
        -- el mismo contrato para no cambiar el comportamiento del llamador.
        RETURN;
    END CATCH;
END;
GO
