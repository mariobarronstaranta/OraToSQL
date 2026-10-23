# Diagnostico de diferencias; NO certifica equivalencia ni despliega a T3QA.
param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$db='CodexOpenItems_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$created=$false
function Sql([string]$Text) {
    $Text | & sqlcmd -S $Server -E -No -b -d $db
    if($LASTEXITCODE -ne 0){throw 'Fallo de comprobacion SQL.'}
}
function Table([string]$File,[string]$Schema,[string]$Name) {
    $ddl=Get-Content -Raw -Encoding UTF8 -LiteralPath $File
    $m=[regex]::Match($ddl,'(?ims)^CREATE TABLE \['+$Schema+'\]\.\['+$Name+'\].*?^GO\s*$')
    if(-not $m.Success){throw "DDL no encontrado: $Schema.$Name"}
    Sql $m.Value
}
try {
    & sqlcmd -S $Server -E -No -b -Q "CREATE DATABASE [$db]"
    if($LASTEXITCODE -ne 0){throw 'No se creo la base temporal.'}
    $created=$true
    Sql "CREATE SCHEMA EAI;`nGO`nCREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA T3;`nGO"
    foreach($t in @('CFDI_OPEN_ITEMS','T3R_CARTERA_SAP_OLD')) {
        Table (Join-Path $root 'EAI/Tablas/Tablas_Schema_EAI_T3.sql') 'EAI' $t
    }
    foreach($t in @('MX_COMPONENTS','MX_EAI_MESSAGE_LOG')) {
        Table (Join-Path $root 'EAI_OWNER/Tables/Tablas_EAI_OWNER.sql') 'EAI_OWNER' $t
    }
    foreach($t in @('CFDI_REFOLEO','REGISTRO_FISCAL','OTROS_GENERAL','FACTURA_DETALLE',
        'PREVENTA_GENERAL','PREVENTA_DETALLE','CLIENTE','CFDI_COBRANZA','CFDI_DOCUMENTOS',
        'CFDI_AGRUPACION_PAGO','CFDI_AGRUPACION_CTRL','REGISTRO_FISCAL_DETALLE',
        'MOV_CLIENTE','DEBIT_NOTE_IFC','CFDI_HISTORIA_DOCTO_PAC','NDC_ISSUE_IVA','RF_PROCESOS_LOG')) {
        Table (Join-Path $root "T3/Tables/T3.$t.Table.sql") 'T3' $t
    }
    Table (Join-Path $root 'T3/Tables/T3.FACTURA_GENERAL.SQL') 'T3' 'FACTURA_GENERAL'
    Sql 'CREATE SEQUENCE EAI_OWNER.ProcessID AS bigint START WITH 1;'
    Sql (Get-Content -Raw (Join-Path $root 'EAI_OWNER/Procedures/LOG_START.SQL'))
    Sql (Get-Content -Raw (Join-Path $root 'EAI_OWNER/Functions/FN_GET_TAX_ISSUE.SQL'))
    # Funciones externas no disponibles: stubs EXCLUSIVAMENTE para la prueba.
    Sql @'
CREATE FUNCTION T3.FN_Cobza_Pay(@Nota varchar(30)) RETURNS decimal(16,2)
AS BEGIN RETURN 0; END;
GO
CREATE FUNCTION T3.FN_COBZA_CM_UUID(@Nota varchar(30)) RETURNS decimal(16,2)
AS BEGIN RETURN 0; END;
GO
'@
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL'))
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Differences.sql'))
} finally {
    if($created){
        & sqlcmd -S $Server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}
