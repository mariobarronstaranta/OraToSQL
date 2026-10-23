<# Windows PowerShell 5.1. ADO.NET conserva tipos y exporta sin limites de ancho de sqlcmd. #>
[CmdletBinding()]
param(
    [ValidateSet('PBI','Diff','POD')][string]$Reporte = 'PBI',
    [switch]$Mensual,
    [switch]$NoPublicar,
    [string]$Servidor = $env:ESI_SERVER,
    [string]$BaseDatos = $env:ESI_DATABASE,
    [string]$Destino = $env:ESI_DESTINO,
    [string]$DirectorioTrabajo = (Join-Path $PSScriptRoot 'work'),
    [string]$DirectorioHistorico = (Join-Path $PSScriptRoot 'Processed'),
    [ValidateRange(1,86400)][int]$TimeoutSegundos = 600
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$connection = $null
$lockAcquired = $false
$runFolder = $null
$manifest = $null
$invariant = [Globalization.CultureInfo]::InvariantCulture

function Read-Sql([string]$RelativePath, [int]$Depth = 0) {
    if ($Depth -gt 8) { throw 'Demasiadas inclusiones SQL.' }
    $root = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $RelativePath))
    if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta SQL fuera del proceso.' }
    $lines = foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*:r\s+(.+?)\s*$') { Read-Sql $Matches[1] ($Depth + 1) }
        else { $line }
    }
    return $lines -join "`r`n"
}
function New-Command([string]$Sql) {
    $command = $connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = $TimeoutSegundos
    return $command
}
function Execute-Sql([string]$Sql) {
    $command = New-Command $Sql
    try { [void]$command.ExecuteNonQuery() } finally { $command.Dispose() }
}
function Scalar([string]$Sql) {
    $command = New-Command $Sql
    try { return $command.ExecuteScalar() } finally { $command.Dispose() }
}
function Save-Manifest {
    $json = $manifest | ConvertTo-Json -Depth 6
    # Antivirus/indexadores pueden abrir brevemente el archivo entre actualizaciones.
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            [IO.File]::WriteAllText((Join-Path $runFolder 'ejecucion.json'), $json, [Text.UTF8Encoding]::new($true))
            return
        } catch [IO.IOException] {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Milliseconds 100
        }
    }
}
function Csv-Value($Value) {
    if ($null -eq $Value -or $Value -is [DBNull]) { return '' }
    if ($Value -is [IFormattable]) { $valueText = $Value.ToString($null, $invariant) }
    else { $valueText = [string]$Value }
    if ($valueText.IndexOfAny([char[]]",`"`r`n") -ge 0) {
        return '"' + $valueText.Replace('"', '""') + '"'
    }
    return $valueText
}
function Export-Query([string]$Sql, [string]$Path, [int]$ExpectedColumns) {
    $command = New-Command $Sql
    $reader = $null
    $writer = $null
    try {
        $reader = $command.ExecuteReader()
        if ($reader.FieldCount -ne $ExpectedColumns) { throw "Contrato CSV incorrecto: $($reader.FieldCount) columnas." }
        $writer = [IO.StreamWriter]::new($Path, $false, [Text.UTF8Encoding]::new($true))
        $headers = for ($i = 0; $i -lt $reader.FieldCount; $i++) { Csv-Value ($reader.GetName($i)) }
        $writer.WriteLine(($headers -join ','))
        [long]$rows = 0
        while ($reader.Read()) {
            $values = for ($i = 0; $i -lt $reader.FieldCount; $i++) { Csv-Value ($reader.GetValue($i)) }
            $writer.WriteLine(($values -join ','))
            $rows++
        }
        # Consume el resto del batch: detecta errores posteriores al SELECT.
        while ($reader.NextResult()) {
            if ($reader.FieldCount -gt 0) { throw 'El batch devolvio un resultado adicional no previsto.' }
        }
        return $rows
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($reader) { $reader.Dispose() }
        $command.Dispose()
    }
}
function Publish-File([string]$Source, [string]$Target) {
    # Temporal en el mismo volumen: el consumidor no ve un CSV a medio escribir.
    $temporary = $Target + '.' + $manifest.Lote + '.tmp'
    [IO.File]::Copy($Source, $temporary, $false)
    if ([IO.File]::Exists($Target)) { [IO.File]::Replace($temporary, $Target, [System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($temporary, $Target) }
}

try {
    if (-not $Servidor -or -not $BaseDatos) { throw 'Configure ESI_SERVER y ESI_DATABASE o los parametros Servidor/BaseDatos.' }
    if ($Mensual -and $Reporte -eq 'POD') { throw 'POD no tiene variante mensual.' }
    if (-not $NoPublicar -and (-not $Destino -or -not [IO.Directory]::Exists($Destino))) {
        throw 'El directorio de entrega debe existir. Configure ESI_DESTINO o use -NoPublicar para QA.'
    }
    [void][IO.Directory]::CreateDirectory($DirectorioTrabajo)
    [void][IO.Directory]::CreateDirectory($DirectorioHistorico)
    $id = (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '_' + [guid]::NewGuid().ToString('N')
    $runFolder = Join-Path $DirectorioTrabajo $id
    [void][IO.Directory]::CreateDirectory($runFolder)
    $manifest = [ordered]@{ Lote=$id; Reporte=$Reporte; Mensual=[bool]$Mensual;
        NoPublicar=[bool]$NoPublicar; Estado='Iniciado'; Archivos=@(); Error=$null }
    Save-Manifest

    $builder = [Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source'] = $Servidor
    $builder['Initial Catalog'] = $BaseDatos
    $builder['Application Name'] = 'ExtractSaleInfo'
    # LocalDB usa transporte local y no admite TLS; conexiones de servidor si lo exigen.
    $builder['Encrypt'] = -not $Servidor.StartsWith('(localdb)\', [StringComparison]::OrdinalIgnoreCase)
    $builder['TrustServerCertificate'] = ($env:ESI_TRUST_CERTIFICATE -eq '1')
    if ($env:ESI_USER) {
        if (-not $env:SQLCMDPASSWORD) { throw 'ESI_USER requiere SQLCMDPASSWORD.' }
        $builder['User ID'] = $env:ESI_USER
        $builder['Password'] = $env:SQLCMDPASSWORD
    } else { $builder['Integrated Security'] = $true }
    $connection = [Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    $connection.Open()
    Execute-Sql @'
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @Result int;
EXEC @Result = sys.sp_getapplock @Resource = N'ExtractSaleInfo',
     @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
IF @Result < 0 THROW 54602, 'Ya hay otra ejecucion de ExtractSaleInfo en esta base.', 1;
'@
    $lockAcquired = $true

    # Se validan todos los reportes del lote ANTES del procedimiento con escrituras.
    $required = @('EAI.SF_BITACORA_CFDI_VENTA_SF','EAI.FC__TIME_WINDOW')
    if ($Reporte -eq 'Diff') { $required = @('EAI.FC__TIME_WINDOW') }
    if ($Reporte -eq 'POD') { $required += @('EAI_OWNER.FACTURAS_B','EAI_OWNER.CLIENT') }
    else {
        $required += @('EAI.CFDI_BITACORA','EAI.CFDI_INFORME','T3.PREVENTA_GENERAL',
            'T3.MOV_CLIENTE','EAI_OWNER.DOCTOS_CANCELLED','T3.FN_CFDI_REFOLEO','T3.CFDI_REFOLEO',
            'T3.CFDI_DOCUMENTOS','EAI.CIFRAS_COMENTARIOS','EAI_OWNER.CHK_ZLOB_DOCUMENT',
            'EAI.CONTROL_REPORTE','EAI_OWNER.TMP_DOCUMENT_HEADER')
    }
    foreach ($object in $required) {
        if ([int](Scalar "SELECT COUNT(*) FROM sys.objects WHERE object_id=OBJECT_ID(N'$object');") -ne 1) {
            throw "Falta la dependencia $object o no es visible para el usuario."
        }
    }
    Execute-Sql @'
IF NOT EXISTS (SELECT 1 FROM EAI.FC__TIME_WINDOW)
    THROW 54603, 'FC__TIME_WINDOW no tiene configuracion.', 1;
IF EXISTS (SELECT 1 FROM EAI.FC__TIME_WINDOW WHERE TRY_CONVERT(date, Start_Date, 103) IS NULL)
    THROW 54604, 'FC__TIME_WINDOW.Start_Date invalido.', 1;
'@
    if ($Mensual) {
        Execute-Sql "IF EXISTS (SELECT 1 FROM EAI.FC__TIME_WINDOW WHERE TRY_CONVERT(date, End_Date, 103) IS NULL) THROW 54605, 'FC__TIME_WINDOW.End_Date invalido.', 1;"
    }
    $suffix = if ($Mensual) { '-Mensual' } else { '' }
    $jobs = @()
    if ($Reporte -eq 'PBI') {
        $jobs += @{ File='VENTAS.CSV'; Query="ExtractPBI$suffix.sql"; Columns=17; Control='AUTO-CIFRAS VENTAS' }
    }
    if ($Reporte -in @('PBI','Diff')) {
        $jobs += @{ File='DIFF_VENTAS.CSV'; Query="ExtractDiffSale$suffix.sql"; Columns=20; Control='AUTO-CIFRAS VENTAS DIFF' }
    } else {
        $jobs += @{ File='PROOF_OF_DELIVERY.CSV'; Query='ExtractPOD.sql'; Columns=2; Control='' }
    }
    foreach ($job in $jobs) {
        if ($job.Control -and -not $NoPublicar) {
            $count = Scalar "SELECT COUNT(*) FROM EAI.CONTROL_REPORTE WHERE Reporte=N'$($job.Control)';"
            if ([int]$count -ne 1) { throw "Se requiere una fila de CONTROL_REPORTE para $($job.Control)." }
        }
    }
    $started = Scalar 'SELECT GETDATE();'
    if ($Reporte -ne 'Diff') { Execute-Sql (Read-Sql 'soporte/Preparar.sql') }
    foreach ($job in $jobs) {
        $path = Join-Path $runFolder $job.File
        $rows = Export-Query (Read-Sql $job.Query) $path $job.Columns
        $manifest.Archivos += [ordered]@{ Archivo=$job.File; Filas=$rows; Historico=$null; Publicado=$false }
        Save-Manifest
    }
    # Ningun CSV se publica hasta que todas las consultas del lote han terminado.
    foreach ($item in $manifest.Archivos) {
        $source = Join-Path $runFolder $item.Archivo
        $archive = Join-Path $DirectorioHistorico ([IO.Path]::GetFileNameWithoutExtension($item.Archivo) + '_' + $id + '.CSV')
        [IO.File]::Copy($source, $archive, $false)
        $item.Historico = $archive
        Save-Manifest
    }
    if (-not $NoPublicar) {
        foreach ($item in $manifest.Archivos) {
            Publish-File (Join-Path $runFolder $item.Archivo) (Join-Path $Destino $item.Archivo)
            $item.Publicado = $true
            Save-Manifest
        }
        $transaction = $connection.BeginTransaction()
        try {
            foreach ($job in $jobs) {
                if (-not $job.Control) { continue }
                $command = New-Command 'UPDATE EAI.CONTROL_REPORTE SET Inicio=@Inicio, Fin=GETDATE() WHERE Reporte=@Reporte; IF @@ROWCOUNT <> 1 THROW 54606, ''Fila de control ausente o duplicada.'', 1;'
                try {
                    $command.Transaction = $transaction
                    [void]$command.Parameters.Add('@Inicio', [Data.SqlDbType]::DateTime2)
                    $command.Parameters['@Inicio'].Value = $started
                    [void]$command.Parameters.Add('@Reporte', [Data.SqlDbType]::NVarChar, 100)
                    $command.Parameters['@Reporte'].Value = $job.Control
                    [void]$command.ExecuteNonQuery()
                } finally { $command.Dispose() }
            }
            $transaction.Commit()
        } catch { $transaction.Rollback(); throw } finally { $transaction.Dispose() }
        foreach ($item in $manifest.Archivos) { [IO.File]::Delete((Join-Path $runFolder $item.Archivo)) }
    }
    $manifest.Estado = if ($NoPublicar) { 'GeneradoSinPublicar' } else { 'Publicado' }
    Save-Manifest
    Write-Output "OK: $($manifest.Estado). Detalle: $runFolder"
} catch {
    $failure = $_.Exception.Message
    if ($manifest) {
        $manifest.Estado = 'Error'
        $manifest.Error = $failure
        try { Save-Manifest } catch { [Console]::Error.WriteLine('No se pudo guardar el manifiesto.') }
    }
    [Console]::Error.WriteLine("ERROR: $failure. Diagnostico: $runFolder")
    exit 1
} finally {
    # Dispose puede devolver la conexion al pool: liberar el applock explicitamente.
    if ($connection) {
        if ($lockAcquired -and $connection.State -eq [Data.ConnectionState]::Open) {
            try { Execute-Sql "EXEC sys.sp_releaseapplock @Resource=N'ExtractSaleInfo', @LockOwner='Session';" }
            catch { [Data.SqlClient.SqlConnection]::ClearPool($connection) }
        }
        $connection.Dispose()
    }
}
