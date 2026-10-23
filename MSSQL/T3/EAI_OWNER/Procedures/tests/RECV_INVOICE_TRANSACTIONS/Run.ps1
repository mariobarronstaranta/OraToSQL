$ErrorActionPreference = 'Stop'
$server = '(localdb)\MSSQLLocalDB'
$db = 'CodexInvoiceTran_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$owner = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$created = $false
function Sql([string]$Text) {
    $Text | & sqlcmd -S $server -E -No -I -b -d $db
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la prueba de transacciones.' }
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db]"
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base temporal.' }
    $created = $true
    Sql "CREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
    $ddl = Get-Content -Raw (Join-Path $owner 'Tables/Tablas_EAI_OWNER.sql')
    foreach ($table in @('MX_RECEIVE_MESSAGE_LOG','MX_EAI_MESSAGE_LOG','MX_HASHTABLE','MX_COMPONENTS','TRACE_EAI_OWNER','TMP_DOCUMENT_HEADER','TMP_DOCUMENT_DETAIL','TMP_DOCUMENT_CONDITIONS')) {
        $m = [regex]::Match($ddl, '(?ims)^CREATE TABLE \[EAI_OWNER\]\.\[' + $table + '\].*?^GO\s*$')
        if (-not $m.Success) { throw "Falta DDL de $table" }
        Sql $m.Value
    }
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))
    foreach ($file in @('Functions/GETCONV.SQL','Functions/FN_CHECK_INSTANCE.SQL','Functions/LINE_ITEM_TEXT.SQL','Procedures/LOG_START.SQL','Procedures/SF_PROC_PREINVOICE_IFC.SQL','Package/RECV_INVOICE.SQL')) {
        Sql (Get-Content -Raw (Join-Path $owner $file))
    }
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Cases.sql'))
} finally {
    if ($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
