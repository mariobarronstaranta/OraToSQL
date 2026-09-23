CREATE DATABASE CodexWebOrderTraceTest;
GO
USE CodexWebOrderTraceTest;
GO
ALTER DATABASE CodexWebOrderTraceTest SET COMPATIBILITY_LEVEL=160;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA EAI;
GO
CREATE SCHEMA T3;
GO
CREATE TABLE [EAI_OWNER].[WO_TMP_ORDER](
	[ENTITY_NAME] [varchar](512) NULL,
	[ROW_NAME] [varchar](512) NULL,
	[CREATEDDATE] [varchar](512) NULL,
	[IVYDSD__MOBILE_ORDER_NUMBER__C] [varchar](512) NULL,
	[RETAILER_PO_NUMBER__C] [varchar](512) NULL,
	[IVYDSD__ORDER_DATE__C] [varchar](512) NULL,
	[IVYDSD__DELIVERY_DATE__C] [varchar](512) NULL,
	[CUSTOMER_ID] [varchar](512) NULL,
	[IVYDSD__STORE__R] [varchar](512) NULL,
	[IVYDSD__STORE__R_NAME] [varchar](512) NULL,
	[IVYBAT__SAP_CUSTOMERID__C] [varchar](512) NULL,
	[IVYDSD__ORDER_STATUS__C] [varchar](512) NULL,
	[DELIVERY_STATUS__C] [varchar](512) NULL,
	[ORDER_AMOUNT__C] [varchar](512) NULL,
	[CREATEDBY] [varchar](512) NULL,
	[CREATEDBY_NAME] [varchar](512) NULL,
	[CREATEDBYID] [varchar](512) NULL
) ON [PRIMARY]
GO
CREATE TABLE [EAI_OWNER].[WO_TMP_INVOICE](
	[ENTITY_NAME] [varchar](512) NULL,
	[ROW_NAME] [varchar](512) NULL,
	[CREATEDDATE] [varchar](512) NULL,
	[MOBILE_INVOICE_NUMBER__C] [varchar](512) NULL,
	[SAP_INVOICE_NUMBER__C] [varchar](512) NULL,
	[IVYDSD__ORDER__R] [varchar](512) NULL,
	[IVYDSD__ORDER__R_NAME] [varchar](512) NULL,
	[ORDER_RETAILER_PO_NUMBER__C] [varchar](512) NULL,
	[MOBILE_ORDER_NUMBER__C] [varchar](512) NULL,
	[IVYDSD__INVOICE_DATE__C] [varchar](512) NULL,
	[CUSTOMER_ID] [varchar](512) NULL,
	[IVYDSD__STORE__R] [varchar](512) NULL,
	[IVYDSD__STORE__R_NAME] [varchar](512) NULL,
	[IVYBAT__SAP_CUSTOMERID__C] [varchar](512) NULL,
	[DELIVERY_STATUS__C] [varchar](512) NULL,
	[IVYDSD__INVOICE_STATUS__C] [varchar](512) NULL,
	[GROSS_AMOUNT__C] [varchar](512) NULL,
	[CREATEDBY] [varchar](512) NULL,
	[CREATEDBY_NAME] [varchar](512) NULL,
	[CREATEDBYID] [varchar](512) NULL,
	[INSERT_TS] [datetime2](0) NULL
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
CREATE TABLE [EAI].[TAO_CARTERA_SAP_LDR](
	[CLIENTE] [varchar](10) NULL,
	[TIPO_DOC] [varchar](2) NULL,
	[ASIGNACION] [varchar](1024) NULL,
	[FECHA_DOC] [varchar](8) NULL,
	[MONTO] [varchar](20) NULL,
	[MONTO_AUX] [varchar](20) NULL,
	[MONEDA] [varchar](20) NULL,
	[DIAS_CDTO] [varchar](4) NULL,
	[REFERENCIA] [varchar](30) NULL,
	[CARGO] [varchar](1) NULL,
	[ACCOUNTDOCUMENT] [varchar](10) NULL,
	[BRANCH_NUMBER] [varchar](10) NULL
) ON [PRIMARY]
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
CREATE TABLE [T3].[PREVENTA_DETALLE](
	[FACTURA] [varchar](30) NULL,
	[PREFIJO] [varchar](3) NULL,
	[NUM_LINEA] [decimal](4, 0) NULL,
	[MATERIAL] [varchar](18) NULL,
	[CANTIDAD_VTA] [decimal](10, 0) NULL,
	[UNIDAD_MED_VTA] [varchar](3) NULL,
	[STATUS_PROD] [char](1) NULL,
	[VALOR_SUBT] [decimal](15, 2) NULL,
	[VALOR_IVA] [decimal](15, 2) NULL,
	[REFERENCIA_PEDIDO] [varchar](12) NULL,
	[VALOR_ISSA] [decimal](15, 2) NULL,
	[BONIF_SUBT] [decimal](15, 2) NULL,
	[BONIF_IVA] [decimal](15, 2) NULL,
	[BONIF_PORC] [decimal](5, 2) NULL,
	[BONIF_VOL] [decimal](10, 0) NULL,
	[ENVIO_SUBT] [decimal](15, 2) NULL,
	[ENVIO_IVA] [decimal](15, 2) NULL,
	[ENVIO_PORC] [decimal](5, 2) NULL,
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
CREATE TABLE [T3].[FACTURA_DETALLE](
	[FACTURA] [varchar](30) NULL,
	[NUM_LINEA] [decimal](4, 0) NULL,
	[MATERIAL] [varchar](18) NULL,
	[CANTIDAD_VTA] [decimal](10, 0) NULL,
	[STATUS_PROD] [char](1) NULL,
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
	[UNIDAD_MED_VTA] [varchar](3) NULL,
	[CREDITO_SUBT] [decimal](15, 2) NULL,
	[CREDITO_IVA] [decimal](15, 2) NULL
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
CREATE OR ALTER FUNCTION [EAI_OWNER].[GET_CLEARING_STATUS]
(
    @pInvoice    VARCHAR(50),
    @pCreditNote VARCHAR(50),
    @pAmount     DECIMAL(15,2)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE
        @sReturn     VARCHAR(50) = '',
        @sInvoice    VARCHAR(50) = ISNULL(@pInvoice, 'NONE'),
        @sCreditNote VARCHAR(50) = ISNULL(@pCreditNote, 'NONE'),
        @nAmount     DECIMAL(15,2) = ISNULL(@pAmount, 0),
        @nInvoiceAmt DECIMAL(15,2) = 0,
        @nCreditAmt  DECIMAL(15,2) = 0;

    IF LEN(@sCreditNote) < 3
        SET @sCreditNote = 'NONE';

    SELECT
        @nInvoiceAmt = ISNULL(SUM(ISNULL(Cobza.Importe, 0)), 0),
        @nCreditAmt = ISNULL(SUM(CASE
                                    WHEN ISNULL(Cobza.Nota_Credito, 'EMPTY') = @sCreditNote
                                        THEN ISNULL(Cobza.Importe, 0)
                                    ELSE 0
                                 END), 0)
    FROM [T3].[CFDI_Cobranza] AS Cobza
    WHERE Cobza.Factura = @sInvoice;

    IF @nAmount > 0 AND @nInvoiceAmt > 0
    BEGIN
        IF ABS(@nAmount - @nInvoiceAmt) < 0.50 AND @sCreditNote = 'NONE'
            SET @sReturn = 'Comp-Ok';
        ELSE IF ABS(@nAmount - @nInvoiceAmt) < 0.50
             AND ABS(@nCreditAmt - @nInvoiceAmt) < 0.50
            SET @sReturn = 'Comp-Inv-ZLOB';
        ELSE IF @sCreditNote <> 'NONE'
        BEGIN
            SELECT
                @nCreditAmt = ISNULL(SUM(ISNULL(Cobza.Importe, 0)), 0)
            FROM [T3].[CFDI_Cobranza] AS Cobza
            WHERE Cobza.Nota_Credito = @sCreditNote;

            IF ABS(@nAmount - @nInvoiceAmt) < 0.50
               AND ABS(@nAmount - @nCreditAmt) < 0.50
                SET @sReturn = 'Inv-Ok-ZLOB-Ok';
            ELSE IF ABS(@nAmount - @nCreditAmt) < 0.50
                SET @sReturn = 'ZLOB-Ok';
            ELSE IF ABS(@nAmount - @nInvoiceAmt) < 0.50
                SET @sReturn = 'Inv-Ok';
        END;
    END;

    RETURN @sReturn;
END;
GO
