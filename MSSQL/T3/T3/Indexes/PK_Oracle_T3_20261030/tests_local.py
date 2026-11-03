"""Pruebas aisladas: 65 DDL locales y 16 tablas ficticias para PK sin DDL local."""
from pathlib import Path
import json
import re
import subprocess
import uuid

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'ORA').is_dir() and (p/'MSSQL').is_dir())
MANIFEST=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
KEYS=MANIFEST['keys']
DB='CodexPKT3_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
BASE=(HERE/'01_CREAR_PK_T3.sql').read_text(encoding='utf-8-sig')
passed=[]

def sql(text,db=DB,fail=False):
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
                     input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    output=p.stdout+p.stderr
    if fail:
        assert p.returncode!=0,'Se esperaba error'
    elif p.returncode:
        (OUT/'FALLO.txt').write_text(output,encoding='utf-8')
        raise RuntimeError(output[-16000:])
    return output

def script(apply=False,table=None,checks=None,convert=True):
    value=BASE
    if apply:value=value.replace('@Aplicar bit=0','@Aplicar bit=1')
    if table:value=value.replace('@SoloTabla sysname=NULL',f"@SoloTabla sysname=N'{table}'")
    if not convert:value=value.replace('@ConvertirColumnasANotNull bit=1','@ConvertirColumnasANotNull bit=0')
    if checks:value=value.replace("IF @Aplicar=0\nBEGIN",checks+"\nIF @Aplicar=0\nBEGIN",1)
    return value

def check_plan(condition,message):
    return f"IF NOT ({condition}) THROW 56901,'{message}',1;"

def ok(message):
    passed.append(message)
    print('PASS',message,flush=True)

def create_real(key):
    path=ROOT/f"MSSQL/T3/T3/Tables/T3.{key['table']}.Table.sql"
    if not path.exists():return False
    raw=path.read_bytes()
    text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    start=text.index(f"CREATE TABLE [T3].[{key['table']}]")
    end=re.search(r'^\s*GO\s*$',text[start:],re.M|re.I)
    assert end
    sql(text[start:start+end.start()])
    return True

made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master');made=True
    sql('CREATE SCHEMA T3;\nGO')
    missing=[]
    for key in KEYS:
        if not create_real(key):missing.append(key)
    checks="SELECT Tabla,Estado,Observacion FROM @Plan WHERE Estado='BLOQUEADA';"+check_plan("(SELECT COUNT(*) FROM @Plan)=81 AND (SELECT COUNT(*) FROM @Plan WHERE Estado='BLOQUEADA')=16",'No detecto 16 DDL ausentes')
    result=sql(script(checks=checks))
    assert 'VISTA PREVIA' in result
    sql("IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE schema_id=SCHEMA_ID('T3')) THROW 56902,'Preview creo restricciones',1;")
    ok('previsualizacion_sin_ddl_detecta_16_tablas_ausentes')
    sql('CREATE TYPE dbo.TestKey FROM varchar(30) NULL;')
    for key in missing:
        cols=[]
        for i,c in enumerate(key['columns']):
            typ='varchar(40)'
            if key['table']=='FACTC_T3':
                typ=['dbo.TestKey','decimal(18,6)','nvarchar(10) COLLATE Latin1_General_100_CS_AS'][i]
            cols.append(f'[{c}] {typ} NULL')
        sql(f"CREATE TABLE T3.[{key['table']}] ("+','.join(cols)+');')
    ok('crea_65_ddl_reales_y_16_fixtures_sin_inferir_tipos_de_oracle')
    sql("INSERT T3.MATERIAL(MATERIAL) VALUES('DUP'),('DUP'); INSERT T3.ASIGNA_T3(NUM_ID) VALUES(NULL);")
    checks=check_plan("(SELECT COUNT(*) FROM @Plan WHERE Estado='BLOQUEADA')=2 AND EXISTS(SELECT 1 FROM @Plan WHERE Tabla='MATERIAL' AND GruposDuplicados=1) AND EXISTS(SELECT 1 FROM @Plan WHERE Tabla='ASIGNA_T3' AND FilasConNull=1)",'No encontro duplicados y NULL')
    sql(script(checks=checks))
    result=sql(script(apply=True),fail=True)
    assert '56830' in result,result[-3000:]
    sql("IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE type='PK' AND schema_id=SCHEMA_ID('T3')) THROW 56903,'Aplico parcialmente a pesar de bloqueo previo',1; DELETE T3.MATERIAL; DELETE T3.ASIGNA_T3;")
    ok('detecta_null_y_duplicados_y_bloquea_aplicacion_global')
    sql("ALTER TABLE T3.MATERIAL ALTER COLUMN MATERIAL varchar(20) COLLATE Latin1_General_100_CI_AS NULL; INSERT T3.MATERIAL(MATERIAL) VALUES('ABC'),('abc');")
    sql(script(table='MATERIAL',checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE GruposDuplicados=1 AND Estado='BLOQUEADA')",'No uso collation destino')))
    sql('DELETE T3.MATERIAL;')
    ok('duplicados_respetan_collation_real_de_sql_server')
    sql(script(table='MATERIAL',convert=False,checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA' AND Observacion LIKE '56822:%')",'No respeto opcion de nullabilidad')))
    ok('no_convierte_nullable_si_opcion_deshabilitada')
    sql('ALTER TABLE T3.ECV_DOCS_SUM_WEEK DROP COLUMN WEEK_ID;')
    sql(script(table='ECV_DOCS_SUM_WEEK',checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA' AND Observacion LIKE '56811:%')",'No detecto columna ausente')))
    sql('ALTER TABLE T3.ECV_DOCS_SUM_WEEK ADD WEEK_ID varchar(40) NULL;')
    ok('detecta_columna_ausente')
    sql('ALTER TABLE T3.CC_PANTALLA ADD OtraClave int NOT NULL CONSTRAINT DF_TEST_OTHER DEFAULT 1; ALTER TABLE T3.CC_PANTALLA ADD CONSTRAINT TEST_PK_DIFERENTE PRIMARY KEY(OtraClave);')
    sql(script(table='CC_PANTALLA',checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA' AND Observacion LIKE '56812:%')",'No detecto otra PK')))
    sql('ALTER TABLE T3.CC_PANTALLA DROP CONSTRAINT TEST_PK_DIFERENTE; ALTER TABLE T3.CC_PANTALLA DROP CONSTRAINT DF_TEST_OTHER; ALTER TABLE T3.CC_PANTALLA DROP COLUMN OtraClave;')
    ok('no_reemplaza_pk_existente_diferente')
    sql('CREATE TABLE T3.BIT_PROC_PK(X int NULL);')
    sql(script(table='BITACORA_PROCESO',checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE Estado='BLOQUEADA' AND Observacion LIKE '56817:%')",'No detecto nombre ocupado')))
    sql('DROP TABLE T3.BIT_PROC_PK;')
    ok('detecta_nombre_de_restriccion_ocupado')
    # Preparar una PK equivalente con otro nombre y un clustered ajeno.
    sql(script(apply=True,table='PAGO'))
    sql("EXEC sys.sp_rename N'T3.PAGO_PK',N'TEST_EQUIVALENTE_PAGO',N'OBJECT'; ALTER TABLE T3.MATERIAL ALTER COLUMN MATERIAL varchar(20) COLLATE Latin1_General_100_CI_AS NOT NULL; CREATE CLUSTERED INDEX TEST_CI_MATERIAL ON T3.MATERIAL(MATERIAL);")
    sql(script(table='PAGO',checks=check_plan("EXISTS(SELECT 1 FROM @Plan WHERE Estado='YA_EXISTE_EQUIVALENTE')",'No reconocio PK equivalente')))
    ok('reconoce_pk_equivalente_con_otro_nombre')
    sql('''SELECT C.object_id,C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name
INTO dbo.TestBaselineColumnas FROM sys.columns C JOIN sys.tables T ON T.object_id=C.object_id WHERE T.schema_id=SCHEMA_ID('T3');''')
    checks=check_plan("(SELECT COUNT(*) FROM @Plan WHERE Estado='LISTA')=80 AND (SELECT COUNT(*) FROM @Plan WHERE Estado='YA_EXISTE_EQUIVALENTE')=1",'Prevalidacion global inesperada')
    result=sql(script(apply=True,checks=checks))
    assert 'APLICACION TERMINADA' in result
    for key in KEYS:
        cols=','.join('['+c+']' for c in key['columns'])
        sql(f'''DECLARE @Actual nvarchar(max),@Index int;
SELECT @Index=unique_index_id FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID('T3.{key['table']}') AND type='PK';
SELECT @Actual=STUFF((SELECT ','+QUOTENAME(C.name) FROM sys.index_columns I JOIN sys.columns C ON C.object_id=I.object_id AND C.column_id=I.column_id
 WHERE I.object_id=OBJECT_ID('T3.{key['table']}') AND I.index_id=@Index AND I.key_ordinal>0 ORDER BY I.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,'');
IF ISNULL(@Actual,'')<>'{cols}' THROW 56904,'Columnas u orden PK incorrectos',1;''')
    sql("IF (SELECT COUNT(*) FROM sys.key_constraints WHERE schema_id=SCHEMA_ID('T3') AND type='PK')<>81 THROW 56905,'No creo las 81 PK',1; IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.MATERIAL') AND name='TEST_CI_MATERIAL' AND type=1) THROW 56906,'Alteró clustered existente',1;")
    ok('crea_81_pk_columnas_orden_correctos_sin_reemplazar_clustered')
    sql('''IF EXISTS(SELECT object_id,column_id,system_type_id,user_type_id,max_length,precision,scale,collation_name FROM dbo.TestBaselineColumnas
EXCEPT SELECT C.object_id,C.column_id,C.system_type_id,C.user_type_id,C.max_length,C.precision,C.scale,C.collation_name
FROM sys.columns C JOIN sys.tables T ON T.object_id=C.object_id WHERE T.schema_id=SCHEMA_ID('T3'))
THROW 56907,'Cambio tipo precision longitud o collation',1;''')
    ok('conserva_tipos_alias_precision_escala_longitud_y_collation')
    sql(script(apply=True,checks=check_plan("(SELECT COUNT(*) FROM @Plan WHERE Estado='YA_EXISTE_EQUIVALENTE')=81",'Reejecucion no idempotente')))
    ok('reejecucion_idempotente_81_pk')
    sql('ALTER TABLE T3.ASIGNA_T3 DROP CONSTRAINT ASIGT3_PK; ALTER TABLE T3.ASIGNA_T3 ALTER COLUMN NUM_ID decimal(10,0) NULL;')
    sql('''CREATE TRIGGER TestRejectPK ON DATABASE FOR ALTER_TABLE AS BEGIN
IF CHARINDEX('ADD CONSTRAINT [ASIGT3_PK]',EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]','nvarchar(max)'))>0
 THROW 56908,'Fallo DDL simulado',1; END;''')
    result=sql(script(apply=True,table='ASIGNA_T3'),fail=True)
    assert '56831' in result and '56908' in result,result[-4000:]
    sql("IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID('T3.ASIGNA_T3') AND type='PK') OR NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.ASIGNA_T3') AND name='NUM_ID' AND is_nullable=1) THROW 56909,'No revirtio ALTER COLUMN al fallar PK',1; DROP TRIGGER TestRejectPK ON DATABASE;")
    ok('revierte_cambio_not_null_si_falla_creacion_pk')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
