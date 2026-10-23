$ErrorActionPreference = 'Stop'
$server = '(localdb)\MSSQLLocalDB'
$db = 'CodexRecv3930_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$patchRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$created = $false
function Sql([string]$Text) {
    $output = $Text | & sqlcmd -S $server -E -No -I -b -d $db 2>&1
    if ($LASTEXITCODE -ne 0) { $output | Write-Output; throw 'Fallo prueba RECV_INVOICE 3930.' }
    $output | Where-Object { $_ -match 'PASS|RunId|Aplicado|revertid|Ya corregido' } | Write-Output
}
try {
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db] COLLATE Latin1_General_100_CI_AS_KS_WS_SC"
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base temporal.' }
    $created = $true
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Fixture.sql'))

    # Se usan los CATCH reales de los cuatro fuentes, retirando solo el guard
    # nuevo para reproducir el comportamiento anterior. El TRY es una inyeccion
    # controlada; no se pretende simular el procesamiento XML completo.
    $modules = @{
        'EAI_OWNER.INVOICE_TO_PREVENTA' = 'MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA.SQL'
        'EAI_OWNER.INVOICE_TO_FACTURA' = 'MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_FACTURA.SQL'
        'EAI_OWNER.INVOICE_TO_ENTREGA_PO' = 'MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_ENTREGA_PO.SQL'
        'T3.DELIVERY_WA_OXXO' = 'MSSQL/T3/T3/Procedures/T3.DELIVERY_WA_OXXO.StoredProcedure.sql'
    }
    foreach ($name in $modules.Keys) {
        $source = [IO.File]::ReadAllText((Join-Path $repoRoot $modules[$name]))
        $source = [regex]::Replace($source, '(?s)\r?\n[ \t]*-- RI3930_PROPAGATE_V1.*?IF @@TRANCOUNT > 0\s*BEGIN\s*THROW;\s*END;', '')
        if ($source.Contains('RI3930_PROPAGATE_V1')) { throw "No se retiro guard en $name" }
        $match = [regex]::Match($source, '(?is)BEGIN CATCH.*?END CATCH\s*;?')
        if (-not $match.Success) { throw "Falta CATCH en $name" }
        $catch = $match.Value
        $declaration = switch ($name) {
            'EAI_OWNER.INVOICE_TO_FACTURA' { 'CREATE   PROCEDURE' }
            'EAI_OWNER.INVOICE_TO_PREVENTA' { 'CREATE OR ALTER PROCEDURE' }
            'T3.DELIVERY_WA_OXXO' { "CREATE`tPROCEDURE" }
            default { 'CREATE PROCEDURE' }
        }
        $ddl = @"
$declaration $name @Caso int=0
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @sErrorCode varchar(500),@sMsg varchar(500),@v_ID varchar(50)='REF_TEST';
 BEGIN TRY
  IF @Caso=0 INSERT dbo.CheckData(Valor) VALUES(1);
  IF @Caso=1
  BEGIN
   SET XACT_ABORT ON;
   INSERT dbo.CheckData(Valor) VALUES(-1);
  END;
  IF @Caso=2
  BEGIN
   SET XACT_ABORT OFF;
   RAISERROR('Error de negocio confirmable',16,1);
  END;
 END TRY
 $catch
END;
"@
        Sql $ddl
    }
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Cases.sql'))
    Sql 'EXEC dbo.Assert3930 @Corregido=0;'
    $patch = [IO.File]::ReadAllText((Join-Path $patchRoot '01_CORREGIR_CATCH.sql'))
    $patch = $patch.Replace("@BaseEsperada sysname=N'T3QA'", "@BaseEsperada sysname=N'$db'")
    Sql ($patch.Replace('@Aplicar bit=1','@Aplicar bit=0'))
    Sql "IF OBJECT_ID(N'EAI_OWNER.RECV_INVOICE_3930_BACKUP') IS NOT NULL THROW 51901,'Preview escribio respaldo',1;"
    Sql $patch
    Sql 'EXEC dbo.Assert3930 @Corregido=1;'
    Sql $patch
    Sql "IF (SELECT COUNT(*) FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP)<>4 THROW 51902,'Reaplicacion duplico respaldos',1; PRINT 'PASS idempotencia y cuatro respaldos';"

    # Dos niveles de hijos: el error debe conservar procedimiento y numero
    # al atravesar los dos CATCH, antes de que el padre haga rollback/log.
    Sql @'
ALTER PROCEDURE EAI_OWNER.INVOICE_TO_FACTURA @Caso int=0 AS
BEGIN
 BEGIN TRY
  EXEC EAI_OWNER.INVOICE_TO_ENTREGA_PO @Caso;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 BEGIN THROW; END;
 END CATCH;
END;
GO
DECLARE @Error int=0,@Proc sysname;
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC EAI_OWNER.INVOICE_TO_FACTURA 1;
END TRY
BEGIN CATCH
 SELECT @Error=ERROR_NUMBER(),@Proc=ERROR_PROCEDURE();
 IF XACT_STATE()<>0 ROLLBACK;
 INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG(SIEBEL_ERROR_CODE,SIEBEL_ERROR_MESSAGE)
 VALUES(CONCAT('SQL-',@Error),@Proc);
END CATCH;
IF @Error<>547 OR PARSENAME(@Proc,1)<>'INVOICE_TO_ENTREGA_PO'
 THROW 51903,'Se perdio la causa en la cadena de dos hijos',1;
PRINT 'PASS cadena anidada y registro despues de rollback';
'@
    # La reversion debe rechazar cualquier cambio posterior sin pisarlo.
    $rollback = [IO.File]::ReadAllText((Join-Path $patchRoot '03_REVERTIR_SOLO_SI_ES_NECESARIO.sql'))
    $rollback = $rollback.Replace("DB_NAME()<>N'T3QA'", "DB_NAME()<>N'$db'")
    $rollback = $rollback.Replace('DECLARE @RunId uniqueidentifier=NULL;', 'DECLARE @RunId uniqueidentifier=(SELECT TOP(1) RunId FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP);')
    $failed = $false
    try { Sql $rollback } catch { $failed = $true }
    if (-not $failed) { throw 'La reversion no rechazo el modulo cambiado.' }
    Sql @'
DECLARE @D nvarchar(max)=
 (SELECT AlterOriginal FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE Nombre=N'EAI_OWNER.INVOICE_TO_FACTURA');
SET @D=STUFF(@D,CHARINDEX(N'BEGIN CATCH',@D)+11,0,
 CHAR(13)+CHAR(10)+N'        -- RI3930_PROPAGATE_V1'+CHAR(13)+CHAR(10)+
 N'        -- Propagar antes de escribir; el llamador decide rollback y logging.'+CHAR(13)+CHAR(10)+
 N'        -- Los cursores LOCAL se liberan al salir del procedimiento.'+CHAR(13)+CHAR(10)+
 N'        IF @@TRANCOUNT > 0'+CHAR(13)+CHAR(10)+N'        BEGIN'+CHAR(13)+CHAR(10)+N'            THROW;'+CHAR(13)+CHAR(10)+N'        END;');
EXEC sys.sp_executesql @D;
'@
    Sql $rollback
    Sql @'
IF EXISTS(SELECT 1 FROM EAI_OWNER.RECV_INVOICE_3930_BACKUP WHERE FechaReversion IS NULL)
 THROW 51904,'Falto revertir un modulo',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id IN
 (OBJECT_ID('EAI_OWNER.INVOICE_TO_PREVENTA'),OBJECT_ID('EAI_OWNER.INVOICE_TO_FACTURA'),
  OBJECT_ID('EAI_OWNER.INVOICE_TO_ENTREGA_PO'),OBJECT_ID('T3.DELIVERY_WA_OXXO'))
 AND CHARINDEX('RI3930_PROPAGATE_V1',definition)>0)
 THROW 51905,'Quedo guard tras revertir',1;
PRINT 'PASS reversion completa y proteccion de cambios posteriores';
'@
    Write-Output 'PASS pruebas RECV_INVOICE 3930 completadas'
} finally {
    if ($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
