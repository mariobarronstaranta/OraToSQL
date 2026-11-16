"""Seis DDL reales, indices de la captura, datos minimos y rollback forzado."""
from pathlib import Path
import json,re,subprocess,uuid
HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'ORA').is_dir())
OUT=HERE/'15_CORRECCIONES_LOTES_12_AL_17'
data=json.loads((OUT/'plan.json').read_text())
keys={k['table']:k for k in json.loads((HERE/'manifest.json').read_text())['keys']}
DB='CodexFix6PK_'+uuid.uuid4().hex[:8]
def sql(s,db=DB,fail=False):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-y','0','-d',db],input=s,encoding='utf-8',capture_output=True)
 o=r.stdout+r.stderr
 if (r.returncode!=0)!=fail:raise RuntimeError(o[-3000:])
 return o
def cols(cs):return ','.join('['+c+']' for c in cs)
def signature(t,pk):
 return sql(f"""SET NOCOUNT ON;
SELECT I.name,I.type,I.is_unique,I.is_disabled,I.has_filter,I.filter_definition,I.fill_factor,I.is_padded,I.ignore_dup_key,I.allow_row_locks,I.allow_page_locks,
 (SELECT C.name,IC.key_ordinal,IC.is_included_column,IC.is_descending_key FROM sys.index_columns IC JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id ORDER BY IC.index_column_id FOR XML PATH('Col'),TYPE)
FROM sys.indexes I WHERE I.object_id=OBJECT_ID('T3.{t}') AND I.index_id>0 AND I.name<>'{pk}' ORDER BY I.name FOR XML PATH('Indice'),TYPE;""")
def script(t,apply=False,checks=''):
 s=(OUT/f"{data[t]['lote']:02d}_{t}_CORREGIDO.sql").read_text(encoding='utf-8-sig').replace('USE [T3QA];',f'USE [{DB}];')
 if apply:s=s.replace('@Aplicar bit=0','@Aplicar bit=1')
 return s.replace('IF @Aplicar=0\nBEGIN',checks+'\nIF @Aplicar=0\nBEGIN')
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('CREATE SCHEMA T3;\nGO')
 before={}
 for t,d in data.items():
  path=ROOT/f'MSSQL/T3/T3/Tables/T3.{t}.Table.sql'
  if path.exists():
   raw=path.read_bytes()
   txt=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')
   a=txt.index(f'CREATE TABLE [T3].[{t}]');b=re.search(r'^\s*GO\s*$',txt[a:],re.M|re.I)
   sql(txt[a:a+b.start()])
  else:
   assert t=='FACTURA_GENERAL'
   cs=sorted({c for i in d['indices'].values() for c in i['keys']+i['include']})
   sql(f'CREATE TABLE T3.[{t}]('+','.join('['+c+'] '+('datetime2(0)' if c.startswith('FECHA') else 'varchar(30)')+' NULL' for c in cs)+');')
  k=keys[t]
  values=["'20260101'" if c.startswith('FECHA') else '1' if c=='NUM_LINEA' else "'K1'" for c in k['columns']]
  sql(f"INSERT T3.[{t}]({cols(k['columns'])}) VALUES("+','.join(values)+');')
  for i in sorted(d['indices'].values(),key=lambda i:i['type']!='CLUSTERED'):
   ddl=f"CREATE {'UNIQUE ' if i['unique'] else ''}{i['type']} INDEX [{i['name']}] ON T3.[{t}]({cols(i['keys'])})"
   if i['include']:ddl+=' INCLUDE('+cols(i['include'])+')'
   if i['filter']:ddl+=' WHERE '+i['filter']
   sql(ddl+';')
   if i['disabled']:sql(f"ALTER INDEX [{i['name']}] ON T3.[{t}] DISABLE;")
  before[t]=signature(t,k['name'])
  assert before[t].count('<Indice>')==len(d['indices'])-1, 'Firma incompleta: '+t
  sql(script(t,checks="IF (SELECT COUNT(*) FROM @Plan WHERE Estado='LISTA')<>1 THROW 56900,'Preview no lista',1;"))
  print('PASS preview '+t,flush=True)
 t='ASIGNACION_PAGO';k=keys[t]
 sql('CREATE INDEX NUEVO ON T3.ASIGNACION_PAGO(FACTURA);')
 sql(script(t,checks="IF NOT EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA') THROW 56901,'No bloqueo nuevo indice',1;"))
 sql('DROP INDEX NUEVO ON T3.ASIGNACION_PAGO;')
 last=data[t]['auxiliares'][-1]
 sql(f"""CREATE TRIGGER FallaFinal ON DATABASE FOR CREATE_INDEX AS
BEGIN IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE name='ASPAGO_PK')
 AND EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.ASIGNACION_PAGO') AND name='{last}')
 THROW 56902,'Fallo intencional al recrear ultimo auxiliar',1; END""")
 sql(script(t,True),fail=True)
 assert signature(t,k['name'])==before[t]
 sql("IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('T3.ASIGNACION_PAGO') AND name IN('PAGO_ID','ASIGNACION_ID','FECHA_TRN','FACTURA') AND is_nullable=1)<>4 THROW 56903,'No restauro nullabilidad',1; IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.ASIGNACION_PAGO') AND name='ASPAGO_PK' AND is_primary_key=0) THROW 56904,'No restauro indice original',1; DROP TRIGGER FallaFinal ON DATABASE;")
 print('PASS guardia nuevo indice y rollback completo al fallar ultimo auxiliar',flush=True)
 for t,d in data.items():
  sql(script(t,True))
  assert signature(t,keys[t]['name'])==before[t],t+' indices diferentes'
  names=','.join("N'"+c+"'" for c in keys[t]['columns'])
  sql(f"IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.{t}') AND name IN({names}) AND is_nullable=1) THROW 56905,'Quedo nullable',1; IF NOT EXISTS(SELECT 1 FROM sys.key_constraints K JOIN sys.indexes I ON I.object_id=K.parent_object_id AND I.index_id=K.unique_index_id WHERE K.parent_object_id=OBJECT_ID('T3.{t}') AND K.type='PK' AND I.is_disabled=0) THROW 56906,'PK no activa',1; IF (SELECT COUNT(*) FROM T3.[{t}])<>1 THROW 56907,'Cambio datos',1;")
  sql(script(t,True))
  print('PASS aplica/repite '+t+'; indices, filtros, INCLUDE y estados conservados',flush=True)
 print('PASS cinco DDL reales y fixture de FACTURA_GENERAL sin DDL local; no es benchmark de volumen.',flush=True)
finally:
 if made:
  sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
  print('Eliminada '+DB)
