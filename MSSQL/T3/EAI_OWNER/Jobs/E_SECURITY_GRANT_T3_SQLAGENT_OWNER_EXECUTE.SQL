/*
    Concede al propietario tecnico los permisos minimos requeridos por los
    steps T-SQL de los 37 jobs y por EAI_OWNER.JOB_NEXT_RUN.

    Prerrequisitos:
    - A_SECURITY_CREATE_T3_SQLAGENT_OWNER.SQL
    - 01_CREATE_OR_UPDATE_JOBS.SQL

    Debe ejecutarlo un miembro de sysadmin o db_owner en T3QA.
*/

USE [T3QA];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RoleName SYSNAME = N'T3SqlAgentJobExecutor';
DECLARE @TechnicalUser SYSNAME = N'T3_SQLAGENT_OWNER';
DECLARE @SecuritySql NVARCHAR(MAX);

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
   AND IS_ROLEMEMBER(N'db_owner') <> 1
BEGIN
    THROW 51500, 'Este script debe ser ejecutado por sysadmin o db_owner de T3QA.', 1;
END;

IF USER_ID(@TechnicalUser) IS NULL
BEGIN
    THROW 51501, 'No existe el usuario T3_SQLAGENT_OWNER en T3QA.', 1;
END;

IF OBJECT_ID(N'T3.RF_PROCESOS_LOG', N'U') IS NULL
BEGIN
    THROW 51506, 'Falta T3.RF_PROCESOS_LOG; no se concedieron permisos.', 1;
END;

IF OBJECT_ID(N'T3.FN_EVAL_REMISION_OBD', N'FN') IS NULL
BEGIN
    THROW 51507, 'Falta T3.FN_EVAL_REMISION_OBD; no se concedieron permisos.', 1;
END;

IF OBJECT_ID(N'T3.PROC_T3_OT_GENERAL', N'P') IS NULL
BEGIN
    THROW 51509, 'Falta T3.PROC_T3_OT_GENERAL; no se concedieron permisos.', 1;
END;

IF OBJECT_ID(N'EAI_OWNER.MX_HASHTABLE', N'U') IS NULL
   OR OBJECT_ID(N'T3.MATERIAL', N'U') IS NULL
BEGIN
    THROW 51508, 'Falta EAI_OWNER.MX_HASHTABLE o T3.MATERIAL; no se concedieron permisos.', 1;
END;

IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NULL
   OR OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
BEGIN
    THROW 51502, 'Faltan las tablas de control. Ejecute primero 01_CREATE_OR_UPDATE_JOBS.SQL.', 1;
END;

IF (SELECT COUNT(*) FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog]) <> 37
BEGIN
    THROW 51503, 'El catalogo de migracion no contiene exactamente 37 jobs.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS C
    WHERE OBJECT_ID
          (
              QUOTENAME(C.Required_Schema) + N'.' + QUOTENAME(C.Required_Procedure),
              N'P'
          ) IS NULL
)
BEGIN
    DECLARE @MissingProcedures NVARCHAR(1800) = N'';

    SELECT @MissingProcedures =
        @MissingProcedures
        + CASE WHEN @MissingProcedures = N'' THEN N'' ELSE N', ' END
        + QUOTENAME(C.Required_Schema) + N'.' + QUOTENAME(C.Required_Procedure)
    FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS C
    WHERE OBJECT_ID
          (
              QUOTENAME(C.Required_Schema) + N'.' + QUOTENAME(C.Required_Procedure),
              N'P'
          ) IS NULL
    ORDER BY C.Oracle_Job_No;

    SELECT
        C.Oracle_Job_No,
        QUOTENAME(C.Required_Schema) + N'.' + QUOTENAME(C.Required_Procedure) AS Missing_Procedure
    FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS C
    WHERE OBJECT_ID
          (
              QUOTENAME(C.Required_Schema) + N'.' + QUOTENAME(C.Required_Procedure),
              N'P'
          ) IS NULL
    ORDER BY C.Oracle_Job_No;

    DECLARE @MissingMessage NVARCHAR(2048) =
        N'Faltan procedimientos requeridos por los jobs; no se concedieron permisos: '
        + @MissingProcedures;

    THROW 51504, @MissingMessage, 1;
END;

IF DATABASE_PRINCIPAL_ID(@RoleName) IS NULL
BEGIN
    SET @SecuritySql = N'CREATE ROLE ' + QUOTENAME(@RoleName) + N' AUTHORIZATION [dbo];';
    EXEC sys.sp_executesql @SecuritySql;
END
ELSE IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_principals
    WHERE principal_id = DATABASE_PRINCIPAL_ID(@RoleName)
      AND [type] = 'R'
)
BEGIN
    THROW 51505, 'Ya existe T3SqlAgentJobExecutor, pero no es un rol de base de datos.', 1;
END;

DECLARE
    @RequiredSchema SYSNAME,
    @RequiredProcedure SYSNAME,
    @GrantSql NVARCHAR(MAX);

DECLARE GrantCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT DISTINCT Required_Schema, Required_Procedure
FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog]
ORDER BY Required_Schema, Required_Procedure;

BEGIN TRY
    BEGIN TRANSACTION;

        OPEN GrantCursor;
        FETCH NEXT FROM GrantCursor INTO @RequiredSchema, @RequiredProcedure;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @GrantSql =
                N'GRANT EXECUTE ON OBJECT::'
                + QUOTENAME(@RequiredSchema) + N'.' + QUOTENAME(@RequiredProcedure)
                + N' TO ' + QUOTENAME(@RoleName) + N';';

            EXEC sys.sp_executesql @GrantSql;

            FETCH NEXT FROM GrantCursor INTO @RequiredSchema, @RequiredProcedure;
        END;

        CLOSE GrantCursor;
        DEALLOCATE GrantCursor;

        GRANT SELECT, UPDATE
            ON OBJECT::[EAI_OWNER].[Job_Oracle_SQLAgent_Map]
            TO [T3SqlAgentJobExecutor];

        GRANT SELECT
            ON OBJECT::[EAI_OWNER].[Job_Oracle_Migration_Catalog]
            TO [T3SqlAgentJobExecutor];

        -- El coordinador inserta el inicio y actualiza el cierre por PID.
        -- Propietarios distintos entre EAI_OWNER y T3 requieren estos permisos.
        GRANT SELECT, INSERT, UPDATE
            ON OBJECT::[T3].[RF_PROCESOS_LOG]
            TO [T3SqlAgentJobExecutor];

        GRANT EXECUTE
            ON OBJECT::[T3].[FN_EVAL_REMISION_OBD]
            TO [T3SqlAgentJobExecutor];

        -- El coordinador intercompany y el paso T3 tienen propietarios distintos.
        -- EXECUTE permite la llamada y la visibilidad usada por OBJECT_ID (50021).
        GRANT EXECUTE
            ON OBJECT::[T3].[PROC_T3_OT_GENERAL]
            TO [T3SqlAgentJobExecutor];

        GRANT SELECT ON OBJECT::[EAI_OWNER].[MX_HASHTABLE]
            TO [T3SqlAgentJobExecutor];

        GRANT SELECT ON OBJECT::[T3].[MATERIAL]
            TO [T3SqlAgentJobExecutor];

-- BEGIN REPLENISHMENT PERMISSIONS
DECLARE @RRPermisos table(Objeto nvarchar(256),Permisos varchar(100));
INSERT @RRPermisos VALUES
 (N'T3.RF_PROCESOS_LOG','SELECT,INSERT,UPDATE'),
 (N'T3.MATERIAL','SELECT'),
 (N'T3.CFDI_PRODSERV','SELECT'),
 (N'T3.PREVENTA_GENERAL','SELECT'),
 (N'T3.ENTREGA','SELECT,INSERT,DELETE'),
 (N'T3.RF_COMPLEMENTO','SELECT,INSERT,DELETE'),
 (N'T3.REMISION_GENERAL','SELECT,INSERT,DELETE'),
 (N'T3.REMISION_DETALLE','SELECT,INSERT,UPDATE,DELETE'),
 (N'T3.MOV_CLIENTE','SELECT'),
 (N'T3.CLIENTE','SELECT'),
 (N'T3.DISTRIBUIDOR_FISCAL','SELECT'),
 (N'T3.REMISION_CTRO_SOCIEDAD','SELECT'),
 (N'T3.FN_EVAL_REMISION_OBD','EXECUTE'),
 (N'T3.DELIVERY_TO_SUBDEPOT','EXECUTE'),
 (N'T3.DELIVERY_IDOC_TO_REMISION','EXECUTE'),
 (N'T3.GET_REMISION_INFO','EXECUTE'),
 (N'EAI.ZSDFE_SOC','SELECT'),
 (N'EAI.IFC_FOLIOS_FE','SELECT,INSERT,UPDATE'),
 (N'EAI_OWNER.MX_HASHTABLE','SELECT'),
 (N'EAI_OWNER.TAO_CEDIS_VALID','SELECT'),
 (N'EAI_OWNER.MX_PRINT_DELIVERY','SELECT'),
 (N'EAI_OWNER.TMP_DOCUMENT_HEADER','SELECT'),
 (N'EAI_OWNER.TMP_DOCUMENT_DETAIL','SELECT'),
 (N'EAI_OWNER.MX_EAI_MESSAGE_LOG','INSERT'),
 (N'EAI_OWNER.GETCONV','EXECUTE'),
 (N'EAI_OWNER.WA_FOLIO_FACTURA','EXECUTE');
-- Otros accesos internos del esquema EAI_OWNER conservan su cadena de propiedad.
-- Se explicitan aqui los accesos que cruzan a T3/EAI y de regreso desde T3.
IF EXISTS(SELECT 1 FROM @RRPermisos WHERE OBJECT_ID(Objeto) IS NULL)
BEGIN
 SELECT Objeto AS ObjetoFaltante FROM @RRPermisos WHERE OBJECT_ID(Objeto) IS NULL;
 THROW 51978,'Faltan objetos del flujo o no son visibles. No se concedieron estos permisos.',1;
END;
DECLARE @RRSql nvarchar(max)=N'';
SELECT @RRSql=@RRSql+N'GRANT '+Permisos+N' ON OBJECT::'
 +QUOTENAME(PARSENAME(Objeto,2))+N'.'+QUOTENAME(PARSENAME(Objeto,1))
 +N' TO [T3SqlAgentJobExecutor];'+NCHAR(10)
FROM @RRPermisos;
-- END REPLENISHMENT PERMISSIONS
EXEC sys.sp_executesql @RRSql;

        -- Ruta intercompany -> INVOICE_TO_PREVENTA. Accesos directos entre
        -- propietarios distintos; la reconstruccion DELETE/INSERT existe en Oracle.
        -- El error 229 en PREVENTA_GENERAL fue confirmado en el PID 26516078.
        GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::[T3].[PREVENTA_GENERAL]
            TO [T3SqlAgentJobExecutor];
        GRANT SELECT, INSERT, DELETE ON OBJECT::[T3].[PREVENTA_DETALLE]
            TO [T3SqlAgentJobExecutor];
        GRANT SELECT, INSERT, DELETE ON OBJECT::[T3].[PREVENTA_CONDICIONES]
            TO [T3SqlAgentJobExecutor];
        GRANT EXECUTE ON OBJECT::[T3].[DELIVERY_WA_OXXO]
            TO [T3SqlAgentJobExecutor];

        -- La otra ruta intercompany convierte OTROS y enriquece SAT/retenciones.
        -- Diez documentos del PID 26516078 registraron SELECT denegado en general.
        GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::[T3].[OTROS_GENERAL]
            TO [T3SqlAgentJobExecutor];
        GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::[T3].[OTROS_DETALLE]
            TO [T3SqlAgentJobExecutor];
        GRANT SELECT, INSERT, DELETE ON OBJECT::[T3].[OTROS_CONDICIONES]
            TO [T3SqlAgentJobExecutor];
        GRANT SELECT ON OBJECT::[T3].[CFDI_PRODSERV_WA]
            TO [T3SqlAgentJobExecutor];

        -- El generador T3.PROC_V40_GENERAR_OTROS lee partners del esquema EAI_OWNER.
        -- El acceso de regreso desde T3 requiere SELECT: error 229 de las 17:25.
        GRANT SELECT ON OBJECT::[EAI_OWNER].[TMP_DOCUMENT_PARTNERS]
            TO [T3SqlAgentJobExecutor];

        GRANT VIEW DEFINITION
            ON OBJECT::[EAI_OWNER].[JOB_NEXT_RUN]
            TO [T3SqlAgentJobExecutor];

        GRANT VIEW DEFINITION
            ON OBJECT::[T3].[PROC_T3_BOD]
            TO [T3SqlAgentJobExecutor];

        GRANT VIEW DEFINITION
            ON OBJECT::[T3].[PROC_T3_EOD]
            TO [T3SqlAgentJobExecutor];

        IF ISNULL(IS_ROLEMEMBER(@RoleName, @TechnicalUser), 0) <> 1
        BEGIN
            SET @SecuritySql =
                N'ALTER ROLE ' + QUOTENAME(@RoleName)
                + N' ADD MEMBER ' + QUOTENAME(@TechnicalUser) + N';';
            EXEC sys.sp_executesql @SecuritySql;
        END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'GrantCursor') >= 0
        CLOSE GrantCursor;

    IF CURSOR_STATUS('local', 'GrantCursor') > -3
        DEALLOCATE GrantCursor;

    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

SELECT
    R.[name] AS RoleName,
    M.[name] AS MemberName
FROM sys.database_role_members AS DRM
INNER JOIN sys.database_principals AS R
    ON R.principal_id = DRM.role_principal_id
INNER JOIN sys.database_principals AS M
    ON M.principal_id = DRM.member_principal_id
WHERE R.[name] = @RoleName;
GO
