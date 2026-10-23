$ErrorActionPreference='Stop'
$server='(localdb)\MSSQLLocalDB'
$db='CodexDiag8114_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$created=$false
try {
 & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db]"
 if($LASTEXITCODE -ne 0){throw 'No se creo base temporal'}
 $created=$true
 $fixture=@'
SET QUOTED_IDENTIFIER ON;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SCHEMA T3;
GO
CREATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG
 (CREATED datetime2,JOB_PID int,REFERENCE varchar(50),QUEUE_NAME varchar(30),
 SIEBEL_ERROR_CODE varchar(100),SIEBEL_ERROR_MESSAGE varchar(2000));
CREATE TABLE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 (ROW_ID varchar(32),CREATED datetime2,REFERENCE varchar(50),QUEUE_NAME varchar(30),
 PROCESSED datetime2,XML_CONTENT xml);
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_DETAIL
 (ReferenceID varchar(50),ItemID numeric(4,0),Material varchar(18),Cantidad numeric(13,2),
 UnidadMedida varchar(10),Valor_Subt numeric(22,7),Valor_IVA numeric(22,7),
 Bonif_Subt numeric(22,7),Envio_Subt numeric(22,7),Credito_Subt numeric(15,2));
INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG VALUES
 (SYSDATETIME(),1,'REF_TEST','PROC_PREINVOICE_IFC','SQL-8114','procedimiento=EAI_OWNER.INVOICE_TO_FACTURA');
INSERT EAI_OWNER.MX_RECEIVE_MESSAGE_LOG VALUES
 ('ROW_TEST',SYSDATETIME(),NULL,'Invoice',NULL,
 N'<Invoice><Message><InvoiceHeader><DocumentNumber>REF_TEST</DocumentNumber></InvoiceHeader><ItemData><ItemNumber>1</ItemNumber><Quantity>2</Quantity><UnitOfMeasure>UA</UnitOfMeasure><ItemID><ObjectIdentification>002</ObjectIdentification><MaterialID>000123</MaterialID></ItemID></ItemData><ItemData><ItemNumber>2</ItemNumber><ItemID><ObjectIdentification>002</ObjectIdentification><MaterialID>ALFA_X</MaterialID></ItemID></ItemData></Message></Invoice>');
'@
 $fixture| & sqlcmd -S $server -E -No -I -b -d $db
 if($LASTEXITCODE -ne 0){throw 'Fallo fixture'}
 $sql=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../05_DIAGNOSTICO_8114_FACTURA.sql'))
 $sql=$sql.Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
 $result=$sql| & sqlcmd -S $server -E -No -I -b -d $db -W -s '|' 2>&1
 if($LASTEXITCODE -ne 0){$result;throw 'Fallo diagnostico'}
 foreach($token in @('REF_TEST','ROW_TEST','000123','ALFA_X','NO convertible: candidato al 8114')){
  if(-not ($result -match [regex]::Escape($token))){throw "Falta resultado $token"}
 }
 Write-Output 'PASS diagnostico 8114 con temporal vacio y Reference revertido: recupera XML y detecta material no numerico.'
 # Mensaje antiguo, ya procesado y sin Reference: debe localizarse por el
 # prefijo que uso el usuario, sin depender de los cinco dias del diagnostico 05.
 $prepare=@'
ALTER TABLE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG ADD STATUS varchar(10) NULL;
UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
SET ROW_ID='202610060001',CREATED='20261006',PROCESSED=SYSDATETIME(),
    XML_CONTENT.modify('replace value of (/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1] with "1658415284"');
'@
 $prepare| & sqlcmd -S $server -E -No -I -b -d $db
 if($LASTEXITCODE -ne 0){throw 'Fallo fixture de mensaje antiguo'}
 $sql=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../06_LOCALIZAR_ORIGEN_8114.sql'))
 $sql=$sql.Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
 $result=$sql| & sqlcmd -S $server -E -No -I -b -d $db -W -s '|' 2>&1
 if($LASTEXITCODE -ne 0){$result;throw 'Fallo diagnostico por prefijo'}
 foreach($token in @('202610060001','1658415284','ALFA_X','NO convertible: revisar dato')){
  if(-not ($result -match [regex]::Escape($token))){throw "Falta resultado por prefijo $token"}
 }
 Write-Output 'PASS busqueda por prefijo ROW_ID recupera mensaje antiguo/procesado sin Reference.'
 $sql=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../07_REVISAR_MATERIALES_DEL_GRUPO.sql'))
 $sql=$sql.Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
 $result=$sql| & sqlcmd -S $server -E -No -I -b -d $db -W -s '|' 2>&1
 if($LASTEXITCODE -ne 0){$result;throw 'Fallo revision de materiales del grupo'}
 foreach($token in @('202610060001','1658415284','ALFA_X','NO convertible','NoConvertibles')){
  if(-not ($result -match [regex]::Escape($token))){throw "Falta resultado del grupo $token"}
 }
 Write-Output 'PASS revision de todos los materiales del grupo, sin depender de una referencia de error.'
 $prepare=@'
INSERT EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
 (ROW_ID,CREATED,REFERENCE,QUEUE_NAME,PROCESSED,XML_CONTENT,STATUS)
 SELECT '202610010001','20261001',NULL,'Invoice',NULL,XML_CONTENT,'Received'
 FROM EAI_OWNER.MX_RECEIVE_MESSAGE_LOG WHERE ROW_ID='202610060001';
UPDATE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG
SET XML_CONTENT.modify('replace value of (/Invoice/Message/InvoiceHeader/DocumentNumber/text())[1] with "REF_TEST"')
WHERE ROW_ID='202610010001';
'@
 $prepare| & sqlcmd -S $server -E -No -I -b -d $db
 if($LASTEXITCODE -ne 0){throw 'Fallo fixture fuera del prefijo'}
 $sql=$sql.Replace("@ReferenciaObjetivo varchar(50)='1658415284'","@ReferenciaObjetivo varchar(50)='REF_TEST'")
 $result=$sql| & sqlcmd -S $server -E -No -I -b -d $db -W -s '|' 2>&1
 if($LASTEXITCODE -ne 0){$result;throw 'Fallo busqueda fuera de prefijo'}
 foreach($token in @('202610010001','REF_TEST','CoincidenciasFueraDelPrefijo','ALFA_X')){
  if(-not ($result -match [regex]::Escape($token))){throw "Falta resultado fuera del prefijo $token"}
 }
 Write-Output 'PASS localiza referencia pendiente anterior a cinco dias fuera del prefijo.'
} finally {
 if($created){ & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];" }
}
