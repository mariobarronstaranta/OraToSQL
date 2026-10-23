CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA T3;
GO
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_HEADER
 (ReferenceID varchar(30), FacturaSAP varchar(30), DeliveryType varchar(10));
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_DETAIL
 (ReferenceID varchar(30), ItemID varchar(30), Material varchar(18), UnidadMedida varchar(10),
 Status_Producto varchar(10), Cantidad decimal(22,7), Valor_Subt decimal(22,7),
 Valor_IVA decimal(22,7), Bonif_Subt decimal(22,7), Envio_Subt decimal(22,7), Credito_Subt decimal(22,7));
CREATE TABLE T3.Material
 (Material varchar(18), Unidad_Med_Vta varchar(10), Cig_x_CLL decimal(22,7), Nombre_Material varchar(50));
CREATE TABLE T3.Preventa_General (Factura varchar(30), Entrega varchar(30));
CREATE TABLE T3.Preventa_Detalle
 (Factura varchar(30), Num_Linea int, Envio_Subt decimal(22,7), Envio_IVA decimal(22,7));
INSERT EAI_OWNER.TMP_DOCUMENT_HEADER VALUES ('TEST','FACTURA','C030');
INSERT EAI_OWNER.TMP_DOCUMENT_DETAIL (ReferenceID,ItemID,Material,Cantidad) VALUES
 ('TEST','1','1',NULL),('TEST','1','1',NULL),
 ('TEST','2','2',NULL),('TEST','2','2',-5),('TEST','2','2',2),
 ('TEST','3','3',0),('TEST','4','4',7),('TEST','4','4',7);
-- Ausencia, todo NULL, mezcla con negativos, vacios, duplicados.
INSERT T3.Material VALUES ('2',NULL,NULL,NULL),('2','',-8,NULL),('2','UA',-2,NULL),
 ('3',NULL,NULL,NULL),('4','CAJ',10,NULL),('4','CAJ',10,NULL),
 ('88000117','UA',NULL,'ENVIO');
INSERT T3.Preventa_General VALUES ('TEST','ENTREGA');
INSERT T3.Preventa_Detalle VALUES ('TEST',NULL,1,NULL),('TEST',-30,2,1),('TEST',-20,NULL,2);
GO
