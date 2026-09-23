/*
    PASO 4 DEL ROLLBACK TOTAL
    =========================
    Elimina el wrapper controlado, el procedimiento administrativo de altas y
    los roles creados para la solucion.
    Los usuarios NO se eliminan aqui; eso se hace posteriormente y permite
    diagnosticar dependencias con mayor claridad.
*/
USE [msdb];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 51640, 'Este paso debe ser ejecutado por un miembro de sysadmin.', 1;

-- Cambiar a 1 solo despues de revisar que los pasos 00 a 03 finalizaron bien.
DECLARE @ConfirmSecurityRollback BIT = 0;
IF @ConfirmSecurityRollback <> 1
    THROW 51641, 'Configure @ConfirmSecurityRollback = 1 para retirar la seguridad de T3.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    /* El wrapper se elimina primero porque contiene EXECUTE AS USER y depende
       del usuario tecnico de msdb. */
    DROP PROCEDURE IF EXISTS dbo.T3_JOB_NEXT_RUN;

    /* Este helper fue creado por D1 y deja de tener sentido cuando se retiran
       los roles que administra. */
    DROP PROCEDURE IF EXISTS dbo.T3_ADD_JOB_EXECUTORS;

    DECLARE @Sql NVARCHAR(MAX) = N'';

    -- Retira todos los miembros antes de eliminar el rol de msdb.
    SELECT @Sql += N'ALTER ROLE [T3JobExecutors] DROP MEMBER '
                 + QUOTENAME(M.name) + N';' + CHAR(13)
    FROM msdb.sys.database_role_members AS DRM
    JOIN msdb.sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
    JOIN msdb.sys.database_principals AS M ON M.principal_id = DRM.member_principal_id
    WHERE R.name = N'T3JobExecutors';

    IF @Sql <> N'' EXEC sys.sp_executesql @Sql;
    IF DATABASE_PRINCIPAL_ID(N'T3JobExecutors') IS NOT NULL
        DROP ROLE [T3JobExecutors];

    /* Hace lo mismo en T3QA. QUOTENAME protege nombres de usuario que pudieran
       contener caracteres especiales. */
    SET @Sql = N'';
    SELECT @Sql += N'USE [T3QA]; ALTER ROLE ' + QUOTENAME(R.name)
                 + N' DROP MEMBER ' + QUOTENAME(M.name) + N';' + CHAR(13)
    FROM T3QA.sys.database_role_members AS DRM
    JOIN T3QA.sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
    JOIN T3QA.sys.database_principals AS M ON M.principal_id = DRM.member_principal_id
    WHERE R.name IN (N'T3BODExecutors', N'T3SqlAgentJobExecutor');

    IF @Sql <> N'' EXEC sys.sp_executesql @Sql;

    IF EXISTS (SELECT 1 FROM T3QA.sys.database_principals WHERE name = N'T3BODExecutors')
        EXEC (N'USE [T3QA]; DROP ROLE [T3BODExecutors];');
    IF EXISTS (SELECT 1 FROM T3QA.sys.database_principals WHERE name = N'T3SqlAgentJobExecutor')
        EXEC (N'USE [T3QA]; DROP ROLE [T3SqlAgentJobExecutor];');

    COMMIT TRANSACTION;
    PRINT 'Paso 4 completado: wrapper, helper administrativo y roles eliminados.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
