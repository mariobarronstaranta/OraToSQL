/*
  Segunda correccion: busqueda de material del cursor curSKU en SF_PROC_PREINVOICE_IFC.
  T3QA, aplicar como administrador al terminar el lote, sin otras ejecuciones/despliegues.
  Cambia una declaracion de cursor: acceso VARCHAR cuando la conversion es sin perdida;
  conserva consulta original como alternativa, proyeccion GETCONV y el cuerpo del cursor.
  Mantiene los tres RI_REF_SEEK ya instalados. No cambia reglas de cantidades/UM ni GETCONV.
  Reutiliza el respaldo atomico EAI_OWNER.RECV_INVOICE_PERF_BACKUP. Guardar RunId.
  Reversa: 02_REVERTIR_REFERENCEID.sql con ESTE nuevo RunId; restaura la version con RI_REF_SEEK.
  No crea indices, no inicia facturas ni modifica estados de mensajes.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @Revertir bit=0;
IF DB_NAME()<>N'T3QA' THROW 51940,'Seleccionar la base T3QA.',1;
IF @@TRANCOUNT<>0 THROW 51941,'Ejecutar fuera de una transaccion externa.',1;
DECLARE @sql nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'));
IF @sql IS NULL THROW 51942,'Procedimiento ausente, cifrado o sin permiso VIEW DEFINITION.',1;
-- Preservar la definicion instalada: no se carga el archivo base del repositorio.
IF (2 & @@OPTIONS)=2
 THROW 52610,'Ejecutar sin transacciones implicitas.',1;
IF @Revertir=1
 THROW 52611,'Para revertir usar 02_REVERTIR_REFERENCEID.sql con el RunId correspondiente.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC')
          AND (uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 52612,'Las opciones SET instaladas requieren revision antes del ALTER.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1
          AND major_id=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'))
 THROW 52613,'Modulo firmado: preparar su refirma antes de ALTER. No se hicieron cambios.',1;
DECLARE @DefinicionOriginal nvarchar(max)=@sql,
        @ObjectId int=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'),
        @RunId uniqueidentifier=NEWID();
DECLARE @tablas table(Id int PRIMARY KEY,Nombre sysname);
INSERT @tablas VALUES(1,N'TMP_DOCUMENT_HEADER'),(2,N'TMP_DOCUMENT_DETAIL'),(3,N'TMP_DOCUMENT_CONDITIONS');
IF EXISTS(SELECT 1 FROM @tablas WHERE CHARINDEX(N'RI_REF_SEEK_'+Nombre,@sql)=0)
 THROW 52660,'Aplicar primero la correccion ReferenceID; no se altera el SP.',1;
IF CHARINDEX(N'RI_SKU_SEEK_V1',@sql)>0
BEGIN
 IF CHARINDEX(N'RI_SKU_SEEK_END_V1',@sql)=0
  THROW 52661,'Marcador SKU incompleto; revisar antes de aplicar.',1;
 PRINT 'Sin cambios: la correccion SKU ya esta presente.';
 RETURN;
END;
DECLARE @MaterialId int=OBJECT_ID(N'T3.MATERIAL',N'U'),
        @ColMaterial int=COLUMNPROPERTY(OBJECT_ID(N'T3.MATERIAL'),N'MATERIAL',N'ColumnId');
IF NOT EXISTS(SELECT 1 FROM sys.columns
 WHERE object_id=@MaterialId AND column_id=@ColMaterial
   AND TYPE_NAME(system_type_id)=N'varchar' AND max_length=18
   AND collation_name=CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation')))
 THROW 52662,'Se esperaba MATERIAL VARCHAR(18) con la collation de esta base.',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes I INNER JOIN sys.index_columns C
 ON C.object_id=I.object_id AND C.index_id=I.index_id
 WHERE I.object_id=@MaterialId AND I.type IN(1,2) AND I.is_disabled=0 AND I.has_filter=0
   AND C.key_ordinal=1 AND C.column_id=@ColMaterial)
 THROW 52663,'No hay indice habilitado inicial por MATERIAL; revisar acceso antes del parche.',1;
DECLARE @pos int=CHARINDEX(N'DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR',@sql),
 @fin int,@old nvarchar(max),@fast nvarchar(max),@new nvarchar(max),@where int,
 @norm nvarchar(max),@cambios int=1;
IF @pos=0 OR CHARINDEX(N'DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR',@sql,@pos+1)>0
 THROW 52664,'Se esperaba una sola declaracion original de curSKU.',1;
SET @fin=CHARINDEX(N';',@sql,@pos);
IF @fin=0 THROW 52665,'Declaracion SKU sin final reconocido.',1;
SET @old=SUBSTRING(@sql,@pos,@fin-@pos+1);
SET @where=CHARINDEX(N'WHERE',@old);
IF @where=0 THROW 52666,'Consulta SKU sin WHERE reconocido.',1;
SET @norm=REPLACE(REPLACE(REPLACE(REPLACE(SUBSTRING(@old,@where,LEN(@old)),N' ',N''),CHAR(13),N''),CHAR(10),N''),CHAR(9),N'');
IF @norm<>N'WHERESKU.MATERIAL=@sMaterialUOM;'
 THROW 52667,'El predicado SKU tiene otra logica. No se aplica automaticamente.',1;
SET @fast=LEFT(@old,@where-1)+N'WHERE SKU.MATERIAL = CONVERT(varchar(18),@sMaterialUOM)
                          AND CONVERT(nvarchar(50),SKU.MATERIAL) = @sMaterialUOM;';
SET @new=N'/* RI_SKU_SEEK_V1 */
                    -- Clave VARCHAR para buscar; conservar Unicode y la consulta original si hay perdida.
                    IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(18),@sMaterialUOM)))
                       = CONVERT(varbinary(max),@sMaterialUOM)
                    BEGIN
'+@fast+N'
                    END
                    ELSE
                    BEGIN
'+@old+N'
                    END;
                    /* RI_SKU_SEEK_END_V1 */';
SET @sql=STUFF(@sql,@pos,@fin-@pos+1,@new);
DECLARE @decl int=CHARINDEX(N'PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]',@sql),
        @linea int,@prefijo nvarchar(max);
IF @decl=0 THROW 52668,'Declaracion PROCEDURE no reconocida.',1;
SET @linea=CASE WHEN CHARINDEX(CHAR(10),REVERSE(LEFT(@sql,@decl-1)))=0 THEN 1
 ELSE @decl-CHARINDEX(CHAR(10),REVERSE(LEFT(@sql,@decl-1)))+1 END;
SET @prefijo=REPLACE(REPLACE(REPLACE(SUBSTRING(@sql,@linea,@decl-@linea),N' ',N''),CHAR(9),N''),CHAR(13),N'');
IF @prefijo NOT IN(N'CREATE',N'ALTER',N'CREATEORALTER')
 THROW 52668,'Prefijo PROCEDURE no reconocido.',1;
SET @sql=STUFF(@sql,@linea,@decl-@linea,N'ALTER ');
DECLARE @AlterOriginal nvarchar(max)=STUFF(@DefinicionOriginal,@linea,@decl-@linea,N'ALTER '),
        @XactAbortOriginal bit=IIF((@@OPTIONS & 16384)=16384,1,0);
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@ObjectId
               AND CONVERT(varbinary(max),definition)=CONVERT(varbinary(max),@DefinicionOriginal))
  THROW 52614,'La definicion cambio despues del preflight. No se aplica el parche.',1;
 IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_PERF_BACKUP',N'U') IS NULL
 BEGIN
  CREATE TABLE EAI_OWNER.RECV_INVOICE_PERF_BACKUP
  (RunId uniqueidentifier NOT NULL,ObjectId int NOT NULL,
   Nombre nvarchar(256) COLLATE DATABASE_DEFAULT NOT NULL,
   FechaAplicacion datetime2(3) NOT NULL,LoginAplicacion sysname COLLATE DATABASE_DEFAULT NULL,
   DefinicionOriginal nvarchar(max) NOT NULL,AlterOriginal nvarchar(max) NOT NULL,
   HashOriginal varbinary(32) NOT NULL,HashAplicado varbinary(32) NULL,
   FechaReversion datetime2(3) NULL,
   CONSTRAINT PK_RECV_INVOICE_PERF_BACKUP PRIMARY KEY(RunId,ObjectId));
 END;
 INSERT EAI_OWNER.RECV_INVOICE_PERF_BACKUP
  (RunId,ObjectId,Nombre,FechaAplicacion,LoginAplicacion,DefinicionOriginal,AlterOriginal,HashOriginal)
 VALUES(@RunId,@ObjectId,N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',SYSDATETIME(),ORIGINAL_LOGIN(),
        @DefinicionOriginal,@AlterOriginal,HASHBYTES('SHA2_256',@DefinicionOriginal));
 EXEC sys.sp_executesql @sql;
 IF EXISTS(SELECT 1 FROM @tablas WHERE
           CHARINDEX(N'RI_REF_SEEK_'+Nombre,OBJECT_DEFINITION(@ObjectId))=0)
  THROW 52615,'No aparecen las tres marcas tras ALTER; se revierte el cambio.',1;
 IF CHARINDEX(N'RI_SKU_SEEK_V1',OBJECT_DEFINITION(@ObjectId))=0
  THROW 52669,'No se encontro la marca SKU tras ALTER; se revierte.',1;
 UPDATE EAI_OWNER.RECV_INVOICE_PERF_BACKUP
 SET HashAplicado=HASHBYTES('SHA2_256',OBJECT_DEFINITION(@ObjectId))
 WHERE RunId=@RunId AND ObjectId=@ObjectId;
 COMMIT TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
        @cambios AS BloquesModificados,
        N'Parche SKU aplicado con respaldo; pendiente medir el siguiente lote.' AS Resultado;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;
