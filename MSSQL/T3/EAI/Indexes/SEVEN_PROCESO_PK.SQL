IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SEVEN_PROCESO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SEVEN_PROCESO]
        ADD CONSTRAINT [SEVEN_PROCESO_PK] PRIMARY KEY CLUSTERED
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
