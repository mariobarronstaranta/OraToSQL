# Prueba de rendimiento y equivalencia de etapa 10; solo base local desechable.
param([string]$Server = '(localdb)\MSSQLLocalDB')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$db='CodexOpenItemsPerf_'+[guid]::NewGuid().ToString('N').Substring(0,12)
$created=$false
function Sql([string]$Text) {
    $Text="SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;`nGO`n"+$Text
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
    function Artifact([string]$Path) {
        $s=Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
        $s=[regex]::Replace($s,'(?im)^USE\s+\[[^\]]+\]\s*\r?\nGO\s*\r?\n','')
        return [regex]::Replace($s,'(?im)^ALTER\s+(FUNCTION|PROCEDURE)', 'CREATE OR ALTER $1')
    }
    foreach($fn in @('FN_COBZA_PAY','FN_COBZA_CM_UUID')) {
        Sql (Artifact (Join-Path $root "T3/Funciones/$fn.SQL"))
    }
    $original=Artifact (Join-Path $root 'EAI/Procedures/SF_CFDI_OPEN_ITEMS.SQL')
    $nuevo=Artifact (Join-Path $root 'EAI/Procedures/SF_CFDI_OPEN_ITEMS_RENDIMIENTO.SQL')
    Sql $nuevo
    foreach($case in @(@('Original',$original),@('Nuevo',$nuevo))) {
        $s=$case[1]
        $first=$s.IndexOf('        IF ISNULL(@nEtapa, 0) <= 10')
        $last=$s.IndexOf('        -------------------------------------------------------------------',$first)
        if($first -lt 0 -or $last -lt $first){throw 'No se pudo extraer etapa 10.'}
        $body=$s.Substring($first,$last-$first)
        Sql ("CREATE OR ALTER PROCEDURE EAI.TestHistoric"+$case[0]+" @nEtapa int=10, @FechaInicio date='20260101', @Diagnostico bit=0 AS BEGIN SET NOCOUNT ON; DECLARE @nProceso4 int; "+$body+" END;")
    }
    # Verificar tambien el diagnostico y los DDL sugeridos, solo en esta base.
    $diagnostic=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'EAI/Procedures/SF_CFDI_OPEN_ITEMS_DIAGNOSTICO.SQL')
    Sql $diagnostic | Out-Null
    foreach($ddl in [regex]::Matches($diagnostic,"'CREATE INDEX [^']+'")) {
        Sql ($ddl.Value.Trim("'"))
    }
    Write-Output 'PASS: diagnostico de solo lectura y 12 propuestas de indices compilan.'
    Sql (Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Rendimiento.sql'))
} finally {
    if($created){
        & sqlcmd -S $Server -E -No -b -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
    }
}

