/*
    Agrega un identificador numerico a [EAI_OWNER].[MX_EAI_MESSAGE_LOG].

    - La secuencia genera el valor de [ROW_ID].
    - El DEFAULT llena automaticamente la columna en nuevos INSERT.
    - Los registros existentes reciben un valor durante la migracion.
    - El indice unico conserva la semantica de identificador del ROWID Oracle.

    Nota: una secuencia garantiza unicidad, pero no valores consecutivos sin
    huecos. Un rollback o el uso de CACHE puede consumir numeros.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]', N'U') IS NULL
BEGIN
    THROW 50001, 'No existe la tabla [EAI_OWNER].[MX_EAI_MESSAGE_LOG].', 1;
END;
GO

IF OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]', N'SO') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE SEQUENCE [EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]
            AS BIGINT
            START WITH 1
            INCREMENT BY 1
            MINVALUE 1
            NO MAXVALUE
            NO CYCLE
            CACHE 100;';
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]', N'ROW_ID') IS NULL
    BEGIN
        /*
            SQL dinamico evita que SQL Server intente resolver ROW_ID al
            compilar este lote, antes de que la columna haya sido creada.
        */
        EXEC sys.sp_executesql N'
            ALTER TABLE [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                ADD [ROW_ID] BIGINT NULL;';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints AS dc
        INNER JOIN sys.columns AS c
            ON c.object_id = dc.parent_object_id
           AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]')
          AND c.name = N'ROW_ID'
    )
    BEGIN
        EXEC sys.sp_executesql N'
            ALTER TABLE [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                ADD CONSTRAINT [DF_MX_EAI_MESSAGE_LOG_ROW_ID]
                DEFAULT (NEXT VALUE FOR [EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ])
                FOR [ROW_ID];';
    END;

    EXEC sys.sp_executesql N'
        UPDATE [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
           SET [ROW_ID] = NEXT VALUE FOR [EAI_OWNER].[MX_EAI_MESSAGE_LOG_ROW_ID_SEQ]
         WHERE [ROW_ID] IS NULL;';

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]')
          AND name = N'ROW_ID'
          AND is_nullable = 1
    )
    BEGIN
        EXEC sys.sp_executesql N'
            ALTER TABLE [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
                ALTER COLUMN [ROW_ID] BIGINT NOT NULL;';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]')
          AND name = N'UX_MX_EAI_MESSAGE_LOG_ROW_ID'
    )
    BEGIN
        EXEC sys.sp_executesql N'
            CREATE UNIQUE INDEX [UX_MX_EAI_MESSAGE_LOG_ROW_ID]
                ON [EAI_OWNER].[MX_EAI_MESSAGE_LOG] ([ROW_ID]);';
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
