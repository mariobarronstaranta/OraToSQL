/*
    Procedure : EAI.SF_BITACORA_CFDI_RESUMEN
    Objetivo  : Reconstruir el resumen de CFDI que se guarda en
                EAI.CFDI_INFORME.

    Guia para desarrolladores :
    - Si inicio es NULL/vacio, se usa un mes antes de FC__TIME_WINDOW y hoy,
      ignorando fecha final, como Oracle. Se conserva fin de mes de ADD_MONTHS.
    - Si inicio se informa, ambas fechas deben usar YYYYMMDD.
    - La carga es completa: CFDI_INFORME se elimina y vuelve a construir.
    - Los movimientos C003 son ventas (+); las demas clases aplicables son
      devoluciones (-), salvo las excepciones indicadas en preventa.
    - Este archivo actualiza el nombre invocado por el job del resumen.

    Alias principales:
    - Info = fila del resumen EAI.CFDI_INFORME.
    - HDoc = relacion entre una venta y su CFDI individual o agrupado.
    - PAC  = datos fiscales y estado de timbrado.
    - RF/RFD = cabecera y detalle del registro fiscal.

    Campos importantes del resultado:
    - Monto_T3In = importe calculado con la informacion operativa de T3.
    - Valor_Subt / Valor_IVA / Valor = importes fiscales usados para conciliar.
    - Factor = 1 para venta y -1 para devolucion; se aplica a los importes.
    - Cigarrillos = unidades convertidas segun la presentacion del material.
    - Diferencia = ajuste menor usado para cuadrar centavos.
    - Origen = sistema considerado como fuente oficial del importe.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI_RESUMEN]
    @pFecha_Inicio VARCHAR(30) = NULL,
    @pFecha_Final  VARCHAR(30) = NULL
AS
BEGIN
    -- Evita mensajes repetidos de "N filas afectadas" enviados al job.
    SET NOCOUNT ON;

    -- Si posteriormente se envuelve el proceso en una transaccion, un error
    -- grave provocara su cancelacion automatica. Hoy las sentencias son autocommit.
    SET XACT_ABORT ON;

    /*
        Variables de auditoria:
        @v_ID identifica la seccion que fallo; @nPID identifica la ejecucion.
        @nProceso1..4 conservan los contadores esperados por RF_PROCESOS_LOG.
        Las variables @d... almacenan fechas ya convertidas y validadas.
    */
    DECLARE
        @v_ID           VARCHAR(50) = 'Inicio',
        @sErrorCode     VARCHAR(30),
        @sMsg           VARCHAR(300),
        @nPID           BIGINT,
        @nProceso       INT = 802,
        @nProceso1      INT = 0,
        @nProceso2      INT = 0,
        @nProceso3      INT = 0,
        @nProceso4      INT = 0,
        @nCount         INT = 0,
        @dFecha_Inicio  DATE,
        @dFecha_Final   DATE,
        @dVentana       DATE,
        @dtFechaLimite  DATETIME2(0);

    BEGIN TRY
        -------------------------------------------------------------------
        -- 1. Abrir las bitacoras tecnicas del proceso 802
        -------------------------------------------------------------------
        -- La secuencia garantiza un identificador distinto aun si hay dos
        -- ejecuciones simultaneas.
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        -- Log_Start informa al monitoreo general que inicio el componente 802.
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        -- Esta fila se completa al final con fecha de termino y contadores.
        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, GETDATE());

        -------------------------------------------------------------------
        -- 2. Convertir las fechas una sola vez
        -------------------------------------------------------------------
        /*
            El original convierte HDoc.Fecha_Factura a VARCHAR en cada fila.
            Aqui se convierten los parametros a DATE y se usa un intervalo
            [inicio, dia posterior al fin), que incluye todo el ultimo dia y
            permite aprovechar un indice por Fecha_Factura.
        */
        -- Estilo 103 interpreta el formato DD/MM/YYYY de la configuracion.
        SELECT @dVentana = TRY_CONVERT(DATE, TW.Start_Date, 103)
        FROM [EAI].[FC__TIME_WINDOW] AS TW;

        IF NULLIF(@pFecha_Inicio, '') IS NULL
        BEGIN
            -- Oracle ADD_MONTHS conserva el ultimo dia del mes de origen.
            SET @dFecha_Inicio = CASE WHEN @dVentana = EOMONTH(@dVentana)
                THEN EOMONTH(@dVentana, -1)
                ELSE DATEADD(MONTH, -1, @dVentana) END;
            SET @dFecha_Final = CONVERT(DATE, GETDATE());
        END
        ELSE
        BEGIN
            -- Estilo 112 interpreta los parametros en formato YYYYMMDD.
            SET @dFecha_Inicio = TRY_CONVERT(DATE, @pFecha_Inicio, 112);
            SET @dFecha_Final = TRY_CONVERT(DATE, @pFecha_Final, 112);
        END;

        IF @dVentana IS NULL
            THROW 54101, 'FC__TIME_WINDOW.Start_Date no contiene una fecha DD/MM/YYYY valida.', 1;

        IF @dFecha_Inicio IS NULL OR @dFecha_Final IS NULL
            THROW 54102, 'Si informa inicio, indique ambas fechas YYYYMMDD; inicio NULL/vacio usa la ventana.', 1;

        IF @dFecha_Inicio > @dFecha_Final
            THROW 54103, 'La fecha inicial no puede ser posterior a la fecha final.', 1;

        -- Se usa "menor que el dia siguiente" para incluir cualquier hora del
        -- ultimo dia sin aplicar CAST/CONVERT sobre la columna filtrada.
        SET @dtFechaLimite = DATEADD(DAY, 1, CONVERT(DATETIME2(0), @dFecha_Final));

        PRINT '-----------------------------';
        PRINT 'Proc_T3_CFDI_Resumen';
        PRINT CONVERT(VARCHAR(8), GETDATE(), 112) + ' ' + CONVERT(VARCHAR(8), GETDATE(), 108);

        SET @v_ID = 'Inicializar CFDI_Informe';

        -- FIN=NULL permite que monitoreo distinga un reporte aun en ejecucion.
        UPDATE [EAI].[CONTROL_REPORTE]
           SET Inicio = GETDATE(), Fin = NULL
         WHERE Reporte = 'BITACORA CFDI';

        /*
            Se lee y filtra el historial una sola vez. Las tres cargas siguientes
            reutilizan esta tabla temporal en lugar de recorrer nuevamente todo
            CFDI_Historia_Docto_PAC y convertir su fecha en cada consulta.
        */
        SELECT
            H.Nota_Venta,
            H.Ctro,
            H.Fecha_Factura,
            H.Nota_Venta_CFDI
        INTO #HDocPeriodo
        FROM [T3].[CFDI_Historia_Docto_PAC] AS H
        WHERE H.Fecha_Factura >= @dFecha_Inicio
          AND H.Fecha_Factura < @dtFechaLimite;

        -- Indice para buscar la venta original durante las cargas individuales.
        CREATE INDEX IX_HDocPeriodo_Nota
            ON #HDocPeriodo (Nota_Venta, Nota_Venta_CFDI);

        -- Indice para agrupar las ventas que comparten un mismo CFDI.
        CREATE INDEX IX_HDocPeriodo_CFDI
            ON #HDocPeriodo (Nota_Venta_CFDI)
            INCLUDE (Nota_Venta, Ctro, Fecha_Factura);

        /* Oracle sobrescribe LP en un cursor sin ORDER BY. MAX no reproduce
           ese contrato si hay valores distintos (incluido NULL). Detectar la
           ambiguedad ANTES del DELETE; requiere definir la regla con negocio.
           Solo se revisan folios del periodo que existen en CFDI_Agrupado.
        */
        SELECT X.Nota_Venta_CFDI, MAX(X.Grupo_Precio) AS Grupo_Precio,
               COUNT_BIG(*) AS ValoresDistintos
        INTO #ListaPrecio
        FROM
        (
            SELECT H.Nota_Venta_CFDI, NULLIF(F.Grupo_Precio, '') AS Grupo_Precio
            FROM [T3].[CFDI_Historia_Docto_PAC] AS H
            INNER JOIN [T3].[Fact_T3] AS F ON F.Factura = H.Nota_Venta
            UNION
            SELECT H.Nota_Venta_CFDI, NULLIF(N.Grupo_Precio, '')
            FROM [T3].[CFDI_Historia_Docto_PAC] AS H
            INNER JOIN [T3].[Nota_T3] AS N ON N.Factura = H.Nota_Venta
        ) AS X
        WHERE EXISTS (SELECT 1 FROM #HDocPeriodo AS P
                      WHERE P.Nota_Venta_CFDI = X.Nota_Venta_CFDI)
          AND EXISTS (SELECT 1 FROM [T3].[CFDI_Agrupado] AS A
                      WHERE A.Nota_Venta_CFDI = X.Nota_Venta_CFDI)
        GROUP BY X.Nota_Venta_CFDI;

        IF EXISTS (SELECT 1 FROM #ListaPrecio WHERE ValoresDistintos > 1)
            THROW 54104, 'Agrupado con varias LP posibles. Oracle no define orden; resolver la regla antes de reconstruir el informe.', 1;

        -- Esta tabla contiene una fotografia completa del periodo solicitado.
        DELETE FROM [EAI].[CFDI_INFORME];

        -------------------------------------------------------------------
        -- 3. CFDI individuales provenientes de Factura_General
        -------------------------------------------------------------------
        SET @v_ID = 'ScrPrompt';

        /*
            "Individual" significa que Nota_Venta = Nota_Venta_CFDI. En este
            bloque el documento se origina en Factura_General.

            Fuentes de los datos:
            - Paso aporta el RFC utilizado al facturar.
            - FG aporta importe T3, tipo y territorio.
            - PAC aporta UUID, estado e importes timbrados.
            - Cliente aporta nombre y lista de precio vigentes al facturar.
        */

        INSERT INTO [EAI].[CFDI_INFORME]
        (
            Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio,
            ID_Confirmacion, Nombre_Cliente, LP, Doctos, Terr,
            Tipo_Docto, Factor, Folio_Fiscal, Status, Monto_T3In,
            Valor_Subt, Valor_IVA, Valor
        )
        SELECT
            'MX06', H.Nota_Venta_CFDI, H.Fecha_Factura, H.Ctro,
            Paso.RFC_Factura, PAC.ID_Envio, PAC.ID_Confirmacion,
            Cte.Nombre, Cte.Lista_Precio, 1,
            SUBSTRING(FG.Ubicacion, 15, 4), FG.Tipo_Docto,
            S.Factor, PAC.Folio_Fiscal, PAC.Status,
            (ISNULL(FG.Valor_Subt, 0) + ISNULL(FG.Valor_IVA, 0)) * S.Factor,
            V.Valor_Subt * S.Factor,
            V.Valor_IVA * S.Factor,
            (V.Valor_Subt + V.Valor_IVA) * S.Factor
        FROM #HDocPeriodo AS H
        INNER JOIN [T3].[CFDI_Documento_Paso] AS Paso
            ON Paso.Factura = H.Nota_Venta
        INNER JOIN [T3].[Factura_General] AS FG
            ON FG.Factura = H.Nota_Venta
        INNER JOIN [T3].[CFDI_Documentos] AS PAC
            ON PAC.Nota_Venta = H.Nota_Venta
        INNER JOIN [T3].[Cliente] AS Cte
            ON Cte.Cliente_SAP = FG.Cliente_SAP
           AND FG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
        -- Calcula el signo una sola vez y lo reutiliza en cuatro expresiones.
        CROSS APPLY
        (
            VALUES (CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END)
        ) AS S(Factor)
        /*
            Regla PAC:
            - CONFIRMADO: usar importes confirmados por el PAC.
            - PENDING/PUBLICADO: usar importes operativos de T3.
            - Otro estado: reportar cero en los importes fiscales.
        */
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_Subt
                    ELSE 0
                END,
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN FG.Valor_IVA
                    ELSE 0
                END
            )
        ) AS V(Valor_Subt, Valor_IVA)
        WHERE H.Nota_Venta = H.Nota_Venta_CFDI;

        SET @nProceso1 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 4. CFDI individuales provenientes de Preventa_General
        -------------------------------------------------------------------
        SET @v_ID = 'ScrPreventa';

        /*
            La estructura es similar a Factura_General, con estas diferencias:
            - Las clases C020/C021/C022 pertenecen a la sociedad MX01.
            - C005, C0FX y C020 son movimientos positivos; el resto negativos.
            - Entrega.Ubicacion tiene prioridad sobre Preventa.Ubicacion.
            - Una cancelacion o fecha de proceso en 2999 deja Monto_T3In en 0.
        */

        INSERT INTO [EAI].[CFDI_INFORME]
        (
            Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio,
            ID_Confirmacion, Nombre_Cliente, LP, Doctos, Terr,
            Tipo_Docto, Factor, Folio_Fiscal, Status, Monto_T3In,
            Valor_Subt, Valor_IVA, Valor
        )
        SELECT
            CASE WHEN PG.Clase_Factura IN ('C020', 'C021', 'C022') THEN 'MX01' ELSE 'MX06' END,
            H.Nota_Venta_CFDI, H.Fecha_Factura, H.Ctro, Cte.RFC,
            PAC.ID_Envio, PAC.ID_Confirmacion, Cte.Nombre, Cte.Lista_Precio,
            1, COALESCE(NULLIF(E.Ubicacion, ''), NULLIF(PG.Ubicacion, '')), PG.Clase_Factura,
            S.Factor, PAC.Folio_Fiscal, PAC.Status,
            CASE
                WHEN PG.Fecha_Cancelacion IS NOT NULL THEN 0
                WHEN YEAR(PG.Fecha_Proc_BATMD) = 2999 THEN 0
                ELSE ISNULL(PG.Valor_Subt, 0) + ISNULL(PG.Valor_IVA, 0)
            END * S.Factor,
            V.Valor_Subt * S.Factor,
            V.Valor_IVA * S.Factor,
            (V.Valor_Subt + V.Valor_IVA) * S.Factor
        FROM #HDocPeriodo AS H
        INNER JOIN [T3].[Preventa_General] AS PG
            ON PG.Factura = H.Nota_Venta
        INNER JOIN [T3].[CFDI_Documentos] AS PAC
            ON PAC.Nota_Venta = H.Nota_Venta
        INNER JOIN [T3].[Cliente] AS Cte
            ON Cte.Cliente_SAP = PG.Cliente_SAP
           AND PG.Fecha_Factura BETWEEN Cte.Fecha_Ini_Vig AND Cte.Fecha_Fin_Vig
        -- LEFT JOIN conserva la preventa aunque no exista una entrega asociada.
        LEFT JOIN [T3].[Entrega] AS E
            ON E.Factura = H.Nota_Venta
        CROSS APPLY
        (
            VALUES (CASE WHEN PG.Clase_Factura IN ('C005', 'C0FX', 'C020') THEN 1 ELSE -1 END)
        ) AS S(Factor)
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN PG.Valor_Subt
                    ELSE 0
                END,
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                    WHEN PAC.Status IN ('PENDING', 'PUBLICADO') THEN PG.Valor_IVA
                    ELSE 0
                END
            )
        ) AS V(Valor_Subt, Valor_IVA)
        WHERE H.Nota_Venta = H.Nota_Venta_CFDI;

        SET @nProceso2 = @@ROWCOUNT;

        -------------------------------------------------------------------
        -- 5. CFDI agrupados
        -------------------------------------------------------------------
        SET @v_ID = 'ScrAgrupado';

        /*
            Un CFDI agrupado representa varias ventas mediante un solo folio.
            MontoOrigen suma los documentos T3 incluidos en el grupo.
            MontoCFDI suma el detalle fiscal del comprobante agrupado.
            Despues ambos resultados se unen por Nota_Venta_CFDI.
        */

        ;WITH HDocUnico AS
        (
            -- DISTINCT evita sumar dos veces la misma relacion historica.
            SELECT DISTINCT Nota_Venta, Ctro, Fecha_Factura, Nota_Venta_CFDI
            FROM #HDocPeriodo
        ), MontoOrigen AS
        (
            -- Importe operativo de todas las ventas que forman el agrupado.
            SELECT
                H.Ctro, H.Fecha_Factura, H.Nota_Venta_CFDI,
                SUM(FD.Valor_Subt + FD.Valor_IVA
                    + ISNULL(FD.Envio_Subt, 0) + ISNULL(FD.Envio_IVA, 0)) AS Total_T3In
            FROM HDocUnico AS H
            INNER JOIN [T3].[Factura_General] AS FG
                ON FG.Factura = H.Nota_Venta
            INNER JOIN [T3].[Factura_Detalle] AS FD
                ON FD.Factura = H.Nota_Venta
            WHERE H.Nota_Venta <> H.Nota_Venta_CFDI
            GROUP BY H.Ctro, H.Fecha_Factura, H.Nota_Venta_CFDI
        ), MontoCFDI AS
        (
            -- Importe fiscal, territorio y cantidad de documentos del grupo.
            SELECT
                A.Ctro,
                SUBSTRING(A.Cliente_SAP, 2, 5) AS Terr,
                A.Tipo_Docto,
                A.Nota_Venta_CFDI,
                CONVERT(DATE, A.Fecha_Documento) AS Fecha,
                MAX(A.Doctos) AS Doctos,
                SUM(D.Valor_Subt + ISNULL(D.Envio_Subt, 0) + ISNULL(D.Credito_Subt, 0)) AS Valor_Subt,
                SUM(D.Valor_IVA + ISNULL(D.Envio_IVA, 0) + ISNULL(D.Credito_IVA, 0)) AS Valor_IVA
            FROM [T3].[CFDI_Agrupado] AS A
            INNER JOIN [T3].[CFDI_Agrupado_Detalle] AS D
                ON D.Nota_Venta_CFDI = A.Nota_Venta_CFDI
            GROUP BY A.Ctro, SUBSTRING(A.Cliente_SAP, 2, 5), A.Tipo_Docto,
                     A.Nota_Venta_CFDI, CONVERT(DATE, A.Fecha_Documento)
        )
        INSERT INTO [EAI].[CFDI_INFORME]
        (
            Sociedad, Folio_Interno, Fecha, Ctro, RFC, ID_Envio,
            ID_Confirmacion, Nombre_Cliente, Doctos, Terr, Tipo_Docto,
            Factor, Folio_Fiscal, Status, Monto_T3In, Valor_Subt,
            Valor_IVA, Valor
        )
        SELECT
            'MX06', O.Nota_Venta_CFDI, O.Fecha_Factura, O.Ctro,
            -- Los agrupados usan el RFC generico definido por la regla SAT.
            'XAXX010101000', PAC.ID_Envio, PAC.ID_Confirmacion,
            'CLIENTE AGRUPADOR VENTAS DIA', C.Doctos, C.Terr,
            C.Tipo_Docto, S.Factor, PAC.Folio_Fiscal, PAC.Status,
            O.Total_T3In * S.Factor,
            V.Valor_Subt * S.Factor,
            V.Valor_IVA * S.Factor,
            (V.Valor_Subt + V.Valor_IVA) * S.Factor
        FROM MontoOrigen AS O
        INNER JOIN MontoCFDI AS C
            ON C.Nota_Venta_CFDI = O.Nota_Venta_CFDI
        INNER JOIN [T3].[CFDI_Documentos] AS PAC
            ON PAC.Nota_Venta = O.Nota_Venta_CFDI
        -- Los agrupados C003 son ventas; cualquier otro tipo es devolucion.
        CROSS APPLY
        (
            VALUES (CASE WHEN C.Tipo_Docto = 'C003' THEN 1 ELSE -1 END)
        ) AS S(Factor)
        /*
            En agrupados, PENDING usa el detalle agrupado. PUBLICADO no aparece
            en esta rama por decision heredada de Oracle y por eso cae en cero.
        */
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_Subt
                    WHEN PAC.Status = 'PENDING' THEN C.Valor_Subt
                    ELSE 0
                END,
                CASE
                    WHEN PAC.Status = 'CONFIRMADO' THEN PAC.Valor_IVA
                    WHEN PAC.Status = 'PENDING' THEN C.Valor_IVA
                    ELSE 0
                END
            )
        ) AS V(Valor_Subt, Valor_IVA);

        SET @nProceso3 = @@ROWCOUNT;
        SET @nCount = @nProceso1 + @nProceso2 + @nProceso3;

        PRINT 'Registros : ' + CONVERT(VARCHAR(20), @nCount);
        PRINT '-----------------------------';

        -------------------------------------------------------------------
        -- 6. Volumen e importes fiscales de documentos individuales
        -------------------------------------------------------------------
        SET @v_ID = 'ScrCIG_Individual';

        -- Conservar la multiplicidad del JOIN de Oracle, incluso si existen
        -- varias cabeceras fiscales. EXISTS limita el trabajo al informe.
        ;WITH Fiscal AS
        (
            /*
                Convierte Cantidad_Vta a cigarrillos:
                CAJ usa Cig_x_CLL y las demas presentaciones Cig_x_PAQ.
                Si la conversion no existe, se usa 1 para no perder cantidad.
            */
            SELECT
                RFD.Factura,
                SUM(RFD.Cantidad_Vta *
                    CASE WHEN M.Unidad_Med_Vta = 'CAJ'
                         THEN ISNULL(M.Cig_x_CLL, 1)
                         ELSE ISNULL(M.Cig_x_PAQ, 1) END) AS Cigarrillos,
                MAX(CASE WHEN RF.Tipo_Docto IN ('C005', 'C006') THEN 0 ELSE 1 END) AS Sumar_Envio,
                SUM(ISNULL(RFD.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(RFD.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(RFD.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(RFD.Credito_IVA, 0)) AS Credito_IVA
            FROM [T3].[Registro_Fiscal_Detalle] AS RFD
            INNER JOIN [T3].[Registro_Fiscal] AS RF ON RF.Factura = RFD.Factura
            INNER JOIN [T3].[Material] AS M ON M.Material = RFD.Material
            WHERE EXISTS (SELECT 1 FROM [EAI].[CFDI_INFORME] AS I
                          WHERE I.Folio_Interno = RFD.Factura)
            GROUP BY RFD.Factura
        )
        -- El signo de Info.Factor se aplica al volumen y a cada importe.
        UPDATE Info
           SET Cigarrillos = Info.Factor * F.Cigarrillos,
               Envio_Subt = Info.Factor * F.Envio_Subt,
               Envio_IVA = Info.Factor * F.Envio_IVA,
               Credito_Subt = Info.Factor * F.Credito_Subt,
               Credito_IVA = Info.Factor * F.Credito_IVA,
               Monto_T3In = Info.Monto_T3In
                   + Info.Factor * (F.Envio_Subt + F.Envio_IVA
                     + F.Credito_Subt + F.Credito_IVA) * F.Sumar_Envio
        FROM [EAI].[CFDI_INFORME] AS Info
        INNER JOIN Fiscal AS F ON F.Factura = Info.Folio_Interno;

        -------------------------------------------------------------------
        -- 7. Volumen e importes fiscales de documentos agrupados
        -------------------------------------------------------------------
        SET @v_ID = 'ScrCIG_Agrupado';

        /*
            Es el equivalente del bloque anterior para el detalle agrupado.
            En este caso no se modifica Monto_T3In: ya fue calculado sumando las
            facturas de origen en MontoOrigen.
        */

        ;WITH Fiscal AS
        (
            SELECT
                D.Nota_Venta_CFDI,
                SUM(D.Cantidad_Vta *
                    CASE WHEN M.Unidad_Med_Vta = 'CAJ'
                         THEN ISNULL(M.Cig_x_CLL, 1)
                         ELSE ISNULL(M.Cig_x_PAQ, 1) END) AS Cigarrillos,
                SUM(ISNULL(D.Envio_Subt, 0)) AS Envio_Subt,
                SUM(ISNULL(D.Envio_IVA, 0)) AS Envio_IVA,
                SUM(ISNULL(D.Credito_Subt, 0)) AS Credito_Subt,
                SUM(ISNULL(D.Credito_IVA, 0)) AS Credito_IVA
            FROM [T3].[CFDI_Agrupado_Detalle] AS D
            INNER JOIN [T3].[CFDI_Agrupado] AS A ON A.Nota_Venta_CFDI = D.Nota_Venta_CFDI
            INNER JOIN [T3].[Material] AS M ON M.Material = D.Material
            WHERE EXISTS (SELECT 1 FROM [EAI].[CFDI_INFORME] AS I
                          WHERE I.Folio_Interno = D.Nota_Venta_CFDI)
            GROUP BY D.Nota_Venta_CFDI
        )
        UPDATE Info
           SET Cigarrillos = Info.Factor * F.Cigarrillos,
               Envio_Subt = Info.Factor * F.Envio_Subt,
               Envio_IVA = Info.Factor * F.Envio_IVA,
               Credito_Subt = Info.Factor * F.Credito_Subt,
               Credito_IVA = Info.Factor * F.Credito_IVA
        FROM [EAI].[CFDI_INFORME] AS Info
        INNER JOIN Fiscal AS F ON F.Nota_Venta_CFDI = Info.Folio_Interno;

        -------------------------------------------------------------------
        -- 8. Lista de precio para CFDI agrupados
        -------------------------------------------------------------------
        SET @v_ID = 'ScrComplementoAGR';

        -- La LP unica fue validada antes de borrar el informe anterior.
        -- Solo completa LP cuando la carga principal no encontro uno.
        UPDATE Info
           SET LP = L.Grupo_Precio
        FROM [EAI].[CFDI_INFORME] AS Info
        INNER JOIN #ListaPrecio AS L ON L.Nota_Venta_CFDI = Info.Folio_Interno
        WHERE NULLIF(Info.LP, '') IS NULL
          AND EXISTS
          (
              SELECT 1 FROM [T3].[CFDI_Agrupado] AS A
              WHERE A.Nota_Venta_CFDI = Info.Folio_Interno
          );

        -------------------------------------------------------------------
        -- 9. Ajustes fiscales y diferencias menores de centavos
        -------------------------------------------------------------------
        SET @v_ID = 'ScrDiferencias';

        -- Oracle aplica CADA ajuste a CADA fila del informe y cuenta cada par.
        -- Agregar por folio conserva ajustes repetidos; un JOIN directo tomaba
        -- un ajuste indeterminado cuando habia mas de uno.
        SELECT D.Nota_Venta_CFDI, SUM(D.Ajuste) AS Ajuste,
               COUNT_BIG(*) AS Cantidad
        INTO #Ajustes
        FROM [T3].[CFDI_Agrupado_DIF] AS D
        WHERE D.Ajuste <> 0
          AND EXISTS (SELECT 1 FROM [EAI].[CFDI_INFORME] AS I
                      WHERE I.Folio_Interno = D.Nota_Venta_CFDI)
        GROUP BY D.Nota_Venta_CFDI;

        SELECT @nProceso4 = COALESCE(SUM(D.Cantidad), 0)
        FROM [EAI].[CFDI_INFORME] AS Info
        INNER JOIN #Ajustes AS D ON D.Nota_Venta_CFDI = Info.Folio_Interno;

        UPDATE Info
           SET Valor_IVA = Info.Valor_IVA + D.Ajuste,
               Valor = Info.Valor + D.Ajuste
        FROM [EAI].[CFDI_INFORME] AS Info
        INNER JOIN #Ajustes AS D
            ON D.Nota_Venta_CFDI = Info.Folio_Interno
        ;
        SET @v_ID = 'ScrCentavos_CFD';

        /*
            Solo se corrigen diferencias menores a seis centavos. El ajuste se
            resta del IVA y se conserva en Diferencia para que sea auditable.
            Los folios G-* se excluyen porque ya usan el ajuste de agrupados.
        */
        UPDATE Info
           SET Valor_IVA = Info.Valor_IVA - (Info.Valor - Info.Monto_T3In),
               Diferencia = Info.Valor - Info.Monto_T3In,
               Valor = Info.Monto_T3In
        FROM [EAI].[CFDI_INFORME] AS Info
        WHERE Info.Valor <> Info.Monto_T3In
          AND Info.Folio_Interno NOT LIKE 'G-%'
          AND ABS(Info.Valor - Info.Monto_T3In) < 0.06
          AND Info.Fecha >= @dVentana;

        -------------------------------------------------------------------
        -- 10. Addenda y normalizacion de documentos publicados
        -------------------------------------------------------------------
        SET @v_ID = 'Updating Addenda';

        -- Igual que Oracle: SI para RFC con addenda; NO solo donde sea NULL.
        UPDATE Info
           SET Addenda = CASE WHEN EXISTS
               (SELECT 1 FROM [T3].[CFDI_Addenda] AS A WHERE A.RFC = Info.RFC)
               THEN 'SI' ELSE COALESCE(NULLIF(Info.Addenda, ''), 'NO') END
        FROM [EAI].[CFDI_INFORME] AS Info;

        -- Para PUBLICADO, T3 es el importe oficial del resumen.
        UPDATE [EAI].[CFDI_INFORME]
           SET Valor = Monto_T3In
         WHERE Status = 'PUBLICADO'
           AND Valor <> Monto_T3In;

        -------------------------------------------------------------------
        -- 11. Ventas centralizadas y cierre de auditoria
        -------------------------------------------------------------------
        SET @v_ID = 'ScrFactCentral';

        -- Oracle selecciona Doc_Num elegibles y luego actualiza TODAS sus filas,
        -- incluso otra fila del mismo documento fuera de vigencia o cliente.
        UPDATE B
           SET SF_Amount = B.SAP_Amount,
               Origen = 'SAP'
        FROM [EAI].[CFDI_BITACORA] AS B
        WHERE EXISTS
        (
            SELECT 1
            FROM [EAI].[CFDI_BITACORA] AS Elegible
            INNER JOIN [EAI_OWNER].[WA_VENTA_CENTRALIZADA] AS C
                ON C.Cliente_SAP = Elegible.Cliente_SAP
               AND Elegible.Invc_dt BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig
            WHERE Elegible.Doc_Num = B.Doc_Num
        );

        -- Propaga la misma fuente al resumen cuando existe el folio relacionado.
        UPDATE I
           SET Origen = 'SAP'
        FROM [EAI].[CFDI_INFORME] AS I
        INNER JOIN [EAI].[CFDI_BITACORA] AS B
            ON B.Doc_Num = I.Folio_Interno
        INNER JOIN [EAI_OWNER].[WA_VENTA_CENTRALIZADA] AS C
            ON C.Cliente_SAP = B.Cliente_SAP
           AND B.Invc_dt BETWEEN C.Fecha_Ini_Vig AND C.Fecha_Fin_Vig;

        -- Cierra las marcas de monitoreo y guarda los contadores de esta corrida.
        UPDATE [EAI].[CONTROL_REPORTE]
           SET Fin = GETDATE()
         WHERE Reporte = 'BITACORA CFDI';

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

        PRINT 'Proceso completado exitosamente.';
    END TRY
    BEGIN CATCH
        /*
            ERROR_NUMBER y ERROR_MESSAGE capturan el error real de SQL Server.
            @v_ID ayuda a identificar que bloque estaba ejecutandose. LEFT limita
            el texto al tamano de Siebel_Error_Message.
        */
        SET @sErrorCode = 'ERR-' + CONVERT(VARCHAR(30), ERROR_NUMBER());
        SET @sMsg = LEFT(CONVERT(VARCHAR(10), ERROR_NUMBER()) + '-' + ERROR_MESSAGE(), 250);
        SET @v_ID = ISNULL(@v_ID, 'Unknown');

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction, Reference, Created, Message, Job_PID, Status,
            Queue_Name, Siebel_Error_Message, Source, Siebel_Error_Code,
            Retry_Count, [Sequence], Parent_Row_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error',
            'SF_BITACORA_CFDI_RESUMEN', @sMsg, 'T-SQL', @sErrorCode,
            NULL, NULL, NULL
        );

        PRINT '*********** Mensaje ************************';
        PRINT '*** Error en BITACORA_CFDI_RESUMEN ***';
        PRINT @sMsg;

        -- SQL Agent debe recibir el error para marcar correctamente el job.
        THROW;
    END CATCH;
END;
GO
