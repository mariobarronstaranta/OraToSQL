-- Solo lectura. No inicia el job, no procesa documentos ni concede permisos.
-- Ejecutar en AZCRNMXNEVTD06 / T3QA, con visibilidad del job en msdb.
USE [T3QA];
GO
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseActual,
 ORIGINAL_LOGIN() LoginConsulta,USER_NAME() UsuarioConsulta;

SELECT N'01_JOB' Seccion,J.name Job,J.enabled Habilitado,
 SUSER_SNAME(J.owner_sid) Propietario,
 IS_SRVROLEMEMBER(N'sysadmin',SUSER_SNAME(J.owner_sid)) PropietarioSysadmin,
 S.step_id Paso,S.subsystem TipoPaso,S.database_name BasePaso,
 S.database_user_name UsuarioPaso,S.proxy_id,S.command Comando
FROM msdb.dbo.sysjobs J JOIN msdb.dbo.sysjobsteps S ON S.job_id=J.job_id
WHERE J.name LIKE N'%REPLENISHMENT%'
 OR S.command LIKE N'%RECV_REPLENISHMENT%';

-- Propiedad efectiva de objetos: ayuda a identificar saltos de cadena de propiedad.
SELECT N'02_OBJETOS' Seccion,SC.name Esquema,O.name Objeto,
 USER_NAME(COALESCE(O.principal_id,SC.principal_id)) PropietarioEfectivo,
 M.execute_as_principal_id,
 CASE WHEN M.execute_as_principal_id IS NULL THEN N'CALLER'
      WHEN M.execute_as_principal_id=-2 THEN N'OWNER'
      ELSE USER_NAME(M.execute_as_principal_id) END ContextoModulo
FROM sys.objects O JOIN sys.schemas SC ON SC.schema_id=O.schema_id
LEFT JOIN sys.sql_modules M ON M.object_id=O.object_id
WHERE O.object_id IN(OBJECT_ID(N'EAI_OWNER.RECV_REPLENISHMENT'),
 OBJECT_ID(N'T3.RF_PROCESOS_LOG'),OBJECT_ID(N'EAI_OWNER.SF_PROC_REPLENISHMENT'));

SELECT N'03_PERMISOS_EXPLICITOS' Seccion,DP.name Principal,
 P.state_desc,P.permission_name,P.class_desc,
 CASE P.class WHEN 0 THEN DB_NAME() WHEN 3 THEN SCHEMA_NAME(P.major_id)
 WHEN 1 THEN OBJECT_SCHEMA_NAME(P.major_id)+N'.'+OBJECT_NAME(P.major_id) END Destino,
 CASE WHEN P.class=1 AND P.minor_id>0 THEN COL_NAME(P.major_id,P.minor_id) END Columna
FROM sys.database_permissions P
JOIN sys.database_principals DP ON DP.principal_id=P.grantee_principal_id
WHERE P.class=0
 OR (P.class=3 AND P.major_id IN(SCHEMA_ID(N'T3'),SCHEMA_ID(N'EAI_OWNER')))
 OR (P.class=1 AND P.major_id IN(OBJECT_ID(N'T3.RF_PROCESOS_LOG'),
 OBJECT_ID(N'EAI_OWNER.RECV_REPLENISHMENT')))
ORDER BY DP.name,P.class,P.major_id,P.minor_id,P.permission_name;

-- Identidades mapeadas y membresias; los permisos explicitos no incluyen
-- automaticamente todos los permisos efectivos de roles fijos.
SELECT N'04_USUARIOS' Seccion,P.name Usuario,P.type_desc,SUSER_SNAME(P.sid) LoginMapeado
FROM sys.database_principals P
WHERE P.name=N'T3_SQLAGENT_OWNER'
 OR P.sid IN(SELECT J.owner_sid FROM msdb.dbo.sysjobs J
 JOIN msdb.dbo.sysjobsteps S ON S.job_id=J.job_id
 WHERE J.name LIKE N'%REPLENISHMENT%' OR S.command LIKE N'%RECV_REPLENISHMENT%')
 OR P.name COLLATE DATABASE_DEFAULT IN
 (SELECT S.database_user_name COLLATE DATABASE_DEFAULT
  FROM msdb.dbo.sysjobs J JOIN msdb.dbo.sysjobsteps S ON S.job_id=J.job_id
  WHERE J.name LIKE N'%REPLENISHMENT%' OR S.command LIKE N'%RECV_REPLENISHMENT%');
SELECT N'05_ROLES' Seccion,M.name Miembro,R.name Rol
FROM sys.database_role_members RM
JOIN sys.database_principals M ON M.principal_id=RM.member_principal_id
JOIN sys.database_principals R ON R.principal_id=RM.role_principal_id
ORDER BY M.name,R.name;

SELECT TOP(10) N'06_ERRORES_RECIENTES' Seccion,CREATED,JOB_PID,
 SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE
FROM EAI_OWNER.MX_EAI_MESSAGE_LOG
WHERE QUEUE_NAME='RECV_REPLENISHMENT'
ORDER BY CREATED DESC;
