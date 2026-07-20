IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX5]
    ON [EAI_OWNER].[PAGOS]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO
