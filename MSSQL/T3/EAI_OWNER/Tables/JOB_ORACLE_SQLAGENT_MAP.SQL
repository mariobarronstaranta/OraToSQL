/*
    Tabla puente entre el identificador historico de DBMS_JOB y los objetos de
    SQL Server Agent. No sustituye ninguna tabla de msdb: solamente conserva el
    mapeo que necesitan los wrappers EAI_OWNER.JOB_*.
*/
IF OBJECT_ID(N'[EAI_OWNER].[Job_Oracle_SQLAgent_Map]', N'U') IS NULL
BEGIN
    CREATE TABLE [EAI_OWNER].[Job_Oracle_SQLAgent_Map]
    (
        Oracle_Job_No       INT              NOT NULL PRIMARY KEY,
        SqlAgent_Job_Id     UNIQUEIDENTIFIER NOT NULL,
        SqlAgent_Job_Name   SYSNAME          NULL,
        Schedule_Id         INT              NOT NULL,
        Original_Interval   VARCHAR(4000)    NULL,
        Last_Interval       VARCHAR(4000)    NULL,
        Last_Update_Date    DATETIME2(0)     NULL,
        Last_Update_User    SYSNAME          NULL,
        Is_Active           BIT              NOT NULL DEFAULT (1)
    );
END;
GO

/*
    Compatibilidad con instalaciones previas:
    si la tabla fue desplegada originalmente bajo dbo, se copian solamente los
    mapeos que todavía no existan en EAI_OWNER. La tabla anterior no se elimina,
    para que el DBA pueda validar la migracion antes de retirarla.
*/
IF OBJECT_ID(N'[dbo].[Job_Oracle_SQLAgent_Map]', N'U') IS NOT NULL
BEGIN
    INSERT INTO [EAI_OWNER].[Job_Oracle_SQLAgent_Map]
    (
        Oracle_Job_No,
        SqlAgent_Job_Id,
        SqlAgent_Job_Name,
        Schedule_Id,
        Original_Interval,
        Last_Interval,
        Last_Update_Date,
        Last_Update_User,
        Is_Active
    )
    SELECT
        Legacy.Oracle_Job_No,
        Legacy.SqlAgent_Job_Id,
        Legacy.SqlAgent_Job_Name,
        Legacy.Schedule_Id,
        Legacy.Original_Interval,
        Legacy.Last_Interval,
        Legacy.Last_Update_Date,
        Legacy.Last_Update_User,
        Legacy.Is_Active
    FROM [dbo].[Job_Oracle_SQLAgent_Map] AS Legacy
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [EAI_OWNER].[Job_Oracle_SQLAgent_Map] AS CurrentMap
        WHERE CurrentMap.Oracle_Job_No = Legacy.Oracle_Job_No
    );
END;
GO
