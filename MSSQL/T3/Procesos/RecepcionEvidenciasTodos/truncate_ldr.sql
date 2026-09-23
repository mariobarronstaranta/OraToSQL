:ON ERROR EXIT
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
 @Resource=N'RecepcionEvidenciasTodos:EAI.LDR_EVIDENCIAS_ENTREGA',
 @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @Resultado<0 THROW 51300,'Otra recepcion de evidencias esta en ejecucion en esta base.',1;
IF OBJECT_ID(N'EAI.LDR_EVIDENCIAS_ENTREGA',N'U') IS NULL
 OR OBJECT_ID(N'EAI.HIST_EVIDENCIAS_ENTREGA',N'U') IS NULL
 OR OBJECT_ID(N'EAI.IFC_Folios_FE',N'U') IS NULL
 OR OBJECT_ID(N'EAI.MOVE_EVIDENCIA_ENTREGA',N'P') IS NULL
 THROW 51302,'Falta una tabla o procedimiento requerido, o no es visible para esta cuenta.',1;
CREATE TABLE [$(StageTable)] (LINEA nvarchar(max) COLLATE DATABASE_DEFAULT NULL);
GO
!! call loader.bat __cargar
:r ".recepcion_lock\carga_estado.sql"
GO
:r "moveInfo.sql"
GO
DROP TABLE [$(StageTable)];
EXEC sys.sp_releaseapplock @Resource=N'RecepcionEvidenciasTodos:EAI.LDR_EVIDENCIAS_ENTREGA',@LockOwner='Session';
GO