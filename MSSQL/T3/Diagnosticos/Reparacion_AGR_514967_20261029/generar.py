"""Genera reparacion de la asociacion erronea con 514967; no conecta a bases."""
from pathlib import Path
import json,hashlib,importlib.util
from decimal import Decimal
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
PREV=HERE.parent/'Reparacion_AGR_4_20261028'
S='REPAIR_AGR514967_20261029';CANCEL='262201996890';LEGIT='262201489238'
raw=(ROOT/'ORA/T3/T3/Datos/Resultados_28_Oracle.jsonl').read_bytes()
sections={}
for line in raw.decode('utf-8-sig').splitlines():
 if line.strip():
  j=json.loads(line,parse_float=Decimal);sections.setdefault(j['SECCION'],[]).append(j['FILA'])
data={
 'CFDI_AGRUPACION_CTRL':[r for r in sections['CONTROLES_ORIGINALES'] if int(r['AGRUPACION'])==514967],
 'CFDI_AGRUPACION_PAGO':[r for r in sections['DETALLE_COMPLETO_GRUPOS_ORIGINALES'] if int(r['AGRUPACION'])==514967]}
assert len(data['CFDI_AGRUPACION_CTRL'])==len(data['CFDI_AGRUPACION_PAGO'])==1
assert data['CFDI_AGRUPACION_CTRL'][0]['IMPORTE']==Decimal('4306.27')
assert data['CFDI_AGRUPACION_PAGO'][0]['ASIGNACION_ID']==LEGIT
meta=json.loads((PREV/'schema.json').read_text())
spec=importlib.util.spec_from_file_location('loader',PREV/'03_preparar_carga.py');loader=importlib.util.module_from_spec(spec);spec.loader.exec_module(loader)
def cols(t):return ','.join('['+c+']' for c,_,_ in meta[t]['columns'])
def quote(vals):return ','.join("'"+str(v).replace("'","''")+"'" for v in sorted(set(vals)))
refs=quote([r['ASIGNACION_ID'] for r in sections['COBRANZAS_ORIGINALES']]+[r['FACTURA'] for r in sections['COBRANZAS_ORIGINALES'] if r['FACTURA']]+[str(r['AGRUPACION']) for r in sections['CONTROLES_ORIGINALES']]+[str(r['AGRUPACION'])+'.00' for r in sections['CONTROLES_ORIGINALES']]+['CHD-33522'])
guards={
 'COBRANZAS':('CFDI_COBRANZA',f"ASIGNACION_ID IN ({quote(r['ASIGNACION_ID'] for r in sections['COBRANZAS_ORIGINALES'])})"),
 'DOCUMENTOS':('CFDI_DOCUMENTOS',f'NOTA_VENTA IN ({refs})'),
 'LAYOUTS':('CFDI_DOCUMENTOS_ENVIAR',f'NOTA_VENTA IN ({refs})'),
 'CONTROL_529057':('CFDI_AGRUPACION_CTRL','AGRUPACION=529057'),
 'OTRAS_RELACIONES_CANCELACION':('CFDI_AGRUPACION_PAGO',f"(ASIGNACION_ID='{CANCEL}' AND (AGRUPACION<>514967 OR AGRUPACION IS NULL)) OR AGRUPACION=529057")}
def hs(table,where='1=1'):
 return f"SELECT H,COUNT_BIG(*) N FROM (SELECT HASHBYTES('SHA2_256',(SELECT T.* FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) H FROM {table} T WITH(HOLDLOCK) WHERE {where}) X GROUP BY H"
def diff(a,b):return f'EXISTS({a} EXCEPT {b}) OR EXISTS({b} EXCEPT {a})'
def targetdiff(t,prefix):return diff(hs(f'T3.[{t}]','AGRUPACION=514967'),hs(f'[{S}].[{prefix}_{t}]'))
def protections():return [f"IF {diff(hs('T3.['+t+']',w),f'SELECT H,N FROM [{S}].Protegido WHERE Objeto=\'{label}\'')} THROW 53306,'Cambio en datos protegidos: {label}.',1;" for label,(t,w) in guards.items()]
header='''USE [T3QA];
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
IF @@TRANCOUNT<>0 THROW 53300,'Ejecutar sin transaccion externa.',1;
DECLARE @TimeoutAnterior int=@@LOCK_TIMEOUT;
DECLARE @RestaurarTimeout nvarchar(80)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@TimeoutAnterior);
SET LOCK_TIMEOUT 15000;
'''
end='''END TRY BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
EXEC(@RestaurarTimeout);
THROW;
END CATCH;'''
def write(n,x):(HERE/n).write_text('\n'.join(x)+'\n',encoding='utf-8')
capture=[header,f"IF SCHEMA_ID('{S}') IS NOT NULL THROW 53301,'Ya existe la captura; no sobrescribir.',1;",'BEGIN TRY BEGIN TRANSACTION;',f"EXEC(N'CREATE SCHEMA [{S}] AUTHORIZATION dbo');",
f"CREATE TABLE [{S}].Estado(Id int PRIMARY KEY CHECK(Id=1),Fase varchar(20),Captura datetime2,Aplicacion datetime2 NULL,HashOrigen varchar(64));",
f"INSERT [{S}].Estado VALUES(1,'CAPTURADO',SYSDATETIME(),NULL,'{hashlib.sha256(raw).hexdigest()}');",
f"CREATE TABLE [{S}].Protegido(Objeto varchar(40),H binary(32),N bigint);",
f"IF (SELECT COUNT_BIG(*) FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='{CANCEL}')<>1 OR NOT EXISTS(SELECT 1 FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='{CANCEL}' AND FACTURA='CHD-33522' AND NOTA_VENTA='CHD-33522' AND STATUS='Canc Pago' AND FECHA_ENVIO IS NULL) THROW 53302,'La cancelacion valida cambio.',1;",
"IF (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967)<>2 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967 AND FECHA_PAGO='20260721' AND RFC='GOSL721114382' AND FECHA_ENVIO IS NOT NULL)<>1 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967 AND FECHA_PAGO='20261001' AND RFC='GOGL7504061AA' AND FECHA_ENVIO IS NULL)<>1 THROW 53303,'Controles diferentes del reporte revisado.',1;",
f"IF (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967)<>2 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967 AND ASIGNACION_ID='{LEGIT}' AND FECHA_PAGO='20260721')<>1 OR (SELECT COUNT_BIG(*) FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967 AND ASIGNACION_ID='{CANCEL}' AND FECHA_PAGO='20261001')<>1 THROW 53304,'Relaciones diferentes del reporte revisado.',1;"]
for t,rows in data.items():
 capture += [f"SELECT {cols(t)} INTO [{S}].[Antes_{t}] FROM T3.[{t}] WITH(HOLDLOCK) WHERE AGRUPACION=514967 OPTION(MAXDOP 1);",f"SELECT TOP(0) {cols(t)} INTO [{S}].[Origen_{t}] FROM T3.[{t}] OPTION(MAXDOP 1);"]
 for r in rows:
  vals=','.join(loader.literal(r[c],typ,n) for c,typ,n in meta[t]['columns'])
  capture += [f"INSERT [{S}].[Origen_{t}]({cols(t)}) VALUES({vals});"]
capture += [f"CREATE TABLE [{S}].SelloOrigen(Objeto varchar(40),H binary(32),N bigint);"]
for t in data:capture += [f"INSERT [{S}].SelloOrigen SELECT '{t}',H,N FROM ({hs('['+S+'].[Origen_'+t+']')}) G;"]
for label,(t,w) in guards.items():capture += [f"INSERT [{S}].Protegido SELECT '{label}',H,N FROM ({hs('T3.['+t+']',w)}) G OPTION(MAXDOP 1);"]
capture += [f"SELECT * INTO [{S}].CancelacionValida FROM T3.CFDI_COBRANZA WITH(HOLDLOCK) WHERE ASIGNACION_ID='{CANCEL}' OPTION(MAXDOP 1);",'COMMIT; EXEC(@RestaurarTimeout);',end,f'SELECT * FROM [{S}].Estado;']
write('01_CAPTURAR.sql',capture)
review=[header,f'SELECT * FROM [{S}].Estado;',f'SELECT * FROM [{S}].CancelacionValida;']
for t in data:review += [f"SELECT '{t}: ANTES' Seccion,* FROM [{S}].[Antes_{t}];",f"SELECT '{t}: DESPUES PROPUESTO' Seccion,* FROM [{S}].[Origen_{t}];"]
review += ['EXEC(@RestaurarTimeout);'];write('02_REVISAR.sql',review)
def restrictions(t):return f"IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID('T3.{t}') AND is_disabled=0) OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID('T3.{t}') AND is_disabled=0) THROW 53307,'Revisar triggers/FK de {t}.',1;"
repair=[header,'-- Predeterminado: ensayo con rollback.\nDECLARE @Aplicar bit=0;', 'BEGIN TRY BEGIN TRANSACTION;',f"DECLARE @Fase varchar(20); SELECT @Fase=Fase FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1;",
"IF @Fase='APLICADO' BEGIN ROLLBACK; EXEC(@RestaurarTimeout); SELECT 'YA APLICADO' Resultado; RETURN; END;",
"IF @Fase<>'CAPTURADO' OR @Fase IS NULL THROW 53305,'Falta captura valida.',1;"]
for t in data:repair += [restrictions(t),f"SELECT COUNT_BIG(*) FilasAntes FROM T3.[{t}] WITH(UPDLOCK,HOLDLOCK) WHERE AGRUPACION=514967 OPTION(MAXDOP 1);",f"IF {targetdiff(t,'Antes')} THROW 53308,'Destino cambio desde la captura.',1;",f"IF {diff(hs('['+S+'].[Origen_'+t+']'),f'SELECT H,N FROM [{S}].SelloOrigen WHERE Objeto=\'{t}\'')} THROW 53309,'Origen preparado modificado.',1;"]
repair+=protections()
repair += ["DELETE FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967;","DELETE FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967;"]
for t in data:repair += [f"INSERT T3.[{t}]({cols(t)}) SELECT {cols(t)} FROM [{S}].[Origen_{t}];",f"IF {targetdiff(t,'Origen')} THROW 53310,'Verificacion de reparacion fallo.',1;"]
repair+=protections()
repair += [f"IF @Aplicar=1 BEGIN UPDATE [{S}].Estado SET Fase='APLICADO',Aplicacion=SYSDATETIME() WHERE Id=1; COMMIT; SELECT 'APLICADO' Resultado; END ELSE BEGIN ROLLBACK; SELECT 'ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS' Resultado; END;",'EXEC(@RestaurarTimeout);',end];write('03_REPARAR.sql',repair)
verify=[header,f'SELECT * FROM [{S}].Estado;']
for t in data:verify += [f"SELECT '{t}' Tabla,CASE WHEN {targetdiff(t,'Origen')} THEN 'DIFERENCIAS' ELSE 'IGUAL A ORIGEN HISTORICO' END Resultado;"]
for label,(t,w) in guards.items():verify += [f"SELECT '{label}' Protegido,CASE WHEN {diff(hs('T3.['+t+']',w),f'SELECT H,N FROM [{S}].Protegido WHERE Objeto=\'{label}\'')} THEN 'CAMBIO: REVISAR' ELSE 'SIN CAMBIOS' END Resultado;"]
verify += ["SELECT * FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967;","SELECT * FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967;",f"SELECT ASIGNACION_ID,FACTURA,NOTA_VENTA,STATUS,FECHA_ENVIO FROM T3.CFDI_COBRANZA WHERE ASIGNACION_ID='{CANCEL}';",f"SELECT * FROM T3.CFDI_AGRUPACION_PAGO WHERE ASIGNACION_ID='{CANCEL}';",'EXEC(@RestaurarTimeout);'];write('04_VERIFICAR.sql',verify)
undo=[header,'DECLARE @Revertir bit=0;',"IF @Revertir<>1 THROW 53311,'Cambiar @Revertir a 1 solo si se decide revertir.',1;",'BEGIN TRY BEGIN TRANSACTION;',f"IF NOT EXISTS(SELECT 1 FROM [{S}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1 AND Fase='APLICADO') THROW 53312,'Paquete no aplicado.',1;"]
for t in data:undo += [restrictions(t),f"SELECT COUNT_BIG(*) FilasActuales FROM T3.[{t}] WITH(UPDLOCK,HOLDLOCK) WHERE AGRUPACION=514967 OPTION(MAXDOP 1);",f"IF {targetdiff(t,'Origen')} THROW 53313,'Cambios posteriores; no revertir automaticamente.',1;"]
undo+=protections();undo += ['DELETE FROM T3.CFDI_AGRUPACION_PAGO WHERE AGRUPACION=514967;','DELETE FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION=514967;']
for t in data:undo += [f"INSERT T3.[{t}]({cols(t)}) SELECT {cols(t)} FROM [{S}].[Antes_{t}];",f"IF {targetdiff(t,'Antes')} THROW 53314,'Fallo restauracion del respaldo.',1;"]
undo += [f"UPDATE [{S}].Estado SET Fase='REVERTIDO' WHERE Id=1; COMMIT; EXEC(@RestaurarTimeout);",end];write('05_REVERTIR.sql',undo)

pre='''/* SOLO LECTURA. Ejecutar despues de verificar la reparacion.
   Esta primera parte revisa metadatos y estado global del liberador.
   La segunda parte proyecta los datos con nDias=30 usando GETDATE del servidor.
   No llama CHECK ni consume secuencias. No altera LOG_START ni crea componente.
*/
USE [T3QA];
SET NOCOUNT ON;
SELECT @@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() HoraServidor,
       CAST(DATEADD(day,-30,GETDATE()) AS date) FechaProcesoLimiteExclusivo;
SELECT Component,Name,Status,Last_Run FROM EAI_OWNER.MX_COMPONENTS WHERE Component IN (613,614);
SELECT OBJECT_DEFINITION(OBJECT_ID('EAI_OWNER.LOG_START')) DefinicionLogStart;
SELECT SCHEMA_NAME(schema_id) Esquema,name,current_value,maximum_value,increment,is_exhausted
FROM sys.sequences WHERE name IN ('SEQ_CFD','SEQ_PAGO_CENTRAL_AGR','ProcessID');
SELECT name,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules M
JOIN sys.objects O ON O.object_id=M.object_id
WHERE O.object_id IN (OBJECT_ID('T3.PROC_CFDI_PROCESA_PAGO_AGR'),
 OBJECT_ID('T3.PROC_CFDI_LIBERA_PAGO_CENTRAL'),OBJECT_ID('T3.PROC_V20_GENERAR_PAGO_AGR'));
-- El contrato del LOG_START local solo hace UPDATE. Un componente inexistente
-- no es por si solo prueba de que la generacion vaya a fallar; revisar instalado.
SELECT 'PENDIENTES_GLOBALES_614' Seccion,A.*
FROM T3.CFDI_AGRUPACION_CTRL A
WHERE A.Fecha_Envio IS NULL AND A.Fecha_Pago>='20220101' AND A.Accnt_ID<>'Contado';
-- El UPDATE inicial del agrupador es mas amplio que el filtro de candidatos.
SELECT 'ALCANCE_UPDATE_INICIAL' Seccion,COUNT_BIG(*) FilasJoin,
 COUNT(DISTINCT C.Asignacion_ID) Asignaciones
FROM T3.CFDI_Cobranza C
JOIN EAI_OWNER.TMP_ACCOUNT_HEADER A ON SUBSTRING(C.Asignacion_ID,3,10)=A.ClearingDocNumber
 AND A.FiscalYear=CONVERT(varchar(4),YEAR(GETDATE()))
JOIN T3.REGISTRO_FISCAL RF ON RF.Factura=C.Factura
WHERE C.Fecha_Proceso>CAST(DATEADD(day,-30,GETDATE()) AS date)
 AND C.Asignacion_Central IS NULL
 AND ISNULL(A.Assignment,RF.Entrega)<>RF.Entrega
 AND ISNULL(A.Assignment,RF.Entrega)<>'B001 - Bank I'
 AND ISNULL(A.Assignment,RF.Entrega)<>C.Factura+','
 AND ISNULL(A.Assignment,RF.Entrega) NOT LIKE '1-1%'
 AND ISNULL(A.Assignment,RF.Entrega)<>RF.Referencia;
'''
existing=(HERE.parent/'Prevalidacion_Pago_AGR/02_DATOS_30_DIAS.sql').read_text(encoding='utf-8-sig')
write('06_PREVALIDAR_30_DIAS.sql',[pre,existing])
print('Generados scripts en',HERE)
