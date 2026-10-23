SET NOCOUNT ON;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261014';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>6 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 THROW 52110,'La version DATE no selecciono las seis asignaciones elegibles.',1;
DECLARE @Esperado table(Asignacion_ID varchar(30),Importe_Factura decimal(16,2),
 Saldo_Anterior decimal(16,2),Numero_Pago decimal(10,0),Status varchar(20));
INSERT @Esperado VALUES
 ('262201996890',20723.95,20723.95,1,'Canc Pago'),
 ('262201997839',1049.57,1049.57,1,'INCOBRABLE'),
 ('262201996684',5688.53,5688.53,1,'INCOBRABLE'),
 ('262201996690',5688.53,4835.59,2,'INCOBRABLE'),
 ('262201997324',NULL,NULL,1,'INCOBRABLE'),
 ('262201997328',NULL,NULL,2,'INCOBRABLE');
IF EXISTS
 (SELECT Asignacion_ID,Importe_Factura,Saldo_Anterior,Numero_Pago,Status
  FROM T3.CFDI_Cobranza EXCEPT SELECT * FROM @Esperado)
 OR EXISTS
 (SELECT * FROM @Esperado EXCEPT
  SELECT Asignacion_ID,Importe_Factura,Saldo_Anterior,Numero_Pago,Status FROM T3.CFDI_Cobranza)
 THROW 52111,'Saldo, parcialidad o cancelacion de la muestra real incorrectos.',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Factura='CHD-33522' AND Fecha_Factura='20260929')
 OR EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Via_Pago NOT IN ('01','02'))
 OR @@TRANCOUNT<>0
 THROW 52112,'Fecha de cancelacion, via de pago o transaccion incorrectas.',1;
PRINT 'PASS DATE + cursores + reglas Oracle: seis filas, parcialidades calculadas y NULL sin detalle fiscal';
PRINT 'PASS CHD-33522: Canc Pago, importe 20723.95 y fecha de cancelacion recuperados';
PRINT 'CAMBIO ORACLE: V2363-145780 sin detalle fiscal produce importe/saldo NULL; no crear total cero';
SELECT 'LOCAL_DATE_CURSORES_CORREGIDOS' AS Escenario,Asignacion_ID,Factura,Importe,Importe_Factura,
 Saldo_Anterior,Numero_Pago,Status,UUID_Venta FROM T3.CFDI_Cobranza ORDER BY Factura,Asignacion_ID;
