/*
  Migracion de PK Oracle -> SQL Server, esquema T3. Fuente: PKS_ORACLE_T3.txt.
  Conserva nombre y orden de columnas; no infiere PK para otras tablas.
  @Aplicar=0: SOLO diagnostico y propuesta de DDL, sin cambios permanentes.
  @Aplicar=1: prevalida todas las PK seleccionadas; si alguna esta bloqueada,
  no aplica ninguna. Si estan listas, aplica una transaccion por tabla.
  Si un DDL falla, revierte esa tabla y detiene el lote; las anteriores quedan
  aplicadas. Puede reejecutarse: reconoce PK equivalentes ya existentes.

  @SoloTabla permite seleccionar una de las tablas de la lista Oracle.
  @ConvertirColumnasANotNull=1 prepara ALTER COLUMN para columnas NULLABLE,
  pero solo si sus datos actuales no contienen NULL. Conserva tipo, longitud,
  precision/escala y collation de la base destino. No rellena ni elimina datos.
  Se elige PRIMARY KEY NONCLUSTERED para no sustituir el indice clustered.
  Cambios sobre tablas activas pueden bloquear; ejecutar DDL sin escritores
  concurrentes. El motor vuelve a validar los datos al crear la restriccion.
  El diagnostico agrupa segun la collation SQL Server de cada columna.
*/
USE [T3QA];
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @Aplicar bit=0;
DECLARE @SoloTabla sysname=NULL; -- Ejemplo: N'MATERIAL'. NULL = todas.
DECLARE @ConvertirColumnasANotNull bit=1;

DECLARE @Origen table(
    Tabla sysname COLLATE DATABASE_DEFAULT NOT NULL,
    NombrePK sysname COLLATE DATABASE_DEFAULT NOT NULL,
    Posicion int NOT NULL,
    Columna sysname COLLATE DATABASE_DEFAULT NOT NULL,
    PRIMARY KEY(Tabla,Posicion));
--__SEED__

IF @SoloTabla IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Origen WHERE Tabla=@SoloTabla)
    THROW 56800,'@SoloTabla no pertenece al listado Oracle proporcionado.',1;
IF @Aplicar=1 AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2)
    THROW 56801,'Aplicar sin transaccion externa y con IMPLICIT_TRANSACTIONS OFF.',1;

SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura,@Aplicar Aplicar,
       @SoloTabla SoloTabla,@ConvertirColumnasANotNull ConvertirColumnasANotNull,
       (SELECT COUNT(DISTINCT Tabla) FROM @Origen) PKEnArchivoOrigen,
       (SELECT COUNT(*) FROM @Origen) ColumnasEnArchivoOrigen;

DECLARE @Plan table(
    Id int NOT NULL PRIMARY KEY,Tabla sysname COLLATE DATABASE_DEFAULT NOT NULL,
    NombrePK sysname COLLATE DATABASE_DEFAULT NOT NULL,Columnas nvarchar(max) NULL,
    Estado varchar(40) COLLATE DATABASE_DEFAULT NOT NULL DEFAULT 'PENDIENTE',
    Observacion nvarchar(2000) NULL,ColumnasNullable int NULL,
    FilasConNull bigint NULL,GruposDuplicados bigint NULL,BytesMaximosClave int NULL,
    SQLPropuesto nvarchar(max) NULL,SQLDiagnostico nvarchar(max) NULL);
INSERT @Plan(Id,Tabla,NombrePK)
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY Tabla)),Tabla,NombrePK
FROM @Origen WHERE @SoloTabla IS NULL OR Tabla=@SoloTabla GROUP BY Tabla,NombrePK;

DECLARE @Meta table(
    Posicion int NOT NULL PRIMARY KEY,Columna sysname COLLATE DATABASE_DEFAULT NOT NULL,
    TipoBase sysname COLLATE DATABASE_DEFAULT NOT NULL,TipoDDL nvarchar(400) NOT NULL,
    CollationName sysname COLLATE DATABASE_DEFAULT NULL,Nullable bit NOT NULL,
    BytesColumna int NOT NULL,NoSoportada bit NOT NULL);
DECLARE @Id int,@Tabla sysname,@PK sysname,@Objeto int,@Nombre nvarchar(520),
        @Columnas nvarchar(max),@PredicadoNull nvarchar(max),@Alter nvarchar(max),
        @DDL nvarchar(max),@SQL nvarchar(max),@SQLDiagnostico nvarchar(max),
        @PKActual sysname,@ColumnasActuales nvarchar(max),@IndicePK int,
        @Nullable int,@Bytes int,@FilasNull bigint,@Duplicados bigint,
        @Error nvarchar(2000),@Orden int,@Columna sysname,@TipoDDL nvarchar(400),@Collation sysname,
        @DefAntes nvarchar(max),@DefDespues nvarchar(max);

DECLARE Claves CURSOR LOCAL STATIC READ_ONLY FOR
SELECT Id,Tabla,NombrePK FROM @Plan ORDER BY Id;
OPEN Claves;
FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Nombre=QUOTENAME(N'T3')+N'.'+QUOTENAME(@Tabla);
    SET @Objeto=OBJECT_ID(@Nombre,N'U');
    SELECT @Columnas=STUFF((SELECT N','+QUOTENAME(O.Columna)
        FROM @Origen O WHERE O.Tabla=@Tabla ORDER BY O.Posicion
        FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
    UPDATE @Plan SET Columnas=@Columnas WHERE Id=@Id;
    BEGIN TRY
        IF @Objeto IS NULL
            THROW 56810,'Tabla ausente o no visible en el esquema T3 de la base destino.',1;
        DELETE @Meta;
        INSERT @Meta(Posicion,Columna,TipoBase,TipoDDL,CollationName,Nullable,BytesColumna,NoSoportada)
        SELECT O.Posicion,C.name,B.name,
            CASE WHEN U.user_type_id<>U.system_type_id THEN QUOTENAME(SCHEMA_NAME(U.schema_id))+N'.'+QUOTENAME(U.name)
                 ELSE QUOTENAME(B.name)+CASE
                   WHEN B.name IN ('varchar','char','varbinary','binary')
                     THEN N'('+CASE WHEN C.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(10),C.max_length) END+N')'
                   WHEN B.name IN ('nvarchar','nchar')
                     THEN N'('+CASE WHEN C.max_length=-1 THEN N'max' ELSE CONVERT(nvarchar(10),C.max_length/2) END+N')'
                   WHEN B.name IN ('decimal','numeric')
                     THEN N'('+CONVERT(nvarchar(10),C.precision)+N','+CONVERT(nvarchar(10),C.scale)+N')'
                   WHEN B.name IN ('datetime2','datetimeoffset','time')
                     THEN N'('+CONVERT(nvarchar(10),C.scale)+N')'
                   WHEN B.name='float' THEN N'('+CONVERT(nvarchar(10),C.precision)+N')'
                   ELSE N'' END END,
            -- Los tipos alias conservan su propia collation: SQL Server no
            -- admite una clausula COLLATE al usarlos en ALTER COLUMN.
            CASE WHEN U.user_type_id<>U.system_type_id THEN NULL ELSE C.collation_name END,
            C.is_nullable,C.max_length,
            CASE WHEN C.is_computed=1 OR C.is_sparse=1 OR C.is_column_set=1 OR C.is_filestream=1
                   OR C.generated_always_type<>0 OR C.encryption_type IS NOT NULL OR C.max_length=-1
                   OR B.name NOT IN ('varchar','char','nvarchar','nchar','varbinary','binary',
                     'decimal','numeric','bigint','int','smallint','tinyint','bit','money','smallmoney',
                     'float','real','date','datetime','smalldatetime','datetime2','datetimeoffset','time','uniqueidentifier')
                 THEN 1 ELSE 0 END
        FROM @Origen O
        JOIN sys.columns C ON C.object_id=@Objeto AND C.name COLLATE DATABASE_DEFAULT=O.Columna
        JOIN sys.types B ON B.user_type_id=C.system_type_id AND B.user_type_id=B.system_type_id
        JOIN sys.types U ON U.user_type_id=C.user_type_id
        WHERE O.Tabla=@Tabla;
        IF (SELECT COUNT(*) FROM @Meta)<>(SELECT COUNT(*) FROM @Origen WHERE Tabla=@Tabla)
            THROW 56811,'Faltan columnas de la clave Oracle o no se pudo resolver su tipo.',1;

        -- Reconocer equivalencia por columnas en el mismo orden, no solo por nombre.
        SET @PKActual=NULL;
        SET @IndicePK=NULL;
        SELECT @PKActual=K.name,@IndicePK=K.unique_index_id
        FROM sys.key_constraints K WHERE K.parent_object_id=@Objeto AND K.type='PK';
        IF @PKActual IS NOT NULL
        BEGIN
            SELECT @ColumnasActuales=STUFF((SELECT N','+QUOTENAME(C.name)
                FROM sys.index_columns IC JOIN sys.columns C
                  ON C.object_id=IC.object_id AND C.column_id=IC.column_id
                WHERE IC.object_id=@Objeto AND IC.index_id=@IndicePK AND IC.key_ordinal>0
                ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
            IF @ColumnasActuales COLLATE DATABASE_DEFAULT<>@Columnas COLLATE DATABASE_DEFAULT
                THROW 56812,'La tabla ya tiene una PK con columnas u orden diferentes. No se reemplaza.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Objeto AND index_id=@IndicePK AND is_disabled=1)
                THROW 56813,'La PK equivalente existe pero su indice esta deshabilitado; requiere revision.',1;
            UPDATE @Plan SET Estado='YA_EXISTE_EQUIVALENTE',
                Observacion=N'PK actual: '+QUOTENAME(@PKActual)+N'. Se conserva su nombre e indice.' WHERE Id=@Id;
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Objeto AND (is_memory_optimized=1 OR is_filetable=1))
                THROW 56814,'Tabla especial: no se aplica DDL automatico de PK rowstore.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.data_spaces D ON D.data_space_id=I.data_space_id
                      WHERE I.object_id=@Objeto AND I.index_id IN(0,1) AND D.type='PS')
                THROW 56815,'Tabla particionada: revisar colocacion del indice y columnas de particion.',1;
            IF EXISTS(SELECT 1 FROM @Meta WHERE NoSoportada=1)
                THROW 56816,'Tipo MAX/especial o atributo de columna no admitido por este script; revisar manualmente.',1;
            IF OBJECT_ID(QUOTENAME(N'T3')+N'.'+QUOTENAME(@PK)) IS NOT NULL
                THROW 56817,'El nombre de la restriccion ya esta ocupado por otro objeto de T3.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@Objeto AND name COLLATE DATABASE_DEFAULT=@PK)
                THROW 56818,'Ya existe un indice con ese nombre; no se elimina ni se sustituye.',1;

            SELECT @Nullable=SUM(CONVERT(int,Nullable)),@Bytes=SUM(BytesColumna) FROM @Meta;
            UPDATE @Plan SET ColumnasNullable=@Nullable,BytesMaximosClave=@Bytes WHERE Id=@Id;
            IF @Bytes>900 OR (SELECT COUNT(*) FROM @Meta)>32
                THROW 56819,'La definicion excede el limite conservador de 900 bytes o 32 columnas para PK; revisar.',1;
            SELECT @PredicadoNull=STUFF((SELECT N' OR '+QUOTENAME(Columna)+N' IS NULL'
                FROM @Meta ORDER BY Posicion FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,4,N'');
            SET @SQL=N'SELECT @N=COUNT_BIG(*) FROM '+@Nombre+N' WHERE '+@PredicadoNull+N';
                SELECT @D=COUNT_BIG(*) FROM (SELECT 1 X FROM '+@Nombre+N' GROUP BY '+@Columnas+
                N' HAVING COUNT_BIG(*)>1) G;';
            SET @FilasNull=NULL;
            SET @Duplicados=NULL;
            EXEC sys.sp_executesql @SQL,N'@N bigint OUTPUT,@D bigint OUTPUT',@N=@FilasNull OUTPUT,@D=@Duplicados OUTPUT;
            SET @SQLDiagnostico=N'SELECT TOP(20) '+@Columnas+N' FROM '+@Nombre+N' WHERE '+@PredicadoNull+N';'+CHAR(13)+CHAR(10)+
                N'SELECT TOP(20) '+@Columnas+N',COUNT_BIG(*) AS Repeticiones FROM '+@Nombre+N' GROUP BY '+@Columnas+
                N' HAVING COUNT_BIG(*)>1 ORDER BY Repeticiones DESC;';
            UPDATE @Plan SET FilasConNull=@FilasNull,GruposDuplicados=@Duplicados,SQLDiagnostico=@SQLDiagnostico WHERE Id=@Id;
            IF @FilasNull>0 THROW 56820,'Existen filas con NULL en columnas de la PK; no se corrigen automaticamente.',1;
            IF @Duplicados>0 THROW 56821,'Existen combinaciones duplicadas segun los tipos/collation SQL Server.',1;
            IF @Nullable>0 AND @ConvertirColumnasANotNull=0
                THROW 56822,'Columnas declaradas NULL: requieren NOT NULL para crear la PK.',1;

            SET @Alter=N'';
            DECLARE ColumnasNull CURSOR LOCAL STATIC READ_ONLY FOR
            SELECT Posicion,Columna,TipoDDL,CollationName FROM @Meta WHERE Nullable=1 ORDER BY Posicion;
            OPEN ColumnasNull;
            FETCH NEXT FROM ColumnasNull INTO @Orden,@Columna,@TipoDDL,@Collation;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SQL=N'ALTER TABLE '+@Nombre+N' ALTER COLUMN '+QUOTENAME(@Columna)+N' '+@TipoDDL+
                    CASE WHEN @Collation IS NOT NULL THEN N' COLLATE '+@Collation ELSE N'' END+
                    N' NOT NULL;';
                -- Compilar cada ALTER despues del anterior. Si se compila el
                -- ADD PK junto con los ALTER, puede ver columnas aun NULL.
                SET @Alter+=N'EXEC sys.sp_executesql N'''+REPLACE(@SQL,N'''',N'''''')+N''';'+CHAR(13)+CHAR(10);
                FETCH NEXT FROM ColumnasNull INTO @Orden,@Columna,@TipoDDL,@Collation;
            END;
            CLOSE ColumnasNull;
            DEALLOCATE ColumnasNull;
            SET @SQL=N'ALTER TABLE '+@Nombre+N' ADD CONSTRAINT '+QUOTENAME(@PK)+
                N' PRIMARY KEY NONCLUSTERED ('+@Columnas+N');';
            SET @DDL=@Alter+N'EXEC sys.sp_executesql N'''+REPLACE(@SQL,N'''',N'''''')+N''';';
            UPDATE @Plan SET Estado='LISTA',Observacion=N'Datos actuales validos; DDL preparado con metadatos destino.',
                SQLPropuesto=@DDL WHERE Id=@Id;
        END;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','ColumnasNull')>=0 CLOSE ColumnasNull;
        IF CURSOR_STATUS('local','ColumnasNull')>=-1 DEALLOCATE ColumnasNull;
        UPDATE @Plan SET Estado='BLOQUEADA',Observacion=LEFT(CONCAT(ERROR_NUMBER(),N': ',ERROR_MESSAGE()),2000) WHERE Id=@Id;
    END CATCH;
    FETCH NEXT FROM Claves INTO @Id,@Tabla,@PK;
END;
CLOSE Claves;
DEALLOCATE Claves;

SELECT '01_PREVALIDACION' Seccion,* FROM @Plan ORDER BY Id;
SELECT '02_RESUMEN' Seccion,Estado,COUNT(*) Cantidad FROM @Plan GROUP BY Estado;
-- XML conserva el DDL completo y evita el truncamiento habitual del grid.
SELECT Tabla,NombrePK,SQLPropuesto FROM @Plan WHERE Estado='LISTA'
FOR XML PATH('Clave'),ROOT('DDLPropuesto'),TYPE;
IF @Aplicar=0
BEGIN
    SELECT 'VISTA PREVIA; NO SE CREARON PK NI SE CAMBIO NULLABILIDAD.' Resultado;
    RETURN;
END;
IF EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA')
    THROW 56830,'Hay PK bloqueadas. No se aplico ninguna; revisar 01_PREVALIDACION o seleccionar @SoloTabla.',1;

DECLARE Aplicacion CURSOR LOCAL STATIC READ_ONLY FOR
SELECT Id,Tabla,NombrePK,SQLPropuesto FROM @Plan WHERE Estado='LISTA' ORDER BY Id;
OPEN Aplicacion;
FETCH NEXT FROM Aplicacion INTO @Id,@Tabla,@PK,@DDL;
BEGIN TRY
    WHILE @@FETCH_STATUS=0
    BEGIN
        BEGIN TRANSACTION;
        SET @Objeto=OBJECT_ID(QUOTENAME(N'T3')+N'.'+QUOTENAME(@Tabla),N'U');
        SELECT @DefAntes=CONVERT(nvarchar(max),(
            SELECT C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name,C.is_identity
            FROM sys.columns C JOIN @Origen O ON O.Tabla=@Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT
            WHERE C.object_id=@Objeto ORDER BY O.Posicion
            FOR XML PATH('Columna'),ROOT('Definicion'),TYPE));
        EXEC sys.sp_executesql @DDL;
        SELECT @DefDespues=CONVERT(nvarchar(max),(
            SELECT C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name,C.is_identity
            FROM sys.columns C JOIN @Origen O ON O.Tabla=@Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT
            WHERE C.object_id=@Objeto ORDER BY O.Posicion
            FOR XML PATH('Columna'),ROOT('Definicion'),TYPE));
        IF HASHBYTES('SHA2_256',@DefAntes)<>HASHBYTES('SHA2_256',@DefDespues)
            THROW 56832,'Cambio inesperado en tipo/longitud/precision/escala/collation/identidad; se revierte la tabla.',1;
        COMMIT TRANSACTION;
        UPDATE @Plan SET Estado='CREADA',Observacion=N'PK creada y cambios NOT NULL confirmados para esta tabla.' WHERE Id=@Id;
        FETCH NEXT FROM Aplicacion INTO @Id,@Tabla,@PK,@DDL;
    END;
    CLOSE Aplicacion;
    DEALLOCATE Aplicacion;
END TRY
BEGIN CATCH
    SET @Error=LEFT(CONCAT(N'Tabla ',QUOTENAME(@Tabla),N'; PK ',QUOTENAME(@PK),N'; ',ERROR_NUMBER(),N': ',ERROR_MESSAGE()),2000);
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF CURSOR_STATUS('local','Aplicacion')>=0 CLOSE Aplicacion;
    IF CURSOR_STATUS('local','Aplicacion')>=-1 DEALLOCATE Aplicacion;
    UPDATE @Plan SET Estado='ERROR_DDL_REVERTIDO',Observacion=@Error WHERE Id=@Id;
    SELECT '03_RESULTADO_APLICACION' Seccion,* FROM @Plan ORDER BY Id;
    THROW 56831,@Error,1;
END CATCH;
SELECT '03_RESULTADO_APLICACION' Seccion,* FROM @Plan ORDER BY Id;
SELECT 'APLICACION TERMINADA. No se eliminaron filas ni indices anteriores.' Resultado;
