/*
    Crea el procedimiento administrativo:

        msdb.dbo.T3_ADD_JOB_EXECUTORS

    Objetivo
    --------
    Facilitar las altas posteriores de operadores sin editar nuevamente toda la
    logica del script D. El DBA proporciona logins separados por comas y este
    procedimiento:

      1. Limpia espacios y elimina nombres repetidos.
      2. Valida que todos sean logins habilitados del servidor.
      3. Crea, si hace falta, sus usuarios en msdb y T3QA.
      4. Los agrega a msdb.T3JobExecutors y T3QA.T3BODExecutors.
      5. Realiza todos los cambios en una sola transaccion.

    Prerrequisito
    -------------
    Ejecutar primero D_SECURITY_GRANT_T3_JOB_EXECUTORS.SQL. Este procedimiento
    no crea ni cambia los roles base; solamente incorpora nuevos miembros.

    Seguridad
    ---------
    La ejecucion exige que el caller sea sysadmin. No se concede EXECUTE a
    public ni a los operadores. Los nombres se protegen con QUOTENAME antes de
    formar cualquier instruccion dinamica.

    Ejemplos (NO se ejecutan automaticamente):

        EXEC msdb.dbo.T3_ADD_JOB_EXECUTORS
            @LoginNames = N'Operador_SQL_Jobs';

        EXEC msdb.dbo.T3_ADD_JOB_EXECUTORS
            @LoginNames = N'IX85234150, AT85233588, DOMINIO\Operador_SQL_Jobs';

    Nota: la coma es el separador y por ello no se admiten nombres que incluyan
    una coma como parte del propio login.
*/
USE [msdb];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[T3_ADD_JOB_EXECUTORS]
    @LoginNames NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MsdbRoleName SYSNAME = N'T3JobExecutors';
    DECLARE @T3RoleName SYSNAME = N'T3BODExecutors';
    DECLARE @TechnicalLogin SYSNAME = N'T3_SQLAGENT_OWNER';
    DECLARE @Sql NVARCHAR(MAX);

    /* Sólo un DBA sysadmin puede dar de alta operadores en ambos databases. */
    IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
        THROW 51420, 'T3_ADD_JOB_EXECUTORS debe ser ejecutado por un miembro de sysadmin.', 1;

    IF @LoginNames IS NULL OR LEN(LTRIM(RTRIM(@LoginNames))) = 0
        THROW 51421, 'Proporcione al menos un login en @LoginNames.', 1;

    IF DB_ID(N'T3QA') IS NULL
        THROW 51422, 'No existe la base de datos T3QA.', 1;

    /* Los roles y permisos base pertenecen al despliegue inicial del script D. */
    IF DATABASE_PRINCIPAL_ID(@MsdbRoleName) IS NULL
       OR NOT EXISTS
          (
              SELECT 1
              FROM sys.database_principals
              WHERE principal_id = DATABASE_PRINCIPAL_ID(@MsdbRoleName)
                AND [type] = 'R'
          )
        THROW 51423, 'No existe el rol msdb.T3JobExecutors. Ejecute primero el script D.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM T3QA.sys.database_principals
        WHERE [name] = @T3RoleName
          AND [type] = 'R'
    )
        THROW 51424, 'No existe el rol T3QA.T3BODExecutors. Ejecute primero el script D.', 1;

    IF OBJECT_ID(N'dbo.T3_JOB_NEXT_RUN', N'P') IS NULL
        THROW 51425, 'No existe msdb.dbo.T3_JOB_NEXT_RUN. Ejecute primero el script B.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM T3QA.sys.procedures AS P
        INNER JOIN T3QA.sys.schemas AS S ON S.schema_id = P.schema_id
        WHERE S.[name] = N'T3' AND P.[name] = N'PROC_T3_BOD'
    )
        THROW 51426, 'No existe T3QA.T3.PROC_T3_BOD.', 1;

    /* No basta con que los roles existan: también deben conservar los GRANT
       base que permiten recorrer toda la cadena de ejecución. */
    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.database_permissions AS P
        INNER JOIN sys.database_principals AS R
            ON R.principal_id = P.grantee_principal_id
        WHERE R.[name] = @MsdbRoleName
          AND P.class = 1
          AND P.major_id = OBJECT_ID(N'dbo.T3_JOB_NEXT_RUN', N'P')
          AND P.permission_name = N'EXECUTE'
          AND P.[state] IN ('G', 'W')
    )
        THROW 51433, 'T3JobExecutors no tiene EXECUTE sobre el wrapper. Ejecute nuevamente el script D.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM T3QA.sys.database_permissions AS P
        INNER JOIN T3QA.sys.database_principals AS R
            ON R.principal_id = P.grantee_principal_id
        INNER JOIN T3QA.sys.procedures AS PR
            ON PR.object_id = P.major_id
        INNER JOIN T3QA.sys.schemas AS S
            ON S.schema_id = PR.schema_id
        WHERE R.[name] = @T3RoleName
          AND S.[name] = N'T3'
          AND PR.[name] = N'PROC_T3_BOD'
          AND P.class = 1
          AND P.permission_name = N'EXECUTE'
          AND P.[state] IN ('G', 'W')
    )
        THROW 51434, 'T3BODExecutors no tiene EXECUTE sobre PROC_T3_BOD. Ejecute nuevamente el script D.', 1;

    /* Primero se conserva el texto en NVARCHAR(4000) para detectar nombres que
       excedan SYSNAME (128 caracteres) antes de convertirlos. */
    DECLARE @ParsedLogins TABLE
    (
        LoginName NVARCHAR(4000) NOT NULL
    );

    INSERT INTO @ParsedLogins (LoginName)
    SELECT DISTINCT LTRIM(RTRIM(S.[value]))
    FROM STRING_SPLIT(@LoginNames, N',') AS S
    WHERE LEN(LTRIM(RTRIM(S.[value]))) > 0;

    IF NOT EXISTS (SELECT 1 FROM @ParsedLogins)
        THROW 51427, 'La lista no contiene nombres de login validos.', 1;

    IF EXISTS (SELECT 1 FROM @ParsedLogins WHERE LEN(LoginName) > 128)
        THROW 51428, 'Un nombre excede el limite SYSNAME de 128 caracteres.', 1;

    DECLARE @TeamLogins TABLE
    (
        LoginName SYSNAME NOT NULL PRIMARY KEY
    );

    INSERT INTO @TeamLogins (LoginName)
    SELECT CONVERT(SYSNAME, LoginName)
    FROM @ParsedLogins;

    IF EXISTS (SELECT 1 FROM @TeamLogins WHERE LoginName = @TechnicalLogin)
        THROW 51429, 'T3_SQLAGENT_OWNER es una cuenta tecnica y no debe darse de alta como operador humano.', 1;

    /* Sólo se aceptan logins SQL, Windows o grupos Windows habilitados. */
    IF EXISTS
    (
        SELECT 1
        FROM @TeamLogins AS T
        LEFT JOIN master.sys.server_principals AS SP ON SP.[name] = T.LoginName
        WHERE SP.principal_id IS NULL
           OR SP.[type] NOT IN ('S', 'U', 'G')
           OR SP.is_disabled = 1
    )
    BEGIN
        SELECT
            T.LoginName,
            SP.[type_desc],
            SP.is_disabled,
            CASE
                WHEN SP.principal_id IS NULL THEN N'LOGIN_NOT_FOUND'
                WHEN SP.[type] NOT IN ('S', 'U', 'G') THEN N'UNSUPPORTED_PRINCIPAL_TYPE'
                WHEN SP.is_disabled = 1 THEN N'LOGIN_DISABLED'
            END AS Validation_Status
        FROM @TeamLogins AS T
        LEFT JOIN master.sys.server_principals AS SP ON SP.[name] = T.LoginName
        WHERE SP.principal_id IS NULL
           OR SP.[type] NOT IN ('S', 'U', 'G')
           OR SP.is_disabled = 1
        ORDER BY T.LoginName;

        THROW 51430, 'Uno o mas logins no existen, estan deshabilitados o no son de un tipo permitido.', 1;
    END;

    /* Impide usar por accidente un usuario homonimo asociado a otro SID. */
    IF EXISTS
    (
        SELECT 1
        FROM @TeamLogins AS T
        INNER JOIN sys.database_principals AS DP ON DP.[name] = T.LoginName
        WHERE DP.[sid] IS NULL OR DP.[sid] <> SUSER_SID(T.LoginName)
    )
        THROW 51431, 'Existe en msdb un usuario homonimo asociado a otro SID.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @TeamLogins AS T
        INNER JOIN T3QA.sys.database_principals AS DP ON DP.[name] = T.LoginName
        WHERE DP.[sid] IS NULL OR DP.[sid] <> SUSER_SID(T.LoginName)
    )
        THROW 51432, 'Existe en T3QA un usuario homonimo asociado a otro SID.', 1;

    DECLARE @LoginName SYSNAME, @MsdbUser SYSNAME, @T3User SYSNAME;
    DECLARE TeamCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT LoginName FROM @TeamLogins ORDER BY LoginName;

    BEGIN TRY
        BEGIN TRANSACTION;

        OPEN TeamCursor;
        FETCH NEXT FROM TeamCursor INTO @LoginName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @MsdbUser = NULL;
            SET @T3User = NULL;

            /* Reutiliza un usuario ya mapeado al mismo SID aunque tenga otro
               nombre; de lo contrario crea USER FOR LOGIN. */
            SELECT @MsdbUser = [name]
            FROM sys.database_principals
            WHERE [sid] = SUSER_SID(@LoginName);

            IF @MsdbUser IS NULL
            BEGIN
                SET @Sql = N'CREATE USER ' + QUOTENAME(@LoginName)
                         + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
                EXEC sys.sp_executesql @Sql;
                SET @MsdbUser = @LoginName;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM sys.database_role_members AS DRM
                INNER JOIN sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
                INNER JOIN sys.database_principals AS M ON M.principal_id = DRM.member_principal_id
                WHERE R.[name] = @MsdbRoleName AND M.[name] = @MsdbUser
            )
            BEGIN
                SET @Sql = N'ALTER ROLE ' + QUOTENAME(@MsdbRoleName)
                         + N' ADD MEMBER ' + QUOTENAME(@MsdbUser) + N';';
                EXEC sys.sp_executesql @Sql;
            END;

            SELECT @T3User = [name]
            FROM T3QA.sys.database_principals
            WHERE [sid] = SUSER_SID(@LoginName);

            IF @T3User IS NULL
            BEGIN
                SET @Sql = N'USE [T3QA]; CREATE USER ' + QUOTENAME(@LoginName)
                         + N' FOR LOGIN ' + QUOTENAME(@LoginName) + N';';
                EXEC sys.sp_executesql @Sql;
                SET @T3User = @LoginName;
            END;

            IF NOT EXISTS
            (
                SELECT 1
                FROM T3QA.sys.database_role_members AS DRM
                INNER JOIN T3QA.sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
                INNER JOIN T3QA.sys.database_principals AS M ON M.principal_id = DRM.member_principal_id
                WHERE R.[name] = @T3RoleName AND M.[name] = @T3User
            )
            BEGIN
                SET @Sql = N'USE [T3QA]; ALTER ROLE ' + QUOTENAME(@T3RoleName)
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
        IF CURSOR_STATUS('local', 'TeamCursor') >= 0 CLOSE TeamCursor;
        IF CURSOR_STATUS('local', 'TeamCursor') > -3 DEALLOCATE TeamCursor;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    /* Evidencia final: una fila por login solicitado y por base de datos. */
    SELECT
        T.LoginName AS Requested_Login,
        N'msdb' AS Database_Name,
        M.[name] AS Database_User,
        R.[name] AS Assigned_Role
    FROM @TeamLogins AS T
    INNER JOIN sys.database_principals AS M ON M.[sid] = SUSER_SID(T.LoginName)
    INNER JOIN sys.database_role_members AS DRM ON DRM.member_principal_id = M.principal_id
    INNER JOIN sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
    WHERE R.[name] = @MsdbRoleName

    UNION ALL

    SELECT
        T.LoginName,
        N'T3QA',
        M.[name],
        R.[name]
    FROM @TeamLogins AS T
    INNER JOIN T3QA.sys.database_principals AS M ON M.[sid] = SUSER_SID(T.LoginName)
    INNER JOIN T3QA.sys.database_role_members AS DRM ON DRM.member_principal_id = M.principal_id
    INNER JOIN T3QA.sys.database_principals AS R ON R.principal_id = DRM.role_principal_id
    WHERE R.[name] = @T3RoleName
    ORDER BY Requested_Login, Database_Name;
END;
GO

PRINT 'Procedimiento msdb.dbo.T3_ADD_JOB_EXECUTORS creado o actualizado.';
PRINT 'Ejemplo: EXEC msdb.dbo.T3_ADD_JOB_EXECUTORS @LoginNames = N''Usuario1, DOMINIO\Grupo1'';';
GO
