/* Correccion del error 2628 expuesto despues del parche 3930.
   Ejecutar TODO en T3QA sin ejecuciones del job/despliegues concurrentes.
   Solo agrega columnas explicitas al INSERT de REMISION_GENERAL.
   No cambia tamanos, valores, folios, indices ni otras reglas del procedimiento.
   Usa el modulo instalado y el respaldo creado por 01_CORREGIR_CATCH.sql.
   No ejecuta el job ni reprocesa documentos. @Aplicar=0 es vista previa.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @BaseEsperada sysname=N'T3QA',@Aplicar bit=1;
IF DB_NAME()<>@BaseEsperada THROW 51300,'Seleccionar T3QA.',1;
IF @@TRANCOUNT<>0 THROW 51301,'Ejecutar sin transaccion externa.',1;
IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_3930_BACKUP',N'U') IS NULL
    THROW 51302,'Aplicar primero el script 01 de manejo de errores.',1;

DECLARE @Id int=OBJECT_ID(N'T3.DELIVERY_WA_OXXO',N'P'),@Original nvarchar(max),
        @Alter nvarchar(max),@Nuevo nvarchar(max),@Pos int,@Fin int,
        @Linea nvarchar(max),@Normal nvarchar(max),@Inicio int,@Proc int,
        @At int,@Despues int,@RunId uniqueidentifier=NEWID(),
        @XactAbortOn bit=IIF((@@OPTIONS & 16384)=16384,1,0);
SELECT @Original=definition FROM sys.sql_modules WHERE object_id=@Id;
IF @Original IS NULL THROW 51303,'No se puede leer T3.DELIVERY_WA_OXXO.',1;
IF CHARINDEX(N'RI3930_PROPAGATE_V1',@Original)=0
    THROW 51304,'Falta el guard de propagacion del script 01.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Id)
    THROW 51305,'Modulo firmado: preparar refirma antes de alterar.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Id
          AND (uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
    THROW 51306,'Opciones de creacion distintas de la captura. Revisar.',1;
IF CHARINDEX(N'RI2628_REMISION_COLUMNAS_V1',@Original)>0
BEGIN
 SELECT N'T3.DELIVERY_WA_OXXO' AS Procedimiento,N'Parche de columnas ya presente; sin cambios' AS Resultado;
 RETURN;
END;

DECLARE @Columnas nvarchar(max)=
 N'FACTURA, PEDIDOSAP, CLASE_REMISION, SOCIEDAD,
 FECHA_FACTURA, FECHA_TRN, FECHA_PROC_BATMD, FECHA_CANCELACION,
 ORIGEN, NOMBRE, DIRECCION, COLONIA, CIUDAD, ESTADO, PAIS, CODIGOPOSTAL,
 SHIPTOPARTY, RFC,
 DESTINO, DESTINO_NOMBRE, DESTINO_DIRECCION, DESTINO_COLONIA,
 DESTINO_CIUDAD, DESTINO_ESTADO, DESTINO_PAIS, DESTINO_CODIGOPOSTAL,
 OBSERVACIONES, REMISION_SERIE, REMISION_FOLIO';
IF EXISTS
 (SELECT 1 FROM STRING_SPLIT(REPLACE(REPLACE(@Columnas,CHAR(13),N''),CHAR(10),N''),N',') L
  WHERE NOT EXISTS
   (SELECT 1 FROM sys.columns C WHERE C.object_id=OBJECT_ID(N'T3.REMISION_GENERAL')
    AND C.name COLLATE DATABASE_DEFAULT=LTRIM(RTRIM(L.value)) COLLATE DATABASE_DEFAULT))
    THROW 51307,'La tabla no tiene las 29 columnas esperadas. No se altera.',1;

-- Convertir exclusivamente la declaracion de procedimiento a ALTER.
SET @Pos=1;
WHILE @Pos<=LEN(@Original) AND @Alter IS NULL
BEGIN
 SET @Fin=CHARINDEX(CHAR(10),@Original,@Pos);
 IF @Fin=0 SET @Fin=LEN(@Original)+1;
 SET @Linea=SUBSTRING(@Original,@Pos,@Fin-@Pos);
 SET @Normal=UPPER(LTRIM(REPLACE(REPLACE(@Linea,CHAR(9),N' '),CHAR(13),N' ')));
 WHILE CHARINDEX(N'  ',@Normal)>0 SET @Normal=REPLACE(@Normal,N'  ',N' ');
 IF @Normal LIKE N'CREATE PROCEDURE %' OR @Normal LIKE N'CREATE OR ALTER PROCEDURE %'
    OR @Normal LIKE N'ALTER PROCEDURE %' OR @Normal LIKE N'CREATE PROC %'
    OR @Normal LIKE N'CREATE OR ALTER PROC %' OR @Normal LIKE N'ALTER PROC %'
 BEGIN
  SET @Inicio=PATINDEX(N'%[^ '+CHAR(9)+N']%',@Linea);
  SET @Proc=CHARINDEX(N'PROC',@Linea COLLATE Latin1_General_100_CI_AS,@Inicio);
  SET @Alter=STUFF(@Original,@Pos+@Inicio-1,@Proc-@Inicio,N'ALTER ');
 END;
 SET @Pos=@Fin+1;
END;
IF @Alter IS NULL THROW 51308,'No se reconoce la declaracion PROCEDURE.',1;

DECLARE @Ancla nvarchar(100)=N'INSERT INTO T3.Remision_General';
SET @At=CHARINDEX(@Ancla,@Alter COLLATE Latin1_General_100_CI_AS);
IF @At=0 OR CHARINDEX(@Ancla,@Alter COLLATE Latin1_General_100_CI_AS,@At+LEN(@Ancla))>0
    THROW 51309,'No se encontro un unico INSERT esperado. Revisar version.',1;
SET @Despues=@At+LEN(@Ancla);
SET @Pos=@Despues;
WHILE SUBSTRING(@Alter,@Pos,1) IN (N' ',CHAR(9),CHAR(10),CHAR(13)) SET @Pos+=1;
IF UPPER(SUBSTRING(@Alter,@Pos,6))<>N'VALUES'
    THROW 51310,'El INSERT instalado difiere del posicional esperado. Revisar antes de cambiar.',1;
SET @Nuevo=STUFF(@Alter,@Despues,0,CHAR(13)+CHAR(10)+
 N' -- RI2628_REMISION_COLUMNAS_V1'+CHAR(13)+CHAR(10)+N' ('+@Columnas+N')');

SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
       @Aplicar AS Aplicar,N'T3.DELIVERY_WA_OXXO' AS Procedimiento,
       N'Agregar lista explicita de columnas; conservar todos los valores.' AS Accion;
IF @Aplicar=0 RETURN;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Id
              AND CONVERT(varbinary(max),definition)=CONVERT(varbinary(max),@Original))
    THROW 51311,'El modulo cambio durante el preflight; se cancela.',1;
 INSERT EAI_OWNER.RECV_INVOICE_3930_BACKUP
  (RunId,ObjectId,Nombre,FechaAplicacion,LoginAplicacion,DefinicionOriginal,AlterOriginal)
 VALUES(@RunId,@Id,N'T3.DELIVERY_WA_OXXO',SYSDATETIME(),ORIGINAL_LOGIN(),@Original,@Alter);
 EXEC sys.sp_executesql @Nuevo;
 UPDATE EAI_OWNER.RECV_INVOICE_3930_BACKUP
 SET HashAplicado=(SELECT HASHBYTES('SHA2_256',definition) FROM sys.sql_modules WHERE object_id=@Id)
 WHERE RunId=@RunId AND ObjectId=@Id;
 COMMIT;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;
SELECT @RunId AS RunId,N'Columnas corregidas; conservar RunId para reversion si fuera necesaria.' AS Resultado;
