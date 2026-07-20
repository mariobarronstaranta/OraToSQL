IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_VENTA_MEN_PDV]')
      AND name = N'PK_SDC_VENTA_PDV'
      AND [type] = 'UQ'
)
BEGIN
    ALTER TABLE [EAI].[SDC_VENTA_MEN_PDV]
        ADD CONSTRAINT [PK_SDC_VENTA_PDV] UNIQUE NONCLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [ANIOMES] ASC,
    [PLAZA_CVE] ASC,
    [TIENDA_CVE] ASC,
    [SKU] ASC
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
