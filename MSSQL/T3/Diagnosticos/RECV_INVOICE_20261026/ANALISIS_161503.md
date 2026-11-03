# Costo posterior al parche: parser e INVOICE_TO_FACTURA

Fuente [captura original](Captura_161503.rpt), recibida como
Resultados_Invoice_202610261615.rpt. Ambiente AZCRNMXNEVTD06/T3QA, captura
26 de octubre de 2026 a las 16:15:03 -06:00, fin a las 16:15:14.

## Parche y medicion posterior acreditados

SF_PROC_PREINVOICE_IFC tiene las tres marcas RI_REF_SEEK=1,
modify_date 2026-10-26 15:24:27.020, 93,966 bytes de definicion, hash
5F9024C4E8E1E4F379B8456D32DFDCB11BE58045EC1BAF4576A33D843A908DA7.
El plan se recompilo a las 15:26:31.703 y registra **1,571 llamadas**,
coincidentes con las dos cargas reportadas (706+865).

| Promedio del parser | Captura previa | Posterior |
|---|---:|---:|
| Tiempo ms | 680.099 | 63.823 |
| CPU ms | 3,867.855 | 37.112 |
| Lecturas logicas | 63,833.574 | 928.285 |

La reduccion observada de lecturas medias es 98.55%. Las ventanas/mezclas
son distintas; no equivale a un A/B identico ni a una nueva medicion de
los DELETE por separado. El parser medio sigue por encima de la referencia
de 40-50 ms por registro equivalente a 20-25 registros/s.

## La ventana de diez segundos no observo una carga

Todas las filas 07_DELTA_LLAMADAS muestran cero. 07B, actividad y esperas
estan vacias. La ultima llamada del parser es 15:31:22.703, unos 44 minutos
antes de la captura. No se interpreta como ausencia de esperas durante los
lotes; solamente no hubo llamadas terminadas en esa muestra de diez segundos.

## Comparacion entre capturas acumuladas

Se compararon las filas de 03_CACHE_ACUMULADA con la captura 14:22:38.
Para estos procedimientos se conservan la fecha de cache y el hash de
definicion. Se reconstruye el total como media multiplicada por ejecuciones
y se restan los totales, no los promedios directamente.

| Procedimiento | Llamadas nuevas | Media de las llamadas nuevas, ms | Lecturas por llamada nueva |
|---|---:|---:|---:|
| INVOICE_TO_FACTURA | 1,542 | 30.512 | 651.293 |
| INVOICE_TO_PREVENTA | 26 | 135.293 | 162.692 |
| DEBITNOTE_TO_IFC | 3 | 2.231 | 60.333 |
| DELIVERY_WA_OXXO | 26 | 0.222 | 4.000 |
| INVOICE_TO_ENTREGA_PO | 1,568 | 0.555 | 11.905 |
| GET_REMISION_INFO | 0 | No intervino en nuevas llamadas | No aplica |
| WA_FOLIO_FACTURA | 0 | No intervino en nuevas llamadas | No aplica |

Las tres rutas directas suman 1,542+26+3=1,571 llamadas. Esto es consistente
con las cargas reportadas; la cache es global y la coincidencia no sustituye
una traza por PID. La comparacion se apoya en cached_time/definicion y
contadores monotonicamente crecientes; la salida historica no incluye el
plan_handle en esa seccion para contrastarlo por separado.

El tiempo acumulado nuevo de INVOICE_TO_FACTURA es aproximadamente 47.05 s;
preventa, 3.52 s; debito, 0.007 s. El parser registra 100.27 s inclusivos.
Como estimacion residual, el trabajo del parser fuera de esas tres llamadas
directas suma unos 49.69 s (31.63 ms por registro). No restar tambien OXXO o
entrega: ya pertenecen a las rutas hijas. Los 135 ms de preventa, con solo 26
llamadas, representan unos 2.24 ms por registro del lote, no 135 ms en cada
uno de los 1,571 registros.

RECV_INVOICE tuvo dos llamadas nuevas que suman 101.08 s; el parser,
100.27 s. La diferencia aproximada es 0.81 s para ambos lotes (~0.52 ms por
registro). Optimizar solo el COUNT_BIG del coordinador no puede explicar
por esta evidencia los 8-16 s que se buscan ahorrar en la ultima carga.

OXXO/remision NO son la prioridad para estas cargas: los promedios antiguos
altos eran historicos; OXXO hizo solo 0.006 s nuevos y remision no tuvo llamadas.

## Siguiente revision sin otra carga de facturas

Ejecutar [04_REVISAR_PARSER_Y_FACTURA.sql](04_REVISAR_PARSER_Y_FACTURA.sql).
Consulta las sentencias en cache de esos dos SP, Query Store posterior al
cambio y sus esperas, mas planes y conversiones/recorridos con llamadas.
No habilita Query Store, no ejecuta negocio, no espera una nueva corrida ni
modifica SP o indices. Las ramas sin estadisticas pueden quedar fuera de
los resumenes de planes; ausencia de filas no prueba ausencia de costo.

Query Store agrupa filas persistidas/en memoria por plan/intervalo y usa
solo intervalos cuyas ejecuciones terminadas comienzan despues del cambio.
Puede devolver menos datos si el intervalo mezcla actividad previa. La cache
del hijo conserva historia; el parser tiene una nueva cache posterior al parche.
Las marcas de tiempo de Query Store corresponden al final de las ejecuciones.
Ver [definicion de runtime stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql)
y [esperas](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql).

SQL validado con TSql160Parser y ejecutado en LocalDB para comprobar catalogos,
cache y XQuery, sin conexiones al servidor real. Query Store no se habilito
en esa prueba y no se simularon sus estadisticas productivas. Se mantuvieron
satisfactorias las pruebas anteriores de parche/reversa/transacciones.
No hubo cambios adicionales de negocio; objetivo 20-25/s sigue abierto.
