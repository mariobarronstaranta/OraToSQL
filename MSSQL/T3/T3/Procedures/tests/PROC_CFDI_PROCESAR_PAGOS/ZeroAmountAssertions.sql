/* Compatibilidad del procedimiento vigente con una base cero.
   No modifica reglas ni sustituye funciones: ejecuta los fuentes completos.
   Solo para la base desechable de Run.ps1 -ValidarCero. */
SET NOCOUNT ON;
IF DB_NAME() NOT LIKE 'CodexPagosDate[_]%'
 THROW 52600,'Solo permite la base sintetica desechable.',1;
SELECT 'AMBIENTE' AS Seccion,GETDATE() AS Fecha,@@VERSION AS VersionSQL;

INSERT T3.CLIENTE(Cliente_SAP,RFC,Dias_Cdto,Fecha_Ini_Vig,Fecha_Fin_Vig)
VALUES('CZERO','AAA010101AAA','30','20261001','20261031'),
 ('CSAT','BBB010101BBB','30','20261001','20261031');
INSERT EAI_OWNER.MX_HashTable([Type],[Source],[Target])
VALUES('SAT Amount Invoice','BBB010101BBB','2');
INSERT T3.REGISTRO_FISCAL_DETALLE(Factura,Valor_Subt,Valor_IVA)
VALUES('ZERO',0,0),('ZERO_SAT',0,0),('V_ZERO',0,0);
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Valor_Subt,Valor_IVA)
VALUES('ZERO_SAT',300,48);
INSERT T3.TIPO_DOCUMENTO(Tipo_Documento,Origen) VALUES('V','Nota de Venta');
INSERT T3.REGISTRO_FISCAL(Factura,Tipo_Docto) VALUES('V_ZERO','V');
INSERT T3.FACTURA_GENERAL(Factura,Fecha_Proc_BATMD) VALUES('V_ZERO','20261024');
INSERT T3.FACTURA_DETALLE(Factura,Valor_Subt,Valor_IVA) VALUES('V_ZERO',0,0);
INSERT T3.ASIGNACION_PAGO
 (Asignacion_ID,Pago_ID,Factura,Cliente_SAP,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
VALUES('Z_PREV','P_PREV','ZERO','CZERO','20261023','20261023',100),
 ('Z_NOW','P_NOW','ZERO','CZERO','20261024','20261024',50),
 ('S_NOW','P_SAT','ZERO_SAT','CSAT','20261024','20261024',10),
 ('N_NOW','P_ABS','ABSENT','CZERO','20261024','20261024',10),
 ('V_NOW','P_VTA','V_ZERO','CZERO','20261024','20261024',10);
INSERT T3.PAGO(Pago_ID,Tipo_Pago,Metodo_Pago)
SELECT Pago_ID,'Payment','T' FROM T3.ASIGNACION_PAGO;

IF T3.FN_TOTAL_FACT('ZERO') IS NULL OR T3.FN_TOTAL_FACT('ZERO')<>0
 OR T3.FN_TOTAL_FACT('ABSENT') IS NULL OR T3.FN_TOTAL_FACT('ABSENT')<>0
 THROW 52601,'FN_TOTAL_FACT SQL no conserva su retorno cero.',1;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261024';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>4
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 OR @@TRANCOUNT<>0
 THROW 52602,'La ejecucion con base cero genero errores o no completo cuatro filas.',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='Z_NOW'
 AND Importe_Factura=0 AND Saldo_Anterior=-100 AND Numero_Pago=2
 AND Cant_Pagos=1 AND Abono_Pagos=100 AND Importe=50)
 THROW 52603,'Base cero con historial no conserva saldo/parcialidad esperados.',1;
PRINT 'PASS base cero con pago previo: importe factura 0, saldo anterior -100, parcialidad 2, sin error';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='S_NOW'
 AND Importe_Factura=348 AND Saldo_Anterior=348 AND Numero_Pago=1)
 THROW 52604,'La regla SAT no sustituye base cero cuando corresponde.',1;
PRINT 'PASS regla SAT activa puede sustituir una base cero por 348';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='V_NOW'
 AND Importe_Factura=0 AND Saldo_Anterior=0 AND Tasa_IVA=0 AND Numero_Pago=1)
 THROW 52605,'Venta T3 cero no conserva importe/tasa o provoca division por cero.',1;
PRINT 'PASS venta T3 cero: importe/saldo/tasa 0, sin division por cero';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='N_NOW'
 AND Importe_Factura IS NULL AND Saldo_Anterior IS NULL AND Numero_Pago=1)
 THROW 52606,'La suma local actual ya no conserva NULL sin detalle.',1;
PRINT 'PASS diferencia vigente: FN_TOTAL_FACT sin detalle devuelve 0, pero PAGOS usa suma local y conserva NULL';
SELECT Asignacion_ID,Factura,Importe_Factura,Saldo_Anterior,Numero_Pago,Tasa_IVA,
 T3.FN_TOTAL_FACT(Factura) AS RetornoFuncionCompartida
FROM T3.CFDI_Cobranza ORDER BY Asignacion_ID;
PRINT 'PASS compatibilidad con cero comprobada en LocalDB; no se modifico ningun procedimiento ni base real';
