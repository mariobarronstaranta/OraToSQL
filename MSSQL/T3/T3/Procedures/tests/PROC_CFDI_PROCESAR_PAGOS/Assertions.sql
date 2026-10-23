SET NOCOUNT ON;
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE T3.RF_PROCESOS_LOG;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
DECLARE @Parametro datetime='20261022 15:37:42',@Fallos int=0;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS @Parametro;
-- No basta con que EXEC regrese sin excepcion: el CATCH puede ocultarla.
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
BEGIN
 SELECT QUEUE_NAME,SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG;
 THROW 52000,'El procedimiento o una dependencia registraron errores.',1;
END;
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>10
BEGIN
 SELECT Asignacion_ID,Factura,Status FROM T3.CFDI_Cobranza;
 THROW 52001,'Cantidad de asignaciones incorrecta; se esperaban 10.',1;
END;
IF EXISTS(SELECT Asignacion_ID FROM T3.CFDI_Cobranza GROUP BY Asignacion_ID HAVING COUNT(*)<>1)
 THROW 52002,'Asignacion duplicada.',1;
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID NOT IN
 ('A1','A2','A3','A4','A5','A6','A7','A8','A9','A10'))
 THROW 52003,'Incluyo una asignacion fuera de lote/vigencia.',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A2' AND Fecha_Asignacion='20261022 23:59:59')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A3' AND Fecha_Asignacion='20261022 01:00:00')
 THROW 52004,'No incluyo dias completos de fin/inicio de vigencia.',1;
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Fecha_Proc_BATMD<>@Parametro)
 THROW 52005,'Alteracion del valor BATMD almacenado.',1;
PRINT 'PASS BATMD con hora, inicio/fin de vigencia, exclusiones y horas originales';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A1'
 AND Saldo_Anterior=1010 AND Numero_Pago=2 AND Cant_Pagos=1 AND Abono_Pagos=100 AND Cant_CM=1 AND Abono_CM=50)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A2'
 AND Saldo_Anterior=810 AND Numero_Pago=3 AND Cant_Pagos=2 AND Abono_Pagos=300 AND Cant_CM=1 AND Abono_CM=50)
BEGIN
 SELECT Asignacion_ID,Importe_Factura,Saldo_Anterior,Numero_Pago,Cant_Pagos,Abono_Pagos,Cant_CM,Abono_CM
 FROM T3.CFDI_Cobranza WHERE Asignacion_ID IN ('A1','A2');
 SET @Fallos+=1;
 PRINT 'FAIL saldo y parcialidad: historial no recuperado por el cursor';
END;
IF @Fallos=0 PRINT 'PASS historial desde 2018-09-01, pago anterior, CM y parcialidades';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A1'
 AND UUID_Venta='UUID-F1' AND Importe_Factura=1160 AND Tasa_IVA=16 AND Via_Pago='03')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A9'
 AND UUID_Venta='UUID-PREV' AND Referencia='REFPREV' AND Importe_Factura=1160)
BEGIN SET @Fallos+=1; PRINT 'FAIL factura/preventa: documento o UUID no recuperados'; END;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A5' AND Status='PendienteT3' AND Tasa_IVA=0)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A10' AND Status='PendienteT3')
 THROW 52008,'Ruta sin detalle o centinela 2999 incorrecta.',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A6' AND Status='DN - Penalizacion' AND UUID_Venta='UUID-DN')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A7' AND Status='Canc Pago'
 AND Importe_Factura=800 AND Fecha_Factura='20261002')
BEGIN SET @Fallos+=1; PRINT 'FAIL penalizacion/cancelacion: documento no recuperado'; END;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A8' AND Via_Pago='AI' AND Nota_Credito='NC-INC')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A4' AND Fecha_Envio=@Parametro)
 THROW 52010,'Ruta incobrable o RFC generico incorrecta.',1;
PRINT 'PASS rutas PendienteT3, incobrable y RFC generico';
IF (SELECT COUNT(*) FROM T3.RF_PROCESOS_LOG WHERE Fin IS NOT NULL)<>2
 OR NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=604 AND Proceso_1=10)
 OR NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=889)
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_COMPONENTS WHERE Status<>1)
 OR @@TRANCOUNT<>0
 THROW 52011,'No completo bitacoras, control posterior o transaccion.',1;
PRINT 'PASS sin errores registrados; cierre de procesos 604/889 y transacciones';
-- Parametro NULL y dia sin asignaciones: ejecuciones validas sin datos de salida.
TRUNCATE TABLE T3.CFDI_Cobranza;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS NULL;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261101';
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza) OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG) OR @@TRANCOUNT<>0
 THROW 52012,'Fallo lote vacio o parametro NULL.',1;
PRINT 'PASS lote vacio y parametro NULL sin errores';

IF @Fallos>0 THROW 52013,'Fallo funcional: cursores declarados antes de asignar sus filtros; revisar evidencia.',1;
