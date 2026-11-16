"""Reproduce error 4922 y verifica correccion atomica de IX_PG_C005."""
from pathlib import Path
import subprocess, uuid
HERE=Path(__file__).resolve().parent
DB='CodexFixPreventa_'+uuid.uuid4().hex[:8]
def sql(s,db=DB,fail=False):
 r=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],input=s,encoding='utf-8',capture_output=True)
 out=r.stdout+r.stderr
 if (r.returncode!=0)!=fail:raise RuntimeError(out[-3000:])
 return out
def script(path,apply=False):
 s=(HERE/path).read_text(encoding='utf-8-sig').replace('USE [T3QA];',f'USE [{DB}];')
 return s.replace('@Aplicar bit=0','@Aplicar bit=1') if apply else s
fix=Path('11_CORREGIR_PK_PREVENTA_GENERAL.sql')
restore_check="""IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='PREVG_PK' AND is_primary_key=0) THROW 56901,'No restauro PREVG_PK',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='IX_PG_C005' AND is_disabled=0) THROW 56902,'No restauro auxiliar',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='FACTURA' AND is_nullable=1) THROW 56903,'No restauro nullabilidad',1;"""
made=False
try:
 sql(f'CREATE DATABASE [{DB}]','master');made=True
 sql('''CREATE SCHEMA T3;
GO
CREATE TABLE T3.PREVENTA_GENERAL(FACTURA varchar(30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CLASE_FACTURA varchar(10) NULL,CLIENTE_SAP varchar(30) NULL,FECHA_FACTURA datetime NULL,
 ENTREGA varchar(30) NULL,PEDIDO varchar(30) NULL,CTRO varchar(10) NULL);
CREATE UNIQUE NONCLUSTERED INDEX PREVG_PK ON T3.PREVENTA_GENERAL(FACTURA);
CREATE NONCLUSTERED INDEX IX_PG_C005 ON T3.PREVENTA_GENERAL(CLASE_FACTURA,CLIENTE_SAP,FECHA_FACTURA,ENTREGA) INCLUDE(PEDIDO,FACTURA,CTRO);
CREATE NONCLUSTERED INDEX OTRO ON T3.PREVENTA_GENERAL(ENTREGA);
INSERT T3.PREVENTA_GENERAL VALUES('F1','C005','CLIENTE','20260101','E1','P1','C1');''')
 out=sql(script(Path('08_LOTES_PK_20261106/10_PREVENTA_GENERAL.sql'),True),fail=True)
 assert '4922' in out
 sql(restore_check)
 print('PASS reproduce 4922 con FACTURA en INCLUDE y rollback original',flush=True)
 sql(script(fix));sql(restore_check)
 sql('''CREATE TRIGGER ForzarFallo ON DATABASE FOR CREATE_INDEX AS
BEGIN
IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE name='PREVG_PK') AND
EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='IX_PG_C005')
 THROW 56904,'Fallo forzado al recrear indice auxiliar',1;
END''')
 sql(script(fix,True),fail=True)
 sql(restore_check)
 sql('DROP TRIGGER ForzarFallo ON DATABASE;')
 print('PASS vista previa y rollback completo ante fallo de recreacion',flush=True)
 # No aceptar una definicion distinta de la recibida.
 sql('ALTER INDEX IX_PG_C005 ON T3.PREVENTA_GENERAL REBUILD WITH(FILLFACTOR=80);')
 preview=script(fix).replace('IF @Aplicar=0\nBEGIN',"IF NOT EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA') THROW 56905,'No detecto opciones distintas',1;\nIF @Aplicar=0\nBEGIN")
 sql(preview)
 sql('DROP INDEX IX_PG_C005 ON T3.PREVENTA_GENERAL; CREATE NONCLUSTERED INDEX IX_PG_C005 ON T3.PREVENTA_GENERAL(CLASE_FACTURA,CLIENTE_SAP,FECHA_FACTURA,ENTREGA) INCLUDE(PEDIDO,FACTURA,CTRO);')
 sql(script(fix,True))
 sql("""IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='PREVG_PK' AND is_primary_key=1 AND is_disabled=0) THROW 56906,'PK no creada',1;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='FACTURA' AND (is_nullable=1 OR max_length<>30 OR collation_name<>'SQL_Latin1_General_CP1_CI_AS')) THROW 56907,'Columna incorrecta',1;
IF (SELECT COUNT(*) FROM sys.index_columns IC JOIN sys.indexes I ON I.object_id=IC.object_id AND I.index_id=IC.index_id WHERE I.object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND I.name='IX_PG_C005' AND IC.is_included_column=1)<>3 THROW 56908,'INCLUDE no conservado',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.PREVENTA_GENERAL') AND name='OTRO') THROW 56909,'Perdio otro indice',1;
IF (SELECT COUNT(*) FROM T3.PREVENTA_GENERAL WHERE FACTURA='F1' AND PEDIDO='P1')<>1 THROW 56910,'Cambio datos',1;""")
 # La segunda aplicacion no debe reconstruir objetos ni fallar.
 sql(script(fix,True))
 print('PASS bloqueo por opciones distintas; PK activa; NOT NULL; INCLUDE; otro indice y datos conservados; reejecucion',flush=True)
finally:
 if made:
  sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
  print('Eliminada base temporal '+DB)
