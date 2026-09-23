:ON ERROR EXIT
-- Entrada de loader.bat. Mantiene el bloqueo SQL durante TODAS las etapas.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET IMPLICIT_TRANSACTIONS OFF;
SET LOCK_TIMEOUT 60000;
DECLARE @RC int;
EXEC @RC=sys.sp_getapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',
    @LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @RC<0 THROW 51500,'Otra carga de cifras de ventas esta en ejecucion.',1;
IF EXISTS(SELECT 1 FROM (VALUES
 (N'EAI.TAO_SALES_DOCS_LDR'),(N'EAI.T3R_SALES_DOCS_OLD'),
 (N'EAI.T3R_SALES_DOCS_LDR_MX01'),(N'EAI.T3R_SALES_DOCS_OTHERS'),
 (N'EAI.ERROR_TABLE'),(N'EAI.CONTROL_REPORTE'),
 (N'T3.PREVENTA_GENERAL'),(N'T3.FACTURA_GENERAL'),(N'T3.RF_PROCESOS_LOG'),
 (N'EAI_OWNER.MX_COMPONENTS'),(N'EAI_OWNER.MX_EAI_MESSAGE_LOG'),
 (N'EAI_OWNER.EAI_TRUNC_TABLE'),(N'EAI_OWNER.EAI_TRUNC_LOG')) T(Nombre)
 WHERE OBJECT_ID(T.Nombre,N'U') IS NULL)
 THROW 51502,'Falta una tabla requerida o no es visible para la cuenta.',1;
IF OBJECT_ID(N'EAI_OWNER.ProcessID',N'SO') IS NULL
 OR OBJECT_ID(N'EAI_OWNER.LOG_START',N'P') IS NULL
 THROW 51502,'Falta ProcessID o LOG_START, o no es visible para la cuenta.',1;
-- Evitar ejecutar la antigua conversion incompleta del procedimiento.
IF ISNULL(CHARINDEX(N'MIGRATION_VERSION: CC_SALESDOC_LDR_TO_CIFRAS_20260918',
 OBJECT_DEFINITION(OBJECT_ID(N'EAI.CC_SALESDOC_LDR_TO_CIFRAS'))),0)=0
 THROW 51503,'Instalar CC_SALESDOC_LDR_TO_CIFRAS.SQL de esta entrega; se requiere VIEW DEFINITION.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.EAI_TRUNC_TABLE
 WHERE UPPER(TABLE_NAME) COLLATE DATABASE_DEFAULT=N'EAI.TAO_SALES_DOCS_LDR')
 THROW 51504,'EAI.TAO_SALES_DOCS_LDR no esta autorizada en EAI_TRUNC_TABLE.',1;
CREATE TABLE [$(StageTable)](LINEA nvarchar(max) COLLATE DATABASE_DEFAULT);
GO
:out ".venta_loader_lock\stamp.txt"
SELECT CONVERT(char(8),GETDATE(),112)+'.'+REPLACE(CONVERT(char(8),GETDATE(),108),':','');
GO
:out stdout
!! call loader.bat __cargar
:r ".venta_loader_lock\carga_estado.sql"
GO
:r "moveDailyInfo.sql"
GO
:out ".venta_loader_lock\resultado.txt"
SELECT Resultado FROM #ResultadoVenta;
GO
:out stdout
DROP TABLE [$(StageTable)];
EXEC sys.sp_releaseapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',@LockOwner='Session';
GO
