/*
  Indices para los tres reportes de MSSQL/T3/Procesos/Ventas.
  Destino: AZCRNMXNEVTD06 / T3QA. Ejecutar una vez en SSMS o sqlcmd -b.
  No requiere modificar los BAT ni los Extract.sql. No contiene credenciales.

  Propuesta basada en los filtros y JOIN de los reportes; validar IO, tiempo
  y planes reales antes/despues con periodos representativos.
  Crear en una ventana de mantenimiento: CREATE INDEX puede bloquear y
  consumir espacio y log. Requiere ALTER sobre las tablas y visibilidad
  de sus metadatos. No elimina ni reconstruye indices existentes.

  Omite indices habilitados con las mismas claves iniciales (ASC), cobertura
  suficiente y filtro equivalente al propuesto. Tambien admite un indice
  sin filtro que cubra la propuesta filtrada, incluidas sus columnas de filtro.
  La equivalencia de filtros se compara por texto normalizado, no mediante
  demostracion logica; revisar manualmente otros filtros/ordenes de claves.
  Si el nombre propuesto existe con otra definicion, se detiene para revision.
  No usa una transaccion global: si falla, los indices ya creados permanecen.
  Se puede volver a ejecutar despues de resolver la causa del error.
  Las comparaciones de nombres usan DATABASE_DEFAULT para evitar el error
  468 cuando el catalogo y los valores de OPENJSON tienen distinta collation.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @Propuestas TABLE (
    Id int PRIMARY KEY,
    Tabla sysname NOT NULL,
    Nombre sysname NOT NULL,
    Claves nvarchar(1000) NOT NULL,
    Incluidas nvarchar(2000) NOT NULL,
    Filtro nvarchar(1000) NULL
);

-- Fechas distintas: CFDI filtra FECHA_FACTURA y Felipe FECHA_DOCUMENTO.
INSERT INTO @Propuestas VALUES
(1,N'REGISTRO_FISCAL',N'IX_Ventas_RF_FechaFactura_Tipo',
 N'["FECHA_FACTURA","TIPO_DOCTO"]',
 N'["FACTURA","ENTREGA","STATUS","CLIENTE_SAP"]',NULL),
(2,N'REGISTRO_FISCAL',N'IX_Ventas_RF_FechaDocumento_Tipo',
 N'["FECHA_DOCUMENTO","TIPO_DOCTO"]',
 N'["FACTURA","ENTREGA","STATUS"]',NULL),
-- Un solo indice de detalle cubre las tres variantes, incluidas bonificaciones.
(3,N'REGISTRO_FISCAL_DETALLE',N'IX_Ventas_RFD_Factura',
 N'["FACTURA"]',
 N'["VALOR_SUBT","VALOR_IVA","ENVIO_SUBT","ENVIO_IVA","CREDITO_SUBT","CREDITO_IVA","BONIF_SUBT","BONIF_IVA"]',NULL),
(4,N'CFDI_COBRANZA',N'IX_Ventas_Cobranza_IncobrableNC',
 N'["NOTA_CREDITO"]',N'["IMPORTE","FACTURA","VIA_PAGO"]',
 N'[FACTURA] = ''INCOBRABLE'' AND [VIA_PAGO] = ''AI'' AND [NOTA_CREDITO] IS NOT NULL'),
(5,N'CLIENTE',N'IX_Ventas_Cliente_SAP_Vigencia',
 N'["CLIENTE_SAP","FECHA_INI_VIG"]',N'["FECHA_FIN_VIG","NOMBRE","RFC"]',NULL),
(6,N'CFDI_HISTORIA_DOCTO_PAC',N'IX_Ventas_PAC_NotaVenta',
 N'["NOTA_VENTA"]',N'["NOTA_VENTA_CFDI"]',NULL),
(7,N'CFDI_DOCUMENTOS',N'IX_Ventas_CFDI_NotaVenta',
 N'["NOTA_VENTA"]',N'["FECHA_ENVIO","FECHA_TIMBRE","FECHA_DOCUMENTO","FOLIO_FISCAL"]',NULL),
(8,N'CFDI_DOCUMENTO_PASO',N'IX_Ventas_Paso_Factura',
 N'["FACTURA"]',N'["VOIDDOC"]',NULL);

-- Comprobar todas las tablas/columnas antes de crear el primer indice.
IF EXISTS (
    SELECT 1 FROM @Propuestas P
    WHERE OBJECT_ID(N'[T3].'+QUOTENAME(P.Tabla),N'U') IS NULL
)
    THROW 51200,'Falta una tabla T3 requerida o no es visible para esta cuenta.',1;

IF EXISTS (
    SELECT 1 FROM @Propuestas P
    CROSS APPLY (
        SELECT value FROM OPENJSON(P.Claves)
        UNION ALL SELECT value FROM OPENJSON(P.Incluidas)
    ) C
    WHERE NOT EXISTS (
        SELECT 1 FROM sys.columns SC
        WHERE SC.object_id=OBJECT_ID(N'[T3].'+QUOTENAME(P.Tabla))
          AND SC.name COLLATE DATABASE_DEFAULT=C.value COLLATE DATABASE_DEFAULT
    )
)
    THROW 51201,'Falta una columna requerida. Revisar las definiciones en destino.',1;

DECLARE @Id int=1, @Tabla sysname, @Nombre sysname, @Claves nvarchar(1000),
        @Incluidas nvarchar(2000), @Filtro nvarchar(1000), @Objeto int,
        @Equivalente sysname, @ListaClaves nvarchar(max),
        @ListaIncluidas nvarchar(max), @SQL nvarchar(max), @Mensaje nvarchar(2048);
DECLARE @Resultado TABLE (Tabla sysname, Indice sysname, Accion varchar(20));

WHILE @Id <= 8
BEGIN
    SELECT @Tabla=Tabla,@Nombre=Nombre,@Claves=Claves,
           @Incluidas=Incluidas,@Filtro=Filtro
    FROM @Propuestas WHERE Id=@Id;
    SET @Objeto=OBJECT_ID(N'[T3].'+QUOTENAME(@Tabla));
    SET @Equivalente=NULL;

    SELECT TOP (1) @Equivalente=I.name
    FROM sys.indexes I
    WHERE I.object_id=@Objeto AND I.type IN (1,2)
      AND I.is_disabled=0 AND I.is_hypothetical=0
      AND (I.has_filter=0 OR (@Filtro IS NOT NULL AND
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(I.filter_definition,
             N'[',N''),N']',N''),N'(',N''),N')',N''),N' ',N'') COLLATE Latin1_General_100_BIN2
          = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Filtro,
             N'[',N''),N']',N''),N'(',N''),N')',N''),N' ',N'') COLLATE Latin1_General_100_BIN2))
      AND NOT EXISTS (
          SELECT 1 FROM OPENJSON(@Claves) K
          WHERE NOT EXISTS (
              SELECT 1 FROM sys.index_columns IC
              JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
              WHERE IC.object_id=@Objeto AND IC.index_id=I.index_id
                AND IC.key_ordinal=CONVERT(int,K.[key])+1
                AND IC.is_descending_key=0
                AND C.name COLLATE DATABASE_DEFAULT=K.value COLLATE DATABASE_DEFAULT
          )
      )
      AND NOT EXISTS (
          SELECT 1 FROM OPENJSON(@Incluidas) N
          WHERE I.type<>1 AND NOT EXISTS (
              SELECT 1 FROM sys.index_columns IC
              JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
              WHERE IC.object_id=@Objeto AND IC.index_id=I.index_id
                AND C.name COLLATE DATABASE_DEFAULT=N.value COLLATE DATABASE_DEFAULT
          ) AND NOT EXISTS (
              -- La clave clustered esta disponible implicitamente en el nonclustered.
              SELECT 1 FROM sys.indexes CI
              JOIN sys.index_columns IC ON IC.object_id=CI.object_id AND IC.index_id=CI.index_id
              JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
              WHERE CI.object_id=@Objeto AND CI.type=1 AND CI.is_disabled=0
                AND IC.key_ordinal>0
                AND C.name COLLATE DATABASE_DEFAULT=N.value COLLATE DATABASE_DEFAULT
          )
      )
    ORDER BY CASE WHEN I.name COLLATE DATABASE_DEFAULT=@Nombre COLLATE DATABASE_DEFAULT THEN 0 ELSE 1 END,I.index_id;

    IF @Equivalente IS NOT NULL
    BEGIN
        PRINT N'OMITIDO: T3.'+@Tabla+N'; cubierto por '+@Equivalente;
        INSERT INTO @Resultado VALUES (@Tabla,@Equivalente,'EXISTENTE');
    END
    ELSE
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=@Objeto
                   AND name COLLATE DATABASE_DEFAULT=@Nombre COLLATE DATABASE_DEFAULT)
        BEGIN
            SET @Mensaje=N'El indice '+@Nombre+N' existe con otra definicion o esta deshabilitado. Revisar antes de continuar.';
            THROW 51202,@Mensaje,1;
        END;
        SELECT @ListaClaves=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(value)),N', ')
            WITHIN GROUP (ORDER BY CONVERT(int,[key])) FROM OPENJSON(@Claves);
        SELECT @ListaIncluidas=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(value)),N', ')
            WITHIN GROUP (ORDER BY CONVERT(int,[key])) FROM OPENJSON(@Incluidas);
        SET @SQL=N'CREATE NONCLUSTERED INDEX '+QUOTENAME(@Nombre)
            +N' ON [T3].'+QUOTENAME(@Tabla)+N' ('+@ListaClaves+N') INCLUDE ('
            +@ListaIncluidas+N')'+CASE WHEN @Filtro IS NULL THEN N'' ELSE N' WHERE '+@Filtro END+N';';
        PRINT @SQL;
        EXEC sys.sp_executesql @SQL;
        INSERT INTO @Resultado VALUES (@Tabla,@Nombre,'CREADO');
    END;
    SET @Id+=1;
END;

SELECT N'T3' AS Esquema,Tabla,Indice,Accion FROM @Resultado ORDER BY Tabla,Indice;
GO
