/* Diagnostico de solo lectura para T3.PROC_CFDI_PROCESAR_DOCTOS.
   Ejecutar en la misma base del procedimiento (por ejemplo T3QA).
   No ejecuta el proceso, no crea indices, no cuenta tablas completas y no
   actualiza estadisticas. Solo escribe una variable de tabla de esta sesion.
   Para revisar una ejecucion activa, asignar su sesion a @SPID.
   Las DMV pueden requerir VIEW DATABASE STATE / VIEW SERVER STATE o los
   permisos equivalentes de rendimiento, segun la version de SQL Server.
   Conservar todos los resultados junto con fecha, servidor y base.
*/
SET NOCOUNT ON;
DECLARE @SPID int = NULL;
-- Unificar la collation de los nombres de la lista y del catalogo.
-- DATABASE_DEFAULT evita depender de la collation de instancia o catalogo.
DECLARE @Tablas TABLE (Nombre sysname COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT INTO @Tablas (Nombre) VALUES
 ('FACTURA_GENERAL'),('FACTURA_DETALLE'),('CLIENTE'),('TIPO_DOCUMENTO'),
 ('CFDI_DOCUMENTO_PASO'),('CFDI_HISTORIA_DOCTO_PAC'),('CFDI_AGRUPADO'),
 ('CFDI_AGRUPADO_DETALLE'),('CFDI_GEN_AGRUPADO'),('CFDI_GEN_AGRUPADO_FECHA'),
 ('CFDI_CFG_AGRUPADO'),('PREVENTA_GENERAL'),('PREVENTA_DETALLE'),
 ('REGISTRO_FISCAL'),('RF_PROCESOS_LOG');

SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura, D.compatibility_level,
       SERVERPROPERTY('ProductVersion') AS VersionSQL,
       SERVERPROPERTY('Edition') AS Edicion,
       OBJECT_ID(N'T3.PROC_CFDI_PROCESAR_DOCTOS', N'P') AS IdProcedimiento
FROM sys.databases D WHERE D.database_id = DB_ID();

-- Nombres ausentes: pueden indicar otra base, diferencias de esquema/nombre
-- o falta de visibilidad de metadatos. No interpretar como ausencia de indices.
SELECT N.Nombre AS TablaNoVisible
FROM @Tablas N
WHERE NOT EXISTS
 (SELECT 1 FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
  WHERE S.name=N'T3' AND UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre);

-- Filas aproximadas y espacio de la tabla base (heap o clustered).
-- reserved_page_count no representa el espacio de todos los indices de la tabla.
BEGIN TRY
 SELECT T.name AS Tabla, SUM(P.row_count) AS FilasAproximadas,
        SUM(P.reserved_page_count)*8.0/1024 AS MBReservadosTablaBase
 FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
 JOIN @Tablas N ON UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre
 JOIN sys.dm_db_partition_stats P ON P.object_id=T.object_id AND P.index_id IN (0,1)
 WHERE S.name=N'T3'
 GROUP BY T.name ORDER BY FilasAproximadas DESC;
END TRY
BEGIN CATCH
 SELECT N'Tamanos' AS SeccionNoDisponible, ERROR_MESSAGE() AS Motivo;
END CATCH;

-- Una fila por columna: incluye heaps (sin columna) e indices deshabilitados.
-- Comparar orden de claves, INCLUDE, filtros y estado; el nombre no basta.
SELECT T.name AS Tabla, I.name AS Indice, I.index_id, I.type_desc,
       I.is_disabled, I.is_hypothetical, I.is_unique, I.is_primary_key,
       I.is_unique_constraint, I.has_filter, I.filter_definition,
       IC.key_ordinal, IC.is_descending_key, IC.is_included_column,
       C.name AS Columna, TY.name AS TipoDato, C.max_length,
       CC.definition AS ExpresionCalculada, CC.is_persisted
FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
JOIN @Tablas N ON UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre
JOIN sys.indexes I ON I.object_id=T.object_id
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
LEFT JOIN sys.types TY ON TY.user_type_id=C.user_type_id
LEFT JOIN sys.computed_columns CC ON CC.object_id=C.object_id AND CC.column_id=C.column_id
WHERE S.name=N'T3'
ORDER BY T.name,I.index_id,IC.is_included_column,IC.key_ordinal,IC.index_column_id;

-- Columnas calculadas, aunque aun no tengan indice. Permite detectar una fecha
-- DATE derivada de BATMD que pudiera servir para el filtro CAST actual.
SELECT T.name AS Tabla, C.name AS Columna, C.definition, C.is_persisted
FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
JOIN @Tablas N ON UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre
JOIN sys.computed_columns C ON C.object_id=T.object_id
WHERE S.name=N'T3' ORDER BY T.name,C.column_id;

-- Uso acumulado de todos los procesos; no atribuible solo a este procedimiento.
-- Ausencia de filas/uso NO demuestra que un indice sea prescindible: los
-- contadores pueden reiniciarse y dependen de la ventana observada.
BEGIN TRY
 SELECT sqlserver_start_time AS InicioInstancia FROM sys.dm_os_sys_info;
 SELECT T.name AS Tabla,I.name AS Indice,I.is_disabled,
        U.user_seeks,U.user_scans,U.user_lookups,U.user_updates,
        U.last_user_seek,U.last_user_scan,U.last_user_lookup,U.last_user_update
 FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
 JOIN @Tablas N ON UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre
 JOIN sys.indexes I ON I.object_id=T.object_id AND I.index_id>0
 LEFT JOIN sys.dm_db_index_usage_stats U ON U.database_id=DB_ID()
       AND U.object_id=I.object_id AND U.index_id=I.index_id
 WHERE S.name=N'T3' ORDER BY T.name,I.index_id;
END TRY
BEGIN CATCH
 SELECT N'Uso de indices' AS SeccionNoDisponible,ERROR_MESSAGE() AS Motivo;
END CATCH;

BEGIN TRY
 SELECT T.name AS Tabla,ST.name AS Estadistica,ST.auto_created,
        ST.has_filter,ST.filter_definition,P.last_updated,
        P.rows,P.rows_sampled,P.modification_counter
 FROM sys.tables T JOIN sys.schemas S ON S.schema_id=T.schema_id
 JOIN @Tablas N ON UPPER(T.name) COLLATE DATABASE_DEFAULT = N.Nombre
 JOIN sys.stats ST ON ST.object_id=T.object_id
 OUTER APPLY sys.dm_db_stats_properties(ST.object_id,ST.stats_id) P
 WHERE S.name=N'T3' ORDER BY T.name,ST.name;
END TRY
BEGIN CATCH
 SELECT N'Estadisticas' AS SeccionNoDisponible,ERROR_MESSAGE() AS Motivo;
END CATCH;

-- Solo si se especifico una sesion: lecturas y espera de la solicitud activa.
-- El plan es compilado, sin metricas reales por operador. La solicitud puede
-- estar ejecutando un procedimiento hijo y puede terminar antes de la captura.
IF @SPID IS NOT NULL
BEGIN
 BEGIN TRY
  SELECT R.session_id,R.status,R.cpu_time,R.total_elapsed_time,
         R.logical_reads,R.reads,R.writes,R.wait_type,R.wait_time,
         R.blocking_session_id,
         SUBSTRING(T.text,R.statement_start_offset/2+1,
          (CASE WHEN R.statement_end_offset=-1 THEN DATALENGTH(T.text)
                ELSE R.statement_end_offset END-R.statement_start_offset)/2+1)
          AS SentenciaActual,P.query_plan AS PlanCompilado
  FROM sys.dm_exec_requests R
  OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) T
  OUTER APPLY sys.dm_exec_query_plan(R.plan_handle) P
  WHERE R.session_id=@SPID AND R.database_id=DB_ID();
 END TRY
 BEGIN CATCH
  SELECT N'Sesion activa' AS SeccionNoDisponible,ERROR_MESSAGE() AS Motivo;
 END CATCH;
END;
