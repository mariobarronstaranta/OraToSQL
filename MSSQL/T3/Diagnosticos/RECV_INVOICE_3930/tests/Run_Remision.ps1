$ErrorActionPreference = 'Stop'
$server = '(localdb)\MSSQLLocalDB'
$db = 'CodexRemision2628_' + [guid]::NewGuid().ToString('N').Substring(0,10)
$patchRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$created = $false
function Sql([string]$Text) {
    $output = $Text | & sqlcmd -S $server -E -No -I -b -d $db 2>&1
    if ($LASTEXITCODE -ne 0) { $output | Write-Output; throw 'Fallo prueba remision 2628.' }
    $output | Where-Object { $_ -match 'PASS|Resultado|Columnas corregidas|ya presente' } | Write-Output
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db] COLLATE Latin1_General_100_CI_AS_KS_WS_SC"
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base temporal.' }
    $created = $true
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))
    $ddl = [IO.File]::ReadAllText((Join-Path $repoRoot 'MSSQL/T3/T3/Tables/T3.REMISION_GENERAL.Table.sql'))
    $ddl = [regex]::Replace($ddl, '(?im)^USE \[T3QA\]\s*\r?$', '')
    Sql $ddl
    $source = [IO.File]::ReadAllText((Join-Path $repoRoot 'MSSQL/T3/T3/Procedures/T3.DELIVERY_WA_OXXO.StoredProcedure.sql'))
    $m = [regex]::Match($source,'(?is)INSERT INTO T3\.Remision_General.*?VALUES\s*\(.*?\);')
    if (-not $m.Success) { throw 'No se encontro INSERT real.' }
    $oldInsert = [regex]::Replace($m.Value,'(?is)INSERT INTO T3\.Remision_General.*?VALUES','INSERT INTO T3.Remision_General VALUES')
    foreach ($name in @('EAI_OWNER.INVOICE_TO_PREVENTA','EAI_OWNER.INVOICE_TO_FACTURA','EAI_OWNER.INVOICE_TO_ENTREGA_PO')) {
        Sql "CREATE PROCEDURE $name AS BEGIN BEGIN TRY SELECT 1; END TRY BEGIN CATCH THROW; END CATCH; END;"
    }
    Sql @"
CREATE PROCEDURE T3.DELIVERY_WA_OXXO AS
BEGIN
 DECLARE @Delivery varchar(50)='ENT123',@PedidoSAP varchar(50)='PED123',
 @DeliveryType varchar(20)='C005',@Sociedad varchar(4)='MX06',@Fecha_Factura datetime='20261022',
 @envID varchar(20)='MXAA',@envNombre varchar(100)='ORIGEN NOMBRE',
 @envDireccion varchar(100)='ORIGEN DIR',@envColonia varchar(80)='COLONIA ORIGEN',
 @envMunicipio varchar(80)='CIUDAD ORIGEN',@envEstado varchar(80)='ESTADO ORIGEN',
 @envPais varchar(30)='MX',@envCodigo varchar(10)='02000',
 @sShiptoParty varchar(100)='SAP123',@RFC varchar(50)='CCO8605231N4',
 @recID varchar(20)='DESTINO01',@recNombre varchar(100)='DESTINO NOMBRE',
 @recDireccion varchar(100)='DESTINO DIR',@recColonia varchar(80)='COLONIA DEST',
 @recMunicipio varchar(80)='CIUDAD DEST',@recEstado varchar(80)='EDODEST',
 @recPais varchar(30)='MX',@recCodigo varchar(10)='01000',
 @Observaciones varchar(500)='VPGG31G10930163 / Observacion completa',
 @sRem_Serie varchar(20)='MX06',@sRem_Folio varchar(20)='1234567890';
 BEGIN TRY
 $oldInsert
 END TRY
 BEGIN CATCH
  THROW;
 END CATCH;
END;
"@
    $baseline = @'
DECLARE @Err int=0,@Msg nvarchar(4000);
BEGIN TRY EXEC T3.DELIVERY_WA_OXXO; END TRY
BEGIN CATCH SELECT @Err=ERROR_NUMBER(),@Msg=ERROR_MESSAGE(); END CATCH;
IF @Err<>2628 OR @Msg NOT LIKE '%REMISION_FOLIO%'
BEGIN
 PRINT CONCAT('Error observado: ',@Err,'; ',@Msg);
 THROW 51920,'No se reprodujo truncamiento de REMISION_FOLIO con INSERT posicional',1;
END;
PRINT 'PASS reproduccion 2628: observaciones entraba en REMISION_FOLIO';
'@
    Sql $baseline
    $patch1 = [IO.File]::ReadAllText((Join-Path $patchRoot '01_CORREGIR_CATCH.sql')).Replace("@BaseEsperada sysname=N'T3QA'","@BaseEsperada sysname=N'$db'")
    Sql $patch1
    $patch4 = [IO.File]::ReadAllText((Join-Path $patchRoot '04_CORREGIR_COLUMNAS_REMISION.sql')).Replace("@BaseEsperada sysname=N'T3QA'","@BaseEsperada sysname=N'$db'")
    Sql ($patch4.Replace('@Aplicar bit=1','@Aplicar bit=0'))
    Sql $baseline
    Sql $patch4
    Sql @'
EXEC T3.DELIVERY_WA_OXXO;
IF (SELECT COUNT(*) FROM T3.REMISION_GENERAL)<>1
 THROW 51921,'No se inserto la remision',1;
IF NOT EXISTS(SELECT 1 FROM T3.REMISION_GENERAL
 WHERE FACTURA='ENT123' AND PEDIDOSAP='PED123' AND CLASE_REMISION='C005' AND SOCIEDAD='MX06'
 AND ORIGEN='MXAA' AND NOMBRE='ORIGEN NOMBRE' AND DIRECCION='ORIGEN DIR'
 AND COLONIA='COLONIA ORIGEN' AND CIUDAD='CIUDAD ORIGEN' AND ESTADO='ESTADO ORIGEN'
 AND PAIS='MX' AND CODIGOPOSTAL='02000' AND SHIPTOPARTY='SAP123' AND RFC='CCO8605231N4'
 AND DESTINO='DESTINO01' AND DESTINO_NOMBRE='DESTINO NOMBRE' AND DESTINO_DIRECCION='DESTINO DIR'
 AND DESTINO_COLONIA='COLONIA DEST' AND DESTINO_CIUDAD='CIUDAD DEST'
 AND DESTINO_ESTADO='EDODEST' AND DESTINO_PAIS='MX' AND DESTINO_CODIGOPOSTAL='01000'
 AND OBSERVACIONES='VPGG31G10930163 / Observacion completa'
 AND REMISION_SERIE='MX06' AND REMISION_FOLIO='1234567890')
 THROW 51922,'Campos truncados o desalineados despues del parche',1;
IF COL_LENGTH('T3.REMISION_GENERAL','REMISION_FOLIO')<>15
 THROW 51923,'Se altero longitud de la tabla',1;
PRINT 'PASS insercion con campos correctos, observaciones completas y tabla sin ampliar';
'@
    Sql $patch4
    Sql "IF (SELECT COUNT(*) FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP)<>5 THROW 51924,'Respaldo duplicado',1; PRINT 'PASS idempotencia parche 04';"
    $rollback = [IO.File]::ReadAllText((Join-Path $patchRoot '03_REVERTIR_SOLO_SI_ES_NECESARIO.sql'))
    $rollback = $rollback.Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
    $rollback = $rollback.Replace('DECLARE @RunId uniqueidentifier=NULL;','DECLARE @RunId uniqueidentifier=(SELECT RunId FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP GROUP BY RunId HAVING COUNT(*)=1);')
    Sql $rollback
    Sql "DELETE T3.REMISION_GENERAL;"
    Sql $baseline
    Sql "IF CHARINDEX('RI3930_PROPAGATE_V1',OBJECT_DEFINITION(OBJECT_ID('T3.DELIVERY_WA_OXXO')))=0 THROW 51925,'Se perdio correccion 3930 al revertir 2628',1; PRINT 'PASS reversion de 2628 conserva parche 3930';"
    Write-Output 'PASS pruebas de columnas de remision completadas'
} finally {
    if ($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
