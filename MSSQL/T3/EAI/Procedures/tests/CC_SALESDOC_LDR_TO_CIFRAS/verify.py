"""Prueba integrada en LocalDB. No conecta con T3QA ni requiere Oracle."""
from pathlib import Path
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
T3 = HERE.parents[3]
PROC = HERE.parents[1] / 'CC_SALESDOC_LDR_TO_CIFRAS.SQL'
SERVER = r'(localdb)\MSSQLLocalDB'
DB = 'CodexCifras_' + uuid.uuid4().hex[:10]

def sql(query=None, file=None, db=DB, check=True):
    args = ['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-d', db, '-h', '-1', '-W']
    args += ['-Q', query] if query is not None else ['-i', str(file)]
    r = subprocess.run(args, capture_output=True, timeout=90)
    msg = r.stdout.decode(errors='replace') + r.stderr.decode(errors='replace')
    if check and r.returncode:
        raise RuntimeError(msg)
    return r.returncode, msg.strip()

created = False
try:
    sql('CREATE DATABASE [' + DB + '] COLLATE SQL_Latin1_General_CP1_CI_AS;', db='master')
    created = True
    sql(file=HERE / 'Schema.sql')
    sql(file=T3 / 'EAI_OWNER/Procedures/LOG_START.SQL')
    sql(file=T3 / 'EAI/Triggers/T3R_SALES_DOCS_OLD_LOG.SQL')
    sql(file=PROC)
    # Segunda instalacion: CREATE OR ALTER debe preservar el objeto sin fallar.
    sql(file=PROC)
    _, msg = sql(file=HERE / 'Cases.sql')
    print(msg, flush=True)
    # Error general de una dependencia: registrar y propagar, sin ocultarlo.
    sql("CREATE TRIGGER EAI.CodexErrorControl ON EAI.CONTROL_REPORTE AFTER UPDATE AS THROW 52990,'Fallo general de prueba',1;")
    rc, msg = sql('EXEC EAI.CC_SALESDOC_LDR_TO_CIFRAS;', check=False)
    assert rc != 0 and '52990' in msg
    assert sql("SET NOCOUNT ON; SELECT COUNT(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG WHERE SIEBEL_ERROR_CODE='52990';")[1] == '1'
    sql('DROP TRIGGER EAI.CodexErrorControl;')
    print('OK fallo general registrado y propagado.', flush=True)
    # Otra sesion retiene el bloqueo para probar una ejecucion concurrente.
    holder = subprocess.Popen(['sqlcmd', '-S', SERVER, '-E', '-No', '-b', '-d', DB,
        '-Q', "EXEC sys.sp_getapplock @Resource=N'EAI.CC_SALESDOC_LDR_TO_CIFRAS',"
              "@LockMode='Exclusive',@LockOwner='Session'; WAITFOR DELAY '00:00:20';"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        for _ in range(20):
            if sql("SET NOCOUNT ON; SELECT APPLOCK_TEST('public',N'EAI.CC_SALESDOC_LDR_TO_CIFRAS','Exclusive','Session');")[1] == '0':
                break
            time.sleep(0.2)
        else:
            raise AssertionError('No se obtuvo el bloqueo de prueba')
        rc, msg = sql('EXEC EAI.CC_SALESDOC_LDR_TO_CIFRAS;', check=False)
        assert rc != 0 and '51402' in msg
    finally:
        holder.terminate()
        holder.wait(timeout=10)
    sql('EXEC EAI.CC_SALESDOC_LDR_TO_CIFRAS;')
    print('OK concurrencia y liberacion de recursos.', flush=True)
finally:
    if created:
        assert DB.startswith('CodexCifras_') and len(DB) == 22
        sql('ALTER DATABASE [' + DB + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [' + DB + '];', db='master')
