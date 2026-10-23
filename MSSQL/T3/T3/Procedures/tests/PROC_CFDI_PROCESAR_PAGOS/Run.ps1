param([switch]$SoloLectura,[string]$CapturaReal,[switch]$ValidarResultado,[switch]$AnalizarDependencias,[switch]$ParidadOracle,[switch]$ValidarCero)
$ErrorActionPreference = 'Stop'
$server = '(localdb)\MSSQLLocalDB'
$db = 'CodexPagosDate_' + [guid]::NewGuid().ToString('N').Substring(0,10)
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../../../../..')).Path
$created = $false
$script:Report = New-Object 'System.Collections.Generic.List[string]'
function Sql([string]$Text) {
    $output = $Text | & sqlcmd -S $server -E -No -I -b -d $db -w 2000 2>&1
    foreach ($line in $output) { $script:Report.Add([string]$line) }
    if ($LASTEXITCODE -ne 0) { $output | Write-Output; throw 'Fallo prueba sintetica de pagos.' }
    $output | Where-Object { $_ -match '^PASS|^FAIL' } | Write-Output
}
function Load([string]$Path) {
    $sql = [IO.File]::ReadAllText((Join-Path $repo $Path))
    if ($AnalizarDependencias -or $ParidadOracle -or $ValidarCero) {
        $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $Path)).Hash
        $script:Report.Add("SOURCE $Path SHA256=$hash")
    }
    $sql = [regex]::Replace($sql,'(?im)^USE \[T3QA\]\s*\r?$','')
    $sql = [regex]::Replace($sql,'(?im)^(?:CREATE|ALTER)\s+(PROCEDURE|FUNCTION)\b','CREATE OR ALTER $1')
    Sql $sql
}
try {
    $dbCollation = if ($CapturaReal) { 'SQL_Latin1_General_CP1_CI_AS' } else { 'Latin1_General_100_CI_AS_KS_WS_SC' }
    & sqlcmd -S $server -E -No -b -Q "CREATE DATABASE [$db] COLLATE $dbCollation"
    if ($LASTEXITCODE -ne 0) { throw 'No se creo la base temporal.' }
    $created = $true
    Sql @'
CREATE SCHEMA T3;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE SEQUENCE EAI_OWNER.ProcessID AS bigint START WITH 1;
CREATE TABLE EAI_OWNER.MX_COMPONENTS(Component int,Status int,Last_Run datetime);
INSERT EAI_OWNER.MX_COMPONENTS VALUES(604,1,NULL),(889,1,NULL);
CREATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG
(DIRECTION varchar(100),REFERENCE varchar(50),CREATED datetime,MESSAGE varchar(max),
 JOB_PID int,STATUS varchar(20),QUEUE_NAME varchar(100),SIEBEL_ERROR_MESSAGE varchar(500),
 SOURCE varchar(50),SIEBEL_ERROR_CODE varchar(50),RETRY_COUNT int,SEQUENCE int,PARENT_ROW_ID varchar(50));
CREATE TABLE EAI_OWNER.MX_HashTable([Type] varchar(99),[Source] varchar(99),[Target] varchar(99));
INSERT EAI_OWNER.MX_HashTable VALUES
('CFG Settings','CompanyCode','MX06'),('CFG Settings','Banco Def - Directo','BANCO'),
('CFG Settings','Cuenta Def - Directo','123456'),
('TMD_PAC Accnt Payment Method','T','03'),('TMD_PAC Accnt Payment Type','T','Transfer');
GO
'@
    foreach ($table in @('ASIGNACION_PAGO','CLIENTE','REGISTRO_FISCAL','TIPO_DOCUMENTO',
        'PAGO','FACTURA_DETALLE','PREVENTA_GENERAL','PREVENTA_DETALLE',
        'CFDI_HISTORIA_DOCTO_PAC','CFDI_DOCUMENTOS','DEBIT_NOTE_IFC','CFDI_COBRANZA','RF_PROCESOS_LOG',
        'REGISTRO_FISCAL_DETALLE')) {
        Load "MSSQL/T3/T3/Tables/T3.$table.Table.sql"
    }
    Load 'MSSQL/T3/T3/Tables/T3.FACTURA_GENERAL.SQL'
    Load 'MSSQL/T3/T3/Funciones/FN_TOTAL_FACT.SQL'
    Load 'MSSQL/T3/EAI_OWNER/Functions/GETCONV.SQL'
    Load 'MSSQL/T3/EAI_OWNER/Procedures/LOG_START.SQL'
    Load 'MSSQL/T3/T3/Procedures/T3.WA_CFDI_COBZA_ASIG_CTRL.StoredProcedure.sql'
    Load 'MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.sql'
    Sql "PRINT 'PASS compilacion del procedimiento completo y dependencias disponibles';"
    if ($ValidarCero) {
        if ($CapturaReal -or $SoloLectura -or $ValidarResultado -or $AnalizarDependencias -or $ParidadOracle) {
            throw 'ValidarCero se ejecuta sin otros modos.'
        }
        Sql ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ZeroAmountAssertions.sql')))
        return
    }
    if ($ParidadOracle) {
        if ($CapturaReal -or $SoloLectura -or $ValidarResultado -or $AnalizarDependencias) {
            throw 'ParidadOracle se ejecuta sin otros modos.'
        }
        Sql ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'OracleParityAssertions.sql')))
        $check=[IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql'))
        foreach ($case in @(@{Fecha='2026-10-24';Filas=20;BasesNull=1},@{Fecha='2026-10-26';Filas=2;BasesNull=0})) {
            if ($case.Fecha -eq '2026-10-26') {
                Sql "TRUNCATE TABLE T3.CFDI_Cobranza; EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261026';"
            }
            $actual=$check.Replace("DECLARE @FechaProc date='2026-10-14';","DECLARE @FechaProc date='$($case.Fecha)';")
            Sql ($actual+"`nIF @UsaParidadOracle<>1 OR @nEsperadas<>$($case.Filas) OR @nInsertadas<>$($case.Filas) OR @nFaltantes+@nExcedentes+@nNoEsperadas+@nSinSaldo+@nErrores<>0 OR @nBaseNull<>$($case.BasesNull) THROW 52520,'Validador no reconoce reglas nuevas NULL/multiplicidad.',1; PRINT 'PASS validador compatible con NULL Oracle y multiplicidad: $($case.Fecha)';")
        }
        return
    }
    if ($AnalizarDependencias) {
        if ($CapturaReal -or $SoloLectura -or $ValidarResultado) {
            throw 'AnalizarDependencias se ejecuta sin otros modos.'
        }
        # Reproduccion historica: estos asserts esperan deliberadamente el defecto anterior.
        Load 'MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/BaselineOracleParity/T3.WA_CFDI_COBZA_ASIG_CTRL.StoredProcedure.sql'
        Load 'MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/BaselineOracleParity/T3.PROC_CFDI_PROCESAR_PAGOS.sql'
        Sql ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DependencyParity.sql')))
        return
    }
    if ($CapturaReal) {
        . (Join-Path $PSScriptRoot 'Read-Capture.ps1')
        $data=Read-PagosCapture $CapturaReal
        Sql "ALTER DATABASE [$db] SET CURSOR_DEFAULT GLOBAL;"
        Sql (Get-CapturedDataSql $data)
        foreach ($module in @('T3.FN_TOTAL_FACT','EAI_OWNER.GETCONV','EAI_OWNER.LOG_START',
            'T3.WA_CFDI_COBZA_ASIG_CTRL','T3.PROC_CFDI_PROCESAR_PAGOS')) {
            Sql (Get-CapturedModule $data $module)
        }
        Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'RealAssertions.sql'))
        Load 'MSSQL/T3/T3/Procedures/T3.WA_CFDI_COBZA_ASIG_CTRL.StoredProcedure.sql'
        Load 'MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.sql'
        Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'RealDateAssertions.sql'))
        return
    }
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Cases.sql'))
    Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'FunctionAssertions.sql'))
    if ($ValidarResultado) {
        Sql "EXEC T3.PROC_CFDI_PROCESAR_PAGOS '20261022';"
        $check=[IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_VALIDAR_RESULTADO.sql'))
        $check=$check.Replace("DECLARE @FechaProc date='2026-10-14';","DECLARE @FechaProc date='2026-10-22';")
        Sql ($check+@'

IF @nEsperadas<>10 OR @nInsertadas<>10 OR @nFaltantes<>0 OR @nExcedentes<>0 OR @nNoEsperadas<>0 OR @nSinSaldo<>0 OR @nErrores<>0
 THROW 52300,'La validacion no acredito las diez filas esperadas.',1;
IF (SELECT COUNT(*) FROM T3.CFDI_Cobranza)<>10 OR (SELECT COUNT(*) FROM T3.RF_PROCESOS_LOG)<>2
 THROW 52301,'La validacion modifico datos de negocio.',1;
PRINT 'PASS validador positivo: diez filas conciliadas, sin escrituras de negocio';
'@)
        Sql "DELETE T3.CFDI_Cobranza WHERE Asignacion_ID='A1';"
        Sql ($check+@'

IF @nFaltantes<>1 OR @nInsertadas<>9 THROW 52302,'El validador no detecto la fila faltante.',1;
PRINT 'PASS validador negativo: detecta una insercion faltante';
'@)
        Sql @'
INSERT T3.CFDI_Cobranza(Asignacion_ID,Factura,Fecha_Proc_BATMD,Fecha_Proceso)
SELECT Asignacion_ID,Factura,Fecha_Proc_BATMD,Fecha_Proceso FROM T3.CFDI_Cobranza WHERE Asignacion_ID='A2';
'@
        Sql ($check+@'

IF @nFaltantes<>1 OR @nExcedentes<>1 OR @nSinSaldo<>1
 THROW 52303,'El validador no detecto duplicado/incompleto.',1;
PRINT 'PASS validador negativo: detecta duplicado y saldo/parcialidad NULL';
'@)
        return
    }
    if ($SoloLectura) {
        $diagnostico = [IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/Diagnosticos/PROC_CFDI_PROCESAR_PAGOS_LECTURA.sql'))
        $diagnostico = $diagnostico.Replace('DECLARE @FechaProc date=NULL;','DECLARE @FechaProc date=''20261022'';')
        $preflight = @'
DECLARE @AntesAP bigint=(SELECT COUNT_BIG(*) FROM T3.Asignacion_Pago),
 @AntesComponentes int=(SELECT SUM(Status) FROM EAI_OWNER.MX_COMPONENTS);
'@
        $verificar = @'
IF (SELECT COUNT_BIG(*) FROM T3.Asignacion_Pago)<>@AntesAP
 OR EXISTS(SELECT 1 FROM T3.CFDI_Cobranza)
 OR EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG)
 OR EXISTS(SELECT 1 FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)
 OR (SELECT SUM(Status) FROM EAI_OWNER.MX_COMPONENTS)<>@AntesComponentes
 THROW 52040,'El diagnostico altero datos de prueba.',1;
PRINT 'PASS diagnostico completo ejecutado sin errores ni cambios en tablas de negocio';
'@
        $reportStart = $script:Report.Count
        Sql ($preflight + "`r`n" + $diagnostico + "`r`n" + $verificar)
        $captura = ($script:Report | Select-Object -Skip $reportStart) -join "`n"
        foreach ($section in @('01_AMBIENTE','04_DEFINICIONES','06_CURSOR_ANTES_SET',
            '07_CURSOR_DESPUES_SET','11_COBERTURA_HISTORIAL','12_ASIGNACIONES_HISTORIAL',
            '13_VIGENCIA','17_DETALLE_FISCAL','29_FIN')) {
            if (-not $captura.Contains($section)) { throw "Falta seccion $section en la captura." }
        }
        Write-Output 'PASS secciones de exportacion verificadas'
        return
    }
    $failedScopes = @()
    foreach ($scope in @('LOCAL','GLOBAL')) {
        Sql "ALTER DATABASE [$db] SET CURSOR_DEFAULT $scope;"
        Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'CursorBinding.sql'))
        try {
            Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'Assertions.sql'))
            Sql (Get-Content -Raw (Join-Path $PSScriptRoot 'CursorCleanup.sql'))
            Sql "PRINT 'PASS casos con CURSOR_DEFAULT $scope';"
        }
        catch {
            $failedScopes += $scope
            Write-Output "FAIL casos con CURSOR_DEFAULT $scope"
        }
    }
    if ($failedScopes.Count -gt 0) { throw "Fallo funcional en CURSOR_DEFAULT: $($failedScopes -join ', '). Ver LastRun.txt." }
}
finally {
    if ($created) {
        & sqlcmd -S $server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]"
        if ($LASTEXITCODE -ne 0) { throw "No se elimino la base temporal $db" }
        Write-Output 'PASS base temporal eliminada'
        $script:Report.Add('PASS base temporal eliminada')
    }
    $reportName = if ($ValidarCero) { 'LastZeroAmount.txt' } elseif ($ParidadOracle) { 'LastOracleParity.txt' } elseif ($AnalizarDependencias) { 'LastDependencyParity.txt' } elseif ($ValidarResultado) { 'LastValidation.txt' } elseif ($CapturaReal) { 'LastRealRun.txt' } elseif ($SoloLectura) { 'LastRead.txt' } else { 'LastRun.txt' }
    $script:Report | Set-Content -LiteralPath (Join-Path $PSScriptRoot $reportName) -Encoding UTF8
}
