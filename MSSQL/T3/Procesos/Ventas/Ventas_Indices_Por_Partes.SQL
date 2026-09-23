/*
  VENTAS - CREACION EXPLICITA POR INDICE
  Servidor: AZCRNMXNEVTD06. Base: T3QA.

  En SSMS, seleccionar UN bloque completo, desde USE hasta su GO final,
  y ejecutar con F5. Cada bloque contiene sus propias opciones de sesion.
  No ejecutar todo el archivo si se desea trabajar indice por indice.
  Confirmar que la ejecucion anterior haya terminado o se haya cancelado
  completamente antes de iniciar estos bloques en otra ventana.

  Conserva los ocho nombres y definiciones de Ventas_Indices.SQL.
  Los indices ya creados por ese archivo se omiten por nombre.
  Si un indice con ese nombre esta deshabilitado/hipotetico, se informa error.
  No comprueba equivalencia con indices de OTRO nombre: revisar antes de crear.
  No elimina ni reconstruye indices. No usa SQL dinamico, JSON ni ciclos.

  La creacion puede tardar por volumen, recursos o bloqueos. Dividirla no
  reduce por si mismo el costo de cada CREATE INDEX. Ejecutar en una ventana
  de mantenimiento y revisar Mensajes para identificar el indice en curso.
  No hay transaccion global; cada indice completado permanece creado.
  Requiere permiso ALTER sobre la tabla y visibilidad de sus metadatos.
*/

-- BLOQUE 1 DE 8: T3.REGISTRO_FISCAL / IX_Ventas_RF_FechaFactura_Tipo
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RF_FechaFactura_Tipo' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_RF_FechaFactura_Tipo: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RF_FechaFactura_Tipo' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 1/8: IX_Ventas_RF_FechaFactura_Tipo',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_RF_FechaFactura_Tipo]
    ON [T3].[REGISTRO_FISCAL] ([FECHA_FACTURA], [TIPO_DOCTO])
    INCLUDE ([FACTURA], [ENTREGA], [STATUS], [CLIENTE_SAP]);
    RAISERROR(N'CREADO 1/8: IX_Ventas_RF_FechaFactura_Tipo',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_RF_FechaFactura_Tipo. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 2 DE 8: T3.REGISTRO_FISCAL / IX_Ventas_RF_FechaDocumento_Tipo
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RF_FechaDocumento_Tipo' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_RF_FechaDocumento_Tipo: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RF_FechaDocumento_Tipo' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 2/8: IX_Ventas_RF_FechaDocumento_Tipo',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_RF_FechaDocumento_Tipo]
    ON [T3].[REGISTRO_FISCAL] ([FECHA_DOCUMENTO], [TIPO_DOCTO])
    INCLUDE ([FACTURA], [ENTREGA], [STATUS]);
    RAISERROR(N'CREADO 2/8: IX_Ventas_RF_FechaDocumento_Tipo',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_RF_FechaDocumento_Tipo. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 3 DE 8: T3.REGISTRO_FISCAL_DETALLE / IX_Ventas_RFD_Factura
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL_DETALLE]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RFD_Factura' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_RFD_Factura: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[REGISTRO_FISCAL_DETALLE]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_RFD_Factura' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 3/8: IX_Ventas_RFD_Factura',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_RFD_Factura]
    ON [T3].[REGISTRO_FISCAL_DETALLE] ([FACTURA])
    INCLUDE ([VALOR_SUBT], [VALOR_IVA], [ENVIO_SUBT], [ENVIO_IVA], [CREDITO_SUBT], [CREDITO_IVA], [BONIF_SUBT], [BONIF_IVA]);
    RAISERROR(N'CREADO 3/8: IX_Ventas_RFD_Factura',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_RFD_Factura. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 4 DE 8: T3.CFDI_COBRANZA / IX_Ventas_Cobranza_IncobrableNC
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_COBRANZA]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Cobranza_IncobrableNC' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_Cobranza_IncobrableNC: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_COBRANZA]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Cobranza_IncobrableNC' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 4/8: IX_Ventas_Cobranza_IncobrableNC',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_Cobranza_IncobrableNC]
    ON [T3].[CFDI_COBRANZA] ([NOTA_CREDITO])
    INCLUDE ([IMPORTE], [FACTURA], [VIA_PAGO])
    WHERE [FACTURA] = 'INCOBRABLE' AND [VIA_PAGO] = 'AI' AND [NOTA_CREDITO] IS NOT NULL;
    RAISERROR(N'CREADO 4/8: IX_Ventas_Cobranza_IncobrableNC',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_Cobranza_IncobrableNC. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 5 DE 8: T3.CLIENTE / IX_Ventas_Cliente_SAP_Vigencia
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CLIENTE]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Cliente_SAP_Vigencia' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_Cliente_SAP_Vigencia: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CLIENTE]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Cliente_SAP_Vigencia' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 5/8: IX_Ventas_Cliente_SAP_Vigencia',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_Cliente_SAP_Vigencia]
    ON [T3].[CLIENTE] ([CLIENTE_SAP], [FECHA_INI_VIG])
    INCLUDE ([FECHA_FIN_VIG], [NOMBRE], [RFC]);
    RAISERROR(N'CREADO 5/8: IX_Ventas_Cliente_SAP_Vigencia',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_Cliente_SAP_Vigencia. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 6 DE 8: T3.CFDI_HISTORIA_DOCTO_PAC / IX_Ventas_PAC_NotaVenta
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_HISTORIA_DOCTO_PAC]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_PAC_NotaVenta' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_PAC_NotaVenta: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_HISTORIA_DOCTO_PAC]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_PAC_NotaVenta' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 6/8: IX_Ventas_PAC_NotaVenta',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_PAC_NotaVenta]
    ON [T3].[CFDI_HISTORIA_DOCTO_PAC] ([NOTA_VENTA])
    INCLUDE ([NOTA_VENTA_CFDI]);
    RAISERROR(N'CREADO 6/8: IX_Ventas_PAC_NotaVenta',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_PAC_NotaVenta. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 7 DE 8: T3.CFDI_DOCUMENTOS / IX_Ventas_CFDI_NotaVenta
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_DOCUMENTOS]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_CFDI_NotaVenta' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_CFDI_NotaVenta: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_DOCUMENTOS]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_CFDI_NotaVenta' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 7/8: IX_Ventas_CFDI_NotaVenta',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_CFDI_NotaVenta]
    ON [T3].[CFDI_DOCUMENTOS] ([NOTA_VENTA])
    INCLUDE ([FECHA_ENVIO], [FECHA_TIMBRE], [FECHA_DOCUMENTO], [FOLIO_FISCAL]);
    RAISERROR(N'CREADO 7/8: IX_Ventas_CFDI_NotaVenta',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_CFDI_NotaVenta. Verificar su definicion si fue creado manualmente.';
GO

-- BLOQUE 8 DE 8: T3.CFDI_DOCUMENTO_PASO / IX_Ventas_Paso_Factura
USE [T3QA];
GO
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_DOCUMENTO_PASO]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Paso_Factura' COLLATE DATABASE_DEFAULT
      AND (is_disabled=1 OR is_hypothetical=1)
)
    THROW 51210,'IX_Ventas_Paso_Factura: existe deshabilitado o hipotetico. Revisar.',1;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'[T3].[CFDI_DOCUMENTO_PASO]')
      AND name COLLATE DATABASE_DEFAULT=N'IX_Ventas_Paso_Factura' COLLATE DATABASE_DEFAULT
)
BEGIN
    RAISERROR(N'INICIO 8/8: IX_Ventas_Paso_Factura',10,1) WITH NOWAIT;
    CREATE NONCLUSTERED INDEX [IX_Ventas_Paso_Factura]
    ON [T3].[CFDI_DOCUMENTO_PASO] ([FACTURA])
    INCLUDE ([VOIDDOC]);
    RAISERROR(N'CREADO 8/8: IX_Ventas_Paso_Factura',10,1) WITH NOWAIT;
END
ELSE
    PRINT N'OMITIDO: ya existe IX_Ventas_Paso_Factura. Verificar su definicion si fue creado manualmente.';
GO

