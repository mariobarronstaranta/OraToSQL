/* Solo si se decide revertir ESTE parche. Seleccionar T3QA.
   Indicar el RunId informado por 01_CORREGIR_REFERENCEID.sql.
   Ejecutar como administrador, sin lotes/despliegues concurrentes.
   No restaura una copia antigua del repositorio: usa el respaldo instalado.
   Si el modulo cambio desde la aplicacion, se detiene sin sobrescribirlo.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @RunId UNIQUEIDENTIFIER=NULL; -- Sustituir solo cuando se requiera revertir.
IF DB_NAME()<>N'T3QA' THROW 52620,'Seleccionar T3QA.',1;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 52621,'Ejecutar sin transacciones externas ni implicitas.',1;
IF @RunId IS NULL THROW 52622,'Indicar el RunId de la aplicacion que se desea revertir.',1;
IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_PERF_BACKUP',N'U') IS NULL
 THROW 52623,'No existe la tabla de respaldos de este parche.',1;

DECLARE @ObjectId INT=OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'P'),
        @OriginalAlter NVARCHAR(MAX),@HashAplicado VARBINARY(32),@Revertido DATETIME2(3),
        @XactAbortOriginal BIT=IIF((@@OPTIONS & 16384)=16384,1,0);
SELECT @OriginalAlter=AlterOriginal,@HashAplicado=HashAplicado,@Revertido=FechaReversion
FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP
WHERE RunId=@RunId AND ObjectId=@ObjectId;
IF @OriginalAlter IS NULL THROW 52624,'El RunId no corresponde a este procedimiento instalado.',1;
IF @Revertido IS NOT NULL
BEGIN
 SELECT N'Ya revertido: sin cambios' AS Resultado,@RunId AS RunId;
 RETURN;
END;
IF @HashAplicado IS NULL
 THROW 52625,'El respaldo no registra una aplicacion terminada.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectId)
 THROW 52626,'Modulo firmado posteriormente: revisar su refirma antes de revertir.',1;

SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_DEFINITION(@ObjectId) IS NULL
    OR HASHBYTES('SHA2_256',OBJECT_DEFINITION(@ObjectId))<>@HashAplicado
  THROW 52627,'El SP cambio despues del parche; no se sobrescribe.',1;
 EXEC sys.sp_executesql @OriginalAlter;
 UPDATE EAI_OWNER.RECV_INVOICE_PERF_BACKUP SET FechaReversion=SYSDATETIME()
 WHERE RunId=@RunId AND ObjectId=@ObjectId;
 COMMIT TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseActual,@RunId AS RunId,
        N'Restaurada la definicion inmediatamente anterior al parche.' AS Resultado;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @XactAbortOriginal=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;
