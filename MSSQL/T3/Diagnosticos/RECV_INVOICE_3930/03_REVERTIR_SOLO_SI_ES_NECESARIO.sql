/* NO es parte de la ejecucion normal. Solo revierte el RunId indicado.
   Conserva el respaldo y rechaza reversion si hubo cambios posteriores.
*/
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @RunId uniqueidentifier=NULL; -- Pegar RunId devuelto por el script 01.
IF DB_NAME()<>N'T3QA' THROW 51200,'Seleccionar T3QA.',1;
IF @@TRANCOUNT<>0 THROW 51201,'Ejecutar sin transaccion externa.',1;
IF @RunId IS NULL THROW 51202,'Indicar RunId de la aplicacion que se desea revertir.',1;
IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_3930_BACKUP',N'U') IS NULL
    THROW 51203,'No existe respaldo.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP
              WHERE RunId=@RunId AND FechaReversion IS NULL)
    THROW 51204,'RunId inexistente o ya revertido.',1;
DECLARE @ObjectId int,@Sql nvarchar(max),@Hash varbinary(32),
        @XactAbortOn bit=IIF((@@OPTIONS & 16384)=16384,1,0);
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 WHILE EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP
              WHERE RunId=@RunId AND FechaReversion IS NULL)
 BEGIN
  SELECT TOP(1) @ObjectId=ObjectId,@Sql=AlterOriginal,@Hash=HashAplicado
  FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP
  WHERE RunId=@RunId AND FechaReversion IS NULL ORDER BY ObjectId;
  IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@ObjectId
               AND HASHBYTES('SHA2_256',definition)=@Hash)
      THROW 51205,'El procedimiento cambio desde la correccion; no se sobreescribe.',1;
  EXEC sys.sp_executesql @Sql;
  UPDATE EAI_OWNER.RECV_INVOICE_3930_BACKUP SET FechaReversion=SYSDATETIME()
  WHERE RunId=@RunId AND ObjectId=@ObjectId;
 END;
 COMMIT TRANSACTION;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF @XactAbortOn=0 SET XACT_ABORT OFF;
 THROW;
END CATCH;
SELECT RunId,Nombre,FechaReversion FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE RunId=@RunId;
