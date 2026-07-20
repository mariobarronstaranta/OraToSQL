IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_DISTRIBUCION_VENTA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_DISTRIBUCION_VENTA]
        ADD CONSTRAINT [PK_SDC_DISTIBUCION_VENTA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [SEMANA] ASC,
    [MATERIAL] ASC
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
