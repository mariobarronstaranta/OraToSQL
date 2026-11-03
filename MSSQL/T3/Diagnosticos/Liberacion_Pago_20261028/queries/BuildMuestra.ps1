$ErrorActionPreference='Stop'
$folder=Split-Path -Parent $PSScriptRoot
$full=[IO.File]::ReadAllText((Join-Path $folder '01_VALIDAR_PRECONDICIONES.sql'))
$pos=$full.IndexOf('/* INICIO_DATOS_GENERADOS */')
if($pos -lt 0){throw 'No se encontro el encabezado de precondiciones.'}
$head=$full.Substring(0,$pos)
$head=[regex]::Replace($head,'(?s)\A/\*.*?\*/',@'
/*
  Sustituye al diagnostico exhaustivo 01 para la siguiente captura.
  SOLO MUESTRA de hasta 100 filas preseleccionadas; no certifica todo el lote.
  Solo lectura/temporales. No ejecuta SP de negocio, no consume secuencias.
  El TOP se aplica antes de validar RFC y leer relaciones. Se inspeccionan
  accesos por metadatos antes de consultar tablas grandes. Sin calculo fiscal.
  TOP no garantiza un tiempo maximo: enviar la ultima etapa si se demora.
*/
'@)
$head=$head.Replace('DECLARE @MaxDetalle int=200;',"DECLARE @MaxDetalle int=100;`r`nDECLARE @MaxMuestra int=100;")
$head=$head.Replace('Ver 11/12.','Revisar facturas de la muestra en 12.')
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DatosPrecondiciones.sql'))
$start=$body.IndexOf('-- Base de diagnostico:')
$end=$body.IndexOf('-- Mantener la multiplicidad')
if($start -lt 0 -or $end -le $start){throw 'No se encontro el bloque base del diagnostico.'}
$base=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'BaseMuestra.sql'))
$body=$body.Substring(0,$start)+$base+"`r`n"+$body.Substring($end)
$guard=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'GuardiaMuestra.sql'))
$body=$guard+"`r`n"+$body
$body=$body.Replace('07_RESUMEN_CANDIDATOS','07_RESUMEN_MUESTRA').Replace('CobranzasPendientesVia01','CobranzasPreseleccionadasMuestra')
$body=$body.Replace('07B_FILTROS_NO_SUPERADOS','07B_FILTROS_MUESTRA')
$body=$body.Replace('SELECT C.* INTO #Alcance', 'SELECT TOP(1000) C.* INTO #Alcance')
$anchor='-- Reproducir los JOIN'
$body=$body.Replace($anchor,@'
IF (SELECT COUNT_BIG(*) FROM #Alcance)>=1000
BEGIN
 SELECT '08L_LIMITE_ALCANCE' AS Seccion,N'La muestra alcanza 1000 cobranzas por sus IDs. Detenido antes de sus relaciones; no inferir cabeceras ausentes.' AS Resultado;
 RETURN;
END;
RAISERROR(N'Etapa M5: revisar cabeceras y datos de las asignaciones de la muestra.',10,1) WITH NOWAIT;
-- Reproducir los JOIN
'@)
$body=$body.Replace('SELECT A.Asignacion_ID,A.Factura,A.Ctro,A.Sociedad,A.Importe,A.Saldo_Anterior,',
 'SELECT TOP(2000) A.Asignacion_ID,A.Factura,A.Ctro,A.Sociedad,A.Importe,A.Saldo_Anterior,')
$body=$body.Replace('CREATE TABLE #Hallazgos',@'
IF (SELECT COUNT_BIG(*) FROM #Cabeceras)>=2000
BEGIN
 SELECT '08L_LIMITE_CABECERAS' AS Seccion,N'Las relaciones alcanzan 2000 cabeceras. Detenido sin diagnosticar ausencias sobre una lista truncada.' AS Resultado;
 RETURN;
END;
CREATE TABLE #Hallazgos
'@)
$cut=$body.IndexOf('-- Dos claves de consulta:')
if($cut -lt 0){throw 'No se encontro el inicio del calculo fiscal.'}
$body=$body.Substring(0,$cut)
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DatosPrecondiciones.sql'))
$tail=$original.IndexOf("SELECT TOP(@MaxDetalle) '09_RELACIONES_GENERADOR'")
if($tail -lt 0){throw 'No se encontro la salida de muestra.'}
$out=$original.Substring($tail)
$out=[regex]::Replace($out,"(?m)^SELECT TOP\(@MaxDetalle\) '11_FISCAL'.*?;\r?\n",'')
$out=$out.Substring(0,$out.IndexOf("SELECT '13_ALCANCE'"))
$body+=$out+@'
SELECT '13_ALCANCE_MUESTRA' AS Seccion,
 N'MUESTRA: no es conteo global ni se verifican importes fiscales/impuestos de todo el lote. No ejecuta negocio. '
 +N'El SP real procesaria TODOS sus candidatos. La muestra no autoriza afirmar que todo el lote esta listo. '
 +N'Se conserva la multiplicidad de documentos de las notas muestreadas. Si no aparecen candidatos, no se concluye que no existan en el resto.' AS Resultado;
'@
$payload="BEGIN TRY`r`n EXEC sys.sp_executesql N'"+$body.Replace("'","''")+"',N'@MaxDetalle int,@MaxMuestra int,@FacturaCorta bit',@MaxDetalle=@MaxDetalle,@MaxMuestra=@MaxMuestra,@FacturaCorta=@FacturaCorta;`r`nEND TRY`r`nBEGIN CATCH`r`n SELECT '99_ERROR_DIAGNOSTICO' AS Seccion,ERROR_NUMBER() AS Numero,ERROR_LINE() AS Linea,ERROR_MESSAGE() AS Mensaje;`r`n THROW;`r`nEND CATCH;"
$dest=Join-Path $folder '04_VALIDAR_MUESTRA_LIGERA.sql'
[IO.File]::WriteAllText($dest,$head+$payload,(New-Object Text.UTF8Encoding($false)))
'BUILD_OK 04_VALIDAR_MUESTRA_LIGERA.sql'
