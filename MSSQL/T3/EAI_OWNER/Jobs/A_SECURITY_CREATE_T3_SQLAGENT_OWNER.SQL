/*
    Crea el login tecnico que sera propietario de los jobs de T3.

    Ejecucion
    ---------
    1. Debe ejecutarlo un miembro de sysadmin.
    2. Antes de la primera ejecucion, sustituya el valor de @LoginPassword.
    3. No conserve la contrasena real en control de versiones.

    Alcance
    -------
    - Crea el login SQL T3_SQLAGENT_OWNER si no existe.
    - Crea su usuario en msdb y lo agrega a SQLAgentUserRole.
    - Crea su usuario en T3QA.
    - No le concede sysadmin.
    - No reasigna jobs ni schedules; esas acciones deben realizarse despues,
      de manera explicita y solamente para los objetos de T3.
*/

USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LoginName     SYSNAME       = N'T3_SQLAGENT_OWNER';
DECLARE @LoginPassword NVARCHAR(128) = N'Bosque$49Delta!Marfil_76#';
DECLARE @TargetDatabase SYSNAME      = N'T3QA';

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51100, 'Este script debe ser ejecutado por un miembro de sysadmin.', 1;
END;

IF DB_ID(@TargetDatabase) IS NULL
BEGIN
    THROW 51101, 'No existe la base de datos T3QA en esta instancia.', 1;
END;

IF SUSER_ID(@LoginName) IS NULL
BEGIN
    IF @LoginPassword = N'REEMPLAZAR_CON_PASSWORD_SEGURO'
    BEGIN
        THROW 51102, 'Sustituya @LoginPassword por una contrasena segura antes de crear el login.', 1;
    END;

    DECLARE @CreateLoginSql NVARCHAR(MAX);

    SET @CreateLoginSql =
        N'CREATE LOGIN ' + QUOTENAME(@LoginName)
        + N' WITH PASSWORD = ' + QUOTENAME(@LoginPassword, '''')
        + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF,'
        + N' DEFAULT_DATABASE = ' + QUOTENAME(@TargetDatabase) + N';';

    EXEC sys.sp_executesql @CreateLoginSql;

    -- Reduce el tiempo durante el que la contrasena permanece en la variable.
    SET @LoginPassword = REPLICATE(N'0', LEN(@LoginPassword));
END
ELSE IF NOT EXISTS
(
    SELECT 1
    FROM sys.server_principals
    WHERE [name] = @LoginName
      AND [type] = 'S'
)
BEGIN
    THROW 51103, 'Ya existe un principal T3_SQLAGENT_OWNER, pero no es un login SQL.', 1;
END;
GO

USE [msdb];
GO

IF USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
BEGIN
    CREATE USER [T3_SQLAGENT_OWNER]
        FOR LOGIN [T3_SQLAGENT_OWNER];
END
ELSE IF
(
    SELECT [sid]
    FROM sys.database_principals
    WHERE [name] = N'T3_SQLAGENT_OWNER'
) <> SUSER_SID(N'T3_SQLAGENT_OWNER')
BEGIN
    THROW 51104, 'El usuario msdb.T3_SQLAGENT_OWNER no corresponde al login del servidor.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS DRM
    INNER JOIN sys.database_principals AS R
        ON R.principal_id = DRM.role_principal_id
    INNER JOIN sys.database_principals AS M
        ON M.principal_id = DRM.member_principal_id
    WHERE R.[name] = N'SQLAgentUserRole'
      AND M.[name] = N'T3_SQLAGENT_OWNER'
)
BEGIN
    ALTER ROLE [SQLAgentUserRole]
        ADD MEMBER [T3_SQLAGENT_OWNER];
END;
GO

USE [T3QA];
GO

IF USER_ID(N'T3_SQLAGENT_OWNER') IS NULL
BEGIN
    CREATE USER [T3_SQLAGENT_OWNER]
        FOR LOGIN [T3_SQLAGENT_OWNER];
END
ELSE IF
(
    SELECT [sid]
    FROM sys.database_principals
    WHERE [name] = N'T3_SQLAGENT_OWNER'
) <> SUSER_SID(N'T3_SQLAGENT_OWNER')
BEGIN
    THROW 51105, 'El usuario T3QA.T3_SQLAGENT_OWNER no corresponde al login del servidor.', 1;
END;
GO

SELECT
    SP.[name] AS Login_Name,
    SP.[type_desc] AS Login_Type,
    SP.is_disabled,
    SUSER_SNAME(D.owner_sid) AS T3QA_Database_Owner,
    IS_SRVROLEMEMBER(N'sysadmin', SP.[name]) AS Is_Sysadmin
FROM master.sys.server_principals AS SP
LEFT JOIN master.sys.databases AS D
    ON D.[name] = N'T3QA'
WHERE SP.[name] = N'T3_SQLAGENT_OWNER';

SELECT
    DP.[name] AS Msdb_User,
    R.[name] AS Agent_Role
FROM msdb.sys.database_principals AS DP
LEFT JOIN msdb.sys.database_role_members AS DRM
    ON DRM.member_principal_id = DP.principal_id
LEFT JOIN msdb.sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
WHERE DP.[name] = N'T3_SQLAGENT_OWNER';
GO

/*
    Siguientes pasos para el DBA
    ----------------------------
    1. Reasignar exclusivamente los jobs T3:

       EXEC msdb.dbo.sp_update_job
           @job_name = N'<NOMBRE_JOB>',
           @owner_login_name = N'T3_SQLAGENT_OWNER';

    2. Reasignar sus schedules exclusivos:

       EXEC msdb.dbo.sp_update_schedule
           @name = N'<NOMBRE_SCHEDULE>',
           @owner_login_name = N'T3_SQLAGENT_OWNER';

    3. Conceder en T3QA solamente los permisos que necesiten los steps de esos
       jobs. No agregar el login a sysadmin ni a db_owner.
*/
