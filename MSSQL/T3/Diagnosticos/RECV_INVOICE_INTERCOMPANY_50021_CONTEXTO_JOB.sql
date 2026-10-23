/*
  Segunda revision de MSSQL-50021. Ejecutar como sysadmin en T3QA.
  Solo consulta metadatos y permisos; no concede permisos ni ejecuta el job.
  La suplantacion de la cuenta tecnica se limita a esta sesion y se revierte.
  La cuenta T3_SQLAGENT_OWNER es la prevista por los scripts del proyecto:
  si el propietario/usuario del paso es otro, no tomar su prueba como concluyente.
*/
USE [T3QA];
GO
SET NOCOUNT ON;

SELECT '01_AMBIENTE' AS Seccion, @@SERVERNAME AS Servidor,
       DB_NAME() AS BaseActual, SYSDATETIMEOFFSET() AS FechaCaptura,
       ORIGINAL_LOGIN() AS LoginOriginal, SUSER_SNAME() AS LoginActual;

-- Comparar propietario, base, comando y usuario especifico del paso.
SELECT '02_JOB_Y_PASO' AS Seccion, J.name AS Job,
       SUSER_SNAME(J.owner_sid) AS PropietarioJob,
       IS_SRVROLEMEMBER(N'sysadmin', SUSER_SNAME(J.owner_sid)) AS PropietarioEsSysadmin,
       J.enabled AS JobHabilitado, JS.step_id, JS.subsystem,
       JS.database_name AS BaseDelPaso, JS.database_user_name AS UsuarioDelPaso,
       JS.command AS Comando
FROM msdb.dbo.sysjobs AS J
INNER JOIN msdb.dbo.sysjobsteps AS JS ON JS.job_id = J.job_id
WHERE J.name LIKE N'%RECV_INVOICE_INTERCOMPANY%'
   OR JS.command LIKE N'%RECV_INVOICE_INTERCOMPANY%'
ORDER BY J.name, JS.step_id;

-- Un propietario efectivo distinto puede romper la cadena de propiedad.
SELECT '03_PROPIETARIOS_OBJETOS' AS Seccion,
       S.name AS Esquema, O.name AS Objeto,
       USER_NAME(COALESCE(O.principal_id, S.principal_id)) AS PropietarioEfectivo
FROM sys.objects AS O
INNER JOIN sys.schemas AS S ON S.schema_id = O.schema_id
WHERE O.object_id IN (OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_INTERCOMPANY'),
                     OBJECT_ID(N'T3.PROC_T3_OT_GENERAL'),
                     OBJECT_ID(N'T3.WA_ERR_INVOICE_PAYMETHOD'),
                     OBJECT_ID(N'T3.PROC_V40_GENERAR_OTROS'));

-- Banderas compactas: el resultado anterior recorto la definicion a 256 caracteres.
SELECT '04_VALIDACION_INSTALADA' AS Seccion,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'OBJECT_ID', M.definition) > 0 THEN 1 ELSE 0 END AS ContieneObjectId,
       CASE WHEN M.definition IS NULL THEN NULL
            WHEN CHARINDEX(N'50021', M.definition) > 0 THEN 1 ELSE 0 END AS Contiene50021,
       M.execute_as_principal_id
FROM sys.sql_modules AS M
WHERE M.object_id = OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_INTERCOMPANY', N'P');

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 51980, 'Esta prueba debe ejecutarla un sysadmin para suplantar el login tecnico.', 1;

IF SUSER_ID(N'T3_SQLAGENT_OWNER') IS NULL
BEGIN
    SELECT '05_CUENTA_TECNICA' AS Seccion,
           N'No existe el login previsto T3_SQLAGENT_OWNER; revisar el propietario real mostrado en 02.' AS Observacion;
END
ELSE
BEGIN
    DECLARE @Cookie VARBINARY(8000), @Suplantado BIT = 0;
    BEGIN TRY
        EXECUTE AS LOGIN = 'T3_SQLAGENT_OWNER' WITH COOKIE INTO @Cookie;
        SET @Suplantado = 1;

        SELECT '05_CONTEXTO_TECNICO' AS Seccion, DB_NAME() AS BaseActual,
               SUSER_SNAME() AS LoginActual, USER_NAME() AS UsuarioBase,
               IS_MEMBER(N'T3SqlAgentJobExecutor') AS MiembroRolJobs;

        SELECT '06_PERMISOS_EFECTIVOS' AS Seccion, V.Objeto,
               OBJECT_ID(V.Objeto, N'P') AS ObjectIdVisible,
               HAS_PERMS_BY_NAME(V.Objeto, N'OBJECT', N'EXECUTE') AS PuedeEjecutar,
               HAS_PERMS_BY_NAME(V.Objeto, N'OBJECT', N'VIEW DEFINITION') AS PuedeVerDefinicion
        FROM (VALUES (N'EAI_OWNER.RECV_INVOICE_INTERCOMPANY'),
                     (N'T3.PROC_T3_OT_GENERAL'),
                     (N'T3.WA_ERR_INVOICE_PAYMETHOD'),
                     (N'T3.PROC_V40_GENERAR_OTROS')) AS V(Objeto);

        REVERT WITH COOKIE = @Cookie;
        SET @Suplantado = 0;
    END TRY
    BEGIN CATCH
        IF @Suplantado = 1
            REVERT WITH COOKIE = @Cookie;
        THROW;
    END CATCH;
END;

SELECT '07_CONTEXTO_RESTAURADO' AS Seccion, SUSER_SNAME() AS LoginActual,
       N'No se ejecutaron procedimientos de negocio ni se modificaron permisos.' AS Observacion;
