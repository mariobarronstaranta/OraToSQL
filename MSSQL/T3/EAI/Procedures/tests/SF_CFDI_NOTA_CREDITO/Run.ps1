# Pruebas de desarrollo, no es parte de la operacion BAT del cliente.
# Crea y elimina exclusivamente una base aislada con nombre aleatorio.
$ErrorActionPreference='Stop'
$server='(localdb)\MSSQLLocalDB'
$testDb='CodexCFDINota_'+[guid]::NewGuid().ToString('N')
$created=$false
try {
    sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$testDb]"
    if($LASTEXITCODE -ne 0){ throw 'No se pudo crear la base de pruebas.' }
    $created=$true
    foreach($script in @((Join-Path $PSScriptRoot 'Schema.sql'),(Join-Path $PSScriptRoot '..\..\SF_CFDI_NOTA_CREDITO.SQL'),(Join-Path $PSScriptRoot 'Cases.sql'))){
        sqlcmd -S $server -E -No -b -d $testDb -i $script
        if($LASTEXITCODE -ne 0){ throw "Fallo la prueba: $script" }
    }
} finally {
    if($created){
        sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$testDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$testDb];"
        if($LASTEXITCODE -ne 0){ Write-Warning "No se pudo eliminar la base temporal $testDb" }
    }
}
