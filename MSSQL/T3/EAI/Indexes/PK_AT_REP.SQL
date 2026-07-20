IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[AT_REP]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[AT_REP]
        ADD CONSTRAINT [PK_AT_REP] PRIMARY KEY CLUSTERED
        (
    [LOGIN] ASC
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
