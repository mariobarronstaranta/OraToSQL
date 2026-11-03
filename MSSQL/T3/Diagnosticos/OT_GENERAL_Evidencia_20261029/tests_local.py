"""Valida limites de fecha y correlaciones con DDL real en LocalDB temporal."""
from pathlib import Path
import re
import subprocess
import uuid

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
DB='CodexOTEvid_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
passed=[]

def sql(text,db=DB):
    result=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout+result.stderr)
    return result.stdout+result.stderr

def ddl(path,table):
    raw=path.read_bytes()
    text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    start=text.index('CREATE TABLE '+table)
    match=re.search(r'^\s*GO\s*$',text[start:],re.M|re.I)
    assert match
    return text[start:start+match.start()]+'\nGO\n'

made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master');made=True
    sql('CREATE SCHEMA T3;\nGO\nCREATE SCHEMA EAI_OWNER;\nGO')
    for name in ['OTROS_GENERAL','OTROS_DETALLE','CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR','RF_ERROR_LOG','CFDI_PRODSERV']:
        sql(ddl(ROOT/f'MSSQL/T3/T3/Tables/T3.{name}.Table.sql',f'[T3].[{name}]'))
    sql(ddl(ROOT/'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql','[EAI_OWNER].[MX_EAI_MESSAGE_LOG]'))
    sql('''INSERT T3.OTROS_GENERAL(Factura,Fecha_Trn,Fecha_Proc_BATMD,MetodoPago) VALUES
('F1','20261029','2026-10-29T01:00:00','03'),
('F1','20261029','2026-10-29T01:00:00','03'),
('OLD_DOC','20261029','2026-10-29T02:00:00','03'),
('ONLY_DOC','20261029',NULL,'03'),
('PREV_DAY','20261028','2026-10-28T23:59:59','03'),
('NEXT_DAY','20261030','2026-10-30T00:00:00','03'),
('SENTINEL','20261029','29991231','03'),
('METHOD_ONLY','20261029',NULL,'03');
UPDATE T3.OTROS_GENERAL SET Fecha_Factura='20261029' WHERE Factura='METHOD_ONLY';
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,Ctro,Fecha_Liberacion) VALUES
('F1','CTRL','2026-10-29T00:00:00'),('F1','CTRL','2026-10-29T23:59:59'),
('F1','CTRL','20261020'),('OLD_DOC','CTRL','20261020'),
('ONLY_DOC','CTRL','20261029'),('OTHER','CTRL','20261029'),
('PREV_DAY','CTRL','2026-10-28T23:59:59'),('NEXT_DAY','CTRL','2026-10-30T00:00:00');
INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES('F1','LAYOUT A'),('F1','LAYOUT B'),('OLD_DOC','LAYOUT HISTORICO');
INSERT T3.RF_ERROR_LOG(Fecha,Rutina,Referencia,ERROR_DESC) VALUES
('20261029','PROC_CFDI_GENERAR_OTROS','ONLY_ERROR','Error sin marca'),
('20261029','PROC_CFDI_GENERAR_OTROS',NULL,'Error sin referencia'),
('20261028','PROC_CFDI_GENERAR_OTROS','OLD_ERROR','Error anterior'),
('20261030','PROC_CFDI_GENERAR_OTROS','NEXT_ERROR','Error posterior');
INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG(Created,Queue_Name,REFERENCE) VALUES
('20261029','WA_ERR_INVOICE_PAYMETHOD','ONLY_EAI'),
('20261029','RECV_INVOICE_INTERCOMPANY','T3');
INSERT T3.OTROS_DETALLE(Factura,Material,MaterialDescripcion) VALUES
('F1','123.4','MATERIAL'),('METHOD_ONLY','R900','FIXED ASSET - External Sales');
INSERT T3.CFDI_PRODSERV(Modulo,Material,Fecha_Creacion,Creado_Por) VALUES
('EXPO','1234','20261029','INVOICING'),('EXPO','999','20261029','INVOICING');''')
    query=(HERE/'01_CONSULTAR_MOVIMIENTOS_HOY.sql').read_text(encoding='utf-8')
    query=query.replace('DECLARE @Fecha date=CONVERT(date,@Captura);',"DECLARE @Fecha date='20261029';")
    checks='''
IF (SELECT COUNT_BIG(*) FROM @Facturas)<>5 THROW 56701,'Lista de facturas incorrecta',1;
IF NOT EXISTS(SELECT 1 FROM @Facturas WHERE Factura='F1' AND MarcaEnPeriodo=1 AND LiberacionEnPeriodo=1)
 THROW 56702,'Perdio marca o liberacion en limites incluidos',1;
IF NOT EXISTS(SELECT 1 FROM @Facturas WHERE Factura='OLD_DOC' AND MarcaEnPeriodo=1 AND LiberacionEnPeriodo=0)
 THROW 56703,'Confundio documento historico con liberacion del periodo',1;
IF NOT EXISTS(SELECT 1 FROM @Facturas WHERE Factura='ONLY_DOC' AND MarcaEnPeriodo=0 AND LiberacionEnPeriodo=1)
 THROW 56704,'Perdio documento sin cabecera marcada',1;
IF NOT EXISTS(SELECT 1 FROM @Facturas WHERE Factura='ONLY_ERROR' AND ErrorRFEnPeriodo=1 AND MarcaEnPeriodo=0)
 THROW 56705,'Perdio error sin cabecera',1;
IF NOT EXISTS(SELECT 1 FROM @Facturas WHERE Factura='ONLY_EAI' AND ErrorMapeoOHelperEnPeriodo=1)
 THROW 56706,'Perdio error del helper',1;
IF EXISTS(SELECT 1 FROM @Facturas WHERE Factura IN('PREV_DAY','NEXT_DAY','OTHER','T3','SENTINEL','METHOD_ONLY','OLD_ERROR','NEXT_ERROR'))
 THROW 56707,'Inclusion temporal o atribucion no sustentada',1;
IF (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD>='20261029' AND Fecha_Proc_BATMD<'20261030')<>3
 THROW 56708,'Conteo de cabeceras cambiado',1;
IF (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS_ENVIAR E WHERE EXISTS(SELECT 1 FROM @Facturas F WHERE F.Factura=E.Nota_Venta))<>3
 THROW 56709,'Multiplico layouts por documentos o cabeceras duplicadas',1;
IF (SELECT COUNT_BIG(*) FROM T3.OTROS_GENERAL)<>8 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_DOCUMENTOS)<>8
 OR (SELECT COUNT_BIG(*) FROM T3.RF_ERROR_LOG)<>4
 THROW 56710,'Modifico tablas permanentes',1;
PRINT 'ASSERTS_OK';
'''
    result=sql(query+checks)
    assert 'ASSERTS_OK' in result
    for section in ['00_CONTEXTO','01_RESUMEN','02_FACTURAS_Y_ESTADO_ACTUAL','03_CABECERAS_ESTADO_ACTUAL',
                    '04_DOCUMENTOS_RELACIONADOS','05_LAYOUTS_ACTUALES_SIN_FECHA','06_ERRORES_RF_DEL_PERIODO',
                    '07_MENSAJES_EAI_DEL_PERIODO','08_CATALOGO_SAT_FECHA_CREACION_EN_PERIODO',
                    '09_METODO_PAGO_ACTUAL_CON_MATERIAL_R900','10_APARTADOS_CENTINELA_ESTADO_ACTUAL']:
        assert section in result,section
    passed=['compila_y_ejecuta_consulta_completa_con_DDL_real',
            'incluye_inicio_y_ultimo_segundo_excluye_dia_siguiente',
            'incluye_errores_sin_marca_o_sin_cabecera',
            'distingue_documentos_historicos_de_liberaciones_del_periodo',
            'no_multiplica_layouts_por_cabeceras_o_documentos_duplicados',
            'no_atribuye_centinela_metodopago_o_log_padre_como_cambio_fechado',
            'muestra_catalogo_relacionado_metodopago_y_centinela_como_contexto',
            'tablas_permanentes_sin_cambios']
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
    for name in passed:print('PASS',name,flush=True)
finally:
    if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
