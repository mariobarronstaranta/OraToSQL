/*
  Correccion de permisos de ambas rutas intercompany, T3QA / 2026-10-23.
  Ejecutar como sysadmin, sin transacciones externas ni implicitas.
  Incluye los quince permisos de PREVENTA del script anterior y catorce mas
  de OTROS/catalogos y lectura de partners para la generacion desde T3.
  La reconstruccion de documentos y los enriquecimientos existen en Oracle.
  Puede ejecutarse aunque ya se haya aplicado el ajuste de PREVENTA.
  Verifica 29 permisos efectivos como T3_SQLAGENT_OWNER antes de confirmar.
  No modifica datos de negocio, SP, estados, propietarios ni jobs.
  No reprocesa documentos y no certifica la generacion/timbrado posterior.
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
 (N'T3.DELIVERY_WA_OXXO',N'EXECUTE'),
 (N'T3.OTROS_GENERAL',N'SELECT'),
 (N'T3.OTROS_GENERAL',N'INSERT'),
 (N'T3.OTROS_GENERAL',N'UPDATE'),
 (N'T3.OTROS_GENERAL',N'DELETE'),
 (N'T3.OTROS_DETALLE',N'SELECT'),
 (N'T3.OTROS_DETALLE',N'INSERT'),
 (N'T3.OTROS_DETALLE',N'UPDATE'),
 (N'T3.OTROS_DETALLE',N'DELETE'),
 (N'T3.OTROS_CONDICIONES',N'SELECT'),
 (N'T3.OTROS_CONDICIONES',N'INSERT'),
 (N'T3.OTROS_CONDICIONES',N'DELETE'),
 (N'T3.CFDI_PRODSERV',N'SELECT'),
 (N'T3.CFDI_PRODSERV_WA',N'SELECT'),
 (N'EAI_OWNER.TMP_DOCUMENT_PARTNERS',N'SELECT');

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
