$ErrorActionPreference = 'Stop'
$server = '(localdb)\MSSQLLocalDB'
$db = 'CodexDetail8114_' + [guid]::NewGuid().ToString('N').Substring(0,10)
$patchRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$created = $false
function Sql([string]$Text) {
    $output = $Text | & sqlcmd -S $server -E -No -I -b -d $db 2>&1
    if ($LASTEXITCODE -ne 0) { $output | Write-Output; throw 'Fallo prueba DetailBase 8114.' }
    $output | Where-Object { $_ -match 'PASS|Resultado|ya presente' } | Write-Output
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db] COLLATE Latin1_General_100_CI_AS_KS_WS_SC"
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base temporal.' }
    $created = $true
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))
    $ddl = [IO.File]::ReadAllText((Join-Path $repoRoot 'MSSQL/T3/T3/Tables/T3.FACTURA_DETALLE.Table.sql'))
    Sql ([regex]::Replace($ddl, '(?im)^USE \[T3QA\]\s*\r?$', ''))
    Sql @'
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_HEADER(ReferenceID varchar(30),Procesado datetime);
CREATE TABLE EAI_OWNER.TMP_DOCUMENT_DETAIL
(ReferenceID varchar(30),ItemID int,Material varchar(60),UnidadMedida varchar(3),
 Status_Producto varchar(10),Cantidad numeric(22,7),Valor_Subt numeric(22,7),
 Valor_IVA numeric(22,7),Bonif_Subt numeric(22,7),Envio_Subt numeric(22,7),Credito_Subt numeric(22,7));
CREATE TABLE EAI_OWNER.MX_HashTable(Type varchar(30),Source varchar(30),Target varchar(30));
CREATE TABLE T3.Material(Material varchar(18),Unidad_Med_Vta varchar(3),Cig_x_CLL numeric(22,7));
INSERT EAI_OWNER.TMP_DOCUMENT_HEADER(ReferenceID) VALUES('VALID'),('BAD'),('MIX'),('NULL'),('BLANK'),('OVERFLOW');
INSERT EAI_OWNER.TMP_DOCUMENT_DETAIL VALUES
('VALID',1,' 000123 ','UA','',2,10000,1600,0,0,0),
('BAD',1,'R044','UA','',1,10000,1600,0,0,0),
('MIX',1,'123','UA','',2,10000,1600,0,0,0),
('MIX',2,'R044','UA','',1,10000,1600,0,0,0),
('NULL',1,NULL,'UA','',1,10000,1600,0,0,0),
('BLANK',1,'','UA','',1,10000,1600,0,0,0),
('OVERFLOW',1,REPLICATE('9',39),'UA','',1,10000,1600,0,0,0);
GO
'@
    $source = [IO.File]::ReadAllText((Join-Path $repoRoot 'MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_FACTURA.SQL'))
    $start = $source.IndexOf(';WITH DetailBase AS')
    $end = $source.IndexOf('FROM DetailFinal AS D;', $start) + 'FROM DetailFinal AS D;'.Length
    if ($start -lt 0 -or $end -lt $start) { throw 'No se encontro CTE real.' }
    $cte = $source.Substring($start,$end-$start)
    $old = [regex]::Replace($cte,'(?s)\s*-- RI8114_DETAILBASE_VACIO_V1.*?(?=\s+GROUP BY)','')
    $old = $old.Replace('TRY_CONVERT(NUMERIC(38,0), TRIM(Det.Material))','CONVERT(NUMERIC(38,0), TRIM(Det.Material))')
    # El CTE y el INSERT son reales; el resto del procedimiento se aísla.
    Sql @"
CREATE PROCEDURE EAI_OWNER.INVOICE_TO_FACTURA @sInvoiceID varchar(30) AS
BEGIN
 DECLARE @Clase_Factura varchar(4)='C003',@nFactorDiv numeric(22,7)=100,@sFacturaV3 varchar(30)=@sInvoiceID;
 BEGIN TRY
 $old
 UPDATE EAI_OWNER.TMP_DOCUMENT_HEADER SET Procesado=GETDATE() WHERE ReferenceID=@sInvoiceID;
 END TRY
 BEGIN CATCH THROW; END CATCH;
END;
"@
    foreach ($name in @('EAI_OWNER.INVOICE_TO_PREVENTA','EAI_OWNER.INVOICE_TO_ENTREGA_PO','T3.DELIVERY_WA_OXXO')) {
        Sql "CREATE PROCEDURE $name AS BEGIN BEGIN TRY SELECT 1; END TRY BEGIN CATCH THROW; END CATCH; END;"
    }
    $patch1 = [IO.File]::ReadAllText((Join-Path $patchRoot '01_CORREGIR_CATCH.sql')).Replace("@BaseEsperada sysname=N'T3QA'","@BaseEsperada sysname=N'$db'")
    Sql $patch1
    $baseline = @'
DECLARE @Err int=0;
BEGIN TRY EXEC EAI_OWNER.INVOICE_TO_FACTURA 'BAD'; END TRY
BEGIN CATCH SET @Err=ERROR_NUMBER(); END CATCH;
IF @Err<>8114 THROW 51950,'No se reprodujo 8114 original.',1;
PRINT 'PASS reproduccion original 8114';
'@
    Sql $baseline
    Sql @'
DECLARE @Err int=0;
BEGIN TRY EXEC EAI_OWNER.INVOICE_TO_FACTURA 'BLANK'; END TRY
BEGIN CATCH SET @Err=ERROR_NUMBER(); END CATCH;
IF @Err<>8114 THROW 51960,'Baseline de cadena vacia inesperado.',1;
PRINT 'PASS cadena vacia tambien fallaba con NUMERIC(38,0)';
'@
    Sql @'
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'VALID';
SELECT * INTO dbo.Expected FROM T3.FACTURA_DETALLE;
IF NOT EXISTS(SELECT 1 FROM dbo.Expected WHERE Material='123' AND Valor_Subt=100 AND Valor_IVA=16)
 THROW 51951,'Baseline numerico inesperado.',1;
TRUNCATE TABLE T3.FACTURA_DETALLE;
'@
    $patch8 = [IO.File]::ReadAllText((Join-Path $patchRoot '08_DETAILBASE_VACIO_MATERIAL_INVALIDO.sql')).Replace("@BaseEsperada sysname=N'T3QA'","@BaseEsperada sysname=N'$db'")
    Sql ($patch8.Replace('@Aplicar bit=1','@Aplicar bit=0'))
    Sql $baseline
    Sql $patch8
    Sql $patch8
    Sql @'
DECLARE @Before int=@@TRANCOUNT;
BEGIN TRANSACTION;
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'BAD';
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'MIX';
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'OVERFLOW';
IF EXISTS(SELECT 1 FROM T3.FACTURA_DETALLE) THROW 51952,'No se omitio todo el detalle invalido.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.TMP_DOCUMENT_HEADER WHERE ReferenceID IN ('BAD','MIX','OVERFLOW') AND Procesado IS NULL)
 THROW 51953,'No continuo despues del CTE vacio.',1;
IF (SELECT SUM(ISNULL(Valor_Subt,0)) FROM T3.FACTURA_DETALLE WHERE Factura='BAD') IS NOT NULL
 THROW 51954,'Cambio comportamiento de SUM vacio.',1;
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'VALID';
COMMIT;
IF @@TRANCOUNT<>@Before THROW 51955,'Cambio contrato de transacciones.',1;
IF EXISTS(SELECT * FROM dbo.Expected EXCEPT SELECT * FROM T3.FACTURA_DETALLE)
 OR EXISTS(SELECT * FROM T3.FACTURA_DETALLE EXCEPT SELECT * FROM dbo.Expected)
 THROW 51956,'Cambio detalle numerico valido.',1;
PRINT 'PASS R044, factura mixta y desbordamiento: cero filas y continuidad';
PRINT 'PASS siguiente factura valida identica al baseline, aislada de materiales ajenos';
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'NULL';
EXEC EAI_OWNER.INVOICE_TO_FACTURA 'BLANK';
IF NOT EXISTS(SELECT 1 FROM T3.FACTURA_DETALLE WHERE Factura='NULL' AND Material IS NULL)
 OR EXISTS(SELECT 1 FROM T3.FACTURA_DETALLE WHERE Factura='BLANK')
 THROW 51957,'NULL no conservado o cadena vacia no omitida.',1;
IF (SELECT COUNT(*) FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE Nombre='EAI_OWNER.INVOICE_TO_FACTURA' AND DefinicionOriginal LIKE '%RI3930_PROPAGATE_V1%')<>1
 THROW 51958,'Fallo idempotencia del parche.',1;
PRINT 'PASS NULL preservado, cadena vacia omitida; aplicacion idempotente';
'@
    $rollback = [IO.File]::ReadAllText((Join-Path $patchRoot '03_REVERTIR_SOLO_SI_ES_NECESARIO.sql')).Replace("DB_NAME()<>N'T3QA'","DB_NAME()<>N'$db'")
    $rollback = $rollback.Replace('DECLARE @RunId uniqueidentifier=NULL;',"DECLARE @RunId uniqueidentifier=(SELECT TOP(1) RunId FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE Nombre='EAI_OWNER.INVOICE_TO_FACTURA' AND DefinicionOriginal LIKE '%RI3930_PROPAGATE_V1%' ORDER BY FechaAplicacion DESC);")
    Sql $rollback
    Sql $baseline
    Sql "IF CHARINDEX('RI3930_PROPAGATE_V1',OBJECT_DEFINITION(OBJECT_ID('EAI_OWNER.INVOICE_TO_FACTURA')))=0 THROW 51959,'Reversion perdio guard anterior.',1; PRINT 'PASS reversion del parche 08 conserva parche 01';"
}
finally {
    if ($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]"
        if ($LASTEXITCODE -ne 0) { throw "No se elimino la base temporal $db" }
    }
}
