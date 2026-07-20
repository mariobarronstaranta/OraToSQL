IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[FC__REP_DISTRIBUTOR]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[FC__REP_DISTRIBUTOR]
        ADD CONSTRAINT [PK_FC__REP_DISTRIBUTOR] PRIMARY KEY CLUSTERED
        (
    [CREATED] ASC
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
