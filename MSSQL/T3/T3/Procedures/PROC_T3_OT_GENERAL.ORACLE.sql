/*
    Objeto      : T3.PROC_T3_OT_GENERAL
    Version     : Alineacion del coordinador con Oracle, 29/10/2026.
    Referencia  : ORA/T3/T3/Procedures/PROC_T3_OT_GENERAL.SQL.

    Este archivo ALTER instala una alternativa del MISMO procedimiento.
    El archivo PROC_T3_OT_GENERAL.sql conserva la version con controles.
    Ejecutar este archivo completo cambia la definicion, no ejecuta el SP.

    CONTRATO Y REGLAS DE ORACLE
    Sin parametros, OUTPUT ni SELECT de negocio. Aparta el caso heredado
    MX10/BAT030325CE9/material y llama WA_ERR_INVOICE_PAYMETHOD(4).
    Recorre el mismo JOIN/GROUP BY de pendientes de cuatro dias, sin ORDER BY.
    No deduplica Factura ni filtra estados de CFDI_DOCUMENTOS.
    Con ABS(total-total_detalle)<0.10 llama PROC_V40_GENERAR_OTROS y marca
    todas las cabeceras de esa Factura, aunque el hijo registre un error y
    retorne normalmente. No consulta salidas ni errores para decidirlo.

    ADAPTACION TECNICA
    NVL -> ISNULL; SYSDATE -> GETDATE; FOR de cursor -> OPEN/FETCH/WHILE.
    Los importes conservan siete decimales del DDL MSSQL, sin redondearlos
    a dos en el FETCH. SUM de los dos valores con signo calcula la diferencia
    sin la reduccion de escala que causa restar dos DECIMAL(38,7) en T-SQL.
    Se reproduce el limite de sFACTURA VARCHAR2(12): T-SQL normalmente
    truncaria al asignar; aqui se propaga un error si excede ese limite.
    TRY/CATCH solo limpia el cursor y relanza errores recibidos, sin log,
    rollback ni sustitucion del error por uno propio del coordinador.

    TRANSACCIONES Y ALCANCE
    Oracle contiene COMMIT despues del apartado y al final. Este archivo
    usa el modo autocommit de SQL Server sin agregar transacciones propias
    ni confirmar transacciones externas. Para el uso normal sin transaccion
    externa, el apartado y marcado persisten al terminar cada sentencia.
    No es una equivalencia transaccional integral del flujo Oracle: los
    COMMIT/ROLLBACK de los hijos dependen de sus versiones MSSQL actuales.
    Ver Analisis/PROC_T3_OT_GENERAL.ORACLE.md. No modifica los procedimientos hijos
    ni revierte la correccion numerica de PROC_V40_GENERAR_OTROS.
*/
USE [T3QA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [T3].[PROC_T3_OT_GENERAL]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sFACTURA varchar(12), @sPROCESAR varchar(12);
    DECLARE @REN_FACTURA varchar(50),
            @REN_FECHA_FACTURA datetime2(0),
            @REN_FECHA_CANCELACION datetime2(0),
            @REN_CLIENTE_SAP varchar(50),
            @REN_CLASE_FACTURA varchar(10),
            @REN_TOTAL decimal(38,7),
            @REN_TOTAL_DETALLE decimal(38,7),
            @Diferencia decimal(38,7);

    -- El cursor conserva las siete columnas del cursor Oracle. STATIC toma
    -- la fotografia al OPEN; el JOIN/GROUP BY puede repetir una Factura.
    DECLARE PREVENTAS CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
        SELECT PG.FACTURA, PG.FECHA_FACTURA, PG.FECHA_CANCELACION,
               PG.CLIENTE_SAP, PG.CLASE_FACTURA,
               ISNULL(PG.VALOR_SUBT,0)+ISNULL(PG.VALOR_IVA,0) AS TOTAL,
               SUM(ISNULL(PD.VALOR_SUBT,0)+ISNULL(PD.VALOR_IVA,0)) AS TOTAL_DETALLE
        FROM T3.OTROS_GENERAL PG
        INNER JOIN T3.OTROS_DETALLE PD ON PG.FACTURA=PD.FACTURA
        WHERE PG.FECHA_TRN>GETDATE()-4
          AND PG.FECHA_PROC_BATMD IS NULL
        GROUP BY PG.FACTURA, PG.FECHA_FACTURA, PG.FECHA_CANCELACION,
                 PG.CLIENTE_SAP, PG.CLASE_FACTURA,
                 ISNULL(PG.VALOR_SUBT,0)+ISNULL(PG.VALOR_IVA,0);

    BEGIN TRY
        -- 1. Mismo apartado que Oracle. La fecha es una marca de exclusion.
        UPDATE OG SET Fecha_Proc_BATMD=CONVERT(datetime2(0),'29991231',112)
        FROM T3.OTROS_GENERAL OG
        WHERE OG.Fecha_Trn>GETDATE()-4
          AND OG.Fecha_Proc_BATMD IS NULL
          AND OG.Factura IN (
              SELECT DISTINCT S.Factura
              FROM T3.OTROS_GENERAL S
              INNER JOIN T3.OTROS_DETALLE D ON S.Factura=D.Factura
              INNER JOIN T3.Material M ON D.Material=M.Material
              WHERE S.Fecha_Trn>GETDATE()-30
                AND S.Sociedad='MX10'
                AND S.RFC='BAT030325CE9');
        -- Punto de COMMIT Oracle: persistencia por autocommit en SQL Server.

        -- 2. El helper aplica su propia ventana sobre Fecha_Factura.
        EXEC T3.WA_ERR_INVOICE_PAYMETHOD 4;

        -- 3. Abrir despues del apartado y helper, como el FOR Oracle.
        OPEN PREVENTAS;
        FETCH NEXT FROM PREVENTAS INTO @REN_FACTURA,@REN_FECHA_FACTURA,
            @REN_FECHA_CANCELACION,@REN_CLIENTE_SAP,@REN_CLASE_FACTURA,
            @REN_TOTAL,@REN_TOTAL_DETALLE;

        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @sPROCESAR='SI';
            -- Oracle rechaza la asignacion si la factura excede 12 caracteres.
            -- El sufijo permite contar tambien espacios finales en T-SQL.
            IF LEN(@REN_FACTURA+'#')-1>12
                THROW 56502,'sFACTURA excede VARCHAR2(12), como en el origen Oracle.',1;
            SET @sFACTURA=@REN_FACTURA;

            -- Mantener los siete decimales durante la diferencia. El signo
            -- unario y SUM no reducen la escala como una resta DECIMAL(38,7).
            SELECT @Diferencia=SUM(V.Importe)
            FROM (VALUES(@REN_TOTAL),(-@REN_TOTAL_DETALLE)) V(Importe);

            -- 4. Misma tolerancia estricta que Oracle: 0.10 exacto no pasa.
            IF ABS(@Diferencia)<0.10 AND @sPROCESAR='SI'
            BEGIN
                EXEC T3.PROC_V40_GENERAR_OTROS @REN_FACTURA;

                -- 5. El retorno normal del hijo permite marcar, incluso si
                -- capturo y registro un error. No se validan sus salidas.
                UPDATE T3.OTROS_GENERAL SET Fecha_Proc_BATMD=GETDATE()
                WHERE Factura=@REN_FACTURA;
            END;

            FETCH NEXT FROM PREVENTAS INTO @REN_FACTURA,@REN_FECHA_FACTURA,
                @REN_FECHA_CANCELACION,@REN_CLIENTE_SAP,@REN_CLASE_FACTURA,
                @REN_TOTAL,@REN_TOTAL_DETALLE;
        END;

        CLOSE PREVENTAS;
        DEALLOCATE PREVENTAS;
        -- Punto de COMMIT final Oracle: cada UPDATE ya persiste en autocommit.
    END TRY
    BEGIN CATCH
        -- Oracle no tiene EXCEPTION en este coordinador: el error que reciba
        -- se propaga. Esta limpieza de recursos no registra ni absorbe errores.
        IF CURSOR_STATUS('local','PREVENTAS')>=0 CLOSE PREVENTAS;
        IF CURSOR_STATUS('local','PREVENTAS')>=-1 DEALLOCATE PREVENTAS;
        THROW;
    END CATCH;
END;
GO
