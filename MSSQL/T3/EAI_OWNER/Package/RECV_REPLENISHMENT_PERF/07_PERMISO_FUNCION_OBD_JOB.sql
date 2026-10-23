-- Ejecutar como dbo/administrador en AZCRNMXNEVTD06 / T3QA.
-- Concede EXECUTE al rol existente. No llama la funcion ni inicia jobs.
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51961,'Ejecutar sin transacciones externas o implicitas.',1;
IF ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor',N'T3_SQLAGENT_OWNER'),0)<>1
 THROW 51973,'La cuenta debe pertenecer al rol T3SqlAgentJobExecutor.',1;
IF OBJECT_ID(N'T3.FN_EVAL_REMISION_OBD',N'FN') IS NULL
 THROW 51974,'No existe la funcion escalar T3.FN_EVAL_REMISION_OBD.',1;
SELECT N'ANTES' Etapa,P.state_desc,P.permission_name
FROM sys.database_permissions P
WHERE P.class=1 AND P.major_id=OBJECT_ID(N'T3.FN_EVAL_REMISION_OBD')
 AND P.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor');
DECLARE @Impersonado bit=0,@PuedeEjecutar int;
BEGIN TRY
 BEGIN TRAN;
 GRANT EXECUTE ON OBJECT::[T3].[FN_EVAL_REMISION_OBD] TO [T3SqlAgentJobExecutor];
 EXECUTE AS USER=N'T3_SQLAGENT_OWNER';
 SET @Impersonado=1;
 SET @PuedeEjecutar=HAS_PERMS_BY_NAME(N'T3.FN_EVAL_REMISION_OBD',N'OBJECT',N'EXECUTE');
 REVERT;
 SET @Impersonado=0;
 IF ISNULL(@PuedeEjecutar,0)<>1
  THROW 51975,'Persiste una restriccion efectiva. Se revierte la concesion.',1;
 COMMIT;
 SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,N'T3_SQLAGENT_OWNER' Usuario,
 @PuedeEjecutar PuedeEjecutarFuncion,N'Permiso verificado' Resultado;
END TRY
BEGIN CATCH
 IF @Impersonado=1 REVERT;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
