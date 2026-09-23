"""Pruebas de integracion solo LocalDB. Python NO es dependencia operativa."""
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SERVER = r'(localdb)\MSSQLLocalDB'
DB = 'CodexRecepcion_' + uuid.uuid4().hex[:10]
WORK = ROOT / 'tests' / 'work' / DB
WORK.mkdir(parents=True)

def sql(query=None, filename=None, database=DB):
    args = ['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-d', database,
            '-h', '-1', '-W', '-w', '65535']
    args += ['-Q', query] if query is not None else ['-i', str(filename)]
    r = subprocess.run(args, capture_output=True, timeout=90)
    if r.returncode:
        raise RuntimeError(r.stdout.decode(errors='replace') + r.stderr.decode(errors='replace'))
    return r.stdout.decode(errors='replace').strip()

def run(expected=0):
    env = os.environ.copy()
    env.update(RE_SERVER=SERVER, RE_DATABASE=DB, RE_TRUSTED='1', RE_SQL_EXTRA='-No', RE_BCP_EXTRA='')
    result = subprocess.run(['cmd.exe', '/d', '/c', str(WORK / 'loader.bat')],
                            env=env, capture_output=True, timeout=90)
    log = (WORK / 'process.log').read_text(errors='replace')
    if result.returncode != expected:
        raise AssertionError(str(result.returncode) + '\n' + log + '\n' +
                             (WORK / 'carga.log').read_text(errors='replace'))
    assert not (WORK / '.recepcion_lock').exists()
    return log

def snapshot():
    return sql("SET NOCOUNT ON; SELECT (SELECT * FROM EAI.IFC_FOLIOS_FE ORDER BY ROW_ID FOR JSON PATH,INCLUDE_NULL_VALUES) F,"
               "(SELECT * FROM EAI.LDR_SHAREPOINT ORDER BY ITEMINTERNALID FOR JSON PATH,INCLUDE_NULL_VALUES) L,"
               "(SELECT COUNT(*) FROM EAI_OWNER.EAI_TRUNC_LOG) A FOR JSON PATH;")

created = False
try:
    sql('CREATE DATABASE [' + DB + '] COLLATE SQL_Latin1_General_CP1_CI_AS;', database='master')
    created = True
    sql(filename=ROOT / 'tests' / 'schema.sql')
    for name in ('loader.bat', 'control.ctl', 'truncate_ldr.sql', 'moveInfo.sql', 'Resultados7_Eleven.csv'):
        shutil.copyfile(ROOT / name, WORK / name)
    original = (WORK / 'Resultados7_Eleven.csv').read_bytes()
    log = run()
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.IFC_FOLIOS_FE;') == '10'
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.LDR_SHAREPOINT;') == '29'
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.IFC_FOLIOS_FE WHERE MODIFICACION IS NOT NULL;') == '8'
    print('OK primera carga: 29 filas, 10 nuevos, 19 actualizaciones logicas.', flush=True)
    run()
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.IFC_FOLIOS_FE;') == '10'
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.IFC_FOLIOS_FE WHERE MODIFICACION IS NOT NULL;') == '10'
    print('OK repeticion: no duplica folios.', flush=True)
    baseline = snapshot()
    lines = original.decode('utf-8-sig').splitlines()
    bad_cases = {
        'sin datos': lines[0] + '\n',
        'columnas incompletas': lines[0] + '\n1,2,3\n',
        'comillas': lines[0] + '\n' + lines[1].replace('Si', '"Si"') + '\n',
        'recepciones incompatibles': '\n'.join(lines + [lines[1].replace('73CE5SSOCW', 'OTRA_RECEPCION')]) + '\n',
        'campo excesivo': lines[0] + '\n' + lines[1].replace('73CE5SSOCW', 'X' * 101) + '\n',
    }
    for label, data in bad_cases.items():
        (WORK / 'Resultados7_Eleven.csv').write_bytes(data.encode('utf-8'))
        run(1)
        assert snapshot() == baseline, label
        print('OK rechazo sin cambios: ' + label, flush=True)
    # Probar un error posterior al TRUNCATE para verificar rollback integral.
    sql("CREATE TRIGGER EAI.CodexFallo ON EAI.IFC_FOLIOS_FE AFTER INSERT AS THROW 51999,'Fallo de prueba',1;")
    row = lines[1].split(',')
    row[6] = 'PRUEBA_NUEVA'
    (WORK / 'Resultados7_Eleven.csv').write_text(lines[0] + '\n' + ','.join(row) + '\n', encoding='utf-8')
    run(1)
    assert snapshot() == baseline
    sql('DROP TRIGGER EAI.CodexFallo;')
    print('OK rollback: destino, tabla de carga y auditoria intactos.', flush=True)
    # Copia terminada sin salto de linea; LF y UTF-8 BOM.
    (WORK / 'Resultados7_Eleven.csv').write_bytes(b'\xef\xbb\xbf' + '\n'.join(lines).encode('utf-8'))
    run()
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.IFC_FOLIOS_FE;') == '10'
    print('OK CSV con BOM, LF y ultima linea sin terminador.', flush=True)
    baseline = snapshot()
    fmt = (WORK / 'control.ctl').read_bytes()
    (WORK / 'control.ctl').write_text('formato incorrecto', encoding='utf-8')
    run(1)
    assert snapshot() == baseline
    (WORK / 'control.ctl').write_bytes(fmt)
    print('OK error bcp: no se aplica carga parcial.', flush=True)
    sql("DELETE EAI_OWNER.EAI_TRUNC_TABLE;")
    run(1)
    assert snapshot() == baseline
    sql("INSERT EAI_OWNER.EAI_TRUNC_TABLE VALUES ('EAI.LDR_SHAREPOINT');")
    print('OK sin autorizacion de limpieza: no modifica tablas.', flush=True)
    holder = subprocess.Popen(['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-r1', '-d', DB,
        '-Q', "EXEC sys.sp_getapplock @Resource=N'RecepcionEvidencias:EAI.LDR_SHAREPOINT',"
              "@LockMode='Exclusive',@LockOwner='Session'; RAISERROR('LOCK_READY',10,1) WITH NOWAIT;"
              "WAITFOR DELAY '00:00:20';"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        for attempt in range(20):
            if sql("SET NOCOUNT ON; SELECT APPLOCK_TEST('public',N'RecepcionEvidencias:EAI.LDR_SHAREPOINT','Exclusive','Session');") == '0':
                break
            time.sleep(0.2)
        else:
            raise AssertionError('No se pudo establecer el bloqueo de prueba')
        run(1)
        assert snapshot() == baseline
    finally:
        holder.terminate()
        holder.wait(timeout=10)
    print('OK bloqueo SQL: rechaza una ejecucion concurrente.', flush=True)
    # UTF-8 con caracteres no ASCII en la columna de texto que llega al destino.
    row = lines[1].split(',')
    row[4] = 'Recepci\u00f3n_\u00f1'
    row[6] = 'PRUEBA_ACENTOS'
    (WORK / 'Resultados7_Eleven.csv').write_text(lines[0] + '\n' + ','.join(row) + '\n', encoding='utf-8')
    run()
    assert sql("SET NOCOUNT ON; SELECT CASE WHEN ENTRADA=N'Recepci\u00f3n_\u00f1' THEN 1 ELSE 0 END "
               "FROM EAI.IFC_FOLIOS_FE WHERE VAR_1='PRUEBA_ACENTOS';") == '1'
    print('OK caracteres UTF-8 conservados en destino.', flush=True)
finally:
    if created:
        # Solo la base de pruebas generada por esta ejecucion.
        assert DB.startswith('CodexRecepcion_') and len(DB) == 25
        sql('ALTER DATABASE [' + DB + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + DB + '];', database='master')
