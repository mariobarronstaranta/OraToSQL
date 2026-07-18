/*
    Homologo SQL Server de EAI_OWNER.SEQ_PURGE_LEGDB (Oracle).

    Oracle : MINVALUE 1, MAXVALUE 9999999999, INCREMENT BY 1,
             START WITH 447333, CACHE 20, CYCLE.
    Tipo   : BIGINT porque el MAXVALUE excede el limite de INT.

    NOORDER, NOKEEP, NOSCALE y GLOBAL son propiedades Oracle sin traduccion
    directa en la sintaxis CREATE SEQUENCE de SQL Server.
*/
SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'EAI_OWNER') IS NULL
    THROW 50040, 'No existe el esquema EAI_OWNER.', 1;
GO

IF OBJECT_ID(N'[EAI_OWNER].[Seq_Purge_LEGDB]', N'SO') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE SEQUENCE [EAI_OWNER].[Seq_Purge_LEGDB]
            AS BIGINT
            START WITH 447333
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 9999999999
            CYCLE
            CACHE 20;';
END;
GO

-- UPDATE sustituye funcionalmente el GRANT SELECT usado para NEXTVAL en Oracle.
IF DATABASE_PRINCIPAL_ID(N'LEGV3_SUPPORT') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[Seq_Purge_LEGDB] TO [LEGV3_SUPPORT];

IF DATABASE_PRINCIPAL_ID(N'ITX_DEV') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[Seq_Purge_LEGDB] TO [ITX_DEV];
GO
