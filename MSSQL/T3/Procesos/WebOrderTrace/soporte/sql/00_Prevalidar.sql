SET NOCOUNT ON;
IF TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))<16
 THROW 51040,'Esta entrega requiere SQL Server 2022 o posterior.',1;
IF (SELECT compatibility_level FROM sys.databases WHERE name=DB_NAME())<140
 THROW 51041,'Se requiere nivel de compatibilidad 140 o superior.',1;
DECLARE @required TABLE(Name nvarchar(128),Type char(2));
INSERT @required VALUES
 ('EAI_OWNER.WO_TMP_ORDER','U'),('EAI_OWNER.WO_TMP_INVOICE','U'),
 ('T3.PREVENTA_GENERAL','U'),('T3.PREVENTA_DETALLE','U'),
 ('T3.FACTURA_GENERAL','U'),('T3.FACTURA_DETALLE','U'),
 ('T3.CFDI_COBRANZA','U'),('EAI.TAO_CARTERA_SAP_LDR','U'),
 ('EAI.CONTROL_REPORTE','U'),('EAI_OWNER.GET_CLEARING_STATUS','FN');
SELECT Name,CASE WHEN OBJECT_ID(Name,Type) IS NULL THEN 'FALTA / SIN VISIBILIDAD' ELSE 'EXISTE' END Estado
FROM @required;
IF EXISTS(SELECT 1 FROM @required WHERE OBJECT_ID(Name,Type) IS NULL)
 THROW 51042,'Faltan objetos requeridos o permisos para verlos.',1;
IF (SELECT COUNT(*) FROM EAI.CONTROL_REPORTE WHERE REPORTE='AUTO-NOT DELIVERED')<>1
 THROW 51043,'CONTROL_REPORTE requiere exactamente una fila AUTO-NOT DELIVERED.',1;
SELECT CONVERT(varchar(128),@@SERVERNAME) Servidor,CONVERT(varchar(128),DB_NAME()) BaseDatos,
 CONVERT(varchar(30),SERVERPROPERTY('ProductVersion')) Version,
 CONVERT(varchar(128),ORIGINAL_LOGIN()) Login,CONVERT(varchar(128),USER_NAME()) UsuarioBD,
 CONVERT(varchar(128),DATABASEPROPERTYEX(DB_NAME(),'Collation')) Collation;
SELECT HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CREATE TABLE') PuedeCrearTablas,
 HAS_PERMS_BY_NAME('EAI_OWNER','SCHEMA','ALTER') PuedeAlterarEsquema,
 HAS_PERMS_BY_NAME('EAI_OWNER.WO_TMP_ORDER','OBJECT','INSERT') PuedeInsertarOrdenes,
 HAS_PERMS_BY_NAME('EAI_OWNER.WO_TMP_ORDER','OBJECT','DELETE') PuedeReemplazarOrdenes,
 HAS_PERMS_BY_NAME('EAI_OWNER.WO_TMP_INVOICE','OBJECT','INSERT') PuedeInsertarFacturas,
 HAS_PERMS_BY_NAME('EAI_OWNER.WO_TMP_INVOICE','OBJECT','DELETE') PuedeReemplazarFacturas;
PRINT 'Prevalidacion de objetos terminada. Revisar permisos y datos antes de cargar.';
