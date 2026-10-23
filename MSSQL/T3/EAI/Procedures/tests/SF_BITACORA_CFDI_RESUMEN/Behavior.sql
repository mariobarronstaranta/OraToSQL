SET NOCOUNT ON;
INSERT EAI.FC__TIME_WINDOW VALUES ('01/08/2026','31/08/2026','100');
INSERT EAI.CONTROL_REPORTE (Reporte) VALUES ('BITACORA CFDI');
INSERT EAI_OWNER.MX_COMPONENTS (Component) VALUES (802);
INSERT T3.Cliente (Cliente_SAP,Fecha_Ini_Vig,Fecha_Fin_Vig,Nombre,Lista_Precio,RFC)
VALUES ('C1','20200101','20300101','CLIENTE','01','RFC-CLIENTE');

-- Matriz PAC x clase; campos nulos deliberados en NUL.
INSERT T3.Factura_General (Factura,Fecha_Factura,Tipo_Docto,Cliente_SAP,Ubicacion,Valor_Subt,Valor_IVA)
VALUES ('F1','20260815','C003','C1','12345678901234T001',100,16),
 ('NUL','20260815','C003','C1','12345678901234T001',100,16),
 ('PEND','20260815','C004','C1','12345678901234T001',NULL,16),
 ('PUB','20260815','C003','C1','12345678901234T001',100,16),
 ('ERR','20260815','C003','C1','12345678901234T001',100,16),
 ('CENT','20260831 23:59:59','C003','C1','12345678901234T001',100,16),
 ('SIX','20260815','C003','C1','12345678901234T001',100,16),
 ('OLD','20260731','C003','C1','12345678901234T001',100,16),
 ('NEXT','20260901','C003','C1','12345678901234T001',100,16);
INSERT T3.CFDI_Historia_Docto_PAC (Nota_Venta,Nota_Venta_CFDI,Fecha_Factura,Ctro)
SELECT Factura,Factura,Fecha_Factura,'0001' FROM T3.Factura_General;
INSERT T3.CFDI_Documento_Paso (Factura,RFC_Factura)
SELECT Factura,'RFC-PASO' FROM T3.Factura_General;
INSERT T3.CFDI_Documentos (Nota_Venta,Status,Valor_Subt,Valor_IVA)
SELECT Factura,CASE Factura WHEN 'PEND' THEN 'PENDING' WHEN 'PUB' THEN 'PUBLICADO'
 WHEN 'ERR' THEN 'ERROR' ELSE 'CONFIRMADO' END,
 CASE WHEN Factura='NUL' THEN NULL ELSE 100 END,
 CASE Factura WHEN 'CENT' THEN 16.05 WHEN 'SIX' THEN 16.06 ELSE 16 END
FROM T3.Factura_General;

INSERT T3.Preventa_General (Factura,Fecha_Factura,Clase_Factura,Cliente_SAP,Ubicacion,
 Valor_Subt,Valor_IVA,Fecha_Cancelacion,Fecha_Proc_BATMD)
VALUES ('P5','20260815','C005','C1','P001',100,16,'20260816','20260815'),
 ('PFX','20260815','C0FX','C1','P001',100,16,NULL,'29990101'),
 ('P20','20260815','C020','C1','P001',100,16,NULL,NULL),
 ('P21','20260815','C021','C1','P001',100,16,NULL,NULL),
 ('P22','20260815','C022','C1','P001',100,16,NULL,NULL),
 ('P6','20260815','C006','C1','P001',100,16,NULL,NULL);
INSERT T3.CFDI_Historia_Docto_PAC (Nota_Venta,Nota_Venta_CFDI,Fecha_Factura,Ctro)
SELECT Factura,Factura,Fecha_Factura,'0001' FROM T3.Preventa_General;
INSERT T3.CFDI_Documentos (Nota_Venta,Status,Valor_Subt,Valor_IVA)
SELECT Factura,'PENDING',100,16 FROM T3.Preventa_General;
INSERT T3.Entrega (Factura,Ubicacion) VALUES ('P20',''),('P21','E001');

-- Duplicados de cabecera: Oracle multiplica detalle; no deben deduplicarse.
INSERT T3.Material (Material,Unidad_Med_Vta,Cig_x_CLL,Cig_x_PAQ)
VALUES ('M1','CAJ',20,5),('M2','PAQ',20,NULL);
INSERT T3.Registro_Fiscal (Factura,Tipo_Docto)
VALUES ('F1','C003'),('F1','C005'),('P5','C005');
INSERT T3.Registro_Fiscal_Detalle (Factura,Material,Cantidad_Vta,Envio_Subt,Envio_IVA,Credito_Subt,Credito_IVA)
VALUES ('F1','M1',2,1,0.16,2,0.32),('F1','M2',3,0,0,0,0),
 ('F1','MISSING',100,999,999,999,999),('P5','M1',1,5,1,0,0);
INSERT T3.CFDI_Agrupado_DIF (Nota_Venta_CFDI,Ajuste)
VALUES ('F1',0.01),('F1',0.02),('F1',0),('NUL',0.10);
INSERT T3.CFDI_Addenda (RFC) VALUES ('RFC-PASO');

-- Un Doc_Num elegible obliga a actualizar TODAS sus filas en bitacora.
INSERT EAI.CFDI_BITACORA (Doc_Num,Cliente_SAP,Invc_dt,SAP_Amount,SF_Amount)
VALUES ('F1','C1','20260815',50,0),('F1','C2','20200101',75,0);
INSERT EAI_OWNER.WA_VENTA_CENTRALIZADA VALUES ('C1','20260101','20261231');

-- Agrupados PENDING y PUBLICADO: el ultimo conserva fiscales en cero inicialmente.
INSERT T3.Factura_General (Factura,Valor_Subt,Valor_IVA) VALUES ('A1',10,2),('A2',10,2);
INSERT T3.Factura_Detalle (Factura,Valor_Subt,Valor_IVA,Envio_Subt,Envio_IVA)
VALUES ('A1',10,2,1,0.16),('A1',NULL,99,9,9),('A2',10,2,0,0);
INSERT T3.CFDI_Historia_Docto_PAC (Nota_Venta,Nota_Venta_CFDI,Fecha_Factura,Ctro)
VALUES ('A1','G-1','20260815','0001'),('A1','G-1','20260815','0001'),
 ('A2','G-2','20260815','0001');
INSERT T3.CFDI_Agrupado (Nota_Venta_CFDI,Fecha_Documento,Tipo_Docto,Ctro,Cliente_SAP,Doctos)
VALUES ('G-1','20260815','C003','0001','X1234',1),
 ('G-1','20260815','C003','0001','X1234',1),('G-2','20260815','C004','0001','X1234',1);
INSERT T3.CFDI_Agrupado_Detalle (Nota_Venta_CFDI,Material,Cantidad_Vta,Valor_Subt,Valor_IVA,Envio_Subt,Envio_IVA)
VALUES ('G-1','M1',2,10,2,1,0.16),('G-1','M2',1,NULL,3,9,0),('G-2','M1',1,10,2,0,0);
INSERT T3.CFDI_Documentos (Nota_Venta,Status) VALUES ('G-1','PENDING'),('G-2','PUBLICADO');
INSERT T3.Fact_T3 VALUES ('A1','01');
INSERT T3.Nota_T3 VALUES ('A1','01');
INSERT T3.CFDI_Agrupado_DIF (Nota_Venta_CFDI,Ajuste) VALUES ('G-1',0.10),('G-1',-0.10);

EXEC EAI.SF_BITACORA_CFDI_RESUMEN '20260801','20260831';
IF (SELECT COUNT(*) FROM EAI.CFDI_INFORME) <> 15 THROW 55001,'Conteo o limites del periodo incorrectos.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='F1'
 AND Cigarrillos=86 AND Envio_Subt=2 AND Credito_Subt=4 AND Monto_T3In=122.96
 AND Valor_IVA=16.03 AND Valor=116.03 AND RFC='RFC-PASO' AND Terr='T001'
 AND Origen='SAP' AND Addenda='SI') THROW 55002,'Individual: multiplicidad, conversion, ajustes o centralizada.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='NUL'
 AND Valor_Subt IS NULL AND Valor IS NULL AND Valor_IVA=16.10) THROW 55003,'PAC NULL no conservado.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='PEND'
 AND Factor=-1 AND Valor_Subt IS NULL AND Valor IS NULL AND Valor_IVA=-16 AND Monto_T3In=-16)
 THROW 55004,'PENDING NULL o signo incorrecto.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='ERR' AND Valor=0)
 THROW 55005,'Estado ERROR.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='PUB' AND Valor=116)
 THROW 55006,'Estado PUBLICADO.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='CENT'
 AND Diferencia=0.05 AND Valor=116 AND Valor_IVA=16) THROW 55007,'Centavos <0.06 o fin del dia.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='SIX'
 AND Diferencia IS NULL AND Valor=116.06) THROW 55008,'Umbral 0.06.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_BITACORA WHERE Doc_Num='F1' AND SF_Amount=SAP_Amount AND Origen='SAP')<>2
 THROW 55009,'Centralizada no actualizo todas las filas del Doc_Num.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='P5' AND Monto_T3In=0
 AND Cigarrillos=20 AND Envio_Subt=5) THROW 55010,'Cancelada C005 o exclusion de envio.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='PFX' AND Monto_T3In=0 AND Factor=1)
 THROW 55011,'Anio 2999 o signo C0FX.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_INFORME WHERE Folio_Interno IN ('P20','P21','P22') AND Sociedad='MX01')<>3
 THROW 55012,'Sociedad MX01.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='P20' AND Factor=1 AND Terr='P001')
 THROW 55013,'Entrega vacia o signo C020.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='P21' AND Factor=-1 AND Terr='E001')
 THROW 55014,'Prioridad entrega o signo C021.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='G-1'
 AND Monto_T3In=13.16 AND Valor_Subt=22 AND Valor_IVA=10.32 AND Valor=32.32
 AND Cigarrillos=82 AND Envio_Subt=20 AND LP='01' AND Doctos=1)
 THROW 55015,'Agrupado: NULL, multiplicidad, DISTINCT historico, LP o ajuste neto cero.',1;
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='G-2' AND Factor=-1
 AND Valor_Subt=0 AND Valor_IVA=0 AND Valor=-12 AND Cigarrillos=-20)
 THROW 55016,'Agrupado PUBLICADO o signo.',1;
IF NOT EXISTS (SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=1 AND Proceso_1=7
 AND Proceso_2=6 AND Proceso_3=2 AND Proceso_4=5 AND Fin IS NOT NULL)
 THROW 55017,'Auditoria: contar ajustes individuales, incluyendo neto cero.',1;
IF EXISTS (SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG) THROW 55018,'Errores inesperados.',1;
PRINT 'PASS: 18 comprobaciones de importes, nulos, signos, volumen, limites, duplicados y auditoria';

-- ADD_MONTHS(30/04,-1) = 31/03 en Oracle, no 30/03.
UPDATE EAI.FC__TIME_WINDOW SET Start_Date='30/04/2026';
UPDATE T3.CFDI_Historia_Docto_PAC SET Fecha_Factura='20260330' WHERE Nota_Venta='OLD';
UPDATE T3.CFDI_Historia_Docto_PAC SET Fecha_Factura='20260331' WHERE Nota_Venta='NEXT';
EXEC EAI.SF_BITACORA_CFDI_RESUMEN NULL,'19000101';
IF EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='OLD')
 OR NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='NEXT')
 THROW 55019,'ADD_MONTHS fin de mes o fecha final ignorada con inicio NULL.',1;
EXEC EAI.SF_BITACORA_CFDI_RESUMEN '','19000101';
IF NOT EXISTS (SELECT 1 FROM EAI.CFDI_INFORME WHERE Folio_Interno='NEXT')
 THROW 55020,'Inicio vacio Oracle.',1;
DECLARE @Filas int=(SELECT COUNT(*) FROM EAI.CFDI_INFORME), @Error int=0;
BEGIN TRY
 EXEC EAI.SF_BITACORA_CFDI_RESUMEN 'invalida','20260831';
END TRY
BEGIN CATCH
 SET @Error=ERROR_NUMBER();
END CATCH;
IF @Error<>54102 OR (SELECT COUNT(*) FROM EAI.CFDI_INFORME)<>@Filas
 THROW 55021,'Validacion preventiva debe conservar informe previo.',1;
PRINT 'PASS: fechas predeterminadas, inicio vacio y proteccion ante fechas invalidas';
INSERT T3.Nota_T3 VALUES ('A1','02');
SET @Error=0;
BEGIN TRY
 EXEC EAI.SF_BITACORA_CFDI_RESUMEN '20260801','20260831';
END TRY
BEGIN CATCH
 SET @Error=ERROR_NUMBER();
END CATCH;
IF @Error<>54104 OR (SELECT COUNT(*) FROM EAI.CFDI_INFORME)<>@Filas
 THROW 55022,'LP ambigua debe detectarse antes del DELETE.',1;
PRINT 'PASS: LP ambigua detectada antes de borrar informe';
GO
