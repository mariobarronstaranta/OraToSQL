"""Genera instaladores independientes desde 05 y el inventario recibido del 07.
Uso inicial: python generar_lotes_08.py ruta_al_resultado_07.txt
Reproducir: python generar_lotes_08.py (usa inventario_07.json guardado).
"""
from pathlib import Path
import sys
import re
import json
import hashlib

HERE=Path(__file__).resolve().parent
OUT=HERE/'08_LOTES_PK_20261106'
OUT.mkdir(exist_ok=True)
if len(sys.argv)>1:
    text=Path(sys.argv[1]).read_text(encoding='utf-8-sig')
    rows=[]
    for line in text.splitlines():
        c=re.split(r'\s+',line.strip())
        if len(c)==17 and c[0].isdigit() and c[3]=='CANDIDATA':
            rows.append(dict(orden=int(c[0]),tabla=c[1],pk=c[2],filas=int(c[4]),mb=float(c[5])))
    assert len(rows)==65 and [r['orden'] for r in rows]==list(range(1,66))
    assert len({r['tabla'] for r in rows})==65
    assert sum(r['filas'] for r in rows)==840506447
    (OUT/'inventario_07.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
else:
    rows=json.loads((OUT/'inventario_07.json').read_text())
assert all(r['filas']==0 for r in rows[:36])
assert all(0<r['mb']<=1.52 for r in rows[36:54])
base=(HERE/'05_APLICAR_PK_TABLAS_MIGRADAS.sql').read_text(encoding='utf-8-sig')
start=base.index('INSERT @Origen(Tabla,NombrePK,Posicion,Columna) VALUES')
end=base.index('-- Suspension posterior al incidente',start)
tuples=re.findall(r"^\(N'([^']+)',[^\r\n]+",base[start:end],re.M)
assert len(tuples)==146
groups=[rows[i:i+9] for i in range(0,54,9)]+[[r] for r in rows[54:]]
manifest=[]
for num,group in enumerate(groups,1):
    label=('VACIAS' if num<=4 else 'PEQUENAS') if num<=6 else group[0]['tabla']
    name=f'{num:02d}_{label}.sql'
    names={r['tabla'] for r in group}
    selected=[]
    for line in base[start:end].splitlines():
        match=re.match(r"\(N'([^']+)'",line)
        if match and match[1] in names:selected.append(line.rstrip(',;'))
    assert {re.match(r"\(N'([^']+)'",line)[1] for line in selected}==names
    insertion='INSERT @Origen(Tabla,NombrePK,Posicion,Columna) VALUES\n'+',\n'.join(selected)+';\n\n'
    script=base[:start]+insertion+base[end:]
    assert 'THROW 56992' in script  # No perder suspension al reemplazar semilla.
    order='CASE Tabla '+ ' '.join(f"WHEN N'{r['tabla']}' THEN {r['orden']}" for r in group)+' END'
    assert script.count('ROW_NUMBER() OVER(ORDER BY Tabla)')==1
    script=script.replace('ROW_NUMBER() OVER(ORDER BY Tabla)',f'ROW_NUMBER() OVER(ORDER BY {order})')
    header=f'''/* LOTE {num:02d} de 17. Archivo autonomo: no necesita ejecutar 05.
   Captura de tamanos: T3QA, 2026-11-06 00:03:29 -06:00.
   Solo valida/aplica las {len(group)} tablas listadas aqui; @Aplicar=0 por defecto.
   Ejecutar archivos secuencialmente, NO todos juntos ni en paralelo.
'''+''.join(f"   {r['orden']:02d}. {r['tabla']}: {r['filas']:,} filas aprox.; {r['mb']:.2f} MB tabla.\n" for r in group)+'''   Ejecutar completo con @Aplicar=0; revisar y cambiar a 1 para aplicar.
   Si falla DDL: revierte esa tabla y detiene; conserva las anteriores.
*/
'''
    script=header+script
    (OUT/name).write_text(script,encoding='utf-8-sig')
    manifest.append(dict(archivo=name,tablas=[r['tabla'] for r in group],filas=sum(r['filas'] for r in group),mb=round(sum(r['mb'] for r in group),2),sha256=hashlib.sha256((OUT/name).read_bytes()).hexdigest()))
assert len(manifest)==17
assert [t for m in manifest for t in m['tablas']]==[r['tabla'] for r in rows]
(OUT/'manifest.json').write_text(json.dumps(dict(base_sha256=hashlib.sha256(base.encode()).hexdigest(),lotes=manifest),indent=2)+'\n',encoding='utf-8')
readme='''# PK T3 por lotes: orden de ejecucion

Basado en el resultado 07 de T3QA del 2026-11-06 00:03:29 -06:00.
65 candidatas: 36 vacias, 18 pequenas y 11 individuales. Las 13 ausentes y
las tres pendientes (CFDI_CATALOGOS_SAT, MOV_CLIENTE, USUARIOS) no se incluyen.
Los tamanos corresponden a la tabla, no suman otros indices; son aproximados.

Cada SQL es autonomo, con el inventario restringido a sus tablas ANTES de
prevalidar datos. No ejecuta 05 ni escanea las otras tablas del inventario.
Conserva los controles, la transaccion por tabla y la reejecucion del 05.
El orden dentro de cada lote respeta el orden del reporte 07.

## Como ejecutar

1. Abrir 01_VACIAS.sql en SSMS conectado a T3QA y ejecutar completo con
   `@Aplicar=0`. Revisar que las nueve tablas esten LISTA o YA_EXISTE_EQUIVALENTE.
2. Cambiar solamente `@Aplicar=1` y ejecutar completo para aplicar ese lote.
   La prevalidacion se repite contra los datos actuales. Guardar el resultado
   03_RESULTADO_APLICACION. Las tablas CREADA o YA_EXISTE_EQUIVALENTE terminaron.
3. Continuar con el siguiente archivo cuando convenga. No ejecutar todos
   juntos ni en paralelo. No es necesario repetir los lotes completados.
4. Ante BLOQUEADA o ERROR_DDL_REVERTIDO, revisar el error; no eliminar indices
   ni datos manualmente. Un error de DDL revierte esa tabla, conserva las
   anteriores y deja las posteriores sin procesar. Se puede reejecutar el lote.
5. Al terminar, ejecutar ../02_VERIFICAR_PK_T3.sql: se esperan 65 equivalentes;
   las tres pendientes y 13 ausentes permanecen fuera del alcance.

Los lotes grandes necesitan su propia ventana sin escritores ni cambios de
esquema. Conservan los escaneos de validacion, el bloqueo exclusivo y el DDL
del 05: dividir archivos no vuelve instantanea ni online una tabla grande.
No se estima duracion ni espacio temporal/log necesario solo con estos MB.
No ejecutar el instalador 05 global ademas de estos lotes.

## Archivos en orden

| Archivo | Tablas | Filas aprox. | MB tabla |
|---|---:|---:|---:|
'''
for m in manifest:readme+=f"| [{m['archivo']}]({m['archivo']}) | {len(m['tablas'])} | {m['filas']:,} | {m['mb']:,.2f} |\n"
readme+='\n## Detalle por archivo\n'
for m in manifest:readme+=f"\n- **{m['archivo']}**: "+', '.join(m['tablas'])+'.\n'
readme+='\nGenerador: ../generar_lotes_08.py. inventario_07.json conserva el orden y volumen recibido; manifest.json registra cobertura y huellas. No se aplicaron cambios en T3QA desde esta sesion.\n'
(OUT/'README.md').write_text(readme,encoding='utf-8')
print(f'Generados {len(manifest)} lotes; 65 tablas exactamente una vez.')
