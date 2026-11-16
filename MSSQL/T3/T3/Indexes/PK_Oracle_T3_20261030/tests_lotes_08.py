"""Valida aislamiento, orden y ejecucion de los 17 lotes en LocalDB.
Fixtures pequenas; no pretende medir duracion en tablas grandes.
"""
from pathlib import Path
import json
import subprocess
import uuid
import re
import hashlib
HERE=Path(__file__).resolve().parent
FOLDER=HERE/'08_LOTES_PK_20261106'
manifest=json.loads((FOLDER/'manifest.json').read_text())['lotes']
keys=json.loads((HERE/'manifest.json').read_text())['keys']
DB='CodexPKLotes_'+uuid.uuid4().hex[:8]
def sql(text,db=DB):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=text,encoding='utf-8',capture_output=True)
 if r.returncode:raise RuntimeError((r.stdout+r.stderr)[-2500:])
 return r.stdout
covered=[t for m in manifest for t in m['tablas']]
assert len(covered)==len(set(covered))==65
assert not set(covered)&{'CFDI_CATALOGOS_SAT','MOV_CLIENTE','USUARIOS'}
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('CREATE SCHEMA T3;\nGO')
 setup=[]
 for k in keys:
  t=k['table']
  # Incluso las 16 fuera de alcance existen con datos que impedirian PK.
  setup.append(f'CREATE TABLE T3.[{t}]('+','.join(f'[{c}] int NULL' for c in k['columns'])+');')
  setup.append(f'INSERT T3.[{t}] VALUES('+','.join('1' if t in covered else 'NULL' for _ in k['columns'])+');')
  if t in covered and t not in {'CREDITO_EXPRESS','FACT_T3','FACTD_AGR_T3','NOTA_T3'}:
   setup.append(f"CREATE UNIQUE INDEX [{k['name']}] ON T3.[{t}]("+','.join(f'[{c}]' for c in k['columns'])+');')
 setup.append('ALTER INDEX CLIENTE_PK ON T3.CLIENTE DISABLE;')
 sql('\n'.join(setup))
 done=[]
 for m in manifest:
  path=FOLDER/m['archivo']
  assert hashlib.sha256(path.read_bytes()).hexdigest()==m['sha256']
  s=path.read_text(encoding='utf-8-sig')
  # El inventario debe contener exclusivamente las tablas del lote.
  origin=s[s.index('INSERT @Origen'):s.index('IF @SoloTabla IS NOT NULL')]
  assert set(re.findall(r"^\(N'([^']+)'",origin,re.M))==set(m['tablas'])
  s=s.replace('USE [T3QA];',f'USE [{DB}];')
  ordered=';'.join(f"IF NOT EXISTS(SELECT 1 FROM @Plan WHERE Id={i} AND Tabla=N'{t}') THROW 56902,'Orden de lote incorrecto',1" for i,t in enumerate(m['tablas'],1))+';'
  checks=f"IF (SELECT COUNT(*) FROM @Plan)<>{len(m['tablas'])} OR EXISTS(SELECT 1 FROM @Plan WHERE Estado<>'LISTA') THROW 56901,'Scope o estado incorrecto',1;\n"+ordered
  sql(s.replace('IF @Aplicar=0\nBEGIN',checks+'\nIF @Aplicar=0\nBEGIN'))
  sql(s.replace('@Aplicar bit=0','@Aplicar bit=1'))
  done+=m['tablas']
  allowed=','.join(f"N'{t}'" for t in done)
  sql(f"IF (SELECT COUNT(*) FROM sys.key_constraints WHERE type='PK')<>{len(done)} OR EXISTS(SELECT 1 FROM sys.key_constraints WHERE type='PK' AND OBJECT_NAME(parent_object_id) NOT IN({allowed})) THROW 56903,'Cambio fuera del lote',1;")
  again="IF EXISTS(SELECT 1 FROM @Plan WHERE Estado<>'YA_EXISTE_EQUIVALENTE') THROW 56904,'Fallo reejecucion',1;"
  sql(s.replace('IF @Aplicar=0\nBEGIN',again+'\nIF @Aplicar=0\nBEGIN'))
  print('PASS '+m['archivo']+'; acumuladas '+str(len(done)),flush=True)
 sql("IF EXISTS(SELECT 1 FROM sys.columns C JOIN sys.tables T ON T.object_id=C.object_id WHERE T.schema_id=SCHEMA_ID('T3') AND T.name IN ('CFDI_CATALOGOS_SAT','MOV_CLIENTE','USUARIOS') AND C.is_nullable=0) THROW 56905,'Modifico pendientes',1;")
 print('PASS: 17 lotes, 65 PK, orden, alcance, pendientes intactas y reejecucion. Fixtures pequenas; sin prueba de rendimiento.')
finally:
 if made:
  sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
  print('Eliminada base temporal '+DB)
