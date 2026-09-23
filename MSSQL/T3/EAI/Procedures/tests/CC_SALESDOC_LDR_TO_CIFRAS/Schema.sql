CREATE SCHEMA EAI;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA T3;
GO

CREATE TABLE [EAI].[TAO_SALES_DOCS_LDR](
	[DOC_ORD_R3] [varchar](20) NULL,
	[DOC_NUM_R3] [varchar](20) NULL,
	[CUSTOMER_NUMBER] [numeric](10, 0) NULL,
	[DISTRIBUTOR] [varchar](4) NULL,
	[CUSTOMER] [varchar](20) NULL,
	[DOC_DATE] [varchar](8) NULL,
	[DOC_TYPE] [varchar](4) NULL,
	[DOC_NUM_REF1] [varchar](30) NULL,
	[DOC_NUM_REF2] [varchar](30) NULL,
	[DOC_STATUS] [varchar](1) NULL,
	[DOC_NETAMT] [numeric](13, 3) NULL,
	[DOC_TAXAMT] [numeric](13, 3) NULL,
	[DOC_QTY] [numeric](13, 3) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[T3R_SALES_DOCS_OLD](
	[DOC_DATE] [varchar](8) NULL,
	[DISTRIBUTOR] [varchar](4) NULL,
	[CUSTOMER] [numeric](10, 0) NULL,
	[DOC_NUM_R3] [varchar](20) NULL,
	[DOC_ORD_R3] [varchar](20) NULL,
	[DOC_NUM_REF1] [varchar](30) NULL,
	[DOC_NUM_REF2] [varchar](30) NULL,
	[DOC_TYPE] [varchar](4) NULL,
	[DOC_STATUS] [varchar](1) NULL,
	[DOC_NETAMT] [numeric](13, 2) NULL,
	[DOC_TAXAMT] [numeric](13, 2) NULL,
	[DOC_QTY] [numeric](13, 2) NULL,
	[CREATED] [datetime2](0) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[T3R_SALES_DOCS_LDR_MX01](
	[DOC_DATE] [varchar](8) NULL,
	[DISTRIBUTOR] [varchar](4) NULL,
	[CUSTOMER] [varchar](10) NULL,
	[DOC_NUM_R3] [varchar](20) NULL,
	[DOC_ORD_R3] [varchar](20) NULL,
	[DOC_NUM_REF1] [varchar](20) NULL,
	[DOC_NUM_REF2] [varchar](20) NULL,
	[DOC_TYPE] [varchar](4) NULL,
	[DOC_STATUS] [varchar](1) NULL,
	[DOC_NETAMT] [numeric](13, 2) NULL,
	[DOC_TAXAMT] [numeric](13, 2) NULL,
	[DOC_QTY] [numeric](13, 2) NULL,
	[CREATED] [datetime2](0) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[T3R_SALES_DOCS_OTHERS](
	[DOC_DATE] [varchar](8) NULL,
	[DISTRIBUTOR] [varchar](4) NULL,
	[CUSTOMER] [numeric](10, 0) NULL,
	[DOC_NUM_R3] [varchar](20) NULL,
	[DOC_ORD_R3] [varchar](20) NULL,
	[DOC_NUM_REF1] [varchar](30) NULL,
	[DOC_NUM_REF2] [varchar](30) NULL,
	[DOC_TYPE] [varchar](4) NULL,
	[DOC_STATUS] [varchar](1) NULL,
	[DOC_NETAMT] [numeric](13, 2) NULL,
	[DOC_TAXAMT] [numeric](13, 2) NULL,
	[DOC_QTY] [numeric](13, 2) NULL,
	[CREATED] [datetime2](0) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[ERROR_TABLE](
	[DISTRIBUTOR] [numeric](4, 0) NULL,
	[PROCESS] [varchar](50) NULL,
	[DOC_NUM] [varchar](20) NULL,
	[ERR_DATE] [datetime2](0) NULL,
	[MESSAGE] [varchar](500) NULL,
	[CTRO] [varchar](4) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[CONTROL_REPORTE](
	[REPORTE] [varchar](50) NOT NULL,
	[INICIO] [datetime2](0) NULL,
	[FIN] [datetime2](0) NULL,
	[DESCRIPCION] [varchar](80) NULL,
	[FILTRO_DISP] [varchar](1) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI].[LOG_T3R_SALES_DOCS_OLD](
	[FECHA] [datetime2](0) NULL,
	[USUARIO] [varchar](30) NULL,
	[USUARIO_RED] [varchar](30) NULL,
	[IP] [varchar](30) NULL,
	[TERMINAL] [varchar](40) NULL,
	[DOC_NUM_R3] [varchar](10) NULL,
	[CAMBIO] [varchar](2000) NULL,
	[TICKET_REFERENCIA] [varchar](30) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI_OWNER].[MX_COMPONENTS](
	[COMPONENT] [numeric](3, 0) NULL,
	[DESCRIPTION] [varchar](60) NULL,
	[NAME] [varchar](60) NULL,
	[STATUS] [numeric](2, 0) NULL,
	[LAST_RUN] [datetime2](0) NULL
) ON [PRIMARY]
GO

CREATE TABLE [EAI_OWNER].[MX_EAI_MESSAGE_LOG](
	[DIRECTION] [varchar](20) NULL,
	[ID] [varchar](20) NULL,
	[CREATED] [datetime2](0) NULL,
	[MESSAGE] [varchar](max) NULL,
	[STATUS] [varchar](10) NULL,
	[QUEUE_NAME] [varchar](30) NULL,
	[SIEBEL_ERROR_MESSAGE] [varchar](2000) NULL,
	[SOURCE] [varchar](10) NULL,
	[SIEBEL_ERROR_CODE] [varchar](100) NULL,
	[RETRY_COUNT] [numeric](2, 0) NULL,
	[SEQUENCE] [numeric](2, 0) NULL,
	[PARENT_ROW_ID] [varchar](20) NULL,
	[REFERENCE] [varchar](50) NULL,
	[JOB_PID] [numeric](10, 0) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [T3].[PREVENTA_GENERAL](
	[FACTURA] [varchar](30) NULL,
	[PREFIJO] [varchar](3) NULL,
	[CENTRO] [varchar](4) NULL,
	[ENTREGA] [varchar](10) NULL,
	[FECHA_FACTURA] [datetime2](0) NULL,
	[FECHA_TRN] [datetime2](0) NULL,
	[CLASE_FACTURA] [varchar](4) NULL,
	[CLIENTE_SAP] [varchar](10) NULL,
	[CLIENTE_PAGADOR_SAP] [varchar](10) NULL,
	[UBICACION] [varchar](4) NULL,
	[PEDIDO] [varchar](18) NULL,
	[FECHA_EST_ENT] [datetime2](0) NULL,
	[VALOR_SUBT] [decimal](15, 2) NULL,
	[VALOR_IVA] [decimal](15, 2) NULL,
	[STATUS_CONTABLE] [char](2) NULL,
	[ANULADA] [char](1) NULL,
	[FECHA_ENTREGA] [datetime2](0) NULL,
	[FECHA_PROC_BATMD] [datetime2](0) NULL,
	[REFERENCIA] [varchar](30) NULL,
	[FECHA_CANCELACION] [datetime2](0) NULL,
	[VALOR_ISSA] [decimal](15, 2) NULL,
	[CTRO] [varchar](4) NULL,
	[BONIF_SUBT] [decimal](15, 2) NULL,
	[BONIF_IVA] [decimal](15, 2) NULL,
	[BONIF_PORC] [decimal](5, 2) NULL,
	[BONIF_VOL] [decimal](10, 0) NULL,
	[CLTE_FACTURA_SAP] [varchar](10) NULL,
	[CREDITO_SUBT] [decimal](15, 2) NULL,
	[CREDITO_IVA] [decimal](15, 2) NULL
) ON [PRIMARY]
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


CREATE TABLE [T3].[RF_PROCESOS_LOG](
	[PID] [decimal](10, 0) NULL,
	[PROCESO] [decimal](4, 0) NULL,
	[FECHA_PROC_BATMD] [datetime2](0) NULL,
	[INICIO] [datetime2](0) NULL,
	[FIN] [datetime2](0) NULL,
	[PROCESO_1] [decimal](10, 0) NULL,
	[PROCESO_2] [decimal](10, 0) NULL,
	[PROCESO_3] [decimal](10, 0) NULL,
	[PROCESO_4] [decimal](10, 0) NULL
) ON [PRIMARY]
GO

CREATE SEQUENCE EAI_OWNER.ProcessID AS bigint START WITH 1 INCREMENT BY 1;
GO
