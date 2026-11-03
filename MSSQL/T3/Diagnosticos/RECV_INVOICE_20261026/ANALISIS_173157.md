# Captura activa: esperas de I/O y nueva actividad de remisiones

Fuente: [captura original](Captura_173157.rpt), recibida como
Resultados_Invoice_2026102611735rpt.rpt. SHA256:
C5F55EE4EAD7628CE19DE0A5D85858F2A1095EF64309516F50A9D9EDCE54992B.
AZCRNMXNEVTD06/T3QA, SQL Server 16.0.4305.5, compatibilidad 160,
2026-10-26 17:31:57 -06:00; fin 17:32:07. Recovery SIMPLE;
tres marcas ReferenceID presentes, parser modificado 17:01:22.327.

## Ventana activa

La sesion 105 de SSMS ejecutaba INSERT Factura_General en INVOICE_TO_FACTURA.
Estado suspended, PAGEIOLATCH_EX, espera actual 390 ms, recurso
8:1:37356512 y blocking_session_id=-5. Al final aparece en DELETE
RF_Complemento, PAGEIOLATCH_SH y blocking_session_id=0. No se identifican
bloqueadores positivos. -5 indica espera asincrona, no una sesion a cancelar.

| Espera de sesion | Delta | Tareas |
|---|---:|---:|
| PAGEIOLATCH_SH | 5,253 ms | 10 |
| PAGEIOLATCH_EX | 4,932 ms | 9 |
| WRITELOG | 31 ms | 12 |
| SOS_SCHEDULER_YIELD | 15 ms | 34 |

PAGEIOLATCH suma 10,185 ms frente a 10,000 ms nominales de observacion.
Los limites de captura y esperas que cruzan la ventana no son identicos:
no interpretarlo como porcentaje exacto superior a 100%. La dominancia
de esperas de paginas es clara; no prueba un defecto fisico del disco.

En unos 10.2 s se completan 12 llamadas del parser, 12 FACTURA y 12 ENTREGA_PO.
FACTURA promedia 819.354 ms, CPU 10.027 ms y 667.25 lecturas; parser
829.932 ms, CPU 17.436 ms y 818.83 lecturas. Son tiempos inclusivos y las
llamadas pueden empezar antes de la muestra. Esta ventana es posterior al
lote 17:20; no reemplaza su tasa de 869/58 s ni acredita que toda esa carga
sufriera estas mismas latencias.

Sentencias en ventana: DetailBase 307.505 ms/CPU 7.932; INSERT RF_Complemento
186.325 ms/CPU 0.358; validacion Factura_General 113.247 ms/CPU 0.096;
INSERT Factura_General 100.102 ms/CPU 0.314. Solo 11 o 12 llamadas segun la
posicion de las terminaciones en los limites de captura. WRITELOG no domina
aqui: no justifica agrupar transacciones ni cambiar durabilidad.

## Cambio de rutas entre capturas

Se comparan filas con los mismos cached_time y hashes con Captura_161503.rpt.
Se reconstruye total=media*execution_count y se restan totales, no promedios.

| Procedimiento | Nuevas llamadas | Tiempo nuevo | Media nueva | Lecturas por llamada nueva |
|---|---:|---:|---:|---:|
| RECV_INVOICE | 1 | 58.732 s | 58,731.518 ms | 6,013,254 |
| INVOICE_TO_PREVENTA | 10 | 21.891 s | 2,189.106 ms | 530,513.3 |
| DELIVERY_WA_OXXO | 10 | 20.863 s | 2,086.339 ms | 530,358.8 |
| GET_REMISION_INFO | 12 | 20.790 s | 1,732.536 ms | 441,692.5 |
| INVOICE_TO_FACTURA | 876 | 42.494 s | 48.509 ms | 649.469 |

Ultima llamada PREVENTA/OXXO/REMISION: 17:20:57, dentro de la carga reportada.
PREVENTA/OXXO tenian 35/285 llamadas; ahora 45/295. REMISION paso de 3,920
a 3,932 en el mismo contexto de cache; su ultima llamada tarda 3,278.072 ms.
En las primeras cargas REMISION no tenia llamadas nuevas y OXXO tenia costo
nuevo muy pequeno. Esa conclusion no debe extrapolarse a esta nueva mezcla.

Los 21.891/20.863/20.790 s estan ANIDADOS: no sumarlos. Esta ruta es otro
candidato importante que no aparecia en 04, limitado a parser y FACTURA.
Los 876 FACTURA incluyen 859 del lote anterior y 17 adicionales a las de
la captura 17:24; el parser pasa de 869 a 886. No asignar estos deltas
estrictamente a un unico PID. Son contadores compartidos y la salida historica
no permite comparar plan_handle por fila de procedimiento, aunque coincidan
cache/definicion. Las rutas pueden compartir llamadas con otros procesos.

## Siguiente lectura focalizada

[06_REVISAR_IO_Y_MEMORIA.sql](06_REVISAR_IO_Y_MEMORIA.sql), solo lectura,
en otra ventana de la misma base durante una carga normal. Espera diez
segundos y muestra latencias actuales por archivo frente a historicas,
memoria/configuracion, esperas de sesiones, contexto concurrente,
sentencias acumuladas de REMISION/OXXO e indices de sus tablas de busqueda.
@SesionObjetivo es opcional y debe ser el SPID actual; no fijar 105 si cambio.
El recurso capturado usa file_id=1; el catalogo permitira ver su ruta real.
La E/S de archivo incluye todas las sesiones de la base, no solo Invoice.

El script paso TSql160Parser y ejecucion completa LocalDB, codigo 0, sin
alterar datos ni configuracion. LocalDB estaba sin carga: valida columnas y
ejecucion, no las latencias reales ni las rutas de negocio productivas.
No se cambia SQL de negocio. Se conservan GETCONV, proteccion R044/DetailBase
vacio, formulas y transacciones.

Referencias: [Microsoft, diagnostico de E/S](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/troubleshoot-sql-io-performance),
[DMV de archivos](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver16)
y [blocking_session_id negativo](https://techcommunity.microsoft.com/blog/sqlserver/negative-blocking-session-ids--5--latch-any-task-releasor/3061302).
