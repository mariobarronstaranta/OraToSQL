IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_OXXO_DUNHILL_DIARIO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_OXXO_DUNHILL_DIARIO]
        ADD CONSTRAINT [SDC_OXXO_DUNHILL_DIARIO_PK] PRIMARY KEY CLUSTERED
        (
    [SEMANA_ID] ASC,
    [UPC_CVE] ASC,
    [NEGOCIO_DES] ASC
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
