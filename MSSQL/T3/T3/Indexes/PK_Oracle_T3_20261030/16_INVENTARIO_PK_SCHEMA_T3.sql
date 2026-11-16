/* SQL Server: inventario actual de tablas y claves primarias del esquema T3.
   SOLO LECTURA de metadatos: no modifica objetos ni recorre datos de negocio.
   Incluye todas las tablas visibles del esquema, no solo las del listado Oracle.
   Reconoce restricciones PRIMARY KEY reales; un indice UNIQUE no cuenta como PK.
   Requiere visibilidad de metadatos para obtener el inventario completo.
*/
USE [T3QA]; -- Cambiar si se consulta otra base de datos.
SET NOCOUNT ON;
DECLARE @Esquema sysname=N'T3';

SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,@Esquema Esquema,
       SYSDATETIMEOFFSET() Captura,
       HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION') PuedeVerDefinicionBase;

-- 1. Una fila por tabla. Las columnas de la PK aparecen en su orden real.
SELECT @Esquema AS Esquema,
       T.name AS Tabla,
       K.name AS NombrePK,
       A.ColumnasPK,
       I.type_desc AS TipoIndicePK,
       CASE WHEN K.object_id IS NULL THEN N'SIN PK'
            WHEN I.index_id IS NULL THEN N'INDICE PK NO VISIBLE'
            WHEN I.is_disabled=1 THEN N'PK DESHABILITADA'
            ELSE N'PK ACTIVA' END AS Estado
FROM sys.tables T
LEFT JOIN sys.key_constraints K
  ON K.parent_object_id=T.object_id AND K.type='PK'
LEFT JOIN sys.indexes I
  ON I.object_id=K.parent_object_id AND I.index_id=K.unique_index_id
OUTER APPLY (
    SELECT STUFF((
        SELECT N', '+QUOTENAME(C.name)
        FROM sys.index_columns IC
        JOIN sys.columns C
          ON C.object_id=IC.object_id AND C.column_id=IC.column_id
        WHERE IC.object_id=T.object_id
          AND IC.index_id=K.unique_index_id
          AND IC.key_ordinal>0
        ORDER BY IC.key_ordinal
        FOR XML PATH(''),TYPE
    ).value('.','nvarchar(max)'),1,2,N'') AS ColumnasPK
) A
WHERE T.schema_id=SCHEMA_ID(@Esquema) AND T.is_ms_shipped=0
ORDER BY T.name;

-- 2. Detalle: una fila por columna de PK; util para exportar/comparar.
--    Las tablas sin PK solo aparecen en el primer resultado.
SELECT @Esquema AS Esquema,
       T.name AS Tabla,
       K.name AS NombrePK,
       IC.key_ordinal AS Posicion,
       C.name AS ColumnaPK,
       TYPE_NAME(C.user_type_id) AS TipoDato,
       C.max_length AS LongitudMaximaBytes,
       C.precision AS Precision,
       C.scale AS Escala,
       C.is_nullable AS PermiteNull,
       CASE WHEN IC.is_descending_key=1 THEN N'DESC' ELSE N'ASC' END AS Direccion,
       I.is_disabled AS PKDeshabilitada
FROM sys.tables T
JOIN sys.key_constraints K
  ON K.parent_object_id=T.object_id AND K.type='PK'
JOIN sys.indexes I
  ON I.object_id=K.parent_object_id AND I.index_id=K.unique_index_id
JOIN sys.index_columns IC
  ON IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0
JOIN sys.columns C
  ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE T.schema_id=SCHEMA_ID(@Esquema) AND T.is_ms_shipped=0
ORDER BY T.name,IC.key_ordinal;
