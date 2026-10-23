USE [T3QA]
GO
/****** Object:  StoredProcedure [EAI].[SF_CFDI_OPEN_ITEMS]    Script Date: 10/8/2026 2:54:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [EAI].[SF_CFDI_OPEN_ITEMS]
    @nEtapa INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        -- Mensaje y nombre de la etapa usados si el proceso falla.
        @sMsg       VARCHAR(500),
        @v_ID       VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode VARCHAR(20),

        -- Datos de auditoria de esta ejecucion.
        @dtInicio   DATETIME2(0),
        @nPID       BIGINT,
        @nProceso   INT = 923,

        -- Contadores que se guardan al final en RF_PROCESOS_LOG.
        @nProceso1  INT = 0,
        @nProceso2  INT = 0,
        @nProceso3  INT = 0,
        @nProceso4  INT = 0;

    BEGIN TRY
        -- Cada ejecucion recibe un PID distinto para relacionar inicio, fin y
        -- cualquier mensaje de error producido por el job.
        SET @dtInicio = SYSDATETIME();
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        -- Log_Start registra el comienzo del componente funcional 923.
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        INSERT INTO [T3].[RF_PROCESOS_LOG]
        (
            PID, Proceso, Fecha_Proc_BATMD, Inicio
        )
        VALUES
        (
            @nPID, @nProceso, NULL, @dtInicio
        );

        -------------------------------------------------------------------
        -- Etapa 0: cartera SAP vigente
        -------------------------------------------------------------------
        SET @v_ID = 'CFDI_OPEN_ITEMS';

        IF ISNULL(@nEtapa, 0) <= 0
        BEGIN
            -- Esta etapa reconstruye la fotografia completa. DELETE se conserva
            -- porque TRUNCATE puede requerir permisos adicionales o fallar si
            -- existen llaves foraneas relacionadas.
            DELETE FROM [EAI].[CFDI_OPEN_ITEMS];


            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
            (
                Nota_Venta, Cliente_SAP, Fecha_Venta, Tipo_Docto,
                Saldo_SAP, Last_Updated
            )
            SELECT
                D.Nota_Venta,
                D.Cliente_SAP,
                -- Fecha_Doc llega como texto YYYYMMDD.
                -- REVISION ORACLE: TO_DATE falla ante fecha invalida; este
                -- TRY_CONVERT produce NULL y permite continuar. Diferencia pendiente.
                TRY_CONVERT(DATE, D.Fecha_Doc, 112),
                -- Primero manda la clase fiscal. Si no se conoce, el signo del
                -- saldo define si se trata de venta o devolucion.
                CASE
                    WHEN D.Tipo_Docto IN ('C003', 'C005') THEN 'Vta'
                    WHEN D.Tipo_Docto IN ('C004', 'C006', 'C019', 'C025') THEN 'Dev'
                    WHEN D.Saldo_SAP = ABS(D.Saldo_SAP) THEN 'Vta'
                    ELSE 'Dev'
                END,
                CASE
                    WHEN D.Tipo_Docto IN ('C003', 'C005') THEN D.Saldo_SAP
                    ELSE ABS(D.Saldo_SAP)
                END,
                GETDATE()
            FROM
            (
                SELECT
                    SAP.Referencia AS Nota_Venta,
                    ISNULL(RF.Tipo_Docto, 'NULL') AS Tipo_Docto,
                    MAX(SAP.Cliente) AS Cliente_SAP,
                    MIN(SAP.Fecha_Doc) AS Fecha_Doc,
                    SUM(ISNULL(SAP.Monto, 0)) AS Saldo_SAP
                FROM
                (
                    -- Refoleo traduce el numero SAP al numero utilizado en T3.
                    -- Si no existe traduccion se conserva la referencia SAP.
                    SELECT
                        S.Cliente,
                        ISNULL(R.Docto_T3MX, S.Referencia) AS Referencia,
                        S.Fecha_Doc,
                        S.Monto
                    FROM [EAI].[T3R_Cartera_SAP_OLD] AS S
                    LEFT JOIN
                    (
                        SELECT Docto_SAP, Docto_T3MX
                        FROM [T3].[CFDI_Refoleo]
                        WHERE Tipo_Registro = 'DOI'
                    ) AS R
                        ON R.Docto_SAP = S.Referencia
                ) AS SAP
                LEFT JOIN [T3].[Registro_Fiscal] AS RF
                    ON RF.Factura = SAP.Referencia
                -- Exclusion de documentos de otro flujo.
                -- REVISION ORACLE: el original usa NOT IN. Con Factura NULL en
                -- Otros_General, NOT IN y NOT EXISTS no son equivalentes;
                -- tampoco siempre lo son para una referencia SAP NULL.
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM [T3].[Otros_General] AS OG
                    WHERE OG.Factura = SAP.Referencia
                )
                GROUP BY SAP.Referencia, ISNULL(RF.Tipo_Docto, 'NULL')
            ) AS D;

            SET @nProceso1 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 10: documentos historicos aun pendientes
        -------------------------------------------------------------------
        SET @v_ID = 'Historico';

        IF ISNULL(@nEtapa, 0) <= 10
        BEGIN
            /*
                HistoricItem normaliza dos fuentes con columnas equivalentes:
                - Factura_General / Factura_Detalle.
                - Preventa_General / Preventa_Detalle.

                UNION ALL conserva todos los renglones de detalle; la siguiente
                CTE los suma por documento.
            */
            ;WITH HistoricItem AS
            (
                SELECT
                    FG.Ctro,
                    FG.Fecha_Factura AS Fecha_Venta,
                    FG.Tipo_Docto AS Clase_Factura,
                    FG.Factura AS Nota_Venta,
                    FG.Cliente_SAP,
                    C.RFC,
                    ISNULL(FD.Valor_Subt, 0)
                  + ISNULL(FD.Valor_IVA, 0)
                  + ISNULL(FD.Credito_Subt, 0)
                  + ISNULL(FD.Credito_IVA, 0)
                  + ISNULL(FD.Envio_Subt, 0)
                  + ISNULL(FD.Envio_IVA, 0) AS Importe_Item
                -- SELECT COUNT(*)
                -- Conteo de universo de datos
                -- 54,995,831 (20230101)
                -- 36,274,833 (20240101)
                -- 19,344,229 (20250101)
                --  5,484,630 (20260101)
                FROM [T3].[Factura_General] AS FG
                INNER JOIN [T3].[Factura_Detalle] AS FD
                    ON FD.Factura = FG.Factura
                INNER JOIN [T3].[Cliente] AS C
                    ON C.Cliente_SAP = FG.Cliente_SAP
                   AND FG.Fecha_Factura BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
                WHERE FG.Fecha_Factura >= CONVERT(DATE, '20260101', 112)
                  AND FG.Tipo_Docto IN ('C003', 'C004')

                UNION ALL

                SELECT
                    PG.Ctro,
                    PG.Fecha_Factura,
                    PG.Clase_Factura,
                    PG.Factura,
                    PG.Cliente_SAP,
                    C.RFC,
                    ISNULL(PD.Valor_Subt, 0)
                  + ISNULL(PD.Valor_IVA, 0)
                  + ISNULL(PD.Credito_Subt, 0)
                  + ISNULL(PD.Credito_IVA, 0)
                  + ISNULL(PD.Envio_Subt, 0)
                  + ISNULL(PD.Envio_IVA, 0)
                -- select count(*)
                -- 5,008,634
                FROM [T3].[Preventa_General] AS PG
                INNER JOIN [T3].[Preventa_Detalle] AS PD
                    ON PD.Factura = PG.Factura
                INNER JOIN [T3].[Cliente] AS C
                    ON C.Cliente_SAP = PG.Cliente_SAP
                   AND PG.Fecha_Factura BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
                WHERE PG.Fecha_Factura >= CONVERT(DATE, '20260101', 112)
                  AND PG.Clase_Factura IN ('C005', 'C006', 'C019', 'C025')
                  AND PG.Fecha_Proc_BATMD IS NOT NULL
                  AND PG.Fecha_Cancelacion IS NULL
            ), Historic AS
            (
                -- Una fila por documento, cliente, fecha y clase fiscal.
                SELECT
                    Ctro, Fecha_Venta, Clase_Factura, Nota_Venta,
                    Cliente_SAP, RFC, SUM(Importe_Item) AS Importe_Venta
                FROM HistoricItem
                GROUP BY
                    Ctro, Fecha_Venta, Clase_Factura, Nota_Venta,
                    Cliente_SAP, RFC
            )
            INSERT INTO [EAI].[CFDI_OPEN_ITEMS]
            (
                Ctro, Nota_Venta, Cliente_SAP, Clte_Factura_SAP,
                Fecha_Venta, Tipo_Docto, Importe_Vta, Last_Updated
            )
            SELECT
                H.Ctro,
                H.Nota_Venta,
                H.Cliente_SAP,
                H.Cliente_SAP,
                H.Fecha_Venta,
                CASE WHEN H.Clase_Factura IN ('C003', 'C005') THEN 'Vta' ELSE 'Dev' END,
                H.Importe_Venta,
                GETDATE()
            FROM Historic AS H
            -- Regla ACTUAL: insertar solo si el folio no existe.
            -- REVISION ORACLE: se evalua DOI.Last_Updated IS NULL de un LEFT
            -- JOIN. Una fila existente sin marca de tiempo SI permite insertar
            -- en Oracle; ademas varias coincidencias pueden multiplicar entradas.
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
                WHERE OI.Nota_Venta = H.Nota_Venta
            )
              AND ABS
              (
                  ISNULL(H.Importe_Venta, 0)
                - ISNULL
                  (
                      -- Las funciones calculan lo ya cobrado. Se usa una
                      -- funcion distinta para ventas y devoluciones.
                      CASE WHEN H.Clase_Factura IN ('C003', 'C005')
                           THEN [T3].[FN_Cobza_Pay](H.Nota_Venta)
                           ELSE [T3].[FN_COBZA_CM_UUID](H.Nota_Venta)
                      END,
                      0
                  )
              -- Diferencias de cinco centavos o menos se consideran saldadas.
              ) > 0.05;

            SET @nProceso4 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 20: cobranza aplicada a ventas
        -------------------------------------------------------------------
        SET @v_ID = 'ScrVenta';

        IF ISNULL(@nEtapa, 0) <= 20
        BEGIN
            /*
                OpenSale reduce la consulta a las ventas que realmente estan
                abiertas. DISTINCT evita multiplicar cobranza si por una
                anomalia existen dos filas con la misma Nota_Venta.
            */
            ;WITH OpenSale AS
            (
                SELECT DISTINCT Nota_Venta
                FROM [EAI].[CFDI_OPEN_ITEMS]
                WHERE Tipo_Docto = 'Vta'
            ), CollectionItem AS
            (
                -- Clasifica cada aplicacion y determina cuantos documentos
                -- fiscales relacionados cuentan con UUID.
                SELECT
                    C.Factura,
                    -- REVISION ORACLE: ScrCobza usa Importe sin NVL; convertirlo
                    -- a cero modifica SUM cuando los importes aplicables son NULL.
                    ISNULL(C.Importe, 0) AS Importe,
                    C.Via_Pago,
                    -- Timbrado NO es booleano: puede valer de 0 a 3. Se suman
                    -- indicadores, sin DISTINCT ni limite de 1, como Oracle.
                    -- Pago individual,
                    -- agrupacion y nota de credito pueden tener CFDI propio.
                    CASE WHEN P.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                  + CASE WHEN AD.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                  + CASE WHEN N.Folio_Fiscal IS NULL THEN 0 ELSE 1 END AS Timbrado
                FROM [T3].[CFDI_Cobranza] AS C
                INNER JOIN OpenSale AS O
                    ON O.Nota_Venta = C.Factura
                LEFT JOIN [T3].[CFDI_Documentos] AS P
                    ON P.Nota_Venta = C.Asignacion_ID
                LEFT JOIN
                (
                    SELECT AP.Agrupacion, AP.Asignacion_Id
                    FROM [T3].[CFDI_Agrupacion_Pago] AS AP
                    INNER JOIN [T3].[CFDI_Agrupacion_Ctrl] AS AC
                        ON AC.Agrupacion = AP.Agrupacion
                    WHERE ISNULL(AC.Importe, 0) <> 0
                ) AS AG
                    ON AG.Asignacion_Id = C.Asignacion_ID
                LEFT JOIN [T3].[CFDI_Documentos] AS AD
                    ON AD.Nota_Venta = CONVERT(VARCHAR(30), AG.Agrupacion)
                LEFT JOIN [T3].[CFDI_Documentos] AS N
                    ON N.Nota_Venta = C.Nota_Credito
            ), Collection AS
            (
                /*
                    Codigos de Via_Pago:
                    01    = efectivo.
                    02/03 = pago agrupado.
                    CM    = aplicacion de nota de credito.
                    AI    = importe incobrable.

                    Los campos *_UUID multiplican el importe por Timbrado.
                    Si los tres documentos tienen UUID, un importe 10 aporta 30.
                    JOIN con varios CFDI/agrupaciones tambien multiplica filas;
                    no convertirlo a EXISTS sin acordar un cambio de negocio.
                */
                SELECT
                    Factura,
                    SUM(Importe) AS Importe,
                    SUM(CASE WHEN Via_Pago = '01' THEN Importe ELSE 0 END) AS Efectivo,
                    SUM(CASE WHEN Via_Pago IN ('02', '03') THEN Importe ELSE 0 END) AS Agrupado,
                    SUM(CASE WHEN Via_Pago = 'CM' THEN Importe ELSE 0 END) AS Aplica_NC,
                    SUM(CASE WHEN Via_Pago = 'AI' THEN Importe ELSE 0 END) AS Incobrable,
                    SUM(CASE WHEN Via_Pago = '01' THEN Importe ELSE 0 END * Timbrado) AS Efectivo_UUID,
                    SUM(CASE WHEN Via_Pago IN ('02', '03') THEN Importe ELSE 0 END * Timbrado) AS Agrupado_UUID,
                    SUM(CASE WHEN Via_Pago = 'CM' THEN Importe ELSE 0 END * Timbrado) AS Aplica_NC_UUID,
                    SUM(Importe * Timbrado) AS Importe_UUID
                FROM CollectionItem
                GROUP BY Factura
            )
            -- REVISION ORACLE etapa 20: el cursor elige ventas, pero su UPDATE
            -- filtra solo Nota_Venta y puede afectar otras filas del mismo folio.
            -- Aqui tambien se filtra Tipo_Docto. Metodo_Pago no tiene una
            -- eleccion unica garantizada si existen varios CFDI diferentes.
            UPDATE OI
               SET OI.Importe = C.Importe,
                   OI.Efectivo = C.Efectivo,
                   OI.Agrupado = C.Agrupado,
                   OI.Aplica_NC = C.Aplica_NC,
                   OI.Efectivo_UUID = C.Efectivo_UUID,
                   OI.Agrupado_UUID = C.Agrupado_UUID,
                   OI.Aplica_NC_UUID = C.Aplica_NC_UUID,
                   OI.Importe_UUID = C.Importe_UUID,
                   OI.Incobrable = C.Incobrable,
                   OI.Metodo_Pago = CFD.Metodo_Pago,
                   OI.Tipo_Docto = 'Vta',
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN Collection AS C
                ON C.Factura = OI.Nota_Venta
            LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                ON CFD.Nota_Venta = OI.Nota_Venta
            WHERE OI.Tipo_Docto = 'Vta';

            -- Guardar inmediatamente el numero actualizado por MSSQL.
            -- REVISION ORACLE: P2 cuenta filas del cursor (incluye ventas sin
            -- cobranza y coincidencias CFDI), no filas actualizadas. No es equivalente.
            SET @nProceso2 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 30: aplicaciones de notas de credito
        -------------------------------------------------------------------
        SET @v_ID = 'ScrDevolucion';

        IF ISNULL(@nEtapa, 0) <= 30
        BEGIN
            -- OpenCredit filtra notas/devoluciones abiertas.
            -- REVISION ORACLE: ScrCreditMemo es agregado SIN GROUP BY; aun sin
            -- cobranza devuelve SUM/MAX=NULL. El INNER JOIN actual omite esas
            -- notas y puede dejar aplicaciones anteriores. No confundir con
            -- ScrCobza de ventas, que SI agrupa y no devuelve fila sin cobranza.
            ;WITH OpenCredit AS
            (
                SELECT DISTINCT Nota_Venta
                FROM [EAI].[CFDI_OPEN_ITEMS]
                WHERE Tipo_Docto = 'Dev'
            ), CreditMemo AS
            (
                -- CM suma aplicaciones normales; AI suma importes incobrables.
                -- La fecha mas reciente representa la ultima aplicacion.
                SELECT
                    C.Nota_Credito,
                    SUM(ISNULL(C.Importe, 0) * CASE WHEN C.Via_Pago = 'CM' THEN 1 ELSE 0 END) AS Importe_Aplicado,
                    SUM(ISNULL(C.Importe, 0) * CASE WHEN C.Via_Pago = 'AI' THEN 1 ELSE 0 END) AS Incobrable,
                    MAX(C.Fecha_Asignacion) AS Fecha_Asignacion
                FROM [T3].[CFDI_Cobranza] AS C
                INNER JOIN OpenCredit AS O
                    ON O.Nota_Venta = C.Nota_Credito
                GROUP BY C.Nota_Credito
            )
            UPDATE OI
               SET OI.Importe_NC = C.Importe_Aplicado,
                   OI.Incobrable = C.Incobrable,
                   OI.Fecha_Aplicacion = C.Fecha_Asignacion,
                   OI.Tipo_Docto = 'Dev',
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN CreditMemo AS C
                ON C.Nota_Credito = OI.Nota_Venta
            WHERE OI.Tipo_Docto = 'Dev';

            SET @nProceso2 = @nProceso2 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 60: importe fiscal y notas de debito
        -------------------------------------------------------------------
        SET @v_ID = 'ImporteVenta';

        IF ISNULL(@nEtapa, 0) <= 60
        BEGIN
            /*
                Primero se calcula el importe desde Registro_Fiscal. Solo se
                consultan facturas presentes en CFDI_OPEN_ITEMS para no agregar
                todo el historico fiscal de T3.
            */
            ;WITH OpenDocument AS
            (
                -- REVISION ORACLE: ScrImporteVenta une todas las filas OI al
                -- detalle fiscal. DISTINCT elimina ese multiplicador; con dos
                -- filas OI del mismo folio este importe difiere del original.
                SELECT DISTINCT Nota_Venta
                FROM [EAI].[CFDI_OPEN_ITEMS]
            ), FiscalAmount AS
            (
                SELECT
                    RF.Factura,
                    RF.Ctro,
                    MC.RFC,
                    SUM
                    (
                        ISNULL(RFD.Valor_Subt, 0)
                      + ISNULL(RFD.Valor_IVA, 0)
                      + ISNULL(RFD.Envio_Subt, 0)
                      + ISNULL(RFD.Envio_IVA, 0)
                      + ISNULL(RFD.Credito_Subt, 0)
                      + ISNULL(RFD.Credito_IVA, 0)
                    ) AS Importe_Vta
                FROM OpenDocument AS O
                INNER JOIN [T3].[Registro_Fiscal] AS RF
                    ON RF.Factura = O.Nota_Venta
                INNER JOIN [T3].[Registro_Fiscal_Detalle] AS RFD
                    ON RFD.Factura = RF.Factura
                LEFT JOIN [T3].[Mov_Cliente] AS MC
                    ON MC.Cliente_SAP = RF.Cliente_SAP
                GROUP BY RF.Factura, RF.Ctro, MC.RFC
            )
            UPDATE OI
               SET OI.Ctro = F.Ctro,
                   OI.RFC = F.RFC,
                   OI.Importe_Vta = F.Importe_Vta,
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN FiscalAmount AS F
                ON F.Factura = OI.Nota_Venta;

            SET @nProceso3 = @@ROWCOUNT;

            /*
                Una nota de debito puede no existir en Registro_Fiscal o puede
                requerir el importe de DEBIT_NOTE_IFC. Esta segunda actualizacion
                se ejecuta despues y, por lo tanto, tiene precedencia.

                REVISION ORACLE: el cursor cuenta cada coincidencia OI/DN/MC;
                @@ROWCOUNT cuenta destinos. Si hay distintas coincidencias para
                un folio, Oracle sobrescribe sin ORDER BY y UPDATE FROM escoge
                una fuente no garantizada: falta una regla unica para esos datos.
            */
            UPDATE OI
               SET OI.Ctro = MC.Ctro,
                   OI.RFC = MC.RFC,
                   OI.Importe_Vta = DN.Total_Amt,
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN [T3].[DEBIT_NOTE_IFC] AS DN
                ON DN.Debit_Note = OI.Nota_Venta
            INNER JOIN [T3].[Mov_Cliente] AS MC
                ON MC.Cliente_SAP = DN.Cust_to_SAP;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 70: relacion entre documento operativo y CFDI
        -------------------------------------------------------------------
        SET @v_ID = 'Fiscal';

        IF ISNULL(@nEtapa, 0) <= 70
        BEGIN
            -- Historia_Docto_PAC traduce la nota operativa al numero realmente
            -- enviado al PAC. El LEFT JOIN conserva la nota aunque el CFDI aun
            -- no haya sido timbrado.
            -- REVISION ORACLE: varias relaciones HDP/CFD generan varias vueltas
            -- de cursor y P3; UPDATE FROM no garantiza escoger la misma fila.
            UPDATE OI
               SET OI.Nota_Venta_CFDI = H.Nota_Venta_CFDI,
                   OI.Folio_Fiscal = CFD.Folio_Fiscal,
                   OI.Metodo_Pago = CFD.Metodo_Pago,
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN [T3].[CFDI_Historia_Docto_PAC] AS H
                ON H.Nota_Venta = OI.Nota_Venta
            LEFT JOIN [T3].[CFDI_Documentos] AS CFD
                ON CFD.Nota_Venta = H.Nota_Venta_CFDI;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 80: importe de notas de credito con UUID
        -------------------------------------------------------------------
        SET @v_ID = 'ScrUUID_Creditos';

        IF ISNULL(@nEtapa, 0) <= 80
        BEGIN
            /*
                Cuando HAY fila CFD coincidente, Importe_NC_UUID es el importe
                aplicado si tiene Folio_Fiscal; si su UUID es NULL, es cero.
                Sin fila CFD, el INNER JOIN deja el valor previo sin cambios.
                ISNULL permite usar el numero original si no hubo traduccion PAC.
                REVISION ORACLE: selecciona Dev pero actualiza todas las filas
                del folio; aqui solo Dev. UUID vacio en MSSQL no es NULL como
                en Oracle; varios CFDI tambien dejan ambiguo el valor final.
            */
            UPDATE OI
               SET OI.Importe_NC_UUID =
                       CASE WHEN CFD.Folio_Fiscal IS NULL THEN 0 ELSE 1 END
                       * ISNULL(OI.Importe_NC, 0),
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            LEFT JOIN [T3].[CFDI_Historia_Docto_PAC] AS H
                ON H.Nota_Venta = OI.Nota_Venta
            INNER JOIN [T3].[CFDI_Documentos] AS CFD
                ON CFD.Nota_Venta = ISNULL(H.Nota_Venta_CFDI, OI.Nota_Venta)
            WHERE OI.Tipo_Docto = 'Dev';

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 90: cliente facturado distinto del cliente operativo
        -------------------------------------------------------------------
        SET @v_ID = 'ScrClte_Factura_SAP';

        IF ISNULL(@nEtapa, 0) <= 90
        BEGIN
            /*
                Algunas ventas se registran para un cliente operativo, pero se
                facturan a otro cliente SAP. Las dos fuentes se normalizan en
                BilledCustomer y despues se actualiza la tabla de trabajo.
                REVISION ORACLE: UNION ALL produce todas las coincidencias y
                el cursor actualiza por ROWID. Si hay varios clientes candidatos,
                no existe ORDER BY que defina cual gana. No asumir que UNION ALL
                o el UPDATE garantizan prioridad entre factura y preventa.
            */
            ;WITH BilledCustomer AS
            (
                SELECT PG.Factura, PG.Clte_Factura_SAP
                FROM [T3].[Preventa_General] AS PG
                WHERE PG.Clte_Factura_SAP IS NOT NULL
                  AND PG.Cliente_SAP <> PG.Clte_Factura_SAP

                UNION ALL

                SELECT FG.Factura, FG.Clte_Factura_SAP
                FROM [T3].[Factura_General] AS FG
                WHERE FG.Clte_Factura_SAP IS NOT NULL
                  AND FG.Cliente_SAP <> FG.Clte_Factura_SAP
            )
            UPDATE OI
               SET OI.Clte_Factura_SAP = B.Clte_Factura_SAP,
                   OI.Last_Updated = GETDATE()
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN BilledCustomer AS B
                ON B.Factura = OI.Nota_Venta;

            SET @nProceso3 = @nProceso3 + @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Final: completar cliente, ajuste fiscal y referencias SAP
        -------------------------------------------------------------------
        SET @v_ID = 'Final';

        -- Se ejecuta cuando RFC falta (aunque Ctro ya tenga valor).
        -- REVISION ORACLE: MAX(RFC)/MAX(Ctro) se calculan por Cliente_SAP de CADA
        -- fila, y ambos pueden quedar NULL sin cliente. Aqui se agrupa por
        -- Nota_Venta y se usa INNER JOIN: puede mezclar clientes del mismo folio
        -- o conservar un centro antiguo cuando no existe Mov_Cliente.
        ;WITH MissingCustomer AS
        (
            SELECT
                OI.Nota_Venta,
                MAX(MC.RFC) AS RFC,
                MAX(MC.Ctro) AS Ctro
            FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
            INNER JOIN [T3].[Mov_Cliente] AS MC
                ON MC.Cliente_SAP = OI.Cliente_SAP
            WHERE OI.RFC IS NULL
            GROUP BY OI.Nota_Venta
        )
        /*
            El ajuste de IVA se suma unicamente a devoluciones. La funcion se
            conserva porque NDC_ISSUE_IVA puede contener duplicados y cambiarla
            por una consulta directa podria seleccionar otra diferencia.
        */
        UPDATE OI
           SET OI.RFC = C.RFC,
               OI.Ctro = C.Ctro
        FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
        INNER JOIN MissingCustomer AS C
            ON C.Nota_Venta = OI.Nota_Venta
        WHERE OI.RFC IS NULL;

        -- Ajuste de IVA en devoluciones. NO es idempotente: repetir Final puede
        -- volver a sumar el ajuste al importe existente.
        -- REVISION ORACLE: Importe_Vta + funcion conserva NULL si un operando
        -- es NULL. Estos ISNULL introducen ceros que no aparecen en Oracle.
        UPDATE OI
           SET OI.Importe_Vta = ISNULL(OI.Importe_Vta, 0)
                             + ISNULL([EAI_OWNER].[FN_GET_TAX_ISSUE](OI.Nota_Venta), 0)
        FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
        WHERE OI.Tipo_Docto = 'Dev';

        -- REVISION ORACLE referencias SAP: subconsulta escalar por fila. Sin RF
        -- pone PedidoSAP/FacturaSAP en NULL; con varias RF lanza error.
        -- El INNER JOIN actual conserva datos antiguos sin RF y puede escoger
        -- una coincidencia arbitraria con duplicados.
        UPDATE OI
           SET OI.PedidoSAP = RF.Pedido,
               OI.FacturaSAP = RF.Entrega
        FROM [EAI].[CFDI_OPEN_ITEMS] AS OI
        INNER JOIN [T3].[Registro_Fiscal] AS RF
            ON RF.Factura = OI.Nota_Venta;

        -- Status=1 informa a los procesos dependientes que el componente 923
        -- termino correctamente.
        UPDATE [EAI_OWNER].[MX_COMPONENTS]
           SET Status = 1
         WHERE Component = @nProceso;

        -- Cierra la misma fila de auditoria creada al inicio y guarda cuantos
        -- registros proceso cada grupo de etapas.
        UPDATE [T3].[RF_PROCESOS_LOG]
           SET Fin = GETDATE(),
               Proceso_1 = @nProceso1,
               Proceso_2 = @nProceso2,
               Proceso_3 = @nProceso3,
               Proceso_4 = @nProceso4
         WHERE PID = @nPID;
    END TRY
    BEGIN CATCH
        -- ERROR_NUMBER/ERROR_MESSAGE corresponden siempre a la excepcion que
        -- llevo el flujo a este bloque.
        SET @sErrorCode = CONCAT('ERR-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(ERROR_NUMBER(), '-', ERROR_MESSAGE()), 250);

        -- @v_ID contiene la ultima seccion visitada (se asigna incluso cuando
        -- @nEtapa omite el bloque). En una transaccion externa condenada este
        -- INSERT puede fallar y ocultar el error original: limitacion pendiente.
        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            DIRECTION, REFERENCE, CREATED, MESSAGE, JOB_PID, STATUS,
            QUEUE_NAME, SIEBEL_ERROR_MESSAGE, SOURCE, SIEBEL_ERROR_CODE,
            RETRY_COUNT, [SEQUENCE], PARENT_ROW_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error',
            'SF_CFDI_OPEN_ITEMS', @sMsg, 'T-SQL', @sErrorCode,
            NULL, NULL, NULL
        );

        PRINT '--------------------------------------';
        PRINT '**** Error en SF_CFDI_OPEN_ITEMS *****';
        PRINT @sMsg;

        /*
            THROW devuelve el error al SQL Agent. Esto permite que el job quede
            marcado como fallido y no reporte un falso exito. Se conserva el
            contrato del procedimiento MSSQL original.
        */
        THROW;
    END CATCH;
END;
