SET NOCOUNT ON;
-- Comparacion de etapa 10 con las UDF reales, en base desechable.
INSERT T3.Cliente(Cliente_SAP,Fecha_Ini_Vig,Fecha_Fin_Vig,RFC)
VALUES ('C1','20200101','20300101','RFC1'),
       ('C2','20200101','20300101','RFC2'),('C2','20200101','20300101','RFC2');
INSERT T3.Factura_General(Factura,Ctro,Fecha_Factura,Tipo_Docto,Cliente_SAP)
SELECT N,'0001',F,T,C FROM (VALUES
 ('OPEN','20260101','C003','C1'),('PAID','20260101','C003','C1'),
 ('FIVE','20260101','C003','C1'),('SIX','20260101','C003','C1'),
 ('OVER','20260101','C003','C1'),('NULLPAY','20260101','C003','C1'),
 ('EXISTS','20260101','C003','C1'),('OLD','20251231','C003','C1'),
 ('WRONG','20260101','C999','C1'),('NOCLIENT','20260101','C003','CX'),
 ('NODETAIL','20260101','C003','C1'),('DUP','20260101','C003','C2'),
 ('DUP','20260101','C003','C2'),('CM_PAID','20260101','C004','C1'),
 ('CM_OPEN','20260101','C004','C1'),('MIX','20260101','C003','C1'),
 ('MIX','20260101','C004','C1'),('ZERO','20260101','C003','C1'),
 ('NULLAMT','20260101','C003','C1')) AS X(N,F,T,C);
INSERT T3.Factura_Detalle(Factura,Valor_Subt)
SELECT DISTINCT Factura,CASE WHEN Factura='ZERO' THEN 0 WHEN Factura='NULLAMT' THEN NULL ELSE 100 END
FROM T3.Factura_General WHERE Factura<>'NODETAIL';
INSERT T3.Factura_Detalle(Factura,Valor_Subt) VALUES ('DUP',10);
INSERT T3.Preventa_General(Factura,Ctro,Fecha_Factura,Clase_Factura,Cliente_SAP,Fecha_Proc_BATMD,Fecha_Cancelacion)
SELECT N,'0001','20260101',T,'C1',P,C FROM (VALUES
 ('P5','C005','20260101',NULL),('P6','C006','20260101',NULL),
 ('P19','C019','20260101',NULL),('P25','C025','20260101',NULL),
 ('PCANCEL','C005','20260101','20260102'),('PNOPROC','C005',NULL,NULL),
 ('OPEN','C005','20260101',NULL)) AS X(N,T,P,C);
INSERT T3.Preventa_Detalle(Factura,Valor_Subt,Valor_IVA,Credito_Subt,Credito_IVA,Envio_Subt,Envio_IVA)
SELECT Factura,80,10,3,2,4,1 FROM T3.Preventa_General;
INSERT T3.CFDI_Cobranza(Factura,Nota_Credito,Importe,Via_Pago) VALUES
 ('PAID',NULL,100,'01'),('FIVE',NULL,99.95,'XX'),('SIX',NULL,99.94,'CM'),
 ('OVER',NULL,101,'AI'),('NULLPAY',NULL,NULL,'01'),
 (NULL,'CM_PAID',25,'XX'),(NULL,'CM_OPEN',100,'CM'),
 ('MIX','MIX',100,'AI');
INSERT T3.CFDI_Historia_Docto_PAC(Nota_Venta,Nota_Venta_CFDI)
VALUES ('CM_PAID','FISCAL'),('CM_PAID','FISCAL'),('CM_OPEN','NO_UUID');
INSERT T3.CFDI_Documentos(Nota_Venta,Folio_Fiscal)
VALUES ('FISCAL','U1'),('FISCAL','U2'),('NO_UUID',NULL);
-- Mas claves para verificar ejecucion por conjuntos con duplicados de detalle.
;WITH N AS (SELECT TOP (1500) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) n
            FROM sys.all_objects A CROSS JOIN sys.all_objects B)
INSERT T3.Factura_General(Factura,Ctro,Fecha_Factura,Tipo_Docto,Cliente_SAP)
SELECT CONCAT('B',n),'0001','20260201','C003','C1' FROM N;
INSERT T3.Factura_Detalle(Factura,Valor_Subt)
SELECT Factura,10 FROM T3.Factura_General WHERE Factura LIKE 'B%';
INSERT T3.CFDI_Cobranza(Factura,Importe)
SELECT Factura,10 FROM T3.Factura_General WHERE Factura LIKE 'B%';

INSERT EAI.CFDI_OPEN_ITEMS(Nota_Venta,Last_Updated) VALUES ('EXISTS',NULL);
DECLARE @T datetime2(3)=SYSDATETIME();
EXEC EAI.TestHistoricOriginal;
SELECT DATEDIFF(millisecond,@T,SYSDATETIME()) AS Original_ms;
SELECT Ctro,Nota_Venta,Cliente_SAP,Clte_Factura_SAP,Fecha_Venta,Tipo_Docto,Importe_Vta,
       COUNT_BIG(*) AS Multiplicidad
INTO #Expected FROM EAI.CFDI_OPEN_ITEMS
GROUP BY Ctro,Nota_Venta,Cliente_SAP,Clte_Factura_SAP,Fecha_Venta,Tipo_Docto,Importe_Vta;
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT EAI.CFDI_OPEN_ITEMS(Nota_Venta,Last_Updated) VALUES ('EXISTS',NULL);
SET @T=SYSDATETIME();
EXEC EAI.TestHistoricNuevo @Diagnostico=1;
SELECT DATEDIFF(millisecond,@T,SYSDATETIME()) AS Nuevo_ms;
SELECT Ctro,Nota_Venta,Cliente_SAP,Clte_Factura_SAP,Fecha_Venta,Tipo_Docto,Importe_Vta,
       COUNT_BIG(*) AS Multiplicidad
INTO #Actual FROM EAI.CFDI_OPEN_ITEMS
GROUP BY Ctro,Nota_Venta,Cliente_SAP,Clte_Factura_SAP,Fecha_Venta,Tipo_Docto,Importe_Vta;
IF EXISTS(SELECT * FROM #Expected EXCEPT SELECT * FROM #Actual)
 OR EXISTS(SELECT * FROM #Actual EXCEPT SELECT * FROM #Expected)
 THROW 51000,'Diferencia de resultados o multiplicidad en etapa 10.',1;
IF (SELECT COUNT(*) FROM EAI.CFDI_OPEN_ITEMS)<>13
 THROW 51001,'Conteo esperado de casos especiales no coincide.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='DUP' AND Importe_Vta=440)
 THROW 51002,'No se conservaron cabeceras duplicadas/vigencias solapadas.',1;
IF EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta IN ('FIVE','PAID','CM_PAID','ZERO','NULLAMT'))
 THROW 51003,'Reglas de saldo o multiplicidad UUID incorrectas.',1;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='MIX' AND Tipo_Docto='Dev')
 OR EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='MIX' AND Tipo_Docto='Vta')
 THROW 51004,'No separa cobranza por folio y tipo.',1;
PRINT 'PASS: igualdad multiconjunto etapa 10, umbral, fechas, clases, NULL, duplicados, UUID y folio mixto.';

-- Las dos versiones deben fallar si la suma no cabe en NUMERIC(15,2).
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT T3.CFDI_Cobranza(Factura,Importe) VALUES ('OPEN',10000000000000);
DECLARE @OldError int=0,@NewError int=0;
BEGIN TRY EXEC EAI.TestHistoricOriginal; END TRY BEGIN CATCH SET @OldError=ERROR_NUMBER(); END CATCH;
DELETE EAI.CFDI_OPEN_ITEMS;
BEGIN TRY EXEC EAI.TestHistoricNuevo; END TRY BEGIN CATCH SET @NewError=ERROR_NUMBER(); END CATCH;
IF @OldError<>8115 OR @NewError<>8115 THROW 51005,'No conserva desbordamiento NUMERIC(15,2).',1;
PRINT 'PASS: desbordamiento NUMERIC(15,2) conservado.';
DELETE T3.CFDI_Cobranza WHERE Factura='OPEN';
DELETE EAI.CFDI_OPEN_ITEMS;
EXEC EAI.TestHistoricNuevo @FechaInicio='20270101';
IF EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS)
 THROW 51007,'No respeta el parametro FechaInicio.',1;
PRINT 'PASS: corte parametrizable sin documentos candidatos.';

-- Compilacion y ejecucion completa, incluida la auditoria original.
EXEC EAI.SF_CFDI_OPEN_ITEMS_RENDIMIENTO @nEtapa=0,@FechaInicio='20260101',@Diagnostico=1;
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE Proceso=923 AND Fin IS NOT NULL)
 THROW 51006,'No cerro auditoria en ejecucion completa.',1;
PRINT 'PASS: ejecucion completa del procedimiento nuevo con funciones reales.';
