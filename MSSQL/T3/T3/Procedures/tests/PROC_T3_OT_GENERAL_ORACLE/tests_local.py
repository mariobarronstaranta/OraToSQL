"""Contrato del coordinador Oracle migrado; solo usa LocalDB temporal."""
from pathlib import Path
import hashlib
import subprocess
import uuid

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'ORA').is_dir() and (p/'MSSQL').is_dir())
SOURCE=ROOT/'MSSQL/T3/T3/Procedures/PROC_T3_OT_GENERAL.ORACLE.sql'
DB='CodexOTOracle_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
passed=[]
files=[ROOT/'MSSQL/T3/T3/Procedures'/name for name in
       ['PROC_T3_OT_GENERAL.sql','PROC_V40_GENERAR_OTROS.sql','WA_ERR_INVOICE_PAYMETHOD.sql']]
before={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

def sql(text,db=DB,fail=False):
    result=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA]',f'USE [{DB}]'),encoding='utf-8',capture_output=True)
    output=result.stdout+result.stderr
    if fail:
        assert result.returncode!=0,'Se esperaba error: '+output
    elif result.returncode:
        raise RuntimeError(output)
    return output

def ok(name):
    passed.append(name)
    print('PASS',name,flush=True)

def reset(mode='ok',header='100',detail='100',factura='FICTICIA'):
    sql(f'''DELETE T3.OTROS_GENERAL; DELETE T3.OTROS_DETALLE; DELETE T3.Material;
DELETE T3.CFDI_DOCUMENTOS; DELETE T3.CFDI_DOCUMENTOS_ENVIAR; DELETE T3.RF_ERROR_LOG;
DELETE dbo.Calls; DELETE dbo.HelperCalls; UPDATE dbo.Config SET Mode='{mode}';
INSERT T3.OTROS_GENERAL(Factura,Fecha_Trn,Valor_Subt,Valor_IVA) VALUES('{factura}',GETDATE(),{header},0);
INSERT T3.OTROS_DETALLE(Factura,Valor_Subt,Valor_IVA) VALUES('{factura}',{detail},0);''')

def run(calls,marked):
    sql(f'''EXEC T3.PROC_T3_OT_GENERAL;
IF (SELECT COUNT(*) FROM dbo.Calls)<>{calls} THROW 56601,'Numero de llamadas inesperado',1;
IF (SELECT COUNT(*) FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL)<>{marked}
 THROW 56602,'Marcado inesperado',1;
IF @@TRANCOUNT<>0 THROW 56603,'Dejo una transaccion abierta',1;''')

made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master'); made=True
    sql('''CREATE SCHEMA T3;
GO
CREATE TABLE T3.OTROS_GENERAL(Factura varchar(20),Fecha_Factura datetime2(0),Fecha_Cancelacion datetime2(0),
Cliente_SAP varchar(10),Clase_Factura varchar(4),Fecha_Trn datetime2(0),Fecha_Proc_BATMD datetime2(0),
Sociedad varchar(4),RFC varchar(20),Valor_Subt decimal(22,7),Valor_IVA decimal(22,7));
CREATE TABLE T3.OTROS_DETALLE(Factura varchar(20),Material varchar(10),Valor_Subt decimal(22,7),Valor_IVA decimal(22,7));
CREATE TABLE T3.Material(Material varchar(10));
CREATE TABLE T3.CFDI_DOCUMENTOS(Nota_Venta varchar(30),Status varchar(25),Folio_Fiscal varchar(40));
CREATE TABLE T3.CFDI_DOCUMENTOS_ENVIAR(Nota_Venta varchar(30),Informacion varchar(max));
CREATE TABLE T3.RF_ERROR_LOG(Rutina varchar(50),Referencia varchar(50),Error_Desc varchar(250));
CREATE TABLE dbo.Calls(Factura varchar(50));
CREATE TABLE dbo.HelperCalls(Dias int);
CREATE TABLE dbo.Config(Mode varchar(20)); INSERT dbo.Config VALUES('ok');
GO
CREATE PROCEDURE T3.WA_ERR_INVOICE_PAYMETHOD @Dias int
AS BEGIN INSERT dbo.HelperCalls VALUES(@Dias); END;
GO
CREATE PROCEDURE T3.PROC_V40_GENERAR_OTROS @Factura varchar(50)
AS BEGIN
INSERT dbo.Calls VALUES(@Factura);
DECLARE @Mode varchar(20)=(SELECT Mode FROM dbo.Config);
IF @Mode='throw' THROW 56620,'Error del generador propagado',1;
IF @Mode='logged' BEGIN
 INSERT T3.RF_ERROR_LOG VALUES('PROC_CFDI_GENERAR_OTROS',@Factura,'Error absorbido simulado'); RETURN;
END;
IF @Mode='silent' RETURN;
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES(@Factura);
INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES(@Factura,'LAYOUT SIMULADO');
END;
GO
CREATE PROCEDURE T3.PROC_T3_OT_GENERAL AS RETURN;
GO
''')
    sql(SOURCE.read_text(encoding='utf-8'))
    ok('compila_alter_del_mismo_nombre')
    reset();run(1,1)
    sql("IF NOT EXISTS(SELECT 1 FROM dbo.HelperCalls WHERE Dias=4) THROW 56604,'Falta llamada al helper con cuatro dias',1; EXEC T3.PROC_T3_OT_GENERAL; IF (SELECT COUNT(*) FROM dbo.Calls)<>1 THROW 56605,'Volvio a procesar una cabecera marcada',1;")
    ok('exito_helper_4_generador_y_marcado_por_factura')
    reset('logged');run(1,1)
    sql("IF NOT EXISTS(SELECT 1 FROM T3.RF_ERROR_LOG WHERE Rutina='PROC_CFDI_GENERAR_OTROS') OR EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS) THROW 56606,'No reprodujo el retorno con error absorbido',1;")
    ok('marca_aunque_el_generador_registre_error_sin_salidas')
    reset('silent');run(1,1)
    ok('marca_con_retorno_normal_sin_validar_salidas')
    reset('throw')
    result=sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
    assert '56620' in result and '53809' not in result,result
    sql("IF EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL) OR EXISTS(SELECT 1 FROM T3.RF_ERROR_LOG) THROW 56607,'Absorbio error o creo log propio',1;")
    ok('propaga_error_original_sin_marcar_ni_log_propio')
    for detail,calls in [('99.9000001',1),('99.9000000',0),('99.8999999',0),('100.0999999',1),('100.1000000',0),('100.1000001',0)]:
        reset(detail=detail);run(calls,calls)
    ok('tolerancia_oracle_0_10_con_siete_decimales_y_ambos_signos')
    reset();sql("INSERT T3.CFDI_DOCUMENTOS VALUES('FICTICIA','CONFIRMADO','UUID-HISTORICO'); INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES('FICTICIA','LAYOUT PREVIO');")
    run(1,1)
    sql("IF (SELECT COUNT(*) FROM T3.CFDI_DOCUMENTOS)<>2 THROW 56608,'Agrego filtro de salida historica',1;")
    ok('no_agrega_filtro_de_historicos_documentos_layouts')
    reset();sql("UPDATE T3.OTROS_GENERAL SET Sociedad='MX10',RFC='BAT030325CE9'; UPDATE T3.OTROS_DETALLE SET Material='MATERIAL'; INSERT T3.Material VALUES('MATERIAL');")
    run(0,1)
    sql("IF NOT EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD=CONVERT(datetime2(0),'29991231',112)) THROW 56609,'Centinela incorrecto',1;")
    ok('apartado_heredado_antes_de_abrir_cursor')
    reset();sql("UPDATE T3.OTROS_GENERAL SET Fecha_Trn=DATEADD(DAY,-5,GETDATE());")
    run(0,0)
    reset();sql("DELETE T3.OTROS_DETALLE;");run(0,0)
    reset();sql("UPDATE T3.OTROS_GENERAL SET Fecha_Trn=DATEADD(DAY,1,GETDATE()),Fecha_Cancelacion=GETDATE();");run(1,1)
    ok('conserva_ventana_join_y_ausencia_de_filtro_cancelacion')
    reset();sql("UPDATE T3.OTROS_GENERAL SET Clase_Factura='A'; INSERT T3.OTROS_GENERAL(Factura,Clase_Factura,Fecha_Trn,Valor_Subt,Valor_IVA) VALUES('FICTICIA','B',GETDATE(),100,0);")
    run(2,2)
    ok('conserva_grupos_repetidos_de_una_factura_sin_deduplicar')
    reset();sql("INSERT T3.OTROS_GENERAL(Factura,Fecha_Trn,Valor_Subt,Valor_IVA) VALUES('FICTICIA',GETDATE(),100,0);")
    run(0,0)
    ok('conserva_multiplicacion_del_detalle_con_cabeceras_identicas')
    reset(factura='1234567890123')
    assert '56502' in sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
    sql("IF EXISTS(SELECT 1 FROM dbo.Calls) OR EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL) THROW 56610,'No respeto VARCHAR2(12)',1;")
    ok('reproduce_error_de_asignacion_varchar2_12')
    reset();sql('''BEGIN TRANSACTION; EXEC T3.PROC_T3_OT_GENERAL;
IF @@TRANCOUNT<>1 THROW 56611,'Confirmo transaccion ajena',1;
ROLLBACK; IF EXISTS(SELECT 1 FROM dbo.Calls) THROW 56612,'Salida fuera de transaccion externa',1;''')
    ok('documenta_adaptacion_sin_confirmar_transacciones_ajenas')
    assert before=={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    ok('version_con_controles_y_generador_y_helper_sin_modificar')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if made:
        sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
