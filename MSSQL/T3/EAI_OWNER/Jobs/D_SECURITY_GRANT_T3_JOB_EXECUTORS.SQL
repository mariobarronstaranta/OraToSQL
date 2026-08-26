/*
    Crea los roles controlados que permiten ejecutar:
        - msdb.dbo.T3_JOB_NEXT_RUN
        - T3QA.T3.PROC_T3_BOD

    Agrega en una sola ejecucion los logins autorizados definidos en
    @TeamLogins. El script es idempotente y no agrega a los usuarios a ningun
    rol fijo de SQL Server Agent.

    Debe ejecutarlo un miembro de sysadmin despues de ejecutar el script B.
*/

USE [msdb];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @MsdbRoleName SYSNAME = N'T3JobExecutors';
DECLARE @T3RoleName SYSNAME = N'T3BODExecutors';
DECLARE @TechnicalLogin SYSNAME = N'T3_SQLAGENT_OWNER';
DECLARE @Sql NVARCHAR(MAX);

DECLARE @TeamLogins TABLE
(
    LoginName SYSNAME NOT NULL PRIMARY KEY
);

INSERT INTO @TeamLogins (LoginName)
VALUES
    (N'IX85234150'),
    (N'AT85233588'),
    (N'AT85233589'),
    (N'T3');

/* Todas las validaciones se realizan antes de modificar permisos. */
IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
BEGIN
    THROW 51400, 'Este script debe ser ejecutado por un miembro de sysadmin.', 1;
END;

IF DB_ID(N'T3QA') IS NULL
BEGIN
    THROW 51401, 'No existe la base de datos T3QA.', 1;
END;

IF OBJECT_ID(N'dbo.T3_JOB_NEXT_RUN', N'P') IS NULL
BEGIN
    THROW 51402, 'No existe msdb.dbo.T3_JOB_NEXT_RUN. Ejecute primero el script B.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM T3QA.sys.procedures AS P
    INNER JOIN T3QA.sys.schemas AS S
        ON S.schema_id = P.schema_id
    WHERE S.[name] = N'T3'
      AND P.[name] = N'PROC_T3_BOD'
)
BEGIN
    THROW 51403, 'No existe T3QA.T3.PROC_T3_BOD.', 1;
END;

IF SUSER_ID(@TechnicalLogin) IS NULL OR USER_ID(@TechnicalLogin) IS NULL
BEGIN
    THROW 51404, 'No existe el login o usuario msdb T3_SQLAGENT_OWNER.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @TeamLogins AS T
    LEFT JOIN master.sys.server_principals AS SP
        ON SP.[name] = T.LoginName
    WHERE SP.principal_id IS NULL
)
BEGIN
    SELECT T.LoginName AS Missing_Server_Login
    FROM @TeamLogins AS T
    LEFT JOIN master.sys.server_principals AS SP
        ON SP.[name] = T.LoginName
    WHERE SP.principal_id IS NULL
    ORDER BY T.LoginName;

    THROW 51405, 'Uno o mas logins de @TeamLogins no existen en la instancia.', 1;
END;

IF DATABASE_PRINCIPAL_ID(@MsdbRoleName) IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.database_principals
       WHERE principal_id = DATABASE_PRINCIPAL_ID(@MsdbRoleName)
         AND [type] = 'R'
   )
BEGIN
    THROW 51406, 'Ya existe T3JobExecutors en msdb, pero no es un rol de base de datos.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM T3QA.sys.database_principals
    WHERE [name] = @T3RoleName
      AND [type] <> 'R'
)
BEGIN
    THROW 51407, 'Ya existe T3BODExecutors en T3QA, pero no es un rol de base de datos.', 1;
END;

/* Detecta usuarios homonimos asociados a otro login antes de crear objetos. */
IF EXISTS
(
    SELECT 1
    FROM @TeamLogins AS T
    INNER JOIN sys.database_principals AS DP
        ON DP.[name] = T.LoginName
    WHERE DP.[sid] IS NULL
       OR DP.[sid] <> SUSER_SID(T.LoginName)
)
BEGIN
    THROW 51408, 'Existe en msdb un usuario homonimo asociado a otro SID.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM @TeamLogins AS T
    INNER JOIN T3QA.sys.database_principals AS DP
        ON DP.[name] = T.LoginName
    WHERE DP.[sid] IS NULL
       OR DP.[sid] <> SUSER_SID(T.LoginName)
)
BEGIN
    THROW 51409, 'Existe en T3QA un usuario homonimo asociado a otro SID.', 1;
END;

DECLARE
    @LoginName SYSNAME,
    @MsdbUser SYSNAME,
    @T3User SYSNAME;

DECLARE TeamCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT LoginName
FROM @TeamLogins
ORDER BY LoginName;

BEGIN TRY
    BEGIN TRANSACTION;

        IF DATABASE_PRINCIPAL_ID(@MsdbRoleName) IS NULL
        BEGIN
            SET @Sql =
                N'CREATE ROLE ' + QUOTENAME(@MsdbRoleName)
                + N' AUTHORIZATION [dbo];';
            EXEC sys.sp_executesql @Sql;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM T3QA.sys.database_principals
            WHERE [name] = @T3RoleName
              AND [type] = 'R'
        )
        BEGIN
            SET @Sql =
                N'USE [T3QA]; CREATE ROLE ' + QUOTENAME(@T3RoleName)
                + N' AUTHORIZATION [dbo];';
            EXEC sys.sp_executesql @Sql;
        END;

        GRANT EXECUTE ON OBJECT::[dbo].[T3_JOB_NEXT_RUN]
            TO [T3JobExecutors];

        GRANT VIEW DEFINITION ON OBJECT::[dbo].[T3_JOB_NEXT_RUN]
            TO [T3JobExecutors];

        SET @Sql =
            N'USE [T3QA]; GRANT EXECUTE ON OBJECT::[T3].[PROC_T3_BOD] TO '
            + QUOTENAME(@T3RoleName) + N';';
        EXEC sys.sp_executesql @Sql;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.database_role_members AS DRM
            INNER JOIN sys.database_principals AS R
                ON R.principal_id = DRM.role_principal_id
            INNER JOIN sys.database_principals AS M
                ON M.principal_id = DRM.member_principal_id
            WHERE R.[name] = @MsdbRoleName
              AND M.[name] = @TechnicalLogin
        )
        BEGIN
            SET @Sql =
                N'ALTER ROLE ' + QUOTENAME(@MsdbRoleName)
                + N' ADD MEMBER ' + QUOTENAME(@TechnicalLogin) + N';';
            EXEC sys.sp_executesql @Sql;
        END;

        OPEN TeamCursor;
        FETCH NEXT FROM TeamCursor INTO @LoginName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @MsdbUser = NULL;
            SET @T3User = NULL;

            SELECT @MsdbUser = [name]
            FROM sys.database_principals
            WHERE [sid] = SUSER_SID(@LoginName);

            IF @MsdbUser IS NULL
            BEGIN
                SET @Sql =
                    N'CREATE USER ' + QUOTENAME(@LoginName)
                    + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
                EXEC sys.sp_executesql @Sql;
                SET @MsdbUser = @LoginName;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM sys.database_role_members AS DRM
                INNER JOIN sys.database_principals AS R
                    ON R.principal_id = DRM.role_principal_id
                INNER JOIN sys.database_principals AS M
                    ON M.principal_id = DRM.member_principal_id
                WHERE R.[name] = @MsdbRoleName
                  AND M.[name] = @MsdbUser
            )
            BEGIN
                SET @Sql =
                    N'ALTER ROLE ' + QUOTENAME(@MsdbRoleName)
                    + N' ADD MEMBER ' + QUOTENAME(@MsdbUser) + N';';
                EXEC sys.sp_executesql @Sql;
            END;

            SELECT @T3User = [name]
            FROM T3QA.sys.database_principals
            WHERE [sid] = SUSER_SID(@LoginName);

            IF @T3User IS NULL
            BEGIN
                SET @Sql =
                    N'USE [T3QA]; CREATE USER ' + QUOTENAME(@LoginName)
                    + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
                EXEC sys.sp_executesql @Sql;
                SET @T3User = @LoginName;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM T3QA.sys.database_role_members AS DRM
                INNER JOIN T3QA.sys.database_principals AS R
                    ON R.principal_id = DRM.role_principal_id
                INNER JOIN T3QA.sys.database_principals AS M
                    ON M.principal_id = DRM.member_principal_id
                WHERE R.[name] = @T3RoleName
                  AND M.[name] = @T3User
            )
            BEGIN
                SET @Sql =
                    N'USE [T3QA]; ALTER ROLE ' + QUOTENAME(@T3RoleName)
                    + N' ADD MEMBER ' + QUOTENAME(@T3User) + N';';
                EXEC sys.sp_executesql @Sql;
            END;

            FETCH NEXT FROM TeamCursor INTO @LoginName;
        END;

        CLOSE TeamCursor;
        DEALLOCATE TeamCursor;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'TeamCursor') >= 0
        CLOSE TeamCursor;

    IF CURSOR_STATUS('local', 'TeamCursor') > -3
        DEALLOCATE TeamCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

SELECT
    R.[name] AS RoleName,
    M.[name] AS MemberName,
    M.[type_desc] AS MemberType
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN sys.database_principals AS M
    ON M.principal_id = DRM.member_principal_id
WHERE R.[name] = @MsdbRoleName
ORDER BY M.[name];

SELECT
    R.[name] AS T3QARoleName,
    M.[name] AS T3QAMemberName,
    M.[type_desc] AS MemberType
FROM T3QA.sys.database_role_members AS DRM
INNER JOIN T3QA.sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN T3QA.sys.database_principals AS M
    ON M.principal_id = DRM.member_principal_id
WHERE R.[name] = @T3RoleName
ORDER BY M.[name];
GO
