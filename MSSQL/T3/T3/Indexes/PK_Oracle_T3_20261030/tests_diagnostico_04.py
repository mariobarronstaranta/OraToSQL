"""Prueba del diagnostico 04 en una base LocalDB exclusiva y descartable."""
from pathlib import Path
import subprocess
import uuid

here = Path(__file__).resolve().parent
db = 'CodexPK04_' + uuid.uuid4().hex[:8]

def sql(text, database='master'):
    result = subprocess.run(
        ['sqlcmd', '-S', r'(localdb)\MSSQLLocalDB', '-E', '-No', '-b', '-I',
         '-f', '65001', '-d', database], input=text, encoding='utf-8',
        capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

made = False
try:
    sql(f'CREATE DATABASE [{db}]')
    made = True
    sql('''CREATE SCHEMA T3;
GO
CREATE TABLE T3.CC_PANTALLA(PANTALLA int NULL);
CREATE UNIQUE INDEX CC_PANTALLA_PK ON T3.CC_PANTALLA(PANTALLA);
INSERT T3.CC_PANTALLA VALUES(1),(2);
CREATE TABLE T3.MOV_CLIENTE(CLIENTE_V3 int NULL);
INSERT T3.MOV_CLIENTE VALUES(NULL),(1),(1);
CREATE TABLE T3.USUARIOS(USUARIO varchar(20) NULL);
CREATE UNIQUE INDEX USUARIO_PK ON T3.USUARIOS(USUARIO);
ALTER INDEX USUARIO_PK ON T3.USUARIOS DISABLE;
INSERT T3.USUARIOS VALUES('duplicado'),('duplicado');
''', db)
    script = (here/'04_VALIDAR_DATOS_Y_PROPIEDADES.sql').read_text(encoding='utf-8-sig')
    script = script.replace('USE [T3QA];', f'USE [{db}];')
    checks = '''
IF (SELECT COUNT(*) FROM @Resultado)<>81 THROW 56901,'Inventario incompleto',1;
IF (SELECT COUNT(*) FROM @Resultado WHERE Estado='OMITIDA_NO_VISIBLE')<>78 THROW 56902,'Faltantes incorrectos',1;
IF NOT EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='CC_PANTALLA' AND Estado='DATOS_VALIDOS' AND ColumnasNullable=1 AND FilasConNull=0 AND GruposDuplicados=0) THROW 56903,'Fallo indice activo',1;
IF NOT EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='MOV_CLIENTE' AND Estado='BLOQUEADA_DATOS' AND FilasConNull=1 AND GruposDuplicados=1) THROW 56904,'Fallo NULL y duplicados',1;
IF NOT EXISTS(SELECT 1 FROM @Resultado WHERE Tabla='USUARIOS' AND Estado='BLOQUEADA_DATOS' AND GruposDuplicados=1) THROW 56905,'Fallo indice deshabilitado',1;
IF EXISTS(SELECT 1 FROM sys.key_constraints WHERE type='PK') THROW 56906,'Creo PK',1;
IF EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('T3.CC_PANTALLA') AND is_nullable=0) THROW 56907,'Modifico nullabilidad',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('T3.USUARIOS') AND name='USUARIO_PK' AND is_disabled=1) THROW 56908,'Modifico indice',1;
'''
    output = sql(script.replace("SELECT '01_DATOS'", checks + "\nSELECT '01_DATOS'", 1), db)
    assert '03_PROPIEDADES_INDICE' in output
    print('PASS: 81 claves; 78 omitidas; indice activo; NULL y duplicados; indice deshabilitado; sin cambios de PK, nullabilidad ni indice; propiedades fisicas.')
finally:
    if made:
        sql(f'ALTER DATABASE [{db}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{db}];')
        print('Base temporal eliminada: ' + db)
