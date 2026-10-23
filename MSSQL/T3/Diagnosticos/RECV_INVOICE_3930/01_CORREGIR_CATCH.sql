/* Ejecutar TODO en T3QA, en una ventana sin ejecuciones de RECV_INVOICE
   ni despliegues concurrentes de sus dependencias.
   @Aplicar=1 aplica; 0 solo prepara/vista previa.
   Solo inserta el guard RI3930_PROPAGATE_V1 al inicio de los cuatro CATCH.
   Usa las definiciones INSTALADAS y conserva el resto de su codigo.
   Respalda las definiciones en EAI_OWNER.RECV_INVOICE_3930_BACKUP.
   No modifica RECV_INVOICE, SF_PROC_PREINVOICE_IFC, indices ni mensajes.
   No inicia ningun reproceso. Los cambios de los cuatro modulos son atomicos.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @BaseEsperada sysname=N'T3QA', @Aplicar bit=1;
IF DB_NAME()<>@BaseEsperada
    THROW 51000,'Seleccionar T3QA antes de ejecutar la correccion.',1;
IF @@TRANCOUNT<>0
    THROW 51001,'Ejecutar sin una transaccion externa activa.',1;

DECLARE @RunId uniqueidentifier=NEWID(),@XactAbortOn bit=IIF((@@OPTIONS & 16384)=16384,1,0);
DECLARE @Guard nvarchar(max)=CHAR(13)+CHAR(10)+
 N'        -- RI3930_PROPAGATE_V1'+CHAR(13)+CHAR(10)+
 N'        -- Propagar antes de escribir; el llamador decide rollback y logging.'+CHAR(13)+CHAR(10)+
 N'        -- Los cursores LOCAL se liberan al salir del procedimiento.'+CHAR(13)+CHAR(10)+
 N'        IF @@TRANCOUNT > 0'+CHAR(13)+CHAR(10)+
 N'        BEGIN'+CHAR(13)+CHAR(10)+
 N'            THROW;'+CHAR(13)+CHAR(10)+
 N'        END;';

DECLARE @Plan TABLE
 (Id int PRIMARY KEY,Nombre nvarchar(256) COLLATE DATABASE_DEFAULT,
  ObjectId int,Original nvarchar(max),OriginalAlter nvarchar(max),Corregida nvarchar(max),
  YaAplicado bit NOT NULL DEFAULT 0);
INSERT @Plan(Id,Nombre) VALUES
 (1,N'EAI_OWNER.INVOICE_TO_PREVENTA'),(2,N'EAI_OWNER.INVOICE_TO_FACTURA'),
 (3,N'EAI_OWNER.INVOICE_TO_ENTREGA_PO'),(4,N'T3.DELIVERY_WA_OXXO');

DECLARE @i int=1,@Nombre nvarchar(256),@ObjectId int,@Def nvarchar(max),
        @Alter nvarchar(max),@Nuevo nvarchar(max),@Pos int,@Fin int,
        @Linea nvarchar(max),@Normal nvarchar(max),@Inicio int,@Proc int,
        @Catch int,@Mensaje nvarchar(2048);

-- Preflight de todos los modulos antes de efectuar cualquier cambio.
WHILE @i<=4
BEGIN
 SELECT @Nombre=Nombre FROM @Plan WHERE Id=@i;
 SET @ObjectId=OBJECT_ID(@Nombre,N'P');
 SET @Def=NULL;
 SELECT @Def=definition FROM sys.sql_modules WHERE object_id=@ObjectId;
 IF @Def IS NULL
 BEGIN
  SET @Mensaje=CONCAT('No se puede leer el procedimiento: ',@Nombre);
  THROW 51002,@Mensaje,1;
 END;
 IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@ObjectId
           AND (uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
     THROW 51003,'Las opciones SET instaladas difieren de la captura. Revisar antes de aplicar.',1;
 IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectId)
     THROW 51004,'Modulo firmado: preparar su refirma antes de ALTER. No se hicieron cambios.',1;
 SET @Catch=CHARINDEX(N'BEGIN CATCH',@Def COLLATE Latin1_General_100_CI_AS);
 IF @Catch=0 OR CHARINDEX(N'BEGIN CATCH',@Def COLLATE Latin1_General_100_CI_AS,@Catch+11)>0
     THROW 51005,'Se esperaba un unico BEGIN CATCH por modulo. Revisar la definicion.',1;

 IF CHARINDEX(N'RI3930_PROPAGATE_V1',@Def)>0
 BEGIN
  -- No asumir que cualquier marcador implica una correccion valida.
  SET @Normal=UPPER(REPLACE(REPLACE(REPLACE(SUBSTRING(@Def,@Catch+11,1200),CHAR(13),N''),CHAR(10),N' '),CHAR(9),N' '));
  IF @Normal NOT LIKE '%IF @@TRANCOUNT > 0%BEGIN%THROW;%END;%'
      THROW 51006,'Marcador existente sin guard esperado; revisar manualmente.',1;
  UPDATE @Plan SET ObjectId=@ObjectId,Original=@Def,YaAplicado=1 WHERE Id=@i;
 END
 ELSE
 BEGIN
  -- Convertir solo la declaracion real a ALTER; no reemplazar codigo completo
  -- ni comentarios que contengan CREATE/PROCEDURE. Permite espacios y tabs.
  SET @Pos=1; SET @Alter=NULL;
  WHILE @Pos<=LEN(@Def) AND @Alter IS NULL
  BEGIN
   SET @Fin=CHARINDEX(CHAR(10),@Def,@Pos);
   IF @Fin=0 SET @Fin=LEN(@Def)+1;
   SET @Linea=SUBSTRING(@Def,@Pos,@Fin-@Pos);
   SET @Normal=UPPER(LTRIM(REPLACE(REPLACE(@Linea,CHAR(9),N' '),CHAR(13),N' ')));
   WHILE CHARINDEX(N'  ',@Normal)>0 SET @Normal=REPLACE(@Normal,N'  ',N' ');
   IF @Normal LIKE N'CREATE PROCEDURE %' OR @Normal LIKE N'CREATE OR ALTER PROCEDURE %'
      OR @Normal LIKE N'ALTER PROCEDURE %' OR @Normal LIKE N'CREATE PROC %'
      OR @Normal LIKE N'CREATE OR ALTER PROC %' OR @Normal LIKE N'ALTER PROC %'
   BEGIN
    SET @Inicio=PATINDEX(N'%[^ '+CHAR(9)+N']%',@Linea);
    SET @Proc=CHARINDEX(N'PROC',@Linea COLLATE Latin1_General_100_CI_AS,@Inicio);
    SET @Alter=STUFF(@Def,@Pos+@Inicio-1,@Proc-@Inicio,N'ALTER ');
   END;
   SET @Pos=@Fin+1;
  END;
  IF @Alter IS NULL
      THROW 51007,'No se reconocio la declaracion PROCEDURE instalada.',1;
  SET @Catch=CHARINDEX(N'BEGIN CATCH',@Alter COLLATE Latin1_General_100_CI_AS);
  SET @Nuevo=STUFF(@Alter,@Catch+11,0,@Guard);
  UPDATE @Plan SET ObjectId=@ObjectId,Original=@Def,OriginalAlter=@Alter,
                   Corregida=@Nuevo WHERE Id=@i;
 END;
 SET @i+=1;
END;

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
       @Aplicar AS Aplicar,Nombre,
       CASE WHEN YaAplicado=1 THEN N'Ya corregido: sin cambios' ELSE N'Agregar guard al CATCH' END AS Accion
FROM @Plan ORDER BY Id;
IF @Aplicar=0 OR NOT EXISTS(SELECT 1 FROM @Plan WHERE YaAplicado=0)
    RETURN;

SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_3930_BACKUP',N'U') IS NULL
 BEGIN
  CREATE TABLE EAI_OWNER.RECV_INVOICE_3930_BACKUP
  (RunId uniqueidentifier NOT NULL,ObjectId int NOT NULL,
   Nombre nvarchar(256) COLLATE DATABASE_DEFAULT NOT NULL,
   FechaAplicacion datetime2(3) NOT NULL,
   LoginAplicacion sysname COLLATE DATABASE_DEFAULT NULL,
   DefinicionOriginal nvarchar(max) NOT NULL,
   AlterOriginal nvarchar(max) NOT NULL,
   HashAplicado varbinary(32) NULL,
   FechaReversion datetime2(3) NULL,
   CONSTRAINT PK_RECV_INVOICE_3930_BACKUP PRIMARY KEY(RunId,ObjectId));
 END;
 SET @i=1;
 WHILE @i<=4
 BEGIN
  IF EXISTS(SELECT 1 FROM @Plan WHERE Id=@i AND YaAplicado=0)
  BEGIN
   SELECT @ObjectId=ObjectId,@Nombre=Nombre,@Def=Original,
          @Alter=OriginalAlter,@Nuevo=Corregida FROM @Plan WHERE Id=@i;
   IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@ObjectId
                AND CONVERT(varbinary(max),definition)=CONVERT(varbinary(max),@Def))
       THROW 51008,'El modulo cambio despues del preflight; se revierte la correccion.',1;
   INSERT EAI_OWNER.RECV_INVOICE_3930_BACKUP
    (RunId,ObjectId,Nombre,FechaAplicacion,LoginAplicacion,DefinicionOriginal,AlterOriginal)
   VALUES(@RunId,@ObjectId,@Nombre,SYSDATETIME(),ORIGINAL_LOGIN(),@Def,@Alter);
   EXEC sys.sp_executesql @Nuevo;
   UPDATE EAI_OWNER.RECV_INVOICE_3930_BACKUP
   SET HashAplicado=(SELECT HASHBYTES('SHA2_256',definition) FROM sys.sql_modules WHERE object_id=@ObjectId)
   WHERE RunId=@RunId AND ObjectId=@ObjectId;
  END;
  SET @i+=1;
 END;
 COMMIT TRANSACTION;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;

SELECT @RunId AS RunId,Nombre,FechaAplicacion,
       N'Aplicado. Conservar RunId para reversion si fuera necesaria.' AS Resultado
FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE RunId=@RunId ORDER BY Nombre;
