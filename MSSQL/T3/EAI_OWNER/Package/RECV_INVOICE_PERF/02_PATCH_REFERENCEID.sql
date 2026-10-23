/* Ejecutar en T3QA cuando el job/lote haya terminado.
   Parche puntual de los tres DELETE sobre la definicion DESPLEGADA.
   Conserva variables Unicode, parametros, transacciones y resto del procedimiento.
   Reversa: ejecutar este mismo archivo con @Revertir=1.
   Si el formato de un DELETE difiere del esperado, no modifica el procedimiento.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @Revertir bit=0;
IF DB_NAME()<>N'T3QA' THROW 51940,'Seleccionar la base T3QA.',1;
IF @@TRANCOUNT<>0 THROW 51941,'Ejecutar fuera de una transaccion externa.',1;
DECLARE @sql nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'));
IF @sql IS NULL THROW 51942,'Procedimiento ausente, cifrado o sin permiso VIEW DEFINITION.',1;
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
EXEC sys.sp_executesql @sql;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,@Revertir Revertido,@cambios BloquesModificados;
