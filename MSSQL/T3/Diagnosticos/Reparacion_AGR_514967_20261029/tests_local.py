"""Prueba LocalDB aislada: preservacion de cancelacion y reparacion de relacion."""
import runpy,re,subprocess,uuid
from pathlib import Path
HERE=Path(__file__).resolve().parent;g=runpy.run_path(str(HERE/'generar.py'))
DB='CodexAGR514967_'+uuid.uuid4().hex[:8];ROOT=g['ROOT'];S=g['S']
out=ROOT/'tmp'/DB;out.mkdir(parents=True)
def sql(text,db=DB,fail=False):
 p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
 if fail:
  assert p.returncode!=0,'Se esperaba rechazo'
 elif p.returncode:raise RuntimeError(p.stdout+p.stderr)
 return p.stdout+p.stderr
def sc(name):return (HERE/name).read_text(encoding='utf-8')
passed=[]
def ok(s):passed.append(s);print('PASS',s)
created=False
try:
 sql(f'CREATE DATABASE [{DB}];','master');created=True;sql('CREATE SCHEMA T3;\nGO')
 for t in ['CFDI_COBRANZA','CFDI_AGRUPACION_CTRL','CFDI_AGRUPACION_PAGO','CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR']:
  raw=(ROOT/f'MSSQL/T3/T3/Tables/T3.{t}.Table.sql').read_bytes();ddl=raw.decode('utf-16') if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else raw.decode('utf-8-sig')
  sql(re.search(r'(?ims)^CREATE TABLE.*?^GO',ddl).group(0))
 sql("INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,FACTURA,NOTA_VENTA,STATUS) VALUES('262201996890','CHD-33522','CHD-33522','Canc Pago'); INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,STATUS) VALUES('529057','CONFIRMADO'); INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES('262201997560',REPLICATE('A',4000));")
 sql("INSERT T3.CFDI_AGRUPACION_CTRL(AGRUPACION,FECHA_PAGO,RFC,IMPORTE,FECHA_ENVIO) VALUES(514967,'20260721','GOSL721114382',20723.95,'20260722'),(514967,'20261001','GOGL7504061AA',20723.95,NULL); INSERT T3.CFDI_AGRUPACION_PAGO VALUES(514967,'20260721','262201489238'),(514967,'20261001','262201996890');")
 sql(sc('01_CAPTURAR.sql'));ok('captura')
 assert 'ENSAYO CORRECTO' in sql(sc('03_REPARAR.sql'))
 sql("IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967)<>2 THROW 53400,'Ensayo persistio cambios',1;");ok('ensayo_rollback')
 sql("UPDATE T3.CFDI_COBRANZA SET STATUS='OTRO' WHERE ASIGNACION_ID='262201996890';")
 assert 'datos protegidos' in sql(sc('03_REPARAR.sql'),fail=True)
 sql("UPDATE T3.CFDI_COBRANZA SET STATUS='Canc Pago' WHERE ASIGNACION_ID='262201996890';");ok('rechazo_cancelacion_modificada')
 sql("ALTER TABLE T3.CFDI_AGRUPACION_CTRL ADD CONSTRAINT TestFallo CHECK(IMPORTE<>4306.27);")
 sql(sc('03_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'),fail=True)
 sql("IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967)<>2 THROW 53401,'No revirtio deletes',1; ALTER TABLE T3.CFDI_AGRUPACION_CTRL DROP CONSTRAINT TestFallo;");ok('rollback_fallo_despues_delete')
 sql(sc('03_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
 v=sql(sc('04_VERIFICAR.sql'));assert v.count('IGUAL A ORIGEN HISTORICO')==2 and v.count('SIN CAMBIOS')==5
 sql("IF EXISTS(SELECT 1 FROM T3.CFDI_AGRUPACION_PAGO WHERE ASIGNACION_ID='262201996890') THROW 53402,'No retiro asociacion erronea',1; IF NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201996890' AND STATUS='Canc Pago' AND FACTURA='CHD-33522' AND FECHA_ENVIO IS NULL) THROW 53403,'Revirtio cancelacion',1;");ok('aplicacion_preserva_cancelacion_y_salidas')
 assert 'YA APLICADO' in sql(sc('03_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'));ok('no_reaplica')
 sql("UPDATE T3.CFDI_DOCUMENTOS SET STATUS='CAMBIO' WHERE NOTA_VENTA='529057';")
 assert 'datos protegidos' in sql(sc('05_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'),fail=True)
 sql("UPDATE T3.CFDI_DOCUMENTOS SET STATUS='CONFIRMADO' WHERE NOTA_VENTA='529057';");ok('reversion_rechaza_documento_modificado')
 sql(sc('05_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'))
 sql("IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967)<>2 OR (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967)<>2 THROW 53404,'No restauro baseline',1;");ok('reversion_baseline')
 (out/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
 if created:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',out)
