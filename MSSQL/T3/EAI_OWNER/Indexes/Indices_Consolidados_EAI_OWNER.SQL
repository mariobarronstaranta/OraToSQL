/*
    Instalacion consolidada de indices y restricciones del schema EAI_OWNER.
    Objetos incluidos: 65.
    Ejecutar en la base de datos destino despues de crear las tablas y schemas.
    El script no cambia el contexto de base de datos.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- Objeto: CLIENT_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[CLIENT]')
      AND name = N'CLIENT_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CLIENT_IDX1]
    ON [EAI_OWNER].[CLIENT]
    (
        [ID] ASC,
        [CLIENTE_SAP] ASC,
        [CLIENTE_V3] ASC,
        [STATUS] ASC,
        [SALES_TERRITORY] ASC,
        [DELIVERY_TERRITORY] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CREDIT_NOTES_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[CREDIT_NOTES]')
      AND name = N'CREDIT_NOTES_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CREDIT_NOTES_IDX1]
    ON [EAI_OWNER].[CREDIT_NOTES]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CREDIT_NOTES_IDX2
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[CREDIT_NOTES]', N'CREDIT_NOTES_IDX2_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[CREDIT_NOTES]
        ADD [CREDIT_NOTES_IDX2_EXPR] AS (CONVERT(date, REPLACE([FECHA], '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[CREDIT_NOTES]')
      AND name = N'CREDIT_NOTES_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CREDIT_NOTES_IDX2]
    ON [EAI_OWNER].[CREDIT_NOTES]
    (
        [CREDIT_NOTES_IDX2_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX2]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [STATUS] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX3
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]', N'DEBIT_OPEN_ITEM_IDX3_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[DEBIT_OPEN_ITEM]
        ADD [DEBIT_OPEN_ITEM_IDX3_EXPR] AS (CONVERT(date, REPLACE(LEFT([CREATED_DATE], 10), '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX3]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [DEBIT_OPEN_ITEM_IDX3_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX4
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]', N'DEBIT_OPEN_ITEM_IDX4_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[DEBIT_OPEN_ITEM]
        ADD [DEBIT_OPEN_ITEM_IDX4_EXPR] AS (CONVERT(date, REPLACE(LEFT([LAST_MOD_DT], 10), '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX4]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [DEBIT_OPEN_ITEM_IDX4_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX5]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [DOC_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX6]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX7
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX7'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX7]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [INVC_NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DEBIT_OPEN_ITEM_IDX8
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DEBIT_OPEN_ITEM_IDX8'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DEBIT_OPEN_ITEM_IDX8]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [NAME] ASC
    )
    INCLUDE ([STATUS])
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: DOI_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[DEBIT_OPEN_ITEM]')
      AND name = N'DOI_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [DOI_IDX1]
    ON [EAI_OWNER].[DEBIT_OPEN_ITEM]
    (
        [NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACT_DET_IDX1
-- ============================================================================
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

-- ============================================================================
-- Objeto: FACT_DET_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACT_DET]')
      AND name = N'FACT_DET_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACT_DET_IDX2]
    ON [EAI_OWNER].[FACT_DET]
    (
        [INVC_DOC_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX1
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[FACTURAS]', N'FACTURAS_IDX1_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[FACTURAS]
        ADD [FACTURAS_IDX1_EXPR] AS (CONVERT(date, REPLACE([INVC_DT], '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX1]
    ON [EAI_OWNER].[FACTURAS]
    (
        [FACTURAS_IDX1_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX1_B
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[FACTURAS_B]', N'FACTURAS_IDX1_B_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[FACTURAS_B]
        ADD [FACTURAS_IDX1_B_EXPR] AS (CONVERT(date, REPLACE([INVC_DT], '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX1_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX1_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [FACTURAS_IDX1_B_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX2]
    ON [EAI_OWNER].[FACTURAS]
    (
        [DELIVERY_STATUS] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX2_B
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX2_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX2_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [DELIVERY_STATUS] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX3]
    ON [EAI_OWNER].[FACTURAS]
    (
        [DOC_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX3_B
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX3_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX3_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [DOC_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX4]
    ON [EAI_OWNER].[FACTURAS]
    (
        [NUM_PEDIDO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX4_B
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX4_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX4_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [NUM_PEDIDO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX5]
    ON [EAI_OWNER].[FACTURAS]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX5_B
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX5_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX5_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS]')
      AND name = N'FACTURAS_IDX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX6]
    ON [EAI_OWNER].[FACTURAS]
    (
        [TIPO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FACTURAS_IDX6_B
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[FACTURAS_B]')
      AND name = N'FACTURAS_IDX6_B'
)
BEGIN
    CREATE NONCLUSTERED INDEX [FACTURAS_IDX6_B]
    ON [EAI_OWNER].[FACTURAS_B]
    (
        [TIPO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: FILTER_CLIENTE_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI_OWNER].[FILTER_CLIENTE]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI_OWNER].[FILTER_CLIENTE]
        ADD CONSTRAINT [FILTER_CLIENTE_PK] PRIMARY KEY CLUSTERED
        (
            [CLIENTE_V3] ASC
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

-- ============================================================================
-- Objeto: FOLIOS_SF_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI_OWNER].[FOLIOS_SF]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI_OWNER].[FOLIOS_SF]
        ADD CONSTRAINT [FOLIOS_SF_PK] PRIMARY KEY CLUSTERED
        (
            [ID] ASC
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

-- ============================================================================
-- Objeto: HIST_CLIENTE_SF_ERP_SAP
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[HIST_CLIENTE_SF]')
      AND name = N'HIST_CLIENTE_SF_ERP_SAP'
)
BEGIN
    CREATE NONCLUSTERED INDEX [HIST_CLIENTE_SF_ERP_SAP]
    ON [EAI_OWNER].[HIST_CLIENTE_SF]
    (
        [IVYBAT__SAP_CUSTOMERID__C] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_EAI_MESSAGE_LOG_ID
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]')
      AND name = N'MX_EAI_MESSAGE_LOG_ID'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_EAI_MESSAGE_LOG_ID]
    ON [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_EAI_MESSAGE_LOG_QUEUE_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_EAI_MESSAGE_LOG]')
      AND name = N'MX_EAI_MESSAGE_LOG_QUEUE_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_EAI_MESSAGE_LOG_QUEUE_IX]
    ON [EAI_OWNER].[MX_EAI_MESSAGE_LOG]
    (
        [QUEUE_NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_HASH_KDGRP_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_HASH_KDGRP]')
      AND name = N'MX_HASH_KDGRP_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_HASH_KDGRP_IX]
    ON [EAI_OWNER].[MX_HASH_KDGRP]
    (
        [LLAVE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_HASHTABLE_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_HASHTABLE]')
      AND name = N'MX_HASHTABLE_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_HASHTABLE_IX]
    ON [EAI_OWNER].[MX_HASHTABLE]
    (
        [TYPE] ASC,
        [SOURCE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_PRINT_DELIVERY_CUST_SAP_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_PRINT_DELIVERY]')
      AND name = N'MX_PRINT_DELIVERY_CUST_SAP_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_PRINT_DELIVERY_CUST_SAP_IX]
    ON [EAI_OWNER].[MX_PRINT_DELIVERY]
    (
        [CUST_TO_SAP] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_PRINT_DELIVERY_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_PRINT_DELIVERY]')
      AND name = N'MX_PRINT_DELIVERY_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_PRINT_DELIVERY_IX]
    ON [EAI_OWNER].[MX_PRINT_DELIVERY]
    (
        [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_RECVMSG_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]')
      AND name = N'MX_RECVMSG_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_RECVMSG_IDX1]
    ON [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
    (
        [ROW_ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_RECVMSG_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]')
      AND name = N'MX_RECVMSG_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_RECVMSG_IDX2]
    ON [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
    (
        [QUEUE_NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: MX_RECVMSG_IDX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]')
      AND name = N'MX_RECVMSG_IDX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [MX_RECVMSG_IDX5]
    ON [EAI_OWNER].[MX_RECEIVE_MESSAGE_LOG]
    (
        [QUEUE_NAME] ASC,
        [CREATED] ASC,
        [PROCESSED] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PAG_IDX_TERR
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAG_IDX_TERR'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAG_IDX_TERR]
    ON [EAI_OWNER].[PAGOS]
    (
        [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PAGOS_IDX1
-- ============================================================================
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

-- ============================================================================
-- Objeto: PAGOS_IDX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX3]
    ON [EAI_OWNER].[PAGOS]
    (
        [DOI_STATUS] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PAGOS_IDX4
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[PAGOS]', N'PAGOS_IDX4_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[PAGOS]
        ADD [PAGOS_IDX4_EXPR] AS (CONVERT(date, REPLACE([PAYMENT_DT], '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX4]
    ON [EAI_OWNER].[PAGOS]
    (
        [PAGOS_IDX4_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PAGOS_IDX5
-- ============================================================================
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

-- ============================================================================
-- Objeto: PAGOS_IDX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX6]
    ON [EAI_OWNER].[PAGOS]
    (
        [ID] ASC
    )
    INCLUDE ([TERRITORIO])
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PAGOS_IDX7
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PAGOS]')
      AND name = N'PAGOS_IDX7'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PAGOS_IDX7]
    ON [EAI_OWNER].[PAGOS]
    (
        [DOI_STATUS] ASC
    )
    INCLUDE ([TERRITORIO])
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PED_DET_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PED_DET]')
      AND name = N'PED_DET_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PED_DET_IDX1]
    ON [EAI_OWNER].[PED_DET]
    (
        [ORDER_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PED_DET_IDX2
-- ============================================================================
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

-- ============================================================================
-- Objeto: PEDIDOS_IDX1
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[PEDIDOS]', N'PEDIDOS_IDX1_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[PEDIDOS]
        ADD [PEDIDOS_IDX1_EXPR] AS (CONVERT(date, REPLACE([ORDER_DT], '-', ''), 112)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PEDIDOS]')
      AND name = N'PEDIDOS_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PEDIDOS_IDX1]
    ON [EAI_OWNER].[PEDIDOS]
    (
        [PEDIDOS_IDX1_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PEDIDOS_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PEDIDOS]')
      AND name = N'PEDIDOS_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PEDIDOS_IDX2]
    ON [EAI_OWNER].[PEDIDOS]
    (
        [ORDER_STATUS] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PEDIDOS_IDX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PEDIDOS]')
      AND name = N'PEDIDOS_IDX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PEDIDOS_IDX3]
    ON [EAI_OWNER].[PEDIDOS]
    (
        [NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: PEDIDOS_IDX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[PEDIDOS]')
      AND name = N'PEDIDOS_IDX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [PEDIDOS_IDX4]
    ON [EAI_OWNER].[PEDIDOS]
    (
        [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: RECURSOS_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[RECURSO_TERRITORIO]')
      AND name = N'RECURSOS_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [RECURSOS_IDX1]
    ON [EAI_OWNER].[RECURSO_TERRITORIO]
    (
        [RESOURCE_NAME] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: RECURSOS_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[RECURSO_TERRITORIO]')
      AND name = N'RECURSOS_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [RECURSOS_IDX2]
    ON [EAI_OWNER].[RECURSO_TERRITORIO]
    (
        [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: RT_IDX1
-- ============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'[EAI_OWNER].[RECURSO_TERRITORIO]', N'RT_IDX1_EXPR') IS NULL
BEGIN
    ALTER TABLE [EAI_OWNER].[RECURSO_TERRITORIO]
        ADD [RT_IDX1_EXPR] AS (SUBSTRING([TERRITORIO], 17, 4)) PERSISTED;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[RECURSO_TERRITORIO]')
      AND name = N'RT_IDX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [RT_IDX1]
    ON [EAI_OWNER].[RECURSO_TERRITORIO]
    (
        [RT_IDX1_EXPR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: SR_ORDER_IDX1
-- ============================================================================
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

-- ============================================================================
-- Objeto: SR_ORDER_IDX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[SR_ORDER]')
      AND name = N'SR_ORDER_IDX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [SR_ORDER_IDX2]
    ON [EAI_OWNER].[SR_ORDER]
    (
        [TIPO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_IX_ACCNT
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_IX_ACCNT'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_IX_ACCNT]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [CLEARINGDOCNUMBER] ASC,
        [FISCALYEAR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_IX_BILL
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_IX_BILL'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_IX_BILL]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [BILLINGDOCUMENT] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_IX_REFDOC
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_IX_REFDOC'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_IX_REFDOC]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [REFERENCEDOCNUMBER] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_IXDOC
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_IXDOC'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_IXDOC]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [ACCNTDOCNUMBER] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_IXIDOC
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_IXIDOC'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_IXIDOC]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [IDOCNUMBER] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_ACCOUNT_HEADER_RESIDUAL_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_ACCOUNT_HEADER]')
      AND name = N'TMP_ACCOUNT_HEADER_RESIDUAL_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_ACCOUNT_HEADER_RESIDUAL_IX]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER]
    (
        [RESIDUALTRANSBELONGSTO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_DOCUMENT_DETAIL_COND_IDX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_DETAIL_COND]')
      AND name = N'TMP_DOCUMENT_DETAIL_COND_IDX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_DOCUMENT_DETAIL_COND_IDX]
    ON [EAI_OWNER].[TMP_DOCUMENT_DETAIL_COND]
    (
        [REFERENCEID] ASC,
        [ITEMID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_DOCUMENT_DETAIL_IDX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_DETAIL]')
      AND name = N'TMP_DOCUMENT_DETAIL_IDX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_DOCUMENT_DETAIL_IDX]
    ON [EAI_OWNER].[TMP_DOCUMENT_DETAIL]
    (
        [REFERENCEID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_DOCUMENT_HEADER_IXREF
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_HEADER]')
      AND name = N'TMP_DOCUMENT_HEADER_IXREF'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_DOCUMENT_HEADER_IXREF]
    ON [EAI_OWNER].[TMP_DOCUMENT_HEADER]
    (
        [REFERENCEID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: TMP_DOCUMENT_PARTNERS_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI_OWNER].[TMP_DOCUMENT_PARTNERS]')
      AND name = N'TMP_DOCUMENT_PARTNERS_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [TMP_DOCUMENT_PARTNERS_IX]
    ON [EAI_OWNER].[TMP_DOCUMENT_PARTNERS]
    (
        [REFERENCEID] ASC
    )
    ON [PRIMARY];
END;
GO
