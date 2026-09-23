/*
    Procedure : EAI.SF_BITACORA_CFDI_VENTA_SF_OPTIMIZADO
    Objetivo  : Conciliar los importes recibidos desde Salesforce con
                EAI.CFDI_BITACORA y complementar informacion fiscal/SAP.

    Guia para desarrolladores JR:
    - @nEtapa se conserva por compatibilidad, pero Oracle y el MSSQL original
      no lo utilizan para omitir bloques.
    - @sPeriod representa un mes YYYYMM. Normalmente se deja vacio.
    - En los dias 1 y 2, si no se envia periodo, se procesa automaticamente el
      mes correspondiente a tres dias antes para resolver el cambio de mes.
    - Vta usa importes positivos y Dev importes negativos.
    - Este archivo no reemplaza el procedure original ni modifica sus callers.

    Alias frecuentes:
    - SF   = movimiento proveniente de Salesforce.
    - Bita = fila de EAI.CFDI_BITACORA.
    - SAP  = documento contable de T3R_SALES_DOCS_OLD.
    - PG/FG = Preventa_General / Factura_General.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI_VENTA_SF_OPTIMIZADO]
    @nEtapa  INT = 0,
    @sPeriod VARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @sPeriodo        CHAR(6) = NULL,
        @sMsg            VARCHAR(500),
        @v_ID            VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode      VARCHAR(20),
        @dtInicio        DATETIME2(0),
        @dHoy            DATE = CONVERT(DATE, GETDATE()),
        @dVentana        DATE,
        @dDesdeSF        DATE,
        @dPeriodoInicio  DATE,
        @dPeriodoFin     DATE,
        @nPID            BIGINT,
        @nProceso        INT = 826,
        @nProceso1       INT = 0,
        @nProceso2       INT = 0,
        @nProceso3       INT = 0,
        @nProceso4       INT = 0;

    BEGIN TRY
        -------------------------------------------------------------------
        -- 1. Resolver ventana de fechas y periodo especial de cierre de mes
        -------------------------------------------------------------------
        /*
            FC__TIME_WINDOW contiene DD/MM/YYYY. Salesforce se consulta desde
            45 dias antes de esa fecha y nunca incluye el dia actual.
        */
        SELECT @dVentana = TRY_CONVERT(DATE, TW.Start_Date, 103)
        FROM [EAI].[FC__Time_Window] AS TW;

        IF @dVentana IS NULL
            THROW 54301, 'FC__TIME_WINDOW.Start_Date no contiene una fecha DD/MM/YYYY valida.', 1;

        SET @dDesdeSF = DATEADD(DAY, -45, @dVentana);

        IF LEN(ISNULL(@sPeriod, '')) < 4
        BEGIN
            -- El cierre automatico solo se activa durante los dias 1 y 2.
            IF DAY(@dHoy) IN (1, 2)
                SET @sPeriodo = CONVERT(CHAR(6), DATEADD(DAY, -3, @dHoy), 112);
        END
        ELSE
        BEGIN
            IF LEN(@sPeriod) <> 6
                THROW 54302, '@sPeriod debe contener un periodo valido con formato YYYYMM.', 1;

            SET @sPeriodo = @sPeriod;
        END;

        IF @sPeriodo IS NOT NULL
        BEGIN
            SET @dPeriodoInicio = TRY_CONVERT(DATE, @sPeriodo + '01', 112);

            IF @dPeriodoInicio IS NULL
                THROW 54302, '@sPeriod debe contener un periodo valido con formato YYYYMM.', 1;

            SET @dPeriodoFin = DATEADD(MONTH, 1, @dPeriodoInicio);
        END;

        -------------------------------------------------------------------
        -- 2. Abrir auditoria del componente 826
        -------------------------------------------------------------------
        SET @dtInicio = SYSDATETIME();
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, @dtInicio);

        -------------------------------------------------------------------
        -- 3. Materializar movimientos Salesforce del periodo
        -------------------------------------------------------------------
        SET @v_ID = 'ScrVentaSalesforce';

        /*
            La tabla temporal unifica tres fuentes:
            - Facturas_B: ventas.
            - SR_Invoice: devoluciones Salesforce.
            - Credit_Notes: notas DESC/CONECT.

            Las fechas de origen son texto. CROSS APPLY las convierte una sola
            vez por fila; el original repetia TRY_CONVERT en SELECT y WHERE.
        */
        CREATE TABLE #VentaSalesforce
        (
            SF_Factura        VARCHAR(30)    NULL,
            SF_Fecha_Factura  DATE           NULL,
            SF_Cliente_SAP    VARCHAR(20)    NULL,
            SF_Importe_TMD    NUMERIC(15, 2) NULL,
            SF_Tipo_Doc       VARCHAR(4)     NULL,
            Delivery_Status   VARCHAR(50)    NULL,
            Ctro              VARCHAR(4)     NULL,
            Nombre_Cliente    VARCHAR(100)   NULL
        );

        ;WITH MovCliente AS
        (
            /*
                Mov_Cliente deberia tener una fila vigente por cliente. MAX
                entrega un unico resultado y evita multiplicar movimientos SF
                si el catalogo contiene duplicados.
            */
            SELECT Cliente_SAP, MAX(Ctro) AS Ctro, MAX(Nombre) AS Nombre
            FROM [T3].[Mov_Cliente]
            GROUP BY Cliente_SAP
        ), Salesforce AS
        (
            SELECT
                I.Doc_Num AS Factura,
                F.Fecha AS Fecha_Factura,
                I.Cte_SAP AS Cliente_SAP,
                CONVERT(NUMERIC(15, 2), I.Ttl_Invc_Amt) AS Importe_TMD,
                CONVERT(VARCHAR(4), 'Vta') AS Tipo_Doc,
                I.Delivery_Status
            FROM [EAI_OWNER].[Facturas_B] AS I
            CROSS APPLY (VALUES (TRY_CONVERT(DATE, I.Invc_dt, 23))) AS F(Fecha)
            WHERE I.Invc_Status NOT IN ('Cancelled', 'Invalid')
              AND I.Invc_dt IS NOT NULL
              AND F.Fecha >= @dDesdeSF
              AND F.Fecha < @dHoy
              AND NOT EXISTS
              (
                  SELECT 1 FROM [EAI_OWNER].[Doctos_Cancelled] AS C
                  WHERE C.Referencia = I.Doc_Num
              )

            UNION ALL

            SELECT
                D.SR_Invoice_Key,
                F.Fecha,
                D.SAP_CustomerID,
                CONVERT(NUMERIC(15, 2), D.Total_Amount * -1),
                'Dev',
                ISNULL(D.Received_Status, 'Empty')
            FROM [EAI_OWNER].[SR_Invoice] AS D
            CROSS APPLY (VALUES (TRY_CONVERT(DATE, D.SRI_Date, 23))) AS F(Fecha)
            WHERE D.SRI_Date IS NOT NULL
              AND F.Fecha >= @dDesdeSF
              AND F.Fecha < @dHoy
              AND NOT EXISTS
              (
                  SELECT 1 FROM [EAI_OWNER].[Doctos_Cancelled] AS C
                  WHERE C.Referencia = D.SR_Invoice_Key
              )

            UNION ALL

            SELECT
                N.Reference_NO,
                F.Fecha,
                N.Cte_SAP,
                CONVERT(NUMERIC(15, 2), ISNULL(N.Amount, 0) * -1),
                'Dev',
                'CreditMemo'
            FROM [EAI_OWNER].[Credit_Notes] AS N
            CROSS APPLY (VALUES (TRY_CONVERT(DATE, N.Fecha, 23))) AS F(Fecha)
            WHERE (N.Reference_NO LIKE 'DESC%' OR N.Reference_NO LIKE 'CONECT%')
              AND F.Fecha >= @dDesdeSF
              AND F.Fecha < @dHoy
        )
        INSERT INTO #VentaSalesforce
        (
            SF_Factura, SF_Fecha_Factura, SF_Cliente_SAP,
            SF_Importe_TMD, SF_Tipo_Doc, Delivery_Status,
            Ctro, Nombre_Cliente
        )
        SELECT
            SF.Factura, SF.Fecha_Factura, SF.Cliente_SAP,
            SF.Importe_TMD, SF.Tipo_Doc, SF.Delivery_Status,
            MC.Ctro, MC.Nombre
        FROM Salesforce AS SF
        LEFT JOIN MovCliente AS MC ON MC.Cliente_SAP = SF.Cliente_SAP;

        -- El indice sirve tanto al UPDATE de existentes como al INSERT de faltantes.
        CREATE INDEX IX_VentaSalesforce_Factura
            ON #VentaSalesforce (SF_Factura)
            INCLUDE (SF_Importe_TMD, Delivery_Status);

        -------------------------------------------------------------------
        -- 4. Actualizar documentos existentes e insertar documentos nuevos
        -------------------------------------------------------------------
        /*
            Unsuccessful-X no actualiza SF_Amount, pero se cuenta para auditoria.
            Los demas estados representan un importe utilizable de Salesforce.
        */
        UPDATE B
           SET SF_Amount = SF.SF_Importe_TMD
        FROM [EAI].[CFDI_BITACORA] AS B
        INNER JOIN #VentaSalesforce AS SF ON SF.SF_Factura = B.Doc_Num
        WHERE ISNULL(SF.Delivery_Status, '') <> 'Unsuccessful-X';

        SET @nProceso1 = @@ROWCOUNT;

        SELECT @nProceso2 = COUNT(*)
        FROM #VentaSalesforce AS SF
        WHERE ISNULL(SF.Delivery_Status, '') = 'Unsuccessful-X'
          AND EXISTS
          (
              SELECT 1 FROM [EAI].[CFDI_BITACORA] AS B
              WHERE B.Doc_Num = SF.SF_Factura
          );

        /*
            Si Salesforce contiene una factura que aun no existe en la bitacora,
            se crea con la informacion minima. ROW_ID y Doc_Num usan el folio SF
            porque esta es la llave operativa heredada del proceso Oracle.
        */
        INSERT INTO [EAI].[CFDI_BITACORA]
        (
            Row_ID, Doc_Num, Nota_Venta_CFDI, Invc_Dt, Fecha_Trn,
            Ctro, Terr, Tipo_Vta, Docto_Ind, Fecha_Venta,
            Nombre_Cliente, Cliente_SAP, Clte_Factura_SAP, SF_Amount
        )
        SELECT
            SF.SF_Factura, SF.SF_Factura, SF.SF_Factura,
            SF.SF_Fecha_Factura, GETDATE(), SF.Ctro, '0000',
            SF.SF_Tipo_Doc, 1, SF.SF_Fecha_Factura, SF.Nombre_Cliente,
            SF.SF_Cliente_SAP, SF.SF_Cliente_SAP, SF.SF_Importe_TMD
        FROM #VentaSalesforce AS SF
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [EAI].[CFDI_BITACORA] AS B
            WHERE B.Doc_Num = SF.SF_Factura
        );

        SET @nProceso3 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 5. Complementar importe y numero de documento SAP
        -------------------------------------------------------------------
        SET @v_ID = 'ScrInfoSAP';

        UPDATE B
           SET SAP_Amount = (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0))
                            * CASE WHEN B.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END,
               Factura_SAP = SAP.Doc_Num_R3
        FROM [EAI].[CFDI_BITACORA] AS B
        INNER JOIN [EAI].[T3R_Sales_Docs_Old] AS SAP
            ON SAP.Doc_Num_ref2 = B.Doc_Num
        WHERE B.Row_ID IS NOT NULL
          AND SAP.Doc_Status = 'C';

        SET @nProceso4 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 6. Workaround de notas de credito DESC/CONECT
        -------------------------------------------------------------------
        SET @v_ID = 'ScrCreditMemoDelete';

        /*
            Una nota con 35 dias o mas respecto a la preventa se elimina. La
            comparacion directa de fechas reemplaza DATEDIFF y evita calcularlo
            fila por fila.
        */
        DELETE B
        FROM [EAI].[CFDI_BITACORA] AS B
        INNER JOIN [T3].[Preventa_General] AS PG ON PG.Factura = B.Doc_Num
        WHERE (B.Doc_Num LIKE 'DESC%' OR B.Doc_Num LIKE 'CONECT%')
          AND B.Invc_dt >= DATEADD(DAY, 35, PG.Fecha_Factura);

        -- Para notas recientes, SAP se considera la fuente oficial cuando SF
        -- trae un importe distinto y diferente de cero.
        UPDATE B
           SET SF_Amount = ISNULL(B.SAP_Amount, 0)
        FROM [EAI].[CFDI_BITACORA] AS B
        WHERE (B.Doc_Num LIKE 'DESC%' OR B.Doc_Num LIKE 'CONECT%')
          AND ISNULL(B.SAP_Amount, 0) <> ISNULL(B.SF_Amount, 0)
          AND ISNULL(B.SF_Amount, 0) <> 0
          -- GETDATE conserva la hora; Oracle compara 45 dias exactos, no solo
          -- fechas de calendario.
          AND B.Invc_dt > DATEADD(DAY, -45, GETDATE());

        -------------------------------------------------------------------
        -- 7. Completar el resumen fiscal cuando aun no tiene folio
        -------------------------------------------------------------------
        SET @v_ID = 'Actualizar CFDI_Informe';

        UPDATE I
           SET Status = C.Status,
               Folio_Fiscal = C.Folio_Fiscal,
               Valor_Subt = C.Valor_Subt * I.Factor,
               Valor_IVA = C.Valor_IVA * I.Factor
        FROM [EAI].[CFDI_INFORME] AS I
        INNER JOIN [T3].[CFDI_Documentos] AS C
            ON C.Nota_Venta = I.Folio_Interno
        WHERE I.Folio_Fiscal IS NULL
          AND C.Folio_Fiscal IS NOT NULL;

        -------------------------------------------------------------------
        -- 8. Correcciones especiales al cambiar de mes
        -------------------------------------------------------------------
        IF @dPeriodoInicio IS NOT NULL
        BEGIN
            SET @v_ID = 'ScrWA_MesAnterior';

            /*
                Solo se revisan filas dentro del mes solicitado. Usar rangos
                evita CONVERT(CHAR(6), Invc_dt) y permite indices por fecha.
                FN_TOTAL_FACT reconstruye el importe faltante desde T3.
            */
            UPDATE B
               SET SF_Amount = [T3].[FN_TOTAL_FACT](B.Doc_Num)
                               * CASE WHEN B.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
            FROM [EAI].[CFDI_BITACORA] AS B
            WHERE ISNULL(B.SF_Amount, 0) = 0
              AND B.Invc_dt >= @dPeriodoInicio
              AND B.Invc_dt < @dPeriodoFin
              AND EXISTS
              (
                  SELECT 1 FROM [T3].[Factura_General] AS FG
                  WHERE FG.Factura = B.Doc_Num
              );

            UPDATE B
               SET SF_Amount = [T3].[FN_TOTAL_FACT](B.Doc_Num)
                               * CASE WHEN B.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
            FROM [EAI].[CFDI_BITACORA] AS B
            INNER JOIN [T3].[Preventa_General] AS PG ON PG.Factura = B.Doc_Num
            WHERE ISNULL(B.SF_Amount, 0) = 0
              AND B.Invc_dt >= @dPeriodoInicio
              AND B.Invc_dt < @dPeriodoFin
              AND PG.Fecha_Proc_BATMD < GETDATE()
              AND PG.Fecha_Cancelacion IS NULL;

            SET @v_ID = 'ScrWA_MesSiguiente';

            -- Corrige la fecha cuando T3 ubica la factura en otro mes.
            UPDATE B
               SET Invc_dt = FG.Fecha_Factura
            FROM [EAI].[CFDI_BITACORA] AS B
            INNER JOIN [T3].[Factura_General] AS FG ON FG.Factura = B.Doc_Num
            WHERE B.Invc_dt >= @dPeriodoInicio
              AND B.Invc_dt < @dPeriodoFin
              AND (FG.Fecha_Factura < @dPeriodoInicio OR FG.Fecha_Factura >= @dPeriodoFin);

            SET @v_ID = 'ScrWA_LOBInicioMes';

            /*
                Recupera preventas canceladas C005/C006 que aun no aparecen en
                la bitacora. El importe se toma de SAP y respeta el signo.
            */
            INSERT INTO [EAI].[CFDI_BITACORA]
            (
                Row_ID, Doc_Num, Nota_Venta_CFDI, Invc_Dt, Fecha_Trn,
                Factura_SAP, Ctro, Terr, Tipo_Vta, Docto_Ind, Fecha_Venta,
                Nombre_Cliente, Cliente_SAP, Clte_Factura_SAP,
                SF_Amount, SAP_Amount
            )
            SELECT
                PG.Factura, PG.Factura, PG.Factura, PG.Fecha_Factura,
                PG.Fecha_Trn, PG.Entrega, PG.Ctro, '0000',
                CASE WHEN PG.Clase_Factura = 'C005' THEN 'Vta' ELSE 'Dev' END,
                1, PG.Fecha_Factura, MC.Nombre, PG.Cliente_SAP, PG.Cliente_SAP,
                A.Importe * S.Factor, A.Importe * S.Factor
            FROM [T3].[Preventa_General] AS PG
            INNER JOIN [T3].[Mov_Cliente] AS MC ON MC.Cliente_SAP = PG.Cliente_SAP
            LEFT JOIN [EAI].[T3R_Sales_Docs_Old] AS SAP ON SAP.Doc_Num_R3 = PG.Entrega
            CROSS APPLY
            (
                VALUES (ISNULL(SAP.Doc_NetAmt, 0) + ISNULL(SAP.Doc_TaxAmt, 0))
            ) AS A(Importe)
            CROSS APPLY
            (
                VALUES (CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END)
            ) AS S(Factor)
            WHERE PG.Clase_Factura IN ('C005', 'C006')
              AND PG.Fecha_Cancelacion IS NOT NULL
              AND PG.Fecha_Proc_BATMD < GETDATE()
              AND PG.Fecha_Factura >= @dVentana
              AND NOT EXISTS
              (
                  SELECT 1 FROM [EAI].[CFDI_BITACORA] AS B
                  WHERE B.Doc_Num = PG.Factura
              );

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- 9. Limpieza y cierre de auditoria
        -------------------------------------------------------------------
        -- CHP identifica cheques devueltos; no forman parte de venta Salesforce.
        DELETE FROM [EAI].[CFDI_BITACORA]
        WHERE Doc_Num LIKE 'CHP%';

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
            @v_ID indica el bloque que fallo. El error se registra y THROW lo
            devuelve a SQL Agent o al caller para que la ejecucion no parezca
            exitosa cuando quedo incompleta.
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
            'SF_BITACORA_CFDI_VENTA_SF', @sMsg, 'T-SQL', @sErrorCode,
            NULL, NULL, NULL
        );

        PRINT '---------------------------------------------';
        PRINT '**** Error en SF_BITACORA_CFDI_VENTA_SF_OPTIMIZADO *****';
        PRINT @sMsg;
        THROW;
    END CATCH;
END;
GO
