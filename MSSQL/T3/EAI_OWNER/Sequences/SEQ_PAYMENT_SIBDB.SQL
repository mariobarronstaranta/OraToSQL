/*
    Homologo SQL Server de EAI_OWNER.SEQ_PAYMENT_SIBDB (Oracle).

    Oracle : MINVALUE 1, MAXVALUE 9999999999, INCREMENT BY 1,
             START WITH 16922, NOCACHE, ORDER, NOCYCLE.
    Tipo   : BIGINT porque el MAXVALUE excede el limite de INT.

    SQL Server no ofrece la opcion ORDER para secuencias. NO CACHE conserva la
    intencion Oracle de no reservar bloques de valores en memoria.
*/
SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'EAI_OWNER') IS NULL
    THROW 50040, 'No existe el esquema EAI_OWNER.', 1;
GO

IF OBJECT_ID(N'[EAI_OWNER].[SEQ_PAYMENT_SIBDB]', N'SO') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE SEQUENCE [EAI_OWNER].[SEQ_PAYMENT_SIBDB]
            AS BIGINT
            START WITH 16922
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 9999999999
            NO CYCLE
            NO CACHE;';
END;
GO

-- UPDATE es el permiso requerido por NEXT VALUE FOR en SQL Server.
IF DATABASE_PRINCIPAL_ID(N'LEGV3_SUPPORT') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[SEQ_PAYMENT_SIBDB] TO [LEGV3_SUPPORT];

IF DATABASE_PRINCIPAL_ID(N'ITX_DEV') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[SEQ_PAYMENT_SIBDB] TO [ITX_DEV];
GO
