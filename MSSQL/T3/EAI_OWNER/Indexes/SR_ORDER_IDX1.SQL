IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[SR_ORDER]')
      AND name = N'SR_ORDER_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [SR_ORDER_IDX1]
    ON [EAI_OWNER].[SR_ORDER]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO
