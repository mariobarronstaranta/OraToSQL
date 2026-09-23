/*
    Procedure : EAI.SF_BITACORA_CFDI
    Objetivo  : Construir y enriquecer la bitacora detallada de CFDI.

    Esta version conserva las etapas Oracle, corrige omisiones de la migracion
    MSSQL y elimina auto-joins/correlaciones que recorrian repetidamente la
    tabla EAI.CFDI_BITACORA.

    Guia para desarrolladores JR:
    - @nEtapa indica desde donde iniciar. Con 0 se ejecutan todas las etapas.
    - Una etapa N se ejecuta cuando @nEtapa <= N.
      Ejemplo: con @nEtapa = 80 se ejecutan 80, 90, 100 y el bloque final.
    - Con @nEtapa = NULL o un valor mayor a 100 solo se ejecuta el bloque final.
    - Las actualizaciones finales siempre se ejecutan.
    - La etapa 0 elimina y reconstruye toda EAI.CFDI_BITACORA. No debe
      ejecutarse manualmente mientras el job productivo este procesando datos.

    Abreviaturas usadas en el codigo:
    - CB  = CFDI_BITACORA (tabla resultado).
    - FG/FD = Factura_General / Factura_Detalle.
    - PG/PD = Preventa_General / Preventa_Detalle.
    - HDP = historial que relaciona una venta con su CFDI agrupado.
    - CFD = datos fiscales/timbrado del comprobante.
    - RFD = detalle del registro fiscal.
    - SAP = documentos provenientes de SAP.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [EAI].[SF_BITACORA_CFDI]
    @nEtapa INT = 0
AS
BEGIN
    -- Evita mensajes "N filas afectadas"; reduce trafico hacia el cliente/job.
    SET NOCOUNT ON;

    -- Si en el futuro se agrega una transaccion explicita, un error de ejecucion
    -- provocara su cancelacion completa. Actualmente las etapas son autocommit.
    SET XACT_ABORT ON;

    /*
        Variables de control:
        - @v_ID identifica la etapa que se registra si ocurre un error.
        - @nPID identifica de forma unica esta ejecucion.
        - @nProceso = 801 es el identificador funcional de BITACORA CFDI.
        - @nProceso1..4 guardan contadores para la bitacora de procesos.
    */
    DECLARE
        @sMsg        VARCHAR(500),
        @v_ID        VARCHAR(50) = 'CEDIS.Clean',
        @sErrorCode  VARCHAR(20),
        @dtInicio    DATETIME2(0),
        @nPID        BIGINT,
        @nProceso    INT = 801,
        @nProceso1   INT = 0,
        @nProceso2   INT = 0,
        @nProceso3   INT = 0,
        @nProceso4   INT = 0;

    BEGIN TRY
        -------------------------------------------------------------------
        -- Inicio y auditoria
        -------------------------------------------------------------------
        SET @dtInicio = SYSDATETIME();

        -- La secuencia evita que dos ejecuciones simultaneas obtengan el mismo PID.
        SET @nPID = NEXT VALUE FOR [EAI_OWNER].[ProcessID];

        -- Notifica al mecanismo general de monitoreo que inicia el proceso 801.
        EXEC [EAI_OWNER].[Log_Start] @nProceso;

        -- Abre el registro detallado que se cerrara al final del procedimiento.
        INSERT INTO [T3].[RF_PROCESOS_LOG]
            (PID, Proceso, Fecha_Proc_BATMD, Inicio)
        VALUES
            (@nPID, @nProceso, NULL, @dtInicio);

        -- Marca el reporte como iniciado y limpia la fecha de fin anterior.
        UPDATE [EAI].[CONTROL_REPORTE]
           SET Inicio = @dtInicio,
               Fin = NULL
         WHERE Reporte = 'BITACORA CFDI - DETALLE';

        -------------------------------------------------------------------
        -- Etapa 0: reconstruir la bitacora desde facturas y preventas
        -------------------------------------------------------------------
        SET @v_ID = 'CFDI_Bitacora';

        IF @nEtapa <= 0
        BEGIN
            -- La bitacora es una tabla de reconstruccion completa, no incremental.
            DELETE FROM [EAI].[CFDI_BITACORA];

            /*
                SourceItem normaliza factura inmediata y preventa. Los importes
                de devoluciones se multiplican por -1. Para preventas canceladas
                Oracle usa factor cero; se conserva esa regla en vez de omitirlas.

                FC__TIME_WINDOW contiene la fecha inicial configurada. Se resta
                un mes porque esa es la ventana definida por el proceso Oracle.
            */
            ;WITH SourceItem AS
            (
                SELECT
                    FG.Ctro,
                    FG.Factura AS Doc_Num,
                    FG.Entrega AS Factura_SAP,
                    HDP.Nota_Venta_CFDI,
                    FG.Cliente_SAP,
                    FG.Clte_Factura_SAP,
                    CAST(FG.Fecha_Factura AS DATE) AS Invc_dt,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 'Vta' ELSE 'Dev' END AS Tipo_Vta,
                    FG.Fecha_Trn,
                    FG.Fecha_Proc_BATMD,
                    CASE WHEN FG.Tipo_Docto = 'C003' THEN 1 ELSE -1 END AS Signo,
                    CONVERT(INT, 1) AS Factor_T3MX,
                    FD.Valor_Subt,
                    FD.Valor_IVA,
                    FD.Bonif_Subt,
                    FD.Envio_Subt,
                    FD.Envio_IVA,
                    FD.Credito_Subt,
                    FD.Credito_IVA
                FROM [T3].[Factura_General] AS FG
                CROSS JOIN [EAI].[FC__TIME_WINDOW] AS TW
                INNER JOIN [T3].[Factura_Detalle] AS FD
                    ON FD.Factura = FG.Factura
                -- LEFT JOIN: una factura puede no pertenecer a un CFDI agrupado.
                LEFT JOIN [T3].[CFDI_Historia_Docto_PAC] AS HDP
                    ON HDP.Nota_Venta = FG.Factura
                WHERE FG.Fecha_Factura >=
                      DATEADD(MONTH, -1, CONVERT(DATE, TW.Start_Date, 103))

                -- Une los movimientos de preventa sin ordenar ni eliminar filas;
                -- la siguiente CTE los consolida por documento.
                UNION ALL

                SELECT
                    PG.Ctro,
                    PG.Factura,
                    PG.Entrega,
                    PG.Factura,
                    PG.Cliente_SAP,
                    PG.Cliente_SAP,
                    CAST(PG.Fecha_Factura AS DATE),
                    CASE WHEN PG.Clase_Factura = 'C005' THEN 'Vta' ELSE 'Dev' END,
                    PG.Fecha_Trn,
                    PG.Fecha_Proc_BATMD,
                    CASE WHEN PG.Clase_Factura = 'C005' THEN 1 ELSE -1 END,
                    -- Una cancelada permanece visible, pero sus importes valen 0.
                    CASE WHEN PG.Fecha_Cancelacion IS NULL THEN 1 ELSE 0 END,
                    PD.Valor_Subt,
                    PD.Valor_IVA,
                    PD.Bonif_Subt,
                    PD.Envio_Subt,
                    PD.Envio_IVA,
                    PD.Credito_Subt,
                    PD.Credito_IVA
                FROM [T3].[Preventa_General] AS PG
                CROSS JOIN [EAI].[FC__TIME_WINDOW] AS TW
                INNER JOIN [T3].[Preventa_Detalle] AS PD
                    ON PD.Factura = PG.Factura
                WHERE PG.Fecha_Factura >=
                      DATEADD(MONTH, -1, CONVERT(DATE, TW.Start_Date, 103))
                  AND PG.Fecha_Proc_BATMD IS NOT NULL
                  AND PG.Clase_Factura IN ('C005', 'C006', 'C025')
            ), Document AS
            (
                -- Puede haber varios renglones de detalle para una factura.
                -- Se suman para insertar una fila consolidada en la bitacora.
                SELECT
                    Ctro, Doc_Num, Factura_SAP, Nota_Venta_CFDI,
                    Cliente_SAP, Clte_Factura_SAP, Invc_dt, Tipo_Vta,
                    Fecha_Trn, Fecha_Proc_BATMD,
                    SUM(Signo * Factor_T3MX * ISNULL(Valor_Subt, 0)) AS Valor_Subt,
                    SUM(Signo * Factor_T3MX * ISNULL(Valor_IVA, 0)) AS Valor_IVA,
                    SUM(Signo * Factor_T3MX * ISNULL(Bonif_Subt, 0)) AS Bonif_Subt,
                    SUM(Signo * Factor_T3MX * ISNULL(Envio_Subt, 0)) AS Envio_Subt,
                    SUM(Signo * Factor_T3MX * ISNULL(Envio_IVA, 0)) AS Envio_IVA,
                    SUM(Signo * Factor_T3MX * ISNULL(Credito_Subt, 0)) AS Credito_Subt,
                    SUM(Signo * Factor_T3MX * ISNULL(Credito_IVA, 0)) AS Credito_IVA
                FROM SourceItem
                GROUP BY
                    Ctro, Doc_Num, Factura_SAP, Nota_Venta_CFDI,
                    Cliente_SAP, Clte_Factura_SAP, Invc_dt, Tipo_Vta,
                    Fecha_Trn, Fecha_Proc_BATMD
            )
            INSERT INTO [EAI].[CFDI_BITACORA]
            (
                Ctro, Doc_Num, Factura_SAP, Nota_Venta_CFDI,
                Cliente_SAP, Clte_Factura_SAP, Invc_dt, Tipo_Vta,
                Fecha_Trn, Fecha_Proc_BATMD, Valor_Subt, Valor_IVA,
                Bonif_Subt, Envio_Subt, Envio_IVA, Credito_Subt, Credito_IVA
            )
            SELECT
                Ctro, Doc_Num, Factura_SAP, Nota_Venta_CFDI,
                Cliente_SAP, Clte_Factura_SAP, Invc_dt, Tipo_Vta,
                Fecha_Trn, Fecha_Proc_BATMD, Valor_Subt, Valor_IVA,
                Bonif_Subt, Envio_Subt, Envio_IVA, Credito_Subt, Credito_IVA
            FROM Document;

            -- Las devoluciones no manejan dias de credito en este reporte.
            UPDATE [EAI].[CFDI_BITACORA]
               SET Credit_Days = 0
             WHERE Tipo_Vta <> 'Vta';

            /*
                El original consultaba Registro_Fiscal_Detalle dos veces por
                fila: una subconsulta para el valor y otra para EXISTS. Aqui se
                agrega una vez y se actualiza mediante JOIN.
            */
            ;WITH Bonus AS
            (
                SELECT
                    RFD.Factura,
                    SUM(ISNULL(RFD.Bonif_Subt, 0) + ISNULL(RFD.Bonif_IVA, 0)) AS Bonif_Subt
                FROM [T3].[Registro_Fiscal_Detalle] AS RFD
                GROUP BY RFD.Factura
                -- Solo se reemplaza la bonificacion cuando existe subtotal
                -- bonificado; esta condicion reproduce la regla de Oracle.
                HAVING SUM(ISNULL(RFD.Bonif_Subt, 0)) > 0
            )
            UPDATE CB
               SET CB.Bonif_Subt = B.Bonif_Subt
            FROM [EAI].[CFDI_BITACORA] AS CB
            CROSS JOIN [EAI].[FC__TIME_WINDOW] AS TW
            INNER JOIN Bonus AS B
                ON B.Factura = CB.Doc_Num
            WHERE CB.Invc_dt >=
                  DATEADD(MONTH, -1, CONVERT(DATE, TW.Start_Date, 103));
        END;

        -------------------------------------------------------------------
        -- Etapa 10: datos de factura inmediata
        -------------------------------------------------------------------
        SET @v_ID = 'ScrPrompt';

        IF @nEtapa <= 10
        BEGIN
            -- Se usa Doc_Num; ROWID no existe en SQL Server y ROW_ID no se
            -- asigna durante la carga inicial.
            -- Ubicacion guarda el territorio desde la posicion 15 (4 caracteres).
            UPDATE CB
               SET CB.Ctro = FG.Ctro,
                   CB.Terr = SUBSTRING(FG.Ubicacion, 15, 4)
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [T3].[Factura_General] AS FG
                ON FG.Factura = CB.Doc_Num;

            SET @nProceso1 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 20: territorio de preventa
        -------------------------------------------------------------------
        SET @v_ID = 'ScrPresales';

        IF @nEtapa <= 20
        BEGIN
            /*
                Para preventas vigentes se toma primero la ubicacion de Entrega.
                Si Entrega.Ubicacion es NULL, se usa la ubicacion de la preventa.
                Las canceladas y registros fuera del ano actual no se enriquecen.
            */
            UPDATE CB
               SET CB.Terr = ISNULL(E.Ubicacion, PG.Ubicacion)
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [T3].[Preventa_General] AS PG
                ON PG.Factura = CB.Doc_Num
            INNER JOIN [T3].[Entrega] AS E
                ON E.Factura = CB.Doc_Num
            WHERE PG.Fecha_Cancelacion IS NULL
              AND YEAR(ISNULL(PG.Fecha_Proc_BATMD, DATEADD(DAY, 366, GETDATE())))
                  = YEAR(GETDATE());

            SET @nProceso2 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 30: CFDI individual
        -------------------------------------------------------------------
        SET @v_ID = 'ScrIndividual';

        IF @nEtapa <= 30
        BEGIN
            /*
                Un CFDI es individual cuando CFDI_Documentos.Nota_Venta coincide
                directamente con Doc_Num. Se copian fechas y estado de timbrado;
                Docto_Ind = 1 permite distinguirlo de un comprobante agrupado.
            */
            UPDATE CB
               SET CB.Nota_Venta_CFDI = CFD.Nota_Venta,
                   CB.Fecha_Venta = CB.Invc_dt,
                   CB.Fecha_Liberacion = CFD.Fecha_Liberacion,
                   CB.Fecha_Envio = CFD.Fecha_Envio,
                   CB.Fecha_Timbre = CFD.Fecha_Timbre,
                   CB.Fecha_CFD = CFD.Fecha_CFD,
                   CB.Status = CFD.Status,
                   CB.Total_CFD = ISNULL(CFD.Valor_Subt, 0) + ISNULL(CFD.Valor_IVA, 0),
                   CB.Docto_Ind = 1
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [T3].[CFDI_Documentos] AS CFD
                ON CFD.Nota_Venta = CB.Doc_Num
            WHERE CB.Fecha_Proc_BATMD IS NOT NULL;
        END;

        -------------------------------------------------------------------
        -- Etapa 40: CFDI agrupado
        -------------------------------------------------------------------
        SET @v_ID = 'ScrAgrupado';

        IF @nEtapa <= 40
        BEGIN
            /*
                En un CFDI agrupado, HDP conecta la venta original con el folio
                fiscal comun. CHARINDEX conserva la validacion heredada de Oracle:
                indica si el documento fiscal contiene el numero de la venta.
            */
            UPDATE CB
               SET CB.Fecha_Venta = A.Fecha_Documento,
                   CB.Fecha_Liberacion = CFD.Fecha_Liberacion,
                   CB.Fecha_Envio = CFD.Fecha_Envio,
                   CB.Fecha_Timbre = CFD.Fecha_Timbre,
                   CB.Fecha_CFD = CFD.Fecha_CFD,
                   CB.Status = CFD.Status,
                   CB.Total_CFD = ISNULL(CFD.Valor_Subt, 0) + ISNULL(CFD.Valor_IVA, 0),
                   CB.Docto_SAT = CASE WHEN CHARINDEX(CFD.Nota_Venta, CB.Doc_Num) = 0 THEN 0 ELSE 1 END,
                   CB.Doctos = CASE WHEN CHARINDEX(CFD.Nota_Venta, CB.Doc_Num) = 0 THEN 0 ELSE A.Doctos END
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [T3].[CFDI_Historia_Docto_PAC] AS H
                ON H.Nota_Venta = CB.Doc_Num
            INNER JOIN [T3].[CFDI_Agrupado] AS A
                ON A.Nota_Venta_CFDI = H.Nota_Venta_CFDI
            INNER JOIN [T3].[CFDI_Documentos] AS CFD
                ON CFD.Nota_Venta = H.Nota_Venta_CFDI
            WHERE CB.Fecha_Proc_BATMD IS NOT NULL
              AND H.Nota_Venta_CFDI <> H.Nota_Venta;

            SET @nProceso3 = @@ROWCOUNT;
        END;

        -------------------------------------------------------------------
        -- Etapa 80: volumen por categoria
        -------------------------------------------------------------------
        SET @v_ID = 'ScrVolumen';

        IF @nEtapa <= 80
        BEGIN
            /*
                Primera categoria: materiales cuyo numero inicia con "1". Su
                volumen se convierte a sticks usando la presentacion del material.
                Segunda categoria: los demas materiales; conserva Cantidad_Vta.

                EXISTS confirma que la factura posee cabecera fiscal sin unirla
                al detalle, evitando duplicar cantidades si hay cabeceras repetidas.
            */
            ;WITH Volume AS
            (
                SELECT
                    RFD.Factura,
                    SUM
                    (
                        CASE WHEN LEFT(LTRIM(RFD.Material), 1) = '1' THEN 1 ELSE 0 END
                        * RFD.Cantidad_Vta
                        * CASE WHEN M.Unidad_Med_Vta = 'CAJ' THEN M.Cig_x_CLL ELSE M.Cig_x_PAQ END
                    ) AS Sticks,
                    SUM
                    (
                        CASE WHEN LEFT(LTRIM(RFD.Material), 1) = '1' THEN 0 ELSE 1 END
                        * RFD.Cantidad_Vta
                    ) AS Segunda_Cat
                FROM [T3].[Registro_Fiscal_Detalle] AS RFD
                INNER JOIN [T3].[Material] AS M
                    ON M.Material = RFD.Material
                WHERE EXISTS
                (
                    SELECT 1
                    FROM [T3].[Registro_Fiscal] AS RF
                    WHERE RF.Factura = RFD.Factura
                )
                GROUP BY RFD.Factura
            )
            UPDATE CB
               SET CB.Primer_Categoria = V.Sticks,
                   CB.Segunda_Categoria = V.Segunda_Cat
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN Volume AS V
                ON V.Factura = CB.Doc_Num;
        END;

        -------------------------------------------------------------------
        -- Etapa 90: importe SAP y documentos de descuento
        -------------------------------------------------------------------
        SET @v_ID = 'SAP_Amount';

        IF @nEtapa <= 90
        BEGIN
            /*
                GETCONV resuelve los folios que fueron sustituidos o duplicados.
                Las ventas conservan signo positivo y las devoluciones negativo.
                Los estados D y E no representan documentos SAP utilizables.
            */
            UPDATE CB
               SET CB.SAP_Amount =
                   CASE WHEN CB.Tipo_Vta = 'Vta' THEN 1 ELSE -1 END
                   * (SAP.Doc_NetAmt + SAP.Doc_TaxAmt)
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [EAI].[T3R_Sales_Docs_Old] AS SAP
                ON SAP.Doc_Num_Ref2 =
                   [EAI_OWNER].[GETCONV]('FolioDuplicado', CB.Doc_Num)
            WHERE SAP.Doc_Status NOT IN ('D', 'E');

            SET @v_ID = 'DESC_Amount';

            /*
                Los importes temporales C025 vienen expresados en centavos.
                Primero se consolidan por ReferenceID y despues se convierten a
                moneda dividiendo entre -100 (son documentos de descuento).
            */
            ;WITH Discount AS
            (
                SELECT
                    D.ReferenceID,
                    SUM(ISNULL(D.Valor_Subt, 0) + ISNULL(D.Valor_IVA, 0)) AS SAP_Amount
                FROM [EAI_OWNER].[tmp_Document_Header] AS H
                INNER JOIN [EAI_OWNER].[tmp_Document_Detail] AS D
                    ON D.ReferenceID = H.ReferenceID
                WHERE H.DeliveryType = 'C025'
                GROUP BY D.ReferenceID
            )
            UPDATE CB
               -- El divisor decimal evita que SQL Server reduzca -1 / 100
               -- mediante aritmética entera y termine asignando cero.
               SET CB.SAP_Amount = D.SAP_Amount / CONVERT(DECIMAL(19, 4), -100.0)
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN Discount AS D
                ON D.ReferenceID = CB.Factura_SAP;
        END;

        -------------------------------------------------------------------
        -- Etapa 100: metodo y forma de pago desde XML CFDI 4.0
        -------------------------------------------------------------------
        SET @v_ID = 'MetodoPago';

        IF @nEtapa <= 100
        BEGIN
            /*
                Los CFDI agrupados no tienen un XML individual por cada venta.
                Por regla de negocio reciben Metodo=PUE y Forma=99.
            */
            UPDATE [EAI].[CFDI_BITACORA]
               SET Metodo_Pago = 'PUE',
                   Forma_Pago = '99'
             WHERE Doc_Num <> Nota_Venta_CFDI
               AND Nota_Venta_CFDI IS NOT NULL;

            /*
                XMLNAMESPACES declara el prefijo cfdi requerido para consultar
                el XML SAT 4.0. [1] obliga a obtener un solo atributo por XML.
                Este UPDATE aplica solamente a documentos individuales.
            */
            ;WITH XMLNAMESPACES
            (
                'http://www.sat.gob.mx/cfd/4' AS cfdi
            )
            UPDATE CB
               SET CB.Metodo_Pago = X.Anexo_CFD.value
                   ('(/cfdi:Comprobante/@MetodoPago)[1]', 'varchar(4)'),
                   CB.Forma_Pago = X.Anexo_CFD.value
                   ('(/cfdi:Comprobante/@FormaPago)[1]', 'varchar(4)')
            FROM [EAI].[CFDI_BITACORA] AS CB
            INNER JOIN [T3].[RF_Documentos] AS X
                ON X.Factura = CB.Doc_Num
            WHERE CB.Doc_Num = CB.Nota_Venta_CFDI;
        END;

        -------------------------------------------------------------------
        -- Final: RFC, centro BackOffice y facturacion central
        -------------------------------------------------------------------
        SET @v_ID = 'Final';

        /*
            Obtiene el RFC vigente en la fecha de la factura. MAX permite devolver
            un unico valor si existen periodos duplicados en el catalogo Cliente.
            OUTER APPLY conserva la fila de bitacora y asigna NULL si no hay RFC.
        */
        UPDATE CB
           SET CB.RFC = C.RFC
        FROM [EAI].[CFDI_BITACORA] AS CB
        OUTER APPLY
        (
            SELECT MAX(Cli.RFC) AS RFC
            FROM [T3].[Cliente] AS Cli
            WHERE Cli.Cliente_SAP = CB.Cliente_SAP
              AND CB.Invc_dt BETWEEN Cli.Fecha_Ini_Vig AND Cli.Fecha_Fin_Vig
        ) AS C;

        /*
            Para clientes BackOffice, el centro depende del tipo de movimiento:
            venta usa Ctro_HUB y devolucion usa Ctro_Customer. El WHERE evita
            escrituras cuando el centro ya tiene el valor correcto.
        */
        UPDATE CB
           SET CB.Ctro =
               CASE
                   WHEN CB.Tipo_Vta = 'Vta' THEN BO.Ctro_HUB
                   WHEN CB.Tipo_Vta = 'Dev' THEN BO.Ctro_Customer
                   ELSE CB.Ctro
               END
        FROM [EAI].[CFDI_BITACORA] AS CB
        INNER JOIN [EAI_OWNER].[TAO_Cedis_Valid] AS BO
            ON BO.Accnt_ID = CB.Cliente_SAP
           AND BO.Loc = CB.Cliente_SAP
        WHERE (CB.Tipo_Vta = 'Vta' AND CB.Ctro <> BO.Ctro_HUB)
           OR (CB.Tipo_Vta = 'Dev' AND CB.Ctro <> BO.Ctro_Customer);

        /*
            Regla Oracle omitida en el MSSQL original: para clientes centrales,
            SAP es la fuente oficial del importe. Se sincroniza tambien el
            campo Origen del informe relacionado.
        */
        UPDATE CB
           SET CB.SF_Amount = CB.SAP_Amount,
               CB.Origen = 'SAP'
        FROM [EAI].[CFDI_BITACORA] AS CB
        INNER JOIN [EAI_OWNER].[WA_VENTA_CENTRALIZADA] AS VC
            ON VC.Cliente_SAP = CB.Cliente_SAP
           AND CB.Invc_dt BETWEEN VC.Fecha_Ini_Vig AND VC.Fecha_Fin_Vig;

        -- El mismo origen debe quedar visible en el reporte consolidado.
        UPDATE I
           SET I.Origen = 'SAP'
        FROM [EAI].[CFDI_INFORME] AS I
        INNER JOIN [EAI].[CFDI_BITACORA] AS CB
            ON CB.Doc_Num = I.Folio_Interno
        INNER JOIN [EAI_OWNER].[WA_VENTA_CENTRALIZADA] AS VC
            ON VC.Cliente_SAP = CB.Cliente_SAP
           AND CB.Invc_dt BETWEEN VC.Fecha_Ini_Vig AND VC.Fecha_Fin_Vig;

        -- Cierra las tres marcas de monitoreo abiertas al iniciar la ejecucion.
        UPDATE [EAI].[CONTROL_REPORTE]
           SET Fin = GETDATE()
         WHERE Reporte = 'BITACORA CFDI - DETALLE';

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
            ERROR_NUMBER/ERROR_MESSAGE describen el fallo real de SQL Server.
            @v_ID permite saber en que etapa ocurrio. LEFT limita el mensaje al
            tamano de la columna Siebel_Error_Message.
        */
        SET @sErrorCode = CONCAT('ORA-', ERROR_NUMBER());
        SET @sMsg = LEFT(CONCAT(@sErrorCode, '-', ERROR_MESSAGE()), 250);

        INSERT INTO [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
        (
            Direction, Reference, Created, Message, Job_PID, Status,
            Queue_Name, Siebel_Error_Message, Source, Siebel_Error_Code,
            Retry_Count, [Sequence], Parent_Row_ID
        )
        VALUES
        (
            'Job Logging', @v_ID, GETDATE(), NULL, @nPID, 'Error',
            'SF_BITACORA_CFDI_1', @sMsg, 'SQL SERVER', @sErrorCode,
            NULL, NULL, NULL
        );

        PRINT '------------------------------------';
        PRINT '**** Error en BITACORA_CFDI_OPTIMIZADO *****';
        PRINT @sMsg;

        -- THROW vuelve a enviar el error para que SQL Agent marque el job fallido.
        THROW;
    END CATCH;
END;
GO
