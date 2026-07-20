IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[CAT_CREDIT_DAYS]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[CAT_CREDIT_DAYS]
        ADD CONSTRAINT [PK_CAT_CREDIT_DAYS] PRIMARY KEY CLUSTERED
        (
    [DAYS] ASC
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
