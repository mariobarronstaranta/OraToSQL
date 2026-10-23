/* Pruebas de caracterizacion: un PASS confirma una DIFERENCIA reproducida
   o una regla conservada, segun el texto. No son pruebas de equivalencia.
   Se ejecuta el nombre que realmente declara el archivo, sin renombrarlo.
*/
SET NOCOUNT ON;
IF OBJECT_ID('EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO','P') IS NULL
 OR OBJECT_ID('EAI.SF_CFDI_OPEN_ITEMS','P') IS NOT NULL
 THROW 55200,'La declaracion de nombre ya cambio; actualizar diagnostico.',1;
PRINT 'D01 confirmado: archivo principal declara solamente _OPTIMIZADO';
INSERT EAI_OWNER.MX_COMPONENTS (Component,Status) VALUES (923,1);

-- Final: mismo folio con dos clientes. Oracle resuelve cada cliente por fila.
INSERT T3.Mov_Cliente (Cliente_SAP,RFC,Ctro) VALUES ('C1','RFC1','0001'),('C2','RFC2','0002');
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Cliente_SAP,Ctro,Tipo_Docto,Importe_Vta,PedidoSAP,FacturaSAP)
VALUES ('F','C1','OLD','Vta',10,'PED_OLD','FAC_OLD'),
 ('F','C2','OLD','Vta',10,'PED_OLD','FAC_OLD'),
 ('MISSING','C0','OLD','Vta',10,NULL,NULL),('DNULL','C1','OLD','Dev',NULL,NULL,NULL);
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 100;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='F' AND Cliente_SAP='C1' AND RFC='RFC2')
 THROW 55201,'No se reprodujo mezcla de clientes.',1;
PRINT 'D02 confirmado: RFC/Ctro calculados por folio mezclan clientes; Oracle espera RFC1 en C1';
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='MISSING' AND Ctro='OLD')
 THROW 55202,'No se reprodujo centro antiguo.',1;
PRINT 'D03 confirmado: sin Mov_Cliente conserva centro antiguo; Oracle lo pone NULL';
IF (SELECT COUNT(*) FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='F' AND PedidoSAP='PED_OLD' AND FacturaSAP='FAC_OLD')<>2
 THROW 55203,'No se reprodujeron referencias antiguas.',1;
PRINT 'D04 confirmado: sin RF conserva referencias; Oracle pone ambas NULL';
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='DNULL' AND Importe_Vta=0)
 THROW 55204,'No se reprodujo NULL convertido a cero.',1;
PRINT 'D05 confirmado: importe NULL pasa a cero; Oracle NULL+0 queda NULL';

-- Etapa 30: agregado escalar sin filas frente a INNER JOIN agrupado.
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Tipo_Docto,Importe_NC,Incobrable,Fecha_Aplicacion)
VALUES ('SIN','Dev',99,88,'20260101');
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 30;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='SIN' AND Importe_NC=99 AND Incobrable=88)
 THROW 55205,'No se reprodujeron aplicaciones antiguas.',1;
PRINT 'D06 confirmado: devolucion sin cobranza conserva aplicaciones; Oracle las pone NULL';
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=(SELECT MAX(PID) FROM T3.RF_PROCESOS_LOG) AND Proceso_2=0)
 THROW 55206,'Conteo inesperado.',1;
PRINT 'D07 confirmado: P2=0 para devolucion sin cobranza; Oracle cuenta 1';

-- Venta NULL y venta sin cobranza. ScrCobza de Oracle SI tiene GROUP BY.
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Tipo_Docto,Importe) VALUES ('VN','Vta',77),('VS','Vta',77);
INSERT T3.CFDI_Cobranza (Factura,Asignacion_ID,Importe,Via_Pago) VALUES ('VN','A',NULL,'01');
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 20;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='VN' AND Importe=0 AND Efectivo=0)
 THROW 55207,'No se reprodujo suma nula.',1;
PRINT 'D08 confirmado: SUM de importe/efectivo NULL pasa a cero; Oracle queda NULL';
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='VS' AND Importe=77)
 THROW 55208,'Venta sin cobranza no debe actualizarse.',1;
PRINT 'R01 conservada: venta sin cobranza conserva importe (distinto de devoluciones)';
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=(SELECT MAX(PID) FROM T3.RF_PROCESOS_LOG) AND Proceso_2=1)
 THROW 55209,'Conteo ventas inesperado.',1;
PRINT 'D09 confirmado: P2 ventas=1; Oracle recorre ambas y cuenta 2';

-- Timbrado es suma de tres indicadores, no booleano.
DELETE EAI.CFDI_OPEN_ITEMS; DELETE T3.CFDI_Cobranza;
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Tipo_Docto) VALUES ('VT','Vta');
INSERT T3.CFDI_Cobranza (Factura,Asignacion_ID,Nota_Credito,Importe,Via_Pago) VALUES ('VT','P','N',10,'01');
INSERT T3.CFDI_Documentos (Nota_Venta,Folio_Fiscal) VALUES ('P','UP'),('N','UN'),('123','UG');
INSERT T3.CFDI_Agrupacion_Pago (Agrupacion,Asignacion_ID) VALUES (123,'P');
INSERT T3.CFDI_Agrupacion_Ctrl (Agrupacion,Importe) VALUES (123,10);
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 20;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='VT' AND Importe=10 AND Importe_UUID=30)
 THROW 55210,'Regla de Timbrado 0..3 incorrecta.',1;
PRINT 'R02 conservada: importe 10 con tres UUID produce Importe_UUID=30';

-- Fiscal: dos filas OI multiplican SUM Oracle, DISTINCT SQL lo elimina.
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Tipo_Docto) VALUES ('FD','Vta'),('FD','Vta');
INSERT T3.Registro_Fiscal (Factura,Cliente_SAP,Ctro) VALUES ('FD','C1','0001');
INSERT T3.Registro_Fiscal_Detalle (Factura,Valor_Subt,Valor_IVA) VALUES ('FD',100,16);
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 60;
IF (SELECT COUNT(*) FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='FD' AND Importe_Vta=116)<>2
 THROW 55211,'No se reprodujo deduplicacion fiscal.',1;
PRINT 'D10 confirmado: SQL da 116 por fila; JOIN Oracle da 232 por fila';
IF NOT EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG WHERE PID=(SELECT MAX(PID) FROM T3.RF_PROCESOS_LOG) AND Proceso_3=2)
 THROW 55212,'Conteo fiscal inesperado.',1;
PRINT 'D11 confirmado: SQL P3=2 destinos, Oracle cuenta 1 grupo fiscal';

-- Referencia escalar Oracle devuelve error con varias cabeceras.
INSERT T3.Registro_Fiscal (Factura,Pedido,Entrega) VALUES ('FD','P2','E2');
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 100;
PRINT 'D12 confirmado: RF duplicado no falla en SQL; subconsulta escalar Oracle falla';

-- Historico existente con Last_Updated NULL es elegible en Oracle.
DELETE EAI.CFDI_OPEN_ITEMS;
INSERT EAI.CFDI_OPEN_ITEMS (Nota_Venta,Tipo_Docto,Last_Updated) VALUES ('H','Vta',NULL);
INSERT T3.Cliente (Cliente_SAP,RFC,Fecha_Ini_Vig,Fecha_Fin_Vig) VALUES ('C1','RFC1','20200101','20300101');
INSERT T3.Factura_General (Factura,Ctro,Fecha_Factura,Tipo_Docto,Cliente_SAP)
VALUES ('H','0001','20260801','C003','C1');
INSERT T3.Factura_Detalle (Factura,Valor_Subt,Valor_IVA) VALUES ('H',100,16);
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 10;
IF (SELECT COUNT(*) FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='H')<>1
 THROW 55213,'No se reprodujo filtro historico.',1;
PRINT 'D13 confirmado: historico existente con marca NULL se omite; Oracle inserta otra fila';
DELETE T3.Factura_General; DELETE T3.Factura_Detalle;

-- NOT IN con NULL elimina el universo; NOT EXISTS no lo hace.
DELETE T3.Registro_Fiscal;
INSERT T3.Otros_General (Factura) VALUES (NULL);
INSERT EAI.T3R_Cartera_SAP_OLD (Referencia,Cliente,Fecha_Doc,Monto) VALUES ('SAP1','C1','20260801',10);
IF EXISTS(SELECT 1 FROM EAI.T3R_Cartera_SAP_OLD WHERE Referencia NOT IN (SELECT Factura FROM T3.Otros_General))
 THROW 55214,'Referencia NOT IN inesperada.',1;
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 0;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='SAP1') THROW 55215,'No se reprodujo NOT EXISTS.',1;
PRINT 'D14 confirmado: NULL en Otros_General cambia NOT IN frente a NOT EXISTS';
DELETE T3.Otros_General;
UPDATE EAI.T3R_Cartera_SAP_OLD SET Fecha_Doc='20260230';
EXEC EAI.SF_CFDI_OPEN_ITEMS_OPTIMIZADO 0;
IF NOT EXISTS(SELECT 1 FROM EAI.CFDI_OPEN_ITEMS WHERE Nota_Venta='SAP1' AND Fecha_Venta IS NULL)
 THROW 55216,'No se reprodujo fecha invalida.',1;
PRINT 'D15 confirmado: fecha invalida entra como NULL; TO_DATE Oracle falla';
PRINT 'DIAGNOSTICO COMPLETO: 15 diferencias reproducidas y 2 reglas conservadas';
GO
