"""Prueba del diagnostico en LocalDB con esquema real y datos ficticios."""
from pathlib import Path
import re
import subprocess
import uuid

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
DB='CodexDeliveryCheck_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
passed=[]

def sql(text,db=DB):
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    if p.returncode:
        (OUT/'ERROR.txt').write_text(p.stdout+p.stderr,encoding='utf-8')
        raise RuntimeError((p.stdout+p.stderr)[-8000:])
    return p.stdout+p.stderr

def ddl(file,table):
    data=file.read_bytes()
    text=data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
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
    sql('CREATE SCHEMA T3;\nGO\nCREATE SCHEMA EAI;\nGO\nCREATE SCHEMA EAI_OWNER;\nGO')
    for name in ['DELIVERY_HIST','REMISION_GENERAL','REMISION_DETALLE','REMISION_CTRO_SOCIEDAD','MATERIAL']:
        sql(ddl(ROOT/f'MSSQL/T3/T3/Tables/T3.{name}.Table.sql',f'[T3].[{name}]'))
    for name in ['MX_EAI_MESSAGE_LOG','MX_NRIV_RELACION']:
        sql(ddl(ROOT/'MSSQL/T3/EAI_OWNER/Tables/Tablas_EAI_OWNER.sql',f'[EAI_OWNER].[{name}]'))
    sql('''CREATE TABLE EAI.ZSDFE_SOC(BUKRS varchar(10),KUNNR varchar(10),Razon_Social varchar(200));
GO
CREATE FUNCTION EAI_OWNER.getConv(@Tipo varchar(99),@Valor varchar(99)) RETURNS varchar(99)
AS BEGIN RETURN @Valor; END;
GO
INSERT EAI.ZSDFE_SOC VALUES('MX16','MX16','Sociedad de prueba');
INSERT T3.Delivery_Hist(Created,Delivery,DeliveryDate,Material,Quantity,UnitMeasure,Sociedad)
VALUES('20261029','HISTORICA','20261029','MAT1',24,'TH','MX16');
INSERT T3.Material(Material,Unidad_Med_Vta,Cig_x_CLL) VALUES('MAT1','CAJ',200);
''')
    query=(HERE/'01_VALIDAR_EJECUCION.sql').read_text(encoding='utf-8')
    query=query.replace('DECLARE @DiaEjecucion date=CONVERT(date,@Captura);',"DECLARE @DiaEjecucion date='20261103';")
    checks='''
IF EXISTS(SELECT 1 FROM @Grupos) THROW 57001,'La historia entro al cursor de hoy',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='HISTORICA' AND GruposPorFecha=0 AND CabecerasActuales=0)
 THROW 57002,'Perdio contexto historico',1;
IF EXISTS(SELECT 1 FROM T3.Remision_General) OR EXISTS(SELECT 1 FROM T3.Remision_Detalle)
 THROW 57003,'El diagnostico escribio salidas',1;
PRINT 'ASSERTS_OK';'''
    assert 'ASSERTS_OK' in sql(query+checks)
    ok('historia_fuera_del_filtro_de_hoy_y_sin_reprocesar')
    sql('''INSERT T3.Delivery_Hist(Created,Delivery,DeliveryDate,Material,Quantity,UnitMeasure,Sociedad)
VALUES('2026-11-03T10:00:00','SIN_DET','20261103','MAT1',24,'TH','MX16'),
('2026-11-03T10:00:00','SIN_SOC','20261103','MAT1',24,'TH','XXXX'),
('2026-11-03T10:00:00','UM_NUM','20261103','MAT1',24,'TH','MX16'),
('2026-11-03T10:00:00','CON_SALIDA','20261103','MAT1',24,'TH','MX16'),
('2026-11-03T10:00:00','SIN_CAB','20261103','MAT1',24,'TH','MX16'),
('2026-11-03T00:00:00','MEDIANOCHE','20261103','MAT1',24,'TH','MX16'),
('2026-11-04T01:00:00','FUTURA','20261104','MAT1',24,'TH','MX16'),
('2026-11-03T10:00:00','CON_HIST','20261103','MAT1',24,'TH','MX16'),
('2026-10-29T10:00:00','CON_HIST','20261029','MAT1',24,'TH','MX16');
INSERT T3.Remision_General(Factura,Fecha_Trn,Remision_Serie,Remision_Folio)
VALUES('SIN_DET','2026-11-03T09:59:59','REM','000001'),
('UM_NUM','2026-11-03T09:59:58','REM','000002'),
('CON_SALIDA','2026-11-03T09:59:57','REM','000003');
INSERT T3.Remision_Detalle(Factura,Num_Linea,Material,Cantidad,UnidadMedida)
VALUES('UM_NUM',1,'MAT1',24,'24.000'),('CON_SALIDA',1,'MAT1',120,'CAJ'),
('SIN_CAB',1,'MAT1',120,'CAJ');
INSERT EAI_OWNER.MX_NRIV_RELACION VALUES('CON_SALIDA','REM-000003','REM');
INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG(Created,Queue_Name,ID,REFERENCE,Siebel_Error_Message)
VALUES('2026-11-03T10:00:00','DELIVERY_TO_REMISION','SIN_DET',NULL,'Fallo simulado'),
('2026-11-03T10:00:00','GET_REMISION_INFO',NULL,'MX09','Fallo en centro');''')
    checks='''
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='SIN_DET' AND CabecerasActuales=1 AND DetallesActuales=0)
 THROW 57004,'No encontro cabecera sin detalle',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='UM_NUM' AND DetallesConUnidadNumerica=1)
 THROW 57005,'No encontro unidad numerica',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='SIN_SOC' AND GruposPorFecha=1 AND GruposConSociedad=0)
 THROW 57006,'No encontro exclusion por sociedad',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='SIN_CAB' AND CabecerasActuales=0 AND DetallesActuales=1)
 THROW 57007,'No encontro detalle huerfano',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='CON_SALIDA' AND RelacionesREMActuales=1 AND LineasEsperadasSegunJoinDetalle=DetallesActuales)
 THROW 57008,'No relaciono folio o cantidades de lineas',1;
IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='CON_HIST' AND FilasOrigen=2 AND LineasEsperadasSegunJoinDetalle=2 AND GruposPorFecha=1)
 THROW 57009,'El detalle no tomo todo el historial',1;
IF EXISTS(SELECT 1 FROM @Grupos WHERE Delivery='MEDIANOCHE') OR NOT EXISTS(SELECT 1 FROM @Grupos WHERE Delivery='FUTURA')
 THROW 57010,'No reprodujo filtro Created estricto sin limite superior',1;
IF (SELECT COUNT(*) FROM T3.Remision_General)<>3 OR (SELECT COUNT(*) FROM T3.Remision_Detalle)<>3
 OR (SELECT COUNT(*) FROM EAI_OWNER.MX_EAI_MESSAGE_LOG)<>2
 THROW 57011,'Modifico datos permanentes',1;
PRINT 'ASSERTS_OK';'''
    output=sql(query+checks)
    assert 'ASSERTS_OK' in output
    assert 'SIN_DET' in output and 'Fallo en centro' in output and 'RIESGO: UNIDAD NO CONVERTIBLE' in output
    ok('cabecera_sin_detalle_unidad_numerica_detalle_huerfano_y_sin_sociedad')
    ok('folios_logs_por_id_y_helpers_por_referencia')
    ok('detalle_cuenta_historial_completo_y_filtro_excluye_medianoche_admite_futuro')
    ok('consulta_completa_no_modifica_datos_permanentes')
    sql("INSERT T3.Remision_General(Factura) VALUES('CON_SALIDA'); INSERT T3.Remision_Detalle(Factura,Num_Linea,Material,Cantidad,UnidadMedida) VALUES('CON_SALIDA',1,'MAT1',120,'CAJ');")
    assert 'ASSERTS_OK' in sql(query+"IF NOT EXISTS(SELECT 1 FROM @Revision WHERE Delivery='CON_SALIDA' AND CabecerasActuales=2 AND DuplicadosNumeroLinea=1) THROW 57012,'No encontro duplicados',1; PRINT 'ASSERTS_OK';")
    ok('detecta_cabeceras_y_numeros_de_linea_duplicados')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if made:sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
