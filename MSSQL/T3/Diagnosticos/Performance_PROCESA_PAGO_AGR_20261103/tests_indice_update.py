"""Pruebas de 06/07 en una base LocalDB propia; no se conecta a T3QA."""
from pathlib import Path
import re
import subprocess
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DB = 'CodexAGRIndice_' + uuid.uuid4().hex[:8]
OUT = ROOT / 'tmp' / DB
OUT.mkdir(parents=True)
INDEX = 'IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC'
script = (HERE / '06_INDICE_UPDATE_COBRANZA.sql').read_text(encoding='utf-8')
measurement = (HERE / '07_VALIDAR_MEJORA_UPDATE.sql').read_text(encoding='utf-8')
update = (HERE / 'Resultados_05/UPDATE_QUERY_32735.sql').read_text(encoding='utf-8')
update = update[update.index('UPDATE Cobza'):]
passed = []
counter = 0


def sql(query, db=DB, expect_error=None):
    global counter
    counter += 1
    p = subprocess.run(['sqlcmd', '-S', r'(localdb)\MSSQLLocalDB', '-E', '-No', '-b', '-I',
                        '-l', '10', '-t', '60', '-f', '65001', '-w', '65535', '-d', db],
                       input=query.replace('USE [T3QA];', f'USE [{DB}];').replace("DB_NAME()<>N'T3QA'", f"DB_NAME()<>N'{DB}'"),
                       encoding='utf-8', capture_output=True, timeout=75)
    output = p.stdout + p.stderr
    (OUT / f'{counter:02d}_SALIDA.txt').write_text(output, encoding='utf-8')
    if expect_error:
        assert p.returncode and str(expect_error) in output, output[-3000:]
    elif p.returncode or 'Timeout expired' in output:
        raise RuntimeError(output[-4000:])
    return output


def check(name):
    passed.append(name)
    print('PASS', name, flush=True)


def apply():
    return script.replace('@Aplicar bit=0', '@Aplicar bit=1')


unchanged = '''
IF EXISTS(SELECT RowId,Asignacion_ID,Factura,Asignacion_Central,Fecha_Proceso FROM T3.CFDI_COBRANZA
EXCEPT SELECT RowId,Asignacion_ID,Factura,Asignacion_Central,Fecha_Proceso FROM T3.SEMILLA)
OR EXISTS(SELECT RowId,Asignacion_ID,Factura,Asignacion_Central,Fecha_Proceso FROM T3.SEMILLA
EXCEPT SELECT RowId,Asignacion_ID,Factura,Asignacion_Central,Fecha_Proceso FROM T3.CFDI_COBRANZA)
THROW 57401,'Cambio datos de cobranza',1;
'''
reset = '''UPDATE C SET Asignacion_Central=S.Asignacion_Central FROM T3.CFDI_COBRANZA C JOIN T3.SEMILLA S ON S.RowId=C.RowId;'''
created = False
try:
    sql(f'CREATE DATABASE [{DB}];', 'master')
    created = True
    sql(f'ALTER DATABASE [{DB}] SET AUTO_CLOSE OFF;', 'master')
    sql(f'ALTER DATABASE [{DB}] SET QUERY_STORE=ON (OPERATION_MODE=READ_WRITE,QUERY_CAPTURE_MODE=ALL);', 'master')
    sql('''CREATE SCHEMA T3;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE TABLE T3.CFDI_COBRANZA(RowId int IDENTITY,Asignacion_ID varchar(30),Factura varchar(30),
Asignacion_Central varchar(30),Fecha_Proceso datetime2(0));
CREATE TABLE T3.REGISTRO_FISCAL(Factura varchar(30),Entrega varchar(30),Referencia varchar(30));
CREATE UNIQUE INDEX REGFIS_PK ON T3.REGISTRO_FISCAL(Factura);
CREATE TABLE EAI_OWNER.TMP_ACCOUNT_HEADER(ClearingDocNumber varchar(20),FiscalYear varchar(4),Assignment varchar(50));
CREATE TABLE T3.CONTADOR(Llamadas int); INSERT T3.CONTADOR VALUES(0);
INSERT T3.CFDI_COBRANZA VALUES
('AA0000000001','F1',NULL,DATEADD(DAY,-1,GETDATE())),
('AA0000000002','F2',NULL,DATEADD(DAY,-1,GETDATE())),
('AA0000000001','FOLD',NULL,DATEADD(DAY,-60,GETDATE())),
('AA0000000001','FSET','YA_ASIGNADA',DATEADD(DAY,-1,GETDATE())),
('AA0000000003','F3',NULL,DATEADD(DAY,-1,GETDATE())),
('AA0000000004','F4',NULL,DATEADD(DAY,-1,GETDATE()));
INSERT T3.REGISTRO_FISCAL VALUES('F1','ENTREGA','REFERENCIA'),('F2','ENTREGA','REFERENCIA'),
('FOLD','ENTREGA','REFERENCIA'),('FSET','ENTREGA','REFERENCIA'),('F3','ENTREGA','REFERENCIA'),('F4','ENTREGA','REFERENCIA');
INSERT EAI_OWNER.TMP_ACCOUNT_HEADER VALUES
('0000000001',CONVERT(varchar(4),YEAR(GETDATE())),'CENTRAL'),
('0000000001',CONVERT(varchar(4),YEAR(GETDATE())),'CENTRAL'),
('0000000002',CONVERT(varchar(4),YEAR(GETDATE())),'OTRA_CENTRAL'),
('0000000002',CONVERT(varchar(4),YEAR(GETDATE())),'B001 - Bank I'),
('0000000003',CONVERT(varchar(4),YEAR(GETDATE())),NULL),
('0000000004',CONVERT(varchar(4),YEAR(GETDATE())),'REFERENCIA');
SELECT * INTO T3.SEMILLA FROM T3.CFDI_COBRANZA;
''')
    sql('CREATE PROCEDURE T3.PROC_CFDI_PROCESA_PAGO_AGR AS BEGIN SET NOCOUNT ON; DECLARE @nDias numeric(18,0)=30;\n' + update + '; UPDATE T3.CONTADOR SET Llamadas=Llamadas+1; END;')

    preview = sql(script)
    assert '03_SOLO_VISTA_PREVIA' in preview
    sql(unchanged + f"IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.CFDI_COBRANZA') AND name='{INDEX}') THROW 57402,'Creo indice en vista previa',1;")
    check('vista_previa_no_crea_indice_ni_cambia_datos')

    sql('EXEC T3.PROC_CFDI_PROCESA_PAGO_AGR; SELECT RowId,Asignacion_Central INTO T3.ESPERADO FROM T3.CFDI_COBRANZA;' + reset)
    result = sql(apply())
    assert '04_INDICE_CREADO' in result
    sql(unchanged + f"IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.CFDI_COBRANZA') AND name='{INDEX}') THROW 57403,'No creo indice',1;")
    check('aplica_solo_indice_aceptando_repetidos_identicos_y_excluyendo_valores_no_elegibles')

    sql('''EXEC T3.PROC_CFDI_PROCESA_PAGO_AGR;
IF EXISTS(SELECT RowId,Asignacion_Central FROM T3.CFDI_COBRANZA EXCEPT SELECT * FROM T3.ESPERADO)
OR EXISTS(SELECT * FROM T3.ESPERADO EXCEPT SELECT RowId,Asignacion_Central FROM T3.CFDI_COBRANZA)
THROW 57404,'Cambian asignaciones con el indice',1;''')
    check('update_extraido_del_plan_conserva_resultados_en_las_fixtures')

    result = sql(measurement)
    assert '04_05_QUERY_STORE_NO_DISPONIBLE' not in result and '03_CACHE_NO_DISPONIBLE' not in result
    assert '04_METRICAS_POR_PLAN_QS' in result
    sql("IF (SELECT Llamadas FROM T3.CONTADOR)<>2 THROW 57405,'El diagnostico ejecuto el SP',1;")
    check('medicion_consulta_cache_y_query_store_sin_ejecutar_el_sp')

    assert '02_YA_EXISTE_EQUIVALENTE' in sql(apply())
    sql(f'''DROP INDEX [{INDEX}] ON T3.CFDI_COBRANZA;
CREATE INDEX OTRO_NOMBRE_EQUIVALENTE ON T3.CFDI_COBRANZA(Asignacion_Central,Fecha_Proceso,Factura) INCLUDE(Asignacion_ID);''')
    assert '02_YA_EXISTE_EQUIVALENTE' in sql(apply())
    check('detecta_equivalentes_con_otro_nombre_y_cobertura_en_claves_o_include')

    sql(f'''DROP INDEX OTRO_NOMBRE_EQUIVALENTE ON T3.CFDI_COBRANZA;
CREATE INDEX [{INDEX}] ON T3.CFDI_COBRANZA(Factura);''')
    sql(apply(), expect_error=57304)
    sql(f'DROP INDEX [{INDEX}] ON T3.CFDI_COBRANZA;')
    check('no_sustituye_indice_con_nombre_ocupado')

    sql(reset + "INSERT EAI_OWNER.TMP_ACCOUNT_HEADER VALUES('0000000001',CONVERT(varchar(4),YEAR(GETDATE())),'CENTRAL_DISTINTA');")
    sql(apply(), expect_error=57305)
    sql(unchanged + f"IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.CFDI_COBRANZA') AND name='{INDEX}') THROW 57406,'Creo indice con ambiguedad',1;")
    check('bloquea_asignaciones_elegibles_distintas_sin_cambiar_datos')

    sql("UPDATE EAI_OWNER.TMP_ACCOUNT_HEADER SET Assignment=CASE WHEN Assignment='CENTRAL_DISTINTA' THEN 'central' ELSE 'CENTRAL' END WHERE ClearingDocNumber='0000000001';")
    sql(apply(), expect_error=57305)
    check('detecta_diferencias_binarias_de_assignment_aunque_la_collation_ignore_mayusculas')
    (OUT / 'RESULTADO.txt').write_text('\n'.join(passed), encoding='utf-8')
finally:
    if created:
        assert re.fullmatch(r'CodexAGRIndice_[0-9a-f]{8}', DB)
        sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];', 'master')
print('Evidencia:', OUT)
