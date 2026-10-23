/* Primera mejora: accesos por ReferenceID, Factura y Material.
   Ejecutar en la BD destino seleccionada en SSMS. No contiene USE ni credenciales.
   @Aplicar=0: inventario y propuestas; @Aplicar=1: crea SOLO los faltantes.
   @SoloId permite aplicar una tabla por ejecucion. No ejecuta procedimientos.
   No elimina/reconstruye indices; no altera unicidad ni cambia datos.
   CREATE INDEX puede bloquear y consumir espacio/log: ejecutar la creacion
   en una ventana apropiada. No se fuerza ONLINE ni se asume una edicion.
   Sin transaccion global: los indices creados permanecen si falla uno posterior.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @Aplicar bit = 0;
DECLARE @SoloId int = NULL; -- NULL: todas las tablas; 1..10: una sola.

DECLARE @P table
 (Id int PRIMARY KEY, Esquema sysname, Tabla sysname, Clave sysname, Nombre sysname,
  Incluidas nvarchar(500), Objeto int NULL, ColumnaId int NULL, IndiceUtil sysname NULL,
  Estado varchar(40) NULL, DDL nvarchar(max) NULL);
INSERT @P (Id,Esquema,Tabla,Clave,Nombre,Incluidas) VALUES
 (1,N'EAI_OWNER',N'TMP_DOCUMENT_HEADER',N'REFERENCEID',N'IX_RI_TMP_HEADER_REF',N''),
 (2,N'EAI_OWNER',N'TMP_DOCUMENT_DETAIL',N'REFERENCEID',N'IX_RI_TMP_DETAIL_REF',N''),
 (3,N'EAI_OWNER',N'TMP_DOCUMENT_CONDITIONS',N'REFERENCEID',N'IX_RI_TMP_CONDITIONS_REF',N''),
 (4,N'T3',N'PREVENTA_GENERAL',N'FACTURA',N'IX_RI_PREVENTA_GENERAL_FACTURA',N''),
 (5,N'T3',N'PREVENTA_DETALLE',N'FACTURA',N'IX_RI_PREVENTA_DETALLE_FACTURA',N''),
 (6,N'T3',N'FACTURA_GENERAL',N'FACTURA',N'IX_RI_FACTURA_GENERAL_FACTURA',N''),
 (7,N'T3',N'FACTURA_DETALLE',N'FACTURA',N'IX_RI_FACTURA_DETALLE_FACTURA',N''),
 (8,N'T3',N'RF_COMPLEMENTO',N'FACTURA',N'IX_RI_RF_COMPLEMENTO_FACTURA',N''),
 (9,N'T3',N'REMISION_GENERAL',N'FACTURA',N'IX_RI_REMISION_GENERAL_FACTURA',N''),
 (10,N'T3',N'MATERIAL',N'MATERIAL',N'IX_RI_MATERIAL',
  N' INCLUDE ([UM],[UNIDAD_MED_VTA],[CIG_X_CLL],[CIG_X_PAQ],[CIG_X_CT],[NOMBRE_MATERIAL])');

IF @SoloId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @P WHERE Id=@SoloId)
    THROW 51900,'SoloId no corresponde a una propuesta (1..10).',1;
IF @Aplicar=1 AND @@TRANCOUNT<>0
    THROW 51901,'Ejecutar la creacion fuera de una transaccion externa.',1;
IF @Aplicar=1 AND (2 & @@OPTIONS)=2
    THROW 51902,'Desactivar IMPLICIT_TRANSACTIONS antes de crear indices.',1;

UPDATE @P SET Objeto=OBJECT_ID(QUOTENAME(Esquema)+N'.'+QUOTENAME(Tabla),N'U');
UPDATE P SET ColumnaId=C.column_id FROM @P P JOIN sys.columns C
 ON C.object_id=P.Objeto AND C.name COLLATE DATABASE_DEFAULT=P.Clave COLLATE DATABASE_DEFAULT;

-- Igualdad por clave inicial: ASC/DESC sirven. Reutilizar incluso indices
-- compuestos, PK y UNIQUE, siempre que esten activos, completos y sean B-tree.
UPDATE P SET IndiceUtil=X.name
FROM @P P OUTER APPLY
 (SELECT TOP (1) I.name FROM sys.indexes I
  JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
  WHERE I.object_id=P.Objeto AND I.type IN (1,2) AND I.is_disabled=0
    AND I.is_hypothetical=0 AND I.has_filter=0
    AND IC.key_ordinal=1 AND IC.column_id=P.ColumnaId
  ORDER BY I.is_unique DESC,I.index_id) X;

UPDATE P SET Estado=CASE
 WHEN Objeto IS NULL THEN 'TABLA_NO_VISIBLE_O_AUSENTE'
 WHEN ColumnaId IS NULL THEN 'COLUMNA_AUSENTE'
 WHEN EXISTS(SELECT 1 FROM sys.tables T WHERE T.object_id=P.Objeto AND T.is_memory_optimized=1)
   THEN 'REVISAR_MEMORY_OPTIMIZED'
 WHEN EXISTS(SELECT 1 FROM sys.indexes I WHERE I.object_id=P.Objeto AND I.type=1 AND I.is_disabled=1)
   THEN 'CLUSTERED_DESHABILITADO'
 WHEN IndiceUtil IS NOT NULL THEN 'ACCESO_EXISTENTE'
 WHEN EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.index_columns IC
   ON IC.object_id=I.object_id AND IC.index_id=I.index_id
   WHERE I.object_id=P.Objeto AND I.type IN (1,2) AND I.is_disabled=0
     AND I.is_hypothetical=0 AND I.has_filter=1
     AND IC.key_ordinal=1 AND IC.column_id=P.ColumnaId)
   THEN 'REVISAR_INDICE_FILTRADO'
 WHEN EXISTS(SELECT 1 FROM sys.indexes I WHERE I.object_id=P.Objeto
   AND I.name COLLATE DATABASE_DEFAULT=P.Nombre COLLATE DATABASE_DEFAULT)
   THEN 'CONFLICTO_NOMBRE'
 WHEN EXISTS(SELECT 1 FROM sys.columns C WHERE C.object_id=P.Objeto AND C.column_id=P.ColumnaId
   AND (C.max_length=-1 OR C.max_length>900 OR C.is_computed=1
        OR TYPE_NAME(C.system_type_id) NOT IN ('varchar','nvarchar','char','nchar','int','bigint','numeric','decimal')))
   THEN 'REVISAR_TIPO_CLAVE'
 ELSE 'FALTA_ACCESO' END FROM @P P;

-- Validar cobertura solo al crear MATERIAL; no duplicar un acceso existente
-- porque le falte alguna columna incluida. Esa ampliacion requiere plan real.
IF EXISTS(SELECT 1 FROM @P WHERE Id=10 AND Estado='FALTA_ACCESO')
 AND EXISTS(SELECT 1 FROM (VALUES(N'UM'),(N'UNIDAD_MED_VTA'),(N'CIG_X_CLL'),
                    (N'CIG_X_PAQ'),(N'CIG_X_CT'),(N'NOMBRE_MATERIAL')) V(Columna)
 WHERE NOT EXISTS(SELECT 1 FROM sys.columns C JOIN @P P ON P.Objeto=C.object_id AND P.Id=10
  WHERE C.name COLLATE DATABASE_DEFAULT=V.Columna COLLATE DATABASE_DEFAULT))
    UPDATE @P SET Estado='COLUMNA_INCLUDE_AUSENTE' WHERE Id=10;

UPDATE @P SET DDL=N'CREATE NONCLUSTERED INDEX '+QUOTENAME(Nombre)+N' ON '
 +QUOTENAME(Esquema)+N'.'+QUOTENAME(Tabla)+N' ('+QUOTENAME(Clave)+N')'+Incluidas+N';'
WHERE Estado='FALTA_ACCESO';

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@Aplicar AS Aplicar,@SoloId AS SoloId;
SELECT P.Id,P.Esquema,P.Tabla,P.Clave,P.Estado,P.IndiceUtil,
 R.FilasAproximadas,P.DDL AS PropuestaCreacion
FROM @P P OUTER APPLY
 (SELECT SUM(CONVERT(bigint,SP.rows)) AS FilasAproximadas FROM sys.partitions SP
  WHERE SP.object_id=P.Objeto AND SP.index_id IN (0,1)) R
WHERE @SoloId IS NULL OR P.Id=@SoloId ORDER BY P.Id;

-- Inventario completo: clave en segunda posicion/INCLUDE no basta para este acceso.
SELECT P.Id,P.Esquema,P.Tabla,I.name AS Indice,I.type_desc,I.is_unique,I.is_disabled,
 I.has_filter,I.filter_definition,IC.key_ordinal,IC.is_included_column,
 IC.is_descending_key,C.name AS Columna,STATS_DATE(I.object_id,I.index_id) AS FechaEstadistica
FROM @P P JOIN sys.indexes I ON I.object_id=P.Objeto
LEFT JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
LEFT JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE @SoloId IS NULL OR P.Id=@SoloId
ORDER BY P.Id,I.index_id,IC.is_included_column,IC.key_ordinal,IC.index_column_id;

IF @Aplicar=1
BEGIN
    -- Prevalidar TODOS los objetos seleccionados antes de crear el primero.
    IF EXISTS(SELECT 1 FROM @P WHERE (@SoloId IS NULL OR Id=@SoloId)
      AND Estado NOT IN ('ACCESO_EXISTENTE','FALTA_ACCESO'))
        THROW 51903,'Hay propuestas que requieren revision. Consultar Estado o seleccionar un SoloId resuelto.',1;
    IF EXISTS(SELECT 1 FROM @P WHERE (@SoloId IS NULL OR Id=@SoloId) AND Estado='FALTA_ACCESO'
      AND ISNULL(HAS_PERMS_BY_NAME(QUOTENAME(Esquema)+N'.'+QUOTENAME(Tabla),'OBJECT','ALTER'),0)<>1)
        THROW 51904,'Falta permiso ALTER en una tabla seleccionada.',1;

    DECLARE @Id int=0,@Objeto int,@ColumnaId int,@DDL nvarchar(max),@Nombre sysname;
    WHILE EXISTS(SELECT 1 FROM @P WHERE Id>@Id AND Estado='FALTA_ACCESO' AND (@SoloId IS NULL OR Id=@SoloId))
    BEGIN
        SELECT TOP(1) @Id=Id,@Objeto=Objeto,@ColumnaId=ColumnaId,@DDL=DDL,@Nombre=Nombre
        FROM @P WHERE Id>@Id AND Estado='FALTA_ACCESO' AND (@SoloId IS NULL OR Id=@SoloId) ORDER BY Id;
        -- Revalidar por si el DBA creo otro indice desde el inventario inicial.
        IF EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.index_columns IC
          ON IC.object_id=I.object_id AND IC.index_id=I.index_id
          WHERE I.object_id=@Objeto AND I.type IN (1,2) AND I.is_disabled=0
            AND I.is_hypothetical=0 AND I.has_filter=0
            AND IC.key_ordinal=1 AND IC.column_id=@ColumnaId)
            UPDATE @P SET Estado='OMITIDO_ACCESO_CONCURRENTE' WHERE Id=@Id;
        ELSE
        BEGIN
            IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Objeto AND name=@Nombre)
                THROW 51905,'El nombre del indice aparecio durante la ejecucion. Revisar y repetir.',1;
            EXEC sys.sp_executesql @DDL;
            UPDATE @P SET Estado='CREADO',IndiceUtil=@Nombre WHERE Id=@Id;
        END;
    END;
    SELECT Id,Esquema,Tabla,Estado,IndiceUtil FROM @P
    WHERE @SoloId IS NULL OR Id=@SoloId ORDER BY Id;
END;
