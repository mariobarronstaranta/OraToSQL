/* Solo lectura de negocio. Basado en reportes del 28/10/2026 21:29-21:30.
   No reinicia secuencias, no completa datos ni ejecuta CHECK/liberador.
   #K conserva tipos y collation de la cobranza instalada.
*/
USE [T3QA];
SET NOCOUNT ON;
DROP TABLE IF EXISTS #K;
SELECT DISTINCT Asignacion_ID,Factura,Nota_Venta,RFC,Cliente_SAP,Importe
INTO #K FROM T3.CFDI_Cobranza
WHERE Asignacion_ID IN ('262201997234','262201997964','262201997720','262201997198');

SELECT '01_COBRANZAS' Seccion,C.Asignacion_ID,C.Factura,
 C.Nota_Venta,LEN(C.Nota_Venta) LongitudNota,DATALENGTH(C.Nota_Venta) BytesNota,
 C.UUID_Venta,LEN(C.UUID_Venta) LongitudUUID,
 C.Accnt_ID,DATALENGTH(C.Accnt_ID) BytesAccnt,
 C.Status,C.Importe,C.Saldo_Anterior,C.Numero_Pago,C.Fecha_Envio
FROM T3.CFDI_Cobranza C
WHERE EXISTS(SELECT 1 FROM #K K WHERE K.Asignacion_ID=C.Asignacion_ID);

-- Buscar por Factura es diagnostico; NO autoriza copiar UUID/Nota_Venta.
SELECT '02_DOCUMENTOS_POR_FACTURA' Seccion,K.Asignacion_ID,K.Factura,
 D.Nota_Venta,D.Metodo_Pago,D.Status,D.Folio_Fiscal,D.Fecha_Timbre
FROM #K K LEFT JOIN T3.CFDI_Documentos D ON D.Nota_Venta=K.Factura;

SELECT '03_ORIGEN_FISCAL' Seccion,K.Asignacion_ID,K.Factura,
 (SELECT COUNT_BIG(*) FROM T3.REGISTRO_FISCAL RF WHERE RF.Factura=K.Factura) Cabeceras,
 (SELECT COUNT_BIG(*) FROM T3.REGISTRO_FISCAL_DETALLE RFD WHERE RFD.Factura=K.Factura) Detalles,
 (SELECT COUNT_BIG(*) FROM T3.REGISTRO_FISCAL RF
  JOIN T3.CFDI_USOCFDI_CLIENTE U ON U.Cliente_SAP=RF.Cliente_SAP
  WHERE RF.Factura=K.Factura) CabecerasConUsoCFDI
FROM #K K;

SELECT '04_AGRUPACIONES_PREVIAS_POR_ASIGNACION' Seccion,K.Asignacion_ID,
 P.Agrupacion,P.Fecha_Pago,A.Cliente_SAP,A.Importe,A.Fecha_Registro,A.Fecha_Envio
FROM #K K JOIN T3.CFDI_AGRUPACION_PAGO P ON P.Asignacion_ID=K.Asignacion_ID
LEFT JOIN T3.CFDI_AGRUPACION_CTRL A ON A.Agrupacion=P.Agrupacion;

SELECT '05_COINCIDENCIAS_RFC_IMPORTE' Seccion,K.Asignacion_ID,
 K.Cliente_SAP ClienteCobranza,A.Agrupacion,A.Cliente_SAP ClienteControl,
 A.RFC,A.Importe,A.Fecha_Pago,A.Fecha_Registro,A.Fecha_Envio
FROM #K K JOIN T3.CFDI_AGRUPACION_CTRL A ON A.RFC=K.RFC AND A.Importe=K.Importe
WHERE A.Fecha_Envio IS NULL AND A.Fecha_Pago='20261001';

SELECT '06_COMPONENTES' Seccion,Component,Name,Status,Last_Run
FROM EAI_OWNER.MX_COMPONENTS WHERE Component IN (109,613,614);

SELECT '07_SECUENCIA' Seccion,name,start_value,current_value,increment,
 minimum_value,maximum_value,is_cycling,is_exhausted
FROM sys.sequences WHERE object_id=OBJECT_ID('T3.SEQ_PAGO_CENTRAL_AGR');
SELECT '08_MAXIMOS' Seccion,
 (SELECT MAX(Agrupacion) FROM T3.CFDI_AGRUPACION_CTRL) MaxControl,
 (SELECT MAX(Agrupacion) FROM T3.CFDI_AGRUPACION_PAGO) MaxDetalle;

-- Rango observado despues de current_value=515343; solo inspecciona IDs.
-- No es una reserva ni garantiza que esos sean los siguientes bajo concurrencia.
SELECT '09_IDS_INMEDIATOS' Seccion,V.ID,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_CTRL A WHERE A.Agrupacion=V.ID) Controles,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_PAGO A WHERE A.Agrupacion=V.ID) Detalles,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS D
  WHERE D.Nota_Venta=CONVERT(varchar(30),V.ID)
     OR D.Nota_Venta=CONVERT(varchar(30),V.ID)+'.00') Documentos,
 (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E
  WHERE E.Nota_Venta=CONVERT(varchar(30),V.ID)
     OR E.Nota_Venta=CONVERT(varchar(30),V.ID)+'.00') Layouts
FROM (VALUES (515344),(515345),(515346),(515347)) V(ID);

-- Evaluacion de todos los pendientes actuales del 614, incluidos los 32
-- anteriores del reporte. Consulta no mutante de la regla del CHECK.
SELECT '10_CHECK_PENDIENTES' Seccion,A.Agrupacion,A.Cliente_SAP,A.Importe,
 P.FilasDetalle,X.Items,X.UUIDs,X.Contado,
 CASE WHEN X.UUIDs>0 AND X.UUIDs=X.Contado THEN 'MARCARIA CONTADO'
      WHEN X.Items>0 AND X.Items=X.UUIDs THEN 'PASA CONTEOS; REVISAR GENERADOR'
      ELSE 'NO PASA CHECK' END Resultado
FROM T3.CFDI_AGRUPACION_CTRL A
OUTER APPLY(SELECT COUNT_BIG(*) FilasDetalle FROM T3.CFDI_AGRUPACION_PAGO P
 WHERE P.Agrupacion=A.Agrupacion) P
OUTER APPLY(
 SELECT COUNT_BIG(*) Items,
 COUNT_BIG(CASE WHEN LEN(ISNULL(C.UUID_Venta,'NULL'))>20 THEN 1 END) UUIDs,
 COUNT_BIG(CASE WHEN CAST(C.Fecha_Asignacion AS date)=CAST(C.Fecha_Factura AS date)
 AND D.Metodo_Pago='PUE' THEN 1 END) Contado
 FROM T3.CFDI_AGRUPACION_PAGO P
 JOIN T3.CFDI_Cobranza C ON C.Asignacion_ID=P.Asignacion_ID
 JOIN T3.CFDI_Documentos D ON D.Nota_Venta=C.Nota_Venta
 WHERE P.Agrupacion=A.Agrupacion
) X
WHERE A.Fecha_Envio IS NULL AND A.Fecha_Pago>='20220101' AND A.Accnt_ID<>'Contado';
DROP TABLE #K;
