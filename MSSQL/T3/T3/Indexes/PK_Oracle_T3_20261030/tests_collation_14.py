"""Simula catalogo con collation diferente sin modificar configuracion/base."""
from pathlib import Path
import subprocess
HERE=Path(__file__).resolve().parent
s=(HERE/'14_DIAGNOSTICAR_LOTES_12_AL_17.sql').read_text(encoding='utf-8-sig')
s=s.replace('USE [T3QA];','USE [master];')
# Materializa un catalogo de prueba: ambas columnas tienen collation implicita.
s=s.replace('sys.columns C','@Catalogo C')
catalog="""
DECLARE @Catalogo table(object_id int,column_id int,
name nvarchar(128) COLLATE Latin1_General_100_CI_AS_KS_WS_SC,
user_type_id int,max_length smallint,precision tinyint,scale tinyint,
collation_name nvarchar(128),is_nullable bit,is_computed bit);
INSERT @Catalogo SELECT object_id,column_id,name,user_type_id,max_length,
precision,scale,collation_name,is_nullable,is_computed FROM sys.columns;
"""
s=s.replace('SET NOCOUNT ON;','SET NOCOUNT ON;'+catalog)
# Fija solo declaraciones de tablas para que el caso sea reproducible.
s=s.replace('sysname COLLATE DATABASE_DEFAULT','sysname COLLATE SQL_Latin1_General_CP1_CI_AS')
# Las comparaciones corregidas usan SQL_Latin1 en esta simulacion de master.
s=s.replace('COLLATE DATABASE_DEFAULT','COLLATE SQL_Latin1_General_CP1_CI_AS')
old=s.replace('C.name COLLATE SQL_Latin1_General_CP1_CI_AS=O.Columna','C.name=O.Columna')
def run(text):
 return subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d','master'],input=text,encoding='utf-8',capture_output=True)
r=run(old)
assert r.returncode!=0 and '468' in r.stdout+r.stderr, (r.stdout+r.stderr)[-2000:]
r=run(s)
assert r.returncode==0,(r.stdout+r.stderr)[-2000:]
assert '01_COLUMNAS_PK' in r.stdout
print('PASS: reproduce 468 con ambas collations y ejecuta diagnostico completo corregido; solo lectura, sin cambios permanentes.')
