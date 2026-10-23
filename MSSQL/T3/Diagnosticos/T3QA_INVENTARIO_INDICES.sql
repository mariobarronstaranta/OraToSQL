/* Inventario de indices de T3QA. SQL Server 2022 / compatibilidad 160.
   Ejecutar TODO en una misma sesion de SSMS, seleccionando T3QA.
   Solo lectura de la base; crea tablas temporales locales en tempdb.
   No ejecuta procesos, no crea/reconstruye/elimina indices de negocio,
   no actualiza estadisticas ni calcula fragmentacion recorriendo paginas.

   Fechas: sys.indexes NO contiene create_date ni modify_date del indice.
   Las fechas de objeto, restriccion y estadistica se identifican por separado.
   El trace, si esta disponible, solo proporciona eventos historicos retenidos.
   No se inventa una fecha de indice a partir de STATS_DATE o sys.objects.

   Filtrar opcionalmente por esquema/tabla. NULL = todos los objetos visibles.
   Incluye todos los esquemas de usuario, tablas y vistas con indices, y heaps.
   Para exportar, conservar cada conjunto de resultados con su encabezado.
*/
SET NOCOUNT ON;
DECLARE @BaseEsperada sysname = N'T3QA';
DECLARE @Esquema sysname = NULL; -- Ejemplo: N'T3'
DECLARE @Objeto sysname = NULL;  -- Ejemplo: N'CFDI_DOCUMENTO_PASO'
DECLARE @LeerTrace bit = 1;     -- 0 omite lectura opcional de trace.

IF DB_NAME() <> @BaseEsperada
    THROW 50000, 'Seleccionar T3QA antes de ejecutar el inventario.', 1;

DROP TABLE IF EXISTS #INV_Objetos;
DROP TABLE IF EXISTS #INV_Uso;
DROP TABLE IF EXISTS #INV_Tamano;
DROP TABLE IF EXISTS #INV_Estadisticas;
DROP TABLE IF EXISTS #INV_Avisos;
CREATE TABLE #INV_Avisos
 (Seccion nvarchar(60) COLLATE DATABASE_DEFAULT,
  Mensaje nvarchar(4000) COLLATE DATABASE_DEFAULT);

SELECT O.object_id,O.schema_id,O.name,O.type_desc,O.create_date,O.modify_date,
       ISNULL(T.is_memory_optimized,0) AS is_memory_optimized
INTO #INV_Objetos
FROM sys.objects O
LEFT JOIN sys.tables T ON T.object_id=O.object_id
WHERE O.type IN ('U','V') AND O.is_ms_shipped=0
  AND (@Esquema IS NULL OR SCHEMA_NAME(O.schema_id) COLLATE DATABASE_DEFAULT
                            = @Esquema COLLATE DATABASE_DEFAULT)
  AND (@Objeto IS NULL OR O.name COLLATE DATABASE_DEFAULT
                           = @Objeto COLLATE DATABASE_DEFAULT)
  AND EXISTS (SELECT 1 FROM sys.indexes I WHERE I.object_id=O.object_id);

-- 01: contexto y alcance de visibilidad.
SELECT N'01_CONTEXTO' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,D.collation_name AS CollationBase,
       D.compatibility_level,SERVERPROPERTY('ProductVersion') AS VersionSQL,
       SERVERPROPERTY('Edition') AS Edicion,
       HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION') AS PuedeVerDefinicionesBase,
       @Esquema AS FiltroEsquema,@Objeto AS FiltroObjeto,
       (SELECT COUNT(*) FROM #INV_Objetos) AS ObjetosVisibles,
       CAST(NULL AS datetime) AS FechaCreacionIndiceNoDisponible,
       N'El catalogo no guarda fechas individuales del indice; ver fechas de objeto, restriccion, estadistica y eventos por separado.' AS NotaFechas
FROM sys.databases D WHERE D.database_id=DB_ID();

CREATE TABLE #INV_Uso
 (object_id int,index_id int,user_seeks bigint,user_scans bigint,
  user_lookups bigint,user_updates bigint,last_user_seek datetime,
  last_user_scan datetime,last_user_lookup datetime,last_user_update datetime);
BEGIN TRY
 INSERT #INV_Uso
 SELECT U.object_id,U.index_id,U.user_seeks,U.user_scans,U.user_lookups,
        U.user_updates,U.last_user_seek,U.last_user_scan,U.last_user_lookup,U.last_user_update
 FROM sys.dm_db_index_usage_stats U JOIN #INV_Objetos O ON O.object_id=U.object_id
 WHERE U.database_id=DB_ID();
END TRY
BEGIN CATCH
 INSERT #INV_Avisos VALUES(N'Uso',ERROR_MESSAGE());
END CATCH;

CREATE TABLE #INV_Tamano
 (object_id int,index_id int,Filas bigint,PaginasReservadas bigint,PaginasUsadas bigint);
BEGIN TRY
 INSERT #INV_Tamano
 SELECT P.object_id,P.index_id,SUM(P.row_count),SUM(P.reserved_page_count),SUM(P.used_page_count)
 FROM sys.dm_db_partition_stats P JOIN #INV_Objetos O ON O.object_id=P.object_id
 GROUP BY P.object_id,P.index_id;
END TRY
BEGIN CATCH
 INSERT #INV_Avisos VALUES(N'Tamano',ERROR_MESSAGE());
 -- Filas aproximadas disponibles en catalogo; espacio queda desconocido.
 INSERT #INV_Tamano
 SELECT P.object_id,P.index_id,SUM(P.rows),NULL,NULL
 FROM sys.partitions P JOIN #INV_Objetos O ON O.object_id=P.object_id
 GROUP BY P.object_id,P.index_id;
END CATCH;

CREATE TABLE #INV_Estadisticas
 (object_id int,stats_id int,last_updated datetime2,Filas bigint,
  FilasMuestreadas bigint,Modificaciones bigint);
BEGIN TRY
 INSERT #INV_Estadisticas
 SELECT S.object_id,S.stats_id,P.last_updated,P.rows,P.rows_sampled,P.modification_counter
 FROM sys.stats S JOIN #INV_Objetos O ON O.object_id=S.object_id
 OUTER APPLY sys.dm_db_stats_properties(S.object_id,S.stats_id) P;
END TRY
BEGIN CATCH
 INSERT #INV_Avisos VALUES(N'Estadisticas',ERROR_MESSAGE());
END CATCH;

-- 02: una fila por indice, incluido el heap (index_id=0).
-- STRING_AGG usa nvarchar(max) para no limitar listas largas a 4,000 caracteres.
-- Las claves clustered implicitas de otros indices no se agregan artificialmente.
SELECT N'02_INVENTARIO' AS Seccion,SCHEMA_NAME(O.schema_id) AS Esquema,
       O.name AS TablaOVista,O.type_desc AS TipoObjeto,O.is_memory_optimized,
       I.object_id,I.index_id,I.name AS Indice,I.type_desc AS TipoIndice,
       K.Claves,INC.ColumnasIncluidas,
       I.is_unique,I.is_primary_key,I.is_unique_constraint,
       I.is_disabled,I.is_hypothetical,I.has_filter,I.filter_definition,
       I.fill_factor,I.is_padded,I.ignore_dup_key,
       I.allow_row_locks,I.allow_page_locks,I.optimize_for_sequential_key,
       DS.name AS EspacioDatos,DS.type_desc AS TipoEspacioDatos,
       Z.Filas AS FilasAproximadasIndice,
       Z.PaginasReservadas*8.0/1024 AS MBReservadosIndice,
       Z.PaginasUsadas*8.0/1024 AS MBUsadosIndice,
       O.create_date AS FechaCreacionTablaOVista,
       O.modify_date AS FechaModificacionTablaOVista,
       CAST(NULL AS datetime) AS FechaCreacionIndiceNoDisponible,
       CAST(NULL AS datetime) AS FechaModificacionIndiceNoDisponible,
       KC.name AS Restriccion,KC.create_date AS FechaCreacionRestriccion,
       KC.modify_date AS FechaModificacionRestriccion,
       E.last_updated AS FechaActualizacionEstadistica,
       E.Filas AS FilasEstadistica,E.FilasMuestreadas,E.Modificaciones,
       ST.no_recompute AS EstadisticaNoRecompute,
       U.user_seeks,U.user_scans,U.user_lookups,U.user_updates,
       U.last_user_seek,U.last_user_scan,U.last_user_lookup,U.last_user_update
FROM #INV_Objetos O JOIN sys.indexes I ON I.object_id=O.object_id
LEFT JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
LEFT JOIN sys.key_constraints KC ON KC.parent_object_id=I.object_id AND KC.unique_index_id=I.index_id
LEFT JOIN sys.stats ST ON ST.object_id=I.object_id AND ST.stats_id=I.index_id
LEFT JOIN #INV_Estadisticas E ON E.object_id=ST.object_id AND E.stats_id=ST.stats_id
LEFT JOIN #INV_Tamano Z ON Z.object_id=I.object_id AND Z.index_id=I.index_id
LEFT JOIN #INV_Uso U ON U.object_id=I.object_id AND U.index_id=I.index_id
OUTER APPLY
 (SELECT STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(C.name)
          + CASE WHEN IC.is_descending_key=1 THEN N' DESC' ELSE N' ASC' END),N', ')
          WITHIN GROUP (ORDER BY IC.key_ordinal) AS Claves
  FROM sys.index_columns IC JOIN sys.columns C
    ON C.object_id=IC.object_id AND C.column_id=IC.column_id
  WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0) K
OUTER APPLY
 (SELECT STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(C.name)),N', ')
          WITHIN GROUP (ORDER BY IC.index_column_id) AS ColumnasIncluidas
  FROM sys.index_columns IC JOIN sys.columns C
    ON C.object_id=IC.object_id AND C.column_id=IC.column_id
  WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.is_included_column=1) INC
ORDER BY SCHEMA_NAME(O.schema_id),O.name,I.index_id;

-- 03: detalle campo por campo, tambien para XML, spatial y columnstore.
-- En esos tipos key_ordinal=0 no significa ausencia de columnas participantes.
SELECT N'03_COLUMNAS' AS Seccion,SCHEMA_NAME(O.schema_id) AS Esquema,
       O.name AS TablaOVista,I.name AS Indice,I.type_desc AS TipoIndice,
       IC.index_column_id,IC.key_ordinal,IC.is_descending_key,
       IC.is_included_column,IC.partition_ordinal,IC.column_store_order_ordinal,
       C.name AS Campo,TY.name AS TipoDato,C.max_length AS LongitudBytes,
       C.precision,C.scale,C.is_nullable,C.collation_name,
       CC.definition AS ExpresionCalculada,CC.is_persisted,
       CASE WHEN IC.column_id=0 THEN N'RID interno'
            WHEN IC.is_included_column=1 THEN N'INCLUDE / columna columnstore'
            WHEN IC.key_ordinal>0 THEN N'CLAVE'
            WHEN IC.partition_ordinal>0 THEN N'PARTICION'
            ELSE N'COLUMNA ESPECIAL' END AS Participacion
FROM #INV_Objetos O JOIN sys.indexes I ON I.object_id=O.object_id
JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
LEFT JOIN sys.types TY ON TY.user_type_id=C.user_type_id
LEFT JOIN sys.computed_columns CC ON CC.object_id=C.object_id AND CC.column_id=C.column_id
ORDER BY SCHEMA_NAME(O.schema_id),O.name,I.index_id,IC.index_column_id;

-- 04: compresion y filas por particion. No sumar filas de TODOS los indices
-- para calcular filas de una tabla: cada indice representa de nuevo sus datos.
SELECT N'04_PARTICIONES' AS Seccion,SCHEMA_NAME(O.schema_id) AS Esquema,
       O.name AS TablaOVista,I.name AS Indice,I.type_desc,
       P.partition_number,P.rows AS FilasAproximadasParticion,
       P.data_compression_desc,DS.name AS EspacioDatos,
       PS.name AS EsquemaParticion,PF.name AS FuncionParticion,
       FG.name AS FilegroupParticion
FROM #INV_Objetos O JOIN sys.indexes I ON I.object_id=O.object_id
JOIN sys.partitions P ON P.object_id=I.object_id AND P.index_id=I.index_id
LEFT JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
LEFT JOIN sys.partition_schemes PS ON PS.data_space_id=I.data_space_id
LEFT JOIN sys.partition_functions PF ON PF.function_id=PS.function_id
LEFT JOIN sys.destination_data_spaces DDS ON DDS.partition_scheme_id=PS.data_space_id
                                         AND DDS.destination_id=P.partition_number
LEFT JOIN sys.filegroups FG ON FG.data_space_id=COALESCE(DDS.data_space_id,I.data_space_id)
ORDER BY SCHEMA_NAME(O.schema_id),O.name,I.index_id,P.partition_number;

-- 05: fechas de todas las estadisticas, incluidas las automaticas sin indice.
SELECT N'05_ESTADISTICAS' AS Seccion,SCHEMA_NAME(O.schema_id) AS Esquema,
       O.name AS TablaOVista,S.name AS Estadistica,I.name AS IndiceAsociado,
       S.auto_created,S.user_created,S.no_recompute,S.is_incremental,
       S.has_filter,S.filter_definition,E.last_updated AS FechaActualizacionEstadistica,
       E.Filas,E.FilasMuestreadas,E.Modificaciones
FROM #INV_Objetos O JOIN sys.stats S ON S.object_id=O.object_id
LEFT JOIN sys.indexes I ON I.object_id=S.object_id AND I.index_id=S.stats_id
LEFT JOIN #INV_Estadisticas E ON E.object_id=S.object_id AND E.stats_id=S.stats_id
ORDER BY SCHEMA_NAME(O.schema_id),O.name,S.stats_id;

-- 06: contexto de uso. Los contadores son globales, no de un procedimiento.
BEGIN TRY
 SELECT N'06_INICIO_INSTANCIA' AS Seccion,sqlserver_start_time AS InicioInstancia
 FROM sys.dm_os_sys_info;
END TRY
BEGIN CATCH
 INSERT #INV_Avisos VALUES(N'Inicio instancia',ERROR_MESSAGE());
END CATCH;

-- 07: evidencia opcional de eventos de indice del default trace.
-- No es auditoria completa. Los archivos rotan, un nombre puede reutilizarse,
-- y un evento puede corresponder a un indice que ya no existe.
-- Se muestran los identificadores tal como los registra el trace, sin inferir
-- que ObjectID/ObjectID2 identifican un indice actual. No asociar solo por nombre.
-- No se aplican los filtros esquema/objeto a estos eventos: son de toda T3QA.
IF @LeerTrace=1
BEGIN
 BEGIN TRY
  DECLARE @TracePath nvarchar(260);
  SELECT @TracePath=path FROM sys.traces WHERE is_default=1;
  IF @TracePath IS NULL
   INSERT #INV_Avisos VALUES(N'Trace',N'No hay default trace visible/activo. No se recuperaron fechas de eventos de indice.');
  ELSE
  BEGIN
   SELECT N'07_TRACE_ORIGEN' AS Seccion,@TracePath AS ArchivoInicialLeido,
          N'Se leen el archivo indicado y rollover posteriores disponibles. No garantiza toda la retencion ni el historial completo.' AS Alcance;
   SELECT N'07_EVENTOS_INDICE' AS Seccion,T.StartTime AS FechaEventoRegistrada,
          E.name AS Evento,T.EventSubClass,
          CASE T.EventSubClass WHEN 0 THEN N'Begin' WHEN 1 THEN N'Commit'
               WHEN 2 THEN N'Rollback' ELSE N'Ver EventSubClass' END AS FaseEvento,
          T.DatabaseName,T.ObjectName AS NombreObjetoRegistrado,
          T.ObjectID,T.ObjectID2,T.ObjectType,T.LoginName,T.HostName,
          T.ApplicationName,T.TextData
   FROM sys.fn_trace_gettable(@TracePath,DEFAULT) T
   LEFT JOIN sys.trace_events E ON E.trace_event_id=T.EventClass
   WHERE T.DatabaseID=DB_ID() AND T.ObjectType=22601
     AND T.EventClass IN (46,47,164) -- Created, Deleted, Altered.
   ORDER BY T.StartTime DESC;
  END;
 END TRY
 BEGIN CATCH
  INSERT #INV_Avisos VALUES(N'Trace',ERROR_MESSAGE());
 END CATCH;
END;

INSERT #INV_Avisos VALUES
 (N'Fechas',N'NULL en fechas de indice significa no disponible. modify_date es de la tabla/vista y puede cambiar por DDL de sus indices. La fecha de estadistica no es fecha de creacion/modificacion del indice.'),
 (N'Visibilidad',N'Para inventario completo se requiere visibilidad de metadatos de toda la base. Falta de permisos puede ocultar objetos, filtros y propiedades sin generar error.'),
 (N'Uso',N'NULL significa sin registro visible/no disponible; cero significa contador observado en cero. No eliminar indices por este dato aislado. Reinicios, detach u otras operaciones pueden reiniciar contadores.'),
 (N'Tipos especiales',N'Memoria optimizada, XML, spatial y columnstore pueden requerir catalogos/DMV propios para caracteristicas y uso adicionales. El espacio mostrado procede de particiones de disco, no es consumo de memoria optimizada.'),
 (N'Impacto',N'Tablas/campos identifica donde se define cada indice. No demuestra que procedimientos o consultas lo usen: para ello se necesitan planes/Query Store.');
SELECT N'08_AVISOS' AS Resultado,Seccion,Mensaje FROM #INV_Avisos;

DROP TABLE #INV_Estadisticas;
DROP TABLE #INV_Tamano;
DROP TABLE #INV_Uso;
DROP TABLE #INV_Objetos;
DROP TABLE #INV_Avisos;
