param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference = 'Stop'
$triggerDir = Split-Path $PSScriptRoot -Parent
$ownerDir = Split-Path $triggerDir -Parent
$t3Dir = Split-Path $ownerDir -Parent
$db = 'CodexEaiTriggers_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
function Invoke-SqlText([string]$Sql) {
    $Sql | & sqlcmd -S $Server -E -No -b -d $db
    if ($LASTEXITCODE -ne 0) { throw 'Fallo SQL en la base temporal.' }
}
try {
    & sqlcmd -S $Server -E -No -b -Q "CREATE DATABASE [$db]"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base temporal.' }
    Invoke-SqlText "CREATE SCHEMA EAI_OWNER AUTHORIZATION dbo;`nGO`nCREATE SCHEMA T3 AUTHORIZATION dbo;`nGO"
    $ddl = Get-Content -Raw (Join-Path $ownerDir 'Tables\Tablas_EAI_OWNER.sql')
    $tables = @('MX_CFDI_PRODSERV_LOG','MX_CFG_CONDITION_HAWA','MX_CONDITION_HAWA_LOG',
        'MX_HASHTABLE','MX_HASHTABLE_LOG','MX_USOCFDI_CLIENTE_LOG','WA_COBRANZA_LOG',
        'XP_ASIGNACION_PAGO','X_APLICA_INCOBRABLE','X_ASIGNACION_PAGO',
        'WO_TMP_INVOICE','WO_TMP_INVOICE_HIST','MX_RECEIVE_MESSAGE_LOG','MX_EAI_MESSAGE_LOG')
    foreach ($table in $tables) {
        $pattern = '(?ms)^CREATE TABLE \[EAI_OWNER\]\.\[' + [regex]::Escape($table) + '\].*?^GO\s*$'
        $match = [regex]::Match($ddl, $pattern)
        if (-not $match.Success) { throw "No se encontro el DDL de $table" }
        Invoke-SqlText $match.Value
    }
    foreach ($table in @('CFDI_PRODSERV','CFDI_USOCFDI_CLIENTE')) {
        $ddl = Get-Content -Raw (Join-Path $t3Dir "T3\Tables\T3.$table.Table.sql")
        $match = [regex]::Match($ddl, '(?ms)^CREATE TABLE .*?^GO\s*$')
        if (-not $match.Success) { throw "No se encontro el DDL de T3.$table" }
        Invoke-SqlText $match.Value
    }
    # Dos instalaciones verifican que los scripts sean reejecutables.
    foreach ($pass in 1..2) {
        foreach ($file in (Get-ChildItem $triggerDir -Filter '*.SQL' | Sort-Object Name)) {
            Invoke-SqlText (Get-Content -Raw -LiteralPath $file.FullName)
            Write-Output "COMPILE_OK ($pass) $($file.Name)"
        }
    }
    Invoke-SqlText (Get-Content -Raw (Join-Path $PSScriptRoot 'Behavior.sql'))
} finally {
    # Solo elimina la base aleatoria creada por esta ejecucion.
    & sqlcmd -S $Server -E -No -b -Q "IF DB_ID(N'$db') IS NOT NULL BEGIN ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]; END"
    if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo limpiar la base temporal $db" }
}
