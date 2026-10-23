/*
  Error 229 reportado en la corrida automatica de las 17:25, 2026-10-23.
  Ejecutar como sysadmin en T3QA, sin transacciones externas ni implicitas.
  Concede solo SELECT en EAI_OWNER.TMP_DOCUMENT_PARTNERS al rol del job.
  T3.PROC_V40_GENERAR_OTROS consulta esta tabla para construir la cabecera.
  No concede UPDATE/INSERT/DELETE ni acceso a todo el esquema.
  Verifica lectura efectiva como T3_SQLAGENT_OWNER antes de COMMIT.
  No ejecuta procedimientos de negocio, jobs ni reprocesa mensajes.
  Si falla la comprobacion, revierte la concesion de esta ejecucion.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
    THROW 51981, 'Ejecutar sin transacciones externas ni implicitas.', 1;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 51982, 'Ejecutar como sysadmin para verificar el login del job.', 1;

IF OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_PARTNERS', N'U') IS NULL
    THROW 51983, 'No existe EAI_OWNER.TMP_DOCUMENT_PARTNERS en esta base.', 1;

IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor', N'T3_SQLAGENT_OWNER'), 0) <> 1
    THROW 51984, 'Verificar login, usuario y pertenencia al rol T3SqlAgentJobExecutor.', 1;

-- Conserva en el resultado el estado explicito previo del permiso en el rol.
SELECT '01_PERMISO_ANTES' AS Seccion, P.state_desc, P.permission_name
FROM sys.database_permissions AS P
WHERE P.class = 1 AND P.minor_id = 0
  AND P.major_id = OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_PARTNERS')
  AND P.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor')
  AND P.permission_name = N'SELECT';

DECLARE @Cookie VARBINARY(8000), @Suplantado BIT = 0,
        @PuedeLeer INT, @ObjectIdVisible INT;

BEGIN TRY
    BEGIN TRANSACTION;

    GRANT SELECT ON OBJECT::[EAI_OWNER].[TMP_DOCUMENT_PARTNERS]
        TO [T3SqlAgentJobExecutor];

    EXECUTE AS LOGIN = 'T3_SQLAGENT_OWNER' WITH COOKIE INTO @Cookie;
    SET @Suplantado = 1;
    SET @PuedeLeer = HAS_PERMS_BY_NAME(N'EAI_OWNER.TMP_DOCUMENT_PARTNERS', N'OBJECT', N'SELECT');
    SET @ObjectIdVisible = OBJECT_ID(N'EAI_OWNER.TMP_DOCUMENT_PARTNERS', N'U');
    REVERT WITH COOKIE = @Cookie;
    SET @Suplantado = 0;

    IF ISNULL(@PuedeLeer, 0) <> 1 OR @ObjectIdVisible IS NULL
        THROW 51985, 'La cuenta tecnica no obtiene acceso efectivo; se revierte el permiso.', 1;

    COMMIT TRANSACTION;

    SELECT '02_PERMISO_VERIFICADO' AS Seccion,
           @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
           N'T3_SQLAGENT_OWNER' AS LoginVerificado,
           N'EAI_OWNER.TMP_DOCUMENT_PARTNERS' AS Objeto,
           @PuedeLeer AS PuedeLeer, @ObjectIdVisible AS ObjectIdVisible,
           N'Concesion confirmada; pendiente validar la siguiente ejecucion normal del job.' AS Resultado;
END TRY
BEGIN CATCH
    IF @Suplantado = 1
        REVERT WITH COOKIE = @Cookie;
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
