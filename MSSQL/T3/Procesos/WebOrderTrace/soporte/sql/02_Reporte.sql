SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE EAI_OWNER.WOT_REPORT
 @RunId uniqueidentifier, @Days int, @AsOf datetime2(0)
AS
BEGIN
 SET NOCOUNT ON;
 IF @Days NOT IN(35,370) THROW 51010,'Periodo permitido: 35 o 370 dias.',1;
 DECLARE @since date=CONVERT(date,DATEADD(day,-@Days,@AsOf));
 DELETE EAI_OWNER.WOT_OUTPUT WHERE RunId=@RunId AND Days=@Days;
 INSERT EAI_OWNER.WOT_OUTPUT VALUES(@RunId,@Days,0,
 N'ORD_ID,ORD_ORDER_NUM,ORD_RETAILER_PO,ORD_CLIENTE,ORD_FECHA,ORD_AMOUNT,ORD_STATUS,INV_DOC_NUM,INV_CLIENTE,INV_FECHA,INV_DELIVERY_STATUS,ORD_DELIVERY_STATUS,ZLOB_REFERENCE,ORDEN_STATUS,INV_PLANTA,INV_FACTURA_SAP,INV_FECHA_TRN,INV_PROC_BATMD,INV_FECHA_CANC,INV_CARTERA,ZLOB_FACTURA_SAP,ZLOB_FECHA_TRN,ZLOB_PROC_BATMD,ZLOB_FECHA_CANC,ZLOB_CARTERA,CLEARING_STATUS');
 ;WITH Orders AS
 (
 SELECT NULLIF(REPLACE(Row_Name,'"',''),'') Ord_ID,
 NULLIF(REPLACE(ivydsd__Mobile_Order_Number__c,'"',''),'') Ord_Order_Num,
 NULLIF(REPLACE(Retailer_PO_Number__c,'"',''),'') Ord_Retailer_PO,
 NULLIF(REPLACE(ivybat__SAP_CustomerId__c,'"',''),'') Ord_Cliente,
 NULLIF(REPLACE(ivydsd__Order_Date__c,'"',''),'') Ord_Fecha,
 NULLIF(REPLACE(ivydsd__Order_Status__c,'"',''),'') Ord_Status,
 NULLIF(REPLACE(Delivery_Status__c,'"',''),'') Ord_Delivery_Status,
 CONVERT(decimal(15,2),NULLIF(REPLACE(Order_Amount__c,'"',''),'')) Ord_Amount
 FROM EAI_OWNER.WO_TMP_ORDER
 WHERE UPPER(REPLACE(Row_Name,'"',''))<>'NAME'
 ), Invoices AS
 (
 SELECT NULLIF(REPLACE(Row_Name,'"',''),'') Inv_ID,
 NULLIF(REPLACE(Mobile_Invoice_Number__c,'"',''),'') Inv_Doc_Num,
 NULLIF(REPLACE(ivydsd__Order__r_Name,'"',''),'') Inv_Order_ID,
 NULLIF(REPLACE(ivydsd__Invoice_Date__c,'"',''),'') Inv_Fecha,
 NULLIF(REPLACE(ivybat__SAP_CustomerId__c,'"',''),'') Inv_Cliente,
 NULLIF(REPLACE(Delivery_Status__c,'"',''),'') Inv_Delivery_Status,
 CASE WHEN REPLACE(Delivery_Status__c,'"','') COLLATE Latin1_General_100_BIN2='Unsuccessful'
 THEN 'L'+REPLACE(SUBSTRING(REPLACE(Row_Name,'"',''),7,20),'-','') END ZLOB_Reference
 FROM EAI_OWNER.WO_TMP_INVOICE
 WHERE UPPER(REPLACE(Row_Name,'"',''))<>'NAME'
 ), Cart AS
 (
 SELECT Asignacion,Referencia,Cargo,AccountDocument
 FROM EAI.TAO_CARTERA_SAP_LDR
 GROUP BY Asignacion,Referencia,Cargo,AccountDocument
 ), Preventa AS
 (
 -- Grouping and detail existence retained from Oracle. The unused Importe
 -- aggregate is omitted; no cardinality-changing DISTINCT is introduced.
 SELECT PG.Factura,PG.Ctro,PG.Fecha_Factura,PG.Fecha_Trn,PG.Clase_Factura,
 PG.Cliente_SAP,PG.Entrega,PG.Pedido,PG.Referencia,PG.Fecha_Proc_BATMD,PG.Fecha_Cancelacion,
 MAX(Cart.AccountDocument) Cartera
 FROM T3.PREVENTA_GENERAL PG
 JOIN T3.PREVENTA_DETALLE PD ON PG.Factura=PD.Factura
 LEFT JOIN Cart ON PG.Entrega=Cart.Asignacion
 WHERE PG.Fecha_Factura>=@since
 AND ((PG.Clase_Factura='C005' AND PG.Factura NOT LIKE 'L%')
 OR (PG.Clase_Factura='C006' AND PG.Factura LIKE 'L%'))
 GROUP BY PG.Factura,PG.Ctro,PG.Fecha_Factura,PG.Fecha_Trn,PG.Clase_Factura,
 PG.Cliente_SAP,PG.Entrega,PG.Pedido,PG.Referencia,PG.Fecha_Proc_BATMD,PG.Fecha_Cancelacion
 ), Inv AS
 (
 SELECT Factura,Ctro,Fecha_Factura,Fecha_Trn,Cliente_SAP,Entrega,Pedido,Referencia,
 Fecha_Proc_BATMD,Fecha_Cancelacion,Cartera FROM Preventa WHERE Clase_Factura='C005'
 UNION ALL
 SELECT PG.Factura,PG.Ctro,PG.Fecha_Factura,PG.Fecha_Trn,PG.Cliente_SAP,PG.Entrega,PG.Pedido,
 PG.Referencia,PG.Fecha_Proc_BATMD,CAST(NULL AS datetime2(0)),MAX(Cart.AccountDocument)
 FROM T3.FACTURA_GENERAL PG
 JOIN T3.FACTURA_DETALLE PD ON PG.Factura=PD.Factura
 LEFT JOIN Cart ON PG.Entrega=Cart.Asignacion
 WHERE PG.Fecha_Factura>=@since AND PG.Tipo_Docto='C003' AND PG.Factura LIKE 'H2%'
 GROUP BY PG.Factura,PG.Ctro,PG.Fecha_Factura,PG.Fecha_Trn,PG.Tipo_Docto,PG.Cliente_SAP,
 PG.Entrega,PG.Pedido,PG.Referencia,PG.Fecha_Proc_BATMD
 ), Info AS
 (
 SELECT ROW_NUMBER() OVER(ORDER BY O.Ord_ID,I.Inv_ID,Inv.Factura,Z.Factura,Inv.Entrega,Z.Entrega) Seq,
 O.*,I.Inv_Doc_Num,I.Inv_Cliente,I.Inv_Fecha,I.Inv_Delivery_Status,I.ZLOB_Reference,
 CASE
 WHEN I.Inv_Delivery_Status='Delivered' AND I.ZLOB_Reference IS NULL
 AND Inv.Fecha_Proc_BATMD<@AsOf AND Inv.Fecha_Cancelacion IS NULL THEN 'Inv-Procesada'
 WHEN I.Inv_Delivery_Status='Unsuccessful' AND I.ZLOB_Reference IS NOT NULL
 AND Inv.Fecha_Proc_BATMD<@AsOf AND Inv.Fecha_Cancelacion IS NULL
 AND Z.Fecha_Proc_BATMD<@AsOf AND Z.Fecha_Cancelacion IS NULL THEN 'ZLob-Procesada'
 WHEN O.Ord_Delivery_Status='Delivered' AND I.ZLOB_Reference IS NULL
 AND Inv.Fecha_Proc_BATMD<@AsOf AND Inv.Fecha_Cancelacion IS NULL THEN 'Ord-Procesada'
 WHEN O.Ord_Status='Rejected by SAP' THEN 'Ord-Cancelada' ELSE '' END Orden_Status,
 Inv.Ctro Inv_Planta,Inv.Entrega Inv_Factura_SAP,
 CONVERT(varchar(16),Inv.Fecha_Trn,120) Inv_Fecha_Trn,
 CONVERT(varchar(16),Inv.Fecha_Proc_BATMD,120) Inv_Proc_BATMD,
 CONVERT(varchar(16),Inv.Fecha_Cancelacion,120) Inv_Fecha_Canc,Inv.Cartera Inv_Cartera,
 Z.Entrega ZLOB_Factura_SAP,
 CONVERT(varchar(16),Z.Fecha_Trn,120) ZLOB_Fecha_Trn,
 CONVERT(varchar(16),Z.Fecha_Proc_BATMD,120) ZLOB_Proc_BATMD,
 CONVERT(varchar(16),Z.Fecha_Cancelacion,120) ZLOB_Fecha_Canc,Z.Cartera ZLOB_Cartera,
 EAI_OWNER.GET_CLEARING_STATUS(I.Inv_Doc_Num,I.ZLOB_Reference,O.Ord_Amount) Clearing_Status
 FROM Orders O
 LEFT JOIN Invoices I ON O.Ord_ID=I.Inv_Order_ID
 LEFT JOIN Inv ON O.Ord_Order_Num=Inv.Factura
 LEFT JOIN Preventa Z ON I.ZLOB_Reference=Z.Factura AND Z.Clase_Factura='C006'
 WHERE I.Inv_Delivery_Status COLLATE Latin1_General_100_BIN2='Unsuccessful'
 )
 INSERT EAI_OWNER.WOT_OUTPUT(RunId,Days,Seq,CsvLine)
 SELECT @RunId,@Days,Info.Seq,Csv.CsvLine
 FROM Info
 CROSS APPLY
 (
 SELECT STRING_AGG(CONVERT(nvarchar(max),
 CASE WHEN CHARINDEX(N',',V.Val)>0 OR CHARINDEX(N'"',V.Val)>0
 OR CHARINDEX(NCHAR(13),V.Val)>0 OR CHARINDEX(NCHAR(10),V.Val)>0
 THEN N'"'+REPLACE(V.Val,N'"',N'""')+N'"' ELSE ISNULL(V.Val,N'') END),N',')
 WITHIN GROUP(ORDER BY V.Pos) CsvLine
 FROM (VALUES
 (1,CONVERT(nvarchar(max),Ord_ID)),(2,CONCAT(N'''',Ord_Order_Num)),
 (3,Ord_Retailer_PO),(4,Ord_Cliente),(5,Ord_Fecha),
 (6,FORMAT(ISNULL(Ord_Amount,0),'0.##','en-US')),(7,Ord_Status),
 (8,Inv_Doc_Num),(9,Inv_Cliente),(10,Inv_Fecha),(11,Inv_Delivery_Status),
 (12,Ord_Delivery_Status),(13,ZLOB_Reference),(14,Orden_Status),
 (15,Inv_Planta),(16,Inv_Factura_SAP),(17,Inv_Fecha_Trn),(18,Inv_Proc_BATMD),
 (19,Inv_Fecha_Canc),(20,Inv_Cartera),(21,ZLOB_Factura_SAP),
 (22,ZLOB_Fecha_Trn),(23,ZLOB_Proc_BATMD),(24,ZLOB_Fecha_Canc),
 (25,ZLOB_Cartera),(26,Clearing_Status)) V(Pos,Val)
 ) Csv;
END;
GO
