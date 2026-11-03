"""Valida 05 en una base LocalDB propia, con tablas y un SP ficticios."""
from pathlib import Path
import hashlib
import re
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DB = 'CodexAGRLeerPlan_' + uuid.uuid4().hex[:8]
OUT = ROOT / 'tmp' / DB
OUT.mkdir(parents=True)


def sql(query, db=DB, headers=True):
    print('SQL', db, query.strip().splitlines()[0][:80], flush=True)
    started = time.monotonic()
    args = ['sqlcmd', '-S', r'(localdb)\MSSQLLocalDB', '-E', '-No', '-b', '-I',
            '-l', '10', '-t', '30', '-f', '65001', '-w', '65535', '-y', '256', '-d', db]
    if not headers:
        args += ['-h', '-1']
    p = subprocess.run(args, input=query, capture_output=True, encoding='utf-8', timeout=45)
    print('SQL_FIN', round(time.monotonic() - started, 2), flush=True)
    if p.returncode or 'Timeout expired' in p.stdout + p.stderr:
        (OUT / 'ERROR.txt').write_text(p.stdout + p.stderr, encoding='utf-8')
        raise RuntimeError((p.stdout + p.stderr)[-5000:])
    return p.stdout + p.stderr


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
CREATE TABLE T3.CFDI_COBRANZA(Asignacion_ID varchar(30),Factura varchar(30),Asignacion_Central varchar(30));
CREATE TABLE T3.REGISTRO_FISCAL(Factura varchar(30));
CREATE TABLE EAI_OWNER.TMP_ACCOUNT_HEADER(ClearingDocNumber varchar(20),Assignment varchar(30));
CREATE TABLE T3.CONTADOR(Llamadas int);
INSERT T3.CONTADOR VALUES(0);
INSERT T3.CFDI_COBRANZA VALUES('AA1234567890','FICTICIA',NULL);
INSERT T3.REGISTRO_FISCAL VALUES('FICTICIA');
INSERT EAI_OWNER.TMP_ACCOUNT_HEADER VALUES('1234567890','CENTRAL');
GO
CREATE PROCEDURE T3.PROC_CFDI_PROCESA_PAGO_AGR @nDias numeric(18,0)=30 AS
BEGIN
    SET NOCOUNT ON;
    UPDATE T3.CONTADOR SET Llamadas=Llamadas+1;
    UPDATE Cobza SET Asignacion_Central=Acc.Assignment
    FROM T3.CFDI_COBRANZA Cobza
    JOIN EAI_OWNER.TMP_ACCOUNT_HEADER Acc ON SUBSTRING(Cobza.Asignacion_ID,3,10)=Acc.ClearingDocNumber
    JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=Cobza.Factura
    WHERE Cobza.Asignacion_Central IS NULL AND @nDias>=0;
END;
GO
EXEC T3.PROC_CFDI_PROCESA_PAGO_AGR;
''')
    select_ids = '''
SELECT TOP(1) Q.query_id,P.plan_id FROM sys.query_store_query Q
JOIN sys.query_store_query_text T ON T.query_text_id=Q.query_text_id
JOIN sys.query_store_plan P ON P.query_id=Q.query_id
WHERE Q.object_id=OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR')
AND T.query_sql_text LIKE '%UPDATE Cobza%' ORDER BY P.plan_id DESC;'''
    ids = sql('SET NOCOUNT ON;' + select_ids, headers=False)
    match = re.search(r'^\s*(\d+)\s+(\d+)\s*$', ids, re.M)
    assert match, ids
    qid, pid = map(int, match.groups())
    source = (HERE / '05_LEER_PLAN_UPDATE.sql').read_text(encoding='utf-8')
    query = source.replace('USE [T3QA];', f'USE [{DB}];').replace(
        '@QueryId bigint=32735, @PlanId bigint=8889', f'@QueryId bigint={qid}, @PlanId bigint={pid}')
    instrumented = query.replace('BEGIN TRY', "RAISERROR('ETAPA_QUERY_STORE',0,1) WITH NOWAIT;\nBEGIN TRY", 1)
    for label, before in [('ETAPA_OPERADORES', 'DECLARE @Operadores table('),
                          ('ETAPA_TEXTOS', 'DECLARE @Textos table('),
                          ('ETAPA_FRAGMENTOS', 'DECLARE @MaxPartes int;')]:
        instrumented = instrumented.replace(before, f"RAISERROR('{label}',0,1) WITH NOWAIT;\n" + before)
    output = sql(instrumented + '''
IF (SELECT Llamadas FROM T3.CONTADOR)<>1 THROW 57211,'Ejecuto el SP de negocio',1;
IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA)<>1 OR NOT EXISTS(
SELECT 1 FROM T3.CFDI_COBRANZA WHERE Asignacion_Central='CENTRAL') THROW 57212,'Modifico datos',1;
PRINT 'DATOS_SIN_CAMBIOS';''')
    (OUT / 'SALIDA_256.txt').write_text(output, encoding='utf-8')
    assert 'DATOS_SIN_CAMBIOS' in output
    assert '00_ERROR_LECTURA' not in output and '00_PLAN_NO_DISPONIBLE' not in output
    for section in ['01_OPERADORES_ESTIMADOS', '02_ARISTAS_DEL_PLAN', '05_TEXTOS_FRAGMENTADOS']:
        assert section in output, section

    # Reconstruir el XML a partir del reporte con limite de 256 por columna.
    lines = output.splitlines()
    chunks = []
    bounds = headers = None
    for i, line in enumerate(lines):
        if line.startswith('Seccion') and i + 1 < len(lines) and lines[i + 1].startswith('---'):
            bounds = [m.span() for m in re.finditer('-+', lines[i + 1])]
            headers = [line[a:b].strip() for a, b in bounds]
        elif line.startswith('05_TEXTOS_FRAGMENTADOS'):
            row = {name: line[a:b].strip() for name, (a, b) in zip(headers, bounds)}
            if row['Clase'] == 'PLAN_XML_COMPLETO':
                # Las partes intermedias pueden terminar con espacios: conservarlos.
                a, b = bounds[headers.index('Fragmento')]
                fragment = line[a:b]
                if int(row['Parte']) == int(row['TotalPartes']):
                    fragment = fragment.rstrip()
                chunks.append((int(row['Parte']), int(row['TotalPartes']), fragment))
    assert chunks and len(chunks) == chunks[0][1]
    assert [n for n, _, _ in chunks] == list(range(1, len(chunks) + 1))
    rebuilt = ''.join(fragment for _, _, fragment in chunks)
    expected_hash = sql(f"SET NOCOUNT ON;SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),TRY_CONVERT(xml,query_plan))),2) FROM sys.query_store_plan WHERE plan_id={pid};", headers=False).strip()
    assert hashlib.sha256(rebuilt.encode('utf-16le')).hexdigest().upper() == expected_hash
    parsed = ET.fromstring(rebuilt)
    assert parsed.findall('.//{http://schemas.microsoft.com/sqlserver/2004/07/showplan}RelOp')
    (OUT / 'PLAN_RECONSTRUIDO.sqlplan').write_text(rebuilt, encoding='utf-8')

    missing = sql(query.replace(f'@PlanId bigint={pid}', '@PlanId bigint=-1'))
    assert '00_PLAN_NO_DISPONIBLE' in missing
    passed = [
        'lee_operadores_aristas_y_predicados_del_plan_real_de_prueba',
        'reconstruye_xml_completo_sin_perdida_con_columnas_limitadas_a_256',
        'no_ejecuta_sp_ni_modifica_datos_de_negocio',
        'informa_plan_no_disponible_sin_ejecutar_negocio',
    ]
    (OUT / 'RESULTADO.txt').write_text('\n'.join(passed), encoding='utf-8')
    for name in passed:
        print('PASS', name, flush=True)
finally:
    if created:
        assert re.fullmatch(r'CodexAGRLeerPlan_[0-9a-f]{8}', DB)
        sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];', 'master')
print('Evidencia:', OUT)
