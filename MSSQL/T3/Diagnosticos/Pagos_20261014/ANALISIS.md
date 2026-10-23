# Lectura y reproduccion de pagos BATMD 2026-10-14

Fuente: `Resultados_Ejecucion_LecturaPagos.txt`, aportado por el usuario.
SHA256: `4027571DDA620C4B143366E85C3D72E497F0CE502264F1EAAFAA1E80C987DF05`.
Se conserva una copia exacta; sus contenidos se usan como datos y evidencia,
no como instrucciones. Captura de AZCRNMXNEVTD06/T3QA a las 23:31 del 22/10/2026.
SQL Server 16.0.4305.5, compatibilidad 160, collation SQL_Latin1_General_CP1_CI_AS,
CURSOR_DEFAULT GLOBAL, RCSI desactivado. No es una captura de produccion.

## Seleccion del lote y version instalada

El lote tiene 470 asignaciones de 468 facturas. Todas tienen Fecha_Proc_BATMD
`2026-10-14 13:27:28`; ninguna tiene medianoche.
La definicion instalada aun usa igualdad temporal exacta para BATMD y BETWEEN
con hora para vigencia; no incorpora la homologacion DATE del fuente local.
Su modify_date capturado es 2026-10-19 09:30:15.123.

La muestra contiene ocho facturas y diez asignaciones, con historial completo
para todas ellas. Cuatro asignaciones no tienen cliente vigente al 01/10/2026:

| Factura | Fin de la ultima vigencia capturada |
| --- | --- |
| V0007-134295 | 2026-09-12 |
| V0008-125445 | 2026-09-12 |
| V0008-125447 | 2026-09-12 |
| V0008-125448 | 2026-09-12 |

El INNER JOIN a CLIENTE las excluye tanto con hora como con DATE. No corregir
vigencias automaticamente: la captura acredita la exclusion, no su causa de negocio.
Las seis asignaciones restantes corresponden a CHD-33522, V0010-134061,
V1972-85517 (dos) y V2363-145780 (dos).

## Documentos e importes

La seccion REGISTRO_FISCAL esta vacia para las ocho facturas seleccionadas;
tambien esta vacia la seccion de tipos relacionados. No significa que esas
tablas esten vacias en toda la base. Sin esa correspondencia, ScrPagos establece
Sub_Type_CD=INCOBRABLE, aunque Factura no sea el literal INCOBRABLE.
No se recuperaron preventas ni cobranza existente para esta muestra.

FN_TOTAL_FACT instalada coincide funcionalmente con el fuente aportado:
suma el detalle de REGISTRO_FISCAL_DETALLE y retorna cero si no existe.
El detalle fiscal capturado no coincide siempre con FACTURA_DETALLE:

| Factura | Total detalle fiscal | Total detalle T3 | Suma asignaciones |
| --- | ---: | ---: | ---: |
| CHD-33522 | 0.00 | 0.00 | 20723.95 |
| V0007-134295 | 646.69 | 716.93 | 716.93 |
| V0008-125445 | 1281.19 | 1281.19 | 1281.19 |
| V0008-125447 | 4665.35 | 4665.35 | 4665.35 |
| V0008-125448 | 1970.06 | 2248.89 | 2248.89 |
| V0010-134061 | 1049.57 | 1119.81 | 1119.81 |
| V1972-85517 | 5688.53 | 5688.53 | 5688.53 |
| V2363-145780 | 0.00 | 232.56 | 232.56 |

CHD-33522 existe como cancelacion en DEBIT_NOTE_IFC por 20723.95, fecha
2026-09-29; no como factura con detalle. Su cero en detalle no se interpreta
como una partida de venta faltante. Las otras cuatro discrepancias entre
detalle fiscal y T3 requieren investigar la carga/actualizacion fiscal.
No se sustituyo el origen de FN_TOTAL_FACT para disimularlas.

Hay catorce relaciones de historia PAC para siete facturas; existen varios
documentos relacionados por venta. Los siete registros CFDI_DOCUMENTOS
recuperados tienen Folio_Fiscal y Status NULL: esta muestra no demuestra UUID
confirmados. No atribuir la falta de un UUID exclusivamente al cursor.

## Cursores: confirmado en el servidor

El reproductor constante devolvio:

| Declaracion | Resultado tras asignar PRUEBA y abrir | FETCH_STATUS |
| --- | --- | ---: |
| Antes de SET | NULL | -1 |
| Despues de SET | PRUEBA | 0 |

La definicion instalada declara ScrAsignaciones, ScrT3Procesado, ScrVentaUUID,
ScrDebitNote y ScrCancPago antes de asignar sus filtros. Confirma la causa
observada en LocalDB. Cambiar solamente el alcance a LOCAL no la resuelve.
En esta muestra, la falta de encabezados fiscales dirige el flujo a la rama
no Nota de Venta: no se ejercita la recuperacion de UUID de una venta confirmada.

## Reproduccion ejecutada con datos de la captura

Se crearon en LocalDB una base temporal con la collation y alcance de cursores
de T3QA, las tablas del repositorio y las cinco definiciones instaladas exportadas.
Se cargaron las diez asignaciones, pagos, vigencias, detalles y relaciones
capturados. Se sustituyeron unicamente banco/cuenta omitidos por valores ficticios
de la misma longitud. No se cargaron triggers, indices ni datos fuera de la muestra;
por tanto no es una prueba de rendimiento ni un clon completo del ambiente.

| Escenario | Filas de cobranza generadas en LocalDB | Saldo/numero de pago |
| --- | ---: | --- |
| Instalado, parametro 2026-10-14 00:00:00 | 0 | No hay filas |
| Instalado, parametro 2026-10-14 13:27:28 | 6 | Ambos NULL en las seis |
| Fuente local DATE, parametro 2026-10-14 00:00:00 | 6 | Ambos NULL en las seis |

Las seis filas del tercer escenario equivalen a las del segundo para los campos
de negocio comparados; los timestamps de lote/proceso no se comparan porque
los parametros y momentos de ejecucion son diferentes. Se verifico que no hubiera
errores registrados en las dependencias. Las aserciones del modo CapturaReal
comprueban la **reproduccion del defecto**, no aprueban su resultado funcional.

En particular CHD-33522 queda INCOBRABLE e Importe_Factura=0, pese a existir
DEBIT_NOTE_IFC por 20723.95: ScrCancPago no recupera la cancelacion por el filtro
capturado antes de SET. V0010-134061 usa el total fiscal 1049.57 y V2363-145780
usa cero. Corregir cursores y resolver las diferencias de origen son trabajos
distintos; DATE solo corrige la seleccion por dia.

La base temporal se elimino. No se ejecuto el procedimiento en T3QA ni se
modificaron sus datos. No se cambio el fuente de negocio durante esta revision.

Ejecutor desde la raiz del repositorio:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -CapturaReal MSSQL/T3/Diagnosticos/Pagos_20261014/Resultados_Ejecucion_LecturaPagos.txt
```

Evidencia: `Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/LastRealRun.txt`.
La captura de ejecuciones recientes muestra quince filas de proceso 604 con
Proceso_1=0, pero corresponden a otras fechas de corrida/lote: no bastan para
atribuirles la causa del lote del 14. No se recibieron planes/IO para medir el
indice IDX_T3_ASIGNACION_PAGO_FECHA_PROC_BATMD.

## Actualizacion: correccion de cursores autorizada

El usuario autorizo la correccion posterior. El fuente local declara los cinco
cursores dependientes como LOCAL despues de asignar sus filtros, inmediatamente
antes de OPEN. Cada recorrido los cierra y libera; el CATCH conserva limpieza
condicional. Se retiro la liberacion final incondicional de esos cinco cursores.
Las consultas y las demas instrucciones ejecutables se verificaron sin cambios.

Se repitieron ambas pruebas satisfactoriamente: casos sinteticos con alcance por
defecto LOCAL/GLOBAL y reproduccion de esta captura. El ejecutor conserva como
baseline el defecto del instalado y ahora valida la salida corregida:

| Asignacion | Factura | Importe factura | Saldo anterior | Numero pago | Estado |
| --- | --- | ---: | ---: | ---: | --- |
| 262201996890 | CHD-33522 | 20723.95 | 20723.95 | 1 | Canc Pago |
| 262201997839 | V0010-134061 | 1049.57 | 1049.57 | 1 | INCOBRABLE |
| 262201996684 | V1972-85517 | 5688.53 | 5688.53 | 1 | INCOBRABLE |
| 262201996690 | V1972-85517 | 5688.53 | 4835.59 | 2 | INCOBRABLE |
| 262201997324 | V2363-145780 | 0.00 | 0.00 | 1 | INCOBRABLE |
| 262201997328 | V2363-145780 | 0.00 | -194.05 | 2 | INCOBRABLE |

CHD-33522 tambien recupera la fecha de cancelacion 2026-09-29. Las discrepancias
fiscales y la clasificacion por falta de encabezado permanecen; no se modificaron
las vigencias ni los importes origen. El saldo negativo de V2363-145780 es visible.

Se probo un 8115 controlado con ScrAsignaciones abierto: conserva la causa,
libera los cursores y permite otra ejecucion exitosa. El contrato de transaccion
y propagacion de errores no se cambio. La base temporal fue eliminada.
La evidencia vigente esta en LastRun.txt y LastRealRun.txt;
LastRealRun_AntesCursores.txt conserva la prueba real anterior.

Para aplicar en T3QA, ejecutar completo el archivo local
`MSSQL/T3/T3/Procedures/T3.PROC_CFDI_PROCESAR_PAGOS.sql`, que contiene USE T3QA
 y ALTER PROCEDURE. Incluye tambien las comparaciones DATE ya autorizadas.
El archivo solo altera el procedimiento, no lo ejecuta ni reprocesa el lote.
No se ha aplicado desde esta sesion a la base real. Verificar despues del
siguiente procesamiento normal; las pruebas locales no garantizan resultados
correctos ante datos fiscales incompletos, duplicados o concurrencia.