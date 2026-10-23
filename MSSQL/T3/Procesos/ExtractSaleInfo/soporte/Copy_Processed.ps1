param([Parameter(Mandatory=$true)][string]$Archivo,
      [Parameter(Mandatory=$true)][string]$Directorio)
$ErrorActionPreference = 'Stop'
try {
    [void][IO.Directory]::CreateDirectory($Directorio)
    $stamp = (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '_' + [guid]::NewGuid().ToString('N')
    $name = [IO.Path]::GetFileNameWithoutExtension($Archivo) + '_' + $stamp + [IO.Path]::GetExtension($Archivo)
    Copy-Item -LiteralPath $Archivo -Destination (Join-Path $Directorio $name) -ErrorAction Stop
} catch { Write-Error $_; exit 1 }
