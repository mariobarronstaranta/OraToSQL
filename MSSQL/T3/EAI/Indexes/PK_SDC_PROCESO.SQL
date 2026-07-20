IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_PROCESO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_PROCESO]
        ADD CONSTRAINT [PK_SDC_PROCESO] PRIMARY KEY CLUSTERED
        (
    [ID_PROCESO] ASC
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
