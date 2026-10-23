-- Ejecutar como dbo/administrador en AZCRNMXNEVTD06 / T3QA.
-- Concede solo SELECT sobre los dos catalogos con errores 229 confirmados.
-- No inicia jobs ni procesa documentos. Guardar la salida ANTES para reversa.
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51961,'Ejecutar sin transacciones externas o implicitas.',1;
IF ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor',N'T3_SQLAGENT_OWNER'),0)<>1
 THROW 51973,'La cuenta debe pertenecer al rol T3SqlAgentJobExecutor.',1;
IF OBJECT_ID(N'EAI_OWNER.MX_HASHTABLE',N'U') IS NULL
 OR OBJECT_ID(N'T3.MATERIAL',N'U') IS NULL
 THROW 51976,'Falta alguno de los catalogos esperados.',1;
SELECT N'ANTES' Etapa,OBJECT_SCHEMA_NAME(P.major_id) Esquema,
 OBJECT_NAME(P.major_id) Objeto,P.state_desc,P.permission_name,P.minor_id
FROM sys.database_permissions P
WHERE P.class=1 AND P.major_id IN(OBJECT_ID(N'EAI_OWNER.MX_HASHTABLE'),OBJECT_ID(N'T3.MATERIAL'))
 AND P.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor');
DECLARE @Impersonado bit=0,@Hashtable int,@Material int;
BEGIN TRY
 BEGIN TRAN;
 GRANT SELECT ON OBJECT::[EAI_OWNER].[MX_HASHTABLE] TO [T3SqlAgentJobExecutor];
 GRANT SELECT ON OBJECT::[T3].[MATERIAL] TO [T3SqlAgentJobExecutor];
 EXECUTE AS USER=N'T3_SQLAGENT_OWNER';
 SET @Impersonado=1;
 SELECT @Hashtable=HAS_PERMS_BY_NAME(N'EAI_OWNER.MX_HASHTABLE',N'OBJECT',N'SELECT'),
        @Material=HAS_PERMS_BY_NAME(N'T3.MATERIAL',N'OBJECT',N'SELECT');
 REVERT;
 SET @Impersonado=0;
 IF ISNULL(@Hashtable,0)<>1 OR ISNULL(@Material,0)<>1
  THROW 51977,'Persisten restricciones efectivas. Se revierte la concesion.',1;
 COMMIT;
 SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,
 @Hashtable PuedeLeerHashtable,@Material PuedeLeerMaterial;
END TRY
BEGIN CATCH
 IF @Impersonado=1 REVERT;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
