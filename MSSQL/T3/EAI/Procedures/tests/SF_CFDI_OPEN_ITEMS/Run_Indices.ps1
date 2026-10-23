param([string]$Server='(localdb)\MSSQLLocalDB')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$db='CodexOIIndexes_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$created=$false
function Sql([string]$Text) {
    $Text | & sqlcmd -S $Server -E -No -b -d $db
    if($LASTEXITCODE -ne 0){throw 'Fallo de validacion local de indices.'}
}
try {
    & sqlcmd -S $Server -E -No -b -Q "CREATE DATABASE [$db] COLLATE SQL_Latin1_General_CP1_CI_AS"
    if($LASTEXITCODE -ne 0){throw 'No se creo base desechable.'}
    $created=$true
    Sql 'CREATE SCHEMA T3;'
    foreach($file in @('T3.FACTURA_GENERAL.SQL','T3.FACTURA_DETALLE.Table.sql')) {
        $s=Get-Content -Raw (Join-Path $root "T3/Tables/$file")
        $m=[regex]::Match($s,'(?ims)^CREATE TABLE \[T3\].*?^GO\s*$')
        if(-not $m.Success){throw 'No se encontro DDL de tabla.'}
        Sql $m.Value
    }
    $s=Get-Content -Raw (Join-Path $root 'EAI/Procedures/SF_CFDI_OPEN_ITEMS_INDICES_SELECCIONADOS.SQL')
    # Reproducir las dos collations reportadas sin depender del catalogo del host.
    $s=$s.Replace('Columna sysname,','Columna sysname COLLATE Latin1_General_100_CI_AS_KS_WS_SC,')
    $legacy=$s.Replace('C.name COLLATE DATABASE_DEFAULT = R.Columna COLLATE DATABASE_DEFAULT','C.name=R.Columna')
    $quoted=$legacy.Replace("'","''")
    Sql ("DECLARE @Error int=0; BEGIN TRY EXEC sys.sp_executesql N'"+$quoted+"'; END TRY BEGIN CATCH SET @Error=ERROR_NUMBER(); IF @Error<>468 THROW; END CATCH; IF @Error<>468 THROW 51013,'No reprodujo conflicto 468.',1; PRINT 'PASS: error 468 reproducido con comparacion anterior.';")
    Sql $s
    Sql "IF EXISTS(SELECT 1 FROM sys.indexes WHERE name LIKE 'IX_OI_%') THROW 51010,'Vista previa creo indices.',1;"
    Sql ($s.Replace('DECLARE @Aplicar bit = 0;','DECLARE @Aplicar bit = 1;'))
    Sql "IF (SELECT COUNT(*) FROM sys.indexes WHERE name IN ('IX_OI_FG_TipoFecha','IX_OI_FD_Factura'))<>2 THROW 51011,'No creo ambos indices.',1;"
    Sql "EXEC sys.sp_rename N'T3.Factura_Detalle.IX_OI_FD_Factura',N'TestCoberturaAlternativa',N'INDEX';"
    Sql ($s.Replace('DECLARE @Aplicar bit = 0;','DECLARE @Aplicar bit = 1;'))
    Sql "IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id IN (OBJECT_ID('T3.Factura_General'),OBJECT_ID('T3.Factura_Detalle')) AND index_id>0)<>2 THROW 51012,'Duplico indice de cobertura con otro nombre.',1;"
    Write-Output 'PASS: vista previa, creacion sobre DDL real y omision de cobertura existente con otro nombre.'
} finally {
    if($created){
        & sqlcmd -S $Server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
