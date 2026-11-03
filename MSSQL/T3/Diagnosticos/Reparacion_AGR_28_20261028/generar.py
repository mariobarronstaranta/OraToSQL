"""Paquete acotado de conciliacion, preservando cancelacion valida de T3QA.
No conecta a bases. Lee el export Oracle y el DDL versionado.
"""
from pathlib import Path
import json,hashlib,importlib.util
from decimal import Decimal

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
PREV=HERE.parent/'Reparacion_AGR_4_20261028'
S='REPAIR_AGR28_20261028'
CANCEL='262201996890'
MISSING='262201997114'
DEFERRED=514967
source=ROOT/'ORA/T3/T3/Datos/Resultados_28_Oracle.jsonl'
raw=source.read_bytes();source_hash=hashlib.sha256(raw).hexdigest()
sec={}
for line in raw.decode('utf-8-sig').splitlines():
    if line.strip():
        j=json.loads(line,parse_float=Decimal);sec.setdefault(j['SECCION'],[]).append(j['FILA'])
meta=json.loads((PREV/'schema.json').read_text())
spec=importlib.util.spec_from_file_location('loader',PREV/'03_preparar_carga.py')
loader=importlib.util.module_from_spec(spec);spec.loader.exec_module(loader)
old=sorted({int(r['AGRUPACION']) for r in sec['CONTROLES_MISMOS_IDS']})
assert len(old)==28 and DEFERRED in old
groups=sorted((set(old)-{DEFERRED})|{529099})
group_list=','.join(map(str,groups))
selected={
 'CFDI_AGRUPACION_CTRL':[r for r in sec['CONTROLES_ORIGINALES'] if int(r['AGRUPACION']) in groups],
 'CFDI_AGRUPACION_PAGO':[r for r in sec['DETALLE_COMPLETO_GRUPOS_ORIGINALES'] if int(r['AGRUPACION']) in groups],
 'CFDI_COBRANZA':[r for r in sec['COBRANZAS_ORIGINALES'] if r['ASIGNACION_ID']==MISSING],
}
assert [len(selected[t]) for t in selected]==[28,100,1]
assert len({int(r['AGRUPACION']) for r in selected['CFDI_AGRUPACION_CTRL']})==28
assert not any(r['ASIGNACION_ID']==CANCEL for r in selected['CFDI_AGRUPACION_PAGO'])
assert len({(int(r['AGRUPACION']),r['ASIGNACION_ID']) for r in selected['CFDI_AGRUPACION_PAGO']})==100
missing=selected['CFDI_COBRANZA'][0]
assert missing['STATUS'] is None and missing['FECHA_ENVIO'] and missing['VIA_PAGO']=='03'
assert next(r for r in selected['CFDI_AGRUPACION_CTRL'] if int(r['AGRUPACION'])==529099)['ACCNT_ID']=='Contado'
for t,rows in selected.items():
    for row in rows:
        assert set(row)=={c for c,_,_ in meta[t]['columns']}
        for c,typ,n in meta[t]['columns']:loader.literal(row[c],typ,n)

def quoted(items):return ','.join("'"+str(v).replace("'","''")+"'" for v in sorted(set(items)))
allids=quoted(r['ASIGNACION_ID'] for r in sec['COBRANZAS_ORIGINALES'])
relationids=quoted(r['ASIGNACION_ID'] for r in selected['CFDI_AGRUPACION_PAGO'])
refs=quoted([r['ASIGNACION_ID'] for r in sec['COBRANZAS_ORIGINALES']]+
 [r['FACTURA'] for r in sec['COBRANZAS_ORIGINALES'] if r['FACTURA']]+
 [str(r['AGRUPACION']) for r in sec['CONTROLES_ORIGINALES']]+
 [str(r['AGRUPACION'])+'.00' for r in sec['CONTROLES_ORIGINALES']])
scopes={'CFDI_AGRUPACION_CTRL':f'AGRUPACION IN ({group_list})',
 'CFDI_AGRUPACION_PAGO':f'AGRUPACION IN ({group_list})',
 'CFDI_COBRANZA':f"ASIGNACION_ID='{MISSING}'"}
protected={
 'COBRANZAS_EXISTENTES':('CFDI_COBRANZA',f'ASIGNACION_ID IN ({allids}) AND ASIGNACION_ID<>\'{MISSING}\''),
 'DOCUMENTOS':('CFDI_DOCUMENTOS',f'NOTA_VENTA IN ({refs})'),
 'LAYOUTS':('CFDI_DOCUMENTOS_ENVIAR',f'NOTA_VENTA IN ({refs})'),
 'CONTROLES_DIFERIDOS':('CFDI_AGRUPACION_CTRL','AGRUPACION IN (514967,529057)'),
 'RELACIONES_CANCELACION':('CFDI_AGRUPACION_PAGO',f"AGRUPACION IN (514967,529057) OR ASIGNACION_ID='{CANCEL}'"),
}
header='''USE [T3QA];
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
IF @@TRANCOUNT<>0 THROW 53100,'Ejecutar sin transaccion externa.',1;
DECLARE @TimeoutAnterior int=@@LOCK_TIMEOUT;
DECLARE @RestaurarTimeout nvarchar(80)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@TimeoutAnterior);
SET LOCK_TIMEOUT 15000;
'''
ending='''END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
EXEC(@RestaurarTimeout);
THROW;
END CATCH;
'''
def cols(t):return ','.join('['+c+']' for c,_,_ in meta[t]['columns'])
def hashset(tab,scope='1=1'):
    return f"SELECT H,COUNT_BIG(*) N FROM (SELECT HASHBYTES('SHA2_256',(SELECT T.* FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) H FROM {tab} T WITH(HOLDLOCK) WHERE {scope}) X GROUP BY H"
def different(a,b):return f'EXISTS({a} EXCEPT {b}) OR EXISTS({b} EXCEPT {a})'
def diff(t,other):return different(hashset(f'T3.[{t}]',scopes[t]),hashset(f'[{S}].[{other}_{t}]'))
def guard_current(label,t,scope):return hashset(f'T3.[{t}]',scope)
def guard_saved(label):return f"SELECT H,N FROM [{S}].Protegido WHERE Objeto='{label}'"
def guards():
    return [f"IF {different(guard_current(label,t,scope),guard_saved(label))} THROW 53106,'Cambio en datos protegidos: {label}.',1;" for label,(t,scope) in protected.items()]
def schema_guard(t):
    return f"IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID('T3.{t}') AND is_disabled=0) OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID('T3.{t}') AND is_disabled=0) THROW 53107,'Revisar trigger o FK entrante de {t}.',1;"
def write(name,lines): (HERE/name).write_text('\n'.join(lines)+'\n',encoding='utf-8')

capture=[header,f"IF SCHEMA_ID('{S}') IS NOT NULL THROW 53101,'Ya existe captura. No sobrescribir.',1;",'BEGIN TRY BEGIN TRANSACTION;',
 f"EXEC(N'CREATE SCHEMA [{S}] AUTHORIZATION dbo');",
 f"CREATE TABLE [{S}].Estado(Id int PRIMARY KEY CHECK(Id=1),Fase varchar(20),Captura datetime2,Aplicacion datetime2 NULL,HashOrigen varchar(64));",
 f"INSERT [{S}].Estado VALUES(1,'CAPTURADO',SYSDATETIME(),NULL,'{source_hash}');",
 f"CREATE TABLE [{S}].Protegido(Objeto varchar(40),H binary(32),N bigint);",
 "IF (SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201996890' AND FACTURA='CHD-33522' AND NOTA_VENTA='CHD-33522' AND STATUS='Canc Pago' AND FECHA_ENVIO IS NULL)<>1 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='262201996890')<>1 THROW 53102,'La cancelacion valida cambio; revisar antes de capturar.',1;",
 f"IF EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE {scopes['CFDI_COBRANZA']}) THROW 53103,'La cobranza faltante ya existe: revisar en vez de sobrescribir.',1;"]
for t,scope in scopes.items():
    capture += [f"SELECT {cols(t)} INTO [{S}].[Antes_{t}] FROM T3.[{t}] WITH(HOLDLOCK) WHERE {scope} OPTION(MAXDOP 1);",
      f"SELECT TOP(0) {cols(t)} INTO [{S}].[Origen_{t}] FROM T3.[{t}] OPTION(MAXDOP 1);"]
for label,(t,scope) in protected.items():
    capture += [f"INSERT [{S}].Protegido SELECT '{label}',H,N FROM ({hashset('T3.['+t+']',scope)}) G OPTION(MAXDOP 1);"]
# A full copy of cancellation for review; untouched by repair.
capture += [f"SELECT * INTO [{S}].CancelacionValida FROM T3.CFDI_COBRANZA WITH(HOLDLOCK) WHERE ASIGNACION_ID='{CANCEL}' OPTION(MAXDOP 1);",
 'COMMIT; EXEC(@RestaurarTimeout);',ending,f'SELECT * FROM [{S}].Estado;']
for t in scopes:capture += [f"SELECT '{t}' Tabla,COUNT_BIG(*) FilasCapturadas FROM [{S}].[Antes_{t}];"]
write('01_CAPTURAR_T3QA.sql',capture)

load=[header,'BEGIN TRY BEGIN TRANSACTION;',
 f"IF NOT EXISTS(SELECT 1 FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1 AND Fase='CAPTURADO' AND HashOrigen='{source_hash}') THROW 53104,'La captura no corresponde a este origen.',1;"]
for t,rows in selected.items():
    load += [f"IF EXISTS(SELECT 1 FROM [{S}].[Origen_{t}]) THROW 53105,'Origen ya cargado.',1;"]
    for row in rows:
        values=','.join(loader.literal(row[c],typ,n) for c,typ,n in meta[t]['columns'])
        load += [f"INSERT [{S}].[Origen_{t}]({cols(t)}) VALUES({values});"]
load += [f"CREATE TABLE [{S}].SelloOrigen(Objeto varchar(40),H binary(32),N bigint);"]
for t in scopes:load += [f"INSERT [{S}].SelloOrigen SELECT '{t}',H,N FROM ({hashset('['+S+'].[Origen_'+t+']')}) G;"]
load += [f"UPDATE [{S}].Estado SET Fase='CARGADO' WHERE Id=1;",'COMMIT; EXEC(@RestaurarTimeout);',ending,f'SELECT * FROM [{S}].Estado;']
write('02_CARGAR_ORIGEN.sql',load)

review=[header,f'SELECT * FROM [{S}].Estado;',f'SELECT * FROM [{S}].CancelacionValida;']
for t in scopes:
    review += [f"SELECT '{t}: ANTES' Seccion,* FROM [{S}].[Antes_{t}];",f"SELECT '{t}: ORIGEN SELECCIONADO' Seccion,* FROM [{S}].[Origen_{t}];"]
review+=['EXEC(@RestaurarTimeout);']
write('03_REVISAR.sql',review)

repair=[header,'-- Ensayo predeterminado. Cambiar solo despues de revisar resultado.\nDECLARE @Aplicar bit=0;',
 'BEGIN TRY BEGIN TRANSACTION;',f"DECLARE @Fase varchar(20); SELECT @Fase=Fase FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1;",
 "IF @Fase='APLICADO' BEGIN ROLLBACK; EXEC(@RestaurarTimeout); SELECT 'YA APLICADO' Resultado; RETURN; END;",
 "IF @Fase<>'CARGADO' OR @Fase IS NULL THROW 53108,'Se requiere origen CARGADO.',1;"]
for t,scope in scopes.items():
    repair += [schema_guard(t),f"SELECT COUNT_BIG(*) FilasRevisadas FROM T3.[{t}] WITH(UPDLOCK,HOLDLOCK) WHERE {scope} OPTION(MAXDOP 1);",
      f"IF {diff(t,'Antes')} THROW 53109,'Cambio desde la captura: {t}.',1;",
      f"IF {different(hashset('['+S+'].[Origen_'+t+']'),f'SELECT H,N FROM [{S}].SelloOrigen WHERE Objeto=\'{t}\'')} THROW 53110,'Origen preparado modificado.',1;"]
repair+=guards()
repair += [f"IF (SELECT COUNT(*) FROM [{S}].Origen_CFDI_AGRUPACION_CTRL)<>28 OR (SELECT COUNT(*) FROM [{S}].Origen_CFDI_AGRUPACION_PAGO)<>100 OR (SELECT COUNT(*) FROM [{S}].Origen_CFDI_COBRANZA)<>1 THROW 53111,'Conteos inesperados de origen.',1;",
 f"IF EXISTS(SELECT 1 FROM T3.CFDI_AGRUPACION_PAGO WHERE ASIGNACION_ID='{CANCEL}' AND AGRUPACION IN ({group_list})) THROW 53112,'Cancelacion vinculada dentro del alcance: no modificar.',1;",
 f"IF EXISTS(SELECT 1 FROM T3.CFDI_AGRUPACION_PAGO WHERE ASIGNACION_ID IN ({relationids}) AND (AGRUPACION NOT IN ({group_list}) OR AGRUPACION IS NULL)) THROW 53113,'Hay relaciones externas al alcance; revisar.',1;",
 "DECLARE @Actual decimal(38,0),@MaxLocal decimal(38,0); SELECT @Actual=CONVERT(decimal(38,0),current_value) FROM sys.sequences WHERE object_id=OBJECT_ID('T3.SEQ_PAGO_CENTRAL_AGR'); SELECT @MaxLocal=MAX(N) FROM (SELECT MAX(AGRUPACION) N FROM T3.CFDI_AGRUPACION_CTRL UNION ALL SELECT MAX(AGRUPACION) FROM T3.CFDI_AGRUPACION_PAGO UNION ALL SELECT CONVERT(decimal(10,0),529099)) X; IF @Actual IS NULL OR @Actual<=@MaxLocal THROW 53114,'Secuencia requiere conciliacion antes de aplicar; este paquete no la cambia.',1;",
 f"DELETE FROM T3.CFDI_AGRUPACION_PAGO WHERE {scopes['CFDI_AGRUPACION_PAGO']};",
 f"DELETE FROM T3.CFDI_AGRUPACION_CTRL WHERE {scopes['CFDI_AGRUPACION_CTRL']};",
 f"INSERT T3.CFDI_AGRUPACION_CTRL({cols('CFDI_AGRUPACION_CTRL')}) SELECT {cols('CFDI_AGRUPACION_CTRL')} FROM [{S}].Origen_CFDI_AGRUPACION_CTRL;",
 f"INSERT T3.CFDI_COBRANZA({cols('CFDI_COBRANZA')}) SELECT {cols('CFDI_COBRANZA')} FROM [{S}].Origen_CFDI_COBRANZA;",
 f"INSERT T3.CFDI_AGRUPACION_PAGO({cols('CFDI_AGRUPACION_PAGO')}) SELECT {cols('CFDI_AGRUPACION_PAGO')} FROM [{S}].Origen_CFDI_AGRUPACION_PAGO;"]
for t in scopes:repair += [f"IF {diff(t,'Origen')} THROW 53115,'Resultado distinto del origen seleccionado: {t}.',1;"]
repair+=guards()
repair += ["SELECT @Aplicar Aplicar,'27 grupos historicos y 529099; 514967/529057 diferidos' Alcance;",
 f"IF @Aplicar=1 BEGIN UPDATE [{S}].Estado SET Fase='APLICADO',Aplicacion=SYSDATETIME() WHERE Id=1; COMMIT; SELECT 'APLICADO' Resultado; END ELSE BEGIN ROLLBACK; SELECT 'ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS' Resultado; END;",
 'EXEC(@RestaurarTimeout);',ending]
write('04_REPARAR.sql',repair)

verify=[header,f'SELECT * FROM [{S}].Estado;']
for t in scopes:verify += [f"SELECT '{t}' Tabla,CASE WHEN {diff(t,'Origen')} THEN 'DIFERENCIAS' ELSE 'IGUAL A ORIGEN SELECCIONADO' END Resultado;"]
for label,(t,scope) in protected.items():
    verify += [f"SELECT '{label}' AlcanceProtegido,CASE WHEN {different(guard_current(label,t,scope),guard_saved(label))} THEN 'CAMBIO: REVISAR' ELSE 'SIN CAMBIOS' END Resultado;"]
verify += [f"SELECT 'CANCELACION_VALIDA' Seccion,ASIGNACION_ID,FACTURA,NOTA_VENTA,STATUS,FECHA_ENVIO FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='{CANCEL}';",
 "SELECT 'CONTROLES_DIFERIDOS' Seccion,* FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION IN (514967,529057);",
 f"SELECT 'GRUPO_RECUPERADO' Seccion,* FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=529099;",
 f"SELECT 'COBRANZA_RECUPERADA' Seccion,* FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='{MISSING}';",
 f"SELECT AGRUPACION,COUNT_BIG(*) Repetidos FROM T3.CFDI_AGRUPACION_CTRL WHERE {scopes['CFDI_AGRUPACION_CTRL']} GROUP BY AGRUPACION HAVING COUNT_BIG(*)>1;",
 "SELECT current_value FROM sys.sequences WHERE object_id=OBJECT_ID('T3.SEQ_PAGO_CENTRAL_AGR');",
 'EXEC(@RestaurarTimeout);']
write('05_VERIFICAR.sql',verify)

undo=[header,'DECLARE @Revertir bit=0;',"IF @Revertir<>1 THROW 53116,'Cambiar @Revertir a 1 solo para reversion deliberada.',1;",'BEGIN TRY BEGIN TRANSACTION;',
 f"IF NOT EXISTS(SELECT 1 FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1 AND Fase='APLICADO') THROW 53117,'Paquete no aplicado.',1;"]
for t,scope in scopes.items():
    undo += [schema_guard(t),f"SELECT COUNT_BIG(*) FilasRevisadas FROM T3.[{t}] WITH(UPDLOCK,HOLDLOCK) WHERE {scope} OPTION(MAXDOP 1);",
      f"IF {diff(t,'Origen')} THROW 53118,'Hay cambios posteriores: {t}.',1;"]
undo+=guards()
for t in ('CFDI_AGRUPACION_PAGO','CFDI_AGRUPACION_CTRL','CFDI_COBRANZA'):
    undo += [f"DELETE FROM T3.[{t}] WHERE {scopes[t]};"]
for t in ('CFDI_AGRUPACION_CTRL','CFDI_COBRANZA','CFDI_AGRUPACION_PAGO'):
    undo += [f"INSERT T3.[{t}]({cols(t)}) SELECT {cols(t)} FROM [{S}].[Antes_{t}];",
      f"IF {diff(t,'Antes')} THROW 53119,'No se restauro el respaldo: {t}.',1;"]
undo += [f"UPDATE [{S}].Estado SET Fase='REVERTIDO' WHERE Id=1; COMMIT; EXEC(@RestaurarTimeout);",ending]
write('06_REVERTIR.sql',undo)
write('MANIFIESTO.txt',[f'Archivo origen: {source}',f'SHA256: {source_hash}',
 'Controles seleccionados: 28 (27 julio + 529099 Contado)',
 'Relaciones seleccionadas: 100 (99 julio + 1 octubre)',
 'Insercion de cobranza: 262201997114 (1 fila)',
 'Sin cambios: cobranza cancelada 262201996890, grupos 514967/529057, demas cobranzas, documentos, layouts, secuencia y componente 614.'])
print('Generados seis scripts SQL y manifiesto en',HERE)
