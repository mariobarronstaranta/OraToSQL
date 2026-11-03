$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$owner=Join-Path $repo 'MSSQL/T3/EAI_OWNER'
$legacy=Join-Path $owner 'Procedures/tests/RECV_INVOICE_TRANSACTIONS'
$package=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server='(localdb)\MSSQLLocalDB'
$db='CodexInvoiceRefSeek_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$created=$false
function Sql([string]$Text) {
 $Text | & sqlcmd -S $server -E -No -I -b -l 5 -d $db
 if($LASTEXITCODE -ne 0){throw 'Fallo prueba LocalDB de ReferenceID.'}
}
try {
 & sqlcmd -S $server -E -No -b -l 5 -Q "CREATE DATABASE [$db] COLLATE SQL_Latin1_General_CP1_CI_AS"
 if($LASTEXITCODE -ne 0){throw 'No fue posible crear la base temporal LocalDB.'}
 $created=$true
 Sql "CREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
 $ddl=[IO.File]::ReadAllText((Join-Path $owner 'Tables/Tablas_EAI_OWNER.sql'))
 foreach($table in @('MX_RECEIVE_MESSAGE_LOG','MX_EAI_MESSAGE_LOG','MX_HASHTABLE','MX_COMPONENTS','TRACE_EAI_OWNER','TMP_DOCUMENT_HEADER','TMP_DOCUMENT_DETAIL','TMP_DOCUMENT_CONDITIONS')){
  $match=[regex]::Match($ddl,'(?ims)^CREATE TABLE \[EAI_OWNER\]\.\['+$table+'\].*?^GO\s*$')
  if(-not $match.Success){throw "Falta DDL de $table"}
  Sql $match.Value
 }
 Sql ([IO.File]::ReadAllText((Join-Path $legacy 'Fixture.sql')))
 foreach($file in @('Functions/GETCONV.SQL','Functions/FN_CHECK_INSTANCE.SQL','Functions/LINE_ITEM_TEXT.SQL','Procedures/LOG_START.SQL','Package/RECV_INVOICE.SQL')){
  Sql ([IO.File]::ReadAllText((Join-Path $owner $file)))
 }
 $source=[IO.File]::ReadAllText((Join-Path $owner 'Procedures/SF_PROC_PREINVOICE_IFC.SQL'))
 # Reproduce la version anterior solo en memoria; el fuente mantenido queda corregido.
 foreach($table in @('TMP_DOCUMENT_HEADER','TMP_DOCUMENT_DETAIL','TMP_DOCUMENT_CONDITIONS')){
  $pattern='(?s)/\* RI_REF_SEEK_'+$table+' \*/.*?/\* RI_REF_END_'+$table+' \*/'
  if([regex]::Matches($source,$pattern).Count -ne 1){throw "Se esperaba un bloque unico: $table"}
  $source=[regex]::Replace($source,$pattern,'DELETE FROM [EAI_OWNER].['+$table+'] WHERE ReferenceID = @sReferenceID;')
 }
 Sql $source
 Sql "CREATE TABLE dbo.BeforeDefinition (Def nvarchar(max)); INSERT dbo.BeforeDefinition SELECT OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC')); CREATE USER RefSeekProof WITHOUT LOGIN; GRANT EXECUTE ON OBJECT::EAI_OWNER.SF_PROC_PREINVOICE_IFC TO RefSeekProof;"
 $patch=[IO.File]::ReadAllText((Join-Path $package '01_CORREGIR_REFERENCEID.sql')).Replace("N'T3QA'","N'$db'")
 Sql $patch
 Sql $patch
 Sql @'
IF (SELECT COUNT(*) FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP)<>1
 THROW 52640,'La repeticion creo respaldos adicionales.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP B CROSS JOIN dbo.BeforeDefinition D
 WHERE CONVERT(varbinary(max),B.DefinicionOriginal)<>CONVERT(varbinary(max),D.Def))
 THROW 52641,'El respaldo no coincide con la definicion original.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP
 WHERE HashAplicado<>HASHBYTES('SHA2_256',OBJECT_DEFINITION(ObjectId)))
 THROW 52642,'Hash aplicado incorrecto.',1;
DECLARE @ok int;
EXECUTE AS USER=N'RefSeekProof';
SET @ok=HAS_PERMS_BY_NAME(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'OBJECT',N'EXECUTE');
REVERT;
IF ISNULL(@ok,0)<>1 THROW 52643,'ALTER no conservo el permiso.',1;
PRINT 'PASS respaldo exacto, aplicacion repetible y permisos preservados';
'@
 Sql ([IO.File]::ReadAllText((Join-Path $legacy 'Cases_ReferencePredicates.sql')))
 Sql ([IO.File]::ReadAllText((Join-Path $legacy 'Cases.sql')))
 $revert=[IO.File]::ReadAllText((Join-Path $package '02_REVERTIR_REFERENCEID.sql')).Replace("N'T3QA'","N'$db'")
 $revert=$revert.Replace('DECLARE @RunId UNIQUEIDENTIFIER=NULL;', 'DECLARE @RunId UNIQUEIDENTIFIER=(SELECT TOP(1) RunId FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP ORDER BY FechaAplicacion DESC);')
 Sql $revert
 Sql $revert
 Sql @'
DECLARE @before nvarchar(max)=(SELECT Def FROM dbo.BeforeDefinition),
 @after nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'));
DECLARE @b int=CHARINDEX(N'PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]',@before),
 @a int=CHARINDEX(N'PROCEDURE [EAI_OWNER].[SF_PROC_PREINVOICE_IFC]',@after);
IF @b=0 OR @a=0 OR CONVERT(varbinary(max),SUBSTRING(@before,@b,LEN(@before)))
 <>CONVERT(varbinary(max),SUBSTRING(@after,@a,LEN(@after)))
 THROW 52644,'Reversion modifico cuerpo o parametros.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP WHERE FechaReversion IS NULL)
 THROW 52645,'No se registro la reversion.',1;
PRINT 'PASS reversion al cuerpo anterior y segunda reversion sin cambios';
'@
 # Compila y prueba tambien el archivo mantenido con sus bloques integrados.
 Sql ([IO.File]::ReadAllText((Join-Path $owner 'Procedures/SF_PROC_PREINVOICE_IFC.SQL')))
 Sql 'DELETE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG; DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG;'
 Sql ([IO.File]::ReadAllText((Join-Path $legacy 'Cases.sql')))
 Write-Output 'PASS fuente mantenido, parche y transacciones'
 . (Join-Path $PSScriptRoot 'SkuCases.ps1')
 # Valida tambien que la nueva lectura compile/ejecute catalogos y XQuery reales.
 Sql ([IO.File]::ReadAllText((Join-Path $package '04_REVISAR_PARSER_Y_FACTURA.sql'))) | Out-Null
 Write-Output 'PASS diagnostico de cache/planes/Query Store y XQuery'
} finally {
 if($created){
  & sqlcmd -S $server -E -No -b -l 5 -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
  if($LASTEXITCODE -ne 0){Write-Warning "Revisar limpieza de la base temporal $db"}
 }
}
