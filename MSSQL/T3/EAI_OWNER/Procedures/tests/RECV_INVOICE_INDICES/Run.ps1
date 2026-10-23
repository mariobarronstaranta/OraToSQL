$ErrorActionPreference='Stop'
$server='(localdb)\MSSQLLocalDB'
$db='CodexInvoiceIndexes_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$owner=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$script=[IO.File]::ReadAllText((Join-Path $owner 'Package/RECV_INVOICE_INDICES.SQL'))
$created=$false
function Sql([string]$Text,[bool]$ExpectedFailure=$false) {
    $out=$Text | & sqlcmd -S $server -E -No -I -b -d $db 2>&1
    if($ExpectedFailure){
        if($LASTEXITCODE -eq 0 -or ($out -join "`n") -notmatch '51903'){throw 'No se rechazo la propuesta pendiente de revision'}
    } elseif($LASTEXITCODE -ne 0){$out | Write-Output; throw 'Fallo la prueba de indices'}
}
function Apply([string]$Solo='NULL') {
    return $script.Replace('DECLARE @Aplicar bit = 0;','DECLARE @Aplicar bit = 1;').Replace('DECLARE @SoloId int = NULL;',"DECLARE @SoloId int = $Solo;")
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db]"
    if($LASTEXITCODE -ne 0){throw 'No se creo base temporal'}
    $created=$true
    Sql "CREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
    $ddl=[IO.File]::ReadAllText((Join-Path $owner 'Tables/Tablas_EAI_OWNER.sql'))
    foreach($table in @('TMP_DOCUMENT_HEADER','TMP_DOCUMENT_DETAIL','TMP_DOCUMENT_CONDITIONS')){
        $m=[regex]::Match($ddl,'(?ims)^CREATE TABLE \[EAI_OWNER\]\.\['+$table+'\].*?^GO\s*$')
        if(-not $m.Success){throw "No se encontro $table"}
        Sql $m.Value
    }
    foreach($table in @('PREVENTA_GENERAL','PREVENTA_DETALLE','FACTURA_GENERAL','FACTURA_DETALLE','RF_COMPLEMENTO','REMISION_GENERAL','MATERIAL')){
        $file=if($table -eq 'FACTURA_GENERAL'){'T3.FACTURA_GENERAL.SQL'}else{"T3.$table.Table.sql"}
        $ddl=[IO.File]::ReadAllText((Join-Path $owner "../T3/Tables/$file"))
        $m=[regex]::Match($ddl,'(?ims)^CREATE TABLE \[T3\]\.\['+$table+'\].*?^GO\s*$')
        if(-not $m.Success){throw "No se encontro $table"}
        Sql $m.Value
    }
    Sql @'
CREATE INDEX ExistingHeader ON EAI_OWNER.TMP_DOCUMENT_HEADER (REFERENCEID DESC);
CREATE INDEX ExistingDetail ON EAI_OWNER.TMP_DOCUMENT_DETAIL (REFERENCEID,ITEMID);
CREATE INDEX ExistingFactura ON T3.FACTURA_DETALLE (FACTURA) INCLUDE (VALOR_SUBT);
CREATE INDEX ExistingMaterial ON T3.MATERIAL (MATERIAL);
CREATE INDEX SecondKey ON T3.PREVENTA_GENERAL (FECHA_FACTURA,FACTURA);
CREATE INDEX FilteredRemision ON T3.REMISION_GENERAL (FACTURA) WHERE FACTURA IS NOT NULL;
'@
    Sql $script
    Sql "IF EXISTS(SELECT 1 FROM sys.indexes WHERE name LIKE 'IX_RI_%') THROW 51000,'El modo revision creo indices',1;"
    Write-Output 'PASS: modo revision sin DDL'
    Sql (Apply) $true
    Sql "IF EXISTS(SELECT 1 FROM sys.indexes WHERE name LIKE 'IX_RI_%') THROW 51000,'La prevalidacion permitio DDL parcial',1;"
    Write-Output 'PASS: indice filtrado requiere revision antes de crear'
    Sql (Apply '3')
    Sql (Apply '3')
    Sql "IF (SELECT COUNT(*) FROM sys.indexes WHERE name='IX_RI_TMP_CONDITIONS_REF')<>1 THROW 51000,'Aplicacion selectiva no idempotente',1;"
    Write-Output 'PASS: aplicacion individual e idempotencia'
    Sql @'
DROP INDEX FilteredRemision ON T3.REMISION_GENERAL;
ALTER TABLE T3.RF_COMPLEMENTO ADD FixtureOther int NULL;
CREATE INDEX IX_RI_RF_COMPLEMENTO_FACTURA ON T3.RF_COMPLEMENTO(FixtureOther);
'@
    Sql (Apply) $true
    Write-Output 'PASS: nombre ocupado con otra clave rechazado'
    Sql 'DROP INDEX IX_RI_RF_COMPLEMENTO_FACTURA ON T3.RF_COMPLEMENTO;'
    Sql (Apply)
    Sql (Apply)
    Sql @'
IF (SELECT COUNT(*) FROM sys.indexes WHERE name LIKE 'IX_RI_%')<>6
 THROW 51000,'No se crearon exactamente seis accesos faltantes',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE name IN ('IX_RI_TMP_HEADER_REF','IX_RI_TMP_DETAIL_REF','IX_RI_FACTURA_DETALLE_FACTURA','IX_RI_MATERIAL'))
 THROW 51000,'Se duplico un acceso existente con otro nombre',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_RI_PREVENTA_GENERAL_FACTURA')
 THROW 51000,'Se acepto indebidamente la clave en segunda posicion',1;
'@
    Write-Output 'PASS: reutilizacion por clave inicial y creacion exacta de faltantes'
    # Probar INCLUDE real de MATERIAL cuando no existe acceso previo.
    Sql 'DROP INDEX ExistingMaterial ON T3.MATERIAL;'
    Sql (Apply '10')
    Sql @'
IF (SELECT COUNT(*) FROM sys.index_columns IC JOIN sys.indexes I
 ON I.object_id=IC.object_id AND I.index_id=IC.index_id
 WHERE I.object_id=OBJECT_ID('T3.MATERIAL') AND I.name='IX_RI_MATERIAL' AND IC.is_included_column=1)<>6
 THROW 51000,'Cobertura de MATERIAL incorrecta',1;
ALTER INDEX IX_RI_MATERIAL ON T3.MATERIAL DISABLE;
'@
    Sql (Apply '10') $true
    Write-Output 'PASS: cobertura de MATERIAL y rechazo de nombre deshabilitado'
} finally {
    if($created){& sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"}
}
