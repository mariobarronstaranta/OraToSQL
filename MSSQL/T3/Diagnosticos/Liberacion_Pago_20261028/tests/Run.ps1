$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$folder=Split-Path -Parent $PSScriptRoot
$server='(localdb)\MSSQLLocalDB'
$db='CodexLibPagoDiag_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$outputFolder=Join-Path $repo ('tmp/liberacion_pago_diag_'+$db)
$null=New-Item -ItemType Directory -Path $outputFolder -Force
$created=$false
function Sql([string]$Text) {
 $output=("SET NOCOUNT ON;`nGO`n"+$Text) | & sqlcmd -S $server -E -No -I -b -l 5 -d $db
 if($LASTEXITCODE -ne 0){throw ('Fallo prueba de diagnostico de liberacion: '+($output -join "`n"))}
 $output -join "`r`n"
}
function Ddl([string]$Path,[string]$Schema,[string]$Table) {
 $s=[IO.File]::ReadAllText((Join-Path $repo $Path))
 $m=[regex]::Match($s,'(?ims)^CREATE TABLE \['+$Schema+'\]\.\['+$Table+'\].*?^GO\s*$')
 if(-not $m.Success){throw "No se encontro DDL $Schema.$Table"}
 $null=Sql $m.Value
}
function Module([string]$Path) {
 $s=[IO.File]::ReadAllText((Join-Path $repo $Path))
 $m=[regex]::Match($s,'(?im)^(CREATE(?:\s+OR\s+ALTER)?|ALTER)\s+(FUNCTION|PROCEDURE)')
 if(-not $m.Success){throw "No se encontro modulo $Path"}
 $s=$s.Substring($m.Index)
 $s=[regex]::Replace($s,'\A(CREATE(?:\s+OR\s+ALTER)?|ALTER)\s+(FUNCTION|PROCEDURE)','CREATE OR ALTER $2',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
 $null=Sql ("SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;`nGO`n"+$s)
}
function Capture([string]$Name,[string]$Sql,[string[]]$Needles) {
 $o=Sql $Sql
 [IO.File]::WriteAllText((Join-Path $outputFolder ($Name+'.txt')),$o)
 foreach($n in $Needles){if(-not $o.Contains($n)){throw "No aparece $n en $Name"}}
 if($o.Contains('99_ERROR_DIAGNOSTICO')){throw 'El diagnostico reporto error.'}
 Write-Host "PASS $Name"
 return $o
}
try {
 & sqlcmd -S $server -E -No -b -l 5 -Q "CREATE DATABASE [$db] COLLATE SQL_Latin1_General_CP1_CI_AS"
 if($LASTEXITCODE -ne 0){throw 'No fue posible crear la base temporal.'}
 $created=$true
 $null=Sql "CREATE SCHEMA T3;`nGO`nCREATE SCHEMA EAI_OWNER;`nGO`nCREATE SCHEMA EAI;`nGO"
 $pre=[IO.File]::ReadAllText((Join-Path $folder '01_VALIDAR_PRECONDICIONES.sql'))
 $sample=[IO.File]::ReadAllText((Join-Path $folder '04_VALIDAR_MUESTRA_LIGERA.sql'))
 $null=Capture '01_dependencias_ausentes' $pre @('05_DIAGNOSTICO_DETENIDO','NO VISIBLE O AUSENTE')
 foreach($t in @('CFDI_COBRANZA','CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR','CFDI_RFC_SETTING',
 'CFDI_REPROCESO','CFDI_USOCFDI_CLIENTE','DISTRIBUIDOR_FISCAL','MOV_CLIENTE','TMD_EMAIL',
 'REGISTRO_FISCAL','REGISTRO_FISCAL_DETALLE','RF_PROCESOS_LOG','RF_ERROR_LOG')){
  Ddl ('MSSQL/T3/T3/Tables/T3.'+$t+'.Table.sql') 'T3' $t
 }
 foreach($t in @('MX_COMPONENTS','MX_HASHTABLE','MX_EAI_MESSAGE_LOG')){
  Ddl 'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql' 'EAI_OWNER' $t
 }
 Ddl 'MSSQL/T3/EAI/Tablas/Tablas_Schema_EAI_T3.sql' 'EAI' 'ZSDFE_SOC'
 $null=Sql @'
CREATE SEQUENCE EAI_OWNER.ProcessID AS bigint START WITH 26515000 INCREMENT BY 1 MAXVALUE 9999999999;
GO
-- Funciones de formato de prueba: solo se inspecciona su existencia. El
-- diagnostico NO las ejecuta ni se usa esta fixture para generar layouts.
CREATE FUNCTION T3.FN_TRIM_CFDI(@x varchar(max)) RETURNS varchar(max) AS BEGIN RETURN TRIM(@x); END;
GO
CREATE FUNCTION T3.FN_ADJUST_GMT(@x varchar(8),@n decimal(3,0)) RETURNS varchar(8) AS BEGIN RETURN @x; END;
GO
CREATE FUNCTION T3.FN_NUM_TO_CHAR_CFDI(@x decimal(38,8),@n int) RETURNS varchar(99) AS BEGIN RETURN CONVERT(varchar(99),@x); END;
GO
'@
 Module 'MSSQL/T3/EAI_OWNER/Functions/GETCONV.SQL'
 Module 'MSSQL/T3/T3/Funciones/FN_VALIDA_RFC.SQL'
 Module 'MSSQL/T3/EAI_OWNER/Procedures/LOG_START.SQL'
 Module 'MSSQL/T3/T3/Procedures/PROC_V20_GENERAR_PAGO.sql'
 Module 'MSSQL/T3/T3/Procedures/PROC_CFDI_LIBERACION_PAGO.sql'
 $null=Sql @'
INSERT EAI_OWNER.MX_COMPONENTS(Component,Name,Status) VALUES(613,'LIBERACION_PAGO',1);
INSERT EAI_OWNER.MX_HASHTABLE([Type],[Source],[Target]) VALUES
 ('CFG Settings','VersionCFDI','4.0'),('CFG Settings','Regimen Fiscal','601'),
 ('CFG Settings','Regimen Fiscal Cliente','601'),('CFG Settings','UsoCFDI_Payment','CP01'),
 ('CFG Settings','UsoCFDI_Comercial','G03'),('CFG Settings','Payment Default Time','120000'),
 ('CFG Settings','Metodo Pago','PPD');
INSERT T3.DISTRIBUIDOR_FISCAL(DISTRIBUIDOR,CTRO,DIF_GMT,CODIGO_POSTAL) VALUES(1,'MX01',0,64000);
INSERT EAI.ZSDFE_SOC(BUKRS,KUNNR,RFC,RAZON_SOCIAL_HH,CODIGO_POSTAL)
 VALUES('1000','1000','EMP010101AA1','EMPRESA',64000);
INSERT T3.MOV_CLIENTE(CLIENTE_SAP,RFC,NOMBRE,CODIGO_POSTAL_3,CODIGO_POSTAL_2)
 VALUES('0000000100','ABC010101AA1','CLIENTE','01000','01000');
INSERT T3.CFDI_USOCFDI_CLIENTE(CLIENTE_SAP,USO_VENTA,DESGLOSE_IEPS) VALUES('0000000100','G03',0);
INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,FOLIO_ID,FACTURA,NOTA_VENTA,RFC,CLIENTE_SAP,
 CTRO,SOCIEDAD,IMPORTE,SALDO_ANTERIOR,NUMERO_PAGO,FECHA_PAGO,FECHA_ASIGNACION,
 VIA_PAGO,CREATED_BY,UUID_VENTA)
 VALUES('TESTPAGO1','PG-001','HH-00001234','VENTA1','ABC010101AA1','0000000100',
 'MX01','1000',116,116,1,GETDATE(),GETDATE(),'01','TEST','11111111-1111-1111-1111-111111111111');
INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,METODO_PAGO) VALUES('VENTA1','PPD');
INSERT T3.REGISTRO_FISCAL(FACTURA,CLIENTE_SAP) VALUES('HH-00001234','0000000100');
INSERT T3.REGISTRO_FISCAL_DETALLE(FACTURA,NUM_LINEA,VALOR_SUBT,VALOR_IVA,VALOR_IEPS)
 VALUES('HH-00001234',1,100,16,0);
'@
 $o=Capture '02_factura_corta' $pre @('FACTURA_TRUNCADA_A_4','SIN_BASE_FISCAL','TESTPAGO1')
 if($o -notmatch '07_RESUMEN_CANDIDATOS\s+1\s+1\s+1\s+1\s+0\s+200'){
  throw 'No coincide el conteo del candidato de prueba.'
 }
 $o=Capture '02B_muestra_factura_corta' $sample @('07_RESUMEN_MUESTRA','FACTURA_TRUNCADA_A_4','13_ALCANCE_MUESTRA')
 if($o -notmatch '07_RESUMEN_MUESTRA\s+1\s+1\s+1\s+1\s+0\s+100'){
  throw 'No coincide el candidato de la muestra.'
 }
 $null=Sql @'
INSERT T3.CFDI_COBRANZA SELECT C.* FROM T3.CFDI_COBRANZA C
CROSS JOIN(SELECT TOP(209) 1 AS N FROM sys.all_objects) X;
'@
 $o=Capture '02C_limite_antes_de_validaciones' $sample @('07_RESUMEN_MUESTRA','13_ALCANCE_MUESTRA')
 if($o -notmatch '07_RESUMEN_MUESTRA\s+100\s+100\s+100\s+1\s+0\s+100'){
  throw 'La muestra no limita las cobranzas antes de validar.'
 }
 $null=Sql @'
;WITH D AS(SELECT *,ROW_NUMBER() OVER(ORDER BY(SELECT NULL)) AS R FROM T3.CFDI_COBRANZA)
DELETE FROM D WHERE R>1;
'@
 # Solo en la fixture: simular una instalacion con variable ya ampliada.
 # Usar el archivo completo para no depender del truncamiento del sqlcmd SELECT.
 $s=[IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/T3/Procedures/PROC_V20_GENERAR_PAGO.sql'))
 $m=[regex]::Match($s,'(?im)^(CREATE(?:\s+OR\s+ALTER)?|ALTER)\s+PROCEDURE')
 if(-not $m.Success){throw 'No se encontro el encabezado del generador.'}
 $s=$s.Substring($m.Index)
 $s=[regex]::Replace($s,'\A(CREATE(?:\s+OR\s+ALTER)?|ALTER)\s+PROCEDURE','ALTER PROCEDURE')
 $s=[regex]::Replace($s,'(?i)@sFacturaPagada\s+VARCHAR\(4\)','@sFacturaPagada VARCHAR(30)')
 $null=Sql $s
 $o=Capture '03_factura_completa' $pre @('11_FISCAL','TESTPAGO1')
 if($o.Contains('FACTURA_TRUNCADA_A_4') -or $o.Contains('SIN_BASE_FISCAL')){
  throw 'El diagnostico no reconoce la variable ampliada de prueba.'
 }
 $null=Sql 'UPDATE T3.CFDI_COBRANZA SET SALDO_ANTERIOR=99999999999999.99;'
 $null=Capture '04_saldo_fuera_de_str' $pre @('SALDO_NO_CABE_EN_STR')
 $null=Sql 'UPDATE T3.CFDI_COBRANZA SET SALDO_ANTERIOR=116;'
 $null=Sql 'UPDATE T3.REGISTRO_FISCAL_DETALLE SET VALOR_SUBT=0,VALOR_IVA=0;'
 $null=Capture '04_denominador_cero' $pre @('DENOMINADOR_CERO')
 $null=Sql 'UPDATE T3.REGISTRO_FISCAL_DETALLE SET VALOR_SUBT=100,VALOR_IVA=16; INSERT T3.MOV_CLIENTE SELECT * FROM T3.MOV_CLIENTE;'
 $null=Capture '05_join_multiplica' $pre @('JOIN_MULTIPLICA_CABECERAS')
 $null=Sql 'DELETE T3.MOV_CLIENTE;'
 $null=Capture '05_cliente_ausente' $pre @('SIN_DATOS_CABECERA')
 $null=Sql @'
IF EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS_ENVIAR) THROW 52770,'El diagnostico creo layouts.',1;
IF EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE Fecha_Envio IS NOT NULL) THROW 52771,'El diagnostico marco cobranzas.',1;
IF EXISTS(SELECT 1 FROM T3.RF_PROCESOS_LOG) THROW 52772,'El diagnostico ejecuto el proceso.',1;
IF EXISTS(SELECT 1 FROM EAI_OWNER.MX_COMPONENTS WHERE Status<>1) THROW 52773,'Cambio el componente.',1;
IF EXISTS(SELECT 1 FROM sys.sequences WHERE object_id=OBJECT_ID(N'EAI_OWNER.ProcessID')
 AND (CONVERT(bigint,current_value)<>26515000 OR last_used_value IS NOT NULL)) THROW 52774,'Se consumio la secuencia.',1;
'@
 Write-Output 'PASS diagnostico sin layouts, marcas, bitacoras de corrida ni consumo de secuencia'
 $post=[IO.File]::ReadAllText((Join-Path $folder '02_VALIDAR_RESULTADO.sql'))
 $post=$post.Replace('DECLARE @Desde datetime2(0)=NULL;','DECLARE @Desde datetime2(0)=DATEADD(day,-1,SYSDATETIME());')
 $null=Capture '06_post_sin_lista' $post @('06_SIN_BASELINE')
 $json='[{"Asignacion_ID":"TESTPAGO1","LayoutsAntes":0,"DocumentosAntes":0,"CobranzasMarcadasAntes":0}]'
 $post=$post.Replace("DECLARE @Baseline nvarchar(max)=N'[]';","DECLARE @Baseline nvarchar(max)=N'$json';")
 $null=Capture '07_post_sin_altas' $post @('REVISAR: NO SE ACREDITAN TODAS LAS SALIDAS ESPERADAS')
 $null=Sql @'
INSERT T3.CFDI_DOCUMENTOS_ENVIAR(NOTA_VENTA,INFORMACION) VALUES('TESTPAGO1','CABPAGOS|2.0|PRUEBA');
INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,FECHA_LIBERACION) VALUES('TESTPAGO1',GETDATE());
UPDATE T3.CFDI_COBRANZA SET FECHA_ENVIO=GETDATE();
'@
 $null=Capture '08_post_con_altas_fixture' $post @('HAY ALTAS Y MARCAS; REVISAR CONTENIDO/ERRORES')
 # Rastreo06: recepcion reciente con fecha de negocio antigua, etapas
 # incompletas, BATMD diferente, reglas de exclusion y collations mezcladas.
 . (Join-Path $PSScriptRoot 'Trace.ps1')
 Write-Output "PASS reportes en $outputFolder"
} finally {
 if($created -and $db -match '^CodexLibPagoDiag_[a-f0-9]{10}$'){
  & sqlcmd -S $server -E -No -b -l 5 -Q "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
  if($LASTEXITCODE -ne 0){Write-Warning "Revisar limpieza $db"}
 }
}
