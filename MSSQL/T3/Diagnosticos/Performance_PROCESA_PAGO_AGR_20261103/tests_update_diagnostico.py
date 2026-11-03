"""Valida 04 con un UPDATE ficticio en LocalDB; no usa los SP reales."""
from pathlib import Path
import re,subprocess,uuid

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
DB='CodexAGRUpdateDiag_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
def sql(text,db=DB):
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    if p.returncode:
        (OUT/'ERROR.txt').write_text(p.stdout+p.stderr,encoding='utf-8')
        raise RuntimeError((p.stdout+p.stderr)[-5000:])
    return p.stdout+p.stderr
def ddl(path,table):
    b=path.read_bytes();t=b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    a=t.index('CREATE TABLE '+table);m=re.search(r'^\s*GO\s*$',t[a:],re.M|re.I)
    return t[a:a+m.start()]+'\nGO\n'
made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master');made=True
    sql(f'ALTER DATABASE [{DB}] SET AUTO_CLOSE OFF;','master')
    sql(f'ALTER DATABASE [{DB}] SET QUERY_STORE=ON (OPERATION_MODE=READ_WRITE,QUERY_CAPTURE_MODE=ALL,WAIT_STATS_CAPTURE_MODE=ON);','master')
    sql('CREATE SCHEMA T3;\nGO\nCREATE SCHEMA EAI_OWNER;\nGO')
    for name in ['CFDI_COBRANZA','REGISTRO_FISCAL']:
        sql(ddl(ROOT/f'MSSQL/T3/T3/Tables/T3.{name}.Table.sql',f'[T3].[{name}]'))
    sql(ddl(ROOT/'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql','[EAI_OWNER].[TMP_ACCOUNT_HEADER]'))
    sql('''INSERT T3.CFDI_COBRANZA(Asignacion_ID,Factura,Fecha_Proceso,Asignacion_Central)
VALUES('AA1234567890','FICTICIA','20261020',NULL);
INSERT EAI_OWNER.TMP_ACCOUNT_HEADER(ClearingDocNumber,FiscalYear,Assignment) VALUES('1234567890','2026','PRUEBA');
INSERT T3.REGISTRO_FISCAL(Factura) VALUES('FICTICIA');
GO
CREATE PROCEDURE T3.PROC_CFDI_PROCESA_PAGO_AGR AS
UPDATE Cobza SET Asignacion_Central=Acc.Assignment FROM T3.CFDI_COBRANZA Cobza
JOIN EAI_OWNER.TMP_ACCOUNT_HEADER Acc ON SUBSTRING(Cobza.Asignacion_ID,3,10)=Acc.ClearingDocNumber;
GO
CREATE PROCEDURE T3.PROC_CFDI_LIBERA_PAGO_CHECK AS SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA;
GO
EXEC T3.PROC_CFDI_PROCESA_PAGO_AGR;
''')
    query=(HERE/'04_AISLAR_UPDATE_ASIGNACION.sql').read_text(encoding='utf-8')
    query=query.replace('@MedirVolumenes bit=0','@MedirVolumenes bit=1')
    query=query.replace("'2026-10-28T00:00:00+00:00'",'DATEADD(DAY,-1,SYSDATETIMEOFFSET())').replace("'2026-10-31T00:00:00+00:00'",'DATEADD(DAY,1,SYSDATETIMEOFFSET())')
    result=sql(query+"IF NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE Asignacion_Central='PRUEBA') OR (SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA)<>1 THROW 57201,'Modifico datos',1; IF NOT EXISTS(SELECT 1 FROM @QS) THROW 57202,'No encontro texto del UPDATE en Query Store',1; PRINT 'ASSERTS_OK';")
    (OUT/'SALIDA.txt').write_text(result,encoding='utf-8')
    assert 'ASSERTS_OK' in result
    assert '02_METRICAS_UPDATE_EN_CACHE' in result or '02_CACHE_SIN_UPDATE' in result
    assert '04_07_QUERY_STORE_NO_DISPONIBLE' not in result,result[-3000:]
    assert '10_SELECTIVIDAD_UPDATE_ESTADO_ACTUAL' in result
    passed=['maneja_cache_y_extrae_texto_xml_de_query_store_del_update_ficticio',
            'consulta_vistas_query_store_y_esperas_sin_cambiarlas',
            'organizacion_y_selectividad_opcional_sin_escrituras_de_negocio']
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
    for p in passed:print('PASS',p,flush=True)
finally:
    if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
