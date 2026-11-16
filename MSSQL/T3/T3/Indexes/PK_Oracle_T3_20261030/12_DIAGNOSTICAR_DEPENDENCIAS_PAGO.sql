/* SOLO LECTURA de catalogos. No reconstruye/elimina indices, estadisticas ni
   restricciones. No escanea filas de PAGO.
   El error 4922 recibido no identifica el objeto bloqueante: los resultados
   listan dependencias candidatas, no prueban que cada objeto sea un bloqueo.
   Revisa ambas columnas de PK: PAGO_ID y FECHA_TRN. Conservar todos los resultados.
   El XML incluye definiciones de dependencias SQL ligadas al esquema.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @Objeto int=OBJECT_ID(N'T3.PAGO',N'U');
DECLARE @Columna int=COLUMNPROPERTY(@Objeto,N'FECHA_TRN',N'ColumnId');
DECLARE @ColumnaPago int=COLUMNPROPERTY(@Objeto,N'PAGO_ID',N'ColumnId');
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,SYSDATETIMEOFFSET() Captura,
 HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION') PuedeVerDefinicionBase;
IF @Objeto IS NULL OR @Columna IS NULL OR @ColumnaPago IS NULL
 THROW 56910,'PAGO, PAGO_ID o FECHA_TRN ausente/no visible.',1;

SELECT '01_ESTADO_COLUMNA' Seccion,C.name Columna,TYPE_NAME(C.user_type_id) Tipo,
 C.max_length,C.precision,C.scale,C.collation_name,C.is_nullable,C.is_computed,
 T.temporal_type_desc,T.is_memory_optimized
FROM sys.columns C JOIN sys.tables T ON T.object_id=C.object_id
WHERE C.object_id=@Objeto AND C.column_id IN(@Columna,@ColumnaPago);
SELECT '02_ESTADO_PK_E_INDICE' Seccion,I.name,I.type_desc,I.is_unique,
 I.is_primary_key,I.is_unique_constraint,I.is_disabled,K.name Restriccion,K.type_desc TipoRestriccion
FROM sys.indexes I LEFT JOIN sys.key_constraints K
 ON K.parent_object_id=I.object_id AND K.unique_index_id=I.index_id
WHERE I.object_id=@Objeto AND (I.name=N'PAGO_PK' OR I.is_primary_key=1);

-- Todos los indices: un filtro puede depender de FECHA_TRN aunque no sea clave.
SELECT '03_INDICES' Seccion,I.name,I.type_desc,I.is_unique,I.is_primary_key,
 I.is_unique_constraint,I.is_disabled,I.has_filter,I.filter_definition,
 I.fill_factor,I.is_padded,I.ignore_dup_key,I.allow_row_locks,I.allow_page_locks,
 DS.name EspacioDatos,DS.type_desc TipoEspacioDatos,
 P.partition_number,P.data_compression_desc,
 IC.key_ordinal,IC.is_included_column,IC.is_descending_key,IC.partition_ordinal,
 C.name Columna,CASE WHEN IC.column_id IN(@Columna,@ColumnaPago) THEN 1 ELSE 0 END EsColumnaPK
FROM sys.indexes I
LEFT JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
LEFT JOIN sys.partitions P ON P.object_id=I.object_id AND P.index_id=I.index_id
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=@Objeto AND I.index_id>0
ORDER BY I.index_id,P.partition_number,IC.index_column_id;

SELECT '04_ESTADISTICAS' Seccion,S.name,S.auto_created,S.user_created,
 S.no_recompute,S.is_incremental,S.has_filter,S.filter_definition,
 I.name IndiceAsociado,SC.stats_column_id,C.name Columna,
 CASE WHEN C.column_id IN(@Columna,@ColumnaPago) THEN 1 ELSE 0 END EsColumnaPK
FROM sys.stats S
LEFT JOIN sys.indexes I ON I.object_id=S.object_id AND I.index_id=S.stats_id
JOIN sys.stats_columns SC ON SC.object_id=S.object_id AND SC.stats_id=S.stats_id
JOIN sys.columns C ON C.object_id=SC.object_id AND C.column_id=SC.column_id
WHERE S.object_id=@Objeto ORDER BY S.stats_id,SC.stats_column_id;

SELECT '05_DEPENDENCIAS_SQL' Seccion,
 OBJECT_SCHEMA_NAME(D.referencing_id) Esquema,OBJECT_NAME(D.referencing_id) Objeto,
 O.type_desc,D.referencing_minor_id,D.referenced_minor_id,D.is_schema_bound_reference
FROM sys.sql_expression_dependencies D
LEFT JOIN sys.objects O ON O.object_id=D.referencing_id
WHERE D.referenced_id=@Objeto AND D.referenced_minor_id IN(0,@Columna,@ColumnaPago)
ORDER BY D.is_schema_bound_reference DESC,Esquema,Objeto;

SELECT '06_COLUMNAS_CALCULADAS' Seccion,name,is_persisted,definition
FROM sys.computed_columns WHERE object_id=@Objeto;
SELECT '07_CHECKS' Seccion,name,parent_column_id,is_disabled,is_not_trusted,definition
FROM sys.check_constraints WHERE parent_object_id=@Objeto;
SELECT '08_DEFAULTS' Seccion,name,parent_column_id,definition
FROM sys.default_constraints WHERE parent_object_id=@Objeto AND parent_column_id IN(@Columna,@ColumnaPago);
SELECT '09_FOREIGN_KEYS' Seccion,F.name,F.is_disabled,F.is_not_trusted,
 OBJECT_SCHEMA_NAME(FC.parent_object_id) EsquemaOrigen,OBJECT_NAME(FC.parent_object_id) TablaOrigen,
 COL_NAME(FC.parent_object_id,FC.parent_column_id) ColumnaOrigen,
 OBJECT_SCHEMA_NAME(FC.referenced_object_id) EsquemaDestino,OBJECT_NAME(FC.referenced_object_id) TablaDestino,
 COL_NAME(FC.referenced_object_id,FC.referenced_column_id) ColumnaDestino,
 F.key_index_id,F.delete_referential_action_desc,F.update_referential_action_desc
FROM sys.foreign_keys F JOIN sys.foreign_key_columns FC ON FC.constraint_object_id=F.object_id
WHERE F.parent_object_id=@Objeto OR F.referenced_object_id=@Objeto
ORDER BY F.name,FC.constraint_column_id;

-- Abrir el XML en SSMS y guardar si las definiciones del grid se truncan.
SELECT
 (SELECT I.name,I.filter_definition FROM sys.indexes I WHERE I.object_id=@Objeto
  FOR XML PATH('Indice'),TYPE) AS Indices,
 (SELECT S.name,S.filter_definition FROM sys.stats S WHERE S.object_id=@Objeto
  FOR XML PATH('Estadistica'),TYPE) AS Estadisticas,
 (SELECT C.name,C.definition FROM sys.computed_columns C WHERE C.object_id=@Objeto
  FOR XML PATH('ColumnaCalculada'),TYPE) AS ColumnasCalculadas,
 (SELECT C.name,C.definition FROM sys.check_constraints C WHERE C.parent_object_id=@Objeto
  FOR XML PATH('Check'),TYPE) AS Checks,
 (SELECT DISTINCT OBJECT_SCHEMA_NAME(D.referencing_id) Esquema,OBJECT_NAME(D.referencing_id) Objeto,
  OBJECT_DEFINITION(D.referencing_id) Definicion
  FROM sys.sql_expression_dependencies D
  WHERE D.referenced_id=@Objeto AND D.referenced_minor_id IN(0,@Columna,@ColumnaPago)
    AND D.is_schema_bound_reference=1
  FOR XML PATH('Dependencia'),TYPE) AS Dependencias
FOR XML PATH('DiagnosticoPago'),TYPE;
