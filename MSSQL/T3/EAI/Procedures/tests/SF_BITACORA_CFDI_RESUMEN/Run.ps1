param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference = 'Stop'
$t3Root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$db = 'CodexResumen_' + [guid]::NewGuid().ToString('N').Substring(0,12)
function Invoke-TestSql([string]$Sql) {
    $Sql | & sqlcmd -S $Server -E -No -b -d $db
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la validacion SQL del resumen.' }
}
function Install-Table([string]$Path, [string]$Schema, [string]$Table) {
    $ddl = Get-Content -Raw -LiteralPath $Path
    $pattern = '(?ims)^CREATE TABLE \[' + $Schema + '\]\.\[' + $Table + '\].*?^GO\s*$'
    $match = [regex]::Match($ddl, $pattern)
    if (-not $match.Success) { throw "DDL no encontrado: $Schema.$Table" }
    Invoke-TestSql $match.Value
}
try {
    & sqlcmd -S $Server -E -No -b -Q "CREATE DATABASE [$db]"
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base temporal.' }
    Invoke-TestSql "CREATE SCHEMA EAI;`nGO`nCREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
    foreach ($table in @('CFDI_INFORME','CFDI_BITACORA','CONTROL_REPORTE','FC__TIME_WINDOW')) {
        Install-Table (Join-Path $t3Root 'EAI/Tablas/Tablas_Schema_EAI_T3.sql') 'EAI' $table
    }
    foreach ($table in @('MX_COMPONENTS','MX_EAI_MESSAGE_LOG','WA_VENTA_CENTRALIZADA')) {
        Install-Table (Join-Path $t3Root 'EAI_OWNER/Tables/Tablas_EAI_OWNER.sql') 'EAI_OWNER' $table
    }
    foreach ($table in @('CFDI_HISTORIA_DOCTO_PAC','CFDI_DOCUMENTO_PASO','CFDI_DOCUMENTOS',
        'CLIENTE','PREVENTA_GENERAL','ENTREGA','FACTURA_DETALLE','CFDI_AGRUPADO',
        'CFDI_AGRUPADO_DETALLE','REGISTRO_FISCAL','REGISTRO_FISCAL_DETALLE','MATERIAL',
        'CFDI_AGRUPADO_DIF','CFDI_ADDENDA','RF_PROCESOS_LOG')) {
        Install-Table (Join-Path $t3Root "T3/Tables/T3.$table.Table.sql") 'T3' $table
    }
    Install-Table (Join-Path $t3Root 'T3/Tables/T3.FACTURA_GENERAL.SQL') 'T3' 'FACTURA_GENERAL'
    # Contratos minimos de fuentes cuyo DDL no esta en el repositorio.
    Invoke-TestSql @'
CREATE TABLE T3.Fact_T3 (Factura varchar(30), Grupo_Precio varchar(2));
CREATE TABLE T3.Nota_T3 (Factura varchar(30), Grupo_Precio varchar(2));
CREATE SEQUENCE EAI_OWNER.ProcessID AS bigint START WITH 1;
'@
    Invoke-TestSql (Get-Content -Raw (Join-Path $t3Root 'EAI_OWNER/Procedures/LOG_START.SQL'))
    Invoke-TestSql (Get-Content -Raw (Join-Path $t3Root 'EAI/Procedures/SF_BITACORA_CFDI_RESUMEN.SQL'))
    Write-Output 'COMPILE_OK SF_BITACORA_CFDI_RESUMEN'
    Invoke-TestSql (Get-Content -Raw (Join-Path $PSScriptRoot 'Behavior.sql'))
} finally {
    # Solo elimina la base aleatoria creada para esta prueba.
    & sqlcmd -S $Server -E -No -b -Q "IF DB_ID(N'$db') IS NOT NULL BEGIN ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]; END"
}
