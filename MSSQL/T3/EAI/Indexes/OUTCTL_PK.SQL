IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[OUT_CTRL]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[OUT_CTRL]
        ADD CONSTRAINT [OUTCTL_PK] PRIMARY KEY CLUSTERED
        (
    [DISTRIBUIDOR] ASC,
    [STAGE] ASC
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
