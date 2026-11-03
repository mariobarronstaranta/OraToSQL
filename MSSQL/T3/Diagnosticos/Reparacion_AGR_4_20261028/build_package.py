"""Genera SQL explicito desde el DDL versionado; no conecta a bases."""
from pathlib import Path
import re, json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SCHEMA = 'REPAIR_AGR_20261028'
IDS = "'262201997234','262201997964','262201997720','262201997198'"
FACT = "'V0225-134949','V0822-105802','V0179-67553','V0440-70133'"
GROUPS = '514957,514969,514981,514984,529050,529096,529120,529179'
SCOPES = {
 'CFDI_COBRANZA': f'ASIGNACION_ID IN ({IDS})',
 'CFDI_AGRUPACION_CTRL': f'AGRUPACION IN ({GROUPS})',
 'CFDI_AGRUPACION_PAGO': f'AGRUPACION IN ({GROUPS}) OR ASIGNACION_ID IN ({IDS})',
 'REGISTRO_FISCAL': f'FACTURA IN ({FACT})',
 'REGISTRO_FISCAL_DETALLE': f'FACTURA IN ({FACT})',
}
META = {}
for table, scope in SCOPES.items():
    raw = (ROOT / f'MSSQL/T3/T3/Tables/T3.{table}.Table.sql').read_bytes()
    ddl = raw.decode('utf-16') if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else raw.decode('utf-8-sig')
    cols = re.findall(r'^\s*\[(\w+)\]\s+\[(\w+)\](\([^)]*\))?\s+NULL', ddl, re.M)
    if not cols: raise ValueError(table)
    META[table] = {'scope':scope,'columns':cols}
(HERE/'schema.json').write_text(json.dumps(META,indent=2),encoding='utf-8')

def write(name, text):
    (HERE/name).write_text(text.strip()+'\n', encoding='utf-8')

header = '''USE [T3QA];
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF @@TRANCOUNT<>0 THROW 52900,'Ejecutar sin transaccion externa.',1;
'''

oracle = ["-- Oracle 19c+. SQL*Plus/SQLcl, ejecutar desde carpeta de exportacion vacia.",
 "-- Una transaccion READ ONLY asegura el mismo corte de datos para todos los archivos.",
 "-- Usar sesion NUEVA, sin trabajo pendiente. No se ejecuta NEXTVAL.",
 "WHENEVER SQLERROR EXIT FAILURE ROLLBACK", "SET ECHO OFF FEEDBACK OFF HEADING OFF PAGESIZE 0 VERIFY OFF",
 "SET LONG 10000000 LONGCHUNKSIZE 32767 LINESIZE 32767 TRIMSPOOL ON TAB OFF",
 "SET TRANSACTION READ ONLY;"]
for table,m in META.items():
    fields=[]
    for c,t,_ in m['columns']:
        val=f'TO_CHAR({c},\'YYYY-MM-DD"T"HH24:MI:SS\')' if t=='datetime2' else c
        fields.append(f"'{c}' VALUE {val}")
    oracle += [f'SPOOL "{ROOT / "ORA/T3/T3/Datos" / (table + ".json")}"',
      "SELECT COALESCE(JSON_ARRAYAGG(JSON_OBJECT("+',\n'.join(fields)+
      f" NULL ON NULL RETURNING CLOB) RETURNING CLOB),TO_CLOB('[]')) FROM T3.{table} WHERE {m['scope']};",
      'SPOOL OFF']
oracle += [f'SPOOL "{ROOT / "ORA/T3/T3/Datos/metadata.json"}"', "SELECT JSON_OBJECT('MAX_CONTROL' VALUE (SELECT MAX(AGRUPACION) FROM T3.CFDI_AGRUPACION_CTRL), 'MAX_DETALLE' VALUE (SELECT MAX(AGRUPACION) FROM T3.CFDI_AGRUPACION_PAGO), 'CAPTURA' VALUE TO_CHAR(SYSDATE,'YYYY-MM-DD\"T\"HH24:MI:SS') RETURNING CLOB) FROM DUAL;",'SPOOL OFF','ROLLBACK;', 'EXIT SUCCESS']
write('01_ORACLE_EXPORTAR.sql','\n'.join(oracle))

setup=[header, f"IF SCHEMA_ID('{SCHEMA}') IS NOT NULL THROW 52901,'Ya existe el paquete: no sobrescribir captura ni respaldo.',1;",
 '-- Captura: bloqueos compartidos serializables, sin TABLOCKX. Evitar paralelismo.\nDECLARE @TimeoutAnterior int=@@LOCK_TIMEOUT; SET LOCK_TIMEOUT 15000;',
 'BEGIN TRY\nBEGIN TRANSACTION;',f"EXEC(N'CREATE SCHEMA [{SCHEMA}] AUTHORIZATION dbo');",
 f"CREATE TABLE [{SCHEMA}].Estado(Id int PRIMARY KEY CHECK(Id=1), Fase varchar(20), Captura datetime2, MaxOrigen decimal(38,0), HashOrigen varchar(64), Aplicacion datetime2 NULL);",
 f"INSERT [{SCHEMA}].Estado VALUES(1,'CAPTURADO',SYSDATETIME(),NULL,NULL,NULL);"]
for table,m in META.items():
    cols=','.join('['+c+']' for c,_,_ in m['columns'])
    setup += [f"SELECT {cols} INTO [{SCHEMA}].[Antes_{table}] FROM T3.[{table}] WITH(HOLDLOCK) WHERE {m['scope']} OPTION(MAXDOP 1);",
      f"SELECT TOP(0) {cols} INTO [{SCHEMA}].[Origen_{table}] FROM T3.[{table}] OPTION(MAXDOP 1);"]
setup += ['COMMIT;\nSET LOCK_TIMEOUT @TimeoutAnterior;\nEND TRY\nBEGIN CATCH\nIF XACT_STATE()<>0 ROLLBACK;\nSET LOCK_TIMEOUT @TimeoutAnterior;\nTHROW;\nEND CATCH;',
 f"SELECT * FROM [{SCHEMA}].Estado;"]
for table in META:
    setup += [f"SELECT '{table}' Tabla,COUNT_BIG(*) FilasCapturadas FROM [{SCHEMA}].[Antes_{table}];"]
write('02_MSSQL_CAPTURAR.sql','\n'.join(setup))

# Compare exact row representations INCLUDING multiplicity, NULL, case and blanks.
def compare(left,right,scope_left='1=1',scope_right='1=1'):
    def hashes(tab,scope):
        return f"SELECT HASHBYTES('SHA2_256',(SELECT T.* FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) H FROM {tab} T WHERE {scope}"
    l=f"SELECT H,COUNT_BIG(*) N FROM ({hashes(left,scope_left)}) L GROUP BY H"
    r=f"SELECT H,COUNT_BIG(*) N FROM ({hashes(right,scope_right)}) R GROUP BY H"
    return f"EXISTS({l} EXCEPT {r}) OR EXISTS({r} EXCEPT {l})"

apply=[header, '-- Ensayo por defecto: realiza comprobaciones y DML, luego ROLLBACK.\nDECLARE @Aplicar bit=0;',
 'BEGIN TRY\nBEGIN TRANSACTION;',
 f"DECLARE @Fase varchar(20); SELECT @Fase=Fase FROM [{SCHEMA}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1;",
 "IF @Fase='APLICADO' BEGIN ROLLBACK; SELECT 'YA APLICADO; no se repitieron cambios' Resultado; RETURN; END;",
 "IF @Fase<>'CARGADO' OR @Fase IS NULL THROW 52902,'Falta cargar y validar el origen.',1;",
 '-- Detener productores/jobs antes de capturar y hasta verificar. Bloqueos no reservan NEXT VALUE FOR.']
for table,m in META.items():
    cols=','.join('['+c+']' for c,_,_ in m['columns'])
    apply += [f"IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID('T3.{table}') AND is_disabled=0) THROW 52903,'Revisar triggers de {table} antes de reparar.',1;",
      f"IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID('T3.{table}') AND is_disabled=0) THROW 52904,'Revisar FK entrantes de {table} antes de reparar.',1;",
      f"SELECT COUNT_BIG(*) AS FilasBloqueadas_{table} FROM T3.[{table}] WITH(TABLOCKX,HOLDLOCK) WHERE {m['scope']};",
      f"IF {compare('T3.['+table+']',f'[{SCHEMA}].[Antes_{table}]',m['scope'])} THROW 52905,'Destino cambio desde captura: {table}.',1;",
      f"IF EXISTS(SELECT 1 FROM [{SCHEMA}].[Origen_{table}] WHERE NOT ({m['scope']})) THROW 52906,'Origen fuera del alcance.',1;"]
# Do not silently discard other associations discovered in destination.
apply += [f"IF EXISTS(SELECT 1 FROM [{SCHEMA}].Antes_CFDI_AGRUPACION_PAGO WHERE AGRUPACION NOT IN ({GROUPS})) THROW 52907,'Hay relaciones con otras agrupaciones; ampliar revision, no eliminar automaticamente.',1;",
 f"IF (SELECT COUNT(*) FROM [{SCHEMA}].Origen_CFDI_COBRANZA)<>4 OR (SELECT COUNT(*) FROM [{SCHEMA}].Origen_CFDI_AGRUPACION_CTRL)<>8 OR (SELECT COUNT(*) FROM [{SCHEMA}].Origen_REGISTRO_FISCAL)<>4 OR (SELECT COUNT(*) FROM [{SCHEMA}].Origen_REGISTRO_FISCAL_DETALLE)<>26 THROW 52908,'Conteos origen distintos de los revisados.',1;"]
for table in ('CFDI_DOCUMENTOS','CFDI_DOCUMENTOS_ENVIAR'):
    apply += [f"IF EXISTS(SELECT 1 FROM T3.{table} WITH(UPDLOCK,HOLDLOCK) WHERE NOTA_VENTA IN ('529050','529096','529120','529179','529050.00','529096.00','529120.00','529179.00')) THROW 52916,'Hay salidas para grupos Contado; revisar antes de reparar.',1;"]
order=['CFDI_AGRUPACION_PAGO','CFDI_AGRUPACION_CTRL','CFDI_COBRANZA','REGISTRO_FISCAL_DETALLE','REGISTRO_FISCAL']
for table in order:
    apply += [f"DELETE FROM T3.[{table}] WHERE {META[table]['scope']};"]
for table in reversed(order):
    cols=','.join('['+c+']' for c,_,_ in META[table]['columns'])
    apply += [f"INSERT T3.[{table}]({cols}) SELECT {cols} FROM [{SCHEMA}].[Origen_{table}];",
     f"IF {compare('T3.['+table+']',f'[{SCHEMA}].[Origen_{table}]',META[table]['scope'])} THROW 52909,'La comprobacion posterior fallo: {table}.',1;"]
apply += [f"DECLARE @Max decimal(38,0),@Actual decimal(38,0),@Limite decimal(38,0),@Incremento decimal(38,0),@Proximo decimal(38,0),@SQL nvarchar(300);",
 "SELECT @Actual=CONVERT(decimal(38,0),current_value),@Limite=CONVERT(decimal(38,0),maximum_value),@Incremento=CONVERT(decimal(38,0),increment) FROM sys.sequences WHERE object_id=OBJECT_ID('T3.SEQ_PAGO_CENTRAL_AGR');",
 "IF @Limite IS NULL OR @Incremento<>1 THROW 52910,'Secuencia ausente o incremento no soportado.',1;",
 f"SELECT @Max=MAX(N) FROM (SELECT MAX(AGRUPACION) N FROM T3.CFDI_AGRUPACION_CTRL UNION ALL SELECT MAX(AGRUPACION) FROM T3.CFDI_AGRUPACION_PAGO UNION ALL SELECT MaxOrigen FROM [{SCHEMA}].Estado UNION ALL SELECT @Actual) X;",
 "IF @Max>=@Limite THROW 52911,'Rango agotado de secuencia.',1; SET @Proximo=@Max+1;",
 "SELECT @Aplicar Aplicar,@Proximo ProximoValorPropuesto;",
 "IF @Aplicar=1 BEGIN",
 "SET @SQL=N'ALTER SEQUENCE T3.SEQ_PAGO_CENTRAL_AGR RESTART WITH '+CONVERT(nvarchar(40),@Proximo); EXEC sys.sp_executesql @SQL;",
 f"UPDATE [{SCHEMA}].Estado SET Fase='APLICADO',Aplicacion=SYSDATETIME() WHERE Id=1;",
 "COMMIT; SELECT 'APLICADO' Resultado; END ELSE BEGIN ROLLBACK; SELECT 'ENSAYO CORRECTO; TODOS LOS CAMBIOS REVERTIDOS' Resultado; END;",
 'END TRY\nBEGIN CATCH\nIF XACT_STATE()<>0 ROLLBACK;\nTHROW;\nEND CATCH;']
write('04_MSSQL_REPARAR.sql','\n'.join(apply))

verify=[header, f'SELECT * FROM [{SCHEMA}].Estado;']
for table,m in META.items():
    verify += [f"SELECT '{table}' Tabla,CASE WHEN {compare('T3.['+table+']',f'[{SCHEMA}].[Origen_{table}]',m['scope'])} THEN 'DIFERENCIAS' ELSE 'IGUAL A ORIGEN' END Resultado;"]
verify += [f"SELECT ASIGNACION_ID,NOTA_VENTA,UUID_VENTA,STATUS,FECHA_ENVIO FROM T3.CFDI_COBRANZA WHERE {SCOPES['CFDI_COBRANZA']};",
 f"SELECT * FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION IN (529050,529096,529120,529179);",
 "SELECT 'DOCUMENTOS_NO_ESPERADOS' Seccion,* FROM T3.CFDI_DOCUMENTOS WHERE NOTA_VENTA IN ('529050','529096','529120','529179','529050.00','529096.00','529120.00','529179.00');",
 "SELECT 'LAYOUTS_NO_ESPERADOS' Seccion,NOTA_VENTA,DATALENGTH(INFORMACION) Bytes FROM T3.CFDI_DOCUMENTOS_ENVIAR WHERE NOTA_VENTA IN ('529050','529096','529120','529179','529050.00','529096.00','529120.00','529179.00');",
 "SELECT current_value,increment,maximum_value FROM sys.sequences WHERE object_id=OBJECT_ID('T3.SEQ_PAGO_CENTRAL_AGR');"]
write('05_MSSQL_VERIFICAR.sql','\n'.join(verify))

review=[header,'-- Revisar ANTES de cambiar @Aplicar a 1. No modifica negocio.']
for table,m in META.items():
    review += [f"SELECT '{table}: ANTES' Seccion,* FROM [{SCHEMA}].[Antes_{table}];",
               f"SELECT '{table}: ORACLE' Seccion,* FROM [{SCHEMA}].[Origen_{table}];"]
write('03B_MSSQL_REVISAR_CAMBIOS.sql','\n'.join(review))

undo=[header,'-- Ejecutar solo si se decide revertir; nunca automaticamente.\nDECLARE @Revertir bit=0;',
 "IF @Revertir<>1 THROW 52912,'Cambiar @Revertir a 1 para una reversion deliberada.',1;",
 'BEGIN TRY\nBEGIN TRANSACTION;',
 f"IF NOT EXISTS(SELECT 1 FROM [{SCHEMA}].Estado WITH(UPDLOCK,HOLDLOCK) WHERE Id=1 AND Fase='APLICADO') THROW 52913,'El paquete no esta aplicado.',1;"]
for table,m in META.items():
    undo += [f"SELECT COUNT_BIG(*) FilasBloqueadas FROM T3.[{table}] WITH(TABLOCKX,HOLDLOCK) WHERE {m['scope']};",
     f"IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID('T3.{table}') AND is_disabled=0) OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID('T3.{table}') AND is_disabled=0) THROW 52914,'Revisar triggers/FK antes de revertir.',1;",
     f"IF {compare('T3.['+table+']',f'[{SCHEMA}].[Origen_{table}]',m['scope'])} THROW 52915,'Hay cambios posteriores; no revertir automaticamente.',1;"]
for table in order:
    undo += [f"DELETE FROM T3.[{table}] WHERE {META[table]['scope']};"]
for table in reversed(order):
    cols=','.join('['+c+']' for c,_,_ in META[table]['columns'])
    undo += [f"INSERT T3.[{table}]({cols}) SELECT {cols} FROM [{SCHEMA}].[Antes_{table}];"]
undo += [f"UPDATE [{SCHEMA}].Estado SET Fase='REVERTIDO' WHERE Id=1;",
 'COMMIT;\nEND TRY\nBEGIN CATCH\nIF XACT_STATE()<>0 ROLLBACK;\nTHROW;\nEND CATCH;',
 "-- La secuencia NO se retrocede: evita reutilizar IDs consumidos posteriormente."]
write('06_MSSQL_REVERTIR.sql','\n'.join(undo))
print('Paquete SQL generado en',HERE)
