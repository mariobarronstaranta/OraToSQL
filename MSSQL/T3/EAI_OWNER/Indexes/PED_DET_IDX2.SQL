IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PED_DET]')
      AND name = N'PED_DET_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PED_DET_IDX2]
    ON [EAI_OWNER].[PED_DET]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO
