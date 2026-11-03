# Se incluye desde Run.ps1, en su base LocalDB temporal. Nunca apunta a T3QA.
foreach($t in @('PAGO','ASIGNACION_PAGO')){
 Ddl ('MSSQL/T3/T3/Tables/T3.'+$t+'.Table.sql') 'T3' $t
}
foreach($t in @('MX_RECEIVE_MESSAGE_LOG','TMP_ACCOUNT_HEADER')){
 Ddl 'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql' 'EAI_OWNER' $t
}
$null=Sql @'
DELETE T3.CFDI_COBRANZA; DELETE T3.CFDI_DOCUMENTOS; DELETE T3.RF_ERROR_LOG;
-- Diferente collation entre columnas de negocio, literales/XML y tempdb.
ALTER TABLE EAI_OWNER.TMP_ACCOUNT_HEADER ALTER COLUMN IDOCNUMBER varchar(10) COLLATE Latin1_General_100_CI_AS_KS_WS_SC NULL;
ALTER TABLE T3.PAGO ALTER COLUMN PAGO_ID varchar(50) COLLATE Latin1_General_100_CI_AS_KS_WS_SC NULL;
ALTER TABLE T3.CFDI_DOCUMENTOS ALTER COLUMN NOTA_VENTA varchar(30) COLLATE Latin1_General_100_CI_AS_KS_WS_SC NULL;
ALTER TABLE T3.RF_ERROR_LOG ALTER COLUMN REFERENCIA varchar(50) COLLATE Latin1_General_100_CI_AS_KS_WS_SC NULL;
CREATE INDEX TRACE_QUEUE ON EAI_OWNER.MX_RECEIVE_MESSAGE_LOG(QUEUE_NAME,CREATED,PROCESSED);
CREATE INDEX TRACE_IDOC ON EAI_OWNER.TMP_ACCOUNT_HEADER(IDOCNUMBER);
CREATE INDEX TRACE_PAGO ON T3.PAGO(PAGO_ID);
CREATE INDEX TRACE_AP ON T3.ASIGNACION_PAGO(PAGO_ID);
CREATE INDEX TRACE_COB ON T3.CFDI_COBRANZA(ASIGNACION_ID);
CREATE INDEX TRACE_DOC ON T3.CFDI_DOCUMENTOS(NOTA_VENTA);
CREATE INDEX TRACE_ERROR ON T3.RF_ERROR_LOG(REFERENCIA);
DECLARE @Now datetime2(0)='2026-10-28T10:00:00';
INSERT EAI_OWNER.MX_RECEIVE_MESSAGE_LOG(ROW_ID,CREATED,QUEUE_NAME,PROCESSED,STATUS,XML_CONTENT)
SELECT CONCAT('TRACE',N),DATEADD(minute,-10,@Now),'Payment',@Now,'Processed',
 CONVERT(xml,CONCAT('<Payment><Header><Reference><ReferenceID>000000',RIGHT(CONCAT('0000000000',N),10),
 '</ReferenceID></Reference></Header><Message><ZTMDALLOCPAY><ClearingDocumentNumber>',5000+N,
 '</ClearingDocumentNumber><ClearingDate>',CASE WHEN N=6 THEN '20261009' ELSE '20261008' END,
 '</ClearingDate><Postingdate>20261008</Postingdate></ZTMDALLOCPAY></Message></Payment>'))
FROM (VALUES(1),(2),(3),(4),(5),(6)) V(N);
UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG SET XML_CONTENT=CONVERT(xml,
 REPLACE(CONVERT(varchar(max),XML_CONTENT),'20261008','20261009')) WHERE ROW_ID='TRACE6';
INSERT EAI_OWNER.TMP_ACCOUNT_HEADER(IDOCNUMBER,CREATED,PROCESSED,STATUS,CLEARINGDOCNUMBER,
 CLEARINGDATE,POSTINGDATE,DC_INDICATOR,PAYMENTAMOUNT,PAYMETHSUPPLEMENT)
SELECT RIGHT(CONCAT('0000000000',N),10),CASE WHEN N=2 THEN DATEADD(minute,-5,@Now) ELSE DATEADD(hour,-3,@Now) END,
 CASE WHEN N>2 THEN @Now END,CASE WHEN N>2 THEN 'Processed' END,
 CONVERT(varchar(20),5000+N),'20261008','20261008','S',100,'A'
FROM (VALUES(2),(3),(4),(5)) V(N);
INSERT T3.PAGO(PAGO_ID,FECHA_PAGO,FECHA_TRN,REP_ID,VALOR_PAGO)
SELECT CONCAT('26',5000+N),'20261008',@Now,'CENTRAL',100 FROM (VALUES(3),(4),(5)) V(N);
INSERT T3.ASIGNACION_PAGO(PAGO_ID,ASIGNACION_ID,FECHA_ASIGNACION,FECHA_TRN,FECHA_PROC_BATMD,FACTURA)
SELECT CONCAT('26',5000+N),CONCAT('26',5000+N),'20261008',@Now,
 CASE WHEN N>3 THEN CONVERT(datetime2,'20261027') END,CONCAT('TEST-',N) FROM (VALUES(3),(4),(5)) V(N);
INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,FOLIO_ID,PAGO_ID,NOTA_VENTA,FACTURA,FECHA_PAGO,
 FECHA_PROC_BATMD,FECHA_PROCESO,CREATED_BY,RFC,UUID_VENTA,VIA_PAGO,STATUS)
VALUES('265004','F4','265004','V4','TEST-4','20261008','20261027',@Now,'CENTRAL','ABC010101AA1','UUID4','01',NULL),
 ('265005','F5','265005','V5','TEST-5','20261008','20261027',@Now,'INTERFACE','XAXX010101000',NULL,'02','PendienteT3');
INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,METODO_PAGO) VALUES('V4','PPD'),('V5','PUE');
INSERT T3.RF_ERROR_LOG(FECHA,RUTINA,REFERENCIA,ERROR_DESC)
 VALUES(@Now,'PROC_CFDI_GENERAR_PAGO','265005','ERROR DE FIXTURE');
'@
$trace=[IO.File]::ReadAllText((Join-Path $folder '06_RASTREAR_PAGOS_20261008.sql'))
# Solo sustituir base permitida y reloj en la copia en memoria de la fixture.
$trace=$trace.Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
$trace=$trace.Replace('@Ahora datetime2(0)=SYSDATETIME()',"@Ahora datetime2(0)='2026-10-28T10:00:00'")
$assert=@'
IF (SELECT COUNT(*) FROM #LP06M)<>5 THROW 52791,'Filtro de fecha XML incorrecto.',1;
IF (SELECT COUNT(*) FROM #LP06H)<>4 THROW 52792,'Relacion IDoc incorrecta.',1;
IF (SELECT COUNT(*) FROM #LP06A)<>3 OR (SELECT COUNT(*) FROM #LP06C)<>2 THROW 52793,'Rastreo de etapas incorrecto.',1;
IF NOT EXISTS(SELECT 1 FROM #LP06A WHERE ASIGNACION_ID='265003' AND FECHA_PROC_BATMD IS NULL) THROW 52794,'No conserva BATMD NULL.',1;
IF NOT EXISTS(SELECT 1 FROM #LP06A WHERE ASIGNACION_ID='265004' AND FECHA_PROC_BATMD='20261027') THROW 52795,'Confunde fecha pago con BATMD.',1;
IF (SELECT Retorno FROM #LP06RFC WHERE RFC='ABC010101AA1')<>1 OR
   (SELECT Retorno FROM #LP06RFC WHERE RFC='XAXX010101000')<>-1 THROW 52796,'Validador RFC alterado.',1;
IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA)<>2 OR EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE FECHA_ENVIO IS NOT NULL)
 THROW 52797,'El diagnostico modifico cobranza.',1;
IF EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG) OR EXISTS(SELECT 1 FROM sys.sequences WHERE last_used_value IS NOT NULL)
 THROW 52798,'El diagnostico ejecuto negocio o consumio una secuencia.',1;
PRINT 'TRACE_ASSERTS_OK';
'@
# La prueba anterior mezclaba columnas de negocio, pero no la collation
# de @Accesos.Columna contra sys.columns.name (fallo real de la linea50).
# Forzar ese caso en la copia en memoria del diagnostico completo.
$catalogCollation=Sql "SELECT TOP(1) CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(name,'Collation')) FROM sys.columns;"
$otherCollation=if($catalogCollation.Contains('SQL_Latin1_General_CP1_CI_AS')){
 'Latin1_General_100_CI_AS_KS_WS_SC'
}else{'SQL_Latin1_General_CP1_CI_AS'}
$traceMetadata=$trace.Replace('Columna sysname,',('Columna sysname COLLATE '+$otherCollation+','))
if($traceMetadata -eq $trace){throw 'No se preparo el caso de collation de metadatos.'}
$legacyMetadata=$traceMetadata.Replace(
 'C.name COLLATE DATABASE_DEFAULT=A.Columna COLLATE DATABASE_DEFAULT',
 'C.name=A.Columna')
if($legacyMetadata -eq $traceMetadata){throw 'No se preparo la reproduccion del fallo original.'}
$probe="BEGIN TRY`nEXEC sys.sp_executesql N'"+$legacyMetadata.Replace("'","''")+"';`nTHROW 52800,'No se reprodujo el conflicto esperado.',1;`nEND TRY`nBEGIN CATCH`nIF ERROR_NUMBER()<>468 THROW;`nPRINT 'REPRODUCIDO_METADATA_468';`nEND CATCH;"
$null=Capture '09A_reproduce_metadata_468' $probe @('REPRODUCIDO_METADATA_468')
$null=Capture '09B_trace_metadata_corregida' ($traceMetadata+"`n"+$assert) @('TRACE_ASSERTS_OK','12_ALCANCE')
$o=Capture '09_trace_etapas_collation' ($trace+"`n"+$assert) @('TRACE_ASSERTS_OK','AUN DENTRO DEL MARGEN','SIN FECHA BATMD','09_FILTROS_LIBERADOR','12_ALCANCE')
if($o -notmatch '11_RESUMEN_MUESTRA\s+5\s+4\s+5\s+3\s+3\s+2'){
 throw 'No coincide el resumen de etapas de la fixture.'
}
$null=Sql @'
INSERT EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 SELECT CONCAT('MORE',ROW_NUMBER() OVER(ORDER BY(SELECT NULL))),CONVERT(datetime2,'2026-10-28T09:59:00'),
 XML_CONTENT,QUEUE_NAME,REFERENCE,PROCESSED,STATUS,DOCNUM
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG R
 CROSS JOIN(SELECT TOP(209) 1 AS N FROM sys.all_objects) V WHERE R.ROW_ID='TRACE6';
'@
$o=Capture '10_trace_limite_antes_xml' $trace @('04_SIN_COINCIDENCIAS')
if($o -notmatch '04_MUESTRA_RECEPCION\s+200\s+1\s+0'){
 throw 'La muestra no se limita antes de filtrar las fechas XML.'
}
$null=Sql "DROP INDEX TRACE_AP ON T3.ASIGNACION_PAGO;"
$null=Capture '11_trace_acceso_ausente' $trace @('03_DETENIDO')
