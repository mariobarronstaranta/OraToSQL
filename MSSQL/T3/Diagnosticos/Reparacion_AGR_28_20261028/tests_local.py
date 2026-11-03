"""Prueba paquete en LocalDB aislado con escenario de destino sintetico.
Usa el export recibido como origen de prueba. No conecta a Oracle/T3QA.
"""
from pathlib import Path
import runpy,subprocess,re,uuid

HERE=Path(__file__).resolve().parent
g=runpy.run_path(str(HERE/'generar.py'))
ROOT=g['ROOT'];S=g['S'];meta=g['meta'];selected=g['selected'];sec=g['sec'];loader=g['loader']
DB='CodexAGR28_'+uuid.uuid4().hex[:10]
OUT=ROOT/'tmp'/DB;OUT.mkdir(parents=True)

def sql(text,db=DB,fail=False):
    text=text.replace('USE [T3QA];',f'USE [{DB}];')
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=text,encoding='utf-8',capture_output=True)
    if fail:
        if p.returncode==0:raise AssertionError('Se esperaba rechazo')
    elif p.returncode:raise RuntimeError(p.stdout+p.stderr)
    return p.stdout+p.stderr
def script(name):return (HERE/name).read_text(encoding='utf-8')
def ins(t,rows):
    text=[]
    for row in rows:
        vals=','.join(loader.literal(row[c],typ,n) for c,typ,n in meta[t]['columns'])
        text.append(f'INSERT T3.[{t}]({g["cols"](t)}) VALUES({vals});')
    sql('\n'.join(text))
passed=[]
def ok(s):passed.append(s);print('PASS',s)
created=False
try:
    sql(f'CREATE DATABASE [{DB}];',db='master');created=True
    sql('CREATE SCHEMA T3;\nGO')
    for t in list(selected)+['CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR']:
        raw=(ROOT/f'MSSQL/T3/T3/Tables/T3.{t}.Table.sql').read_bytes()
        ddl=raw.decode('utf-16') if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else raw.decode('utf-8-sig')
        sql(re.search(r'(?ims)^CREATE TABLE.*?^GO',ddl).group(0))
    sql('CREATE SEQUENCE T3.SEQ_PAGO_CENTRAL_AGR AS decimal(10,0) START WITH 534443 INCREMENT BY 1 CACHE 20;')
    hist=[dict(r) for r in selected['CFDI_AGRUPACION_CTRL'] if int(r['AGRUPACION'])!=529099]
    fake=[]
    for r in hist:
        r['IMPORTE']=1
        f=dict(r);f['FECHA_PAGO']='2026-10-01T00:00:00';f['FECHA_ENVIO']=None;fake.append(f)
    ins('CFDI_AGRUPACION_CTRL',hist+fake)
    ins('CFDI_AGRUPACION_CTRL',[dict(r) for r in sec['CONTROLES_ORIGINALES'] if int(r['AGRUPACION']) in (514967,529057)])
    ins('CFDI_AGRUPACION_PAGO',[dict(r) for r in selected['CFDI_AGRUPACION_PAGO'] if r['ASIGNACION_ID']!='262201997114'])
    ins('CFDI_AGRUPACION_PAGO',[dict(r) for r in sec['RELACIONES_ORIGINALES'] if int(r['AGRUPACION'])==514967])
    sql("INSERT T3.CFDI_AGRUPACION_PAGO VALUES(514967,'20261001','262201996890');")
    existing=[]
    for orig in sec['COBRANZAS_ORIGINALES']:
        if orig['ASIGNACION_ID']=='262201997114':continue
        r=dict(orig)
        if r['ASIGNACION_ID']=='262201996890':
            r.update(FACTURA='CHD-33522',NOTA_VENTA='CHD-33522',STATUS='Canc Pago',FECHA_ENVIO=None)
        existing.append(r)
    ins('CFDI_COBRANZA',existing)
    sql("INSERT T3.CFDI_DOCUMENTOS(NOTA_VENTA,STATUS,FOLIO_FISCAL) VALUES('529057','CONFIRMADO','906EB9B4-BE51-11F1-B5BA-215483603023'); INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES('262201997560',REPLICATE('A',4000));")
    sql(script('01_CAPTURAR_T3QA.sql'));ok('captura_cancelacion_y_protegidos')
    sql(script('02_CARGAR_ORIGEN.sql'));ok('carga_28_controles_100_relaciones_1_cobranza')
    out=sql(script('04_REPARAR.sql'));assert 'ENSAYO CORRECTO' in out
    sql("IF EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201997114') THROW 53200,'Ensayo persistio cambios',1;")
    ok('ensayo_rollback')
    sql("UPDATE T3.CFDI_COBRANZA SET FACTURA='OTRA' WHERE ASIGNACION_ID='262201996890';")
    assert 'datos protegidos' in sql(script('04_REPARAR.sql'),fail=True)
    sql("UPDATE T3.CFDI_COBRANZA SET FACTURA='CHD-33522' WHERE ASIGNACION_ID='262201996890';")
    ok('rechaza_cambio_cancelacion')
    sql('UPDATE REPAIR_AGR28_20261028.Origen_CFDI_AGRUPACION_CTRL SET IMPORTE=2 WHERE AGRUPACION=529099;')
    assert 'Origen preparado modificado' in sql(script('04_REPARAR.sql'),fail=True)
    sql('UPDATE REPAIR_AGR28_20261028.Origen_CFDI_AGRUPACION_CTRL SET IMPORTE=6913.11 WHERE AGRUPACION=529099;')
    ok('rechaza_alteracion_staging')
    sql('ALTER TABLE T3.CFDI_AGRUPACION_CTRL ADD CONSTRAINT TestErrorTardio CHECK(AGRUPACION<>529099);')
    sql(script('04_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'),fail=True)
    sql("IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514955)<>2 THROW 53201,'No revirtio DML',1; ALTER TABLE T3.CFDI_AGRUPACION_CTRL DROP CONSTRAINT TestErrorTardio;")
    ok('rollback_error_despues_delete')
    sql(script('04_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
    out=sql(script('05_VERIFICAR.sql'))
    assert out.count('IGUAL A ORIGEN SELECCIONADO')==3 and out.count('SIN CAMBIOS')==5
    sql("IF NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201996890' AND FACTURA='CHD-33522' AND STATUS='Canc Pago' AND FECHA_ENVIO IS NULL) THROW 53202,'Cambio cancelacion',1; IF NOT EXISTS(SELECT 1 FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967 AND ASIGNACION_ID='262201996890') THROW 53203,'Cambio relacion diferida',1; IF EXISTS(SELECT 1 FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=529057 AND ASIGNACION_ID='262201996890') THROW 53204,'Creo relacion cancelada',1;")
    ok('aplicacion_con_paridad_y_cancelacion_preservada')
    assert 'YA APLICADO' in sql(script('04_REPARAR.sql').replace('@Aplicar bit=0','@Aplicar bit=1'))
    ok('no_reaplica')
    sql("UPDATE T3.CFDI_DOCUMENTOS SET STATUS='CAMBIADO' WHERE NOTA_VENTA='529057';")
    assert 'datos protegidos' in sql(script('06_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'),fail=True)
    sql("UPDATE T3.CFDI_DOCUMENTOS SET STATUS='CONFIRMADO' WHERE NOTA_VENTA='529057';")
    ok('reversion_rechaza_documento_modificado')
    sql(script('06_REVERTIR.sql').replace('@Revertir bit=0','@Revertir bit=1'))
    sql("IF EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201997114') THROW 53205,'No retiro insercion al revertir',1; IF (SELECT COUNT(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514955)<>2 THROW 53206,'No restauro duplicados',1; IF (SELECT CONVERT(bigint,current_value) FROM sys.sequences WHERE name='SEQ_PAGO_CENTRAL_AGR')<>534443 THROW 53207,'Cambio secuencia',1;")
    ok('reversion_exacta_y_secuencia_intacta')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if created:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];',db='master')
print('Evidencia:',OUT)
