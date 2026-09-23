SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_PROCESS
 @RunId uniqueidentifier,
 @Load bit=1,
 @AsOf datetime2(0)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @AsOf IS NULL SET @AsOf=SYSDATETIME();
 IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WOT_RUN WHERE RunId=@RunId AND State='CREATED')
 THROW 51020,'La ejecucion no existe o ya fue procesada.',1;
 CREATE TABLE #Cells(Kind char(1),RowNo int,ColNo int,Value nvarchar(max),RawValue varchar(512));
 CREATE TABLE #Parsed(RowNo int,ColNo int,Value nvarchar(max));
 DECLARE @expected TABLE(Kind char(1),ColNo int,Name nvarchar(128));
 INSERT @expected VALUES
 ('O',1,'name'),('O',2,'createddate'),('O',3,'ivydsd__Mobile_Order_Number__c'),
 ('O',4,'Retailer_PO_Number__c'),('O',5,'ivydsd__Order_Date__c'),('O',6,'ivydsd__Delivery_Date__c'),
 ('O',7,'id'),('O',8,'ivydsd__Store__r.ivybat__SAP_CustomerId__c'),
 ('O',9,'ivydsd__Order_Status__c'),('O',10,'Delivery_Status__c'),('O',11,'Order_Amount__c'),
 ('O',12,'CreatedBy.name'),('O',13,'CreatedById'),
 ('I',1,'name'),('I',2,'createddate'),('I',3,'ivydsd__Mobile_Invoice_Number__c'),
 ('I',4,'SAP_Invoice_Number__c'),('I',5,'ivydsd__Order__r.name'),
 ('I',6,'ivydsd__Order__r.Retailer_PO_Number__c'),('I',7,'ivydsd__Order__r.ivydsd__Mobile_Order_Number__c'),
 ('I',8,'ivydsd__Invoice_Date__c'),('I',9,'id'),('I',10,'ivydsd__Store__r.ivybat__SAP_CustomerId__c'),
 ('I',11,'Delivery_Status__c'),('I',12,'ivydsd__Invoice_Status__c'),('I',13,'Gross_Amount__c'),
 ('I',14,'createdby.Name'),('I',15,'CreatedById');
 DECLARE @kind char(1)='O',@sql nvarchar(max),@text nvarchar(max),@lock int,
 @suffix varchar(32)=REPLACE(CONVERT(varchar(36),@RunId),'-','');
 IF @Load=1
 BEGIN
 WHILE 1=1
 BEGIN
   SET @sql=N'SELECT @text=STRING_AGG(CONVERT(nvarchar(max),ISNULL(RawLine,N'''')),NCHAR(10)) WITHIN GROUP(ORDER BY [LineNo]) FROM EAI_OWNER.WOT_'+@kind+'_'+@suffix+N';';
   EXEC sys.sp_executesql @sql,N'@text nvarchar(max) OUTPUT',@text OUTPUT;
   IF @text IS NULL OR DATALENGTH(@text)>104857600
     THROW 51021,'CSV vacio o mayor a 100 MB de texto Unicode.',1;
   INSERT #Parsed EXEC EAI_OWNER.WOT_PARSE_CSV @text;
   INSERT #Cells(Kind,RowNo,ColNo,Value) SELECT @kind,RowNo,ColNo,Value FROM #Parsed;
   TRUNCATE TABLE #Parsed;
   IF @kind='I' BREAK;
   SET @kind='I';
 END;
 IF EXISTS(SELECT 1 FROM #Cells GROUP BY Kind,RowNo HAVING COUNT(*)<>CASE Kind WHEN 'O' THEN 13 ELSE 15 END)
   THROW 51022,'CSV: numero de columnas distinto del contrato (13 orden, 15 factura).',1;
 IF EXISTS(SELECT 1 FROM @expected E LEFT JOIN #Cells C ON C.Kind=E.Kind AND C.RowNo=1 AND C.ColNo=E.ColNo
 WHERE C.Value IS NULL OR C.Value COLLATE Latin1_General_100_CI_AS<>E.Name COLLATE Latin1_General_100_CI_AS)
   THROW 51023,'CSV: encabezados distintos del contrato esperado.',1;
 DELETE #Cells WHERE RowNo=1;
 IF NOT EXISTS(SELECT 1 FROM #Cells WHERE Kind='O') OR NOT EXISTS(SELECT 1 FROM #Cells WHERE Kind='I')
   THROW 51024,'CSV sin filas de datos: no se reemplazan las tablas.',1;
 -- Canonical quoted storage preserves consumers comparing to '"Unsuccessful"'.
 -- Fail on truncation or characters not representable in the database code page.
 IF EXISTS(SELECT 1 FROM #Cells WHERE
 DATALENGTH(CONVERT(varchar(max),N'"'+REPLACE(Value,N'"',N'""')+N'"'))>512 OR
 CONVERT(nvarchar(max),CONVERT(varchar(max),Value)) COLLATE Latin1_General_100_BIN2
 <>Value COLLATE Latin1_General_100_BIN2)
   THROW 51025,'CSV: valor mayor a 512 bytes o caracter no representable en destino.',1;
 IF EXISTS(SELECT 1 FROM #Cells WHERE ColNo=1 AND NULLIF(LTRIM(RTRIM(Value)),N'') IS NULL)
   THROW 51026,'CSV: identificador NAME vacio.',1;
 IF EXISTS(SELECT 1 FROM #Cells WHERE (Kind='O' AND ColNo=11 OR Kind='I' AND ColNo=13)
 AND NULLIF(Value,N'') IS NOT NULL AND
 (TRY_CONVERT(decimal(15,2),Value) IS NULL OR CHARINDEX(N',',Value)>0
 OR TRY_CONVERT(decimal(38,10),Value)<>TRY_CONVERT(decimal(15,2),Value)))
   THROW 51027,'CSV: importe invalido; punto decimal, maximo dos decimales, sin separador de miles.',1;
 UPDATE #Cells SET RawValue=CONVERT(varchar(512),N'"'+REPLACE(Value,N'"',N'""')+N'"');
 END;
 BEGIN TRY
 BEGIN TRAN;
 EXEC @lock=sys.sp_getapplock @Resource='WebOrderTrace.LoadAndReport',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @lock<0 THROW 51028,'Otra ejecucion WebOrderTrace esta procesando; reintente mas tarde.',1;
 UPDATE EAI_OWNER.WOT_RUN WITH(UPDLOCK) SET State='PROCESSING' WHERE RunId=@RunId AND State='CREATED';
 IF @@ROWCOUNT<>1 THROW 51020,'La ejecucion ya fue procesada.',1;
 IF (SELECT COUNT(*) FROM EAI.CONTROL_REPORTE WHERE REPORTE='AUTO-NOT DELIVERED')<>1
   THROW 51029,'CONTROL_REPORTE requiere exactamente una fila AUTO-NOT DELIVERED.',1;
 IF @Load=1
 BEGIN
 -- Table locks keep replacement of both inputs atomic for normal readers.
 DELETE FROM EAI_OWNER.WO_TMP_ORDER WITH(TABLOCKX);
 DELETE FROM EAI_OWNER.WO_TMP_INVOICE WITH(TABLOCKX);
 INSERT EAI_OWNER.WO_TMP_ORDER
 (ROW_NAME,CREATEDDATE,IVYDSD__MOBILE_ORDER_NUMBER__C,RETAILER_PO_NUMBER__C,
 IVYDSD__ORDER_DATE__C,IVYDSD__DELIVERY_DATE__C,CUSTOMER_ID,IVYBAT__SAP_CUSTOMERID__C,
 IVYDSD__ORDER_STATUS__C,DELIVERY_STATUS__C,ORDER_AMOUNT__C,CREATEDBY_NAME,CREATEDBYID)
 SELECT MAX(CASE ColNo WHEN 1 THEN RawValue END),MAX(CASE ColNo WHEN 2 THEN RawValue END),
 MAX(CASE ColNo WHEN 3 THEN RawValue END),MAX(CASE ColNo WHEN 4 THEN RawValue END),
 MAX(CASE ColNo WHEN 5 THEN RawValue END),MAX(CASE ColNo WHEN 6 THEN RawValue END),
 MAX(CASE ColNo WHEN 7 THEN RawValue END),MAX(CASE ColNo WHEN 8 THEN RawValue END),
 MAX(CASE ColNo WHEN 9 THEN RawValue END),MAX(CASE ColNo WHEN 10 THEN RawValue END),
 MAX(CASE ColNo WHEN 11 THEN RawValue END),MAX(CASE ColNo WHEN 12 THEN RawValue END),
 MAX(CASE ColNo WHEN 13 THEN RawValue END)
 FROM #Cells WHERE Kind='O' GROUP BY RowNo;
 UPDATE EAI_OWNER.WOT_RUN SET OrderRows=@@ROWCOUNT WHERE RunId=@RunId;
 INSERT EAI_OWNER.WO_TMP_INVOICE
 (ROW_NAME,CREATEDDATE,MOBILE_INVOICE_NUMBER__C,SAP_INVOICE_NUMBER__C,IVYDSD__ORDER__R_NAME,
 ORDER_RETAILER_PO_NUMBER__C,MOBILE_ORDER_NUMBER__C,IVYDSD__INVOICE_DATE__C,CUSTOMER_ID,
 IVYBAT__SAP_CUSTOMERID__C,DELIVERY_STATUS__C,IVYDSD__INVOICE_STATUS__C,GROSS_AMOUNT__C,
 CREATEDBY_NAME,CREATEDBYID,INSERT_TS)
 SELECT MAX(CASE ColNo WHEN 1 THEN RawValue END),MAX(CASE ColNo WHEN 2 THEN RawValue END),
 MAX(CASE ColNo WHEN 3 THEN RawValue END),MAX(CASE ColNo WHEN 4 THEN RawValue END),
 MAX(CASE ColNo WHEN 5 THEN RawValue END),MAX(CASE ColNo WHEN 6 THEN RawValue END),
 MAX(CASE ColNo WHEN 7 THEN RawValue END),MAX(CASE ColNo WHEN 8 THEN RawValue END),
 MAX(CASE ColNo WHEN 9 THEN RawValue END),MAX(CASE ColNo WHEN 10 THEN RawValue END),
 MAX(CASE ColNo WHEN 11 THEN RawValue END),MAX(CASE ColNo WHEN 12 THEN RawValue END),
 MAX(CASE ColNo WHEN 13 THEN RawValue END),MAX(CASE ColNo WHEN 14 THEN RawValue END),
 MAX(CASE ColNo WHEN 15 THEN RawValue END),@AsOf
 FROM #Cells WHERE Kind='I' GROUP BY RowNo;
 UPDATE EAI_OWNER.WOT_RUN SET InvoiceRows=@@ROWCOUNT WHERE RunId=@RunId;
 END;
 EXEC EAI_OWNER.WOT_REPORT @RunId,35,@AsOf;
 EXEC EAI_OWNER.WOT_REPORT @RunId,370,@AsOf;
 UPDATE EAI_OWNER.WOT_RUN SET State='READY',Finished=SYSDATETIME() WHERE RunId=@RunId;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_MARK_PUBLISHED @RunId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM EAI_OWNER.WOT_RUN WHERE RunId=@RunId AND State='READY')
 THROW 51030,'La ejecucion no esta lista para publicacion.',1;
 BEGIN TRY
 BEGIN TRAN;
 UPDATE C SET INICIO=R.Started,FIN=SYSDATETIME()
 FROM EAI.CONTROL_REPORTE C CROSS JOIN EAI_OWNER.WOT_RUN R
 WHERE C.REPORTE='AUTO-NOT DELIVERED' AND R.RunId=@RunId;
 IF @@ROWCOUNT<>1 THROW 51031,'CONTROL_REPORTE debe tener exactamente una fila para el reporte.',1;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
GO
