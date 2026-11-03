/*
  Candidato para T3QA: recuperar acceso por CLIENTE_V3 y vigencia.
  Ejecutar como administrador AL TERMINAR las cargas, sin procesos concurrentes
  sobre CLIENTE. Construir el indice consume IO/espacio y puede bloquear.

  La captura 17:42:41 muestra CLIENTE_PK deshabilitado y CLIENTE_IDX1 activo
  por CLIENTE_SAP. El inventario confirma que CLIENTE_PK es UNIQUE: este script
  crea un indice NO UNIQUE y conserva el estado de todos los existentes.
  No habilita restricciones, no elimina duplicados ni cambia datos/GETCONV/SP.
  No promete una tasa integral; medir una carga comparable despues.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME()<>N'T3QA' THROW 52700,'Seleccionar T3QA antes de aplicar el indice.',1;
IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
 THROW 52701,'Ejecutar sin transacciones externas ni implicitas.',1;
DECLARE @Tabla int=OBJECT_ID(N'T3.CLIENTE',N'U'),
        @Columna int=COLUMNPROPERTY(OBJECT_ID(N'T3.CLIENTE'),N'CLIENTE_V3',N'ColumnId');
IF @Tabla IS NULL OR @Columna IS NULL
 THROW 52702,'CLIENTE o CLIENTE_V3 no visible; revisar base/permisos.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@Tabla AND column_id=@Columna
              AND TYPE_NAME(system_type_id)=N'varchar' AND max_length=20)
 OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@Tabla AND name=N'FECHA_INI_VIG'
               AND TYPE_NAME(system_type_id)=N'datetime2')
 OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@Tabla AND name=N'FECHA_FIN_VIG'
               AND TYPE_NAME(system_type_id)=N'datetime2')
 THROW 52703,'La definicion de CLIENTE difiere de la revisada; no crear automaticamente.',1;

SELECT '01_ANTES' AS Seccion,@@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,
       SYSDATETIMEOFFSET() AS FechaCaptura,I.name,I.type_desc,I.is_unique,
       I.is_primary_key,I.is_unique_constraint,I.is_disabled,
       IC.key_ordinal,C.name AS Columna
FROM sys.indexes I INNER JOIN sys.index_columns IC
 ON IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0
INNER JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=@Tabla AND
 (I.name IN(N'CLIENTE_PK',N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA')
  OR EXISTS(SELECT 1 FROM sys.index_columns K
            WHERE K.object_id=I.object_id AND K.index_id=I.index_id
              AND K.column_id=@Columna AND K.key_ordinal=1))
ORDER BY I.index_id,IC.key_ordinal;

-- Si el DBA ya rehabilito CLIENTE_PK u otro acceso inicial por V3, no duplicar.
IF EXISTS(SELECT 1 FROM sys.indexes I INNER JOIN sys.index_columns IC
 ON IC.object_id=I.object_id AND IC.index_id=I.index_id
 WHERE I.object_id=@Tabla AND I.type IN(1,2) AND I.is_disabled=0
   AND I.is_hypothetical=0 AND I.has_filter=0
   AND IC.key_ordinal=1 AND IC.column_id=@Columna)
BEGIN
 SELECT '02_RESULTADO' AS Seccion,CAST(0 AS int) AS IndicesCreados,
        N'Sin cambios: ya existe un indice habilitado inicial por CLIENTE_V3.' AS Resultado;
 RETURN;
END;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Tabla
           AND name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA')
 THROW 52704,'El nombre propuesto ya existe sin cobertura activa reconocida; revisar.',1;

-- No UNIQUE: no impone una regla de unicidad sobre los datos cargados.
-- Las columnas de domicilio se obtienen de la tabla para las filas encontradas.
CREATE NONCLUSTERED INDEX IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA
ON T3.CLIENTE(CLIENTE_V3,FECHA_INI_VIG,FECHA_FIN_VIG);

SELECT '02_RESULTADO' AS Seccion,CAST(1 AS int) AS IndicesCreados,
       I.name AS Indice,I.is_unique,I.is_disabled,
       N'Acceso V3 creado. Pendiente revisar uso y medir una carga comparable.' AS Resultado
FROM sys.indexes I WHERE I.object_id=@Tabla
 AND I.name=N'IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA';

/*
  Reversion, solo si este indice se creo en esta intervencion y se decide retirarlo:
  DROP INDEX IX_RECV_INVOICE_CLIENTE_V3_VIGENCIA ON T3.CLIENTE;
  No es una instruccion activa ni revierte/rehabilita otros indices.
*/
