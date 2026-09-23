-- Exclusivo para LocalDB de pruebas. No ejecutar en T3QA.
CREATE DATABASE CodexVentasMigrationTest;
GO
USE CodexVentasMigrationTest;
GO
ALTER DATABASE CodexVentasMigrationTest SET COMPATIBILITY_LEVEL=160;
GO
CREATE SCHEMA T3;
GO
CREATE TABLE [T3].[REGISTRO_FISCAL](
	[FACTURA] [varchar](30) NULL,
	[DISTRIBUIDOR] [decimal](4, 0) NULL,
	[PEDIDO] [varchar](30) NULL,
	[FECHA_FACTURA] [datetime2](0) NULL,
	[TIPO_DOCTO] [varchar](4) NULL,
	[CLIENTE_V3] [varchar](15) NULL,
	[CLIENTE_SAP] [varchar](10) NULL,
	[STATUS] [varchar](15) NULL,
	[CLTE_FACTURA_V3] [varchar](15) NULL,
	[CLTE_FACTURA_SAP] [varchar](10) NULL,
	[FECHA_TRN] [datetime2](0) NULL,
	[VALOR_SUBTOTAL] [decimal](15, 2) NULL,
	[VALOR_DESCTO] [decimal](15, 2) NULL,
	[VALOR_IVA] [decimal](15, 2) NULL,
	[TIPO_VENTA] [varchar](2) NULL,
	[DESGLOSE_IVA] [char](1) NULL,
	[REFERENCIA] [varchar](30) NULL,
	[ENTREGA] [varchar](10) NULL,
	[FECHA_PAGO] [datetime2](0) NULL,
	[ROW_ID] [varchar](15) NULL,
	[REP_ID] [varchar](10) NULL,
	[CREDITO_EXPRESS] [varchar](20) NULL,
	[VALOR_ISSA] [decimal](15, 2) NULL,
	[CTRO] [varchar](4) NULL,
	[BONIF_SUBT] [decimal](15, 2) NULL,
	[BONIF_IVA] [decimal](15, 2) NULL,
	[BONIF_PORC] [decimal](5, 2) NULL,
	[BONIF_VOL] [decimal](10, 0) NULL,
	[FECHA_DOCUMENTO] [datetime2](0) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[REGISTRO_FISCAL_DETALLE](
	[FACTURA] [varchar](30) NULL,
	[NUM_LINEA] [decimal](4, 0) NULL,
	[MATERIAL] [varchar](18) NULL,
	[REFERENCIA_PEDIDO] [varchar](12) NULL,
	[CANTIDAD_VTA] [decimal](10, 0) NULL,
	[UNIDAD_MED_VTA] [varchar](3) NULL,
	[PRECIO_UNIT] [decimal](15, 2) NULL,
	[VALOR_SUBT] [decimal](15, 2) NULL,
	[VALOR_TOT] [decimal](15, 2) NULL,
	[VALOR_DESC] [decimal](15, 2) NULL,
	[VALOR_IVA] [decimal](15, 2) NULL,
	[VALOR_ISSA] [decimal](15, 2) NULL,
	[BONIF_SUBT] [decimal](15, 2) NULL,
	[BONIF_IVA] [decimal](15, 2) NULL,
	[BONIF_PORC] [decimal](5, 2) NULL,
	[BONIF_VOL] [decimal](10, 0) NULL,
	[ENVIO_SUBT] [decimal](15, 2) NULL,
	[ENVIO_IVA] [decimal](15, 2) NULL,
	[ENVIO_PORC] [decimal](5, 2) NULL,
	[VALOR_IEPS] [decimal](15, 2) NULL,
	[CREDITO_SUBT] [decimal](15, 2) NULL,
	[CREDITO_IVA] [decimal](15, 2) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[CLIENTE](
	[CLIENTE_V3] [varchar](20) NULL,
	[NOMBRE] [varchar](100) NULL,
	[FECHA_INI_VIG] [datetime2](0) NULL,
	[FECHA_FIN_VIG] [datetime2](0) NULL,
	[STATUS_CLTE] [bit] NULL,
	[CLASE_CLTE] [varchar](10) NULL,
	[ALIAS] [varchar](100) NULL,
	[CLIENTE_SAP] [varchar](10) NULL,
	[CLTE_FACTURA_SAP] [varchar](10) NULL,
	[CLTE_ENT_SAP] [varchar](10) NULL,
	[METODO_PAGO] [char](1) NULL,
	[REGIMEN_FISCAL] [bit] NULL,
	[RFC] [varchar](35) NULL,
	[DIAS_CDTO] [varchar](4) NULL,
	[LISTA_PRECIO] [varchar](50) NULL,
	[DIST_VENTA] [decimal](4, 0) NULL,
	[DIST_COBZA] [decimal](4, 0) NULL,
	[AREA_MGR] [varchar](3) NULL,
	[REGION_ID] [varchar](4) NULL,
	[FECHA_SYNCR] [datetime2](0) NULL,
	[LIMITE_CDTO] [decimal](15, 2) NULL,
	[CANAL] [varchar](2) NULL,
	[TIPO_CLTE] [varchar](30) NULL,
	[SUBTIPO_CLTE] [varchar](30) NULL,
	[TERRITORIO] [varchar](75) NULL,
	[TIPO_TERRITORIO] [varchar](30) NULL,
	[LISTA_IVA] [varchar](50) NULL,
	[FAX] [varchar](30) NULL,
	[TELEFONO] [varchar](30) NULL,
	[DIRECCION_1] [varchar](200) NULL,
	[COLONIA_1] [varchar](50) NULL,
	[ID_DIRECCION_1] [varchar](15) NULL,
	[CIUDAD_1] [varchar](50) NULL,
	[ESTADO_1] [varchar](35) NULL,
	[CODIGO_POSTAL_1] [varchar](35) NULL,
	[PAIS_1] [varchar](2) NULL,
	[TIPO_DIRECCION_1] [varchar](10) NULL,
	[DIRECCION_2] [varchar](200) NULL,
	[COLONIA_2] [varchar](50) NULL,
	[ID_DIRECCION_2] [varchar](15) NULL,
	[CIUDAD_2] [varchar](50) NULL,
	[ESTADO_2] [varchar](35) NULL,
	[CODIGO_POSTAL_2] [varchar](35) NULL,
	[PAIS_2] [varchar](2) NULL,
	[TIPO_DIRECCION_2] [varchar](10) NULL,
	[DIRECCION_3] [varchar](200) NULL,
	[COLONIA_3] [varchar](50) NULL,
	[ID_DIRECCION_3] [varchar](15) NULL,
	[CIUDAD_3] [varchar](50) NULL,
	[ESTADO_3] [varchar](35) NULL,
	[CODIGO_POSTAL_3] [varchar](35) NULL,
	[PAIS_3] [varchar](2) NULL,
	[TIPO_DIRECCION_3] [varchar](10) NULL,
	[SUCURSAL_CLTE] [varchar](25) NULL,
	[CTRO] [varchar](4) NULL,
	[CTRO_COBZA] [varchar](4) NULL,
	[CLABE_BANCARIA] [varchar](20) NULL,
	[SIEBEL_LOC] [varchar](30) NULL,
	[PAYER] [varchar](30) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[CFDI_HISTORIA_DOCTO_PAC](
	[NOTA_VENTA] [varchar](30) NULL,
	[CTRO] [varchar](4) NULL,
	[FECHA_FACTURA] [datetime2](0) NULL,
	[NOTA_VENTA_CFDI] [varchar](30) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[CFDI_DOCUMENTOS](
	[NOTA_VENTA] [varchar](30) NULL,
	[CTRO] [varchar](4) NULL,
	[FECHA_LIBERACION] [datetime2](0) NULL,
	[FECHA_ENVIO] [datetime2](0) NULL,
	[FECHA_CONFIRMACION] [datetime2](0) NULL,
	[FOLIO_FISCAL] [varchar](40) NULL,
	[FECHA_TIMBRE] [datetime2](0) NULL,
	[FECHA_CFD] [datetime2](0) NULL,
	[ID_ENVIO] [varchar](25) NULL,
	[ID_CONFIRMACION] [varchar](25) NULL,
	[STATUS] [varchar](25) NULL,
	[VALOR_SUBT] [decimal](20, 2) NULL,
	[VALOR_IVA] [decimal](20, 2) NULL,
	[METODO_PAGO] [varchar](5) NULL,
	[FECHA_DOCUMENTO] [datetime2](0) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[CFDI_DOCUMENTO_PASO](
	[FACTURA] [varchar](30) NULL,
	[CTRO] [varchar](4) NULL,
	[FECHA_FACTURA_T3] [datetime2](0) NULL,
	[FECHA_FACTURA_V3] [datetime2](0) NULL,
	[TIPO_DOCTO] [varchar](4) NULL,
	[UBICACION] [varchar](20) NULL,
	[RFC_FACTURA] [varchar](15) NULL,
	[RFC_CLIENTE] [varchar](15) NULL,
	[LISTA_PRECIO] [varchar](2) NULL,
	[CLIENTE_AGRUPADO] [varchar](10) NULL,
	[FECHA_PROC_BATMD] [datetime2](0) NULL,
	[VOIDDOC] [varchar](2) NULL
) ON [PRIMARY]
GO
CREATE TABLE [T3].[CFDI_COBRANZA](
	[FOLIO_ID] [varchar](30) NULL,
	[ASIGNACION_ID] [varchar](30) NULL,
	[FECHA_ASIGNACION] [datetime2](0) NULL,
	[IMPORTE] [decimal](16, 2) NULL,
	[SALDO_ANTERIOR] [decimal](16, 2) NULL,
	[NUMERO_PAGO] [decimal](10, 0) NULL,
	[ACCNT_ID] [varchar](30) NULL,
	[FACTURA] [varchar](30) NULL,
	[NOTA_VENTA] [varchar](30) NULL,
	[RFC] [varchar](15) NULL,
	[FECHA_PROC_BATMD] [datetime2](0) NULL,
	[FECHA_PROCESO] [datetime2](0) NULL,
	[STATUS] [varchar](20) NULL,
	[VIA_PAGO] [varchar](4) NULL,
	[CANT_PAGOS] [decimal](10, 0) NULL,
	[ABONO_PAGOS] [decimal](16, 2) NULL,
	[CANT_CM] [decimal](10, 0) NULL,
	[ABONO_CM] [decimal](16, 2) NULL,
	[NOTA_CREDITO] [varchar](30) NULL,
	[UUID_VENTA] [varchar](40) NULL,
	[FECHA_FACTURA] [datetime2](0) NULL,
	[DIAS_CDTO] [decimal](3, 0) NULL,
	[IMPORTE_FACTURA] [decimal](16, 2) NULL,
	[PID] [decimal](10, 0) NULL,
	[CREATED_BY] [varchar](30) NULL,
	[PAGO_ID] [varchar](30) NULL,
	[FECHA_PAGO] [datetime2](0) NULL,
	[SOCIEDAD] [varchar](4) NULL,
	[CTRO] [varchar](4) NULL,
	[DB_LAST_UPD] [datetime2](0) NULL,
	[BANCO_NOMBRE] [varchar](30) NULL,
	[BANCO_NUM_CUENTA] [varchar](20) NULL,
	[NUMERO_CHEQUE] [varchar](20) NULL,
	[MASTER_BANCO] [varchar](30) NULL,
	[MASTER_CUENTA] [varchar](20) NULL,
	[RECEPTOR_BANCO] [varchar](30) NULL,
	[RECEPTOR_CUENTA] [varchar](30) NULL,
	[FECHA_ENVIO] [datetime2](0) NULL,
	[TASA_IVA] [decimal](6, 2) NULL,
	[REFERENCIA] [varchar](30) NULL,
	[ASIGNACION_CENTRAL] [varchar](30) NULL,
	[CLIENTE_SAP] [varchar](10) NULL
) ON [PRIMARY]
GO
SET NOCOUNT ON;
IF DB_NAME()<>'CodexVentasMigrationTest' THROW 52000,'Base de prueba incorrecta.',1;
INSERT T3.CLIENTE(CLIENTE_SAP,NOMBRE,RFC,FECHA_INI_VIG,FECHA_FIN_VIG)
VALUES('C001',N'Compañía, "QA"','RFC001','20000101','21000101');
DECLARE @periods TABLE(Tag varchar(2),StartDate date);
INSERT @periods VALUES('A','20260201'),('F','20241001'),('G','20260701');
INSERT T3.REGISTRO_FISCAL(FACTURA,FECHA_FACTURA,FECHA_DOCUMENTO,TIPO_DOCTO,CLIENTE_SAP,STATUS,ENTREGA)
SELECT Tag+V.Code,
 CASE WHEN V.Code='D' THEN DATEADD(day,-1,StartDate) WHEN V.Code='E' THEN DATEADD(month,1,StartDate) ELSE StartDate END,
 CASE WHEN V.Code IN('F','E') THEN DATEADD(month,1,StartDate) ELSE StartDate END,
 V.Tipo,CASE WHEN V.Code='N' THEN 'MISSING' ELSE 'C001' END,
 CASE WHEN V.Code='C' THEN 'Cancelled' ELSE 'Active' END,Tag+V.Code
FROM @periods CROSS JOIN (VALUES('S','C003'),('R','C004'),('X','C0FX'),('C','C003'),('E','C003'),('N','C003'),('D','C003'),('F','C003')) V(Code,Tipo);
INSERT T3.REGISTRO_FISCAL_DETALLE(FACTURA,VALOR_SUBT,VALOR_IVA,ENVIO_SUBT,ENVIO_IVA,CREDITO_SUBT,CREDITO_IVA,BONIF_SUBT,BONIF_IVA)
SELECT FACTURA,100,16,10,1.60,2,0.32,5,0.8 FROM T3.REGISTRO_FISCAL;
INSERT T3.CFDI_HISTORIA_DOCTO_PAC(NOTA_VENTA,NOTA_VENTA_CFDI)
SELECT Tag+'S',Tag+'CFDI' FROM @periods;
INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,FECHA_ENVIO,FECHA_TIMBRE,FECHA_DOCUMENTO,FOLIO_FISCAL)
SELECT Tag+'CFDI',StartDate,StartDate,DATEADD(day,2,StartDate),N'UUID,"QA"'+CHAR(13)+CHAR(10)+'line2' FROM @periods;
INSERT T3.CFDI_DOCUMENTO_PASO(FACTURA,VOIDDOC)
SELECT Tag+'S',V.Flag FROM @periods CROSS JOIN (VALUES('Y'),('N')) V(Flag);
INSERT T3.CFDI_COBRANZA(FACTURA,NOTA_CREDITO,IMPORTE,VIA_PAGO,FECHA_FACTURA)
SELECT 'INCOBRABLE',Tag+'S',40,'AI','20200101' FROM @periods;
