/*
    Procedure : EAI.SF_CFDI_VENTA_OPTIMIZADO
    Objetivo  : Construir EAI.CFDI_UUID_VENTA y enriquecer cada venta con sus
                importes de cobranza y su metodo de pago.

    Guia para desarrolladores JR:
    - @nEtapa controla desde que punto se procesa:
        0  = reconstruir el reporte y calcular cobranza.
        1..10 = conservar el reporte y recalcular cobranza.
        >10 = solo cerrar las marcas de auditoria.
      NULL se trata como 0, igual que en Oracle.
    - El proceso incluye solamente ventas (`Tipo_Vta = 'Vta'`).
    - El RFC generico XAXX010101000 se excluye porque corresponde a ventas
      agrupadas y este reporte trabaja por nota de venta individual.
    - El procedimiento original y el job no se modifican con este archivo.

    Conceptos importantes:
    - Importe_Vta = subtotal + IVA + envio + credito registrados en T3.
    - Saldo_SAP = suma de partidas de cartera SAP para la nota de venta.
    - Importe = total de movimientos de cobranza.
    - Efectivo, Agrupado, Aplica_NC e Incobrable clasifican el importe segun
      la via de pago 01, 02/03, CM y AI respectivamente.
    - Las columnas *_UUID contienen solamente importes respaldados por un
      comprobante fiscal timbrado.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[SF_CFDI_VENTA_OPTIMIZADO]
    @nEtapa INT = 0
AS
BEGIN
    -- Evita mensajes repetidos de "N filas afectadas" enviados al job.
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
        -------------------------------------------------------------------
        -- 1. Abrir auditoria del componente 921
        -------------------------------------------------------------------
        SET @dtInicio = SYSDATETIME();

        -- La secuencia evita que dos ejecuciones compartan el mismo PID.
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        -- Esta fila se cierra al final con fecha y contadores de proceso.
        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, @dtInicio);

        -------------------------------------------------------------------
        -- 2. Reconstruir el universo de ventas individuales
        -------------------------------------------------------------------
        SET @v_ID = 'CFDI_UUID_VENTA';

        IF ISNULL(@nEtapa, 0) <= 0
        BEGIN
            -- El reporte es una fotografia completa, no una carga incremental.
            DELETE FROM [EAI].[CFDI_UUID_VENTA];

            /*
                Ventas conserva las filas de bitacora que pertenecen al reporte.
                VentaClave evita multiplicar la cartera si por una anomalia la
                bitacora contiene dos filas con el mismo Doc_Num.
            */
            ;WITH Ventas AS
            (
                SELECT
                    B.Ctro,
                    B.Invc_dt AS Fecha_Venta,
                    B.Doc_Num AS Nota_Venta,
                    B.RFC,
                    B.Cliente_SAP,
                    ISNULL(B.Valor_Subt, 0)
                    + ISNULL(B.Envio_Subt, 0)
                    + ISNULL(B.Credito_Subt, 0)
                    + ISNULL(B.Valor_IVA, 0)
                    + ISNULL(B.Envio_IVA, 0)
                    + ISNULL(B.Credito_IVA, 0) AS Importe_Vta
                FROM [EAI].[CFDI_BITACORA] AS B
                WHERE B.Tipo_Vta = 'Vta'
                  AND ISNULL(B.RFC, '') <> 'XAXX010101000'
            ), VentaClave AS
            (
                SELECT DISTINCT Nota_Venta FROM Ventas
            ), SaldoSAP AS
            (
                /*
                    Solo se agrega cartera de documentos presentes en el reporte.
                    El original agregaba primero toda T3R_Cartera_SAP_OLD.
                */
                SELECT
                    S.Referencia AS Nota_Venta,
                    SUM(ISNULL(S.Monto, 0)) AS Saldo_SAP
                FROM [EAI].[T3R_Cartera_SAP_OLD] AS S
                INNER JOIN VentaClave AS V ON V.Nota_Venta = S.Referencia
                GROUP BY S.Referencia
            )
            INSERT INTO [EAI].[CFDI_UUID_VENTA]
            (
                Ctro, Fecha_Venta, Nota_Venta, RFC,
                Cliente_SAP, Importe_Vta, Saldo_SAP
            )
            SELECT
                V.Ctro, V.Fecha_Venta, V.Nota_Venta, V.RFC,
                V.Cliente_SAP, V.Importe_Vta, ISNULL(S.Saldo_SAP, 0)
            FROM Ventas AS V
            LEFT JOIN SaldoSAP AS S ON S.Nota_Venta = V.Nota_Venta;
        END;

        -------------------------------------------------------------------
        -- 3. Clasificar cobranza y detectar comprobantes timbrados
        -------------------------------------------------------------------
        SET @v_ID = 'ScrPrompt';

        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            /*
                Documento reduce CFDI_Documentos a una fila por Nota_Venta.
                Tiene_UUID vale 1 cuando al menos un registro posee folio fiscal.
                MAX(Metodo_Pago) entrega un valor determinista si hay duplicados.
            */
            ;WITH VentaClave AS
            (
                SELECT DISTINCT Nota_Venta
                FROM [EAI].[CFDI_UUID_VENTA]
            ), CobranzaRelevante AS
            (
                -- Desde este punto solo se trabaja con facturas del reporte.
                SELECT C.Factura, C.Importe, C.Via_Pago,
                       C.Asignacion_ID, C.Nota_Credito
                FROM [T3].[CFDI_Cobranza] AS C
                INNER JOIN VentaClave AS V ON V.Nota_Venta = C.Factura
            ), DocumentoNecesario AS
            (
                /*
                    Lista minima de folios que pueden aportar metodo o UUID.
                    UNION elimina duplicados antes de consultar CFDI_Documentos.
                */
                SELECT V.Nota_Venta FROM VentaClave AS V
                UNION
                SELECT C.Asignacion_ID FROM CobranzaRelevante AS C
                WHERE C.Asignacion_ID IS NOT NULL
                UNION
                SELECT C.Nota_Credito FROM CobranzaRelevante AS C
                WHERE C.Nota_Credito IS NOT NULL
                UNION
                SELECT CONVERT(VARCHAR(30), AP.Agrupacion)
                FROM CobranzaRelevante AS C
                INNER JOIN [T3].[CFDI_Agrupacion_Pago] AS AP
                    ON AP.Asignacion_ID = C.Asignacion_ID
            ), Documento AS
            (
                SELECT
                    D.Nota_Venta,
                    MAX(CASE WHEN D.Folio_Fiscal IS NULL THEN 0 ELSE 1 END) AS Tiene_UUID,
                    MAX(D.Metodo_Pago) AS Metodo_Pago
                FROM [T3].[CFDI_Documentos] AS D
                INNER JOIN DocumentoNecesario AS N ON N.Nota_Venta = D.Nota_Venta
                GROUP BY D.Nota_Venta
            ), AgrupacionTimbrada AS
            (
                /*
                    Una asignacion puede apuntar a un CFDI agrupado. Se conserva
                    una sola bandera para no duplicar el importe de cobranza.
                */
                SELECT
                    AP.Asignacion_ID,
                    MAX(ISNULL(D.Tiene_UUID, 0)) AS Tiene_UUID
                FROM
                (
                    SELECT DISTINCT Asignacion_ID
                    FROM CobranzaRelevante
                    WHERE Asignacion_ID IS NOT NULL
                ) AS C
                INNER JOIN [T3].[CFDI_Agrupacion_Pago] AS AP
                    ON AP.Asignacion_ID = C.Asignacion_ID
                LEFT JOIN Documento AS D
                    ON D.Nota_Venta = CONVERT(VARCHAR(30), AP.Agrupacion)
                GROUP BY AP.Asignacion_ID
            ), CobranzaBase AS
            (
                SELECT
                    C.Factura,
                    ISNULL(C.Importe, 0) AS Importe,
                    CASE WHEN C.Via_Pago = '01' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Efectivo,
                    CASE WHEN C.Via_Pago IN ('02', '03') THEN ISNULL(C.Importe, 0) ELSE 0 END AS Agrupado,
                    CASE WHEN C.Via_Pago = 'CM' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Aplica_NC,
                    CASE WHEN C.Via_Pago = 'AI' THEN ISNULL(C.Importe, 0) ELSE 0 END AS Incobrable,
                    ISNULL(P.Tiene_UUID, 0)
                    + ISNULL(A.Tiene_UUID, 0)
                    + ISNULL(N.Tiene_UUID, 0) AS Timbrado
                FROM CobranzaRelevante AS C
                LEFT JOIN Documento AS P ON P.Nota_Venta = C.Asignacion_ID
                LEFT JOIN AgrupacionTimbrada AS A ON A.Asignacion_ID = C.Asignacion_ID
                LEFT JOIN Documento AS N ON N.Nota_Venta = C.Nota_Credito
            ), Cobranza AS
            (
                -- Una fila final por factura, lista para actualizar el reporte.
                SELECT
                    B.Factura,
                    SUM(B.Importe) AS Importe,
                    SUM(B.Efectivo) AS Efectivo,
                    SUM(B.Agrupado) AS Agrupado,
                    SUM(B.Aplica_NC) AS Aplica_NC,
                    SUM(B.Incobrable) AS Incobrable,
                    SUM(B.Efectivo * B.Timbrado) AS Efectivo_UUID,
                    SUM(B.Agrupado * B.Timbrado) AS Agrupado_UUID,
                    SUM(B.Aplica_NC * B.Timbrado) AS Aplica_NC_UUID,
                    SUM(B.Importe * B.Timbrado) AS Importe_UUID
                FROM CobranzaBase AS B
                GROUP BY B.Factura
            )
            UPDATE V
               SET Importe = C.Importe,
                   Efectivo = C.Efectivo,
                   Agrupado = C.Agrupado,
                   Aplica_NC = C.Aplica_NC,
                   Incobrable = C.Incobrable,
                   Efectivo_UUID = C.Efectivo_UUID,
                   Agrupado_UUID = C.Agrupado_UUID,
                   Aplica_NC_UUID = C.Aplica_NC_UUID,
                   Importe_UUID = C.Importe_UUID,
                   Metodo_Pago = D.Metodo_Pago
            FROM [EAI].[CFDI_UUID_VENTA] AS V
            INNER JOIN Cobranza AS C ON C.Factura = V.Nota_Venta
            LEFT JOIN Documento AS D ON D.Nota_Venta = V.Nota_Venta;

            /*
                Oracle incrementa este contador por cada venta recorrida, aunque
                no tenga cobranza. El MSSQL original contaba solo filas actualizadas.
            */
            SELECT @nProceso1 = COUNT(*)
            FROM [EAI].[CFDI_UUID_VENTA];
        END;

        -------------------------------------------------------------------
        -- 4. Cerrar auditoria
        -------------------------------------------------------------------
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
        /*
            @v_ID identifica la etapa que fallo. THROW vuelve a enviar el error
            para que SQL Agent marque la ejecucion como fallida.
        */
        SET @sErrorCode = 'ERR-' + CONVERT(VARCHAR(10), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(10), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction, Reference, Created, Message, Job_PID, Status,
            Queue_Name, Siebel_Error_Message, Source, Siebel_Error_Code,
            Retry_Count, [Sequence], Parent_Row_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error',
            'SF_CFDI_VENTA', @sMsg, 'T-SQL', @sErrorCode,
            NULL, NULL, NULL
        );

        PRINT '----------------------------------';
        PRINT '**** Error en SF_CFDI_VENTA_OPTIMIZADO *****';
        PRINT @sMsg;
        THROW;
    END CATCH;
END;
GO
