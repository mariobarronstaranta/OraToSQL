/* Ejecutar COMPLETO en una conexion nueva. Solo lectura de metadatos.
   No cuenta ni agrupa filas de REGISTRO_FISCAL_DETALLE. No genera DDL.
   No presupone que el rollback haya restaurado el estado anterior.
   LOCK_TIMEOUT limita esperas por bloqueos, NO la duracion total.
*/
USE [master];
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR (@@OPTIONS & 2)=2
    THROW 56990,'Usar una conexion nueva, sin transaccion y con IMPLICIT_TRANSACTIONS OFF.',1;
SELECT @@SERVERNAME Servidor, SYSDATETIMEOFFSET() Captura,
       SERVERPROPERTY('ProductVersion') Version,
       SERVERPROPERTY('ProductLevel') Nivel,
       SERVERPROPERTY('Edition') Edicion,
       SERVERPROPERTY('EngineEdition') EngineEdition;
SELECT name, state_desc, recovery_model_desc, log_reuse_wait_desc,
       compatibility_level, is_read_only, page_verify_option_desc
FROM sys.databases WHERE name=N'T3QA';
IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name=N'T3QA' AND state_desc=N'ONLINE')
    THROW 56991,'T3QA no esta ONLINE o no es visible. Detener; no ejecutar migracion.',1;

-- SET local al lote dinamico; SQL Server restaura opciones al salir.
 EXEC sys.sp_executesql N'
USE [T3QA];
SET LOCK_TIMEOUT 5000;
SELECT DB_NAME() BaseDatos,
 HAS_PERMS_BY_NAME(DB_NAME(),''DATABASE'',''VIEW DEFINITION'') PuedeVerDefinicionBase;
DECLARE @obj int=OBJECT_ID(N''T3.REGISTRO_FISCAL_DETALLE'',N''U'');
IF @obj IS NULL
BEGIN
 SELECT N''Tabla ausente o sin visibilidad. No concluir que faltan indices.'' Resultado;
 RETURN;
END;
SELECT N''01_COLUMNAS'' Seccion,c.column_id,c.name Columna,ty.name Tipo,
 c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_computed
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id=c.user_type_id
WHERE c.object_id=@obj ORDER BY c.column_id;

SELECT N''02_INDICES_Y_COLUMNAS'' Seccion,i.index_id,i.name Indice,i.type_desc,
 i.is_primary_key,i.is_unique_constraint,i.is_unique,i.is_disabled,
 i.is_hypothetical,i.has_filter,i.filter_definition,i.ignore_dup_key,
 i.fill_factor,ds.name EspacioDatos,ds.type_desc TipoEspacio,
 ic.key_ordinal,ic.is_included_column,ic.is_descending_key,ic.partition_ordinal,
 c.name Columna,k.name Restriccion,k.type_desc TipoRestriccion
FROM sys.indexes i
LEFT JOIN sys.data_spaces ds ON ds.data_space_id=i.data_space_id
LEFT JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
LEFT JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
LEFT JOIN sys.key_constraints k ON k.parent_object_id=i.object_id AND k.unique_index_id=i.index_id
WHERE i.object_id=@obj ORDER BY i.index_id,ic.index_column_id;

SELECT N''03_PARTICIONES_FILAS_ESTIMADAS'' Seccion,i.name Indice,
 p.index_id,p.partition_number,p.rows FilasEstimadas,p.data_compression_desc
FROM sys.partitions p JOIN sys.indexes i ON i.object_id=p.object_id AND i.index_id=p.index_id
WHERE p.object_id=@obj ORDER BY p.index_id,p.partition_number;

SELECT N''04_CLAVES_EQUIVALENTES'' Seccion,i.name Indice,i.is_primary_key,
 i.is_unique_constraint,i.ignore_dup_key,
 CASE WHEN i.is_primary_key=1 THEN N''PK activa con las dos columnas esperadas''
 ELSE N''Indice UNIQUE activo: conserva unicidad; no equivale a PK ni prueba NOT NULL'' END Resultado
FROM sys.indexes i
WHERE i.object_id=@obj AND i.is_unique=1 AND i.is_disabled=0
 AND i.is_hypothetical=0 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id
      AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2
 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c
 ON c.object_id=ic.object_id AND c.column_id=ic.column_id
 WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1
 AND c.name COLLATE DATABASE_DEFAULT=N''FACTURA'')
 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c
 ON c.object_id=ic.object_id AND c.column_id=ic.column_id
 WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2
 AND c.name COLLATE DATABASE_DEFAULT=N''NUM_LINEA'');

SELECT N''05_FK_DEPENDIENTES'' Seccion,f.name FK,
 OBJECT_SCHEMA_NAME(f.parent_object_id) Esquema,OBJECT_NAME(f.parent_object_id) Tabla,
 f.key_index_id,f.is_disabled,f.is_not_trusted
FROM sys.foreign_keys f WHERE f.referenced_object_id=@obj OR f.parent_object_id=@obj;

IF OBJECT_ID(N''sys.index_resumable_operations'') IS NOT NULL
 EXEC(N''SELECT N''''06_OPERACIONES_REANUDABLES'''' Seccion,*
 FROM sys.index_resumable_operations
 WHERE object_id=OBJECT_ID(N''''T3.REGISTRO_FISCAL_DETALLE'''');'');
ELSE SELECT N''06_OPERACIONES_REANUDABLES: vista no disponible en esta version'' Resultado;
';
