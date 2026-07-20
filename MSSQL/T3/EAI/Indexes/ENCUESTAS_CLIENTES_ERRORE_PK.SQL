IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_ERRORES]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[ENCUESTAS_CLIENTES_ERRORES]
        ADD CONSTRAINT [ENCUESTAS_CLIENTES_ERRORE_PK] PRIMARY KEY CLUSTERED
        (
    [IDERROR] ASC
        )
        WITH
        (
            PAD_INDEX = OFF,
            STATISTICS_NORECOMPUTE = OFF,
            IGNORE_DUP_KEY = OFF,
            ALLOW_ROW_LOCKS = ON,
            ALLOW_PAGE_LOCKS = ON,
            OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
        )
        ON [PRIMARY];
END;
GO
