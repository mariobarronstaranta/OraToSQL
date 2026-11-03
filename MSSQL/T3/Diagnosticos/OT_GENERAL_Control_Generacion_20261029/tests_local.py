"""Pruebas funcionales del coordinador con generador simulado. Solo LocalDB."""
from pathlib import Path
import subprocess, uuid
from concurrent.futures import ThreadPoolExecutor

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
DB='CodexOTGeneral_'+uuid.uuid4().hex[:8]
OUT=ROOT/'tmp'/DB
OUT.mkdir(parents=True)
passed=[]

def sql(text,db=DB,fail=False):
    p=subprocess.run(['sqlcmd','-S',r'(localdb)\MSSQLLocalDB','-E','-No','-b','-I','-f','65001','-d',db],
        input=text.replace('USE [T3QA];',f'USE [{DB}];'),encoding='utf-8',capture_output=True)
    output=p.stdout+p.stderr
    if fail:
        assert p.returncode!=0,'Se esperaba error: '+output
    elif p.returncode:
        raise RuntimeError(output)
    return output

def ok(name):
    passed.append(name)
    print('PASS',name,flush=True)

def reset(mode='ok',total=116,header_count=1):
    sql(f'''DELETE T3.CFDI_DOCUMENTOS; DELETE T3.CFDI_DOCUMENTOS_ENVIAR;
    DELETE T3.RF_ERROR_LOG; DELETE EAI_OWNER.MX_EAI_MESSAGE_LOG;
    DELETE T3.OTROS_GENERAL; DELETE T3.OTROS_DETALLE; DELETE dbo.Calls;
    UPDATE dbo.TestConfig SET Mode='{mode}';
    INSERT T3.OTROS_GENERAL(Factura,Fecha_Trn,Valor_Subt,Valor_IVA)
    SELECT 'FICTICIA',GETDATE(),100,16 FROM (VALUES(1),(2)) V(N) WHERE N<={header_count};
    INSERT T3.OTROS_DETALLE(Factura,Valor_Subt,Valor_IVA) VALUES('FICTICIA',{total},0);''')

def unchanged():
    sql('''IF EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL)
    THROW 53901,'Se marco una factura que no se genero correctamente',1;''')

made=False
try:
    sql(f'CREATE DATABASE [{DB}];','master'); made=True
    sql('''CREATE SCHEMA T3;
GO
CREATE SCHEMA EAI_OWNER;
GO
CREATE TABLE T3.OTROS_GENERAL(Factura varchar(20),Fecha_Trn datetime2(0),Fecha_Proc_BATMD datetime2(0),
Sociedad varchar(4),RFC varchar(20),Valor_Subt decimal(22,7),Valor_IVA decimal(22,7));
CREATE TABLE T3.OTROS_DETALLE(Factura varchar(20),Material varchar(10),Valor_Subt decimal(22,7),Valor_IVA decimal(22,7));
CREATE TABLE T3.Material(Material varchar(10));
CREATE TABLE T3.CFDI_DOCUMENTOS(Nota_Venta varchar(30),Folio_Fiscal varchar(40),Fecha_Timbre datetime,
Fecha_Envio datetime,Fecha_Confirmacion datetime,Id_Envio varchar(25),Id_Confirmacion varchar(25),Status varchar(25));
CREATE TABLE T3.CFDI_DOCUMENTOS_ENVIAR(Nota_Venta varchar(30),Informacion varchar(max));
CREATE TABLE T3.RF_ERROR_LOG(Fecha datetime2(0),Rutina varchar(50),Referencia varchar(50),ERROR_DESC varchar(250));
CREATE TABLE EAI_OWNER.MX_EAI_MESSAGE_LOG(REFERENCE varchar(50),QUEUE_NAME varchar(50));
CREATE TABLE dbo.Calls(Factura varchar(50));
CREATE TABLE dbo.TestConfig(Mode varchar(30)); INSERT dbo.TestConfig VALUES('ok');
GO
CREATE PROCEDURE T3.WA_ERR_INVOICE_PAYMETHOD @Dias int AS RETURN;
GO
CREATE PROCEDURE T3.PROC_V40_GENERAR_OTROS @Factura varchar(50)
AS BEGIN
-- Contrato de despliegue: CAST(@Doc_tasa AS DECIMAL(38,12)) / 100.0
DECLARE @Mode varchar(30)=(SELECT Mode FROM dbo.TestConfig);
INSERT dbo.Calls VALUES(@Factura);
IF @Mode='slow' WAITFOR DELAY '00:00:01';
IF @Mode='throw' THROW 53920,'Error aritmetico simulado',1;
IF @Mode='doomed' BEGIN SET XACT_ABORT ON; THROW 53921,'Transaccion no confirmable simulada',1; END;
IF @Mode='silent' RETURN;
INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES(@Factura,CASE WHEN @Mode='empty' THEN '' ELSE 'LAYOUT FICTICIO VALIDO' END);
IF @Mode='partial' RETURN;
INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES(@Factura);
IF @Mode='duplicates' INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES(@Factura);
IF @Mode='logged' INSERT T3.RF_ERROR_LOG VALUES(GETDATE(),'PROC_CFDI_GENERAR_OTROS',@Factura,'Error capturado por generador');
IF @Mode='mapping' INSERT EAI_OWNER.MX_EAI_MESSAGE_LOG VALUES(@Factura,'GET_SAT_CLAVEPRODUCTO');
END;
GO
CREATE PROCEDURE T3.PROC_T3_OT_GENERAL AS RETURN;
GO
''')
    old_hash=sql("SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL'))),2);")
    preview=(HERE/'01_INSTALAR_CORRECCION.sql').read_text(encoding='utf-8')
    assert 'VISTA PREVIA' in sql(preview)
    assert old_hash==sql("SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL'))),2);")
    ok('despliegue_previo_no_altera')
    assert 'CORRECCION INSTALADA' in sql(preview.replace('@Aplicar bit=0','@Aplicar bit=1'))
    ok('despliegue_respalda_y_compila')
    reset()
    sql("EXEC T3.PROC_T3_OT_GENERAL; EXEC T3.PROC_T3_OT_GENERAL; IF (SELECT COUNT(*) FROM dbo.Calls)<>1 OR (SELECT COUNT(*) FROM T3.CFDI_DOCUMENTOS)<>1 OR NOT EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL) THROW 53900,'Generacion o idempotencia incorrecta',1;")
    ok('exito_marca_y_segunda_ejecucion_no_duplica')
    for column,value in [('Folio_Fiscal',"'UUID-HISTORICO'"),('Fecha_Envio','GETDATE()'),('Fecha_Timbre','GETDATE()'),('Fecha_Confirmacion','GETDATE()'),('Id_Envio',"'ENVIO'"),('Id_Confirmacion',"'CONFIRMACION'"),('Status',"'CONFIRMADO'"),('Status',"'CANCELADO'"),('Status',"'TIMBRADO'")]:
        reset(); sql(f"INSERT T3.CFDI_DOCUMENTOS(Nota_Venta,{column}) VALUES('FICTICIA',{value}); EXEC T3.PROC_T3_OT_GENERAL; IF EXISTS(SELECT 1 FROM dbo.Calls) OR (SELECT COUNT(*) FROM T3.CFDI_DOCUMENTOS)<>1 THROW 53902,'Documento protegido regenerado',1;")
        unchanged()
    ok('protege_historicos_sin_layout_por_uuid_envio_timbre_estado')
    reset();sql("INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES('FICTICIA'); INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES('FICTICIA','LAYOUT EXISTENTE'); EXEC T3.PROC_T3_OT_GENERAL; IF EXISTS(SELECT 1 FROM dbo.Calls) THROW 53903,'Salida existente regenerada',1;")
    unchanged();ok('omite_salida_completa_sin_modificar_fecha')
    for mode,number in [('silent','53805'),('partial','53805'),('empty','53805'),('duplicates','53805'),('logged','53803'),('mapping','53804'),('throw','53920')]:
        reset(mode)
        result=sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
        assert number in result and 'FICTICIA' in result,result
        unchanged()
        sql("IF EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS) OR EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS_ENVIAR) OR @@TRANCOUNT<>0 THROW 53904,'Salida parcial o transaccion abierta',1; IF NOT EXISTS(SELECT 1 FROM T3.RF_ERROR_LOG WHERE Rutina='PROC_T3_OT_GENERAL') THROW 53905,'Se perdio el diagnostico',1;")
        ok('revierte_y_no_marca_'+mode)
    reset();sql("INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES('FICTICIA');")
    assert '53801' in sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
    unchanged();sql("IF (SELECT COUNT(*) FROM T3.CFDI_DOCUMENTOS)<>1 OR EXISTS(SELECT 1 FROM dbo.Calls) THROW 53906,'Se altero salida preexistente',1;")
    ok('salida_parcial_preexistente_se_preserva_y_se_reporta')
    reset(header_count=2)
    assert '53802' in sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
    unchanged();ok('rechaza_cabeceras_duplicadas')
    reset(total='115.90');sql('EXEC T3.PROC_T3_OT_GENERAL; IF EXISTS(SELECT 1 FROM dbo.Calls) THROW 53907,\'No respeto tolerancia\',1;');unchanged()
    reset(total='115.91');sql('EXEC T3.PROC_T3_OT_GENERAL; IF (SELECT COUNT(*) FROM dbo.Calls)<>1 THROW 53908,\'Rechazo diferencia admisible\',1;')
    ok('conserva_tolerancia_estricta_0_10')
    reset();sql("INSERT T3.RF_ERROR_LOG VALUES(DATEADD(DAY,-1,GETDATE()),'PROC_CFDI_GENERAR_OTROS','FICTICIA','Error historico'); EXEC T3.PROC_T3_OT_GENERAL; IF NOT EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD IS NOT NULL) THROW 53915,'Error historico bloqueo generacion',1;")
    ok('errores_historicos_no_bloquean_generacion_nueva')
    reset();sql("UPDATE T3.OTROS_GENERAL SET Fecha_Trn=DATEADD(DAY,-5,GETDATE()); EXEC T3.PROC_T3_OT_GENERAL; IF EXISTS(SELECT 1 FROM dbo.Calls) THROW 53916,'Proceso fuera de ventana',1;")
    unchanged();ok('conserva_ventana_de_cuatro_dias')
    reset();sql("UPDATE T3.OTROS_GENERAL SET Sociedad='MX10',RFC='BAT030325CE9'; UPDATE T3.OTROS_DETALLE SET Material='MATERIAL'; INSERT T3.Material VALUES('MATERIAL'); EXEC T3.PROC_T3_OT_GENERAL; IF EXISTS(SELECT 1 FROM dbo.Calls) OR NOT EXISTS(SELECT 1 FROM T3.OTROS_GENERAL WHERE Fecha_Proc_BATMD=CONVERT(datetime,'29991231',112)) THROW 53917,'No conservo apartado heredado',1;")
    ok('conserva_apartado_centinela_heredado')
    reset('slow')
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(lambda _:sql('EXEC T3.PROC_T3_OT_GENERAL;'),range(2)))
    sql("IF (SELECT COUNT(*) FROM dbo.Calls)<>1 OR (SELECT COUNT(*) FROM T3.CFDI_DOCUMENTOS)<>1 THROW 53918,'Sesiones concurrentes duplicaron salida',1;")
    ok('dos_sesiones_concurrentes_generan_una_sola_vez')
    reset();sql('''BEGIN TRANSACTION; EXEC T3.PROC_T3_OT_GENERAL;
IF @@TRANCOUNT<>1 THROW 53909,'Confirmo transaccion externa',1;
ROLLBACK; IF EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS) THROW 53910,'Salida fuera de transaccion externa',1;''')
    unchanged();ok('exito_respeta_transaccion_del_llamador')
    reset('partial');sql('''BEGIN TRANSACTION;
INSERT dbo.Calls VALUES('TRABAJO ANTERIOR');
BEGIN TRY EXEC T3.PROC_T3_OT_GENERAL; END TRY BEGIN CATCH
IF ERROR_NUMBER()<>53809 THROW;
END CATCH;
IF XACT_STATE()<>1 OR @@TRANCOUNT<>1 OR NOT EXISTS(SELECT 1 FROM dbo.Calls WHERE Factura='TRABAJO ANTERIOR')
THROW 53911,'Se perdio trabajo del llamador',1;
IF EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS_ENVIAR) THROW 53912,'No revirtio savepoint',1;
ROLLBACK;''');ok('error_revierte_savepoint_sin_perder_trabajo_previo')
    reset('doomed');sql('''BEGIN TRANSACTION;
BEGIN TRY EXEC T3.PROC_T3_OT_GENERAL; END TRY BEGIN CATCH
IF ERROR_NUMBER()<>53809 THROW;
END CATCH;
IF XACT_STATE()<>-1 OR @@TRANCOUNT<>1 THROW 53913,'Manejo incorrecto de transaccion no confirmable',1;
ROLLBACK;''');ok('transaccion_externa_no_confirmable_se_propaga_al_llamador')
    reset('logged');sql("INSERT T3.OTROS_GENERAL(Factura,Fecha_Trn,Valor_Subt,Valor_IVA) VALUES('AAA_OK',GETDATE(),100,16); INSERT T3.OTROS_DETALLE(Factura,Valor_Subt,Valor_IVA) VALUES('AAA_OK',116,0);")
    # Generador simulado falla por igual: probar preservacion por factura con
    # un generador que solo rechaza FICTICIA.
    sql("ALTER PROCEDURE T3.PROC_V40_GENERAR_OTROS @Factura varchar(50) AS BEGIN IF @Factura='FICTICIA' RETURN; INSERT T3.CFDI_DOCUMENTOS(Nota_Venta) VALUES(@Factura); INSERT T3.CFDI_DOCUMENTOS_ENVIAR VALUES(@Factura,'LAYOUT FICTICIO VALIDO'); END;")
    sql('EXEC T3.PROC_T3_OT_GENERAL;',fail=True)
    sql("IF NOT EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta='AAA_OK') OR EXISTS(SELECT 1 FROM T3.CFDI_DOCUMENTOS WHERE Nota_Venta='FICTICIA') THROW 53914,'Atomicidad por factura incorrecta',1;")
    ok('fallo_posterior_preserva_facturas_confirmadas_en_ejecucion')
    rollback=(HERE/'02_REVERTIR_CORRECCION.sql').read_text(encoding='utf-8')
    sql(rollback.replace('@Revertir bit=0','@Revertir bit=1'))
    assert old_hash==sql("SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID('T3.PROC_T3_OT_GENERAL'))),2);")
    ok('reversion_recupera_definicion_instalada_original')
    (OUT/'RESULTADO.txt').write_text('\n'.join(passed),encoding='utf-8')
finally:
    if made:
        sql(f'ALTER DATABASE [{DB}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DB}];','master')
print('Evidencia:',OUT)
