/* Seleccion inicial basada en diagnostico de T3QA del 2026-10-09 10:43.
   Primer ensayo: SOLO Factura_General y Factura_Detalle.
   25,289,742 cabeceras y 91,612,849 detalles: programar creacion con capacidad
   de disco/log y ventana de mantenimiento; CREATE INDEX puede bloquear.
   No elimina, reemplaza ni habilita indices existentes.
   Por defecto muestra la propuesta. Cambiar @Aplicar a 1 para crear.
   Ejecutar en la base objetivo; no incluye USE para evitar cambiar de base
   inadvertidamente. Ver BaseActual en la salida antes de aplicar.
   No hay transaccion conjunta: si el segundo falla, el primero permanece.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @Aplicar bit = 0;
SELECT DB_NAME() AS BaseActual, @Aplicar AS Aplicar;

DECLARE @P table (Id int PRIMARY KEY, Tabla sysname, Nombre sysname, DDL nvarchar(max));
INSERT @P VALUES
(1,N'Factura_General',N'IX_OI_FG_TipoFecha',
 N'CREATE NONCLUSTERED INDEX [IX_OI_FG_TipoFecha] ON [T3].[Factura_General] ([Tipo_Docto],[Fecha_Factura]) INCLUDE ([Factura],[Cliente_SAP],[Ctro]);'),
(2,N'Factura_Detalle',N'IX_OI_FD_Factura',
 N'CREATE NONCLUSTERED INDEX [IX_OI_FD_Factura] ON [T3].[Factura_Detalle] ([Factura]) INCLUDE ([Valor_Subt],[Valor_IVA],[Credito_Subt],[Credito_IVA],[Envio_Subt],[Envio_IVA]);');

-- Ordinal 0: basta que este almacenada como clave o INCLUDE.
-- Ordinal positivo: debe ser esa posicion inicial de la clave del indice.
DECLARE @R table (Id int, Columna sysname, Ordinal int);
INSERT @R VALUES
(1,N'Tipo_Docto',1),(1,N'Fecha_Factura',2),(1,N'Factura',0),(1,N'Cliente_SAP',0),(1,N'Ctro',0),
(2,N'Factura',1),(2,N'Valor_Subt',0),(2,N'Valor_IVA',0),(2,N'Credito_Subt',0),
(2,N'Credito_IVA',0),(2,N'Envio_Subt',0),(2,N'Envio_IVA',0);

DECLARE @Id int=1,@Tabla sysname,@Nombre sysname,@DDL nvarchar(max),
        @Objeto int,@Equivalente sysname,@Mensaje nvarchar(2048);
WHILE @Id<=2
BEGIN
    SELECT @Tabla=Tabla,@Nombre=Nombre,@DDL=DDL FROM @P WHERE Id=@Id;
    SET @Objeto=OBJECT_ID(N'T3.'+QUOTENAME(@Tabla),N'U');
    IF @Objeto IS NULL THROW 51000,'No existe la tabla objetivo en la base actual.',1;
    SET @Equivalente=NULL;
    -- Revalidar en el servidor: omitir si otro nombre ya cubre estas columnas.
    -- Solo indices completos, activos y reales; uno filtrado no es equivalente
    -- automaticamente. La comprobacion es conservadora para claves implicitas.
    SELECT TOP (1) @Equivalente=I.name
    FROM sys.indexes I
    WHERE I.object_id=@Objeto AND I.type IN (1,2)
      AND I.is_disabled=0 AND I.is_hypothetical=0 AND I.has_filter=0
      AND NOT EXISTS
      (
        SELECT 1 FROM @R R WHERE R.Id=@Id AND NOT EXISTS
        (
          SELECT 1 FROM sys.index_columns IC
          JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
          WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id
            -- Catalogo y tabla variable pueden tener collations distintas.
            -- Normalizar solo los nombres comparados, sin alterar tablas/datos.
            AND C.name COLLATE DATABASE_DEFAULT = R.Columna COLLATE DATABASE_DEFAULT
            AND (R.Ordinal=0 OR IC.key_ordinal=R.Ordinal)
        )
      )
    ORDER BY I.index_id;
    IF @Equivalente IS NOT NULL
        SELECT @Tabla AS Tabla,N'OMITIDO: cobertura existente' AS Accion,@Equivalente AS Indice;
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=@Objeto
                   AND name COLLATE DATABASE_DEFAULT = @Nombre COLLATE DATABASE_DEFAULT)
        BEGIN
            SET @Mensaje=N'El nombre '+@Nombre+N' ya existe pero no cumple la cobertura o esta deshabilitado. Revisar manualmente.';
            THROW 51001,@Mensaje,1;
        END;
        SELECT @Tabla AS Tabla,CASE WHEN @Aplicar=1 THEN N'CREAR' ELSE N'PROPUESTA' END AS Accion,@DDL AS Script;
        IF @Aplicar=1
        BEGIN
            RAISERROR('Creando %s...',10,1,@Nombre) WITH NOWAIT;
            EXEC sys.sp_executesql @DDL;
            RAISERROR('Indice %s creado.',10,1,@Nombre) WITH NOWAIT;
        END;
    END;
    SET @Id+=1;
END;
