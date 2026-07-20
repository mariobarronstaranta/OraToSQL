IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_ERROR_DIARIA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_ERROR_DIARIA]
        ADD CONSTRAINT [PK_SDC_ERROR_DIARIA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [TIENDA] ASC,
    [FECHA] ASC,
    [NO_ERROR] ASC
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
