IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CARGA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CARGA]
        ADD CONSTRAINT [PK_SDC_CARGA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [SEMANA] ASC,
    [UPC] ASC
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
