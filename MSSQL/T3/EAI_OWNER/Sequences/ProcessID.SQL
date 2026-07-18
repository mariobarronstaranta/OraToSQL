/*
    Homologo SQL Server de EAI_OWNER.PROCESSID (Oracle).

    Oracle : MINVALUE 1, MAXVALUE 9999999999, INCREMENT BY 1,
             START WITH 26512123, CACHE 20, CYCLE.
    Tipo   : BIGINT porque el MAXVALUE excede el limite de INT.

    NOORDER, NOKEEP, NOSCALE y GLOBAL no tienen una opcion equivalente directa
    en CREATE SEQUENCE de SQL Server y se omiten.

    El script es idempotente: si la secuencia existe, no cambia su valor actual
    ni reinicia numeracion. Antes de un primer despliegue sobre datos migrados,
    confirme que START WITH sea mayor que cualquier PID ya existente.
*/
SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'EAI_OWNER') IS NULL
    THROW 50040, 'No existe el esquema EAI_OWNER.', 1;
GO

IF OBJECT_ID(N'[EAI_OWNER].[ProcessID]', N'SO') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE SEQUENCE [EAI_OWNER].[ProcessID]
            AS BIGINT
            START WITH 26512123
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 9999999999
            CYCLE
            CACHE 20;';
END;
GO

/*
    Oracle usa GRANT SELECT para permitir NEXTVAL. En SQL Server, NEXT VALUE FOR
    requiere UPDATE sobre la secuencia (o un permiso superior en el esquema).
*/
IF DATABASE_PRINCIPAL_ID(N'LEGV3_SUPPORT') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[ProcessID] TO [LEGV3_SUPPORT];

IF DATABASE_PRINCIPAL_ID(N'EAI') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[ProcessID] TO [EAI];

IF DATABASE_PRINCIPAL_ID(N'T3') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[ProcessID] TO [T3];

IF DATABASE_PRINCIPAL_ID(N'CC_DOCTOS_OWNER') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[ProcessID] TO [CC_DOCTOS_OWNER];

IF DATABASE_PRINCIPAL_ID(N'ITX_DEV') IS NOT NULL
    GRANT UPDATE ON OBJECT::[EAI_OWNER].[ProcessID] TO [ITX_DEV];
GO
