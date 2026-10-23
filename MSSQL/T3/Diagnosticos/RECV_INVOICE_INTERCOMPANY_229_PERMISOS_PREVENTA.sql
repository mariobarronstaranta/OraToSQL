/*
  Ejecutar como sysadmin en T3QA, sin transacciones abiertas/implicitas.
  Error confirmado: PID 26516078, DELETE denegado en T3.PREVENTA_GENERAL.
  Permisos limitados a accesos T3 directos de EAI_OWNER.INVOICE_TO_PREVENTA:
    - reconstruccion de general, detalle y condiciones;
    - complemento RF, material y llamada a DELIVERY_WA_OXXO.
  No modifica datos, SP, propietarios ni jobs; no reprocesa mensajes.
  La comprobacion suplanta el login del job sin ejecutar documentos.
  Si algun permiso efectivo falta, revierte todas las concesiones de este script.
  No certifica permisos transitivos de los otros procedimientos de la ruta.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
    THROW 51986, 'Ejecutar sin transacciones externas ni implicitas.', 1;
IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 51987, 'Ejecutar como sysadmin para verificar el login del job.', 1;
IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor', N'T3_SQLAGENT_OWNER'), 0) <> 1
    THROW 51988, 'Verificar login, usuario y pertenencia al rol T3SqlAgentJobExecutor.', 1;

DECLARE @Permisos TABLE (Objeto NVARCHAR(256), Permiso SYSNAME);
INSERT INTO @Permisos VALUES
 (N'T3.PREVENTA_GENERAL',N'SELECT'),
 (N'T3.PREVENTA_GENERAL',N'INSERT'),
 (N'T3.PREVENTA_GENERAL',N'UPDATE'),
 (N'T3.PREVENTA_GENERAL',N'DELETE'),
 (N'T3.PREVENTA_DETALLE',N'SELECT'),
 (N'T3.PREVENTA_DETALLE',N'INSERT'),
 (N'T3.PREVENTA_DETALLE',N'DELETE'),
 (N'T3.PREVENTA_CONDICIONES',N'SELECT'),
 (N'T3.PREVENTA_CONDICIONES',N'INSERT'),
 (N'T3.PREVENTA_CONDICIONES',N'DELETE'),
 (N'T3.RF_COMPLEMENTO',N'SELECT'),
 (N'T3.RF_COMPLEMENTO',N'INSERT'),
 (N'T3.RF_COMPLEMENTO',N'DELETE'),
 (N'T3.MATERIAL',N'SELECT'),
 (N'T3.DELIVERY_WA_OXXO',N'EXECUTE');

IF EXISTS (SELECT 1 FROM @Permisos WHERE OBJECT_ID(Objeto) IS NULL)
BEGIN
    SELECT DISTINCT Objeto AS ObjetoFaltante FROM @Permisos WHERE OBJECT_ID(Objeto) IS NULL;
    THROW 51989, 'Faltan objetos de la ruta; no se concedieron permisos.', 1;
END;

DECLARE @Sql NVARCHAR(MAX) = N'', @Cookie VARBINARY(8000), @Suplantado BIT = 0;
DECLARE @Verificacion TABLE (Objeto NVARCHAR(256), Permiso SYSNAME, PermisoEfectivo INT);
SELECT @Sql = @Sql + N'GRANT ' + Permiso + N' ON OBJECT::'
    + QUOTENAME(PARSENAME(Objeto,2)) + N'.' + QUOTENAME(PARSENAME(Objeto,1))
    + N' TO [T3SqlAgentJobExecutor];' + NCHAR(10)
FROM @Permisos;

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql @Sql;

    EXECUTE AS LOGIN = 'T3_SQLAGENT_OWNER' WITH COOKIE INTO @Cookie;
    SET @Suplantado = 1;
    INSERT INTO @Verificacion (Objeto, Permiso, PermisoEfectivo)
    SELECT Objeto, Permiso, HAS_PERMS_BY_NAME(Objeto, N'OBJECT', Permiso)
    FROM @Permisos;
    REVERT WITH COOKIE = @Cookie;
    SET @Suplantado = 0;

    IF EXISTS (SELECT 1 FROM @Verificacion WHERE ISNULL(PermisoEfectivo,0) <> 1)
    BEGIN
        SELECT * FROM @Verificacion WHERE ISNULL(PermisoEfectivo,0) <> 1;
        THROW 51990, 'Faltan permisos efectivos; se revierten las concesiones.', 1;
    END;
    COMMIT TRANSACTION;

    SELECT N'PERMISOS_VERIFICADOS' AS Seccion, @@SERVERNAME AS Servidor,
           DB_NAME() AS BaseActual, N'T3_SQLAGENT_OWNER' AS LoginVerificado,
           Objeto, Permiso, PermisoEfectivo
    FROM @Verificacion ORDER BY Objeto, Permiso;
END TRY
BEGIN CATCH
    IF @Suplantado = 1 REVERT WITH COOKIE = @Cookie;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
