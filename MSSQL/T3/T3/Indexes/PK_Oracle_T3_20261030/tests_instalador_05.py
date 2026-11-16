"""Pruebas aisladas del reemplazo de indices por PK; no conecta a T3QA."""
from pathlib import Path
import subprocess
import uuid
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'ORA').is_dir())
DB='CodexPK05_'+uuid.uuid4().hex[:8]
BASE=(HERE/'05_APLICAR_PK_TABLAS_MIGRADAS.sql').read_text(encoding='utf-8-sig')
KEYS=json.loads((HERE/'manifest.json').read_text())['keys']
def sql(text,db=DB,fail=False):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=text,encoding='utf-8',capture_output=True)
 if (r.returncode!=0)!=fail: raise RuntimeError((r.stdout+r.stderr)[-2000:])
 return r.stdout+r.stderr
def script(apply=False,table=None,checks='',include=False):
 s=BASE.replace('USE [T3QA];',f'USE [{DB}];')
 if apply:s=s.replace('@Aplicar bit=0','@Aplicar bit=1')
 if table:s=s.replace('@SoloTabla sysname=NULL',f"@SoloTabla sysname=N'{table}'")
 if include:s=s.replace('@IncluirPendientes bit=0','@IncluirPendientes bit=1')
 return s.replace('IF @Aplicar=0\nBEGIN',checks+'\nIF @Aplicar=0\nBEGIN')
def check(c):return f"IF NOT ({c}) THROW 56900,'Fallo prueba',1;"
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('CREATE SCHEMA T3;\nGO\nCREATE TABLE T3.CC_PANTALLA(PANTALLA int NULL, Otra int NULL); CREATE UNIQUE INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA(PANTALLA); INSERT T3.CC_PANTALLA VALUES(1,2);')
 sql(script(checks=check("(SELECT Estado FROM @Plan WHERE Tabla='CC_PANTALLA')='LISTA' AND (SELECT COUNT(*) FROM @Plan WHERE Estado='OMITIDA_NO_VISIBLE')=80")))
 sql("IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE type='PK') THROW 56901,'Preview cambio objetos',1;")
 print('PASS preview e inexistentes',flush=True)
 sql('''CREATE TRIGGER FalloPrueba ON DATABASE FOR ALTER_TABLE AS
BEGIN
 IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE name='CC_PANTALLA_PK')
 THROW 56902,'Fallo de prueba despues de crear PK',1;
END''')
 sql(script(True,'CC_PANTALLA'),fail=True)
 sql("IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.CC_PANTALLA') AND name='CC_PANTALLA_PK' AND is_primary_key=0) THROW 56903,'No restauro indice',1; IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.CC_PANTALLA') AND name='PANTALLA' AND is_nullable=1) THROW 56904,'No restauro NULL',1; DROP TRIGGER FalloPrueba ON DATABASE;")
 print('PASS rollback indice y nullabilidad',flush=True)
 sql('DROP INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA; CREATE UNIQUE INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA(Otra);')
 sql(script(table='CC_PANTALLA',checks=check("(SELECT Estado FROM @Plan)='BLOQUEADA'")))
 sql('DROP INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA; CREATE UNIQUE INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA(PANTALLA) INCLUDE(Otra);')
 sql(script(table='CC_PANTALLA',checks=check("(SELECT Estado FROM @Plan)='BLOQUEADA'")))
 sql('DROP INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA; CREATE UNIQUE INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA(PANTALLA); CREATE TABLE T3.Hija(P int REFERENCES T3.CC_PANTALLA(PANTALLA));')
 sql(script(table='CC_PANTALLA',checks=check("(SELECT Estado FROM @Plan)='BLOQUEADA'")))
 sql('DROP TABLE T3.Hija; DROP TABLE T3.CC_PANTALLA;')
 print('PASS bloquea columnas distintas, INCLUDE y FK',flush=True)
 absent=set('ECV_DOCS_SUM_WEEK ECV_DOCS_SUM_WEEK_NEW FACT_AGR_T3 FACTC_AGR_T3 FACTC_T3 NOTAC_AGR_T3 NOTAC_T3 PED_T3 PEDC_T3 RMA_T3 RMAC_T3 RMAD_T3 VAN_T3'.split())
 noindex=set('CREDITO_EXPRESS FACT_T3 FACTD_AGR_T3 NOTA_T3 MOV_CLIENTE'.split())
 real=0
 for k in KEYS:
  t=k['table']
  if t in absent:continue
  path=ROOT/f'MSSQL/T3/T3/Tables/T3.{t}.Table.sql'
  if path.exists():
   raw=path.read_bytes();txt=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')
   start=txt.index(f'CREATE TABLE [T3].[{t}]');end=re.search(r'^\s*GO\s*$',txt[start:],re.M|re.I)
   sql(txt[start:start+end.start()]);real+=1
  else:sql(f'CREATE TABLE T3.[{t}]('+','.join(f'[{c}] varchar(20) NULL' for c in k['columns'])+');')
  if t not in noindex:sql(f"CREATE UNIQUE INDEX [{k['name']}] ON T3.[{t}]("+','.join(f'[{c}]' for c in k['columns'])+');')
 sql('ALTER INDEX CLIENTE_PK ON T3.CLIENTE DISABLE; ALTER INDEX USUARIO_PK ON T3.USUARIOS DISABLE; INSERT T3.CFDI_CATALOGOS_SAT(ID) VALUES(NULL); INSERT T3.MOV_CLIENTE(CLIENTE_V3) VALUES(1),(1); INSERT T3.USUARIOS(USUARIO) VALUES(1),(1);')
 sql(script(checks=check("(SELECT COUNT(*) FROM @Plan WHERE Estado='LISTA')=65 AND (SELECT COUNT(*) FROM @Plan WHERE Estado='PENDIENTE_DATOS')=3 AND (SELECT COUNT(*) FROM @Plan WHERE Estado='OMITIDA_NO_VISIBLE')=13")))
 sql(script(include=True,checks=check("(SELECT COUNT(*) FROM @Plan WHERE Estado='BLOQUEADA')=3")))
 sql(script(True))
 sql("IF (SELECT COUNT(*) FROM sys.key_constraints WHERE type='PK')<>65 THROW 56905,'Conteo final distinto',1; IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.CLIENTE') AND name='CLIENTE_PK' AND is_primary_key=1 AND is_disabled=0) THROW 56906,'CLIENTE no activo',1;")
 sql(script(checks=check("(SELECT COUNT(*) FROM @Plan WHERE Estado='YA_EXISTE_EQUIVALENTE')=65")))
 print(f'PASS 65 PK, 13 ausentes, 3 pendientes, revalidacion de datos, CLIENTE activo y reejecucion; {real} DDL reales y {68-real} tablas ficticias.',flush=True)
finally:
 if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master');print('Base temporal eliminada: '+DB)
