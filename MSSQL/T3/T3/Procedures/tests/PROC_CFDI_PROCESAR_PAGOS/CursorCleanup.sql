SET NOCOUNT ON;
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
-- Falla controlada mientras ScrAsignaciones esta abierto: el acumulador
-- NUMERIC(16,4) no admite este importe, aunque el dato origen si lo admite.
INSERT T3.Asignacion_Pago(Asignacion_ID,Factura,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
VALUES('ERROR_CONTROLADO','F1','20180901 01:00:00','20180901',2000000000000);
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261022';
IF (SELECT COUNT(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)<>1
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE SIEBEL_ERROR_CODE='SQL-8115')
 THROW 52200,'La limpieza oculto o sustituyo el error controlado 8115.',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_cursors(@@SPID) WHERE name IN
 ('ScrPagos','ScrAsignaciones','ScrT3Procesado','ScrVentaUUID','ScrDebitNote','ScrCancPago'))
 THROW 52201,'Quedaron cursores declarados despues del error.',1;
DELETE T3.Asignacion_Pago WHERE Asignacion_ID='ERROR_CONTROLADO';
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261022';
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 OR (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>10 OR @@TRANCOUNT<>0
 THROW 52202,'No pudo ejecutarse otra vez despues del error controlado.',1;
PRINT 'PASS limpieza con cursor abierto: conserva 8115 y permite siguiente ejecucion sin fugas';
