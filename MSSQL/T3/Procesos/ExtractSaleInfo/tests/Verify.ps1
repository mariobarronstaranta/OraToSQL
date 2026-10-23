# QA LocalDB con datos sinteticos. No conecta a bases de negocio.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$repo=[IO.Path]::GetFullPath((Join-Path $root '../../../..'))
$server='(localdb)\MSSQLLocalDB'
$db='CodexExtractSale_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$work=Join-Path $PSScriptRoot "work/$db"
$dest=Join-Path $work 'destino'
[void][IO.Directory]::CreateDirectory($dest)
$created=$false
function Sql([string]$Query,[string]$Database=$db){
 $c=[Data.SqlClient.SqlConnection]::new("Data Source=$server;Initial Catalog=$Database;Integrated Security=True;Encrypt=False")
 try{
  $c.Open()
  foreach($batch in [regex]::Split($Query,'(?im)^\s*GO\s*\r?$')){
   if(-not $batch.Trim()){continue}
   $cmd=$c.CreateCommand()
   try{$cmd.CommandTimeout=90;$cmd.CommandText=$batch;$value=$cmd.ExecuteScalar();if($null -ne $value){$value}}
   finally{$cmd.Dispose()}
  }
 }finally{$c.Dispose()}
}
function Assert($Condition,[string]$Message){if(-not $Condition){throw "ASSERT: $Message"}}
function Run([string]$Report='PBI',[string[]]$Options=@(),[bool]$Ok=$true){
 $env:ESI_SERVER=$server;$env:ESI_DATABASE=$db;$env:ESI_DESTINO=$dest;$env:ESI_TRUST_CERTIFICATE='1';$env:ESI_USER=''
 $argsList=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'Exportar_CSV.ps1'),'-Reporte',$Report,
  '-DirectorioTrabajo',(Join-Path $work 'runs'),'-DirectorioHistorico',(Join-Path $work 'Processed'))+$Options
 $saved=$ErrorActionPreference;$ErrorActionPreference='Continue'
 $output=& powershell.exe @argsList 2>&1
 $code=$LASTEXITCODE;$ErrorActionPreference=$saved
 $output | Out-File -LiteralPath (Join-Path $work 'ultima_ejecucion.log') -Encoding utf8
 Assert (($code -eq 0) -eq $Ok) ("Ejecucion $Report : $code`n"+($output -join "`n"))
 $file=Get-ChildItem -LiteralPath (Join-Path $work 'runs') -Recurse -Filter ejecucion.json | Sort-Object LastWriteTimeUtc | Select-Object -Last 1
 $manifest=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
 $expected=if(-not $Ok){'Error'}elseif($Options -contains '-NoPublicar'){'GeneradoSinPublicar'}else{'Publicado'}
 Assert ($manifest.Estado -eq $expected) 'Estado del manifiesto'
 return @{Folder=$file.DirectoryName;Manifest=$manifest}
}
function Rows([string]$Name,[string]$Folder=$dest,[int]$Fields=0){
 $path=Join-Path $Folder $Name
 $headerReader=[IO.File]::OpenText($path)
 try{$header=$headerReader.ReadLine()}finally{$headerReader.Dispose()}
 if($Fields){Assert (($header.Split(',')).Count -eq $Fields) "Columnas $Name"}
 Import-Csv -LiteralPath $path -Encoding UTF8
}
function Hashes{(Get-ChildItem -LiteralPath $dest -Filter '*.CSV' | Sort-Object Name | Get-FileHash).Hash -join ','}
try{
 Sql "CREATE DATABASE [$db];" 'master';$created=$true
 Sql (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Schema.sql') -Raw -Encoding UTF8)
 $refoleo=Get-Content -LiteralPath (Join-Path $repo 'MSSQL/T3/T3/Funciones/FN_CFDI_REFOLEO.SQL') -Raw -Encoding UTF8
 $refoleo=[regex]::Replace($refoleo,'(?im)^USE\s+\[[^]]+\]\s*$','')
 $refoleo=[regex]::Replace($refoleo,'(?i)ALTER\s+FUNCTION','CREATE OR ALTER FUNCTION')
 Sql $refoleo
 Sql (Get-Content -LiteralPath (Join-Path $repo 'MSSQL/T3/EAI_OWNER/Functions/CHK_ZLOB_DOCUMENT.SQL') -Raw -Encoding UTF8)
 $result=Run
 $sales=@(Rows 'VENTAS.CSV' $dest 17);$diffs=@(Rows 'DIFF_VENTAS.CSV' $dest 20)
 Assert ($sales.Count -eq 9 -and $diffs.Count -eq 5) "Conteos ventas=$($sales.Count), diferencias=$($diffs.Count)"
 $byid=@{};foreach($r in $sales){$byid[$r.SFDC_REFERENCE]=$r}
 $diff=@{};foreach($r in $diffs){$diff[$r.'REFERENCIA TMD']=$r}
 Assert ((($byid.Keys | Sort-Object) -join ',') -eq 'B,C,D,E,F,G,H,N,SAP-A') 'Universo de ventas'
 Assert ((($diff.Keys | Sort-Object) -join ',') -eq 'C,D,E,G,N') 'Universo de diferencias'
 $expected=@{'SAP-A'=100;B=-100;C=100;D=100;E=0;H=0}
 foreach($key in $expected.Keys){Assert ([decimal]$byid[$key].PAC_SALES_AMOUNT -eq $expected[$key]) "Rama SAT $key"}
 Assert ($byid['SAP-A'].SAP_ORDER -eq 'SAP-A') 'Refoleo real'
 Assert ($byid['SAP-A'].DOCUMENT_TYPE -eq 'Presales') 'Clasificacion preventa'
 Assert ($byid['SAP-A'].NOMBRE_CLIENTE -eq ('Compa'+[char]0x00F1+[char]0x00ED+'a  "QA"')) 'Nombre con caracteres y comillas'
 Assert ([decimal]$diff.N.DIFERENCIA -eq -20 -and [decimal]$diff.D.DIFERENCIA -eq 20) 'Signos y suma de diferencias'
 Assert ($diff.D.ZLOB_PROCESS -eq 'LOB-Ok') 'Funcion real ZLOB'
 Assert ($diff.D.FECHA_EDICOM -eq '2026-07-01 12:34:56') 'Fecha EDICOM'
 Assert ($diff.D.COMENTARIOS -eq ('Comentario, "QA"'+"`r`n"+('z'*6000))) 'Comentario largo con comas y salto de linea'
 Assert ([decimal]$diff.G.DIFERENCIA -eq [decimal]0.051 -and $byid.G.DIFERENCIA -eq '0.05') 'Umbral antes de redondear'
 Assert ((Sql 'SELECT Llamadas FROM EAI.TestPreparacion;') -eq 1) 'Una preparacion PBI'
 foreach($item in $result.Manifest.Archivos){
  Assert ((Get-FileHash -LiteralPath $item.Historico).Hash -eq (Get-FileHash -LiteralPath (Join-Path $dest $item.Archivo)).Hash) 'Respaldo identico'
  Assert (-not(Test-Path -LiteralPath (Join-Path $result.Folder $item.Archivo))) 'Borrado local tras entrega'
 }
 Assert ((Sql 'SELECT COUNT(*) FROM EAI.CONTROL_REPORTE WHERE Fin>=Inicio;') -eq 2) 'Control de entrega'
 Write-Output 'OK ventas/diferencias: reglas SAT, signos, umbral, refoleo y ZLOB reales, CSV y entrega.'
 $null=Run 'POD'
 $pod=@(Rows 'PROOF_OF_DELIVERY.CSV' $dest 2)
 Assert ((($pod.Doc_Num | Sort-Object) -join ',') -eq 'P0,P10,PF') 'POD: limite, futuro, RFC y nulos'
 Assert (($pod | Where-Object Doc_Num -eq 'P0').Proof_of_Delivery -eq 'POD,"QA"') 'Escape POD'
 $null=Run 'Diff'
 Assert ((Sql 'SELECT Llamadas FROM EAI.TestPreparacion;') -eq 2) 'Diff no ejecuta preparacion; POD si'
 Write-Output 'OK POD y ejecucion independiente de diferencias.'
 $result=Run 'PBI' @('-Mensual','-NoPublicar')
 Assert (@(Rows 'VENTAS.CSV' $result.Folder 17).Count -eq 9) 'Mensual PBI conserva exclusiones'
 Assert (@(Rows 'DIFF_VENTAS.CSV' $result.Folder 20).Count -eq 7) 'Mensual Diff usa End_Date'
 Sql 'INSERT EAI.FC__TIME_WINDOW SELECT * FROM EAI.FC__TIME_WINDOW;'
 $result=Run 'Diff' @('-NoPublicar')
 Assert (@(Rows 'DIFF_VENTAS.CSV' $result.Folder 20).Count -eq 10) 'Multiplicidad de ventanas'
 Sql 'WITH W AS(SELECT *,ROW_NUMBER() OVER(ORDER BY Start_Date) rn FROM EAI.FC__TIME_WINDOW) DELETE W WHERE rn>1;'
 Sql 'INSERT EAI_OWNER.DOCTOS_CANCELLED VALUES(NULL);'
 $result=Run 'PBI' @('-NoPublicar')
 Assert (@(Rows 'VENTAS.CSV' $result.Folder 17).Count -eq 0) 'NOT IN con NULL y encabezado vacio'
 Assert (@(Rows 'DIFF_VENTAS.CSV' $result.Folder 20).Count -eq 0) 'Diff vacio'
 Sql 'DELETE EAI_OWNER.DOCTOS_CANCELLED WHERE Referencia IS NULL;'
 Write-Output 'OK variantes mensuales, multiplicidad, nulos y archivos sin datos.'
 $before=Hashes
 Sql 'UPDATE EAI.TestPreparacion SET Fallar=1;'
 $null=Run 'PBI' @() $false
 Assert ((Hashes) -eq $before) 'Fallo del procedimiento conserva entregas'
 Sql 'UPDATE EAI.TestPreparacion SET Fallar=0;'
 $calls=Sql 'SELECT Llamadas FROM EAI.TestPreparacion;'
 Sql 'DROP FUNCTION T3.FN_CFDI_REFOLEO;'
 $null=Run 'PBI' @() $false
 Assert ((Sql 'SELECT Llamadas FROM EAI.TestPreparacion;') -eq $calls) 'Dependencia faltante antes de escrituras'
 Assert ((Hashes) -eq $before) 'Dependencia faltante conserva entregas'
 Sql $refoleo
 Sql "UPDATE EAI.FC__TIME_WINDOW SET Start_Date='INVALIDA';"
 $null=Run 'PBI' @() $false
 Assert ((Sql 'SELECT Llamadas FROM EAI.TestPreparacion;') -eq $calls) 'Fecha invalida antes de escrituras'
 Sql "UPDATE EAI.FC__TIME_WINDOW SET Start_Date=CONVERT(char(10),DATEADD(day,-20,GETDATE()),103);"
 Write-Output 'OK fallos de preparacion, dependencia y fecha sin publicacion ni borrado de entregas anteriores.'
 # Un consumidor mantiene abierto el destino: se conserva el CSV nuevo para recuperar.
 $control=Sql "SELECT CONVERT(varchar(33),Fin,126) FROM EAI.CONTROL_REPORTE WHERE Reporte='AUTO-CIFRAS VENTAS DIFF';"
 $held=[IO.File]::Open((Join-Path $dest 'DIFF_VENTAS.CSV'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
 try{$result=Run 'Diff' @() $false}finally{$held.Dispose()}
 Assert ((Hashes) -eq $before) 'Fallo de copia conserva entrega anterior'
 Assert (Test-Path -LiteralPath (Join-Path $result.Folder 'DIFF_VENTAS.CSV')) 'Fallo de copia conserva nuevo archivo'
 Assert ((Sql "SELECT CONVERT(varchar(33),Fin,126) FROM EAI.CONTROL_REPORTE WHERE Reporte='AUTO-CIFRAS VENTAS DIFF';") -eq $control) 'Fallo de copia no marca control exitoso'
 # El bloqueo SQL impide ejecuciones simultaneas aun desde directorios distintos.
 $heldConnection=[Data.SqlClient.SqlConnection]::new("Data Source=$server;Initial Catalog=$db;Integrated Security=True;Encrypt=False;Pooling=False")
 try{
  $heldConnection.Open();$lockCommand=$heldConnection.CreateCommand()
  try{$lockCommand.CommandText="EXEC sys.sp_getapplock @Resource=N'ExtractSaleInfo',@LockMode='Exclusive',@LockOwner='Session';";[void]$lockCommand.ExecuteNonQuery()}
  finally{$lockCommand.Dispose()}
  $null=Run 'PBI' @() $false
  Assert ((Sql 'SELECT Llamadas FROM EAI.TestPreparacion;') -eq $calls) 'Concurrencia detenida antes de preparacion'
 }finally{$heldConnection.Dispose()}
 # Verificar tambien el entrypoint BAT y la preservacion de configuracion externa.
 & (Join-Path $root 'Extract_Diff_Sale.bat') -NoPublicar -DirectorioTrabajo (Join-Path $work 'bat') -DirectorioHistorico (Join-Path $work 'Processed')
 Assert ($LASTEXITCODE -eq 0) 'Entrada BAT'
 Write-Output 'OK fallo de copia recuperable, exclusion de concurrencia y entrada BAT.'
 Write-Output "QA completada. Evidencia: $work"
}finally{
 if($created){Sql "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];" 'master'}
}
