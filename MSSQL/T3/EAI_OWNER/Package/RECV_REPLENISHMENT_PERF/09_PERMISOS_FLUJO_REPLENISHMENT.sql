-- Ejecutar como administrador en AZCRNMXNEVTD06 / T3QA.
-- Permisos por objeto del flujo revisado, incluidos accesos entre esquemas.
-- No inicia jobs, no procesa documentos ni concede permisos sobre todo un esquema.
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2
 THROW 51961,'Ejecutar sin transacciones externas o implicitas.',1;
IF ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor',N'T3_SQLAGENT_OWNER'),0)<>1
 THROW 51973,'La cuenta debe pertenecer al rol T3SqlAgentJobExecutor.',1;

-- BEGIN REPLENISHMENT PERMISSIONS
DECLARE @RRPermisos table(Objeto nvarchar(256),Permisos varchar(100));
INSERT @RRPermisos VALUES
 (N'T3.RF_PROCESOS_LOG','SELECT,INSERT,UPDATE'),
 (N'T3.MATERIAL','SELECT'),
 (N'T3.CFDI_PRODSERV','SELECT'),
 (N'T3.PREVENTA_GENERAL','SELECT'),
 (N'T3.ENTREGA','SELECT,INSERT,DELETE'),
 (N'T3.RF_COMPLEMENTO','SELECT,INSERT,DELETE'),
 (N'T3.REMISION_GENERAL','SELECT,INSERT,DELETE'),
 (N'T3.REMISION_DETALLE','SELECT,INSERT,UPDATE,DELETE'),
 (N'T3.MOV_CLIENTE','SELECT'),
 (N'T3.CLIENTE','SELECT'),
 (N'T3.DISTRIBUIDOR_FISCAL','SELECT'),
 (N'T3.REMISION_CTRO_SOCIEDAD','SELECT'),
 (N'T3.FN_EVAL_REMISION_OBD','EXECUTE'),
 (N'T3.DELIVERY_TO_SUBDEPOT','EXECUTE'),
 (N'T3.DELIVERY_IDOC_TO_REMISION','EXECUTE'),
 (N'T3.GET_REMISION_INFO','EXECUTE'),
 (N'EAI.ZSDFE_SOC','SELECT'),
 (N'EAI.IFC_FOLIOS_FE','SELECT,INSERT,UPDATE'),
 (N'EAI_OWNER.MX_HASHTABLE','SELECT'),
 (N'EAI_OWNER.TAO_CEDIS_VALID','SELECT'),
 (N'EAI_OWNER.MX_PRINT_DELIVERY','SELECT'),
 (N'EAI_OWNER.TMP_DOCUMENT_HEADER','SELECT'),
 (N'EAI_OWNER.TMP_DOCUMENT_DETAIL','SELECT'),
 (N'EAI_OWNER.MX_EAI_MESSAGE_LOG','INSERT'),
 (N'EAI_OWNER.GETCONV','EXECUTE'),
 (N'EAI_OWNER.WA_FOLIO_FACTURA','EXECUTE');
-- Otros accesos internos del esquema EAI_OWNER conservan su cadena de propiedad.
-- Se explicitan aqui los accesos que cruzan a T3/EAI y de regreso desde T3.
IF EXISTS(SELECT 1 FROM @RRPermisos WHERE OBJECT_ID(Objeto) IS NULL)
BEGIN
 SELECT Objeto AS ObjetoFaltante FROM @RRPermisos WHERE OBJECT_ID(Objeto) IS NULL;
 THROW 51978,'Faltan objetos del flujo o no son visibles. No se concedieron estos permisos.',1;
END;
DECLARE @RRSql nvarchar(max)=N'';
SELECT @RRSql=@RRSql+N'GRANT '+Permisos+N' ON OBJECT::'
 +QUOTENAME(PARSENAME(Objeto,2))+N'.'+QUOTENAME(PARSENAME(Objeto,1))
 +N' TO [T3SqlAgentJobExecutor];'+NCHAR(10)
FROM @RRPermisos;
-- END REPLENISHMENT PERMISSIONS

-- Guardar ANTES para una reversa que conserve concesiones anteriores.
SELECT N'ANTES' Etapa,R.Objeto,P.state_desc,P.permission_name,P.minor_id
FROM @RRPermisos R JOIN sys.database_permissions P ON P.major_id=OBJECT_ID(R.Objeto)
 AND P.class=1 AND P.grantee_principal_id=DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor');
DECLARE @RRImpersonado bit=0;
DECLARE @RRResultado table(Objeto nvarchar(256),Permiso varchar(100),Permitido int);
BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql @RRSql;
 EXECUTE AS USER=N'T3_SQLAGENT_OWNER';
 SET @RRImpersonado=1;
 INSERT @RRResultado
 SELECT R.Objeto,S.value,HAS_PERMS_BY_NAME(R.Objeto,N'OBJECT',S.value)
 FROM @RRPermisos R CROSS APPLY STRING_SPLIT(R.Permisos,',') S;
 REVERT;
 SET @RRImpersonado=0;
 IF EXISTS(SELECT 1 FROM @RRResultado WHERE ISNULL(Permitido,0)<>1)
 BEGIN
  SELECT * FROM @RRResultado WHERE ISNULL(Permitido,0)<>1;
  THROW 51979,'Persisten restricciones efectivas; se revierte esta concesion.',1;
 END;
 COMMIT;
 SELECT * FROM @RRResultado ORDER BY Objeto,Permiso;
 SELECT N'Permisos verificados; falta validar el job completo.' Resultado;
END TRY
BEGIN CATCH
 IF @RRImpersonado=1 REVERT;
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
