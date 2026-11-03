param([Parameter(Mandatory=$true)][string]$Entrada)
$ErrorActionPreference='Stop'
$inputPath=(Resolve-Path -LiteralPath $Entrada).Path
$runtime=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if(-not (Test-Path -LiteralPath $runtime)) {
    $candidate=Get-Command python -ErrorAction SilentlyContinue
    if(-not $candidate -or $candidate.Source -like '*WindowsApps*') {
        throw 'Se necesita Python 3. Ejecutar 03_preparar_carga.py con una instalacion disponible.'
    }
    $runtime=$candidate.Source
}
& $runtime (Join-Path $PSScriptRoot '03_preparar_carga.py') --entrada $inputPath
if($LASTEXITCODE -ne 0){throw 'El origen no paso la validacion. No ejecutar la reparacion.'}
