$ErrorActionPreference='Stop'
$folder=Split-Path -Parent $PSScriptRoot
$path=Join-Path $folder '01_VALIDAR_PRECONDICIONES.sql'
$main=[IO.File]::ReadAllText($path)
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DatosPrecondiciones.sql'))
$start='/* INICIO_DATOS_GENERADOS */'
$end='/* FIN_DATOS_GENERADOS */'
$a=$main.IndexOf($start)
$b=$main.IndexOf($end)
if($a -lt 0 -or $b -le $a){throw 'No se encontraron delimitadores del wrapper.'}
$payload=$start+"`r`nBEGIN TRY`r`n EXEC sys.sp_executesql N'"+$body.Replace("'","''")+"',N'@MaxDetalle int,@FacturaCorta bit',@MaxDetalle=@MaxDetalle,@FacturaCorta=@FacturaCorta;`r`nEND TRY`r`nBEGIN CATCH`r`n SELECT '99_ERROR_DIAGNOSTICO' AS Seccion,ERROR_NUMBER() AS Numero,ERROR_LINE() AS Linea,ERROR_MESSAGE() AS Mensaje;`r`n THROW;`r`nEND CATCH;`r`n"+$end
$main=$main.Substring(0,$a)+$payload+$main.Substring($b+$end.Length)
[IO.File]::WriteAllText($path,$main,(New-Object Text.UTF8Encoding($false)))
'BUILD_OK 01_VALIDAR_PRECONDICIONES.sql'
