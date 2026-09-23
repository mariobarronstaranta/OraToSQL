USE [T3QA]
GO

/****** Object:  Table [T3].[FACTURA_GENERAL]    Script Date: 9/8/2026 2:36:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [T3].[FACTURA_GENERAL](
	[FACTURA] [varchar](30) NULL,
	[DISTRIBUIDOR] [numeric](4, 0) NULL,
	[FECHA_FACTURA] [datetime] NULL,
	[TIPO_DOCTO] [varchar](4) NULL,
	[CLIENTE_V3] [varchar](15) NULL,
	[CLIENTE_SAP] [varchar](10) NULL,
	[UBICACION] [varchar](20) NULL,
	[REP_ID] [varchar](10) NULL,
	[STATUS] [varchar](15) NULL,
	[CLTE_FACTURA_V3] [varchar](15) NULL,
	[CLTE_FACTURA_SAP] [varchar](10) NULL,
	[FECHA_TRN] [datetime] NULL,
	[CREDITO_EXPRESS] [varchar](20) NULL,
	[FECHA_PAGO] [datetime] NULL,
	[ROW_ID] [varchar](15) NULL,
	[VALOR_SUBT] [numeric](15, 2) NULL,
	[VALOR_DESC] [numeric](15, 2) NULL,
	[VALOR_IVA] [numeric](15, 2) NULL,
	[FECHA_PROC_BATMD] [datetime] NULL,
	[VALOR_ISSA] [numeric](15, 2) NULL,
	[CTRO] [varchar](4) NULL,
	[BONIF_SUBT] [numeric](15, 2) NULL,
	[BONIF_IVA] [numeric](15, 2) NULL,
	[BONIF_PORC] [numeric](5, 2) NULL,
	[BONIF_VOL] [numeric](10, 0) NULL,
	[ENVIO_SUBT] [numeric](15, 2) NULL,
	[ENVIO_IVA] [numeric](15, 2) NULL,
	[ENTREGA] [varchar](10) NULL,
	[PEDIDO] [varchar](18) NULL,
	[REFERENCIA] [varchar](30) NULL,
	[CREDITO_SUBT] [numeric](15, 2) NULL,
	[CREDITO_IVA] [numeric](15, 2) NULL
) ON [PRIMARY]
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'T3 - Inbound from V3 to T3' , @level0type=N'SCHEMA',@level0name=N'T3', @level1type=N'TABLE',@level1name=N'FACTURA_GENERAL'
GO


