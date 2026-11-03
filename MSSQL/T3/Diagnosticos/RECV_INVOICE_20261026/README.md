# Correccion de accesos por ReferenceID

El reporte del 26 de octubre identifica dos DELETE del parser con 533.66 ms
y 61,074 lecturas logicas combinadas por llamada. Los indices ya existen.
Ver [analisis de la captura](ANALISIS_143154.md).

## Resultado confirmado por el usuario

Captura17:42:41 recibida: datosG:21.416ms/lectura (320lecturas/2.5MB),
logP:3.458ms/escritura. Senales de memoria baja=0; no ajustar memoria por
esta captura. CLIENTE_PK deshabilitado y sin otro acceso inicial activo por
CLIENTE_V3; CLIENTE_IDX1 porSAP activo. Usuario desconoce causa del DISABLE.
Se preparo [07_CREAR_ACCESO_CLIENTE_V3.sql](07_CREAR_ACCESO_CLIENTE_V3.sql):
acceso NO UNIQUE porV3/vigencias, preserva CLIENTE_PK y duplicados. Aplicar en
T3QA despues de terminar cargas y sin concurrencia sobre CLIENTE; construir
el indice consume IO/espacio y puede bloquear. IndicesCreados=1, o0 si ya hay
acceso activo porV3. Once casos con GET_REMISION_INFO real pasan; microprueba
1,210->20lecturas/call, no garantiza throughput integral. Pendiente aplicar
y medir. Ver [analisis y alcance](ANALISIS_174241.md).

Captura activa 17:31:57: sesion105 en FACTURA con PAGEIOLATCH_SH/EX,
10,185 ms de espera de paginas en ventana nominal10s; WRITELOG solo31ms.
FACTURA12llamadas/819msmedia/10msCPU. Otra ventana posterior al lote17:20;
no extrapolar esa tasa a todo el lote. Comparando con16:15 tambien aparecen
10PREVENTA nuevas/21.891s, incluidas OXXO20.863s y REMISION20.790s (anidados,
no sumar); ultima llamada17:20:57. Esta mezcla SI usa remision costosa.
Siguiente paso vigente: [06_REVISAR_IO_Y_MEMORIA.sql](06_REVISAR_IO_Y_MEMORIA.sql)
en otra ventana mismaDB DURANTE carga normal: latencia por archivo/memoria y
sentencias/indices remision. Ver [analisis](ANALISIS_173157.md).
No se cambia SQL de negocio hasta separar estos costos; conservar R044/GETCONV.

Ultima captura, 17:24:34: **ParcheSku=1**, parser modificado a las 17:01:22,
antes del lote 17:20:03-17:21:01 (869 registros/58 s = **14.98/s**).
curSKU registra ahora 0.229 s acumulados; los principales costos visibles
son DetailBase y RF_Complemento en INVOICE_TO_FACTURA, con esperas Buffer IO.
No se explica por completo el tiempo del lote. Antes de otro parche, ejecutar
[03_MEDIR_COSTO_ACTUAL.sql](03_MEDIR_COSTO_ACTUAL.sql) durante una carga normal
activa, en otra ventana de la misma base, y guardar todos los resultados.
Ver [analisis de la captura posterior a SKU](ANALISIS_172434.md).
La meta de 20-25/s permanece pendiente; las mediciones siguientes son historicas.

Parche aplicado antes del lote del 26 de octubre, 15:26:32-15:27:22:
**706 registros en 50 segundos, 847.2 registros/minuto**. Frente a la
referencia inicial aproximada de 100/min, la tasa observada fue unas
8.47 veces mayor. Ver [medicion posterior y alcance](RESULTADO_POSTERIOR_152632.md).
Segunda corrida, 15:30:32-15:31:23: **865 registros en 51 segundos,
1,017.65/min**. Ambas suman **1,571 registros en 101 segundos**, una tasa conjunta
de **933.27/min**, unas **9.33 veces** la referencia inicial aproximada.
No se ha recibido aun una medicion nueva de lecturas por sentencia ni RunId.

## Continuacion: recuperar la mejor marca historica

Captura 16:30: Query Store posterior confirma **33.322 s en 6,714 consultas
curSKU** (4.963 ms por partida, ~21.21 ms por registro del lote). Se preparo
[05_CORREGIR_BUSQUEDA_SKU.sql](05_CORREGIR_BUSQUEDA_SKU.sql), que ajusta solo
ese acceso en el parser instalado y conserva GETCONV, formulas y el parche
ReferenceID. Aplicar como administrador en T3QA cuando termine el lote y no
haya otra ejecucion/despliegue del flujo. Debe devolver **BloquesModificados=1**
y un nuevo **RunId**. Conservarlo: 02_REVERTIR_REFERENCEID.sql con ese RunId
revierte solo esta intervencion, manteniendo el ajuste ReferenceID anterior.
No ejecutar 01 otra vez para aplicar SKU.

Despues, medir una carga habitual con inicio/fin/procesados y repetir 04.
La seccion 01 de 04 informa ParcheSku y usa la nueva modificacion del parser
como corte para Query Store. No se garantiza 20-25/s por una microprueba.
Ver [evidencia, alcance y pruebas SKU](ANALISIS_163038.md).

Captura 16:15 recibida: el parche esta instalado y el parser registra las
1,571 llamadas de las cargas, media 63.82 ms / 928.29 lecturas. La ventana
de diez segundos se tomo despues del lote y no contiene actividad. Comparando
contadores acumulados con la primera captura, INVOICE_TO_FACTURA hizo 1,542
llamadas nuevas a 30.51 ms; OXXO solo 0.22 ms y GET_REMISION_INFO no intervino.
No optimizar sus promedios historicos como si fueran el costo de estas cargas.
Ver [analisis posterior](ANALISIS_161503.md).

Siguiente paso: ejecutar
[04_REVISAR_PARSER_Y_FACTURA.sql](04_REVISAR_PARSER_Y_FACTURA.sql) en la misma
base. **No requiere otra carga activa**: utiliza cache y Query Store existentes.
Entregar todos los resultados. Si se exportan planes, abrir la celda PlanXML
de cada fila de 06_PLANES_PROCEDIMIENTOS y guardar su contenido como .sqlplan.
Los propios planes de ejecucion del diagnostico no son los planes de negocio.

El usuario precisa que la mejor marca previa era **20-25 registros/segundo**
(1,200-1,500/min). Esta es la referencia de rendimiento; la mejora frente a
100/min no cierra el objetivo. Aun no se indicaron ambiente y mezcla de esa
marca historica, por lo que no se supone una comparacion A/B identica.

La ultima corrida alcanza 16.96/s. Para 865 registros, la referencia equivale
a 34.60-43.25 segundos; frente a los 51 observados, falta recortar
7.75-16.40 segundos de ese lote, unos 8.96-18.96 ms por registro.
No es un pronostico de que una optimizacion concreta vaya a obtener ese ahorro.

Para otra medicion de actividad durante una carga, ejecutar en otra ventana de la misma base
[03_MEDIR_COSTO_ACTUAL.sql](03_MEDIR_COSTO_ACTUAL.sql). Solo consulta
catalogos/DMVs y espera diez segundos; no ejecuta facturas ni cambia negocio.
Priorizar resultados 02 (marcas), 07 (llamadas), 07B (sentencias de la ventana)
y 08 (esperas). Las sentencias se identifican por los handles de los SP,
evitando el filtro de texto/dbid que no devolvio filas en la primera captura.

Se comparan solo planes/generaciones estables y contadores que aumentaron;
las sentencias nuevas o recompiladas durante la ventana quedan fuera del delta.
Una llamada terminada puede haber empezado antes de la muestra. Padres/hijos
siguen siendo inclusivos y las cifras de cache de procesos compartidos pueden
incluir otras sesiones. Si se conoce el SPID, completar @SesionObjetivo para
acotar actividad/esperas; los contadores de cache siguen siendo globales.

El costo previo de OXXO/GET_REMISION_INFO es un candidato a revisar, no una
medicion posterior al parche. El COUNT_BIG repetido del coordinador tambien
permanece, pero su microprueba no permite atribuirle decenas de segundos para
los lotes actuales. La marca sintetica antigua de 23.807 ms del parser aislado
no es rendimiento integral de facturas ni un objetivo productivo acreditado.

## Aplicacion en AZCRNMXNEVTD06 / T3QA

1. Esperar a que termine el lote habitual y aplicar sin otras ejecuciones ni
   despliegues concurrentes de este flujo. No iniciar otra corrida para aplicar.
2. Seleccionar T3QA y ejecutar completo
   [01_CORREGIR_REFERENCEID.sql](01_CORREGIR_REFERENCEID.sql) como administrador,
   sin transacciones abiertas ni implicitas.
3. Debe devolver **BloquesModificados = 3** y un **RunId**. Conservar ese valor.
   El respaldo se guarda en EAI_OWNER.RECV_INVOICE_PERF_BACKUP. Si ya estan los
   tres bloques, informa sin cambios y no crea otro respaldo.
4. Tras el siguiente lote normal comparable, repetir
   [el diagnostico focalizado](../RECV_INVOICE_RENDIMIENTO_FOCALIZADO.sql).
   Guardar resultados, cantidad de documentos completos y duracion del lote.

Solo cambia los tres DELETE de HEADER/DETAIL/CONDITIONS dentro de
SF_PROC_PREINVOICE_IFC. No modifica RECV_INVOICE, rutas, parametros, estados,
reglas de importes, folios, permisos, indices ni GETCONV. El archivo fuente
completo tambien integra los bloques, pero la aplicacion recomendada usa la
definicion INSTALADA para preservar variantes que no esten en el repositorio.

Las estadisticas del parser se reinician al ALTER por invalidacion del plan.
Comparar nuevos promedios y lecturas por llamada; no restar contadores del
plan anterior. El siguiente lote debe tener una mezcla/volumen comparable.
Una corrida sin errores no confirma por si sola las inserciones finales.

## Reversion solo si se requiere

Abrir [02_REVERTIR_REFERENCEID.sql](02_REVERTIR_REFERENCEID.sql), indicar el
RunId de la aplicacion y ejecutarlo sin lotes concurrentes. Se detiene si el
SP cambio despues del parche, para no perder correcciones posteriores. No
elimina indices ni mensajes y no inicia reprocesos. Restaura la definicion
inmediatamente anterior y conserva el respaldo con fecha de reversion.

## Validacion

Se probaron el parche, la reversion y el fuente mantenido en LocalDB, con
DDL real de las tablas temporales persistentes y dependencias de prueba.
Ver [resultado](tests/RESULTADO.md). La aplicacion la realizo el usuario y
confirmo despues dos mediciones: 706/50 s y 865/51 s. No se realizaron
conexiones remotas desde el agente ni se acredita otra base distinta de la
ultima identificada en las capturas.
