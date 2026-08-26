/*
    PASO 5 DEL ROLLBACK TOTAL
    =========================
    Elimina el usuario tecnico de T3QA/msdb y finalmente su login de servidor.

    NO ejecute este archivo si T3_SQLAGENT_OWNER existia antes de la migracion
    o si tambien es utilizado por otra aplicacion.
*/
USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 51650, 'Este paso debe ser ejecutado por un miembro de sysadmin.', 1;

-- Confirmacion intencional para evitar borrar accidentalmente el login tecnico.
DECLARE @ConfirmDropTechnicalLogin BIT = 0;
IF @ConfirmDropTechnicalLogin <> 1
    THROW 51651, 'Configure @ConfirmDropTechnicalLogin = 1 despues de validar dependencias.', 1;

DECLARE @TechnicalSid VARBINARY(85) = SUSER_SID(N'T3_SQLAGENT_OWNER');

IF @TechnicalSid IS NULL
BEGIN
    PRINT 'El login T3_SQLAGENT_OWNER ya no existe; no hay nada que eliminar.';
    RETURN;
END;

-- Un login propietario no se puede borrar de forma segura.
IF EXISTS (SELECT 1 FROM sys.databases WHERE owner_sid = @TechnicalSid)
    THROW 51652, 'T3_SQLAGENT_OWNER es propietario de una base de datos.', 1;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE owner_sid = @TechnicalSid)
    THROW 51653, 'Todavia existen jobs propiedad de T3_SQLAGENT_OWNER.', 1;

IF OBJECT_ID(N'msdb.dbo.T3_JOB_NEXT_RUN', N'P') IS NOT NULL
    THROW 51654, 'Todavia existe msdb.dbo.T3_JOB_NEXT_RUN; ejecute primero el paso 4.', 1;

-- Comprueba ownership de esquemas antes de intentar DROP USER.
IF EXISTS
(
    SELECT 1 FROM T3QA.sys.schemas AS S
    JOIN T3QA.sys.database_principals AS P ON P.principal_id = S.principal_id
    WHERE P.name = N'T3_SQLAGENT_OWNER'
)
    THROW 51655, 'El usuario tecnico es propietario de un esquema en T3QA.', 1;

IF EXISTS
(
    SELECT 1 FROM msdb.sys.schemas AS S
    JOIN msdb.sys.database_principals AS P ON P.principal_id = S.principal_id
    WHERE P.name = N'T3_SQLAGENT_OWNER'
)
    THROW 51656, 'El usuario tecnico es propietario de un esquema en msdb.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Retira membresias restantes, incluso si alguien agrego al usuario a un
       rol fijo adicional despues de la instalacion. */
    DECLARE @Sql NVARCHAR(MAX) = N'';
    SELECT @Sql += N'USE [msdb]; ALTER ROLE ' + QUOTENAME(R.name)
                 + N' DROP MEMBER [T3_SQLAGENT_OWNER];' + CHAR(13)
    FROM msdb.sys.database_role_members AS DRM
    JOIN msdb.sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
    JOIN msdb.sys.database_principals AS M ON M.principal_id = DRM.member_principal_id
    WHERE M.name = N'T3_SQLAGENT_OWNER';

    IF @Sql <> N'' EXEC sys.sp_executesql @Sql;

    IF EXISTS (SELECT 1 FROM T3QA.sys.database_principals WHERE name = N'T3_SQLAGENT_OWNER')
        EXEC (N'USE [T3QA]; DROP USER [T3_SQLAGENT_OWNER];');

    IF EXISTS (SELECT 1 FROM msdb.sys.database_principals WHERE name = N'T3_SQLAGENT_OWNER')
        EXEC (N'USE [msdb]; DROP USER [T3_SQLAGENT_OWNER];');

    DROP LOGIN [T3_SQLAGENT_OWNER];

    COMMIT TRANSACTION;
    PRINT 'Paso 5 completado: usuario y login T3_SQLAGENT_OWNER eliminados.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
