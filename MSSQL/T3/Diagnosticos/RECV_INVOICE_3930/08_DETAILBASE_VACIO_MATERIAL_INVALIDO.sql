/* Correccion 8114 autorizada: un material no convertible a NUMERIC(38,0)
   hace que DetailBase devuelva cero filas para TODA la factura.
   Ejecutar TODO en T3QA sin ejecuciones del job/despliegues concurrentes.
   Cambia solo DetailBase del modulo instalado, conserva los otros cambios.
   El flujo posterior continua; sus SUM sobre detalle vacio dejan totales NULL.
   Usa respaldos del script 01; reversion por RunId mediante script 03.
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

DECLARE @Id int=OBJECT_ID(N'EAI_OWNER.INVOICE_TO_FACTURA',N'P'),@Original nvarchar(max),
        @Alter nvarchar(max),@Nuevo nvarchar(max),@Pos int,@Fin int,
        @Linea nvarchar(max),@Normal nvarchar(max),@Inicio int,@Proc int,
        @RunId uniqueidentifier=NEWID(),
        @XactAbortOn bit=IIF((@@OPTIONS & 16384)=16384,1,0);
SELECT @Original=definition FROM sys.sql_modules WHERE object_id=@Id;
IF @Original IS NULL THROW 51303,'No se puede leer EAI_OWNER.INVOICE_TO_FACTURA.',1;
IF CHARINDEX(N'RI3930_PROPAGATE_V1',@Original)=0
    THROW 51304,'Falta el guard de propagacion del script 01.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Id)
    THROW 51305,'Modulo firmado: preparar refirma antes de alterar.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Id
          AND (uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
    THROW 51306,'Opciones de creacion distintas de la captura. Revisar.',1;
IF CHARINDEX(N'RI8114_DETAILBASE_VACIO_V1',@Original)>0
BEGIN
 SELECT N'EAI_OWNER.INVOICE_TO_FACTURA' AS Procedimiento,N'Parche de detalle vacio ya presente; sin cambios' AS Resultado;
 RETURN;
END;

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

DECLARE @InicioDetalle int=CHARINDEX(N';WITH DetailBase AS',@Alter COLLATE Latin1_General_100_CI_AS),
        @FinDetalle int,@Bloque nvarchar(max),@BloqueNuevo nvarchar(max),
        @Conversion nvarchar(100)=N'CONVERT(NUMERIC(38,0), TRIM(Det.Material))',
        @Filtro nvarchar(100)=N'WHERE Head.ReferenceID = @sInvoiceID';
IF @InicioDetalle=0 OR CHARINDEX(N';WITH DetailBase AS',@Alter COLLATE Latin1_General_100_CI_AS,@InicioDetalle+1)>0
    THROW 51309,'No se encontro un unico DetailBase esperado.',1;
SET @FinDetalle=CHARINDEX(N'DetailMapped AS',@Alter COLLATE Latin1_General_100_CI_AS,@InicioDetalle);
IF @FinDetalle=0 THROW 51310,'No se encontro el limite de DetailBase.',1;
SET @Bloque=SUBSTRING(@Alter,@InicioDetalle,@FinDetalle-@InicioDetalle);
IF (LEN(@Bloque)-LEN(REPLACE(@Bloque,@Conversion,N'')))/LEN(@Conversion)<>5
   OR CHARINDEX(N'TRY_CONVERT',@Bloque)>0
   OR CHARINDEX(@Filtro,@Bloque)=0
   OR CHARINDEX(@Filtro,@Bloque,CHARINDEX(@Filtro,@Bloque)+LEN(@Filtro))>0
    THROW 51312,'DetailBase difiere de la version esperada. Revisar antes de cambiar.',1;
SET @BloqueNuevo=REPLACE(@Bloque,@Conversion,N'TRY_CONVERT(NUMERIC(38,0), TRIM(Det.Material))');
SET @BloqueNuevo=REPLACE(@BloqueNuevo,@Filtro,N'WHERE Head.ReferenceID = @sInvoiceID
                      -- RI8114_DETAILBASE_VACIO_V1
                      -- Un material no convertible omite TODO el detalle de esta factura.
                      -- TRY_CONVERT protege expresiones evaluadas antes del filtro.
                      -- NULL conserva su tratamiento previo; no se omiten otras facturas.
                      AND NOT EXISTS
                      (
                          SELECT 1
                          FROM EAI_OWNER.TMP_DOCUMENT_DETAIL AS MaterialInvalido
                          WHERE MaterialInvalido.ReferenceID = @sInvoiceID
                            AND MaterialInvalido.Material IS NOT NULL
                            AND TRY_CONVERT(NUMERIC(38,0), TRIM(MaterialInvalido.Material)) IS NULL
                      )');
SET @Nuevo=STUFF(@Alter,@InicioDetalle,@FinDetalle-@InicioDetalle,@BloqueNuevo);
SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
       @Aplicar AS Aplicar,N'EAI_OWNER.INVOICE_TO_FACTURA' AS Procedimiento,
       N'Omitir todo DetailBase de la factura si algun material no convierte a NUMERIC(38,0).' AS Accion;
IF @Aplicar=0 RETURN;
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Id
              AND CONVERT(varbinary(max),definition)=CONVERT(varbinary(max),@Original))
    THROW 51311,'El modulo cambio durante el preflight; se cancela.',1;
 INSERT EAI_OWNER.RECV_INVOICE_3930_BACKUP
  (RunId,ObjectId,Nombre,FechaAplicacion,LoginAplicacion,DefinicionOriginal,AlterOriginal)
 VALUES(@RunId,@Id,N'EAI_OWNER.INVOICE_TO_FACTURA',SYSDATETIME(),ORIGINAL_LOGIN(),@Original,@Alter);
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
SELECT @RunId AS RunId,N'DetailBase corregido; conservar RunId para reversion si fuera necesaria.' AS Resultado;
