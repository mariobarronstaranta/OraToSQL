IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX1]
    ON [EAI_OWNER].[PAGOS]
    (
        [DOI_NAME] ASC
    )
    ON [PRIMARY];
END;
GO
