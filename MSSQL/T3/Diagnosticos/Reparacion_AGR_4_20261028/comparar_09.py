"""Compara el reporte SSMS del 09 con el JSONL Oracle; no conecta a bases."""
import argparse,json,re
from pathlib import Path
from collections import Counter,defaultdict
from decimal import Decimal
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
p=argparse.ArgumentParser();p.add_argument('reporte',type=Path);args=p.parse_args()
lines=args.reporte.read_text(encoding='utf-8-sig').splitlines()
sections=defaultdict(list);cols=[]
for i,line in enumerate(lines):
    if line.startswith('Seccion ') and i+1<len(lines):
        cols=[(line[m.start():m.end()].strip(),m.start(),m.end()) for m in re.finditer(r'-+',lines[i+1])]
    if re.match(r'^\d\d_\w+ ',line):
        row={name:line[start:end].strip() for name,start,end in cols}
        sections[row.pop('Seccion')].append(row)
oracle=defaultdict(list)
for line in (ROOT/'ORA/T3/T3/Datos/Resultados_28_Oracle.jsonl').read_text(encoding='utf-8-sig').splitlines():
    if line.strip():
        j=json.loads(line,parse_float=Decimal);oracle[j['SECCION']].append(j['FILA'])
print('SECCIONES', {s:len(r) for s,r in sections.items()})
def pair(r):return str(r['AGRUPACION']),r['ASIGNACION_ID']
before=Counter(pair(r) for r in sections['03_RELACIONES'])
original=Counter(pair(r) for r in oracle['RELACIONES_ORIGINALES'])
extra=before-original;missing=original-before
print('RELACIONES extra',sum(extra.values()),'faltantes',sum(missing.values()),'comunes',sum((before&original).values()))
print('FALTANTES',list(missing))
cob=sections['04_COBRANZAS_ACTUALES']
duplicates={k:v for k,v in Counter(r['ASIGNACION_ID'] for r in cob).items() if v>1}
print('COBRANZAS_DUPLICADAS',duplicates)
missing_cob={r['ASIGNACION_ID'] for r in oracle['COBRANZAS_ORIGINALES']}-{r['ASIGNACION_ID'] for r in cob}
octids={r['ASIGNACION_ID'] for r in oracle['COBRANZAS_ORIGINALES'] if (r['FECHA_PAGO']or'').startswith('2026-10')}
docs=sections['05_DOCUMENTOS_EXISTENTES'];layouts=sections['06_LAYOUTS_EXISTENTES']
for label,rows,key in [('DOCS',docs,'NOTA_VENTA'),('LAYOUTS',layouts,'NOTA_VENTA')]:
    selected=[r for r in rows if r[key] in octids]
    print(label,'OCT individuales',len(selected),'referencias',sorted({r[key] for r in selected}))
for table,rows in [('DOCS',docs),('LAYOUTS',layouts)]:
    print(table,'GRUPOS OCT',[r for r in rows if r['NOTA_VENTA'] in ('529057','529099','529057.00','529099.00')])
print('DUPLICADOS_DESGLOSE')
for r in cob:
    if r['ASIGNACION_ID'] in duplicates:
        print({k:r[k] for k in ('ASIGNACION_ID','FACTURA','STATUS','VIA_PAGO','IMPORTE','FECHA_ENVIO')})
ctrls=sections['02_CONTROLES'];orig={str(r['AGRUPACION']):r for r in oracle['CONTROLES_MISMOS_IDS']}
historic=[r for r in ctrls if r['FECHA_PAGO'].startswith('2026-07')]
wrong=[r for r in historic if Decimal(r['IMPORTE'])!=orig[r['AGRUPACION']]['IMPORTE']]
print('CONTROLES_HISTORICOS_IMPORTE_DISTINTO',len(wrong))
result=['# Comparacion 09 T3QA contra Oracle','',
 'Comparacion de reportes exportados; no sustituye el baseline transaccional antes de reparar.','',
 '| Seccion de T3QA | Filas |','|---|---:|']
result += [f'|{s}|{len(r)}|' for s,r in sections.items()]
result += ['',f'- Relaciones comunes: {sum((before&original).values())}.',f'- Relaciones adicionales en T3QA: {sum(extra.values())}.',f'- Relaciones de origen faltantes: {sum(missing.values())}.',
 f'- Controles historicos de julio con importe distinto de Oracle: {len(wrong)}.',
 f'- IDs con mas de una cobranza: {len(duplicates)} (no eliminar sin comparar filas).',
 f'- Cobranzas de origen ausentes en destino: {", ".join(sorted(missing_cob))}.',
 '', '## Relaciones faltantes', '', '| Agrupacion | Asignacion |','|---:|---|']
result += [f'|{g}|{a}|' for g,a in missing]
result += ['', '## Preservar salidas actuales','',
 'Hay documentos/layouts individuales creados en T3QA sobre parte de las cobranzas de octubre. No restaurar Fecha_Envio globalmente desde el export de Oracle ni borrar estas salidas como parte de la conciliacion de agrupaciones.',
 'Persisten layouts individuales de 4000 bytes (262201997560,262201997736,262201997738); revisar su contenido en una tarea separada, sin regenerar automaticamente.',
 '', '## Alcance propuesto de la siguiente reparacion','',
 'Controles y relaciones: recuperar los 28 controles historicos de julio, eliminar sus copias incorrectas de octubre mediante reemplazo transaccional del alcance, preservar 100 relaciones legitimas y reemplazar las 32 relaciones adicionales por las dos relaciones originales de octubre.',
 'No incluir actualizaciones de cobranza, documentos ni layouts en esa transaccion. Las diferencias de cobranza requieren conciliacion especifica porque T3QA ya genero salidas.',
 'T3QA ya tiene el documento 529057 CONFIRMADO, UUID 906EB9B4-BE51-11F1-B5BA-215483603023 y fecha de timbre 02/10/2026 05:18:10; la consulta no encontro su layout. No reinsertar ni regenerar ese documento automaticamente. Oracle marca su control enviado.',
 'La cobranza 262201996890 tiene una discrepancia adicional: Oracle Factura/Nota_Venta V0011-26521, estado NULL y fecha envio 02/10/2026; T3QA Factura/Nota_Venta CHD-33522, estado Canc Pago y sin fecha envio. Determinar si esos cambios de T3QA corresponden a pruebas o a una cancelacion valida antes de restaurarla.',
 'El 09 encontro 146 filas de cobranza para 131 de los 132 IDs de origen. Hay 15 IDs con dos filas; cada par contiene una fila con estado NULL y otra INCOBRABLE. No borrarlas globalmente.',
 'El componente 614 falta tambien en Oracle. No insertar un clon de 613 sin revisar la rutina LOG_START y el contrato operacional.']
(HERE/'COMPARACION_09_DESTINO_ORACLE.md').write_text('\n'.join(result)+'\n',encoding='utf-8')
