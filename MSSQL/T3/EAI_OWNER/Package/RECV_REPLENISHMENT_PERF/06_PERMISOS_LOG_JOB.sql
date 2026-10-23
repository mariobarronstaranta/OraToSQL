/*
 Corrige el acceso confirmado a T3.RF_PROCESOS_LOG.
 Ejecutar como dbo/administrador en AZCRNMXNEVTD06 / T3QA.
 Concede SELECT, INSERT, UPDATE solamente en esa tabla al rol existente del job.
 No habilita ni inicia jobs. No ejecuta documentos.
 No modifica propietarios, membresias, procedimientos ni esquemas.
 La cuenta es compartida: el permiso tambien esta disponible para sus otros jobs.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51961,'Ejecutar sin transacciones externas o implicitas.',1;
IF USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
 THROW 51970,'No existe el usuario T3_SQLAGENT_OWNER.',1;
IF ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor',N'T3_SQLAGENT_OWNER'),0)<>1
 THROW 51973,'La cuenta debe pertenecer al rol T3SqlAgentJobExecutor.',1;
IF OBJECT_ID(N'T3.RF_PROCESOS_LOG',N'U') IS NULL
 THROW 51971,'No existe la tabla T3.RF_PROCESOS_LOG.',1;

-- Guardar este resultado como evidencia del estado anterior.
SELECT N'ANTES' Etapa,P.state_desc,P.permission_name,P.minor_id
FROM sys.database_permissions P
WHERE P.class=1 AND P.major_id=OBJECT_ID(N'T3.RF_PROCESOS_LOG')
 AND P.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor');

DECLARE @Impersonado bit=0,@PuedeLeer int,@PuedeInsertar int,@PuedeActualizar int;
BEGIN TRY
 BEGIN TRAN;
 GRANT SELECT, INSERT, UPDATE ON OBJECT::T3.RF_PROCESOS_LOG TO [T3SqlAgentJobExecutor];
 EXECUTE AS USER=N'T3_SQLAGENT_OWNER';
 SET @Impersonado=1;
 SELECT @PuedeLeer=HAS_PERMS_BY_NAME(N'T3.RF_PROCESOS_LOG',N'OBJECT',N'SELECT'),
        @PuedeInsertar=HAS_PERMS_BY_NAME(N'T3.RF_PROCESOS_LOG',N'OBJECT',N'INSERT'),
        @PuedeActualizar=HAS_PERMS_BY_NAME(N'T3.RF_PROCESOS_LOG',N'OBJECT',N'UPDATE');
 REVERT;
 SET @Impersonado=0;
 IF ISNULL(@PuedeLeer,0)<>1 OR ISNULL(@PuedeInsertar,0)<>1 OR ISNULL(@PuedeActualizar,0)<>1
  THROW 51972,'Persisten restricciones efectivas. Se revierte la concesion.',1;
 COMMIT;
 SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,
 N'T3_SQLAGENT_OWNER' Usuario,@PuedeLeer PuedeLeer,
 @PuedeInsertar PuedeInsertar,@PuedeActualizar PuedeActualizar,
 N'Permisos de tabla verificados; falta validar la ejecucion del job' Resultado;
END TRY
BEGIN CATCH
 IF @Impersonado=1 REVERT;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
