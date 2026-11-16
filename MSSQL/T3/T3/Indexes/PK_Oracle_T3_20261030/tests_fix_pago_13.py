"""Reproduce 4922 de FECHA_TRN; prueba la correccion y rollback completo."""
from pathlib import Path
import subprocess,uuid
HERE=Path(__file__).resolve().parent
DB='CodexFixPago_'+uuid.uuid4().hex[:8]
def sql(s,db=DB,fail=False):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=s,encoding='utf-8',capture_output=True)
 out=r.stdout+r.stderr
 if (r.returncode!=0)!=fail:raise RuntimeError(out[-3000:])
 return out
def script(name='13_CORREGIR_PK_PAGO.sql',apply=False):
 s=(HERE/name).read_text(encoding='utf-8-sig').replace('USE [T3QA];',f'USE [{DB}];')
 return s.replace('@Aplicar bit=0','@Aplicar bit=1') if apply else s
restore="""IF (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('T3.PAGO') AND name IN('PAGO_ID','FECHA_TRN') AND is_nullable=1)<>2 THROW 56901,'No restauro ambas columnas',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PAGO') AND name IN('PAGO_PK','PAGO_IDX_1') AND is_primary_key=0 AND is_disabled=0)<>2 THROW 56902,'No restauro ambos indices',1;"""
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('''CREATE SCHEMA T3;
GO
CREATE TABLE T3.PAGO(PAGO_ID varchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
FECHA_TRN datetime2(0) NULL,REP_ID int NULL,DISTRIBUIDOR int NULL,FECHA_PROC_BATMD datetime2(0) NULL);
CREATE UNIQUE NONCLUSTERED INDEX PAGO_PK ON T3.PAGO(PAGO_ID,FECHA_TRN);
CREATE NONCLUSTERED INDEX PAGO_IDX_1 ON T3.PAGO(FECHA_TRN);
CREATE NONCLUSTERED INDEX REP_P ON T3.PAGO(REP_ID);
CREATE NONCLUSTERED INDEX PK_PAGO_FECHA_PROC ON T3.PAGO(DISTRIBUIDOR,FECHA_PROC_BATMD);
INSERT T3.PAGO VALUES('P1','20260101',1,1,NULL),('P1','20260102',1,1,NULL);''')
 out=sql(script('08_LOTES_PK_20261106/11_PAGO.sql',True),fail=True)
 assert '4922' in out and 'FECHA_TRN' in out
 sql(restore)
 print('PASS reproduce error original y rollback de PAGO_ID/FECHA_TRN e indices',flush=True)
 sql(script());sql(restore)
 sql('''CREATE TRIGGER ForzarFallo ON DATABASE FOR CREATE_INDEX AS
BEGIN
IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE name='PAGO_PK') AND
EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PAGO') AND name='PAGO_IDX_1')
THROW 56903,'Fallo forzado en recreacion auxiliar',1;
END''')
 sql(script(apply=True),fail=True);sql(restore)
 sql('DROP TRIGGER ForzarFallo ON DATABASE;')
 print('PASS preview y rollback si falla recreacion de PAGO_IDX_1',flush=True)
 sql('ALTER INDEX PAGO_IDX_1 ON T3.PAGO REBUILD WITH(FILLFACTOR=80);')
 sql(script().replace('IF @Aplicar=0\nBEGIN',"IF NOT EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA') THROW 56904,'No bloqueo opciones distintas',1;\nIF @Aplicar=0\nBEGIN"))
 sql('DROP INDEX PAGO_IDX_1 ON T3.PAGO; CREATE NONCLUSTERED INDEX PAGO_IDX_1 ON T3.PAGO(FECHA_TRN);')
 sql(script(apply=True))
 sql("""IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PAGO') AND name='PAGO_PK' AND is_primary_key=1 AND is_disabled=0) THROW 56905,'PK no creada',1;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.PAGO') AND name IN('PAGO_ID','FECHA_TRN') AND is_nullable=1) THROW 56906,'Quedo nullable',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.PAGO') AND name='FECHA_TRN' AND TYPE_NAME(system_type_id)='datetime2' AND scale=0) THROW 56907,'Cambio tipo fecha',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.PAGO') AND name='PAGO_ID' AND max_length=50 AND collation_name='SQL_Latin1_General_CP1_CI_AS') THROW 56908,'Cambio tipo pago',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes I JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id WHERE I.object_id=OBJECT_ID('T3.PAGO') AND I.name='PAGO_IDX_1' AND I.is_disabled=0 AND I.is_unique=0 AND IC.key_ordinal=1 AND COL_NAME(IC.object_id,IC.column_id)='FECHA_TRN') THROW 56909,'Auxiliar no restaurado',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PAGO') AND name IN('REP_P','PK_PAGO_FECHA_PROC'))<>2 THROW 56910,'Perdio otro indice',1;
IF (SELECT COUNT(*) FROM T3.PAGO WHERE PAGO_ID='P1')<>2 THROW 56911,'Modifico datos',1;""")
 sql(script(apply=True))
 print('PASS opciones distintas bloqueadas; PK compuesta activa; tipos/NOT NULL; auxiliares y datos conservados; reejecucion',flush=True)
finally:
 if made:
  sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
  print('Eliminada base temporal '+DB)
