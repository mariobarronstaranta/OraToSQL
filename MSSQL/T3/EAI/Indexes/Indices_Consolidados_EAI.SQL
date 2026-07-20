/*
    Instalacion consolidada de indices y restricciones del schema EAI.
    Objetos incluidos: 86.
    Ejecutar en la base de datos destino despues de crear las tablas y schemas.
    El script no cambia el contexto de base de datos.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- Objeto: CFDI_BITACORA_DOC_NUM_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CFDI_BITACORA]')
      AND name = N'CFDI_BITACORA_DOC_NUM_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CFDI_BITACORA_DOC_NUM_IX]
    ON [EAI].[CFDI_BITACORA]
    (
    [DOC_NUM] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CFDI_OPEN_ITEMS_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CFDI_OPEN_ITEMS]')
      AND name = N'CFDI_OPEN_ITEMS_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CFDI_OPEN_ITEMS_IX]
    ON [EAI].[CFDI_OPEN_ITEMS]
    (
    [NOTA_VENTA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CLIENTES_SIEBEL_I1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CLIENTE_SIEBEL]')
      AND name = N'CLIENTES_SIEBEL_I1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CLIENTES_SIEBEL_I1]
    ON [EAI].[CLIENTE_SIEBEL]
    (
    [CLIENTE_V3] ASC,
    [CLIENTE_SAP] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CLIENTES_SIEBEL_I2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CLIENTE_SIEBEL]')
      AND name = N'CLIENTES_SIEBEL_I2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CLIENTES_SIEBEL_I2]
    ON [EAI].[CLIENTE_SIEBEL]
    (
    [CLIENTE_V3] ASC,
    [DIAS_CDTO] ASC,
    [RFC] ASC,
    [LISTA_IVA] ASC,
    [LISTA_PRECIO] ASC,
    [TERRITORIO] ASC,
    [DIST_COBZA] ASC,
    [FORMA_PAGO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: CUSTOMER_LOG_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CUSTOMER_LOG]')
      AND name = N'CUSTOMER_LOG_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [CUSTOMER_LOG_IX]
    ON [EAI].[CUSTOMER_LOG]
    (
    [CLIENTE_V3] ASC,
    [FECHA_INSERT] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_BITACORA_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_BITACORA]')
      AND name = N'ENCUESTAS_BITACORA_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_BITACORA_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_BITACORA]
    (
    [FECHA_HORA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [IDENCUESTADO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [IDENCUESTADOR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX4]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [DIA_VISITA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX5]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CARGADAS_INDEX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_CARGADAS]')
      AND name = N'ENCUESTAS_CARGADAS_INDEX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_CARGADAS_INDEX6]
    ON [EAI].[ENCUESTAS_CLIENTES_CARGADAS]
    (
    [SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_CLIENTES_BITACO_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_BITACORA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[ENCUESTAS_CLIENTES_BITACORA]
        ADD CONSTRAINT [ENCUESTAS_CLIENTES_BITACO_PK] PRIMARY KEY CLUSTERED
        (
    [IDEJECUCION] ASC
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
-- Objeto: ENCUESTAS_CLIENTES_ERRORE_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_ERRORES]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[ENCUESTAS_CLIENTES_ERRORES]
        ADD CONSTRAINT [ENCUESTAS_CLIENTES_ERRORE_PK] PRIMARY KEY CLUSTERED
        (
    [IDERROR] ASC
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
-- Objeto: ENCUESTAS_CLIENTES_INVALI_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
        ADD CONSTRAINT [ENCUESTAS_CLIENTES_INVALI_PK] PRIMARY KEY CLUSTERED
        (
    [IDENCUESTA_INVALIDA] ASC
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
-- Objeto: ENCUESTAS_CLIENTES_VALIDA_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
        ADD CONSTRAINT [ENCUESTAS_CLIENTES_VALIDA_PK] PRIMARY KEY CLUSTERED
        (
    [IDENCUESTA] ASC
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
-- Objeto: ENCUESTAS_ERRORES_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_ERRORES]')
      AND name = N'ENCUESTAS_ERRORES_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_ERRORES_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_ERRORES]
    (
    [IDENCUESTA_INVALIDA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_ERRORES_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_ERRORES]')
      AND name = N'ENCUESTAS_ERRORES_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_ERRORES_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_ERRORES]
    (
    [FECHA_REGISTRO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_ERRORES_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_ERRORES]')
      AND name = N'ENCUESTAS_ERRORES_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_ERRORES_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_ERRORES]
    (
    [CAMPO_ERROR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [DIA_DE_VISITA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX4]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX5]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [CLAVE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX6]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INEGI_INDEX7
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INEGI]')
      AND name = N'ENCUESTAS_INEGI_INDEX7'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INEGI_INDEX7]
    ON [EAI].[ENCUESTAS_CLIENTES_INEGI]
    (
    [ID_BAT] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [TERRITORIO] ASC,
    [ANIO_SEMANA] ASC,
    [DIA_SEMANA] ASC,
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [IDEJECUCION] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX4]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [ANIO_SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX5]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [DIA_SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX6]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX7
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX7'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX7]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [IDENCUESTADO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX8
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX8'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX8]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [IDENCUESTADOR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_INVALIDAS_INDEX9
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_INVALIDAS]')
      AND name = N'ENCUESTAS_INVALIDAS_INDEX9'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_INVALIDAS_INDEX9]
    ON [EAI].[ENCUESTAS_CLIENTES_INVALIDAS]
    (
    [FECHA_INICIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [IDENCUESTADO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [IDENCUESTADOR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX4
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX4'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX4]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [DIA_VISITA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX5]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_RESUMEN_INDEX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_RESUMEN]')
      AND name = N'ENCUESTAS_RESUMEN_INDEX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_RESUMEN_INDEX6]
    ON [EAI].[ENCUESTAS_CLIENTES_RESUMEN]
    (
    [SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX1]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [TERRITORIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX2
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX2'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX2]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [ANIO_SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX3
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX3'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX3]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [DIA_SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX5
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX5'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX5]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [IDENCUESTADO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX6
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX6'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX6]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [IDENCUESTADOR] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX7
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX7'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX7]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [SEMANA] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX8
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX8'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX8]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [FECHA_INICIO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: ENCUESTAS_VALIDAS_INDEX9
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[ENCUESTAS_CLIENTES_VALIDAS]')
      AND name = N'ENCUESTAS_VALIDAS_INDEX9'
)
BEGIN
    CREATE NONCLUSTERED INDEX [ENCUESTAS_VALIDAS_INDEX9]
    ON [EAI].[ENCUESTAS_CLIENTES_VALIDAS]
    (
    [TERRITORIO] ASC,
    [ANIO_SEMANA] ASC,
    [DIA_SEMANA] ASC,
    [CONSECUTIVO] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: I1_FC__REP_DISTRIBUTOR
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[FC__REP_DISTRIBUTOR]')
      AND name = N'I1_FC__REP_DISTRIBUTOR'
)
BEGIN
    CREATE NONCLUSTERED INDEX [I1_FC__REP_DISTRIBUTOR]
    ON [EAI].[FC__REP_DISTRIBUTOR]
    (
    [REP_ID] ASC,
    [START_DATE] ASC,
    [END_DATE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: IDX_CONTROL_REPORTE
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[CONTROL_REPORTE]')
      AND name = N'IDX_CONTROL_REPORTE'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [IDX_CONTROL_REPORTE]
    ON [EAI].[CONTROL_REPORTE]
    (
    [REPORTE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: IFC_FOLIOS_CONFIG_EMAIL_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[IFC_FOLIOS_CONFIG_EMAIL]')
      AND name = N'IFC_FOLIOS_CONFIG_EMAIL_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IFC_FOLIOS_CONFIG_EMAIL_INDEX1]
    ON [EAI].[IFC_FOLIOS_CONFIG_EMAIL]
    (
    [RFC] ASC,
    [CLIENTE_V3] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: IFC_FOLIOS_FE_CREADOPOR
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[IFC_FOLIOS_FE]')
      AND name = N'IFC_FOLIOS_FE_CREADOPOR'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IFC_FOLIOS_FE_CREADOPOR]
    ON [EAI].[IFC_FOLIOS_FE]
    (
    [CREADOPOR] ASC,
    [ROW_ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: IFC_FOLIOS_FE_DOCNUM
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[IFC_FOLIOS_FE]')
      AND name = N'IFC_FOLIOS_FE_DOCNUM'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IFC_FOLIOS_FE_DOCNUM]
    ON [EAI].[IFC_FOLIOS_FE]
    (
    [VAR_1] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: IFC_FOLIOS_FE_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[IFC_FOLIOS_FE]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[IFC_FOLIOS_FE]
        ADD CONSTRAINT [IFC_FOLIOS_FE_PK] PRIMARY KEY CLUSTERED
        (
    [ROW_ID] ASC
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
-- Objeto: IX_DELPHIC_SEMANA_CLIENTE
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[LDR_DELPHIC]')
      AND name = N'IX_DELPHIC_SEMANA_CLIENTE'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_DELPHIC_SEMANA_CLIENTE]
    ON [EAI].[LDR_DELPHIC]
    (
    [WEEK_START] ASC,
    [SAP_CUSTOMER_CLEAN] ASC,
    [SKU_CODE] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: OUTCTL_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[OUT_CTRL]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[OUT_CTRL]
        ADD CONSTRAINT [OUTCTL_PK] PRIMARY KEY CLUSTERED
        (
    [DISTRIBUIDOR] ASC,
    [STAGE] ASC
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
-- Objeto: PK_AT_DISTRIB
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[AT_DISTRIB]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[AT_DISTRIB]
        ADD CONSTRAINT [PK_AT_DISTRIB] PRIMARY KEY CLUSTERED
        (
    [DISTRIB] ASC
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
-- Objeto: PK_AT_REP
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[AT_REP]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[AT_REP]
        ADD CONSTRAINT [PK_AT_REP] PRIMARY KEY CLUSTERED
        (
    [LOGIN] ASC
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
-- Objeto: PK_CAT_CREDIT_DAYS
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[CAT_CREDIT_DAYS]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[CAT_CREDIT_DAYS]
        ADD CONSTRAINT [PK_CAT_CREDIT_DAYS] PRIMARY KEY CLUSTERED
        (
    [DAYS] ASC
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
-- Objeto: PK_CUSTOMER_NO
-- ============================================================================
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

-- ============================================================================
-- Objeto: PK_CUSTOMERS_T3_ERROR_LOG
-- ============================================================================
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

-- ============================================================================
-- Objeto: PK_FC__REP_DISTRIBUTOR
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[FC__REP_DISTRIBUTOR]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[FC__REP_DISTRIBUTOR]
        ADD CONSTRAINT [PK_FC__REP_DISTRIBUTOR] PRIMARY KEY CLUSTERED
        (
    [CREATED] ASC
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
-- Objeto: PK_SDC_CADENA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CADENA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CADENA]
        ADD CONSTRAINT [PK_SDC_CADENA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC
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
-- Objeto: PK_SDC_CARGA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CARGA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CARGA]
        ADD CONSTRAINT [PK_SDC_CARGA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [SEMANA] ASC,
    [UPC] ASC
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
-- Objeto: PK_SDC_CARGA_DIA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CARGA_DIA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CARGA_DIA]
        ADD CONSTRAINT [PK_SDC_CARGA_DIA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [FECHA] ASC,
    [UPC] ASC
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
-- Objeto: PK_SDC_CEDIS
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_CEDIS]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_CEDIS]
        ADD CONSTRAINT [PK_SDC_CEDIS] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC
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
-- Objeto: PK_SDC_DISTIBUCION_VENTA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_DISTRIBUCION_VENTA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_DISTRIBUCION_VENTA]
        ADD CONSTRAINT [PK_SDC_DISTIBUCION_VENTA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [SEMANA] ASC,
    [MATERIAL] ASC
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
-- Objeto: PK_SDC_ERROR
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_ERROR]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_ERROR]
        ADD CONSTRAINT [PK_SDC_ERROR] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [SEMANA] ASC,
    [NO_ERROR] ASC
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
-- Objeto: PK_SDC_ERROR_DIARIA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_ERROR_DIARIA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_ERROR_DIARIA]
        ADD CONSTRAINT [PK_SDC_ERROR_DIARIA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [TIENDA] ASC,
    [FECHA] ASC,
    [NO_ERROR] ASC
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
-- Objeto: PK_SDC_ERROR_VENTA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_ERROR_VENTA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_ERROR_VENTA]
        ADD CONSTRAINT [PK_SDC_ERROR_VENTA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [ANIOMES] ASC,
    [PLAZA] ASC,
    [ERROR] ASC
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
-- Objeto: PK_SDC_HISTORIA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_HISTORIA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_HISTORIA]
        ADD CONSTRAINT [PK_SDC_HISTORIA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC,
    [ANIO] ASC,
    [MES] ASC,
    [MATERIAL] ASC
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
-- Objeto: PK_SDC_PLAZA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_PLAZA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_PLAZA]
        ADD CONSTRAINT [PK_SDC_PLAZA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC
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
-- Objeto: PK_SDC_PROCESO
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_PROCESO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_PROCESO]
        ADD CONSTRAINT [PK_SDC_PROCESO] PRIMARY KEY CLUSTERED
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

-- ============================================================================
-- Objeto: PK_SDC_TIENDA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_TIENDA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_TIENDA]
        ADD CONSTRAINT [PK_SDC_TIENDA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [CEDIS] ASC,
    [PLAZA] ASC,
    [TIENDA] ASC
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
-- Objeto: PK_SDC_VENTA_PDV
-- ============================================================================
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

-- ============================================================================
-- Objeto: SDC_CARGA_DIA_LDR_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[SDC_CARGA_DIA_LDR]')
      AND name = N'SDC_CARGA_DIA_LDR_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [SDC_CARGA_DIA_LDR_INDEX1]
    ON [EAI].[SDC_CARGA_DIA_LDR]
    (
    [TIEMPO_ID] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: SDC_ERROR_PUNTO_VENTA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_ERROR_PUNTO_VENTA]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_ERROR_PUNTO_VENTA]
        ADD CONSTRAINT [SDC_ERROR_PUNTO_VENTA] PRIMARY KEY CLUSTERED
        (
    [CADENA] ASC,
    [PLAZA] ASC,
    [ERROR] ASC,
    [ANIOSEM] ASC,
    [TIENDA] ASC,
    [UPC] ASC
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
-- Objeto: SDC_OXXO_DUNHILL_DIARIO_INDEX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[SDC_OXXO_DUNHILL_DIARIO]')
      AND name = N'SDC_OXXO_DUNHILL_DIARIO_INDEX1'
)
BEGIN
    CREATE NONCLUSTERED INDEX [SDC_OXXO_DUNHILL_DIARIO_INDEX1]
    ON [EAI].[SDC_OXXO_DUNHILL_DIARIO]
    (
    [SEMANA_ID] ASC,
    [NEGOCIO_DES] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: SDC_OXXO_DUNHILL_DIARIO_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'[EAI].[SDC_OXXO_DUNHILL_DIARIO]')
      AND [type] = 'PK'
)
BEGIN
    ALTER TABLE [EAI].[SDC_OXXO_DUNHILL_DIARIO]
        ADD CONSTRAINT [SDC_OXXO_DUNHILL_DIARIO_PK] PRIMARY KEY CLUSTERED
        (
    [SEMANA_ID] ASC,
    [UPC_CVE] ASC,
    [NEGOCIO_DES] ASC
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
-- Objeto: SDC_VENTA_IDX1
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[SDC_VENTA]')
      AND name = N'SDC_VENTA_IDX1'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [SDC_VENTA_IDX1]
    ON [EAI].[SDC_VENTA]
    (
    [CADENA] ASC,
    [ANIOMES] ASC,
    [PLAZA] ASC,
    [SKU] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: SEVEN_PROCESO_PK
-- ============================================================================
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

-- ============================================================================
-- Objeto: T3R_CARTERA_SAP_OLD_FACT_IX
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[T3R_CARTERA_SAP_OLD]')
      AND name = N'T3R_CARTERA_SAP_OLD_FACT_IX'
)
BEGIN
    CREATE NONCLUSTERED INDEX [T3R_CARTERA_SAP_OLD_FACT_IX]
    ON [EAI].[T3R_CARTERA_SAP_OLD]
    (
    [ASIGNACION] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: T3R_SALES_DOCS_FACTURA
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[T3R_SALES_DOCS_OLD]')
      AND name = N'T3R_SALES_DOCS_FACTURA'
)
BEGIN
    CREATE NONCLUSTERED INDEX [T3R_SALES_DOCS_FACTURA]
    ON [EAI].[T3R_SALES_DOCS_OLD]
    (
    [DOC_NUM_REF2] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: T3R_SALES_DOCS_ORDER_NUM
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[T3R_SALES_DOCS_OLD]')
      AND name = N'T3R_SALES_DOCS_ORDER_NUM'
)
BEGIN
    CREATE NONCLUSTERED INDEX [T3R_SALES_DOCS_ORDER_NUM]
    ON [EAI].[T3R_SALES_DOCS_OLD]
    (
    [DOC_NUM_REF1] ASC
    )
    ON [PRIMARY];
END;
GO

-- ============================================================================
-- Objeto: T3R_SALES_DOCS_OTHERS_PK
-- ============================================================================
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[EAI].[T3R_SALES_DOCS_OTHERS]')
      AND name = N'T3R_SALES_DOCS_OTHERS_PK'
)
BEGIN
    CREATE NONCLUSTERED INDEX [T3R_SALES_DOCS_OTHERS_PK]
    ON [EAI].[T3R_SALES_DOCS_OTHERS]
    (
    [DOC_NUM_R3] ASC
    )
    ON [PRIMARY];
END;
GO

