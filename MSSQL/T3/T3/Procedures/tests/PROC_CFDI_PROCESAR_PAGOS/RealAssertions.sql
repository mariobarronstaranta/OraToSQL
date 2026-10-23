SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM T3.Asignacion_Pago)<>10
 OR (SELECT COUNT(DISTINCT Factura) FROM T3.Asignacion_Pago)<>8
 OR EXISTS(SELECT 1 FROM T3.Registro_Fiscal)
 THROW 52100,'Muestra distinta a la captura del 14/10/2026.',1;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261014';
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza) OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 THROW 52101,'La version instalada debia excluir el lote con parametro a medianoche.',1;
PRINT 'PASS REPRODUCCION instalado + 2026-10-14 00:00:00: cero filas sin excepcion';
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '2026-10-14T13:27:28';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>6
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 THROW 52102,'No se reprodujeron las seis asignaciones elegibles de la muestra.',1;
SELECT Asignacion_ID,Factura,Importe,Importe_Factura,Saldo_Anterior,Numero_Pago,Status,UUID_Venta
INTO dbo.InstaladoExacto FROM T3.CFDI_Cobranza;
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Saldo_Anterior IS NOT NULL OR Numero_Pago IS NOT NULL)
 THROW 52103,'Cambio el fallo de enlace de cursores esperado.',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Factura='CHD-33522' AND Status='INCOBRABLE'
 AND Importe_Factura=0 AND Saldo_Anterior IS NULL)
 THROW 52104,'No se reprodujo la cancelacion no recuperada por el cursor.',1;
PRINT 'PASS REPRODUCCION instalado + hora exacta: seis filas, seis saldos/parcialidades NULL';
PRINT 'PASS REPRODUCCION CHD-33522: INCOBRABLE e importe factura 0 pese a existir cancelacion por 20723.95';
SELECT 'INSTALADO_HORA_EXACTA' AS Escenario,* FROM dbo.InstaladoExacto ORDER BY Factura,Asignacion_ID;
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE T3.RF_PROCESOS_LOG;
