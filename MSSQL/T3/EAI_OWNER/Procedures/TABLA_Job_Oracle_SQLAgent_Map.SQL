IF OBJECT_ID('dbo.Job_Oracle_SQLAgent_Map', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Job_Oracle_SQLAgent_Map
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