IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CADENA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CADENA]
        ADD CONSTRAINT [PK_SDC_CADENA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC
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
