/*
  Correccion puntual confirmada en AZCRNMXNEVTD06 / T3QA, 2026-10-23.
  Ejecutar como sysadmin, sin transacciones abiertas ni implicitas.

  Concede unicamente EXECUTE sobre T3.PROC_T3_OT_GENERAL al rol existente
  T3SqlAgentJobExecutor. El permiso tambien permite que OBJECT_ID vea el objeto.
  No cambia propietarios, procedimientos, datos de negocio ni horarios.
  No inicia el job ni ejecuta documentos.

  Verifica el permiso y la visibilidad como el login tecnico ANTES de confirmar.
  Si la prueba falla (por ejemplo, por un DENY), revierte la concesion.
  La prueba no certifica todos los accesos transitivos del proceso de negocio.
*/
USE [T3QA];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
    THROW 51981, 'Ejecutar sin transacciones externas ni implicitas.', 1;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 51982, 'Ejecutar como sysadmin para verificar el login del job.', 1;

IF OBJECT_ID(N'T3.PROC_T3_OT_GENERAL', N'P') IS NULL
    THROW 51983, 'No existe T3.PROC_T3_OT_GENERAL en esta base.', 1;

IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
   OR ISNULL(IS_ROLEMEMBER(N'T3SqlAgentJobExecutor', N'T3_SQLAGENT_OWNER'), 0) <> 1
    THROW 51984, 'Verificar login, usuario y pertenencia al rol T3SqlAgentJobExecutor.', 1;

-- Conserva en el resultado el estado explicito previo del permiso en el rol.
SELECT '01_PERMISO_ANTES' AS Seccion, P.state_desc, P.permission_name
FROM sys.database_permissions AS P
WHERE P.class = 1 AND P.minor_id = 0
  AND P.major_id = OBJECT_ID(N'T3.PROC_T3_OT_GENERAL')
  AND P.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'T3SqlAgentJobExecutor')
  AND P.permission_name = N'EXECUTE';

DECLARE @Cookie VARBINARY(8000), @Suplantado BIT = 0,
        @PuedeEjecutar INT, @ObjectIdVisible INT;

BEGIN TRY
    BEGIN TRANSACTION;

    GRANT EXECUTE ON OBJECT::[T3].[PROC_T3_OT_GENERAL]
        TO [T3SqlAgentJobExecutor];

    EXECUTE AS LOGIN = 'T3_SQLAGENT_OWNER' WITH COOKIE INTO @Cookie;
    SET @Suplantado = 1;
    SET @PuedeEjecutar = HAS_PERMS_BY_NAME(N'T3.PROC_T3_OT_GENERAL', N'OBJECT', N'EXECUTE');
    SET @ObjectIdVisible = OBJECT_ID(N'T3.PROC_T3_OT_GENERAL', N'P');
    REVERT WITH COOKIE = @Cookie;
    SET @Suplantado = 0;

    IF ISNULL(@PuedeEjecutar, 0) <> 1 OR @ObjectIdVisible IS NULL
        THROW 51985, 'La cuenta tecnica no obtiene acceso efectivo; se revierte el permiso.', 1;

    COMMIT TRANSACTION;

    SELECT '02_PERMISO_VERIFICADO' AS Seccion,
           @@SERVERNAME AS Servidor, DB_NAME() AS BaseActual,
           N'T3_SQLAGENT_OWNER' AS LoginVerificado,
           N'T3.PROC_T3_OT_GENERAL' AS Objeto,
           @PuedeEjecutar AS PuedeEjecutar, @ObjectIdVisible AS ObjectIdVisible,
           N'Concesion confirmada; pendiente validar la siguiente ejecucion normal del job.' AS Resultado;
END TRY
BEGIN CATCH
    IF @Suplantado = 1
        REVERT WITH COOKIE = @Cookie;
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
