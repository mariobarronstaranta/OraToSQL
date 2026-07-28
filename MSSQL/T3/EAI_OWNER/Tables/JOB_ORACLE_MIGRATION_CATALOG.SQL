/*
    Catalogo auditable de la conversion de DBMS_JOB a SQL Server Agent.
    Es una tabla de la aplicacion y por ello reside en EAI_OWNER; las tablas
    operativas propias del agente permanecen correctamente en msdb.dbo.
*/
IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_Migration_Catalog]', N'U') IS NULL
BEGIN
    CREATE TABLE [EAI_OWNER].[Job_Oracle_Migration_Catalog]
    (
        Oracle_Job_No            INT           NOT NULL PRIMARY KEY,
        Required_Schema          SYSNAME       NOT NULL,
        Required_Procedure       SYSNAME       NOT NULL,
        Step_Command             NVARCHAR(MAX) NOT NULL,
        Oracle_Broken            BIT           NOT NULL,
        Original_Interval        VARCHAR(4000) NOT NULL,
        Converted_Subday_Type     INT          NOT NULL,
        Converted_Subday_Interval INT          NOT NULL,
        Converted_Start_Time      INT          NOT NULL,
        Migration_Date           DATETIME2(0)  NOT NULL,
        Migration_User           SYSNAME       NOT NULL
    );
END;
GO

/*
    Copia no destructiva desde la ubicacion historica bajo dbo. No se sobrescribe
    informacion que ya haya sido validada en el catalogo de EAI_OWNER.
*/
IF OBJECT_ID(N'[dbo].[Job_Oracle_Migration_Catalog]', N'U') IS NOT NULL
BEGIN
    INSERT INTO [EAI_OWNER].[Job_Oracle_Migration_Catalog]
    (
        Oracle_Job_No,
        Required_Schema,
        Required_Procedure,
        Step_Command,
        Oracle_Broken,
        Original_Interval,
        Converted_Subday_Type,
        Converted_Subday_Interval,
        Converted_Start_Time,
        Migration_Date,
        Migration_User
    )
    SELECT
        Legacy.Oracle_Job_No,
        Legacy.Required_Schema,
        Legacy.Required_Procedure,
        Legacy.Step_Command,
        Legacy.Oracle_Broken,
        Legacy.Original_Interval,
        Legacy.Converted_Subday_Type,
        Legacy.Converted_Subday_Interval,
        Legacy.Converted_Start_Time,
        Legacy.Migration_Date,
        Legacy.Migration_User
    FROM [dbo].[Job_Oracle_Migration_Catalog] AS Legacy
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [EAI_OWNER].[Job_Oracle_Migration_Catalog] AS CurrentCatalog
        WHERE CurrentCatalog.Oracle_Job_No = Legacy.Oracle_Job_No
    );
END;
GO
