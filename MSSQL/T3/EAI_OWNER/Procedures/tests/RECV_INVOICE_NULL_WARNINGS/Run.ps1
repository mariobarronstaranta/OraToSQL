$ErrorActionPreference='Stop'
$owner=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$server='(localdb)\MSSQLLocalDB'
$db='CodexInvoiceNull_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$created=$false
function Sql([string]$Text) {
    $out=$Text | & sqlcmd -S $server -E -No -I -b -d $db 2>&1
    $code=$LASTEXITCODE
    $out | Write-Output
    if($code -ne 0 -or ($out -join "`n") -match 'Null value is eliminated|8153') { throw 'Fallo SQL o aviso de NULL.' }
}
function MatchText([string]$Source,[string]$Pattern) {
    $m=[regex]::Match($Source,$Pattern)
    if(-not $m.Success){throw "No se encontro el bloque: $Pattern"}
    return $m.Groups[1].Value
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db]"
    if($LASTEXITCODE -ne 0){throw 'No se creo base temporal'}
    $created=$true
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))
    $pre=[IO.File]::ReadAllText((Join-Path $owner 'Procedures/INVOICE_TO_PREVENTA.SQL'))
    $fac=[IO.File]::ReadAllText((Join-Path $owner 'Procedures/INVOICE_TO_FACTURA.SQL'))
    $ox=[IO.File]::ReadAllText((Join-Path $owner '../T3/Procedures/T3.DELIVERY_WA_OXXO.StoredProcedure.sql'))
    # Ejecutar las consultas extraidas del codigo real, no copias del nuevo calculo.
    $queries=@(
        (MatchText $pre '(?s);WITH DetailData AS\s*\((.*?)\),\s*BaseCalc AS'),
        (MatchText $pre '(?s)DECLARE ScrDetalle CURSOR LOCAL FAST_FORWARD FOR\s*(.*?GROUP BY Factura, Prefijo, Num_Linea, Material, Unidad_Med_Vta, Status_Prod);'),
        (MatchText $fac '(?s);WITH DetailBase AS\s*\((.*?)\),\s*DetailMapped AS'),
        (MatchText $ox '(?s)(SELECT\s+PG\.Entrega\s+AS Factura,\s*\(SELECT MAX\(PN\..*?HAVING SUM\(ISNULL\(PD\.Envio_Subt,0\)\) > 0);')
    )
    # Reconstruir la expresion anterior unicamente para comparar resultados.
    $pairs=@(
        @("CASE WHEN MAX(CASE WHEN Head.DeliveryType = 'C019' OR Det.Cantidad IS NOT NULL THEN 1 ELSE 0 END) = 1 THEN SUM(CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE ISNULL(Det.Cantidad, 0) END) END", "SUM(CASE WHEN Head.DeliveryType = 'C019' THEN 1 ELSE Det.Cantidad END)"),
        @('CASE WHEN MAX(CASE WHEN Cantidad_Vta IS NOT NULL THEN 1 ELSE 0 END) = 1 THEN SUM(ISNULL(Cantidad_Vta, 0)) END','SUM(Cantidad_Vta)'),
        @("CASE WHEN MAX(CASE WHEN @Clase_Factura = 'C019' OR Det.Cantidad IS NOT NULL THEN 1 ELSE 0 END) = 1 THEN SUM(CASE WHEN @Clase_Factura = 'C019' THEN 1 ELSE ISNULL(Det.Cantidad, 0) END) END", "SUM(CASE WHEN @Clase_Factura = 'C019' THEN 1 ELSE Det.Cantidad END)"),
        @('(SELECT MAX(MU.Unidad_Med_Vta) FROM T3.Material AS MU WHERE MU.Material = CONVERT(VARCHAR(18), CONVERT(NUMERIC(38,0), TRIM(Det.Material))) AND MU.Unidad_Med_Vta IS NOT NULL)','MAX(Mat.Unidad_Med_Vta)'),
        @('(SELECT MAX(MP.Cig_x_CLL) FROM T3.Material AS MP WHERE MP.Material = CONVERT(VARCHAR(18), CONVERT(NUMERIC(38,0), TRIM(Det.Material))) AND MP.Cig_x_CLL IS NOT NULL)','MAX(Mat.Cig_x_CLL)'),
        @('(SELECT MAX(PN.Num_Linea + 10) FROM T3.Preventa_Detalle AS PN WHERE PN.Factura = PG.Factura AND PN.Num_Linea IS NOT NULL)','MAX(PD.Num_Linea + 10)')
    )
    $index=0
    foreach($q in $queries){
        $old=$q
        foreach($pair in $pairs){$old=$old.Replace($pair[0],$pair[1])}
        if($old -eq $q){throw 'No se reconstruyo expresion anterior'}
        # El cursor no nombra sus agregados; CTE con nombres explicitos.
        $cols=if($index -eq 1){'(Factura,Prefijo,Num_Linea,Material,Unidad_Med_Vta,Status_Prod,Tasa_IEPS,Cantidad_Vta,Valor_Subt,Valor_IVA,Valor_ISSA,Bonif_Subt,Bonif_Vol,Envio_Subt)'}else{''}
        foreach($mode in @('C030','C019','EMPTY','ALLNULL')){
            $setup=if($mode -eq 'ALLNULL'){'UPDATE T3.Preventa_Detalle SET Num_Linea=NULL;'}else{'UPDATE T3.Preventa_Detalle SET Num_Linea=CASE WHEN Envio_Subt=1 THEN NULL WHEN Envio_Subt=2 THEN -30 ELSE -20 END;'}
            $id=if($mode -eq 'EMPTY'){'MISSING'}else{'TEST'}
            Sql @"
SET NOCOUNT ON;
DECLARE @sInvoiceID varchar(30)='$id', @pInvoice varchar(30)='$id', @Clase_Factura varchar(10)='$mode';
UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET DeliveryType='$mode';
$setup
SET ANSI_WARNINGS OFF;
;WITH R$cols AS ($old) SELECT * INTO #Expected FROM R;
SET ANSI_WARNINGS ON;
;WITH R$cols AS ($q) SELECT * INTO #Actual FROM R;
IF EXISTS(SELECT * FROM #Expected EXCEPT SELECT * FROM #Actual) OR EXISTS(SELECT * FROM #Actual EXCEPT SELECT * FROM #Expected)
    THROW 51000,'Cambio de resultados en agregacion',1;
PRINT 'PASS: consulta $index / $mode sin avisos y con resultados equivalentes';
"@
        }
        $index++
    }
    foreach($source in @($pre,$fac,$ox)){
        # Los scripts T3 incluyen USE de despliegue: solo se analiza el modulo.
        $start=[regex]::Match($source,'(?im)^(?:CREATE OR ALTER|CREATE|ALTER)\s+PROCEDURE\b')
        if(-not $start.Success){throw 'No se encontro declaracion de procedimiento'}
        Sql ("SET PARSEONLY ON;`nGO`n"+$source.Substring($start.Index))
    }
} finally {
    if($created){& sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"}
}
