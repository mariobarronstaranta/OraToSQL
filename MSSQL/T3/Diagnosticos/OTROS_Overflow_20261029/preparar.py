"""Prepara correccion puntual y evidencia; no conecta a T3QA."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
path=ROOT/'MSSQL/T3/T3/Procedures/PROC_V40_GENERAR_OTROS.sql'
old1="TRIM(CAST(ROUND( ISNULL( Doc.Valor_IVA , 0 ) * 100 /      NULLIF(( ISNULL( Ret.Retenido, 0 ) + ISNULL( Doc.Valor_Subt, 0 )),0),0) AS VARCHAR(10)))"
new1=old1.replace('VARCHAR(10)','VARCHAR(40)')
old2='T3.FN_NUM_TO_CHAR_CFDI( @Doc_tasa / 100      , 6 )'
new2='T3.FN_NUM_TO_CHAR_CFDI( CAST(@Doc_tasa AS DECIMAL(38,12)) / 100.0, 6 )'
raw=path.read_bytes();enc='utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig'
before=HERE/'PROC_V40_GENERAR_OTROS.antes.sql'
if before.exists() and before.read_bytes()!=raw:raise RuntimeError('Existe respaldo diferente; no sobrescribir')
text=raw.decode(enc)
assert text.count(old1)==text.count(old2)==1
before.write_bytes(raw)
text=text.replace(old1,new1).replace(old2,new2)
text=text.replace('Documentacion : 29/10/2026. Solo comentarios; SQL ejecutable conservado.',
 'Documentacion : 29/10/2026. Correccion de conversion de tasa: ver OTROS_Overflow_20261029.')
text=text.replace('-- @Doc_tasa es VARCHAR: revisar la conversion implicita de @Doc_tasa / 100\r\n-- y posible division entera antes de cambiar formatos. No se corrige aqui.',
 '-- @Doc_tasa es VARCHAR(100): su conversion se hace explicitamente a decimal\r\n-- antes de dividir entre 100.0 para emitir fraccion de tasa con seis decimales.')
path.write_bytes(text.encode(enc))
def q(s):return "N'"+s.replace("'","''")+"'"
patch=f'''/* Aplicar solo despues del diagnostico. No ejecuta generacion ni cambia filas.
   Dos sustituciones exactas sobre la definicion INSTALADA. Respalda antes.
   Ensayo por defecto: valida patrones sin ALTER ni crear respaldo en base.
*/
USE [T3QA]; SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
DECLARE @Aplicar bit=0;
DECLARE @Def nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS'));
DECLARE @Old1 nvarchar(max)={q(old1)},@New1 nvarchar(max)={q(new1)};
DECLARE @Old2 nvarchar(max)={q(old2)},@New2 nvarchar(max)={q(new2)};
IF @@TRANCOUNT<>0 THROW 53600,'No usar transaccion externa.',1;
IF @Def IS NULL THROW 53601,'Modulo no visible o ausente.',1;
IF CHARINDEX(@New1,@Def)>0 AND CHARINDEX(@New2,@Def)>0 AND CHARINDEX(@Old1,@Def)=0 AND CHARINDEX(@Old2,@Def)=0
BEGIN SELECT 'YA CORREGIDO; no se aplicaron cambios' Resultado; RETURN; END;
IF (LEN(@Def)-LEN(REPLACE(@Def,@Old1,N'')))/LEN(@Old1)<>1
 OR (LEN(@Def)-LEN(REPLACE(@Def,@Old2,N'')))/LEN(@Old2)<>1
 THROW 53602,'La definicion instalada no coincide: revisar sin aplicar sustituciones aproximadas.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID('T3.PROC_V40_GENERAR_OTROS') AND (uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 53603,'Opciones persistidas diferentes: revisar antes de alterar.',1;
DECLARE @New nvarchar(max)=REPLACE(REPLACE(@Def,@Old1,@New1),@Old2,@New2);
DECLARE @Decl nvarchar(200)=N'PROCEDURE [T3].[PROC_V40_GENERAR_OTROS]',@Pos int;
SET @Pos=CHARINDEX(@Decl,@New);
IF @Pos=0 OR CHARINDEX(@Decl,@New,@Pos+LEN(@Decl))>0
 THROW 53604,'Declaracion del modulo diferente: revisar.',1;
SET @New=N'ALTER '+SUBSTRING(@New,@Pos,LEN(@New));
SELECT @Aplicar Aplicar,@Old1 ExpresionAnterior1,@New1 ExpresionNueva1,
 @Old2 ExpresionAnterior2,@New2 ExpresionNueva2;
IF @Aplicar=0 BEGIN SELECT 'PATRONES VALIDADOS; NO SE ALTERO EL PROCEDIMIENTO' Resultado; RETURN; END;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.REPAIR_OTROS_8115_20261029','U') IS NOT NULL
  THROW 53605,'Ya existe respaldo de modulo: no sobrescribir.',1;
 IF HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))<>HASHBYTES('SHA2_256',@Def)
  THROW 53606,'El modulo cambio durante la preparacion.',1;
 CREATE TABLE dbo.REPAIR_OTROS_8115_20261029(Captura datetime2,DefinicionAntes nvarchar(max),DefinicionDespues nvarchar(max));
 INSERT dbo.REPAIR_OTROS_8115_20261029 VALUES(SYSDATETIME(),@Def,@New);
 EXEC sys.sp_executesql @New;
 IF CHARINDEX(@New1,OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))=0
  OR CHARINDEX(@New2,OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS')))=0
  THROW 53607,'Verificacion del ALTER fallida.',1;
 UPDATE dbo.REPAIR_OTROS_8115_20261029 SET DefinicionDespues=OBJECT_DEFINITION(OBJECT_ID('T3.PROC_V40_GENERAR_OTROS'));
 COMMIT; SELECT 'CORRECCION APLICADA; NINGUNA FACTURA REPROCESADA' Resultado;
END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
'''
(HERE/'02_CORREGIR_MODULO.sql').write_text(patch,encoding='utf-8')
(HERE/'cambio.json').write_text(json.dumps({'sha256_antes':hashlib.sha256(raw).hexdigest(),'sha256_despues':hashlib.sha256(path.read_bytes()).hexdigest(),'old1':old1,'new1':new1,'old2':old2,'new2':new2},indent=2),encoding='utf-8')
print('Correccion local y script de despliegue preparados.')
