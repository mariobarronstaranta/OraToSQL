:ON ERROR EXIT
-- Entrada SQL de loader.bat. La limpieza se difiere hasta validar el CSV.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET LOCK_TIMEOUT 60000;
DECLARE @Resultado int;
EXEC @Resultado=sys.sp_getapplock
 @Resource=N'RecepcionEvidencias:EAI.LDR_SHAREPOINT',
 @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @Resultado<0 THROW 51300,'Otra recepcion esta en ejecucion en esta base.',1;
IF OBJECT_ID(N'EAI.LDR_SHAREPOINT',N'U') IS NULL
 OR OBJECT_ID(N'EAI.IFC_FOLIOS_FE',N'U') IS NULL
 OR OBJECT_ID(N'EAI_OWNER.EAI_TRUNC_TABLE',N'U') IS NULL
 OR OBJECT_ID(N'EAI_OWNER.EAI_TRUNC_LOG',N'U') IS NULL
 THROW 51302,'Falta una tabla requerida o no es visible para esta cuenta.',1;
IF NOT EXISTS (SELECT 1 FROM EAI_OWNER.EAI_TRUNC_TABLE
 WHERE UPPER(TABLE_NAME) COLLATE DATABASE_DEFAULT=N'EAI.LDR_SHAREPOINT')
 THROW 51303,'EAI.LDR_SHAREPOINT no esta autorizada en EAI_OWNER.EAI_TRUNC_TABLE.',1;
CREATE TABLE [$(StageTable)] (LINEA nvarchar(max) COLLATE DATABASE_DEFAULT NULL);
GO
!! call loader.bat __cargar
:r ".recepcion_lock\carga_estado.sql"
GO
:r "moveInfo.sql"
GO
DROP TABLE [$(StageTable)];
EXEC sys.sp_releaseapplock @Resource=N'RecepcionEvidencias:EAI.LDR_SHAREPOINT',@LockOwner='Session';
GO
