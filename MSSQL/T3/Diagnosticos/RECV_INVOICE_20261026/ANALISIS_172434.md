# Resultado posterior al parche SKU

Fuente: [captura original](Captura_172434.rpt), recibida como
Resultados_Invoice_2026102611734rpt.rpt. SHA256:
FDCD91EEEA0CFD2F391570E32BEB24E2C3B26AE283F092C32C296E28E7C246C0.
AZCRNMXNEVTD06 / T3QA; captura 2026-10-26 17:24:34 -06:00,
fin 17:25:00. Query Store READ_WRITE/AUTO, esperas ON, intervalos 60 min.

## Version y ventana

01_AMBIENTE informa ParcheSku=1 y modificacion del parser a las
17:01:22.327 -06:00, anterior al lote reportado 17:20:03-17:21:01.
Su plan se almaceno a las 17:20:02.683 y tiene 869 llamadas. Los horarios
23:20-23:21 UTC de Query Store equivalen a 17:20-17:21 locales.
El contador instalado y las horas respaldan el uso del parser con la marca
SKU en esta carga; no se recibio RunId ni definicion completa/hash del modulo.

El usuario reporta 869/58 s = 14.98 registros/s. No se alcanza 20-25/s.
La mejora de una sentencia no acredita mejora integral del lote.

## Costos posteriores de Query Store

| Sentencia | QueryId / PlanId | Ejecuciones | Tiempo total | Media | CPU media | Lecturas por llamada |
|---|---|---:|---:|---:|---:|---:|
| curSKU | 31819 / 8548 | 7,454 | 0.229 s | 0.0307 ms | 0.0289 ms | 2.50 |
| DetailBase / INSERT Factura_Detalle | 30820 / 8103 | 859 | 13.805 s | 16.071 ms | 7.576 ms | 557.98 |
| INSERT RF_Complemento | 20736 / 4569 | 859 | 4.777 s | 5.561 ms | 0.110 ms | 8.89 |
| INSERT Factura_General | 20737 / 4570 | 859 | 1.897 s | 2.208 ms | 0.152 ms | 16.12 |
| DELETE RF_Complemento | 20735 / 6065 | 859 | 0.865 s | 1.007 ms | 0.040 ms | 4.01 |
| DELETE Factura_Detalle | 18186 / 8059 | 859 | 0.591 s | 0.688 ms | 0.081 ms | 5.33 |

En la captura anterior curSKU tenia 6,714 ejecuciones/33.322 s/4.963 ms.
Ahora dejo de encabezar los costos visibles. No restar esos tiempos como un
ahorro del lote: corresponden a cargas y cantidades de ejecuciones distintas.
Hay 3,727 llamadas de lectura XML de partidas frente a 7,454 del nuevo hash
SKU; el contador de cursor no equivale al numero de documentos ni demuestra
por si solo el numero de partidas. Tampoco sumar padres e hijos inclusivos.

Los datos de cache de INVOICE_TO_FACTURA abarcan 5,275 llamadas desde el
22 de octubre. Para analizar esta ventana se priorizan sus 859 llamadas de
Query Store posteriores al cambio, sin asumir que las diez llamadas restantes
del parser fueron errores: hay otras rutas posibles y no se entrego desglose.

## Esperas y alcance del siguiente cambio

Buffer IO: DetailBase 6,782 ms; INSERT RF_Complemento 4,686 ms;
INSERT Factura_General 1,767 ms; DELETE RF_Complemento 830 ms;
DELETE Factura_Detalle 521 ms. DetailBase registra ademas CPU 525 ms y
Memory 361 ms en las categorias de espera.

Son esperas de lectura de paginas reportadas por Query Store. No prueban
WRITELOG, bloqueo o un defecto de configuracion. No sumar esperas al tiempo
de la sentencia: ya estan comprendidas en su duracion. Los dos Table Scan de
MATERIAL reaparecen en el plan de DetailBase; las 5,275 llamadas del hash son
acumuladas y no son un contador de filas leidas de esta carga.

DetailBase y RF_Complemento son los siguientes costos visibles a revisar,
pero esta captura solo incluye dos modulos y no mide por separado COMMIT,
otras rutas, funciones o esperas de la sesion. No explica completamente los
58 s ni permite atribuir todo el resto al almacenamiento o a una sentencia.

Antes de otro parche, ejecutar [03_MEDIR_COSTO_ACTUAL.sql](03_MEDIR_COSTO_ACTUAL.sql)
en otra ventana de SSMS de la misma base mientras la siguiente carga normal
esta activa. Si se conoce el SPID, completar @SesionObjetivo; si no, la
consulta toma las sesiones activas de la base y devuelve su identificacion.
La observacion dura diez segundos. Guardar todos los resultados, en especial
05_ACTIVIDAD_INICIAL, 07_DELTA_LLAMADAS, 07B_SENTENCIAS_VENTANA y 08_DELTA_ESPERAS.
Las esperas de sesion incluyen trabajo no atribuido a estas consultas, como
una posible espera de confirmacion, cuya existencia debe verificarse.

03 y 04 ya son scripts existentes; no se cambia SQL de negocio, indices,
GETCONV ni transacciones en esta revision. La proteccion
RI8114_DETAILBASE_VACIO_V1 de INVOICE_TO_FACTURA permanece en el fuente:
TRY_CONVERT y NOT EXISTS omiten todo el detalle de la factura si tiene un
material no nulo no convertible, como R044. Cualquier optimizacion posterior
de DetailBase debe conservarla, asi como la multiplicidad del LEFT JOIN,
los MAX y las reglas de cantidades/importes.
