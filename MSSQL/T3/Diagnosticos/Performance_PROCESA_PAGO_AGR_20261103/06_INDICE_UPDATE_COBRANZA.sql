/*
  Primera mejora propuesta a partir del plan 8889 / query_id 32735.
  @Aplicar=0: SOLO metadatos y propuesta de DDL. No lee tablas de negocio,
              no crea indices y no simula su construccion ni mide la mejora.
  @Aplicar=1: comprueba coincidencias ambiguas del UPDATE y, si no encuentra,
              crea UN indice nonclustered. No ejecuta el SP ni actualiza datos.

  La tabla tiene unos 56 millones de filas. La construccion requiere espacio
  de datos/log, mantiene el indice en futuras cargas y puede bloquear escritores.
  Coordinar una ventana para @Aplicar=1. DDL ordinario, sin ONLINE ni edicion
  especial requerida. No se sustituyen ni eliminan indices existentes.

  La comprobacion usa el mismo @nDias que la siguiente corrida prevista (30).
  Evitar escritores/procesos concurrentes durante comprobacion y construccion:
  la comprobacion no bloquea logicamente futuras altas de coincidencias ambiguas.
  El resultado no garantiza paridad para otros dias ni para datos futuros.
*/
USE [T3QA];
SET NOCOUNT ON;
DECLARE @Aplicar bit=0;
DECLARE @nDias numeric(18,0)=30;
DECLARE @Captura datetime=GETDATE();
DECLARE @Limite date=CAST(DATEADD(DAY,-ISNULL(@nDias,0),@Captura) AS date);
DECLARE @Ejercicio varchar(4)=CONVERT(varchar(4),YEAR(@Captura));
DECLARE @Tabla int=OBJECT_ID(N'T3.CFDI_COBRANZA',N'U');
DECLARE @Nombre sysname=N'IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC';
DECLARE @DDL nvarchar(max)=N'CREATE NONCLUSTERED INDEX [IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC]
ON [T3].[CFDI_COBRANZA] ([ASIGNACION_CENTRAL], [FECHA_PROCESO])
INCLUDE ([ASIGNACION_ID], [FACTURA]);';

IF DB_NAME()<>N'T3QA' OR @Tabla IS NULL
    THROW 57301,'Se requiere T3QA y la tabla T3.CFDI_COBRANZA.',1;
IF @@TRANCOUNT<>0 OR XACT_STATE()<>0
    THROW 57302,'Ejecutar en una sesion sin transacciones abiertas.',1;
IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=@Tabla AND name IN
    (N'ASIGNACION_CENTRAL',N'FECHA_PROCESO',N'ASIGNACION_ID',N'FACTURA'))<>4
    THROW 57303,'Faltan columnas requeridas para el indice.',1;

SELECT '00_CONTEXTO_INDICE' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,
    SYSDATETIMEOFFSET() Captura,@Aplicar Aplicar,@nDias nDias,
    @Limite LimiteExclusivo,@Ejercicio Ejercicio;

-- Cobertura equivalente: mismas dos primeras claves, activas y sin filtro;
-- ambas columnas adicionales deben estar en clave o INCLUDE. Se permite otro
-- nombre e incluso mas columnas al final de la clave/cobertura.
DECLARE @Equivalentes table(Nombre sysname,IndexId int);
INSERT @Equivalentes
SELECT I.name,I.index_id FROM sys.indexes I
WHERE I.object_id=@Tabla AND I.type=2 AND I.is_disabled=0
  AND I.is_hypothetical=0 AND I.has_filter=0
  AND EXISTS(SELECT 1 FROM sys.index_columns IC JOIN sys.columns C
      ON C.object_id=IC.object_id AND C.column_id=IC.column_id
      WHERE IC.object_id=@Tabla AND IC.index_id=I.index_id
        AND IC.key_ordinal=1 AND C.name=N'ASIGNACION_CENTRAL')
  AND EXISTS(SELECT 1 FROM sys.index_columns IC JOIN sys.columns C
      ON C.object_id=IC.object_id AND C.column_id=IC.column_id
      WHERE IC.object_id=@Tabla AND IC.index_id=I.index_id
        AND IC.key_ordinal=2 AND C.name=N'FECHA_PROCESO')
  AND 2=(SELECT COUNT(DISTINCT C.name) FROM sys.index_columns IC JOIN sys.columns C
      ON C.object_id=IC.object_id AND C.column_id=IC.column_id
      WHERE IC.object_id=@Tabla AND IC.index_id=I.index_id
        AND (IC.is_included_column=1 OR IC.key_ordinal>0)
        AND C.name IN(N'ASIGNACION_ID',N'FACTURA'));

SELECT '01_INDICES_ACTUALES' Seccion,I.name Indice,I.is_disabled Deshabilitado,
    I.has_filter Filtrado,IC.key_ordinal OrdenClave,IC.is_included_column EsInclude,
    C.name Columna
FROM sys.indexes I JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=@Tabla AND I.index_id>0 ORDER BY I.index_id,IC.index_column_id;

IF EXISTS(SELECT 1 FROM @Equivalentes)
BEGIN
    SELECT '02_YA_EXISTE_EQUIVALENTE' Seccion,Nombre Indice FROM @Equivalentes;
    RETURN;
END;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Tabla AND name=@Nombre)
BEGIN
    SELECT '02_NOMBRE_OCUPADO' Seccion,@Nombre Indice,
        'El nombre existe con otra definicion o estado. No se elimina ni sustituye; revisar antes de crear.' Mensaje;
    IF @Aplicar=1 THROW 57304,'Nombre de indice ocupado sin cobertura activa equivalente.',1;
    RETURN;
END;

SELECT '02_PROPUESTA' Seccion,@Nombre Indice,@DDL DDL;
IF @Aplicar=0
BEGIN
    SELECT '03_SOLO_VISTA_PREVIA' Seccion,
        'No se creo el indice. Para crearlo, revisar la propuesta y ejecutar completo con @Aplicar=1 en la ventana acordada.' Mensaje;
    RETURN;
END;

-- El plan anterior agrega ANY(Assignment) por fila destino. Eso no demuestra
-- duplicados reales, pero exige comprobar que no hay dos valores distintos
-- elegibles para la misma cobranza antes de cambiar el orden fisico de acceso.
-- No se elige arbitrariamente MIN/MAX ni se modifican relaciones de origen.
DECLARE @Ambiguas table(Asignacion_ID nvarchar(128),Factura nvarchar(128),Alternativas bigint);
;WITH Alternativas AS (
    SELECT DISTINCT Cobza.Asignacion_ID,Cobza.Factura,
        CONVERT(varbinary(max),Acc.Assignment) ValorBinario,
        DATALENGTH(Acc.Assignment) BytesOriginales
    FROM T3.CFDI_COBRANZA Cobza
    JOIN EAI_OWNER.TMP_ACCOUNT_HEADER Acc
      ON SUBSTRING(Cobza.Asignacion_ID,3,10)=Acc.ClearingDocNumber
     AND Acc.FiscalYear=@Ejercicio
    JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=Cobza.Factura
    WHERE Cobza.Fecha_Proceso>@Limite AND Cobza.Asignacion_Central IS NULL
      AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Entrega
      AND ISNULL(Acc.Assignment,RF.Entrega)<>'B001 - Bank I'
      AND ISNULL(Acc.Assignment,RF.Entrega)<>Cobza.Factura+','
      AND ISNULL(Acc.Assignment,RF.Entrega) NOT LIKE '1-1%'
      AND ISNULL(Acc.Assignment,RF.Entrega)<>RF.Referencia
)
INSERT @Ambiguas
SELECT TOP(20) Asignacion_ID,Factura,COUNT_BIG(*)
FROM Alternativas GROUP BY Asignacion_ID,Factura HAVING COUNT_BIG(*)>1;
IF EXISTS(SELECT 1 FROM @Ambiguas)
BEGIN
    SELECT '03_ASIGNACIONES_AMBIGUAS' Seccion,* FROM @Ambiguas;
    THROW 57305,'Hay varias asignaciones elegibles para una cobranza. No se creo el indice; revisar las coincidencias antes de continuar.',1;
END;
SELECT '03_COINCIDENCIAS_REVISADAS' Seccion,
    'Sin valores Assignment diferentes elegibles para una misma cobranza en el alcance actual.' Mensaje;

-- Opciones de sesion correctas para las tablas que ya poseen indices filtrados.
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
EXEC sys.sp_executesql @DDL;
SELECT '04_INDICE_CREADO' Seccion,@Nombre Indice,SYSDATETIMEOFFSET() Finalizacion,
    'Se creo solo el indice. El procedimiento no fue ejecutado.' Mensaje;
SELECT '05_REVERSION_SOLO_TEXTO' Seccion,
    'DROP INDEX [IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC] ON [T3].[CFDI_COBRANZA];' DDL;
