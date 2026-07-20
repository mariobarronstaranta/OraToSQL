IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI_OWNER].[FOLIOS_SF]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI_OWNER].[FOLIOS_SF]
        ADD CONSTRAINT [FOLIOS_SF_PK] PRIMARY KEY CLUSTERED
        (
            [ID] ASC
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
