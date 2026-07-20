IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[CUSTOMERS_T3_ERROR_LOG]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[CUSTOMERS_T3_ERROR_LOG]
        ADD CONSTRAINT [PK_CUSTOMERS_T3_ERROR_LOG] PRIMARY KEY CLUSTERED
        (
    [CUST_ID] ASC,
    [LOG_DATE] ASC
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
