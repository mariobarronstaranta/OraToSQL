param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference = 'Stop'
$path = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'PROC_V40_GENERAR_MX06AD_CORREGIDO.sql'
$source = [IO.File]::ReadAllText($path, [Text.Encoding]::Unicode)
$detail = [regex]::Match($source, '(?s)DECLARE ScrDetalle CURSOR.*?OPEN ScrDetalle;').Value
$projection = @()
foreach ($alias in @('cantidad','valorUnitario','importe','Descuento','RFD_Tasa_IVA','PDF_TASA_IVA')) {
    $match = [regex]::Match($detail, '(?m)^\s*(.+) AS '+$alias+'\s*,')
    if (-not $match.Success) { throw "No se encontro $alias" }
    $projection += $match.Groups[1].Value + ' AS ' + $alias
}
function Get-Guard([string]$condition) {
    $match = [regex]::Match($source, '(?s)IF \(' + [regex]::Escape($condition) + '\)\s*BEGIN\s*SET @sMsg.*?END;')
    if (-not $match.Success) { throw "No se encontro validacion: $condition" }
    return $match.Value
}
$detailGuard = Get-Guard '@Item_RFD_Tasa_IVA IS NULL OR @Item_valorUnitario IS NULL'
$pendingGuard = Get-Guard 'ABS(@nTtl_CreditMemo - @nTtl_Assigned) > 999999999999.99'
$adjustmentGuard = Get-Guard '@nAjusteIVA_DistFee IS NULL OR ABS(@nAjusteIVA_DistFee) > 999.99'
$declarations = foreach ($name in @('nTtl_CreditMemo','nTtl_Assigned','nTotalAmt','nLineas')) {
    [regex]::Match($source, 'DECLARE @'+$name+'\s+NUMERIC\(\d+,\d+\);').Value
}
$sql = @'
SET NOCOUNT ON;
SET ANSI_WARNINGS ON;
DECLARE @pFactura varchar(30)='PRUEBA', @sMsg varchar(500), @Item_numLinea numeric(4,0)=1;
/*DECLARATIONS*/
SET @nTtl_Assigned = 99999999999999.99;
SET @nTtl_Assigned = @nTtl_Assigned + 99999999999999.99;
IF @nTtl_Assigned <> 199999999999999.98 THROW 52000, 'Se redujo la capacidad del acumulador de cobranza.',1;
SET @nTotalAmt = 99999999999999.99;
IF @nTotalAmt <> 99999999999999.99 THROW 52000, 'Total de articulo truncado.',1;
SET @nLineas = 9999;
SET @nLineas = @nLineas + 1;
IF @nLineas <> 10000 THROW 52000, 'Capacidad insuficiente del contador de lineas.',1;
DECLARE @RF TABLE (id int, Tipo_Venta varchar(2));
DECLARE @RFD TABLE (id int, Cantidad_Vta decimal(10,0), Precio_Unit decimal(15,2), Valor_Subt decimal(15,2), Valor_IVA decimal(15,2), Bonif_Subt decimal(15,2));
INSERT @RF VALUES (1,'VD'),(2,'XX'),(3,'VD'),(4,'VD'),(5,'VD'),(6,'VD');
INSERT @RFD VALUES
 (1,2,1000000000.00,2000000000.00,320000000.00,0),
 (2,9999999999,0.01,99999999.99,16000000,0),
 (3,2,-1000000000,-2000000000,-320000000,0),
 (4,0,1,10,1.6,0),
 (5,1,1,0,0,0),
 (6,2,1,2.01,0.32,0);
SELECT RF.id, /*PROJECTION*/ INTO #actual FROM @RF RF JOIN @RFD RFD ON RF.id=RFD.id;
IF NOT EXISTS(SELECT 1 FROM #actual WHERE id=1 AND valorUnitario=1000000000.00 AND importe=2000000000.00 AND RFD_Tasa_IVA=16) THROW 52000,'Fallo importe mayor al limite STR(12,2).',1;
IF NOT EXISTS(SELECT 1 FROM #actual WHERE id=2 AND cantidad=9999999999 AND importe=99999999.99) THROW 52000,'Fallo cantidad de diez digitos.',1;
IF NOT EXISTS(SELECT 1 FROM #actual WHERE id=3 AND valorUnitario=-1000000000.00 AND importe=-2000000000.00) THROW 52000,'Fallo importe negativo.',1;
IF NOT EXISTS(SELECT 1 FROM #actual WHERE id=6 AND valorUnitario=1.01 AND PDF_TASA_IVA=16) THROW 52000,'Cambio de redondeo heredado.',1;
DECLARE @Item_RFD_Tasa_IVA numeric(22,2), @Item_valorUnitario numeric(22,2), @id int=4, @caught bit;
WHILE @id<=5
BEGIN
 SELECT @Item_RFD_Tasa_IVA=RFD_Tasa_IVA, @Item_valorUnitario=valorUnitario FROM #actual WHERE id=@id;
 SET @caught=0;
 BEGIN TRY
  /*DETAIL_GUARD*/
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>51001 THROW;
  SET @caught=1;
 END CATCH;
 IF @caught=0 THROW 52000,'Division invalida no rechazada.',1;
 SET @id+=1;
END;
DECLARE @cases TABLE (id int, value decimal(22,2), bad bit);
INSERT @cases VALUES (1,999999999999.99,0),(2,-999999999999.99,0),(3,1000000000000,1),(4,-1000000000000,1);
SET @id=1;
WHILE @id<=4
BEGIN
 DECLARE @bad bit;
 SELECT @nTtl_CreditMemo=value,@bad=bad FROM @cases WHERE id=@id;
 SET @nTtl_Assigned=0;
 SET @caught=0;
 BEGIN TRY
  /*PENDING_GUARD*/
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>51002 THROW;
  SET @caught=1;
 END CATCH;
 IF @caught<>@bad THROW 52000,'Validacion incorrecta del rango PENDIENTE.',1;
 SET @id+=1;
END;
DELETE @cases;
INSERT @cases VALUES (1,999.99,0),(2,-999.99,0),(3,1000,1),(4,-1000,1),(5,NULL,1),(6,0,0);
DECLARE @nAjusteIVA_DistFee numeric(22,2);
SET @id=1;
WHILE @id<=6
BEGIN
 SELECT @nAjusteIVA_DistFee=value,@bad=bad FROM @cases WHERE id=@id;
 SET @caught=0;
 BEGIN TRY
  /*ADJUSTMENT_GUARD*/
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>51003 THROW;
  SET @caught=1;
 END CATCH;
 IF @caught<>@bad THROW 52000,'Validacion incorrecta del rango AJUSTE.',1;
 SET @id+=1;
END;
PRINT 'OK: expresiones reales, importes grandes/negativos, cantidad de 10 digitos, redondeo, division cero y limites de destinos.';
'@
$sql = $sql.Replace('/*PROJECTION*/', ($projection -join ', ')).Replace('/*DECLARATIONS*/', ($declarations -join "`r`n")).Replace('/*DETAIL_GUARD*/',$detailGuard).Replace('/*PENDING_GUARD*/',$pendingGuard).Replace('/*ADJUSTMENT_GUARD*/',$adjustmentGuard)
$sql += "`r`nDECLARE @Reg_NumLin numeric(6,0)=1;`r`n"
foreach ($variable in @('@Item_Subt_sin_IEPS','@Item_PDF_Valor_Subt','@Doc_Valor_Subt_IEPS','@Item_cantidad','@Reg_Cantidad_Vta','@CMA_Paid_Amt')) {
    $condition = "$variable IS NULL OR $variable = 0"
    if ($variable -eq '@CMA_Paid_Amt') { $condition = "$variable IS NULL" }
    $guard = Get-Guard $condition
    $sql += "`r`nDECLARE $variable numeric(22,2);`r`n"
    foreach ($value in @('NULL','0','1')) {
        $expected = if ($value -eq 'NULL' -or ($value -eq '0' -and $variable -ne '@CMA_Paid_Amt')) { 1 } else { 0 }
        $sql += @"
SET $variable = $value;
SET @caught=0;
BEGIN TRY
 $guard
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51001 THROW;
 SET @caught=1;
END CATCH;
IF @caught<>$expected THROW 52000, 'Validacion incorrecta: $variable = $value',1;

"@
    }
}
$sql += "`r`nPRINT 'OK: bases IVA/IEPS, cantidades de addenda e importes de cobranza (NULL, cero y valor valido).';`r`n"
$tempPath = Join-Path ([IO.Path]::GetTempPath()) ('mx06ad_numbers_' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    [IO.File]::WriteAllText($tempPath,$sql,[Text.Encoding]::Unicode)
    & sqlcmd -S $Server -E -No -b -i $tempPath
    if ($LASTEXITCODE -ne 0) { throw 'Fallo de pruebas numericas.' }
} finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath }
}
