IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[EAI_CUSTOMER_NO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[EAI_CUSTOMER_NO]
        ADD CONSTRAINT [PK_CUSTOMER_NO] PRIMARY KEY CLUSTERED
        (
    [CUSTTYPE] ASC
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
