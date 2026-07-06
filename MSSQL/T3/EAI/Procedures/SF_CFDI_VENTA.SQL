CREATE OR ALTER PROCEDURE [EAI].[SF_CFDI_VENTA]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sMsg       VARCHAR(500),
        @v_ID       VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode VARCHAR(20),
        @dtInicio   DATETIME2(0),
        @nPID       BIGINT,
        @nProceso   INT = 921,
        @nProceso1  INT = 0,
        @nProceso2  INT = 0,
        @nProceso3  INT = 0,
        @nProceso4  INT = 0;

    BEGIN TRY
        SET @dtInicio = SYSDATETIME();
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
            @dtInicio
        );

        SET @v_ID = 'CFDI_UUID_VENTA';

        IF ISNULL(@nEtapa, 0) <= 0
        BEGIN
            DELETE FROM [EAI].[CFDI_UUID_VENTA];

            INSERT INTO [EAI].[CFDI_UUID_VENTA]
            (
                Ctro,
                Fecha_Venta,
                Nota_Venta,
                RFC,
                Cliente_SAP,
                Importe_Vta,
                Saldo_SAP
            )
            SELECT
                Doc.Ctro,
                Doc.Invc_dt,
                Doc.Doc_Num,
                Doc.RFC,
                Doc.Cliente_SAP,
                ISNULL(Doc.Valor_Subt, 0)
                    + ISNULL(Doc.Envio_Subt, 0)
                    + ISNULL(Doc.Credito_Subt, 0)
                    + ISNULL(Doc.Valor_IVA, 0)
                    + ISNULL(Doc.Envio_IVA, 0)
                    + ISNULL(Doc.Credito_IVA, 0),
                ISNULL(DOI.Saldo_SAP, 0)
            FROM [EAI].[CFDI_Bitacora] AS Doc
            LEFT JOIN
            (
                SELECT
                    SAP.Referencia AS Nota_Venta,
                    MAX(SAP.Cliente) AS Cliente_SAP,
                    MIN(SAP.Fecha_Doc) AS Fecha_Doc,
                    SUM(ISNULL(SAP.Monto, 0)) AS Saldo_SAP
                FROM [EAI].[T3R_Cartera_SAP_OLD] AS SAP
                GROUP BY SAP.Referencia
            ) AS DOI
                ON Doc.Doc_Num = DOI.Nota_Venta
            WHERE Doc.Tipo_Vta = 'Vta'
              AND ISNULL(Doc.RFC, '') <> 'XAXX010101000';
        END;

        SET @v_ID = 'ScrPrompt';

        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            ;WITH Cobza AS
            (
                SELECT
                    Base.Factura,
                    SUM(Base.Importe) AS Importe,
                    SUM(Base.Efectivo) AS Efectivo,
                    SUM(Base.Agrupado) AS Agrupado,
                    SUM(Base.Aplica_NC) AS Aplica_NC,
                    SUM(Base.Incobrable) AS Incobrable,
                    SUM(Base.Efectivo * Base.Timbrado) AS Efectivo_UUID,
                    SUM(Base.Agrupado * Base.Timbrado) AS Agrupado_UUID,
                    SUM(Base.Aplica_NC * Base.Timbrado) AS Aplica_NC_UUID,
                    SUM(Base.Importe * Base.Timbrado) AS Importe_UUID
                FROM
                (
                    SELECT
                        C.Factura,
                        ISNULL(C.Importe, 0) AS Importe,
                        CASE WHEN C.Via_Pago = '01'
                             THEN ISNULL(C.Importe, 0) ELSE 0 END AS Efectivo,
                        CASE WHEN C.Via_Pago IN ('02', '03')
                             THEN ISNULL(C.Importe, 0) ELSE 0 END AS Agrupado,
                        CASE WHEN C.Via_Pago = 'CM'
                             THEN ISNULL(C.Importe, 0) ELSE 0 END AS Aplica_NC,
                        CASE WHEN C.Via_Pago = 'AI'
                             THEN ISNULL(C.Importe, 0) ELSE 0 END AS Incobrable,
                        CASE WHEN Pago.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                            + CASE WHEN Agr.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                            + CASE WHEN Nota.Folio_Fiscal IS NULL THEN 0 ELSE 1 END AS Timbrado
                    FROM [T3].[CFDI_Cobranza] AS C
                    LEFT JOIN [T3].[CFDI_Documentos] AS Pago
                        ON C.Asignacion_ID = Pago.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Agrupacion_Pago] AS AgrP
                        ON C.Asignacion_ID = AgrP.Asignacion_ID
                    LEFT JOIN [T3].[CFDI_Documentos] AS Agr
                        ON CONVERT(VARCHAR(30), AgrP.Agrupacion) = Agr.Nota_Venta
                    LEFT JOIN [T3].[CFDI_Documentos] AS Nota
                        ON C.Nota_Credito = Nota.Nota_Venta
                ) AS Base
                GROUP BY Base.Factura
            )
            UPDATE Vta
               SET Importe = Cobza.Importe,
                   Efectivo = Cobza.Efectivo,
                   Agrupado = Cobza.Agrupado,
                   Aplica_NC = Cobza.Aplica_NC,
                   Incobrable = Cobza.Incobrable,
                   Efectivo_UUID = Cobza.Efectivo_UUID,
                   Agrupado_UUID = Cobza.Agrupado_UUID,
                   Aplica_NC_UUID = Cobza.Aplica_NC_UUID,
                   Importe_UUID = Cobza.Importe_UUID,
                   Metodo_Pago = CFD.Metodo_Pago
            FROM [EAI].[CFDI_UUID_VENTA] AS Vta
            INNER JOIN Cobza
                ON Vta.Nota_Venta = Cobza.Factura
            LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                ON Vta.Nota_Venta = CFD.Nota_Venta;

            SET @nProceso1 = @@ROWCOUNT;
        END;

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
    END TRY
    BEGIN CATCH
        SET @sErrorCode = 'ERR-' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        SET @sMsg = SUBSTRING(CAST(ERROR_NUMBER() AS VARCHAR(10)) + '-' + ERROR_MESSAGE(), 1, 250);

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
            'Job Logging',
            @v_ID,
            GETDATE(),
            NULL,
            @nPID,
            'Error',
            'SF_CFDI_VENTA',
            @sMsg,
            'T-SQL',
            @sErrorCode,
            NULL,
            NULL,
            NULL
        );

        PRINT '----------------------------------';
        PRINT '**** Error en SF_CFDI_VENTA *****';
        PRINT @sMsg;

        THROW;
    END CATCH;
END;
GO
