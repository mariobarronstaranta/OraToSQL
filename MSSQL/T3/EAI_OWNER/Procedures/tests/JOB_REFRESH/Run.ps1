# No modifica msdb ni SQL Agent. Prueba la consulta contra catalogos simulados.
$ErrorActionPreference='Stop'
$server='(localdb)\MSSQLLocalDB'
$db='CodexJobRefresh_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$owner=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$created=$false
function Sql([string]$Text){
    $Text | & sqlcmd -S $server -E -No -b -d $db
    if($LASTEXITCODE -ne 0){throw 'Fallo la prueba JOB_REFRESH.'}
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db]"
    if($LASTEXITCODE -ne 0){throw 'No se creo base temporal.'}
    $created=$true
    Sql "CREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA AgentFixture;`nGO"
    $ddl=Get-Content -Raw (Join-Path $owner 'Tables/Tablas_EAI_OWNER.sql')
    $m=[regex]::Match($ddl,'(?ims)^CREATE TABLE \[EAI_OWNER\]\.\[INTERNAL_JOBS\].*?^GO\s*$')
    if(-not $m.Success){throw 'Falta DDL INTERNAL_JOBS.'}
    Sql $m.Value
    Sql (Get-Content -Raw (Join-Path $owner 'Tables/JOB_ORACLE_SQLAGENT_MAP.SQL'))
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))
    $proc=Get-Content -Raw (Join-Path $owner 'Procedures/JOB_REFRESH.SQL')
    # Solo se redirige el catalogo externo al fixture; SELECT/INSERT reales.
    Sql ($proc.Replace('msdb.dbo.','AgentFixture.'))
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Cases.sql'))
} finally {
    if($created){
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
