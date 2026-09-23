"""Prueba del BAT real en LocalDB; crea y elimina su propia base temporal."""
from pathlib import Path
import os
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
T3 = ROOT.parents[2]
REPO = ROOT.parents[4]
DB = 'CodexVenta_' + uuid.uuid4().hex[:10]
SERVER = r'(localdb)\MSSQLLocalDB'
WORK = ROOT / 'tests' / 'work' / 'con espacios' / DB
WORK.mkdir(parents=True)

def sql(query=None, file=None, db=DB):
    args = ['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-d', db, '-h', '-1', '-W', '-w', '65535']
    args += ['-Q', query] if query is not None else ['-i', str(file)]
    r = subprocess.run(args, capture_output=True, timeout=120)
    text = r.stdout.decode(errors='replace') + r.stderr.decode(errors='replace')
    if r.returncode:
        raise RuntimeError(text)
    return text.strip()

def write(rows):
    data = ('\n'.join(rows)).encode('latin-1')  # Sin terminador final deliberadamente.
    (WORK / 'factura.ready.doc').write_bytes(data)
    return data

def run(expected, kind, data):
    env = os.environ.copy()
    env.update(VENTA_SERVER=SERVER, VENTA_DATABASE=DB, VENTA_TRUSTED='1',
               VENTA_SQL_EXTRA='-No', VENTA_BCP_EXTRA='', VENTA_CODEPAGE='28591')
    before = set((WORK / 'processed').rglob('*.doc')) if (WORK / 'processed').exists() else set()
    r = subprocess.run(['cmd.exe', '/d', '/c', str(WORK / 'loader.bat')],
                       cwd=ROOT, env=env, capture_output=True, timeout=180)
    if r.returncode != expected:
        raise AssertionError(str(r.returncode) + '\n' + r.stdout.decode(errors='replace') + '\n' +
                             (WORK / 'moveDailyInfo.log').read_text(errors='replace') + '\n' +
                             (WORK / 'process.log').read_text(errors='replace'))
    assert not (WORK / '.venta_loader_lock').exists()
    new = set((WORK / 'processed').rglob('*.doc')) - before
    assert len(new) == 1, new
    archive = new.pop()
    assert archive.parent == WORK / 'processed' / kind
    assert archive.read_bytes() == data
    assert (WORK / 'factura.ready.doc').read_bytes() == data
    suffix = archive.name.removeprefix('factura.processed.').removesuffix('.doc')
    assert (archive.parent / ('factura.log.' + suffix + '.txt')).exists()
    assert (archive.parent / ('moveDailyInfo.' + suffix + '.log')).exists()

def snapshot():
    return sql("SET NOCOUNT ON; SELECT "
               "(SELECT * FROM EAI.TAO_SALES_DOCS_LDR ORDER BY DOC_NUM_R3 FOR JSON PATH,INCLUDE_NULL_VALUES) L,"
               "(SELECT * FROM EAI.T3R_SALES_DOCS_OLD ORDER BY DOC_NUM_R3 FOR JSON PATH,INCLUDE_NULL_VALUES) F,"
               "(SELECT COUNT(*) FROM EAI_OWNER.EAI_TRUNC_LOG) A FOR JSON PATH;")

created = False
try:
    sql('CREATE DATABASE [' + DB + '] COLLATE SQL_Latin1_General_CP1_CI_AS;', db='master')
    created = True
    sql(file=T3 / 'EAI/Procedures/tests/CC_SALESDOC_LDR_TO_CIFRAS/Schema.sql')
    sql(file=ROOT / 'tests/Setup.sql')
    sql(file=T3 / 'EAI_OWNER/Procedures/LOG_START.SQL')
    sql(file=T3 / 'EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL')
    sql(file=ROOT / 'CC_SALESDOC_LDR_TO_CIFRAS.SQL')
    assert (ROOT / 'CC_SALESDOC_LDR_TO_CIFRAS.SQL').read_bytes() == (T3 / 'EAI/Procedures/CC_SALESDOC_LDR_TO_CIFRAS.SQL').read_bytes()
    for name in ('loader.bat', 'control.ctl', 'truncate_ldr.sql', 'moveDailyInfo.sql'):
        shutil.copyfile(ROOT / name, WORK / name)
    sql("INSERT EAI.T3R_SALES_DOCS_OLD(DOC_NUM_R3,CUSTOMER,DOC_STATUS) VALUES('PREVIO',53545044,'A');")
    good = [
        'P1,V1,0000123,MX09,123,20260918,ZF2,ASIG,Recepci\u00f3n,A,100.12 ,16.00 ,1.234 ',
        'P2,V2,,MX09,123,20260918,ZRE,ASIG,REF,,10.00,1.60,2.000',
        'P3,V3,,MX09,ABC,20260918,C020,ASIG,REF,A,10,1,1',
        'P4,V4,,MX09,123,20260918,S2,ASIG,REF,A,10,1,1',
    ]
    data = write(good)
    run(0, '', data)
    assert sql("SET NOCOUNT ON; SELECT DOC_STATUS FROM EAI.T3R_SALES_DOCS_OLD WHERE DOC_NUM_R3='PREVIO';") == 'D'
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.TAO_SALES_DOCS_LDR;') == '4'
    assert sql("SET NOCOUNT ON; SELECT CASE WHEN DOC_NUM_REF1=N'Recepci\u00f3n' THEN 1 ELSE 0 END FROM EAI.T3R_SALES_DOCS_OLD WHERE DOC_NUM_R3='V1';") == '1'
    run(0, '', data)
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.T3R_SALES_DOCS_OLD;') == '3'
    print('OK carga, cliente especial, latin-1, nulos, rutas con espacios y respaldos exactos sin sobreescritura.', flush=True)
    baseline = snapshot()
    for label, rows in [
        ('fecha', [good[0].replace('20260918', '20260231')]),
        ('importe', [good[0].replace('100.12 ', 'NO_NUMERO')]),
        ('columnas', ['1,2,3']),
        ('longitud', [good[0].replace('MX09', 'MX090')]),
        ('vacio', []),
    ]:
        data = write(rows)
        run(1, 'error', data)
        assert snapshot() == baseline
        print('OK archivo rechazado sin cambios: ' + label, flush=True)
    # Datos validos para la tabla de carga pero invalidos para CUSTOMER numerico del destino.
    data = write([good[0].replace('V1', 'BUENO'), good[0].replace('V1', 'MALO').replace(',123,2026', ',ABC,2026')])
    run(2, 'parcial', data)
    assert sql("SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.T3R_SALES_DOCS_OLD WHERE DOC_NUM_R3='BUENO';") == '1'
    assert sql("SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.ERROR_TABLE WHERE DOC_NUM='MALO';") == '1'
    print('OK carga parcial: conserva validos, codigo 2 y historico separado.', flush=True)
    baseline = snapshot()
    sql("ALTER PROCEDURE EAI.CC_SALESDOC_LDR_TO_CIFRAS AS SELECT 1;")
    data = write(good)
    run(1, 'error', data)
    assert snapshot() == baseline
    sql(file=ROOT / 'CC_SALESDOC_LDR_TO_CIFRAS.SQL')
    print('OK rechazo del procedimiento antiguo antes de modificar datos.', flush=True)
    # Reversion de la carga y la auditoria si falla la regla del cliente.
    sql("CREATE TRIGGER EAI.CodexClienteFallo ON EAI.T3R_SALES_DOCS_OLD AFTER UPDATE AS THROW 52999,'Fallo cliente',1;")
    run(1, 'error', data)
    assert snapshot() == baseline
    sql('DROP TRIGGER EAI.CodexClienteFallo;')
    print('OK rollback de carga/auditoria ante fallo previo al procedimiento.', flush=True)
    control = (WORK / 'control.ctl').read_bytes()
    (WORK / 'control.ctl').write_text('formato incorrecto', encoding='ascii')
    run(1, 'error', data)
    assert snapshot() == baseline
    (WORK / 'control.ctl').write_bytes(control)
    print('OK fallo bcp: sin cambios en tablas y con respaldo del intento.', flush=True)
    holder = subprocess.Popen(['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-d', DB,
        '-Q', "EXEC sys.sp_getapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',"
              "@LockMode='Exclusive',@LockOwner='Session'; WAITFOR DELAY '00:00:20';"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        for _ in range(20):
            if sql("SET NOCOUNT ON; SELECT APPLOCK_TEST('public',N'EAI.CC_SALESDOC_LDR_TO_CIFRAS','Exclusive','Session');") == '0':
                break
            time.sleep(0.2)
        else:
            raise AssertionError('No se obtuvo el bloqueo de prueba')
        run(1, 'error', data)
        assert snapshot() == baseline
    finally:
        holder.terminate()
        holder.wait(timeout=10)
    print('OK ejecucion concurrente rechazada antes de modificar datos.', flush=True)
    # Archivo real proporcionado en el repositorio; sin acceso al Oracle original.
    data = (REPO / 'ORA/T3/Procesos/Ventas/Venta/factura.ready.doc').read_bytes()
    (WORK / 'factura.ready.doc').write_bytes(data)
    run(0, '', data)
    assert sql('SET NOCOUNT ON; SELECT COUNT(*) FROM EAI.TAO_SALES_DOCS_LDR;') == '8191'
    print('OK archivo de muestra completo: 8191 filas cargadas y procesamiento sin rechazos.', flush=True)
finally:
    if created:
        assert DB.startswith('CodexVenta_') and len(DB) == 21
        sql('ALTER DATABASE [' + DB + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + DB + '];', db='master')
