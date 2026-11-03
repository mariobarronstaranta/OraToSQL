"""Genera propuestas como texto para revisar; no ejecuta DDL ni conecta SQL."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
candidates=[
 ('T3.CFDI_COBRANZA','IX_PERF_COBRANZA_PENDIENTE_PROCESO',['Fecha_Proceso'],
  ['Fecha_Envio','Asignacion_ID','Factura','Fecha_Pago','RFC','Via_Pago','Banco_Nombre','Banco_Num_Cuenta',
   'Asignacion_Central','Importe','Accnt_ID','Cliente_SAP','Created_By','Status'],'[Fecha_Envio] IS NULL',
  'Agrupacion y marcado recientes. Pesar selectividad y costo de mantener/remover filas pendientes.'),
 ('EAI_OWNER.TMP_ACCOUNT_HEADER','IX_PERF_ACCOUNT_CLEARING_YEAR',['ClearingDocNumber','FiscalYear'],
  ['Assignment'],'','Buscar compensacion/ejercicio desde cobranzas recientes; los IXDOC locales tienen otra columna inicial.'),
 ('T3.WA_FACTORAJE','IX_PERF_FACTORAJE_FACTURA',['Factura'],[], '',
  'Anti join de factoraje repetido; revisar si ya hay clave inicial Factura.'),
 ('T3.CFDI_AGRUPACION_PAGO','IX_PERF_AGRUPACION_ASIGNACION',['Agrupacion','Asignacion_ID'],
  ['Fecha_Pago'],'','CHECK, detalle de generacion y marcado: localizar asignaciones por grupo.'),
 ('T3.CFDI_COBRANZA','IX_PERF_COBRANZA_ASIGNACION',['Asignacion_ID'],
  ['Nota_Venta','UUID_Venta','Fecha_Asignacion','Fecha_Factura','Factura','Numero_Pago','Saldo_Anterior','Importe'],'',
  'CHECK y detalle del generador; conserva multiplicidad, no es UNIQUE.'),
 ('T3.CFDI_DOCUMENTOS','IX_PERF_DOCUMENTO_METODO',['Nota_Venta'],['Metodo_Pago'],'',
  'Cruce del CHECK con documentos; comparar con indices mas amplios existentes.'),
 ('T3.CFDI_AGRUPACION_CTRL','IX_PERF_CTRL_PENDIENTE_CENTRAL',['Fecha_Pago','Agrupacion'],
  ['Fecha_Envio','Accnt_ID','RFC'],"[Fecha_Envio] IS NULL AND [Accnt_ID] <> 'Contado'",
  'Cursor de liberacion global: mismos filtros de pendientes y exclusion Contado/NULL.'),
 ('T3.CFDI_RFC_SETTING','IX_PERF_RFC_SETTING_PARAMETRO',['Parametro','RFC'],['Valor'],'',
  'Configuracion por RFC/parametro, con MAX(Valor); medir costo real antes de agregar.'),
]
def lit(value):return "N'"+value.replace("'","''")+"'"
seed=[]
parts=[]
for ident,(table,name,keys,includes,predicate,note) in enumerate(candidates,1):
    cols=','.join('['+col+']' for col in keys)
    include=','.join('['+col+']' for col in includes)
    ddl='CREATE NONCLUSTERED INDEX ['+name+'] ON '+'.'.join('['+t+']' for t in table.split('.'))+' ('+cols+')'
    if includes:ddl+=' INCLUDE ('+include+')'
    if predicate:ddl+=' WHERE '+predicate
    ddl+=';'
    seed.append('('+','.join([str(ident),lit(table),lit(name),lit(cols),lit(include),lit(predicate),lit(note),lit(ddl)])+')')
    for role,values in [('K',keys),('I',includes)]:
        for pos,col in enumerate(values,1):parts.append(f'({ident},{lit(role)},{pos},{lit(col)})')
sql='''/* SOLO LECTURA. Devuelve DDL COMO TEXTO, no crea ni elimina indices.
   Candidatos para decidir DESPUES de revisar tiempos, planes e inventario real.
   El prefijo de clave no certifica equivalencia: revisar filtro, INCLUDE,
   estado, unicidad, tipos y costo de escritura. No crear todos de una vez.
   La comparacion por prefijo muestra indices existentes aunque tengan otro
   nombre y mas columnas. No reutiliza ni convierte PK o indices existentes.
*/
USE [T3QA]; SET NOCOUNT ON;
DECLARE @C table(Id int PRIMARY KEY,Tabla nvarchar(256) COLLATE DATABASE_DEFAULT,
 Nombre sysname COLLATE DATABASE_DEFAULT,Claves nvarchar(2000) COLLATE DATABASE_DEFAULT,
 Incluidas nvarchar(4000),Filtro nvarchar(4000),Motivo nvarchar(1000),DDL nvarchar(max));
INSERT @C VALUES
__CANDIDATES__;
DECLARE @P table(Id int,Rol char(1),Posicion int,Columna sysname COLLATE DATABASE_DEFAULT);
INSERT @P VALUES
__PARTS__;
SELECT '00_ADVERTENCIA' Seccion,'PROPUESTAS, NO MEDICIONES. No ejecutar DDL sin revisar 01/02 y planes.' Mensaje;
SELECT C.Id,C.Tabla,C.Nombre IndiceCandidato,C.Claves,C.Incluidas,C.Filtro,C.Motivo,
       CASE WHEN OBJECT_ID(C.Tabla,'U') IS NULL THEN 'TABLA AUSENTE O NO VISIBLE'
            WHEN V.Faltantes>0 THEN 'COLUMNAS AUSENTES O NO VISIBLES'
            WHEN A.name IS NULL AND EXISTS(SELECT 1 FROM sys.indexes I
              WHERE I.object_id=OBJECT_ID(C.Tabla,'U') AND I.name COLLATE DATABASE_DEFAULT=C.Nombre)
              THEN 'NOMBRE CANDIDATO OCUPADO; PREFIJO DIFERENTE'
            WHEN A.name IS NOT NULL THEN 'PREFIJO EXISTENTE: COMPARAR FILTRO/INCLUDE/ESTADO'
            ELSE 'NO SE VE PREFIJO EQUIVALENTE; MEDIR ANTES DE CREAR' END Revision,
       A.name IndiceActualConPrefijo,A.type_desc TipoActual,A.is_unique UnicoActual,A.is_primary_key EsPKActual,
       A.is_disabled Deshabilitado,A.filter_definition FiltroActual,A.ColumnasClaveActuales,
       CASE WHEN OBJECT_ID(C.Tabla,'U') IS NOT NULL AND V.Faltantes=0
              AND NOT EXISTS(SELECT 1 FROM sys.indexes I WHERE I.object_id=OBJECT_ID(C.Tabla,'U')
                AND I.name COLLATE DATABASE_DEFAULT=C.Nombre)
            THEN C.DDL END DDL_Candidato_NoEjecutado
FROM @C C
OUTER APPLY(SELECT COUNT(*) Faltantes FROM @P P
    WHERE P.Id=C.Id AND NOT EXISTS(SELECT 1 FROM sys.columns X
      WHERE X.object_id=OBJECT_ID(C.Tabla,'U') AND X.name COLLATE DATABASE_DEFAULT=P.Columna)) V
OUTER APPLY(
    SELECT I.name,I.type_desc,I.is_unique,I.is_primary_key,I.is_disabled,I.filter_definition,K.ColumnasClaveActuales
    FROM sys.indexes I
    CROSS APPLY(SELECT STUFF((SELECT N','+QUOTENAME(X.name) FROM sys.index_columns IC
        JOIN sys.columns X ON X.object_id=IC.object_id AND X.column_id=IC.column_id
        WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0
        ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') ColumnasClaveActuales) K
    WHERE I.object_id=OBJECT_ID(C.Tabla,'U') AND I.index_id>0
      AND LEFT(K.ColumnasClaveActuales,LEN(C.Claves)) COLLATE DATABASE_DEFAULT=C.Claves
      AND (LEN(K.ColumnasClaveActuales)=LEN(C.Claves) OR SUBSTRING(K.ColumnasClaveActuales,LEN(C.Claves)+1,1)=',')
) A
ORDER BY C.Id,A.name;
'''
(HERE/'03_PROPUESTAS_INDICES_SOLO_TEXTO.sql').write_text(
 sql.replace('__CANDIDATES__',',\n'.join(seed)).replace('__PARTS__',',\n'.join(parts)),encoding='utf-8')
(HERE/'candidatos_indices.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2),encoding='utf-8')
print('Generadas 8 propuestas de indices como texto, sin ejecutar DDL.')
