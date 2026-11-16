param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference = 'Stop'
$procedures = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$original = [IO.File]::ReadAllText((Join-Path $procedures 'PROC_V40_GENERAR_MX06AD.sql'), [Text.Encoding]::Unicode)
$corrected = [IO.File]::ReadAllText((Join-Path $procedures 'PROC_V40_GENERAR_MX06AD_CORREGIDO.sql'), [Text.Encoding]::Unicode)

# Conservar FETCH y formulas. Se permite mover la diferencia antes de los INSERT,
# inicializar el contador y retirar dos tasas provisionales reemplazadas por 16.
foreach ($pattern in @('^\s*SET @n', '^\s*FETCH ')) {
    $excluded = '@nTimbrados\s*=\s*0;|SET @n(?:Envio|Credito)_TASA = ROUND'
    $before = @($original -split '\r?\n' | Where-Object { $_ -match $pattern -and $_ -notmatch $excluded })
    $after = @($corrected -split '\r?\n' | Where-Object { $_ -match $pattern -and $_ -notmatch $excluded })
    if ($pattern -eq '^\s*SET @n') { $before = @($before | Sort-Object); $after = @($after | Sort-Object) }
    if (($before -join "`n") -cne ($after -join "`n")) { throw "Cambio inesperado: $pattern" }
}
if ($corrected -notmatch 'CREATE OR ALTER PROCEDURE \[T3\]\.\[PROC_V40_GENERAR_MX06AD_CORREGIDO\]') {
    throw 'Nombre de procedimiento inesperado.'
}
if ([regex]::Matches($corrected, '(?m)^\s*DECLARE Scr\w+ CURSOR').Count -ne 9) {
    throw 'Se esperan 8 cursores y dos sitios excluyentes de ScrPedimento.'
}
Write-Output 'OK: asignaciones numericas, FETCH e identidad de la version separada.'

# Extraer solo el JOIN exterior de ScrDatos; no confundirlo con ScrDetalle/UsoC_in.
$scrDatos = [regex]::Match($corrected, '(?s)DECLARE ScrDatos CURSOR.*?OPEN ScrDatos;').Value
$join = [regex]::Match($scrDatos, '(?m)^\s*(LEFT JOIN T3\.CFDI_USOCFDI_CLIENTE UsoC ON RF\.Cliente_SAP = UsoC\.Cliente_SAP)\s*$')
if (-not $join.Success) { throw 'ScrDatos no conserva la relacion opcional UsoC de Oracle.' }
$fixtureJoin = $join.Groups[1].Value.Replace('T3.CFDI_USOCFDI_CLIENTE', '@UsoC')

# Probar las expresiones reales; las dos consultas de pedimentos deben coincidir.
$dateSql = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Validar_Fechas.sql'))
foreach ($field in @('FePedido','FeNotaEnt','FecPedimento')) {
    $expressions = [regex]::Matches($corrected, '(?m)^[ \t]*(.+?) AS '+$field+'[, \t]*\r?$')
    $expectedCount = if ($field -eq 'FecPedimento') { 2 } else { 1 }
    if ($expressions.Count -ne $expectedCount) { throw "No se encontraron las expresiones de $field" }
    $expression = $expressions[0].Groups[1].Value
    foreach ($found in $expressions) {
        if ($found.Groups[1].Value -cne $expression) { throw "Expresiones distintas para $field" }
    }
    $expression = $expression.Replace('RF.Fecha_Factura','c.Fecha').Replace('SAT.Fecha_Pedimento','c.Fecha').Replace('Comp.Hora_Factura','c.Hora')
    $dateSql = $dateSql.Replace('/*'+$field+'*/', $expression)
}

# PARSEONLY impide ejecutar USE/DDL/DML; ademas se retira el contexto T3QA.
$parsePath = Join-Path ([IO.Path]::GetTempPath()) ('mx06ad_parse_' + [guid]::NewGuid().ToString('N') + '.sql')
$joinPath = Join-Path ([IO.Path]::GetTempPath()) ('mx06ad_join_' + [guid]::NewGuid().ToString('N') + '.sql')
$datePath = Join-Path ([IO.Path]::GetTempPath()) ('mx06ad_dates_' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    $parse = "SET PARSEONLY ON;`r`nGO`r`n" + $corrected.Replace('USE [T3QA]', '-- Contexto omitido para PARSEONLY')
    [IO.File]::WriteAllText($parsePath, $parse, [Text.Encoding]::Unicode)
    & sqlcmd -S $Server -E -No -b -i $parsePath
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de sintaxis.' }
    Write-Output 'OK: PARSEONLY de la definicion completa; sin despliegue.'
    & sqlcmd -S $Server -E -No -b -i (Join-Path $PSScriptRoot 'Validar_Concatenacion.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de pruebas aisladas.' }
    $joinSql = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Validar_Joins.sql')).Replace('/*JOIN_BAJO_PRUEBA*/', $fixtureJoin)
    [IO.File]::WriteAllText($joinPath, $joinSql, [Text.Encoding]::Unicode)
    & sqlcmd -S $Server -E -No -b -i $joinPath
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de pruebas de JOIN.' }
    [IO.File]::WriteAllText($datePath, $dateSql, [Text.Encoding]::Unicode)
    & sqlcmd -S $Server -E -No -b -i $datePath
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de pruebas de fechas.' }
    & (Join-Path $PSScriptRoot 'Validar_Numericos.ps1') -Server $Server
} finally {
    if (Test-Path -LiteralPath $parsePath) { Remove-Item -LiteralPath $parsePath }
    if (Test-Path -LiteralPath $joinPath) { Remove-Item -LiteralPath $joinPath }
    if (Test-Path -LiteralPath $datePath) { Remove-Item -LiteralPath $datePath }
}
