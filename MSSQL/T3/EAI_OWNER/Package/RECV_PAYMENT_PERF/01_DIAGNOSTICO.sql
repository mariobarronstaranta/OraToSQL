-- Solo lectura. No ejecuta pagos ni modifica objetos permanentes.
-- Ejecutar despues de un lote normal reciente, en AZCRNMXNEVTD06 / T3QA.
USE [T3QA];
SET NOCOUNT ON;
IF DB_NAME() <> N'T3QA' THROW 51960, 'Seleccionar T3QA.', 1;
SELECT N'Entorno' Seccion, @@SERVERNAME Servidor, DB_NAME() BaseActual,
       SYSDATETIME() Captura, ORIGINAL_LOGIN() LoginConsulta,
       compatibility_level, collation_name
FROM sys.databases WHERE database_id = DB_ID();

DECLARE @Objetos TABLE (object_id int PRIMARY KEY, nivel int NOT NULL);
DECLARE @Raiz int = OBJECT_ID(N'EAI_OWNER.RECV_PAYMENT');
IF @Raiz IS NULL THROW 51961, 'RECV_PAYMENT no existe o no es visible.', 1;
INSERT @Objetos VALUES (@Raiz, 0);
DECLARE @Nivel int = 0, @Agregados int = 1;
-- Dependencias locales estaticas y triggers de las tablas referenciadas.
WHILE @Nivel < 16 AND @Agregados > 0
BEGIN
    INSERT @Objetos (object_id, nivel)
    SELECT D.referenced_id, @Nivel + 1
    FROM sys.sql_expression_dependencies D
    JOIN @Objetos O ON O.object_id = D.referencing_id AND O.nivel = @Nivel
    WHERE D.referenced_id IS NOT NULL
      AND D.referenced_database_name IS NULL
      AND NOT EXISTS (SELECT 1 FROM @Objetos X WHERE X.object_id = D.referenced_id)
    GROUP BY D.referenced_id;
    SET @Agregados = @@ROWCOUNT;
    INSERT @Objetos (object_id, nivel)
    SELECT T.object_id, @Nivel + 1
    FROM sys.triggers T JOIN @Objetos O ON O.object_id = T.parent_id
    WHERE T.is_disabled = 0
      AND NOT EXISTS (SELECT 1 FROM @Objetos X WHERE X.object_id = T.object_id);
    SET @Agregados += @@ROWCOUNT;
    SET @Nivel += 1;
END;

SELECT N'Dependencias' Seccion, O.nivel,
       QUOTENAME(SCHEMA_NAME(S.schema_id))+N'.'+QUOTENAME(S.name) Objeto,
       S.type_desc, S.modify_date,
       CONVERT(varchar(64), HASHBYTES('SHA2_256', M.definition), 2) HashDefinicion
FROM @Objetos O JOIN sys.objects S ON S.object_id = O.object_id
LEFT JOIN sys.sql_modules M ON M.object_id = O.object_id
ORDER BY O.nivel, Objeto;

SELECT N'Dependencias sin resolver o externas' Seccion,
       OBJECT_SCHEMA_NAME(D.referencing_id)+N'.'+OBJECT_NAME(D.referencing_id) Llamador,
       D.referenced_server_name, D.referenced_database_name,
       D.referenced_schema_name, D.referenced_entity_name
FROM sys.sql_expression_dependencies D JOIN @Objetos O ON O.object_id = D.referencing_id
WHERE D.referenced_id IS NULL OR D.referenced_database_name IS NOT NULL;

SELECT N'Triggers' Seccion,
       OBJECT_SCHEMA_NAME(T.parent_id)+N'.'+OBJECT_NAME(T.parent_id) Tabla,
       OBJECT_SCHEMA_NAME(T.object_id)+N'.'+T.name TriggerNombre, T.is_disabled
FROM sys.triggers T JOIN @Objetos O ON O.object_id = T.parent_id;

-- Foco inicial: tablas de recepcion, catalogo y bitacora.
DECLARE @Tablas TABLE (object_id int PRIMARY KEY);
INSERT @Tablas SELECT object_id FROM sys.tables
WHERE object_id IN
 (OBJECT_ID(N'EAI_OWNER.MX_RECEIVE_MESSAGE_LOG'),
  OBJECT_ID(N'EAI_OWNER.TMP_ACCOUNT_HEADER'), OBJECT_ID(N'EAI_OWNER.TMP_ACCOUNT_DETAIL'),
  OBJECT_ID(N'EAI_OWNER.MX_HASHTABLE'), OBJECT_ID(N'EAI_OWNER.MX_COMPONENTS'),
  OBJECT_ID(N'T3.RF_PROCESOS_LOG'));

SELECT N'Tipos' Seccion, OBJECT_SCHEMA_NAME(C.object_id)+N'.'+OBJECT_NAME(C.object_id) Tabla,
       C.name Columna, TYPE_NAME(C.user_type_id) Tipo, C.max_length,
       C.precision, C.scale, C.collation_name, C.is_nullable
FROM sys.columns C JOIN @Tablas T ON T.object_id = C.object_id
ORDER BY Tabla, C.column_id;

SELECT N'Indices' Seccion, OBJECT_SCHEMA_NAME(I.object_id)+N'.'+OBJECT_NAME(I.object_id) Tabla,
       I.name Indice, I.type_desc, I.is_unique, I.is_disabled, I.filter_definition,
       C.name Columna, IC.key_ordinal, IC.is_included_column, IC.is_descending_key
FROM sys.indexes I JOIN @Tablas T ON T.object_id = I.object_id
LEFT JOIN sys.index_columns IC ON IC.object_id = I.object_id AND IC.index_id = I.index_id
LEFT JOIN sys.columns C ON C.object_id = IC.object_id AND C.column_id = IC.column_id
ORDER BY Tabla, I.index_id, IC.index_column_id;

SELECT N'Filas aproximadas' Seccion,
       OBJECT_SCHEMA_NAME(P.object_id)+N'.'+OBJECT_NAME(P.object_id) Tabla,
       SUM(P.rows) Filas
FROM sys.partitions P JOIN @Tablas T ON T.object_id = P.object_id
WHERE P.index_id IN (0,1) GROUP BY P.object_id;

BEGIN TRY
    -- Hasta 8 sentencias por modulo: evita que un solo subproceso monopolice el reporte.
    ;WITH Q AS
    (
        SELECT T.objectid,
               S.creation_time, S.last_execution_time, S.execution_count,
               S.total_elapsed_time / 1000.0 TiempoTotal_ms,
               S.total_elapsed_time / 1000.0 / NULLIF(S.execution_count,0) Media_ms,
               S.total_worker_time / 1000.0 / NULLIF(S.execution_count,0) CPU_ms,
               S.total_logical_reads * 1.0 / NULLIF(S.execution_count,0) LecturasPorEjecucion,
               S.total_logical_writes * 1.0 / NULLIF(S.execution_count,0) EscriturasPorEjecucion,
               SUBSTRING(T.text, S.statement_start_offset/2+1,
                 (CASE S.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
                   ELSE S.statement_end_offset END-S.statement_start_offset)/2+1) Sentencia,
               ROW_NUMBER() OVER(PARTITION BY T.objectid ORDER BY S.total_elapsed_time DESC) Posicion
        FROM sys.dm_exec_query_stats S
        CROSS APPLY sys.dm_exec_sql_text(S.sql_handle) T
        JOIN @Objetos O ON O.object_id = T.objectid
        WHERE T.dbid = DB_ID()
    )
    SELECT N'Cache por sentencia' Seccion,
           OBJECT_SCHEMA_NAME(objectid)+N'.'+OBJECT_NAME(objectid) Objeto,
           creation_time, last_execution_time, execution_count,
           TiempoTotal_ms, Media_ms, CPU_ms, LecturasPorEjecucion,
           EscriturasPorEjecucion, Sentencia
    FROM Q WHERE Posicion <= 8 ORDER BY Objeto, Posicion;
END TRY
BEGIN CATCH
    SELECT N'Cache no disponible' Seccion, ERROR_NUMBER() ErrorNumero, ERROR_MESSAGE() Mensaje;
END CATCH;

SELECT N'Nota' Seccion,
 N'Metricas acumuladas desde la compilacion, no tiempos exclusivos del ultimo lote. '
 + N'Las llamadas anidadas pueden solapar tiempos; no sumar sus promedios. '
 + N'El SQL dinamico no siempre aparece en dependencias. No se ejecutaron pagos.' Mensaje;
