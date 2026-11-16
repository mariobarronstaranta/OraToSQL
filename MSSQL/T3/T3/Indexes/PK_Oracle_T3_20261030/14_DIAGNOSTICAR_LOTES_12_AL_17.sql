/* SOLO LECTURA de catalogos. Lotes 12-17: diagnosticar dependencias
   antes de reintentar ASIGNACION_PAGO o aplicar los siguientes lotes.
   No escanea datos, no ejecuta DDL ni elimina indices/estadisticas.
   Los objetos listados son candidatos: su presencia no prueba por si sola
   que bloqueen ALTER COLUMN. Incluye todos los indices y estadisticas para
   revisar filtros, INCLUDE, claves y opciones sin deducirlos por el nombre.
   Guardar TODOS los resultados; abrir XML final para texto sin truncamiento.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @SoloTabla sysname=NULL; -- NULL: seis tablas. Ejemplo N'ASIGNACION_PAGO'.
DECLARE @Origen table(Lote int,Tabla sysname COLLATE DATABASE_DEFAULT,
 NombrePK sysname COLLATE DATABASE_DEFAULT,Posicion int,Columna sysname COLLATE DATABASE_DEFAULT);
INSERT @Origen VALUES
(12,N'ASIGNACION_PAGO',N'ASPAGO_PK',1,N'PAGO_ID'),
(12,N'ASIGNACION_PAGO',N'ASPAGO_PK',2,N'ASIGNACION_ID'),
(12,N'ASIGNACION_PAGO',N'ASPAGO_PK',3,N'FECHA_TRN'),
(12,N'ASIGNACION_PAGO',N'ASPAGO_PK',4,N'FACTURA'),
(13,N'CLIENTE',N'CLIENTE_PK',1,N'CLIENTE_V3'),
(13,N'CLIENTE',N'CLIENTE_PK',2,N'FECHA_INI_VIG'),
(14,N'FACTURA_GENERAL',N'FACTURA_PK',1,N'FACTURA'),
(15,N'FACTURA_DETALLE',N'FACTDET_PK',1,N'FACTURA'),
(15,N'FACTURA_DETALLE',N'FACTDET_PK',2,N'NUM_LINEA'),
(16,N'REGISTRO_FISCAL',N'REGFIS_PK',1,N'FACTURA'),
(17,N'REGISTRO_FISCAL_DETALLE',N'REGFEDDET_PK',1,N'FACTURA'),
(17,N'REGISTRO_FISCAL_DETALLE',N'REGFEDDET_PK',2,N'NUM_LINEA');
IF @SoloTabla IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Origen WHERE Tabla=@SoloTabla)
 THROW 56914,'@SoloTabla no pertenece a los lotes 12-17.',1;
DECLARE @Tablas table(Lote int,Tabla sysname COLLATE DATABASE_DEFAULT,NombrePK sysname COLLATE DATABASE_DEFAULT,
 Objeto int NULL);
INSERT @Tablas SELECT Lote,Tabla,NombrePK,OBJECT_ID(QUOTENAME(N'T3')+N'.'+QUOTENAME(Tabla),N'U')
 FROM @Origen WHERE @SoloTabla IS NULL OR Tabla=@SoloTabla GROUP BY Lote,Tabla,NombrePK;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,SYSDATETIMEOFFSET() Captura,
 HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION') PuedeVerDefinicionBase;
SELECT '01_COLUMNAS_PK' Seccion,T.Lote,T.Tabla,T.NombrePK,O.Posicion,O.Columna,
 CASE WHEN T.Objeto IS NULL THEN 'TABLA_AUSENTE_O_NO_VISIBLE'
      WHEN C.column_id IS NULL THEN 'COLUMNA_AUSENTE_O_NO_VISIBLE' ELSE 'VISIBLE' END Estado,
 TYPE_NAME(C.user_type_id) Tipo,C.max_length,C.precision,C.scale,C.collation_name,
 C.is_nullable,C.is_computed,ST.temporal_type_desc,ST.is_memory_optimized
FROM @Tablas T JOIN @Origen O ON O.Tabla=T.Tabla
LEFT JOIN sys.columns C ON C.object_id=T.Objeto AND C.name COLLATE DATABASE_DEFAULT=O.Columna
LEFT JOIN sys.tables ST ON ST.object_id=T.Objeto ORDER BY T.Lote,O.Posicion;

SELECT '02_ESTADO_PK_E_INDICE' Seccion,T.Lote,T.Tabla,T.NombrePK,I.name,I.type_desc,
 I.is_unique,I.is_primary_key,I.is_unique_constraint,I.is_disabled,K.name Restriccion
FROM @Tablas T LEFT JOIN sys.indexes I ON I.object_id=T.Objeto
 AND (I.name=T.NombrePK COLLATE DATABASE_DEFAULT OR I.is_primary_key=1)
LEFT JOIN sys.key_constraints K ON K.parent_object_id=I.object_id AND K.unique_index_id=I.index_id
ORDER BY T.Lote,I.name;

SELECT '03_INDICES' Seccion,T.Lote,T.Tabla,I.name,I.type_desc,I.is_unique,
 I.is_primary_key,I.is_unique_constraint,I.is_disabled,I.has_filter,I.filter_definition,
 I.fill_factor,I.is_padded,I.ignore_dup_key,I.allow_row_locks,I.allow_page_locks,
 DS.name EspacioDatos,DS.type_desc TipoEspacioDatos,P.partition_number,P.data_compression_desc,
 IC.key_ordinal,IC.is_included_column,IC.is_descending_key,IC.partition_ordinal,C.name Columna,
 CASE WHEN EXISTS(SELECT 1 FROM @Origen O WHERE O.Tabla=T.Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT)
 THEN 1 ELSE 0 END EsColumnaPKOracle
FROM @Tablas T JOIN sys.indexes I ON I.object_id=T.Objeto AND I.index_id>0
LEFT JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
LEFT JOIN sys.partitions P ON P.object_id=I.object_id AND P.index_id=I.index_id
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
ORDER BY T.Lote,I.index_id,P.partition_number,IC.index_column_id;

SELECT '04_ESTADISTICAS' Seccion,T.Lote,T.Tabla,S.name,S.auto_created,S.user_created,
 S.no_recompute,S.is_incremental,S.has_filter,S.filter_definition,I.name IndiceAsociado,
 SC.stats_column_id,C.name Columna,
 CASE WHEN EXISTS(SELECT 1 FROM @Origen O WHERE O.Tabla=T.Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT)
 THEN 1 ELSE 0 END EsColumnaPKOracle
FROM @Tablas T JOIN sys.stats S ON S.object_id=T.Objeto
LEFT JOIN sys.indexes I ON I.object_id=S.object_id AND I.index_id=S.stats_id
JOIN sys.stats_columns SC ON SC.object_id=S.object_id AND SC.stats_id=S.stats_id
JOIN sys.columns C ON C.object_id=SC.object_id AND C.column_id=SC.column_id
ORDER BY T.Lote,S.stats_id,SC.stats_column_id;

SELECT '05_DEPENDENCIAS_SQL' Seccion,T.Lote,T.Tabla,
 OBJECT_SCHEMA_NAME(D.referencing_id) Esquema,OBJECT_NAME(D.referencing_id) Objeto,
 O.type_desc,D.referencing_minor_id,D.referenced_minor_id,D.is_schema_bound_reference
FROM @Tablas T JOIN sys.sql_expression_dependencies D ON D.referenced_id=T.Objeto
LEFT JOIN sys.objects O ON O.object_id=D.referencing_id
ORDER BY T.Lote,D.is_schema_bound_reference DESC,Esquema,Objeto;

SELECT '06_CALCULADAS' Seccion,T.Lote,T.Tabla,C.name,C.is_persisted,C.definition
FROM @Tablas T JOIN sys.computed_columns C ON C.object_id=T.Objeto;
SELECT '07_CHECKS' Seccion,T.Lote,T.Tabla,C.name,C.parent_column_id,C.is_disabled,C.is_not_trusted,C.definition
FROM @Tablas T JOIN sys.check_constraints C ON C.parent_object_id=T.Objeto;
SELECT '08_DEFAULTS' Seccion,T.Lote,T.Tabla,C.name,C.parent_column_id,C.definition
FROM @Tablas T JOIN sys.default_constraints C ON C.parent_object_id=T.Objeto;
SELECT '09_FK' Seccion,T.Lote,T.Tabla,F.name,F.is_disabled,F.is_not_trusted,
 OBJECT_SCHEMA_NAME(FC.parent_object_id) EsquemaOrigen,OBJECT_NAME(FC.parent_object_id) TablaOrigen,
 COL_NAME(FC.parent_object_id,FC.parent_column_id) ColumnaOrigen,
 OBJECT_SCHEMA_NAME(FC.referenced_object_id) EsquemaDestino,OBJECT_NAME(FC.referenced_object_id) TablaDestino,
 COL_NAME(FC.referenced_object_id,FC.referenced_column_id) ColumnaDestino,
 F.key_index_id,F.delete_referential_action_desc,F.update_referential_action_desc
FROM @Tablas T JOIN sys.foreign_keys F ON F.parent_object_id=T.Objeto OR F.referenced_object_id=T.Objeto
JOIN sys.foreign_key_columns FC ON FC.constraint_object_id=F.object_id
ORDER BY T.Lote,F.name,FC.constraint_column_id;
SELECT '10_PROPIEDADES_INDICES' Seccion,T.Lote,T.Tabla,I.name Indice,EP.name Propiedad,
 CONVERT(nvarchar(4000),EP.value) Valor
FROM @Tablas T JOIN sys.extended_properties EP ON EP.class=7 AND EP.major_id=T.Objeto
JOIN sys.indexes I ON I.object_id=T.Objeto AND I.index_id=EP.minor_id;

SELECT T.Lote,T.Tabla,
 (SELECT I.name,I.filter_definition FROM sys.indexes I WHERE I.object_id=T.Objeto
 FOR XML PATH('Indice'),TYPE) Indices,
 (SELECT S.name,S.filter_definition FROM sys.stats S WHERE S.object_id=T.Objeto
 FOR XML PATH('Estadistica'),TYPE) Estadisticas,
 (SELECT C.name,C.definition FROM sys.computed_columns C WHERE C.object_id=T.Objeto
 FOR XML PATH('Calculada'),TYPE) Calculadas,
 (SELECT C.name,C.definition FROM sys.check_constraints C WHERE C.parent_object_id=T.Objeto
 FOR XML PATH('Check'),TYPE) Checks,
 (SELECT DISTINCT OBJECT_SCHEMA_NAME(D.referencing_id) Esquema,OBJECT_NAME(D.referencing_id) Objeto,
 OBJECT_DEFINITION(D.referencing_id) Definicion FROM sys.sql_expression_dependencies D
 WHERE D.referenced_id=T.Objeto AND D.is_schema_bound_reference=1
 FOR XML PATH('Dependencia'),TYPE) DependenciasLigadasAlEsquema
FROM @Tablas T ORDER BY T.Lote FOR XML PATH('Tabla'),ROOT('DiagnosticoLotes12a17'),TYPE;
