"""Genera seis correcciones acotadas desde captura 14; preserva indices auxiliares.
Uso inicial: python generar_correcciones_15.py resultado14.txt
Reproducir: python generar_correcciones_15.py
"""
from pathlib import Path
import json,re,sys
HERE=Path(__file__).resolve().parent
OUT=HERE/'15_CORRECCIONES_LOTES_12_AL_17'
OUT.mkdir(exist_ok=True)
keys={k['table']:k for k in json.loads((HERE/'manifest.json').read_text())['keys']}
if len(sys.argv)>1:
 data={}
 for line in Path(sys.argv[1]).read_text(encoding='utf-8-sig').splitlines():
  if not line.startswith('03_INDICES '):continue
  c=line.split();assert len(c)==26,c
  assert c[6:8]==['0','0'] and c[11:18]==['0','0','0','1','1','PRIMARY','ROWS_FILEGROUP']
  assert c[18:20] in (['1','NONE'],['NULL','NULL']) and c[22:24]==['0','0']
  t=c[2];name=c[3]
  d=data.setdefault(t,dict(lote=int(c[1]),indices={}))['indices'].setdefault(name,dict(name=name,type=c[4],unique=int(c[5]),disabled=int(c[8]),filter=None if c[10]=='NULL' else c[10],keys=[],include=[]))
  if int(c[20]):d['keys'].append(c[24])
  elif c[21]=='1':d['include'].append(c[24])
 assert len(data)==6
 (OUT/'captura_indices_14.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
else:data=json.loads((OUT/'captura_indices_14.json').read_text())
def lit(x):return "N'"+x.replace("'","''")+"'"
def cols(cs):return ','.join('['+c+']' for c in cs)
def create(t,i):
 ddl=f"CREATE {'UNIQUE ' if i['unique'] else ''}{i['type']} INDEX [{i['name']}] ON [T3].[{t}] ({cols(i['keys'])})"
 if i['include']:ddl+=' INCLUDE ('+cols(i['include'])+')'
 if i['filter']:ddl+=' WHERE '+i['filter']
 return ddl+' WITH(PAD_INDEX=OFF,IGNORE_DUP_KEY=OFF,STATISTICS_NORECOMPUTE=OFF,ALLOW_ROW_LOCKS=ON,ALLOW_PAGE_LOCKS=ON,DATA_COMPRESSION=NONE) ON [PRIMARY];'
block='''
            -- Solo indices auxiliares cuya definicion completa coincide con la captura.
            DELETE @Actuales;
            INSERT @Actuales
            SELECT I.name,I.is_unique,I.is_disabled,ISNULL(I.filter_definition,N''),
              ISNULL(A.Claves,N''),ISNULL(A.Incluidas,N'')
            FROM sys.indexes I
            OUTER APPLY(SELECT
             STUFF((SELECT N','+QUOTENAME(C.name) FROM sys.index_columns IC
              JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
              WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.key_ordinal>0
              ORDER BY IC.key_ordinal FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') Claves,
             STUFF((SELECT N','+QUOTENAME(C.name) FROM sys.index_columns IC
              JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
              WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id AND IC.is_included_column=1
              ORDER BY IC.index_column_id FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'') Incluidas
            ) A
            WHERE I.object_id=@Objeto AND I.name COLLATE DATABASE_DEFAULT<>@PK
              AND (EXISTS(SELECT 1 FROM @Aux E WHERE E.Nombre=I.name COLLATE DATABASE_DEFAULT)
               OR EXISTS(SELECT 1 FROM sys.index_columns IC JOIN sys.columns C
                ON C.object_id=IC.object_id AND C.column_id=IC.column_id
                JOIN @Origen O ON O.Tabla=@Tabla AND O.Columna=C.name COLLATE DATABASE_DEFAULT
                WHERE IC.object_id=I.object_id AND IC.index_id=I.index_id));
            IF EXISTS(SELECT * FROM @Actuales EXCEPT SELECT * FROM @Aux)
             OR EXISTS(SELECT * FROM @Aux EXCEPT SELECT * FROM @Actuales)
                THROW 56860,'Indices auxiliares distintos de la captura (columnas, INCLUDE, filtro, unicidad o estado); no se aplica.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes I JOIN @Aux E ON E.Nombre=I.name COLLATE DATABASE_DEFAULT
             LEFT JOIN sys.data_spaces DS ON DS.data_space_id=I.data_space_id
             LEFT JOIN sys.stats S ON S.object_id=I.object_id AND S.stats_id=I.index_id
             WHERE I.object_id=@Objeto AND (I.type<>2 OR I.is_primary_key<>0 OR I.is_unique_constraint<>0
              OR I.is_hypothetical<>0 OR I.fill_factor<>0 OR I.is_padded<>0 OR I.ignore_dup_key<>0
              OR I.allow_row_locks<>1 OR I.allow_page_locks<>1 OR ISNULL(DS.name,N'')<>N'PRIMARY'
              OR ISNULL(DS.type,'')<>'FG' OR S.stats_id IS NULL OR S.no_recompute<>0 OR S.is_incremental<>0))
                THROW 56861,'Opciones fisicas/estadisticas de indices auxiliares no soportadas; no se aplica.',1;
            IF EXISTS(SELECT 1 FROM sys.indexes I JOIN @Aux E ON E.Nombre=I.name COLLATE DATABASE_DEFAULT
             JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
             WHERE I.object_id=@Objeto AND (IC.is_descending_key=1 OR IC.partition_ordinal<>0))
             OR EXISTS(SELECT 1 FROM sys.indexes I JOIN @Aux E ON E.Nombre=I.name COLLATE DATABASE_DEFAULT
              JOIN sys.partitions P ON P.object_id=I.object_id AND P.index_id=I.index_id
              WHERE I.object_id=@Objeto AND (P.partition_number<>1 OR P.data_compression<>0))
             OR EXISTS(SELECT 1 FROM sys.indexes I JOIN @Aux E ON E.Nombre=I.name COLLATE DATABASE_DEFAULT
              JOIN sys.foreign_keys F ON F.referenced_object_id=I.object_id AND F.key_index_id=I.index_id WHERE I.object_id=@Objeto)
             OR EXISTS(SELECT 1 FROM sys.indexes I JOIN @Aux E ON E.Nombre=I.name COLLATE DATABASE_DEFAULT
              JOIN sys.extended_properties EP ON EP.class=7 AND EP.major_id=I.object_id AND EP.minor_id=I.index_id WHERE I.object_id=@Objeto)
                THROW 56862,'Dependencias, compresion, particionado o direccion de auxiliares no soportados.',1;
            SET @Prefijo=@DropAux+@Prefijo;
'''
for t,d in sorted(data.items(),key=lambda x:x[1]['lote']):
 k=keys[t];aux=[i for i in d['indices'].values() if i['name']!=k['name'] and set(i['keys']+i['include'])&set(k['columns'])]
 assert aux and all(i['type']=='NONCLUSTERED' for i in aux)
 d['auxiliares']=[i['name'] for i in aux]
 source=HERE/'08_LOTES_PK_20261106'/f"{d['lote']:02d}_{t}.sql"
 s=source.read_text(encoding='utf-8-sig');s=s[s.index('USE [T3QA];'):]
 decl='''DECLARE @Aux table(Nombre sysname COLLATE DATABASE_DEFAULT,EsUnico bit,Deshabilitado bit,
 Filtro nvarchar(2000) COLLATE DATABASE_DEFAULT,Claves nvarchar(2000) COLLATE DATABASE_DEFAULT,Incluidas nvarchar(2000) COLLATE DATABASE_DEFAULT);
DECLARE @Actuales table(Nombre sysname COLLATE DATABASE_DEFAULT,EsUnico bit,Deshabilitado bit,
 Filtro nvarchar(2000) COLLATE DATABASE_DEFAULT,Claves nvarchar(2000) COLLATE DATABASE_DEFAULT,Incluidas nvarchar(2000) COLLATE DATABASE_DEFAULT);
INSERT @Aux VALUES
'''+',\n'.join(f"({lit(i['name'])},{i['unique']},{i['disabled']},{lit(i['filter'] or '')},{lit(cols(i['keys']))},{lit(cols(i['include']))})" for i in aux)+';\n'
 drop='\n'.join(f"DROP INDEX [{i['name']}] ON [T3].[{t}];" for i in aux)+'\n'
 recreate='\n'.join(create(t,i)+(f"\nALTER INDEX [{i['name']}] ON [T3].[{t}] DISABLE;" if i['disabled'] else '') for i in aux)
 decl+=f'DECLARE @DropAux nvarchar(max)={lit(drop)},@RecrearAux nvarchar(max)={lit(recreate)};\n'
 s=s.replace('DECLARE @IndiceReemplazo int,',decl+'DECLARE @IndiceReemplazo int,')
 s=s.replace('            SELECT @Nullable=SUM',block+'            SELECT @Nullable=SUM',1)
 s=s.replace("            UPDATE @Plan SET Estado='LISTA',Observacion=", "            SET @DDL+=CHAR(13)+CHAR(10)+N'EXEC sys.sp_executesql N'''+REPLACE(@RecrearAux,N'''',N'''''')+N''';';\n            UPDATE @Plan SET Estado='LISTA',Observacion=")
 s=s.replace("N'Reemplazar indice equivalente por PK activa; datos validados.'", "N'Reemplazar PK y recrear auxiliares especificados en la misma transaccion; preservar estado deshabilitado.'")
 s=s.replace('Solo se reemplazaron los indices equivalentes indicados en el plan.','Se reemplazo la PK y se recrearon sus indices auxiliares conservando su estado.')
 s='''/* CORRECCION INDIVIDUAL. Sustituye el lote original del mismo numero.
   Captura T3QA 2026-11-06 01:11:08 -06:00. @Aplicar=0 por defecto.
   Conserva claves, INCLUDE, filtro, unicidad y estado de auxiliares.
   Los auxiliares deshabilitados se crean y deshabilitan dentro de la transaccion;
   su construccion tambien consume tiempo, espacio y log. Compresion NONE.
   Un fallo revierte toda la tabla. No ejecutar archivos en paralelo.
   Los otros indices y datos no se modifican. Ejecutar solo esta tabla.
*/\n'''+s
 s+='''
SELECT I.name,I.type_desc,I.is_primary_key,I.is_unique,I.is_disabled,I.filter_definition,
 IC.key_ordinal,IC.is_included_column,C.name Columna,C.is_nullable
FROM sys.indexes I JOIN sys.index_columns IC ON IC.object_id=I.object_id AND IC.index_id=I.index_id
JOIN sys.columns C ON C.object_id=IC.object_id AND C.column_id=IC.column_id
WHERE I.object_id=OBJECT_ID(N'T3.'''+t+''') AND
 (I.is_primary_key=1 OR EXISTS(SELECT 1 FROM @Aux A WHERE A.Nombre=I.name COLLATE DATABASE_DEFAULT))
ORDER BY I.name,IC.index_column_id;
'''
 # Tres comillas para cerrar el literal T3.tabla en la cadena generada.
 s=s.replace("OBJECT_ID(N'T3."+t+")", "OBJECT_ID(N'T3."+t+"')")
 (OUT/f"{d['lote']:02d}_{t}_CORREGIDO.sql").write_text(s,encoding='utf-8-sig')
 print(t,len(aux),'auxiliares')
(OUT/'plan.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
