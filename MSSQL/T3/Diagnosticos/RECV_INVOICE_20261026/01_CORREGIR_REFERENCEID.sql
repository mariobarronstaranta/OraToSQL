/*
  Correccion puntual de SF_PROC_PREINVOICE_IFC en T3QA, 26 de octubre de 2026.
  Ejecutar completo como administrador cuando termine el lote habitual,
  sin otras ejecuciones ni despliegues concurrentes de este flujo.
  Modifica solo los tres DELETE por ReferenceID; no crea indices ni reprocesa.
  Usa la definicion INSTALADA y guarda respaldo atomico en
  EAI_OWNER.RECV_INVOICE_PERF_BACKUP. Conservar el RunId del resultado.
  Ya aplicado: no vuelve a modificar ni crea otro respaldo.
  El formato o tipo distinto del esperado detiene el preflight sin ALTER.
  Conserva parametros, Unicode, reglas, transacciones y permisos del SP.
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
DECLARE @tablas table(Id int PRIMARY KEY, Nombre sysname);
INSERT @tablas VALUES(1,N'TMP_DOCUMENT_HEADER'),(2,N'TMP_DOCUMENT_DETAIL'),(3,N'TMP_DOCUMENT_CONDITIONS');
DECLARE @i int=1,@tabla sysname,@old nvarchar(max),@new nvarchar(max),@marker nvarchar(150),
 @pos int,@fin int,@norm nvarchar(max),@expected nvarchar(max),@cambios int=0;
WHILE @i<=3
BEGIN
 SELECT @tabla=Nombre FROM @tablas WHERE Id=@i;
 SET @marker=N'/* RI_REF_SEEK_'+@tabla+N' */';
 IF @Revertir=1
 BEGIN
   SET @pos=CHARINDEX(@marker,@sql);
   IF @pos>0
   BEGIN
     SET @fin=CHARINDEX(N'/* RI_REF_END_'+@tabla+N' */',@sql,@pos);
     IF @fin=0 THROW 51943,'Marcador final de parche ausente.',1;
     SET @fin+=LEN(N'/* RI_REF_END_'+@tabla+N' */');
     SET @old=N'DELETE FROM [EAI_OWNER].'+QUOTENAME(@tabla)+N' WHERE ReferenceID = @sReferenceID;';
     SET @sql=STUFF(@sql,@pos,@fin-@pos,@old);
     SET @cambios+=1;
   END;
 END
 ELSE IF CHARINDEX(@marker,@sql)=0
 BEGIN
   SET @pos=CHARINDEX(N'DELETE FROM [EAI_OWNER].'+QUOTENAME(@tabla),@sql);
   IF @pos=0 THROW 51944,'No se encontro el DELETE esperado. Revisar definicion desplegada.',1;
   SET @fin=CHARINDEX(N';',@sql,@pos);
   IF @fin=0 THROW 51945,'No se encontro el final del DELETE.',1;
   SET @old=SUBSTRING(@sql,@pos,@fin-@pos+1);
   SET @norm=REPLACE(REPLACE(REPLACE(REPLACE(@old,N' ',N''),CHAR(13),N''),CHAR(10),N''),CHAR(9),N'');
   SET @expected=N'DELETEFROM[EAI_OWNER].'+QUOTENAME(@tabla)+N'WHEREReferenceID=@sReferenceID;';
   IF @norm<>@expected THROW 51946,'El DELETE tiene otra logica. No se aplica el parche automaticamente.',1;
   IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'EAI_OWNER.'+@tabla)
      AND name=N'REFERENCEID' AND (TYPE_NAME(system_type_id)<>N'varchar' OR max_length<>50))
      OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'EAI_OWNER.'+@tabla) AND name=N'REFERENCEID')
      THROW 51947,'Se esperaba ReferenceID VARCHAR(50).',1;
   SET @new=@marker+N'
                IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(50),@sReferenceID)))
                   = CONVERT(varbinary(max),@sReferenceID)
                BEGIN
                    DELETE FROM [EAI_OWNER].'+QUOTENAME(@tabla)+N'
                    WHERE ReferenceID = CONVERT(varchar(50),@sReferenceID)
                      AND CONVERT(nvarchar(50),ReferenceID) = @sReferenceID;
                END
                ELSE
                BEGIN
                    '+@old+N'
                END;
                /* RI_REF_END_'+@tabla+N' */';
   SET @sql=STUFF(@sql,@pos,@fin-@pos+1,@new);
   SET @cambios+=1;
 END;
 SET @i+=1;
END;
IF @cambios=0
BEGIN
 PRINT 'Sin cambios: el procedimiento ya esta en el estado solicitado.';
 RETURN;
END;
-- ALTER conserva permisos. No se reemplaza el cuerpo por una copia local antigua.
-- SQL Server puede almacenar CREATE OR ALTER como CREATE con espacios.
DECLARE @decl int=CHARINDEX(N'PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]',@sql),@linea int,@prefijo nvarchar(max);
IF @decl=0
 THROW 51948,'Declaracion del modulo no reconocida.',1;
SET @linea=CASE WHEN CHARINDEX(CHAR(10),REVERSE(LEFT(@sql,@decl-1)))=0 THEN 1
 ELSE @decl-CHARINDEX(CHAR(10),REVERSE(LEFT(@sql,@decl-1)))+1 END;
SET @prefijo=REPLACE(REPLACE(REPLACE(SUBSTRING(@sql,@linea,@decl-@linea),N' ',N''),CHAR(9),N''),CHAR(13),N'');
IF @prefijo NOT IN(N'CREATE',N'ALTER',N'CREATEORALTER')
 THROW 51948,'Formato de declaracion no reconocido. No se altero el modulo.',1;
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
 UPDATE EAI_OWNER.RECV_INVOICE_PERF_BACKUP
 SET HashAplicado=HASHBYTES('SHA2_256',OBJECT_DEFINITION(@ObjectId))
 WHERE RunId=@RunId AND ObjectId=@ObjectId;
 COMMIT TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
        @cambios AS BloquesModificados,
        N'Parche aplicado con respaldo; pendiente medir siguiente lote comparable.' AS Resultado;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;
