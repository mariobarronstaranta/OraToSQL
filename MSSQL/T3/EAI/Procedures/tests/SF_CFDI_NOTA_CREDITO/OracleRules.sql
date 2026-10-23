-- Ejecutar despues de Cases.sql, exclusivamente en la base temporal.
SET NOCOUNT ON;
ALTER TABLE EAI.CFDI_UUID_NOTA_CREDITO DROP CONSTRAINT CK_Test_Aplicacion;
DELETE T3.CFDI_Cobranza;
DELETE EAI.CFDI_UUID_NOTA_CREDITO;
INSERT EAI.CFDI_UUID_NOTA_CREDITO
 (Nota_Venta,Aplica_NC,Importe_NC,Fecha_Aplicacion,Incobrable)
VALUES ('SIN',99,999,'20260101',999),('AI_NULL',99,999,'20260101',999),
 ('MIX',99,999,'20260101',999),('DUP',99,999,'20260101',999),
 ('DUP',99,999,'20260101',999),(NULL,99,999,'20260101',999);
INSERT T3.CFDI_Cobranza VALUES
 ('AI_NULL',NULL,NULL,'20260901','AI'),
 ('MIX',NULL,10,'20260901','CM'),('MIX','',5,'20260902','AI'),
 ('MIX','A',NULL,'20260903','AI'),('MIX','A',-2,'20260904','ZZ'),
 ('DUP','D',3,'20260901',NULL),(NULL,'NULL',999,'20260901','AI');

-- Referencia independiente: agregado SIN GROUP BY por cada nota, igual que
-- ScrCobza Oracle. Si Nota_Venta es NULL, su UPDATE no encuentra filas.
SELECT N.Ctro,N.Fecha_Venta,N.Nota_Venta,N.RFC,N.Cliente_SAP,N.Importe_Vta,
 N.Saldo_SAP,N.Folio_Fiscal,
 CASE WHEN N.Nota_Venta IS NULL THEN N.Aplica_NC ELSE C.Aplicaciones END AS Aplica_NC,
 CASE WHEN N.Nota_Venta IS NULL THEN N.Importe_NC ELSE C.Importe END AS Importe_NC,
 CASE WHEN N.Nota_Venta IS NULL THEN N.Fecha_Aplicacion ELSE C.Fecha END AS Fecha_Aplicacion,
 CASE WHEN N.Nota_Venta IS NULL THEN N.Incobrable ELSE C.Incobrable END AS Incobrable
INTO #OracleEsperado
FROM EAI.CFDI_UUID_NOTA_CREDITO AS N
OUTER APPLY
(
 SELECT COUNT(NULLIF(Asignacion_ID,'')) AS Aplicaciones,
 SUM(ISNULL(Importe,0)) AS Importe, MAX(Fecha_Asignacion) AS Fecha,
 SUM(CASE WHEN Via_Pago='AI' THEN Importe ELSE 0 END) AS Incobrable
 FROM T3.CFDI_Cobranza AS C WHERE C.Nota_Credito=N.Nota_Venta
) C;
EXEC EAI.SF_CFDI_NOTA_CREDITO 10;
IF EXISTS(SELECT * FROM #OracleEsperado EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 OR EXISTS(SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO EXCEPT SELECT * FROM #OracleEsperado)
 OR (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO)<>6
 THROW 51100,'Etapa 10 difiere del agregado escalar Oracle.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='SIN'
 AND Aplica_NC=0 AND Importe_NC IS NULL AND Fecha_Aplicacion IS NULL AND Incobrable IS NULL)
 THROW 51101,'La nota sin cobranza conserva valores obsoletos.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='AI_NULL'
 AND Aplica_NC=0 AND Importe_NC=0 AND Incobrable IS NULL)
 THROW 51102,'AI con todos los importes NULL.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='MIX'
 AND Aplica_NC=2 AND Importe_NC=13 AND Incobrable=5 AND Fecha_Aplicacion='20260904')
 THROW 51103,'Conteo no DISTINCT o suma de todas las vias.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='DUP' AND Importe_NC=3)<>2
 THROW 51104,'Duplicados destino incorrectos.',1;
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=(SELECT MAX(PID) FROM T3.RF_PROCESOS_LOG)
 AND Proceso_1=6 AND Proceso_2=0 AND Proceso_3=0 AND Proceso_4=0 AND Fin IS NOT NULL)
 THROW 51105,'Contador debe incluir notas sin cobranza y nota NULL.',1;
EXEC EAI.SF_CFDI_NOTA_CREDITO 11;
IF EXISTS(SELECT * FROM #OracleEsperado EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 THROW 51106,'Etapa 11 modifico aplicaciones.',1;
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=(SELECT MAX(PID) FROM T3.RF_PROCESOS_LOG)
 AND Proceso_1=0) THROW 51107,'Etapa 11 contador no es cero.',1;
PRINT 'PASS: 8 verificaciones de agregado Oracle, vacios, nulos, duplicados y etapas';

DELETE EAI.CFDI_UUID_NOTA_CREDITO;
DELETE T3.CFDI_Cobranza;
DELETE T3.Factura_General;
DELETE T3.Factura_Detalle;
DELETE T3.Preventa_General;
DELETE T3.Preventa_Detalle;
DELETE T3.Cliente;
DELETE EAI.T3R_Cartera_SAP_OLD;
DELETE T3.CFDI_Documentos;
INSERT T3.Cliente VALUES
 ('C1','RFC_TEST','20230101','20300101'),('GEN','XAXX010101000','20230101','20300101'),
 ('NULO',NULL,'20230101','20300101'),('VACIO','','20230101','20300101'),
 ('EXP','RFC_EXP','20200101','20221231');
INSERT T3.Factura_General VALUES
 ('MX01','20230101','EDGE','C1','C004'),('MX01','20260901','BOTH','C1','C004'),
 ('MX01','20260901','NEG','C1','C004'),('MX01','20221231','OLD','C1','C004'),
 ('MX01','20260901','TIPO','C1','C003'),('MX01','20260901','GEN','GEN','C004'),
 ('MX01','20260901','NULO','NULO','C004'),('MX01','20260901','VACIO','VACIO','C004'),
 ('MX01','20260901','EXP','EXP','C004');
INSERT T3.Factura_Detalle SELECT Factura,'M',100,16,0,0 FROM T3.Factura_General;
INSERT T3.Factura_Detalle VALUES ('EDGE','M',100,16,1,0.16);
UPDATE T3.Factura_Detalle SET Valor_Subt=-100,Valor_IVA=-16 WHERE Factura='NEG';
INSERT T3.Preventa_General VALUES
 ('MX01','20260901','BOTH','C1','C006','20260901',NULL),
 ('MX01','20260901','PG19','C1','C019','20260901',NULL),
 ('MX01','20260901','PG25','C1','C025','20260901',NULL),
 ('MX01','20260901','CANCEL','C1','C006','20260901','20260902'),
 ('MX01','20260901','NOPROC','C1','C006',NULL,NULL),
 ('MX01','20260901','PGTIPO','C1','C005','20260901',NULL);
INSERT T3.Preventa_Detalle SELECT Factura,'M',50,8,0,0 FROM T3.Preventa_General;
UPDATE T3.Preventa_Detalle SET Valor_Subt=NULL,Valor_IVA=NULL,Envio_Subt=NULL,Envio_IVA=NULL
WHERE Factura='PG19';
INSERT EAI.T3R_Cartera_SAP_OLD VALUES ('EDGE','C1','20230101',-50),('EDGE','C2','20230102',10),
 ('EDGE','C1','20230103',NULL);
INSERT T3.CFDI_Documentos VALUES ('EDGE','UUID1'),('EDGE','UUID2');
EXEC EAI.SF_CFDI_NOTA_CREDITO -1;
IF (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO)<>6 THROW 51108,'Filtros de carga incorrectos.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='EDGE'
 AND Importe_Vta=233.16 AND Saldo_SAP=40 AND Folio_Fiscal IN ('UUID1','UUID2'))<>2
 THROW 51109,'Fecha inclusiva, detalle duplicado, suma SAP o multiplicidad CFDI.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='BOTH'
 AND Importe_Vta=174 AND Saldo_SAP=0 AND Folio_Fiscal IS NULL)
 THROW 51110,'UNION ALL o LEFT JOIN opcional.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='NEG' AND Importe_Vta=-116)
 THROW 51111,'Importe de venta no debe convertirse a ABS.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Nota_Venta='PG19' AND Importe_Vta=0)
 THROW 51112,'NVL de los cuatro importes.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO WHERE Aplica_NC=0 AND Importe_NC IS NULL)<>6
 THROW 51113,'Carga sin cobranza debe aplicar agregado vacio.',1;
IF @@TRANCOUNT<>0 THROW 51114,'Transaccion abierta.',1;
PRINT 'PASS: 7 verificaciones de carga, filtros, signos, SAP y UUID opcional/repetido';
-- El DDL real limita Aplica_NC a numeric(4,0), no INT.
SELECT * INTO #AntesOverflow FROM EAI.CFDI_UUID_NOTA_CREDITO;
;WITH N AS (SELECT 1 AS I FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) V(I))
INSERT T3.CFDI_Cobranza (Nota_Credito,Asignacion_ID,Importe,Fecha_Asignacion,Via_Pago)
SELECT 'BOTH','REPETIDA',1,'20260901','CM' FROM N A CROSS JOIN N B CROSS JOIN N C CROSS JOIN N D;
DECLARE @ErrorOverflow int=0;
BEGIN TRY
 EXEC EAI.SF_CFDI_NOTA_CREDITO 0;
END TRY
BEGIN CATCH
 SET @ErrorOverflow=ERROR_NUMBER();
END CATCH;
IF @ErrorOverflow<>8115 OR @@TRANCOUNT<>0 THROW 51115,'Limite de Aplica_NC o transaccion incorrectos.',1;
IF EXISTS(SELECT * FROM #AntesOverflow EXCEPT SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO)
 OR EXISTS(SELECT * FROM EAI.CFDI_UUID_NOTA_CREDITO EXCEPT SELECT * FROM #AntesOverflow)
 OR (SELECT COUNT(*) FROM EAI.CFDI_UUID_NOTA_CREDITO)<>6
 THROW 51116,'Overflow no restauro reporte anterior.',1;
PRINT 'PASS: overflow de 10000 asignaciones revierte la reconstruccion';
GO
