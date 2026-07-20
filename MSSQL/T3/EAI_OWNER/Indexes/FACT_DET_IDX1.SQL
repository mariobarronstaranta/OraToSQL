IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACT_DET]')
      AND name = N'FACT_DET_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACT_DET_IDX1]
    ON [EAI_OWNER].[FACT_DET]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO
