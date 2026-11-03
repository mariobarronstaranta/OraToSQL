/* Reversion del cambio de definicion; no modifica documentos ni layouts. */
USE [T3QA]; SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
DECLARE @Revertir bit=0;
IF @Revertir<>1 THROW 53620,'Cambiar @Revertir a 1 solo para reversion deliberada.',1;
IF @@TRANCOUNT<>0 THROW 53621,'No usar transaccion externa.',1;
IF OBJECT_ID('dbo.REPAIR_OTROS_8115_20261029','U') IS NULL THROW 53622,'No existe respaldo de modulo.',1;
DECLARE @Antes nvarchar(max),@Despues nvarchar(max),@Pos int;
BEGIN TRY
 BEGIN TRANSACTION;
 IF (SELECT COUNT_BIG(*) FROM dbo.REPAIR_OTROS_8115_20261029 WITH(UPDLOCK,HOLDLOCK))<>1
  THROW 53623,'Respaldo ambiguo.',1;
 SELECT @Antes=DefinicionAntes,@Despues=DefinicionDespues FROM dbo.REPAIR_OTROS_8115_20261029;
 IF OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')) IS NULL
  OR HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))<>HASHBYTES('SHA2_256',@Despues)
  THROW 53624,'El modulo cambio despues del parche; no sobrescribir.',1;
 SET @Pos=CHARINDEX(N'PROCEDURE [T3].[PROC_V40_GENERAR_OTROS]',@Antes);
 IF @Pos=0 THROW 53625,'Declaracion del respaldo no reconocida.',1;
 SET @Antes=N'ALTER '+SUBSTRING(@Antes,@Pos,LEN(@Antes));
 EXEC sys.sp_executesql @Antes;
 COMMIT; SELECT 'DEFINICION ANTERIOR RESTAURADA' Resultado;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
