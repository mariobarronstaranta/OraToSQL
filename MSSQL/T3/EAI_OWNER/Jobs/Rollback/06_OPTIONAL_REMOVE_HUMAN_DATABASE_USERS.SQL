/*
    PASO 6 OPCIONAL DEL ROLLBACK TOTAL
    ==================================
    Intenta eliminar de T3QA y msdb los usuarios de base de datos creados para
    los cuatro ejecutores. NO elimina sus logins de servidor/Active Directory.

    Normalmente este paso se omite: un usuario pudo existir antes o ser usado
    por otro proceso. Solo se elimina si no tiene roles, permisos explicitos
    ni esquemas bajo su propiedad.
*/
USE [master];
GO
SET NOCOUNT ON;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 51660, 'Este paso debe ser ejecutado por un miembro de sysadmin.', 1;

DECLARE @ConfirmDropHumanUsers BIT = 0;
IF @ConfirmDropHumanUsers <> 1
    THROW 51661, 'Paso opcional. Cambie @ConfirmDropHumanUsers a 1 solo si estos usuarios fueron creados por el proceso.', 1;

DECLARE @Users TABLE (UserName SYSNAME PRIMARY KEY);
INSERT @Users VALUES (N'IX85234150'), (N'AT85233588'), (N'AT85233589'), (N'T3');

DECLARE @DatabaseName SYSNAME, @UserName SYSNAME, @Sql NVARCHAR(MAX);
DECLARE DatabaseCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DatabaseName FROM (VALUES (N'T3QA'), (N'msdb')) AS D(DatabaseName);

OPEN DatabaseCursor;
FETCH NEXT FROM DatabaseCursor INTO @DatabaseName;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE UserCursor CURSOR LOCAL FAST_FORWARD FOR SELECT UserName FROM @Users;
    OPEN UserCursor;
    FETCH NEXT FROM UserCursor INTO @UserName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* La validacion ocurre dentro de cada base. Si hay una dependencia,
           se informa el motivo y el usuario se conserva. */
        SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';
DECLARE @PrincipalId INT = DATABASE_PRINCIPAL_ID(@Name);
IF @PrincipalId IS NULL
    PRINT N''No existe ' + @DatabaseName + N'.'' + @Name + N''; se omite.'';
ELSE IF EXISTS (SELECT 1 FROM sys.database_role_members WHERE member_principal_id=@PrincipalId)
    PRINT N''Se conserva ' + @DatabaseName + N'.'' + @Name + N'': aun pertenece a un rol.'';
ELSE IF EXISTS (SELECT 1 FROM sys.database_permissions WHERE grantee_principal_id=@PrincipalId)
    PRINT N''Se conserva ' + @DatabaseName + N'.'' + @Name + N'': tiene permisos explicitos.'';
ELSE IF EXISTS (SELECT 1 FROM sys.schemas WHERE principal_id=@PrincipalId)
    PRINT N''Se conserva ' + @DatabaseName + N'.'' + @Name + N'': es propietario de un esquema.'';
ELSE
BEGIN
    EXEC (N''DROP USER '' + QUOTENAME(@Name) + N'';'');
    PRINT N''Usuario eliminado: ' + @DatabaseName + N'.'' + @Name;
END;';
        EXEC sys.sp_executesql @Sql, N'@Name SYSNAME', @Name=@UserName;
        FETCH NEXT FROM UserCursor INTO @UserName;
    END;
    CLOSE UserCursor;
    DEALLOCATE UserCursor;
    FETCH NEXT FROM DatabaseCursor INTO @DatabaseName;
END;
CLOSE DatabaseCursor;
DEALLOCATE DatabaseCursor;

PRINT 'Paso 6 completado. Revise los mensajes para conocer los usuarios conservados.';
GO
