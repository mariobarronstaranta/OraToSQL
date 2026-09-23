-- Esquema minimo para pruebas aisladas. No ejecutar en T3QA.
CREATE SCHEMA EAI;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA T3;
GO
CREATE SEQUENCE EAI_OWNER.ProcessID AS BIGINT START WITH 1;
CREATE TABLE EAI_OWNER.MX_COMPONENTS (Component int, Status int);
INSERT EAI_OWNER.MX_COMPONENTS VALUES (922,1);
CREATE TABLE T3.RF_PROCESOS_LOG
(PID int, Proceso int, Fecha_Proc_BATMD datetime2, Inicio datetime2, Fin datetime2,
 Proceso_1 int, Proceso_2 int, Proceso_3 int, Proceso_4 int);
CREATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG
(DIRECTION varchar(50), REFERENCE varchar(50), CREATED datetime2, MESSAGE varchar(max),
 JOB_PID int, STATUS varchar(30), QUEUE_NAME varchar(50), SIEBEL_ERROR_MESSAGE varchar(250),
 SOURCE varchar(30), SIEBEL_ERROR_CODE varchar(30), RETRY_COUNT int, SEQUENCE int, PARENT_ROW_ID varchar(50));
CREATE TABLE EAI.CFDI_UUID_NOTA_CREDITO
(Ctro varchar(4), Fecha_Venta datetime2, Nota_Venta varchar(20), RFC varchar(15), Cliente_SAP varchar(10),
 Importe_Vta decimal(15,2), Saldo_SAP decimal(15,2), Folio_Fiscal varchar(50),
 Aplica_NC int, Importe_NC decimal(15,2), Fecha_Aplicacion datetime2, Incobrable decimal(15,2));
CREATE TABLE T3.Factura_General
(Ctro varchar(4), Fecha_Factura datetime2, Factura varchar(20), Cliente_SAP varchar(10), Tipo_Docto varchar(4));
CREATE TABLE T3.Factura_Detalle
(Factura varchar(20), Material varchar(10), Valor_Subt decimal(15,2), Valor_IVA decimal(15,2),
 Envio_Subt decimal(15,2), Envio_IVA decimal(15,2));
CREATE TABLE T3.Preventa_General
(Ctro varchar(4), Fecha_Factura datetime2, Factura varchar(20), Cliente_SAP varchar(10), Clase_Factura varchar(4),
 Fecha_Proc_BATMD datetime2, Fecha_Cancelacion datetime2);
CREATE TABLE T3.Preventa_Detalle
(Factura varchar(20), Material varchar(10), Valor_Subt decimal(15,2), Valor_IVA decimal(15,2),
 Envio_Subt decimal(15,2), Envio_IVA decimal(15,2));
CREATE TABLE T3.Cliente (Cliente_SAP varchar(10), RFC varchar(15), Fecha_Ini_Vig datetime2, Fecha_Fin_Vig datetime2);
CREATE TABLE EAI.T3R_Cartera_SAP_OLD (Referencia varchar(20), Cliente varchar(10), Fecha_Doc datetime2, Monto decimal(15,2));
CREATE TABLE T3.CFDI_Documentos (Nota_Venta varchar(20), Folio_Fiscal varchar(50));
CREATE TABLE T3.CFDI_Cobranza
(Nota_Credito varchar(20), Asignacion_ID varchar(20), Importe decimal(15,2), Fecha_Asignacion datetime2, Via_Pago varchar(2));
GO
-- Simula unicamente el cambio de estado de la dependencia LOG_START.
CREATE PROCEDURE EAI_OWNER.Log_Start @nComponent int AS
UPDATE EAI_OWNER.MX_COMPONENTS SET Status=0 WHERE Component=@nComponent;
GO
INSERT T3.Cliente VALUES ('C1','RFC_TEST','20230101','20300101');
INSERT T3.Factura_General VALUES ('MX01','20260901','NC1','C1','C004');
INSERT T3.Factura_Detalle VALUES ('NC1','10001',100,16,0,0);
INSERT T3.Preventa_General VALUES ('MX01','20260901','NC2','C1','C006','20260901',NULL);
INSERT T3.Preventa_Detalle VALUES ('NC2','10001',200,32,0,0);
INSERT EAI.T3R_Cartera_SAP_OLD VALUES ('NC1','C1','20260901',-40);
INSERT T3.CFDI_Documentos VALUES ('NC1','UUID_TEST');
INSERT T3.CFDI_Cobranza VALUES ('NC1','A1',20,'20260902','CM'),('NC1','A2',10,'20260903','AI');
GO
