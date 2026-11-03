"""Pruebas aisladas de aritmetica y parche de definicion; no accede a T3QA."""
from pathlib import Path
import json,subprocess,uuid
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
c=json.loads((HERE/'cambio.json').read_text());DB='CodexOT8115_'+uuid.uuid4().hex[:8]
out=ROOT/'tmp'/DB;out.mkdir(parents=True)
def sql(text,db=DB,fail=False):
 p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
 if fail:assert p.returncode!=0,'Se esperaba error'
 elif p.returncode:raise RuntimeError(p.stdout+p.stderr)
 return p.stdout+p.stderr
def sc(n):return (HERE/n).read_text(encoding='utf-8')
passed=[]
def ok(s):passed.append(s);print('PASS',s)
made=False
try:
 sql(f'CREATE DATABASE [{DB}];','master');made=True;sql('CREATE SCHEMA T3;\nGO')
 sql('''SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION T3.FN_NUM_TO_CHAR_CFDI(@N decimal(38,12),@D int) RETURNS varchar(100)
AS BEGIN RETURN CONVERT(varchar(100),@N); END;
GO
''')
 fixture=f'''SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [T3].[PROC_V40_GENERAR_OTROS] @pFactura varchar(max)
AS BEGIN
 DECLARE @Doc_tasa varchar(100);
 SELECT @Doc_tasa={c['old1']}
 FROM (SELECT CONVERT(decimal(22,7),100) Valor_Subt,CONVERT(decimal(22,7),16) Valor_IVA) Doc
 LEFT JOIN (SELECT CONVERT(decimal(38,7),0) Retenido) Ret ON 1=1;
 SELECT {c['old2']} Tasa;
END;
GO
'''
 sql(fixture)
 err=sql("EXEC T3.PROC_V40_GENERAR_OTROS 'FICTICIA';",fail=True)
 assert '8115' in err;ok('reproduce_8115_con_tasa_16')
 assert 'PATRONES VALIDADOS' in sql(sc('02_CORREGIR_MODULO.sql'));ok('ensayo_parche_sin_alter')
 sql(sc('02_CORREGIR_MODULO.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
 sql("DECLARE @R table(Tasa varchar(100)); INSERT @R EXEC T3.PROC_V40_GENERAR_OTROS 'FICTICIA'; IF NOT EXISTS(SELECT 1 FROM @R WHERE CONVERT(decimal(38,12),Tasa)=0.16) THROW 53700,'Tasa incorrecta',1;")
 ok('parche_emite_0_16_sin_division_entera')
 assert 'YA CORREGIDO' in sql(sc('02_CORREGIR_MODULO.sql').replace('@Aplicar bit=0','@Aplicar bit=1'));ok('parche_no_reaplica')
 sql('''DECLARE @Sub decimal(22,7)=100,@IVA decimal(22,7)=16,@Ret decimal(38,7)=0;
IF TRY_CONVERT(varchar(10),ROUND(ISNULL(@IVA,0)*100/NULLIF(ISNULL(@Ret,0)+ISNULL(@Sub,0),0),0)) IS NOT NULL
 THROW 53701,'La prueba original no expone overflow',1;
IF CONVERT(decimal(38,12),CONVERT(varchar(40),ROUND(ISNULL(@IVA,0)*100/NULLIF(ISNULL(@Ret,0)+ISNULL(@Sub,0),0),0)))/100.0<>0.16
 THROW 53702,'Fraccion incorrecta',1;
DECLARE @Cases table(Tasa decimal(38,12)); INSERT @Cases VALUES(0),(16),(100),(-16),(12345678901234567890123456.000000000000),(NULL);
IF EXISTS(SELECT 1 FROM @Cases WHERE Tasa IS NOT NULL AND TRY_CONVERT(varchar(40),Tasa) IS NULL)
 THROW 53703,'La longitud 40 no admite el rango',1;
IF EXISTS(SELECT 1 FROM @Cases WHERE Tasa IS NOT NULL AND CONVERT(decimal(38,12),CONVERT(varchar(40),Tasa))<>Tasa)
 THROW 53704,'Conversion perdio valor',1;
''');ok('rango_signo_cero_null_y_precision')
 sql(sc('04_REVERTIR_MODULO.sql').replace('@Revertir bit=0','@Revertir bit=1'))
 assert '8115' in sql("EXEC T3.PROC_V40_GENERAR_OTROS 'FICTICIA';",fail=True);ok('reversion_definicion_original')
 (out/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
 if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',out)
