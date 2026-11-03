"""Lee el JSONL original y prepara informe y captura de destino; sin conexiones."""
from pathlib import Path
import json
from collections import Counter

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
src=ROOT/'ORA/T3/T3/Datos/Resultados_28_Oracle.jsonl'
sections={}
for num,line in enumerate(src.read_text(encoding='utf-8-sig').splitlines(),1):
    if not line.strip(): continue
    item=json.loads(line)
    sections.setdefault(item['SECCION'],[]).append(item['FILA'])
cob=sections['COBRANZAS_ORIGINALES']
ctrl=sections['CONTROLES_ORIGINALES']
rel=sections['RELACIONES_ORIGINALES']
octubre=[r for r in cob if (r['FECHA_PAGO'] or '').startswith('2026-10')]
ids=sorted({r['ASIGNACION_ID'] for r in cob})
facts=sorted({r['FACTURA'] for r in cob if r['FACTURA']})
groups=sorted({r['AGRUPACION'] for r in ctrl}|{r['AGRUPACION'] for r in sections['CONTROLES_MISMOS_IDS']})
def literals(vals): return ','.join("'"+str(v).replace("'","''")+"'" for v in vals)
idfilter=literals(ids); factfilter=literals(facts)
groupfilter=','.join(str(g) for g in groups)
refs=literals(sorted(set(ids+facts+[str(g) for g in groups]+[str(g)+'.00' for g in groups])))
sql=f'''/* Solo lectura de negocio. Alcance derivado del JSONL de Oracle.
No modifica las cuatro asignaciones ya reparadas ni restaura fechas de envio.
Guardar todas las salidas. Son 132 IDs de cobranza y 30 grupos identificados.
No ejecutar agrupador/liberadores durante la captura para comparar el corte.
No es una fotografia transaccional de varias tablas.
*/
USE [T3QA];
SET NOCOUNT ON;
SELECT '01_AMBIENTE' Seccion,@@SERVERNAME Servidor,DB_NAME() BaseDatos,GETDATE() Captura;
SELECT '02_CONTROLES' Seccion,A.* FROM T3.CFDI_AGRUPACION_CTRL A
WHERE AGRUPACION IN ({groupfilter}) ORDER BY AGRUPACION,FECHA_REGISTRO;
SELECT '03_RELACIONES' Seccion,P.* FROM T3.CFDI_AGRUPACION_PAGO P
WHERE AGRUPACION IN ({groupfilter}) OR ASIGNACION_ID IN ({idfilter})
ORDER BY AGRUPACION,ASIGNACION_ID;
SELECT '04_COBRANZAS_ACTUALES' Seccion,C.* FROM T3.CFDI_COBRANZA C
WHERE ASIGNACION_ID IN ({idfilter}) ORDER BY ASIGNACION_ID,FECHA_PROCESO;
SELECT '05_DOCUMENTOS_EXISTENTES' Seccion,D.* FROM T3.CFDI_DOCUMENTOS D
WHERE NOTA_VENTA IN ({refs}) ORDER BY NOTA_VENTA,FECHA_LIBERACION;
SELECT '06_LAYOUTS_EXISTENTES' Seccion,E.NOTA_VENTA,DATALENGTH(E.INFORMACION) BytesLayout,
 LEFT(E.INFORMACION,120) InicioLayout FROM T3.CFDI_DOCUMENTOS_ENVIAR E
WHERE NOTA_VENTA IN ({refs}) ORDER BY NOTA_VENTA;
SELECT '07_COMPONENTES' Seccion,C.* FROM EAI_OWNER.MX_COMPONENTS C WHERE COMPONENT IN (613,614);
SELECT '08_MULTIPLICIDAD_CONTROL' Seccion,AGRUPACION,COUNT_BIG(*) Filas
FROM T3.CFDI_AGRUPACION_CTRL WHERE AGRUPACION IN ({groupfilter})
GROUP BY AGRUPACION HAVING COUNT_BIG(*)>1;
'''
(HERE/'09_CAPTURAR_DESTINO_28.sql').write_text(sql,encoding='utf-8')
lines=['# Analisis de Resultados_28_Oracle.jsonl','',
 'Lectura de origen; no se modifico T3QA ni Oracle. Comparacion con el reporte 07 previo.',
 '', '| Seccion | Filas |','|---|---:|']
lines += [f'|{k}|{len(v)}|' for k,v in sections.items()]
lines += ['', '## Hallazgos', '',
 f'- Los {len(sections["CONTROLES_MISMOS_IDS"])} controles con los mismos IDs son de julio en Oracle; en el reporte 07 tenian fecha de pago de octubre.',
 '- De esos 28 controles, 25 tienen Fecha_Envio y tres son Contado: 514974, 514982 y 514985.',
 '- Se recibieron 132 cobranzas unicas: 100 de julio y 32 de octubre.',
 '- Las 32 de octubre incluyen 30 de via 01 sin relacion de agrupacion en este export y dos de vias 02/03 ya agrupadas en origen.',
 '- No restaurar globalmente esas cobranzas ni poner Fecha_Envio NULL: T3QA ya genero salidas en la corrida individual 26517156. La comparacion de fechas debe conservar esa evidencia y distinguir los cortes.',
 '- No basta borrar todos los detalles de los 28 IDs: contienen relaciones historicas legitimas de julio.',
 '- El export del componente incluye solo 613; 614 no existe en la consulta de Oracle. No tratarlo como un registro olvidado en la migracion ni clonarlo sin revisar LOG_START y el contrato del proceso.',
 '', '## Relaciones de octubre originales', '', '| Asignacion | Factura | Via | Grupo | Estado control | Fecha envio control |', '|---|---|---|---:|---|---|']
bygroup={r['AGRUPACION']:r for r in ctrl}
for r in octubre:
    for p in rel:
        if p['ASIGNACION_ID']==r['ASIGNACION_ID']:
            g=bygroup[p['AGRUPACION']]
            lines.append(f'|{r["ASIGNACION_ID"]}|{r["FACTURA"]}|{r["VIA_PAGO"]}|{p["AGRUPACION"]}|{g["ACCNT_ID"] or "NULL"}|{g["FECHA_ENVIO"] or "NULL"}|')
lines += ['', '## Siguiente captura', '',
 '`09_CAPTURAR_DESTINO_28.sql` obtiene controles/relaciones/cobranzas actuales y presencia de documentos y layouts. Es necesario para definir la reparacion sin deshacer la corrida individual ni duplicar salidas.',
 'Este informe no certifica equivalencia global: faltan comparacion actual de destino y documentos originales de las dos agrupaciones de octubre.']
(HERE/'ANALISIS_28_ORACLE.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Secciones:',{k:len(v) for k,v in sections.items()})
print('Cobranzas octubre por via:',dict(Counter(r['VIA_PAGO'] for r in octubre)))
print('Generados: ANALISIS_28_ORACLE.md y 09_CAPTURAR_DESTINO_28.sql')
