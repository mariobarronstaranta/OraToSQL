"""Pruebas LocalDB con datos SINTETICOS. Nunca usa T3QA ni Oracle."""
from pathlib import Path
import importlib.util, json, subprocess, uuid, re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
spec=importlib.util.spec_from_file_location('loader',HERE/'03_preparar_carga.py')
loader=importlib.util.module_from_spec(spec); spec.loader.exec_module(loader)
schema=json.loads((HERE/'schema.json').read_text())
DB='CodexRepairAGR_'+uuid.uuid4().hex[:10]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
data={}
for table,m in schema.items(): data[table]=[]
def row(table,**values):
    r={c:None for c,_,_ in schema[table]['columns']}; r.update(values); return r
for a,(f,g,c,amt) in loader.MAP.items():
    data['CFDI_COBRANZA'].append(row('CFDI_COBRANZA',ASIGNACION_ID=a,FOLIO_ID=a,
      FACTURA=f,NOTA_VENTA=f,CLIENTE_SAP=c,IMPORTE=float(amt),SALDO_ANTERIOR=float(amt),
      FECHA_ENVIO='2026-10-02T12:34:56',UUID_VENTA='12345678-1234-1234-1234-123456789012'))
    data['CFDI_AGRUPACION_CTRL'].append(row('CFDI_AGRUPACION_CTRL',AGRUPACION=g,
      ACCNT_ID='Contado',CLIENTE_SAP=c,IMPORTE=float(amt),FECHA_PAGO='2026-10-01T00:00:00'))
    data['CFDI_AGRUPACION_PAGO'].append(row('CFDI_AGRUPACION_PAGO',AGRUPACION=g,ASIGNACION_ID=a,FECHA_PAGO='2026-10-01T00:00:00'))
    data['REGISTRO_FISCAL'].append(row('REGISTRO_FISCAL',FACTURA=f,CLIENTE_SAP=c))
    count={'V0179-67553':8,'V0225-134949':8,'V0440-70133':6,'V0822-105802':4}[f]
    for i in range(count): data['REGISTRO_FISCAL_DETALLE'].append(row('REGISTRO_FISCAL_DETALLE',FACTURA=f,NUM_LINEA=i+1,VALOR_SUBT=100.25))
for g,a in loader.OLD.items():
    data['CFDI_AGRUPACION_CTRL'].append(row('CFDI_AGRUPACION_CTRL',AGRUPACION=g,
      FECHA_PAGO='2026-07-21T00:00:00',FECHA_ENVIO=None if g==514957 else '2026-07-22T05:08:16'))
    data['CFDI_AGRUPACION_PAGO'].append(row('CFDI_AGRUPACION_PAGO',AGRUPACION=g,ASIGNACION_ID=a,FECHA_PAGO='2026-07-21T00:00:00'))
for table,rows in data.items(): (OUT/(table+'.json')).write_text(json.dumps(rows),encoding='utf-8')
(OUT/'metadata.json').write_text(json.dumps({'MAX_CONTROL':534442,'MAX_DETALLE':534442,'CAPTURA':'2026-10-28T22:00:00'}))
loader.generate(OUT,OUT/'source.sql')

# Fail closed on old exports without time and incomplete detail.
original=data['CFDI_COBRANZA'][0]['FECHA_ENVIO']
data['CFDI_COBRANZA'][0]['FECHA_ENVIO']='02-OCT-26'
(OUT/'CFDI_COBRANZA.json').write_text(json.dumps(data['CFDI_COBRANZA']))
try:
    loader.generate(OUT,OUT/'invalid.sql'); raise AssertionError('Fecha ambigua aceptada')
except ValueError: print('PASS rechazo_fecha_sin_hora')
data['CFDI_COBRANZA'][0]['FECHA_ENVIO']=original
(OUT/'CFDI_COBRANZA.json').write_text(json.dumps(data['CFDI_COBRANZA']))
print('PASS validacion_origen')

def sql(text,db=DB,fail=False):
    # Only replace the deployment USE, never connect to the remote server.
    text=text.replace('USE [T3QA];',f'USE [{DB}];')
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
                     input=text,encoding='utf-8',capture_output=True)
    if fail:
        if p.returncode==0: raise AssertionError('Se esperaba fallo')
    elif p.returncode:
        raise RuntimeError(p.stdout+p.stderr)
    return p.stdout+p.stderr
def script(name): return (HERE/name).read_text(encoding='utf-8')
created=False
passed=[]
def ok(name): passed.append(name); print('PASS',name)
try:
    sql(f'CREATE DATABASE [{DB}];',db='master'); created=True
    sql('CREATE SCHEMA T3;\nGO')
    for table in list(schema)+['CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR']:
        raw=(ROOT/f'MSSQL/T3/T3/Tables/T3.{table}.Table.sql').read_bytes()
        text=raw.decode('utf-16') if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else raw.decode('utf-8-sig')
        match=re.search(r'(?ims)^CREATE TABLE.*?^GO',text)
        sql(match.group(0))
    sql('CREATE SEQUENCE T3.SEQ_PAGO_CENTRAL_AGR AS decimal(10,0) START WITH 520658 INCREMENT BY 1 MAXVALUE 1000000000 CYCLE CACHE 20;')
    # Initial target deliberately wrong; also a row outside scope to preserve.
    for a,(f,g,c,amt) in loader.MAP.items():
        sql(f"INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,FACTURA,IMPORTE,STATUS) VALUES('{a}','{f}',{amt},'INCOBRABLE');")
    sql("INSERT T3.CFDI_COBRANZA(ASIGNACION_ID,FACTURA,STATUS) VALUES('FUERA','NO_TOCAR','ORIGINAL');")
    sql("INSERT T3.CFDI_AGRUPACION_CTRL(AGRUPACION,ACCNT_ID) VALUES(514957,'LEGITIMO'),(514957,'INCORRECTO'); INSERT T3.CFDI_AGRUPACION_PAGO(AGRUPACION,ASIGNACION_ID) VALUES(514957,'262201997234');")
    sql(script('02_MSSQL_CAPTURAR.sql')); ok('captura')
    sql((OUT/'source.sql').read_text()); ok('carga_staging')
    output=sql(script('04_MSSQL_REPARAR.sql'))
    assert 'ENSAYO CORRECTO' in output
    sql("IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA WHERE STATUS='INCOBRABLE')<>4 THROW 53001,'Ensayo modifico negocio',1;")
    ok('ensayo_rollback')
    sql("UPDATE T3.CFDI_COBRANZA SET IMPORTE=1 WHERE ASIGNACION_ID='262201997234';")
    assert 'Destino cambio' in sql(script('04_MSSQL_REPARAR.sql'),fail=True)
    sql("UPDATE T3.CFDI_COBRANZA SET IMPORTE=8138.65 WHERE ASIGNACION_ID='262201997234';")
    ok('rechazo_destino_modificado')
    sql('UPDATE REPAIR_AGR_20261028.Estado SET MaxOrigen=1000000000;')
    assert 'Rango agotado' in sql(script('04_MSSQL_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'),fail=True)
    sql("IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA WHERE STATUS='INCOBRABLE')<>4 THROW 53002,'No revirtio fallo tardio',1; UPDATE REPAIR_AGR_20261028.Estado SET MaxOrigen=534442;")
    ok('rollback_error_despues_DML')
    sql(script('04_MSSQL_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
    result=sql(script('05_MSSQL_VERIFICAR.sql'))
    assert 'DIFERENCIAS' not in result and result.count('IGUAL A ORIGEN')==5
    sql("IF NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='FUERA' AND STATUS='ORIGINAL') THROW 53003,'Cambio fuera de alcance',1;")
    ok('aplicacion_y_paridad_cinco_tablas')
    assert 'YA APLICADO' in sql(script('04_MSSQL_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
    ok('no_reaplica')
    sql("UPDATE T3.CFDI_COBRANZA SET IMPORTE=1 WHERE ASIGNACION_ID='262201997234';")
    assert 'cambios posteriores' in sql(script('06_MSSQL_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'),fail=True)
    sql("UPDATE T3.CFDI_COBRANZA SET IMPORTE=8138.65 WHERE ASIGNACION_ID='262201997234';")
    ok('reversion_rechaza_cambios_posteriores')
    sql(script('06_MSSQL_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'))
    sql("IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA WHERE STATUS='INCOBRABLE')<>4 THROW 53004,'Reversion incompleta',1; IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514957)<>2 THROW 53005,'No restauro duplicados de baseline',1;")
    ok('reversion_preserva_baseline')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if created:
        sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];',db='master')
print('Evidencia local:',OUT)
