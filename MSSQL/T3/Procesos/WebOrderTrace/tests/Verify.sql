-- Execute only in the isolated fixture database created from repository DDL.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'CodexWebOrderTraceTest' THROW 52000,'Solo ejecutar en CodexWebOrderTraceTest.',1;
DECLARE @parsed TABLE(RowNo int,ColNo int,Value nvarchar(max));
DECLARE @csv nvarchar(max)=NCHAR(65279)+N'a,b'+NCHAR(13)+NCHAR(10)+N'"x,y","line1'+NCHAR(10)+N'line2 ""ok"""';
INSERT @parsed EXEC EAI_OWNER.WOT_PARSE_CSV @csv;
IF (SELECT COUNT(*) FROM @parsed)<>4 THROW 52001,'Parser: cantidad de campos.',1;
IF NOT EXISTS(SELECT 1 FROM @parsed WHERE RowNo=2 AND ColNo=2 AND Value=N'line1'+NCHAR(10)+N'line2 "ok"')
 THROW 52002,'Parser: multilinea o escape incorrecto.',1;
BEGIN TRY
 DELETE @parsed;
 SET @csv=N'a,b'+NCHAR(10)+N'"unterminated,b';
 INSERT @parsed EXEC EAI_OWNER.WOT_PARSE_CSV @csv;
 THROW 52003,'Parser acepto comillas sin cerrar.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51001 THROW;
END CATCH;
PRINT 'OK CSV parser: BOM, commas, embedded LF, escaped quotes, malformed rejection';

DELETE EAI.CONTROL_REPORTE WHERE REPORTE='AUTO-NOT DELIVERED';
INSERT EAI.CONTROL_REPORTE(REPORTE) VALUES('AUTO-NOT DELIVERED');
DELETE T3.PREVENTA_GENERAL;
DELETE T3.PREVENTA_DETALLE;
DELETE T3.FACTURA_GENERAL;
DELETE T3.FACTURA_DETALLE;
DELETE T3.CFDI_COBRANZA;
DELETE EAI.TAO_CARTERA_SAP_LDR;
INSERT T3.PREVENTA_GENERAL(FACTURA,CTRO,FECHA_FACTURA,CLASE_FACTURA,ENTREGA,FECHA_PROC_BATMD)
VALUES('NUM001','P001','20260820','C005','SAP001','20260821'),
('L1234','P001','20260820','C006','SAPZ001','20260821'),
('NUM002','P002','20260501','C005','SAP002','20260502');
INSERT T3.PREVENTA_DETALLE(FACTURA,VALOR_SUBT) VALUES('NUM001',100),('L1234',100),('NUM002',200);
INSERT T3.CFDI_COBRANZA(FACTURA,NOTA_CREDITO,IMPORTE) VALUES('INV001','L1234',100);
INSERT EAI.TAO_CARTERA_SAP_LDR(ASIGNACION,ACCOUNTDOCUMENT) VALUES('SAP001','CART001');
DECLARE @run TABLE(RunId uniqueidentifier);
INSERT @run EXEC EAI_OWNER.WOT_BEGIN;
DECLARE @id uniqueidentifier=(SELECT RunId FROM @run),@s varchar(32),@sql nvarchar(max),@o nvarchar(max),@i nvarchar(max);
SET @s=REPLACE(CONVERT(varchar(36),@id),'-','');
SET @o=N'name,createddate,ivydsd__Mobile_Order_Number__c,Retailer_PO_Number__c,ivydsd__Order_Date__c,ivydsd__Delivery_Date__c,id,ivydsd__Store__r.ivybat__SAP_CustomerId__c,ivydsd__Order_Status__c,Delivery_Status__c,Order_Amount__c,CreatedBy.name,CreatedById'+NCHAR(10)+
N'O1,2026-08-20,NUM001,"A,B",2026-08-20,2026-08-21,C1,CL1,Open,Unsuccessful,100,"Ana ""Q""",U1'+NCHAR(10)+
N'O2,2026-05-01,NUM002,PO2,2026-05-01,2026-05-02,C2,CL2,Open,Unsuccessful,200,Bob,U2';
SET @i=N'name,createddate,ivydsd__Mobile_Invoice_Number__c,SAP_Invoice_Number__c,ivydsd__Order__r.name,ivydsd__Order__r.Retailer_PO_Number__c,ivydsd__Order__r.ivydsd__Mobile_Order_Number__c,ivydsd__Invoice_Date__c,id,ivydsd__Store__r.ivybat__SAP_CustomerId__c,Delivery_Status__c,ivydsd__Invoice_Status__c,Gross_Amount__c,createdby.Name,CreatedById'+NCHAR(10)+
N'ABCDEF123-4,2026-08-20,INV001,SAP001,O1,PO1,NUM001,2026-08-20,C1,CL1,Unsuccessful,Open,100,Ana,U1'+NCHAR(10)+
N'ABCDEF567-8,2026-05-01,INV002,SAP002,O2,PO2,NUM002,2026-05-01,C2,CL2,Unsuccessful,Open,200,Bob,U2';
SET @sql=N'INSERT EAI_OWNER.WOT_O_'+@s+N'(RawLine) VALUES(@o); INSERT EAI_OWNER.WOT_I_'+@s+N'(RawLine) VALUES(@i);';
EXEC sys.sp_executesql @sql,N'@o nvarchar(max),@i nvarchar(max)',@o,@i;
EXEC EAI_OWNER.WOT_PROCESS @id,1,'20260825';
IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_ORDER)<>2 OR (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE)<>2
 THROW 52004,'Carga: conteo incorrecto.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WO_TMP_ORDER WHERE ROW_NAME='"O1"' AND CREATEDBY_NAME='"Ana ""Q"""' AND CREATEDBYID='"U1"' AND CREATEDBY IS NULL)
 THROW 52005,'Carga: mapeo del creador.',1;
IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE WHERE DELIVERY_STATUS__C='"Unsuccessful"' AND INSERT_TS='20260825')<>2
 THROW 52006,'Carga: contrato de consumidores compartidos.',1;
IF (SELECT COUNT(*) FROM EAI_OWNER.WOT_OUTPUT WHERE RunId=@id)<>6
 THROW 52007,'Reporte: conteo con encabezados.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WOT_OUTPUT WHERE RunId=@id AND Days=35 AND CsvLine LIKE '%"A,B"%ZLob-Procesada%Comp-Inv-ZLOB')
 THROW 52008,'Reporte: escape CSV, estado o compensacion.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.WOT_OUTPUT WHERE RunId=@id AND Days=35 AND CsvLine LIKE '%SAP002%')
 THROW 52009,'Reporte: ventana de 35 dias.',1;
IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WOT_OUTPUT WHERE RunId=@id AND Days=370 AND CsvLine LIKE '%SAP002%')
 THROW 52010,'Reporte: ventana de 370 dias.',1;
PRINT 'OK load mapping, shared consumers, 35/370 windows, CSV output and clearing';

-- A missing control row must roll back replacement of both inputs.
DELETE @run;
INSERT @run EXEC EAI_OWNER.WOT_BEGIN;
DECLARE @bad uniqueidentifier=(SELECT RunId FROM @run);
SET @s=REPLACE(CONVERT(varchar(36),@bad),'-','');
SET @sql=N'INSERT EAI_OWNER.WOT_O_'+@s+N'(RawLine) VALUES(@o); INSERT EAI_OWNER.WOT_I_'+@s+N'(RawLine) VALUES(@i);';
EXEC sys.sp_executesql @sql,N'@o nvarchar(max),@i nvarchar(max)',@o,@i;
DELETE EAI.CONTROL_REPORTE WHERE REPORTE='AUTO-NOT DELIVERED';
BEGIN TRY
 EXEC EAI_OWNER.WOT_PROCESS @bad,1,'20260826';
 THROW 52011,'No se detecto ausencia del control.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51029 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE WHERE INSERT_TS='20260825')<>2
 THROW 52012,'Falla modifico los datos anteriores.',1;
INSERT EAI.CONTROL_REPORTE(REPORTE) VALUES('AUTO-NOT DELIVERED');
-- Reject invalid numeric values before modifying either destination.
SET @sql=N'UPDATE EAI_OWNER.WOT_O_'+@s+N' SET RawLine=REPLACE(RawLine,N'',100,'',N'',INVALID,'');';
EXEC sys.sp_executesql @sql;
BEGIN TRY
 EXEC EAI_OWNER.WOT_PROCESS @bad,1,'20260826';
 THROW 52013,'No se detecto importe invalido.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51027 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE WHERE INSERT_TS='20260825')<>2
 THROW 52014,'CSV invalido modifico destino.',1;
-- Force an error AFTER deletion/reinsertion begins; verify real rollback.
SET @sql=N'UPDATE EAI_OWNER.WOT_O_'+@s+N' SET RawLine=REPLACE(RawLine,N'',INVALID,'',N'',100,'');';
EXEC sys.sp_executesql @sql;
EXEC(N'CREATE OR ALTER TRIGGER EAI_OWNER.WOT_TEST_FAIL ON EAI_OWNER.WO_TMP_INVOICE AFTER INSERT AS THROW 52015,''Injected failure after replacement'',1;');
BEGIN TRY
 EXEC EAI_OWNER.WOT_PROCESS @bad,1,'20260826';
 THROW 52016,'No se ejecuto el fallo inyectado.',1;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>52015
 BEGIN
   DROP TRIGGER EAI_OWNER.WOT_TEST_FAIL;
   THROW;
 END;
END CATCH;
DROP TRIGGER EAI_OWNER.WOT_TEST_FAIL;
IF (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_INVOICE WHERE INSERT_TS='20260825')<>2
 OR (SELECT COUNT(*) FROM EAI_OWNER.WO_TMP_ORDER)<>2
 THROW 52017,'Rollback no restauro ambas tablas.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.WOT_OUTPUT WHERE RunId=@bad)
 THROW 52018,'Fallo dejo reporte parcial.',1;
EXEC EAI_OWNER.WOT_CLEANUP @bad;
EXEC EAI_OWNER.WOT_CLEANUP @id;
PRINT 'OK failure paths preserve previous input tables';
