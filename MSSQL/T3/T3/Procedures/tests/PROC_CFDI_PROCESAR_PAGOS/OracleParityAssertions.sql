/* Expectativas derivadas de Oracle, ejecutadas sobre los fuentes completos SQL.
   No es una ejecucion del motor Oracle. Solo base desechable de Run.ps1. */
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF DB_NAME() NOT LIKE 'CodexPagosDate[_]%'
 THROW 52500,'Solo permite la base sintetica desechable.',1;
SELECT 'AMBIENTE' AS Seccion,GETDATE() AS Fecha,@@VERSION AS VersionSQL;

CREATE TABLE #Casos(Caso char(2) COLLATE DATABASE_DEFAULT,Config varchar(99) COLLATE DATABASE_DEFAULT,HayConfig bit,HayDetalle bit,
 Base decimal(15,2),SAT decimal(20,2),IVA decimal(20,2),Esperado decimal(16,2));
INSERT #Casos VALUES
 ('01','2',1,1,100,175,25,200), -- activo
 ('02','1',1,1,100,175,25,100), -- umbral estricto >1
 ('03',NULL,0,1,100,175,25,100),-- sin catalogo
 ('04','0',1,1,100,175,25,100),
 ('05',NULL,1,1,100,175,25,100),-- Target NULL
 ('06','',1,1,100,175,25,100),  -- Target vacio Oracle NULL
 ('07','-1',1,1,100,175,25,100),
 ('08','2',1,1,100,0,0,100),
 ('09','2',1,1,100,-20,0,100),
 ('10','2',1,1,100,NULL,NULL,100),
 ('11',NULL,0,0,NULL,NULL,NULL,NULL), -- sin detalle: NULL
 ('12',NULL,0,1,NULL,NULL,NULL,0),    -- detalle con componentes NULL: cero
 ('13','2',1,0,NULL,175,25,200),      -- SAT sustituye NULL
 ('14','1.5',1,1,100,175,25,200),     -- NUMBER(4) redondea a 2
 ('15','2',1,1,100,175,25,200),       -- MAX textual frente a 10000
 ('16',NULL,0,1,100,NULL,NULL,100),
 ('17','2',1,1,100,NULL,25,25),
 ('18','2',1,1,100,175,NULL,175),
 ('19','INVALIDO',1,1,100,175,25,100),-- RFC generico: ni convertir config
 ('20','INVALIDO',1,1,100,175,25,100);-- RFC vacio: ni convertir config

INSERT T3.CLIENTE(Cliente_SAP,RFC,Dias_Cdto,Fecha_Ini_Vig,Fecha_Fin_Vig)
SELECT 'C'+Caso,CASE Caso WHEN '19' THEN 'XAXX010101000' WHEN '20' THEN '' ELSE 'RFC'+Caso END,
 '30','20261001','20261031' FROM #Casos;
INSERT EAI_OWNER.MX_HashTable([Type],[Source],[Target])
SELECT 'SAT Amount Invoice',C.RFC,X.Config FROM #Casos X
JOIN T3.CLIENTE C ON C.Cliente_SAP='C'+X.Caso WHERE HayConfig=1;
INSERT EAI_OWNER.MX_HashTable VALUES('SAT Amount Invoice','RFC15','10000');
INSERT T3.REGISTRO_FISCAL_DETALLE(Factura,Valor_Subt)
SELECT 'F'+Caso,Base FROM #Casos WHERE HayDetalle=1;
-- Seis componentes y mas de una linea: el total sigue en 100 para este caso.
UPDATE T3.REGISTRO_FISCAL_DETALLE SET Valor_Subt=10,Valor_IVA=20,Envio_Subt=5,
 Envio_IVA=5,Credito_Subt=10,Credito_IVA=10 WHERE Factura='F16';
INSERT T3.REGISTRO_FISCAL_DETALLE(Factura,Valor_Subt) VALUES('F16',40);
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Valor_Subt,Valor_IVA,Status)
SELECT 'F'+Caso,SAT,IVA,'RECHAZADO' FROM #Casos;
INSERT T3.ASIGNACION_PAGO(Asignacion_ID,Pago_ID,Factura,Cliente_SAP,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
SELECT 'A'+Caso,'P'+Caso,'F'+Caso,'C'+Caso,'20261024 12:00:00','20261024 18:00:00',10 FROM #Casos;
INSERT T3.PAGO(Pago_ID,Tipo_Pago,Metodo_Pago) SELECT 'P'+Caso,'Payment','T' FROM #Casos;
-- Cadena vacia no debe ser nota de credito; espacios significativos si lo son.
UPDATE T3.ASIGNACION_PAGO SET Nota_Credito='' WHERE Asignacion_ID='A01';
UPDATE T3.ASIGNACION_PAGO SET Nota_Credito=' ' WHERE Asignacion_ID='A02';
INSERT T3.TIPO_DOCUMENTO(Tipo_Documento,Origen) VALUES('E',''),('V','Nota de Venta');
INSERT T3.REGISTRO_FISCAL(Factura,Tipo_Docto) VALUES('F01','E');

EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261024 14:30:00';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>20 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 THROW 52501,'Fallo de seleccion/errores en los veinte casos SAT.',1;
IF EXISTS(SELECT 'A'+Caso,Esperado,Esperado FROM #Casos
 EXCEPT SELECT Asignacion_ID,Importe_Factura,Saldo_Anterior FROM T3.CFDI_Cobranza)
 OR EXISTS(SELECT Asignacion_ID,Importe_Factura,Saldo_Anterior FROM T3.CFDI_Cobranza
 EXCEPT SELECT 'A'+Caso,Esperado,Esperado FROM #Casos)
BEGIN
 SELECT X.Caso,X.Esperado,C.Importe_Factura,C.Saldo_Anterior
 FROM #Casos X LEFT JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID='A'+X.Caso;
 THROW 52502,'Importe o saldo no coincide con expectativas Oracle.',1;
END;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A01'
 AND Status='INCOBRABLE' AND Via_Pago='03' AND Numero_Pago=1 AND Nota_Credito IS NULL)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A02'
 AND Via_Pago='CM' AND Numero_Pago=0 AND DATALENGTH(Nota_Credito)=1)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A19' AND Fecha_Envio='20261024 14:30:00')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A20' AND RFC IS NULL)
 OR EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Accnt_ID IS NOT NULL OR Master_Banco IS NOT NULL)
 THROW 52503,'Fallo vacio/NULL, espacios significativos o RFC generico.',1;
PRINT 'PASS 20 escenarios: SAT >1, ausente/NULL/vacio, no positivo, MAX textual, generico y RFC vacio';
PRINT 'PASS detalle ausente NULL frente a detalle cero, seis componentes, varias lineas y SAT sobre NULL';
PRINT 'PASS cadenas vacias Oracle: Origen fallback, nota vacia no CM, espacios conservados, salidas NULL';

TRUNCATE TABLE T3.CFDI_Cobranza;
INSERT T3.ASIGNACION_PAGO(Asignacion_ID,Pago_ID,Factura,Cliente_SAP,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
VALUES('PEN','PPEN','F_PEN','C01','20261025','20261025',10),
 ('CAN','PCAN','F_CAN','C01','20261025','20261025',10),
 ('VTA','PVTA','F_VTA','C01','20261025','20261025',10);
INSERT T3.PAGO(Pago_ID,Tipo_Pago,Metodo_Pago) VALUES('PPEN','Payment','T'),('PCAN','Payment','T'),('PVTA','Payment','T');
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Valor_Subt,Valor_IVA,Status)
VALUES('F_PEN',250,0,NULL),('F_CAN',900,0,NULL),('F_VTA',1800,0,'RECHAZADO');
INSERT T3.PREVENTA_GENERAL(Factura,Referencia) VALUES('DN_PEN','F_PEN');
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Folio_Fiscal) VALUES('DN_PEN','UUID-PEN');
INSERT T3.DEBIT_NOTE_IFC(Debit_Note,Total_Amt,Document_Date) VALUES('F_CAN',800,'20261002');
INSERT T3.REGISTRO_FISCAL(Factura,Tipo_Docto) VALUES('F_VTA','V');
INSERT T3.FACTURA_GENERAL(Factura,Fecha_Proc_BATMD) VALUES('F_VTA','20261025');
INSERT T3.FACTURA_DETALLE(Factura,Valor_Subt,Valor_IVA) VALUES('F_VTA',1000,160);
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261025';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>3
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='PEN' AND Importe_Factura=250 AND Status='DN - Penalizacion' AND UUID_Venta='UUID-PEN')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='CAN' AND Importe_Factura=900 AND Status='Canc Pago' AND Fecha_Factura='20261002')
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='VTA' AND Importe_Factura=1800 AND Tasa_IVA=16 AND Status IS NULL AND UUID_Venta IS NULL)
 THROW 52504,'SAT no se aplica despues de penalizacion/cancelacion/venta o exige UUID.',1;
PRINT 'PASS SAT despues de penalizacion, cancelacion y venta T3; sin exigir UUID/CONFIRMADO';

TRUNCATE TABLE T3.CFDI_Cobranza;
INSERT T3.ASIGNACION_PAGO(Asignacion_ID,Pago_ID,Factura,Cliente_SAP,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
VALUES('MULTI','PMULTI','F_MULTI','C01','20261026','20261026',10);
INSERT T3.PAGO(Pago_ID,Tipo_Pago,Metodo_Pago) VALUES('PMULTI','Payment','T');
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Valor_Subt,Valor_IVA) VALUES('F_MULTI',100,25),('F_MULTI',200,25);
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261026';
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>2
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='MULTI' AND Importe_Factura=125)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Asignacion_ID='MULTI' AND Importe_Factura=225)
 THROW 52505,'El outer join directo no conserva multiplicidad Oracle.',1;
PRINT 'PASS multiples CFDI: dos coincidencias se conservan, sin MAX/DISTINCT arbitrario';

-- El segundo cliente falla despues de haber procesado el primero: probar rollback real.
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE T3.RF_PROCESOS_LOG;
INSERT T3.CLIENTE(Cliente_SAP,RFC,Dias_Cdto,Fecha_Ini_Vig,Fecha_Fin_Vig)
VALUES('Z99','RFCBAD','30','20261001','20261031');
INSERT EAI_OWNER.MX_HashTable VALUES('SAT Amount Invoice','RFCBAD','INVALIDO');
INSERT T3.ASIGNACION_PAGO(Asignacion_ID,Pago_ID,Factura,Cliente_SAP,Fecha_Asignacion,Fecha_Proc_BATMD,Valor_Pago)
VALUES('ERR_OK','ERRP1','ERR_OK','C01','20261027','20261027',10),
 ('ERR_BAD','ERRP2','ERR_BAD','Z99','20261027','20261027',10);
INSERT T3.PAGO(Pago_ID,Tipo_Pago,Metodo_Pago) VALUES('ERRP1','Payment','T'),('ERRP2','Payment','T');
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261027';
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza) OR EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG)
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE REFERENCE='ERR_BAD' AND SIEBEL_ERROR_CODE='SQL-8114')
 OR @@TRANCOUNT<>0
 THROW 52506,'Configuracion invalida no revirtio el lote/bitacora antes del error.',1;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
UPDATE EAI_OWNER.MX_HashTable SET Target='10000' WHERE [Type]='SAT Amount Invoice' AND [Source]='RFCBAD';
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261027';
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza)
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE SIEBEL_ERROR_CODE='SQL-8115')
 OR @@TRANCOUNT<>0 THROW 52507,'No se preservo limite NUMBER(4) o rollback.',1;
PRINT 'PASS configuracion invalida y overflow NUMBER(4): conserva errores 8114/8115 y revierte lote';

TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
-- El overflow 8115 mantiene XACT_STATE=1 con XACT_ABORT OFF en esta prueba.
UPDATE EAI_OWNER.MX_HashTable SET Target='10000' WHERE [Type]='SAT Amount Invoice' AND [Source]='RFCBAD';
BEGIN TRANSACTION;
INSERT EAI_OWNER.MX_HashTable VALUES('Caller','MARKER','PREVIO');
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261027';
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR EXISTS(SELECT 1 FROM T3.CFDI_Cobranza)
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_HashTable WHERE [Type]='Caller')
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE SIEBEL_ERROR_CODE='SQL-8115')
 THROW 52508,'Savepoint no preservo trabajo anterior o transaccion externa.',1;
ROLLBACK TRANSACTION;
UPDATE EAI_OWNER.MX_HashTable SET Target='INVALIDO' WHERE [Type]='SAT Amount Invoice' AND [Source]='RFCBAD';
BEGIN TRANSACTION;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261024';
IF @@TRANCOUNT<>1 OR (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>20
 THROW 52509,'Ejecucion correcta confirmo transaccion externa.',1;
ROLLBACK TRANSACTION;
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza) THROW 52510,'Rollback externo no revierte lote.',1;
SET XACT_ABORT ON;
DECLARE @ErrorExterno int=0;
BEGIN TRANSACTION;
BEGIN TRY
 EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261027';
END TRY
BEGIN CATCH
 SET @ErrorExterno=ERROR_NUMBER();
END CATCH;
IF @ErrorExterno<>8114 OR XACT_STATE()<>-1 OR @@TRANCOUNT<>1
BEGIN
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW 52511,'TRAN externa condenada no conserva error original/propietario.',1;
END;
ROLLBACK TRANSACTION;
SET XACT_ABORT OFF;
SET IMPLICIT_TRANSACTIONS ON;
EXEC T3.PROC_CFDI_PROCESAR_PAGOS NULL;
DECLARE @Opciones int=@@OPTIONS,@Trans int=@@TRANCOUNT;
SET IMPLICIT_TRANSACTIONS OFF;
IF @Trans<>0 OR (@Opciones & 2)<>2 THROW 52512,'No restaura IMPLICIT_TRANSACTIONS o deja TRAN abierta.',1;
PRINT 'PASS transaccion externa: exito sin commit, savepoint en error, 8114 en TRAN condenada y opciones restauradas';

-- Control: mismo ID fuera de grupo/ventana, ID NULL y empate no deben ampliar UPDATE.
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE T3.RF_PROCESOS_LOG;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
CREATE TABLE #Control(Folio varchar(30) COLLATE DATABASE_DEFAULT,ID varchar(30) COLLATE DATABASE_DEFAULT,RFC varchar(15) COLLATE DATABASE_DEFAULT,Central varchar(30) COLLATE DATABASE_DEFAULT,Via varchar(4) COLLATE DATABASE_DEFAULT,Dias int,Enviado bit,Marcar bit);
INSERT #Control VALUES
 ('A1','A1','RFC-A','CENTRAL0001','01',0,0,0),('A2','A2','RFC-A','CENTRAL0001','01',0,0,0),
 ('A3','DUP','RFC-A','CENTRAL0001','03',0,0,1),('ACM','ACM','RFC-A','CENTRAL0001','CM',0,0,1),
 ('A_SENT','A_SENT','RFC-A','CENTRAL0001','03',0,1,0),
 ('OUTDATE','DUP','RFC-A','CENTRAL0001','03',-10,0,0),
 ('OUTGROUP','DUP','RFC-X','OTHER00001','03',0,0,0),
 ('B1','B1','RFC-B','CENTRAL0002','01',0,0,0),('B2','B2','RFC-B','CENTRAL0002','01',0,0,0),
 ('B3','B3','RFC-B','CENTRAL0002','01',0,0,0),
 ('B4',NULL,'RFC-B','CENTRAL0002','03',0,0,1),('B5',NULL,'RFC-B','CENTRAL0002','03',0,0,1),
 ('T1','T1','RFC-T','TIE0000001','01',0,0,0),('T2','T2','RFC-T','TIE0000001','03',0,0,0),
 ('L1','L1','RFC-L','12345678 ','01',0,0,0),('L2','L2','RFC-L','12345678 ','01',0,0,0),
 ('L3','L3','RFC-L','12345678 ','03',0,0,1),
 ('S1','S1','RFC-S','12345678','01',0,0,0),('S2','S2','RFC-S','12345678','01',0,0,0),
 ('S3','S3','RFC-S','12345678','03',0,0,0),
 ('G1','G1','XAXX010101000','GENERIC001','01',0,0,0),('G2','G2','XAXX010101000','GENERIC001','03',0,0,0);
INSERT T3.CFDI_Cobranza(Folio_ID,Asignacion_ID,RFC,Asignacion_Central,Via_Pago,Fecha_Proceso,Fecha_Envio)
SELECT Folio,ID,RFC,Central,Via,DATEADD(day,Dias,GETDATE()),CASE WHEN Enviado=1 THEN CONVERT(datetime,'20261001',112) END FROM #Control;
SET CURSOR_CLOSE_ON_COMMIT ON;
EXEC T3.WA_CFDI_COBZA_ASIG_CTRL 3,0;
DECLARE @OpcionesCursor int=@@OPTIONS;
SET CURSOR_CLOSE_ON_COMMIT OFF;
IF (@OpcionesCursor & 4)<>4 THROW 52513,'No restaura CURSOR_CLOSE_ON_COMMIT del llamador.',1;
IF EXISTS(SELECT 1 FROM #Control E JOIN T3.CFDI_Cobranza C ON C.Folio_ID=E.Folio
 WHERE (E.Marcar=1 AND C.Fecha_Envio IS NULL)
 OR (E.Marcar=0 AND E.Enviado=0 AND C.Fecha_Envio IS NOT NULL)
 OR (E.Enviado=1 AND C.Fecha_Envio<>'20261001'))
 OR NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=889 AND Proceso_1=8 AND Proceso_2=3 AND Proceso_3=6 AND Fin IS NOT NULL)
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG) OR @@TRANCOUNT<>0
BEGIN
 SELECT E.*,C.Fecha_Envio FROM #Control E JOIN T3.CFDI_Cobranza C ON C.Folio_ID=E.Folio;
 SELECT * FROM T3.RF_PROCESOS_LOG;
 SELECT SIEBEL_ERROR_MESSAGE FROM EAI_OWNER.MX_EAI_MESSAGE_LOG;
 THROW 52514,'Fallo control con grupos activos, IDs repetidos/NULL, empate o LENGTH.',1;
END;
PRINT 'PASS control activo: 8 grupos, 3 inconsistencias, 6 pagos revisados; 5 filas nuevas marcadas';
PRINT 'PASS CURRENT OF en heap sin PK: IDs duplicados/NULL no afectan otros grupos/fechas; CM y enviados conservan regla';
PRINT 'PASS empate, RFC generico, longitud 8 frente a 8+espacio y opcion de cursor restaurada';
-- Repetir en TRAN externa y luego revertir: las marcas no deben quedar confirmadas.
UPDATE C SET Fecha_Envio=NULL FROM T3.CFDI_Cobranza C JOIN #Control E ON E.Folio=C.Folio_ID WHERE E.Marcar=1;
BEGIN TRANSACTION;
EXEC T3.WA_CFDI_COBZA_ASIG_CTRL 3,0;
IF @@TRANCOUNT<>1 OR (SELECT COUNT(*) FROM T3.CFDI_Cobranza C JOIN #Control E ON E.Folio=C.Folio_ID WHERE E.Marcar=1 AND C.Fecha_Envio IS NOT NULL)<>5
 THROW 52515,'Control confirmo TRAN externa o no marco filas esperadas.',1;
ROLLBACK TRANSACTION;
IF EXISTS(SELECT 1 FROM T3.CFDI_Cobranza C JOIN #Control E ON E.Folio=C.Folio_ID WHERE E.Marcar=1 AND C.Fecha_Envio IS NOT NULL)
 THROW 52516,'El rollback externo no revierte marcas del control.',1;
PRINT 'PASS control dentro de transaccion externa conserva @@TRANCOUNT y permite rollback del llamador';
GO
-- Error tardio del control: el grupo anterior confirmado debe sobrevivir.
TRUNCATE TABLE T3.CFDI_Cobranza;
TRUNCATE TABLE T3.RF_PROCESOS_LOG;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
INSERT T3.CFDI_Cobranza(Folio_ID,Asignacion_ID,RFC,Asignacion_Central,Via_Pago,Fecha_Proceso)
VALUES('FIRST1','FIRST1','RFC-A','AAA_FIRST01','01',GETDATE()),('FIRST2','FIRST2','RFC-A','AAA_FIRST01','01',GETDATE()),
 ('FIRST3','FIRST3','RFC-A','AAA_FIRST01','03',GETDATE()),
 ('LAST1','LAST1','RFC-Z','ZZZ_LAST001','01',GETDATE()),('LAST2','LAST2','RFC-Z','ZZZ_LAST001','01',GETDATE()),
 ('LAST3','LAST3','RFC-Z','ZZZ_LAST001','03',GETDATE());
GO
CREATE TRIGGER T3.TEST_FAIL_CONTROL ON T3.CFDI_Cobranza AFTER UPDATE AS
BEGIN
 IF UPDATE(Fecha_Envio) AND EXISTS(SELECT 1 FROM inserted WHERE Asignacion_Central='ZZZ_LAST001')
  RAISERROR('Error tardio sintetico del control',16,1);
END;
GO
EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261024';
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Folio_ID='FIRST3' AND Fecha_Envio IS NOT NULL)
 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Folio_ID='LAST3' AND Fecha_Envio IS NULL)
 OR (SELECT COUNT(*) FROM T3.CFDI_Cobranza WHERE Fecha_Proc_BATMD='20261024')<>20
 OR NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=604 AND Fin IS NOT NULL AND Proceso_1=20)
 OR NOT EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE QUEUE_NAME='WA_CFDI_COBZA_ASIG_CTRL' AND SIEBEL_ERROR_CODE='SQL-50000')
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE QUEUE_NAME='PROC_CFDI_PROCESAR_PAGOS') OR @@TRANCOUNT<>0
 THROW 52517,'Error del control revirtio lote principal o grupo anterior confirmado.',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_cursors(@@SPID) WHERE name IN ('ScrCursor','ScrPagos'))
 THROW 52518,'Error del control dejo cursores abiertos.',1;
DROP TRIGGER T3.TEST_FAIL_CONTROL;
TRUNCATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG;
EXEC T3.WA_CFDI_COBZA_ASIG_CTRL 3,0;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_Cobranza WHERE Folio_ID='LAST3' AND Fecha_Envio IS NOT NULL)
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG) OR @@TRANCOUNT<>0
 THROW 52519,'No se recupero el control despues del error.',1;
PRINT 'PASS error tardio: lote 604 y grupo 889 previo persisten; grupo fallido se revierte, log original y cursores limpios';
PRINT 'PASS nueva ejecucion del control despues de retirar error completa el grupo pendiente';
PRINT 'PASS correccion de reglas Oracle terminada; solo SQL Server sintetico, sin certificar motor Oracle ni datos reales';
