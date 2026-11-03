# Se ejecuta dentro de la base temporal creada por Run.ps1. Nunca en T3QA.
$maintained=[IO.File]::ReadAllText((Join-Path $owner 'Procedures/SF_PROC_PREINVOICE_IFC.SQL'))
$skuMarker='(?s)/\* RI_SKU_SEEK_V1 \*/.*?/\* RI_SKU_SEEK_END_V1 \*/'
if([regex]::IsMatch($maintained,$skuMarker)){
 $marked=[regex]::Match($maintained,$skuMarker).Value
 $decls=[regex]::Matches($marked,'(?s)DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR.*?;')
 if($decls.Count -ne 2){throw 'Se esperaban las consultas SKU rapida y original.'}
 $maintained=[regex]::Replace($maintained,$skuMarker,[Text.RegularExpressions.MatchEvaluator]{param($m) $decls[1].Value})
}
$block=[regex]::Match($maintained,'(?s)DECLARE\s+@UOM_Fact NVARCHAR\(50\).*?DEALLOCATE curSKU;').Value
$oldQuery=[regex]::Match($block,'(?s)DECLARE curSKU CURSOR LOCAL FAST_FORWARD FOR.*?;').Value
if(-not $block -or -not $oldQuery){throw 'No se encontro el bloque SKU de prueba.'}
$oldWhere='WHERE SKU.MATERIAL = @sMaterialUOM;'
$newWhere="WHERE SKU.MATERIAL = CONVERT(varchar(18),@sMaterialUOM)`n                      AND CONVERT(nvarchar(50),SKU.MATERIAL) = @sMaterialUOM;"
if(-not $oldQuery.Contains($oldWhere)){throw 'Predicado SKU no reconocido.'}
$newQuery=@'
/* RI_SKU_SEEK_V1 */
IF CONVERT(varbinary(max),CONVERT(nvarchar(50),CONVERT(varchar(18),@sMaterialUOM)))
   = CONVERT(varbinary(max),@sMaterialUOM)
BEGIN
{FAST}
END
ELSE
BEGIN
{ORIGINAL}
END;
/* RI_SKU_SEEK_END_V1 */
'@
$newQuery=$newQuery.Replace('{FAST}',$oldQuery.Replace($oldWhere,$newWhere)).Replace('{ORIGINAL}',$oldQuery)
$newBlock=$block.Replace($oldQuery,$newQuery)
$ddlMaterial=[IO.File]::ReadAllText((Join-Path $repo 'MSSQL/T3/T3/Tables/T3.MATERIAL.Table.sql'))
$ddlMatch=[regex]::Match($ddlMaterial,'(?ims)^CREATE TABLE \[T3\]\.\[MATERIAL\].*?^GO\s*$')
if(-not $ddlMatch.Success){throw 'No se encontro el DDL real de MATERIAL.'}
Sql $ddlMatch.Value
Sql @'
CREATE INDEX IX_SkuProof ON T3.MATERIAL(MATERIAL);
INSERT EAI_OWNER.MX_HASHTABLE([TYPE],[SOURCE],[TARGET]) VALUES
 ('ECC_V3 UOM','P','PAQ'),('ECC_V3 UOM','C','CASES'),('ECC_V3 UOM','U','UNI'),
 ('ECC_V3 UOM','CAJ','CAJ'),('ECC_V3 UOM','PAQ','PAQ'),('ECC_V3 UOM','N',NULL);
;WITH D AS (SELECT N FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) V(N))
INSERT T3.MATERIAL(MATERIAL,UM,CIG_X_CLL,CIG_X_PAQ,CIG_X_CT)
SELECT TOP(10000) RIGHT('00000000'+CONVERT(varchar(8),ROW_NUMBER() OVER(ORDER BY A.N)),8),
 'CAJ',100,20,500 FROM D A CROSS JOIN D B CROSS JOIN D C CROSS JOIN D E;
INSERT T3.MATERIAL(MATERIAL,UM,CIG_X_CLL,CIG_X_PAQ,CIG_X_CT) VALUES
 ('12345678','CAJ',100,20,500),('DUP','CAJ',100,20,500),('DUP','PAQ',100,50,200),
 ('','CAJ',100,20,500),('?','CAJ',100,20,500),('caf'+CHAR(233),'CAJ',100,20,500),
 ('ZERO','CAJ',0,20,500),('NUL','CAJ',NULL,NULL,NULL),('NULLUM',NULL,100,20,500);
'@
foreach($variant in @(@{Name='SkuOriginal';Body=$block},@{Name='SkuNuevo';Body=$newBlock})){
 $body=$variant.Body
 $procedure="CREATE OR ALTER PROCEDURE EAI_OWNER.$($variant.Name) @sMaterialUOM nvarchar(50),@sUnidadMedVta nvarchar(50),@sCantidadVta nvarchar(50),@Qty nvarchar(50) OUTPUT,@Unidad nvarchar(50) OUTPUT AS BEGIN SET NOCOUNT ON;`n$body`nSET @Qty=@sCantidadVta; SET @Unidad=@sUnidadMedVta; END;`nGO"
 Sql $procedure
}
Sql @'
SET NOCOUNT ON;
DECLARE @Cases TABLE(Id int IDENTITY,Material nvarchar(50),Uom nvarchar(50),Cantidad nvarchar(50));
INSERT @Cases VALUES
 (N'12345678',N'P',N'10'),(N'12345678',N'C',N'10'),(N'12345678',N'U',N'10'),
 (N'12345678',N'CAJ',N'10'),(N'12345678',NULL,N'10'),(N'12345678',N'N',N'10'),
 (NULL,N'P',N'10'),(N'',N'P',N'10'),(N' ',N'P',N'10'),(N'NO_EXISTE',N'P',N'10'),
 (N'DUP',N'P',N'10'),(N'DUP',N'C',N'10'),(N'ZERO',N'P',N'10'),(N'NUL',N'C',N'10'),
 (N'NULLUM',N'P',N'10'),(N'caf'+NCHAR(233),N'P',N'10'),(N'00001001',N'P',N'10'),
 (N'12345678                  ',N'P',N'10'),(NCHAR(28450),N'P',N'10'),
 (N'12345678',N'P',N'INVALIDO');
DECLARE @i int=1,@m nvarchar(50),@u nvarchar(50),@c nvarchar(50),
 @qa nvarchar(50),@qb nvarchar(50),@ua nvarchar(50),@ub nvarchar(50),@ea int,@eb int;
WHILE @i<=(SELECT COUNT(*) FROM @Cases)
BEGIN
 SELECT @m=Material,@u=Uom,@c=Cantidad FROM @Cases WHERE Id=@i;
 SELECT @qa=NULL,@qb=NULL,@ua=NULL,@ub=NULL,@ea=0,@eb=0;
 BEGIN TRY EXEC EAI_OWNER.SkuOriginal @m,@u,@c,@qa OUTPUT,@ua OUTPUT; END TRY
 BEGIN CATCH SET @ea=ERROR_NUMBER(); END CATCH;
 BEGIN TRY EXEC EAI_OWNER.SkuNuevo @m,@u,@c,@qb OUTPUT,@ub OUTPUT; END TRY
 BEGIN CATCH SET @eb=ERROR_NUMBER(); END CATCH;
 IF @ea<>@eb OR (@ea=0 AND
   (ISNULL(CONVERT(varbinary(max),@qa),0x)<>ISNULL(CONVERT(varbinary(max),@qb),0x)
    OR ISNULL(CONVERT(varbinary(max),@ua),0x)<>ISNULL(CONVERT(varbinary(max),@ub),0x)
    OR (@qa IS NULL AND @qb IS NOT NULL) OR (@qa IS NOT NULL AND @qb IS NULL)
    OR (@ua IS NULL AND @ub IS NOT NULL) OR (@ua IS NOT NULL AND @ub IS NULL)))
 BEGIN
  SELECT @i Caso,@m Material,@qa CantidadOriginal,@qb CantidadNueva,@ua UomOriginal,@ub UomNueva,@ea ErrorOriginal,@eb ErrorNuevo;
  THROW 52670,'Diferencia de reglas en cursor SKU.',1;
 END;
 SET @i+=1;
END;
PRINT 'PASS 20 casos SKU: cantidades, unidades, duplicados, NULL, vacios y error original';

DECLARE @start datetime2,@oldMs decimal(18,3),@newMs decimal(18,3),@loops int=300;
SET @i=1;SET @start=SYSDATETIME();
WHILE @i<=@loops
BEGIN EXEC EAI_OWNER.SkuOriginal N'00001001',N'P',N'10',@qa OUTPUT,@ua OUTPUT;SET @i+=1;END;
SET @oldMs=DATEDIFF_BIG(MICROSECOND,@start,SYSDATETIME())/1000.0;
SET @i=1;SET @start=SYSDATETIME();
WHILE @i<=@loops
BEGIN EXEC EAI_OWNER.SkuNuevo N'00001001',N'P',N'10',@qb OUTPUT,@ub OUTPUT;SET @i+=1;END;
SET @newMs=DATEDIFF_BIG(MICROSECOND,@start,SYSDATETIME())/1000.0;
SELECT @loops Llamadas,10000 MaterialesSinteticos,@oldMs TiempoOriginal_ms,@newMs TiempoNuevo_ms,
 @oldMs/@loops MediaOriginal_ms,@newMs/@loops MediaNueva_ms;
'@

$skuPatchPath=Join-Path $package '05_CORREGIR_BUSQUEDA_SKU.sql'
if(Test-Path -LiteralPath $skuPatchPath){
 # La base temporal recibe el cursor anterior en memoria para probar aplicacion real.
 Sql $maintained
 $skuPatch=[IO.File]::ReadAllText($skuPatchPath).Replace("N'T3QA'","N'$db'")
 Sql $skuPatch
 Sql $skuPatch
 Sql @'
DECLARE @s nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'));
IF CHARINDEX(N'RI_SKU_SEEK_V1',@s)=0
 OR CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_HEADER',@s)=0
 OR CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_DETAIL',@s)=0
 OR CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_CONDITIONS',@s)=0
 THROW 52671,'No se preservaron todos los ajustes.',1;
IF (SELECT COUNT(*) FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP WHERE FechaReversion IS NULL)<>1
 THROW 52672,'Aplicacion SKU no idempotente.',1;
DECLARE @p int;
EXECUTE AS USER=N'RefSeekProof';
SET @p=HAS_PERMS_BY_NAME(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC',N'OBJECT',N'EXECUTE');
REVERT;
IF ISNULL(@p,0)<>1 THROW 52673,'Se perdio un permiso del SP.',1;
PRINT 'PASS parche SKU, repeticion, permisos y preservacion de ReferenceID';
'@
 $skuRevert=[IO.File]::ReadAllText((Join-Path $package '02_REVERTIR_REFERENCEID.sql')).Replace("N'T3QA'","N'$db'")
 $skuRevert=$skuRevert.Replace('DECLARE @RunId UNIQUEIDENTIFIER=NULL;', 'DECLARE @RunId UNIQUEIDENTIFIER=(SELECT TOP(1) RunId FROM EAI_OWNER.RECV_INVOICE_PERF_BACKUP ORDER BY FechaAplicacion DESC);')
 Sql $skuRevert
 Sql $skuRevert
 Sql @'
DECLARE @s nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'EAI_OWNER.SF_PROC_PREINVOICE_IFC'));
IF CHARINDEX(N'RI_SKU_SEEK_V1',@s)>0 OR CHARINDEX(N'RI_REF_SEEK_TMP_DOCUMENT_DETAIL',@s)=0
 THROW 52674,'Reversion SKU no conservo el parche previo.',1;
PRINT 'PASS reversion SKU conservando ReferenceID';
'@
 Sql ([IO.File]::ReadAllText((Join-Path $owner 'Procedures/SF_PROC_PREINVOICE_IFC.SQL')))
 Sql 'DELETE EAI_OWNER.MX_RECEIVE_MESSAGE_LOG; DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG;'
 Sql ([IO.File]::ReadAllText((Join-Path $legacy 'Cases.sql')))
 Write-Output 'PASS fuente mantenido con SKU y seis casos de transacciones'
}
