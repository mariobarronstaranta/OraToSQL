$ErrorActionPreference='Stop'
$server='(localdb)\MSSQLLocalDB'
$db='CodexReplenish_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$owner=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$created=$false
function Sql([string]$Text) {
    $Text | & sqlcmd -S $server -E -No -I -b -d $db
    if($LASTEXITCODE -ne 0){throw 'Fallo prueba local de replenishment'}
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db] COLLATE SQL_Latin1_General_CP1_CI_AS"
    if($LASTEXITCODE -ne 0){throw 'No se creo la base local'}
    $created=$true
    Sql "CREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
    $ddl=Get-Content -Raw -Encoding UTF8 (Join-Path $owner 'Tables/Tablas_EAI_OWNER.sql')
    foreach($table in @('MX_RECEIVE_MESSAGE_LOG','MX_EAI_MESSAGE_LOG','MX_HASHTABLE','TRACE_EAI_OWNER','TMP_DOCUMENT_HEADER','TMP_DOCUMENT_DETAIL','TMP_DOCUMENT_CONDITIONS','TMP_DOCUMENT_PARTNERS')){
        $m=[regex]::Match($ddl,'(?ims)^CREATE TABLE \[EAI_OWNER\]\.\['+$table+'\].*?^GO\s*$')
        if(-not $m.Success){throw "Falta DDL de $table"}
        Sql $m.Value
    }
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $owner 'Functions/GETCONV.SQL'))
    Sql "CREATE FUNCTION T3.FN_EVAL_REMISION_OBD(@a varchar(50),@b varchar(50),@c varchar(100)) RETURNS varchar(10) AS BEGIN RETURN 'NO'; END;"
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'respaldo_recibido.sql'))
    $patch=(Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot '02_PATCH_REFERENCEID.sql')).Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
    Sql $patch
    Sql $patch
    Sql "DECLARE @s nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_REPLENISHMENT')); IF (LEN(@s)-LEN(REPLACE(@s,N'/* RR_REFERENCEID_BEGIN */',N'')))/LEN(N'/* RR_REFERENCEID_BEGIN */')<>7 THROW 51990,'No hay siete bloques',1;"
    Sql ($patch.Replace('DECLARE @Revertir bit=0;','DECLARE @Revertir bit=1;'))
    Sql ($patch.Replace('DECLARE @Revertir bit=0;','DECLARE @Revertir bit=1;'))
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'TestPredicados.sql'))
    Write-Output 'PASS: compilacion sobre respaldo, aplicacion/reversa repetibles, 7 bloques y equivalencia de predicados.'
} finally {
    if($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
