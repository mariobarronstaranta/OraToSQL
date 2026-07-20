IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[IFC_FOLIOS_FE]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[IFC_FOLIOS_FE]
        ADD CONSTRAINT [IFC_FOLIOS_FE_PK] PRIMARY KEY CLUSTERED
        (
    [ROW_ID] ASC
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
