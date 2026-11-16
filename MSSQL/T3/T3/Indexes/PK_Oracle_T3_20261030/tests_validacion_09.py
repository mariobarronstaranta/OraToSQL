"""Prueba del validador de lotes 01-06 en LocalDB temporal."""
from pathlib import Path
import json, subprocess, uuid
HERE=Path(__file__).resolve().parent
DB='CodexValPK09_'+uuid.uuid4().hex[:8]
BASE=(HERE/'09_VALIDAR_LOTES_01_AL_06.sql').read_text(encoding='utf-8-sig').replace('USE [T3QA];',f'USE [{DB}];')
keys={k['table']:k for k in json.loads((HERE/'manifest.json').read_text())['keys']}
tables=[t for g in json.loads((HERE/'08_LOTES_PK_20261106/manifest.json').read_text())['lotes'][:6] for t in g['tablas']]
def sql(s,db=DB):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=s,encoding='utf-8',capture_output=True)
 if r.returncode:raise RuntimeError((r.stdout+r.stderr)[-2000:])
 return r.stdout
def verify(condition):
 sql(BASE.replace('-- Resultado global:',f"IF NOT ({condition}) THROW 56900,'Fallo de validacion',1;\n-- Resultado global:"))
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('CREATE SCHEMA T3;\nGO')
 verify("(SELECT COUNT(*) FROM @Resultado WHERE Resultado='TABLA_AUSENTE_O_NO_VISIBLE')=54")
 for t in tables:
  k=keys[t]
  sql(f'CREATE TABLE T3.[{t}]('+','.join(f'[{c}] int NOT NULL' for c in k['columns'])+f",CONSTRAINT [{k['name']}] PRIMARY KEY NONCLUSTERED ("+','.join(f'[{c}]' for c in k['columns'])+'));')
 verify("(SELECT COUNT(*) FROM @Resultado WHERE Resultado='OK')=54")
 sql('''DROP TABLE T3.ASIGNA_AGR_T3;
ALTER TABLE T3.ASIGNA_T3 DROP CONSTRAINT ASIGT3_PK;
CREATE UNIQUE INDEX ASIGT3_PK ON T3.ASIGNA_T3(NUM_ID);
ALTER INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA DISABLE;
ALTER TABLE T3.BITACORA_EDI DROP CONSTRAINT PK_BITACORA_EDI;
ALTER TABLE T3.BITACORA_EDI ADD CONSTRAINT PK_BITACORA_EDI PRIMARY KEY NONCLUSTERED(FECHA,DISTRIBUIDOR);
EXEC sys.sp_rename N'T3.CLACLI_PK', N'OTRO_NOMBRE_PK', N'OBJECT';''')
 verify("""(SELECT COUNT(*) FROM @Resultado WHERE Resultado='OK')=49
 AND EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='ASIGNA_AGR_T3' AND Resultado='TABLA_AUSENTE_O_NO_VISIBLE')
 AND EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='ASIGNA_T3' AND Resultado='FALTA_RESTRICCION_PK')
 AND EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='CC_PANTALLA' AND Resultado='PK_DESHABILITADA')
 AND EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='BITACORA_EDI' AND Resultado='COLUMNAS_U_ORDEN_DIFERENTES')
 AND EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='CLASE_CLIENTE' AND Resultado='OK_EQUIVALENTE_OTRO_NOMBRE')""")
 print('PASS: 54 PK correctas; ausentes; indice unico sin PK; PK deshabilitada; orden incorrecto; PK equivalente con otro nombre.')
finally:
 if made:
  sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
  print('Base temporal eliminada: '+DB)
