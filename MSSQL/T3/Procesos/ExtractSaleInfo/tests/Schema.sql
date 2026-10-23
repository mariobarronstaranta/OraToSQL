-- Datos sinteticos para consultas/exportador. No instalar en una base de negocio.
CREATE SCHEMA EAI;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA T3;
GO
CREATE TABLE EAI.FC__TIME_WINDOW(Start_Date varchar(19), End_Date varchar(19), Mandant varchar(3));
INSERT EAI.FC__TIME_WINDOW VALUES(CONVERT(char(10),DATEADD(day,-20,GETDATE()),103),CONVERT(char(10),DATEADD(day,2,GETDATE()),103),'QA');
CREATE TABLE EAI.CFDI_BITACORA(
 Doc_Num varchar(30), Nota_Venta_CFDI varchar(30), Invc_dt datetime2, Ctro varchar(4),
 Cliente_SAP varchar(10), Tipo_Vta varchar(4), SF_Amount decimal(15,3), SAP_Amount decimal(15,3),
 Valor_Subt decimal(15,3), Valor_IVA decimal(15,3), Envio_Subt decimal(15,3),
 Envio_IVA decimal(15,3), Credito_Subt decimal(15,3), Credito_IVA decimal(15,3));
CREATE TABLE EAI.CFDI_INFORME(Folio_Interno varchar(30), Folio_Fiscal varchar(40), Addenda varchar(2), Valor_Subt decimal(15,3), Valor_IVA decimal(15,3));
CREATE TABLE T3.PREVENTA_GENERAL(Factura varchar(30), Entrega varchar(30), Fecha_Cancelacion datetime2, Fecha_Proc_BATMD datetime2);
CREATE TABLE T3.MOV_CLIENTE(Cliente_SAP varchar(10), Nombre nvarchar(100));
CREATE TABLE EAI_OWNER.DOCTOS_CANCELLED(Referencia varchar(30));
CREATE TABLE T3.CFDI_DOCUMENTOS(Nota_Venta varchar(30), Fecha_Liberacion datetime2, Fecha_Envio datetime2);
CREATE TABLE EAI.CIFRAS_COMENTARIOS(Referencia varchar(30), Comentarios nvarchar(max));
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_HEADER(ReferenceID varchar(30), MetodoPago varchar(99));
CREATE TABLE T3.CFDI_REFOLEO(Docto_T3MX varchar(30), Docto_SAP varchar(30), Tipo_Registro varchar(10));
CREATE TABLE EAI_OWNER.FACTURAS_B(Doc_Num varchar(30), Cte_SAP varchar(10), Invc_dt varchar(1024), Proof_of_Delivery__C nvarchar(100));
CREATE TABLE EAI_OWNER.CLIENT(Cliente_SAP varchar(10), RFC varchar(20));
CREATE TABLE EAI.CONTROL_REPORTE(Reporte nvarchar(100), Inicio datetime2, Fin datetime2);
INSERT EAI.CONTROL_REPORTE(Reporte) VALUES('AUTO-CIFRAS VENTAS'),('AUTO-CIFRAS VENTAS DIFF');
CREATE TABLE EAI.TestPreparacion(Llamadas int, Fallar bit);
INSERT EAI.TestPreparacion VALUES(0,0);
GO
-- Doble de prueba: valida orden/invocacion y propagacion de errores del caller.
-- No pretende validar la logica interna del procedimiento compartido.
CREATE PROCEDURE EAI.SF_BITACORA_CFDI_VENTA_SF @nEtapa int=0 AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM EAI.TestPreparacion WHERE Fallar=1)
    THROW 54999,'Fallo de preparacion simulado.',1;
 UPDATE EAI.TestPreparacion SET Llamadas=Llamadas+1;
END;
GO
INSERT T3.MOV_CLIENTE VALUES('C1',N' Compañía, "QA" ');
INSERT T3.CFDI_REFOLEO VALUES('A','SAP-A','Venta');
INSERT T3.PREVENTA_GENERAL VALUES('A','EntregaA',NULL,NULL),('D','Original',GETDATE(),GETDATE()),('Rev0001','Reversa',GETDATE(),GETDATE());
INSERT EAI_OWNER.TMP_DOCUMENT_HEADER VALUES('Original','Rev0001'),('Reversa',NULL);
INSERT EAI.CFDI_BITACORA VALUES
('A','A',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100,100,100,0,0,0,0,0),
('B','B',DATEADD(day,-1,GETDATE()),'0001','C1','Dev',-100,-100,-100,0,0,0,0,0),
('C','C',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',110,110,100,0,0,0,10,0),
('D','G-D',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100,90,100,0,0,0,0,0),
('E','OTHER',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100,100,100,0,0,0,0,0),
('F','F',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100.05,100,100,0,0,0,0,0),
('G','G',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100.051,100,100,0,0,0,0,0),
('H','H',DATEADD(day,-1,GETDATE()),'0001','MISSING',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
('N','N',DATEADD(day,-1,GETDATE()),'0001','C1','Dev',-120,-100,-100,0,0,0,0,0),
('X','X',DATEADD(day,-1,GETDATE()),'0001','C1','Vta',100,100,100,0,0,0,0,0),
('TODAY','TODAY',GETDATE(),'0001','C1','Vta',100,100,100,0,0,0,0,0),
('FUTURE','FUTURE',DATEADD(day,1,GETDATE()),'0001','C1','Vta',100,100,100,0,0,0,0,0),
('OLD','OLD',DATEADD(day,-21,GETDATE()),'0001','C1','Vta',100,100,100,0,0,0,0,0);
INSERT EAI.CFDI_INFORME VALUES('A','UUID-A',NULL,100,0),('C',NULL,'SI',0,0),('F','UUID-F',NULL,100,0),('G','UUID-G',NULL,100,0);
INSERT EAI_OWNER.DOCTOS_CANCELLED VALUES('X');
INSERT T3.CFDI_DOCUMENTOS VALUES('G-D',NULL,'2026-07-01T12:34:56');
INSERT EAI.CIFRAS_COMENTARIOS VALUES('D',N'Comentario, "QA"'+NCHAR(13)+NCHAR(10)+REPLICATE(CONVERT(nvarchar(max),N'z'),6000));
INSERT EAI_OWNER.CLIENT VALUES('C1','SEM980701STA'),('C2','OTRO');
INSERT EAI_OWNER.FACTURAS_B VALUES
('P0','C1',CONVERT(char(10),GETDATE(),23),N'POD,"QA"'),
('P10','C1',CONVERT(char(10),DATEADD(day,-10,GETDATE()),23),N'Limite'),
('P11','C1',CONVERT(char(10),DATEADD(day,-11,GETDATE()),23),N'Fuera'),
('PF','C1',CONVERT(char(10),DATEADD(day,2,GETDATE()),23),N'Futuro'),
('PN','C1',CONVERT(char(10),GETDATE(),23),NULL),
('PE','C1',CONVERT(char(10),GETDATE(),23),N''),
('PR','C2',CONVERT(char(10),GETDATE(),23),N'Otro RFC');
