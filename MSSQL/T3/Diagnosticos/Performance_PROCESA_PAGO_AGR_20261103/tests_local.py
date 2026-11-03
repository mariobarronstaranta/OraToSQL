"""Consulta metadatos y reproduce casos de cardinalidad, solo en LocalDB."""
from pathlib import Path
import hashlib
import re
import subprocess
import uuid

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
DB='CodexAGRPerf_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
passed=[]
names=['PROC_CFDI_PROCESA_PAGO_AGR','PROC_CFDI_LIBERA_PAGO_CENTRAL','PROC_CFDI_LIBERA_PAGO_CHECK','PROC_V20_GENERAR_PAGO_AGR']
sources=[ROOT/f'MSSQL/T3/T3/Procedures/{n}.sql' for n in names]
before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}

def sql(text,db=DB):
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    if p.returncode:
        (OUT/'ERROR.txt').write_text(p.stdout+p.stderr,encoding='utf-8')
        raise RuntimeError((p.stdout+p.stderr)[-9000:])
    return p.stdout+p.stderr

def ddl(path,table):
    raw=path.read_bytes()
    text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    start=text.index('CREATE TABLE '+table)
    end=re.search(r'^\s*GO\s*$',text[start:],re.M|re.I)
    assert end
    return text[start:start+end.start()]+'\nGO\n'

def ok(name):
    passed.append(name)
    print('PASS',name,flush=True)

made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master');made=True
    sql('CREATE SCHEMA T3;\nGO\nCREATE SCHEMA EAI_OWNER;\nGO')
    for name in ['CFDI_COBRANZA','CFDI_AGRUPACION_CTRL','CFDI_AGRUPACION_PAGO','REGISTRO_FISCAL',
                 'REGISTRO_FISCAL_DETALLE','WA_FACTORAJE','CFDI_DOCUMENTOS','CFDI_RFC_SETTING','RF_PROCESOS_LOG']:
        sql(ddl(ROOT/f'MSSQL/T3/T3/Tables/T3.{name}.Table.sql',f'[T3].[{name}]'))
    sql(ddl(ROOT/'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql','[EAI_OWNER].[TMP_ACCOUNT_HEADER]'))
    sql('CREATE TABLE dbo.BusinessCalls(Proceso varchar(100));')
    # Stubs de solo lectura para obtener estadisticas cacheadas sin ejecutar
    # ninguno de los procedimientos reales del workspace.
    for name in names:
        sql(f'CREATE PROCEDURE T3.{name} AS SELECT COUNT_BIG(*) N FROM T3.CFDI_COBRANZA;')
        sql(f'EXEC T3.{name};')
    result=sql((HERE/'01_METADATOS_Y_TIEMPOS.sql').read_text(encoding='utf-8').replace('@VerPlanes bit=0','@VerPlanes bit=1'))
    (OUT/'METADATOS.txt').write_text(result,encoding='utf-8')
    assert '02_INDICES_ACTUALES' not in result or '00_CONTEXTO' in result
    assert '06_TIEMPOS_EN_CACHE' in result and '08_PLANES_EN_CACHE_NO_REALES' in result, '\n'.join(line for line in result.splitlines() if '06_' in line or '07_' in line or '08_' in line)
    sql("IF EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA) OR EXISTS(SELECT 1 FROM dbo.BusinessCalls) THROW 57101,'Diagnostico ejecuto negocio',1;")
    ok('metadatos_cache_planes_y_estadisticas_sin_ejecutar_sp_reales')
    sql('''CREATE NONCLUSTERED INDEX EXISTENTE_FACTOR_FACTURA ON T3.WA_FACTORAJE(Factura);
CREATE NONCLUSTERED INDEX EXISTENTE_ACCOUNT_CLEARING ON EAI_OWNER.TMP_ACCOUNT_HEADER(ClearingDocNumber,FiscalYear,Assignment);
CREATE NONCLUSTERED INDEX IX_PERF_DOCUMENTO_METODO ON T3.CFDI_DOCUMENTOS(Ctro);''')
    result=sql((HERE/'03_PROPUESTAS_INDICES_SOLO_TEXTO.sql').read_text(encoding='utf-8')+'''
IF (SELECT COUNT(*) FROM @C)<>8 THROW 57102,'No contiene ocho propuestas',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID('T3.WA_FACTORAJE') AND index_id>0)<>1
 THROW 57103,'Creo indices',1;
''')
    assert 'EXISTENTE_FACTOR_FACTURA' in result and 'EXISTENTE_ACCOUNT_CLEARING' in result
    assert 'NOMBRE CANDIDATO OCUPADO' in result
    ok('propuestas_solo_texto_reconocen_prefijos_y_colision_de_nombre')
    sql('''INSERT T3.CFDI_COBRANZA(Asignacion_ID,Factura,Nota_Venta,Fecha_Proceso,Fecha_Pago,RFC,Via_Pago,Created_By,Importe)
VALUES('AA1234567890','FACT-1','NV-1','20261020','20261015','RFC_PRUEBA','NA','CARGA',100),
('OLD','FACT-2','NV-2','20260801','20261015','RFC_PRUEBA','03','CARGA',50),
('NO_FECHA','FACT-3','NV-3',NULL,'20261015','RFC_PRUEBA','03','CARGA',25),
('SIN_IMPORTE','FACT-4','NV-4','20261020','20261015','RFC_PRUEBA','03','CARGA',NULL),
('PAGO_NULL','FACT-5','NV-5','20261020',NULL,'OTRO_RFC','03','CARGA',10),
('FACTOR','FACTOR-1','NV-6','20261020','20261015','RFC_PRUEBA','03','CARGA',20);
INSERT T3.WA_FACTORAJE(Factura) VALUES('FACTOR-1');
INSERT T3.REGISTRO_FISCAL(Factura,Entrega,Referencia) VALUES('FACT-1','ENTREGA','REFERENCIA');
INSERT EAI_OWNER.TMP_ACCOUNT_HEADER(ClearingDocNumber,FiscalYear,Assignment)
VALUES('1234567890','2026','ASIG_A'),('1234567890','2026','ASIG_B');
INSERT T3.CFDI_AGRUPACION_CTRL(Agrupacion,Fecha_Pago,Accnt_ID,Fecha_Envio) VALUES
(1,'20261015','CLIENTE',NULL),(2,'20261015','Contado',NULL),(3,'20261015',NULL,NULL);
INSERT T3.CFDI_AGRUPACION_PAGO VALUES(1,'20261015','AA1234567890'),(1,'20261015','OLD');
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Metodo_Pago) VALUES('NV-1','PUE'),('NV-1','PUE'),('NV-2','PPD');
''')
    query=(HERE/'02_VOLUMENES_Y_SELECTIVIDAD.sql').read_text(encoding='utf-8')
    query=query.replace('@Captura datetime=GETDATE()',"@Captura datetime=CONVERT(datetime,'20261103',112)")
    query=query.replace('@AnalizarLiberacion bit=0','@AnalizarLiberacion bit=1').replace('@RevisarAsignacionCentral bit=0','@RevisarAsignacionCentral bit=1')
    checks='''
IF (SELECT COUNT(*) FROM #PerfAGR_Pendientes)<>5 OR (SELECT COUNT(*) FROM #PerfAGR_Grupos)<>2
 THROW 57104,'Modelo incorrecto de pendientes o grupos',1;
IF NOT EXISTS(SELECT 1 FROM #PerfAGR_Grupos WHERE RFC='RFC_PRUEBA' AND Importe=100 AND Cantidad_Pagos=1 AND Filas=2)
 THROW 57105,'Cambio SUM/COUNT de importe NULL o normalizacion NA/03',1;
IF (SELECT COUNT(*) FROM #PerfAGR_Pendientes P JOIN #PerfAGR_Grupos G ON P.Fecha_Pago=G.Fecha_Pago
 AND P.RFC=G.RFC AND P.Via_Pago=G.Via_Pago AND P.Banco_Nombre=G.Banco_Nombre
 AND P.Banco_Num_Cuenta=G.Banco_Num_Cuenta AND P.Asignacion_Central=G.Asignacion_Central)<>4
 THROW 57106,'Omitio filas antiguas o Fecha_Proceso NULL del detalle',1;
IF (SELECT COUNT(*) FROM T3.CFDI_COBRANZA)<>6 OR EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE Fecha_Envio IS NOT NULL)
 THROW 57107,'Modifico cobranzas',1;
IF NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE Asignacion_ID='AA1234567890' AND Asignacion_Central IS NULL)
 THROW 57108,'Ejecuto UPDATE inicial',1;
PRINT 'ASSERTS_OK';
'''
    query=query.replace('DROP TABLE #PerfAGR_Grupos;',checks+'\nDROP TABLE #PerfAGR_Grupos;')
    # Reemplazar solo el DROP final: el DROP preventivo del principio debe
    # quedar sin comprobaciones cuando todavia no existen las temporales.
    query=query.replace("IF OBJECT_ID('tempdb..#PerfAGR_Grupos') IS NOT NULL "+checks+'\nDROP TABLE #PerfAGR_Grupos;',
                        "IF OBJECT_ID('tempdb..#PerfAGR_Grupos') IS NOT NULL DROP TABLE #PerfAGR_Grupos;")
    result=sql(query)
    assert 'ASSERTS_OK' in result
    assert '06_FILAS_DEL_CHECK_EN_CONJUNTO' in result and '08_MULTIPLICIDAD_ASIGNACION_CENTRAL' in result
    ok('modelo_conserva_antiguas_fecha_null_importe_null_y_na_03')
    ok('lecturas_opcionales_del_check_y_asignacion_no_modifican_datos')
    result=sql(query)
    assert 'ASSERTS_OK' in result
    ok('modelo_de_volumenes_reejecutable_sin_temporales_residuales')
    assert before=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    ok('fuentes_de_los_cuatro_sp_sin_modificaciones')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
