# Revision de indices: PROC_CFDI_PROCESAR_DOCTOS

## Indices creados para esta optimizacion

Estado: el usuario confirmo el 22 de octubre de 2026 que los dos indices ya se
encuentran en la base de produccion. No hay despliegue pendiente de estos
indices. La confirmacion no sustituye una inspeccion del ambiente ni constituye
una medicion de su rendimiento; los planes y cifras de este informe son de QA.
No se recibieron nombre de servidor/base de produccion ni fecha de despliegue.

Segun confirmacion del usuario del 22 de octubre de 2026, ambos indices se
crearon para optimizar `T3.PROC_CFDI_PROCESAR_DOCTOS`:

- `T3.FACTURA_GENERAL.IDX_FACTURA_GENERAL_FECHA`: cubre la seleccion de ventas
  Prompt por tipo y fecha BATMD. Ya estaba presente en la primera captura
  recibida para este analisis; eso no significa que fuera ajeno a la optimizacion.
- `T3.CFDI_DOCUMENTO_PASO.IX_CFDI_Paso_BATMD_RFC_Cobertura`: cubre las consultas
  de Paso y elimino los RID Lookup en las pruebas documentadas a continuacion.

La reduccion de 8,305 a 92 lecturas de Paso mide el efecto del segundo indice.
No se dispone de una prueba antes/despues aislada del primero y no se le
atribuye ese porcentaje.

## Resultado posterior a la creacion del indice: prueba favorable

Evidencia recibida: Ejecucion01.sqlplan/.rpt y Ejecucion02.sqlplan/.rpt, capturadas
en AZCRNMXNEVTD06/T3QA el 21 de octubre de 2026 a las 19:27:35 y 19:28:20,
ambas para el dia BATMD 2026-10-14. Esta seccion actualiza la propuesta de prueba
de las secciones anteriores: el usuario ya creo el indice candidato en T3QA.

Ambos planes utilizan IX_CFDI_Paso_BATMD_RFC_Cobertura mediante Index Seek.
Desaparecen los RID Lookup a CFDI_DOCUMENTO_PASO en ambos SELECT, conservando
CAST AS DATE y sin modificar la logica de las consultas.

| Metrica de STATISTICS IO/TIME | Inicial | Ejecucion 01 | Ejecucion 02 |
|---|---:|---:|---:|
| Individuales: lecturas logicas Paso | 8,305 | 92 | 92 |
| Individuales: lecturas logicas Factura_General | 4,445 | 4,416 | 4,416 |
| Individuales: CPU / transcurrido, ms | 47 / 649 | 0 / 72 | 0 / 10 |
| Agrupacion: lecturas logicas Paso | 8,305 | 92 | 92 |
| Agrupacion: CPU / transcurrido, ms | 123 / 86 | 31 / 36 | 47 / 36 |
| Individuales: filas devueltas | 1,085 | 1,085 | 1,085 |
| Agrupacion: grupos devueltos | 334 | 334 | 334 |

La reduccion de lecturas de Paso es 98.89% en cada consulta; en conjunto pasan
de 16,610 a 184. Incluyendo Factura_General en individuales, el total de las
tablas de negocio de ambos SELECT pasa de 21,055 a 4,600 lecturas (78.15%).
Las lecturas restantes estan concentradas en el join por FACTURA_PK de
Factura_General; ya es un acceso por la clave unica y no justifica duplicarla.

Se compararon todas las lineas de datos de los reportes inicial, 01 y 02,
ordenadas para ignorar diferencias de orden de presentacion, conservando
duplicados. No se detectaron diferencias en individuales ni en agrupacion.
Es una validacion de los valores tal como fueron exportados en esos archivos,
no una comparacion de tablas persistentes ni de otras fechas.

### Lectura del plan nuevo

- El indice lee 8,261 entradas en cada SELECT, con 92 lecturas, y aplica los
  filtros dentro del propio acceso. Devuelve 1,085 individuales o 7,176 notas
  agrupables. RFC como segunda clave no evita leer todas las entradas del dia
  en estos planes; la mejora demostrada procede de cobertura y eliminacion
  de accesos al heap.
- La agrupacion es ahora serial y mantiene Sort y Stream Aggregate, sin
  warnings de spill. No es necesario cambiar MAXDOP para obtener esta mejora.
- En agrupacion la memoria concedida pasa de 12,680 KB a 2,576 KB en 01 y
  1,536 KB en 02; uso maximo 824 KB. El XML indica ajuste de memory grant
  feedback en 02. La estimacion de grupos sigue alta (7,955.83 frente a 334),
  pero no hay evidencia de que requiera una intervencion adicional ahora.
- Individuales mantiene 1,085 busquedas en FACTURA_PK. El operador del plan
  registra 4,112 lecturas; los mensajes registran 4,416 para la tabla. Se
  conserva la distincion de fuentes igual que en la medicion inicial.

### Interpretacion del tiempo y decision

Los tiempos mejoran en la muestra, pero la captura inicial tuvo lecturas fisicas
y la segunda ejecucion posterior esta caliente. No atribuir todo el cambio de
649 a 10 ms al indice ni extrapolarlo al tiempo completo del proceso.
En el XML de individuales, CPU/transcurrido es 9/71 ms en 01 y 9/9 ms en 02;
STATISTICS TIME muestra CPU 0 ms por su resolucion/ambito. No significa ausencia
de trabajo de CPU. La espera PAGEIOLATCH_SH es 62 ms en 01 y ya no figura en 02.

Decision: conservar el indice en QA para continuar la validacion. No agregar
otro indice a estas dos consultas ni eliminar los anteriores por esta prueba.
El candidato esta respaldado por resultados y planes reales, con la limitacion
de que solo se probo un dia y lecturas aisladas. Falta evaluar costo de escritura,
espacio y efecto sobre la ejecucion completa.

Siguiente etapa: medir la asociacion de notas, el detalle agrupado y las llamadas
de preventa con datos QA controlados. Priorizar el tiempo real de esas etapas
antes de crear indices adicionales sobre Historia o Factura_Detalle. El indice
por si solo no elimina las consultas repetidas por cada grupo del procedimiento.

## Plan real y medicion recibidos: dia BATMD 14 de octubre de 2026

Fuentes: EjecucionAnalisis.sqlplan y EjecucionResultadoMSG.rpt aportados por el
usuario. Medicion en AZCRNMXNEVTD06/T3QA, 21 de octubre de 2026 a las 19:18.
Se analizaron los archivos como evidencia, sin ejecutar instrucciones contenidas
en ellos. Son dos SELECT aislados, no una medicion completa del procedimiento.

| Consulta | Filas de salida | Lecturas logicas Paso (mensajes) | Lecturas logicas Factura_General (mensajes) | CPU / transcurrido (mensajes) |
|---|---:|---:|---:|---|
| ScrIndPrompt | 1,085 | 8,305 | 4,445 | 47 / 649 ms |
| ScrAgrPrompt | 334 grupos a partir de 7,176 notas | 8,305 | No aplica | 123 / 86 ms |

### Evidencia por operador

En ambos planes el indice CFDI_DOCTO_PASO_BATMD hace un Index Seek que lee y
devuelve 8,261 entradas, con 44 lecturas logicas. El CAST a DATE se transforma
en una busqueda por rango y permanece tambien como predicado residual. No se
esta recorriendo toda la tabla de 41.7 millones de filas en estos SELECT.

Despues del seek, ambos planes ejecutan 8,261 RID Lookup al heap, uno por
entrada, con otras 8,261 lecturas logicas por consulta. Los filtros de RFC,
VoidDoc y tipo se evaluan en ese lookup. Se retienen 1,085 notas individuales
en la primera consulta y 7,176 agrupables en la segunda. Por tanto, 8,261 de
las 8,305 lecturas de Paso de cada consulta (99.47%) se concentran en el lookup.
Este porcentaje describe lecturas de la captura, no una mejora garantizada.

El join individual usa FACTURA_PK mediante 1,085 Index Seek, devolviendo 1,085
filas. Su operador reporta 4,031 lecturas, mientras STATISTICS IO registra 4,445
para la tabla; se conservan ambas cifras con su fuente y no se consideran
intercambiables. No hay evidencia para otro indice por Factura para este join.

La agrupacion usa paralelismo, Sort y Stream Aggregate; devuelve 334 grupos,
frente a una estimacion de 7,959.83. No hay warnings de spill y las Worktable
reportan cero lecturas. La memoria concedida es 12,680 KB, con uso maximo de
2,344 KB. Conviene reevaluar estimaciones y memoria despues del cambio de
cobertura; no agregar hints de memoria, MAXDOP ni RECOMPILE por esta unica prueba.

### Interpretacion de tiempos

En individuales, QueryTimeStats del XML registra 34 ms CPU y 648 ms transcurridos;
los mensajes registran 47/649 ms. WaitStats registra 614 ms PAGEIOLATCH_SH,
espera de lectura de paginas hacia el buffer. En mensajes hubo 79 lecturas
fisicas y 112 read-ahead en Paso; Factura_General tuvo 3 y 2 respectivamente.
No atribuir automaticamente esta espera a bloqueo ni diagnosticar un problema
del almacenamiento con una sola muestra.

En agrupacion, QueryTimeStats del XML registra 88 ms CPU y 54 ms transcurridos;
mensajes registra 123/86 ms. Paso tuvo cero lecturas fisicas/read-ahead; la
consulta se ejecuto despues de individuales y pudo aprovechar paginas ya en
cache. No presentar la diferencia de tiempo entre las dos como una comparacion
controlada de eficiencia. En paralelo el CPU acumulado puede superar el tiempo
transcurrido. Las esperas CXSYNC y ASYNC_NETWORK_IO observadas no justifican
por si solas modificar paralelismo o red.

### Decision para la primera prueba

La evidencia respalda probar el indice de cobertura propuesto en la seccion
siguiente, sobre (FECHA_PROC_BATMD,RFC_CLIENTE), INCLUDE de las columnas leidas
y filtro VOIDDOC IS NULL. Mantener inicialmente CAST AS DATE y las consultas
sin cambios para aislar el efecto del indice. No habilitar ni eliminar otros
indices durante esta prueba.

El optimizador tambien sugiere un indice faltante para la agrupacion con
impacto estimado 99.4231%. Es una estimacion de costo de esa consulta, no una
promesa de reduccion del tiempo total. No se copia literalmente su orden de
claves: la primera prueba busca cubrir ambos SELECT y el acceso por dia.

Validacion despues de crear el candidato en QA:

1. Repetir INDICES_MEDICION.sql con @dtFechaProcBATMD = '20261014', Ctrl+M y
   el mismo estado de datos. Repetir una vez antes y despues para comparar tambien
   ejecuciones con cache caliente; no vaciar caches compartidas.
2. Comparar filas completas y valores, no solo conteos. Para esta captura se
   esperan 1,085 individuales y 334 grupos si las fuentes no cambiaron.
3. Revisar que desaparezcan los RID Lookup a Paso y que bajen sus 8,305 lecturas
   por SELECT. El numero exacto posterior depende del plan y paginas del indice.
4. Conservar el plan nuevo y STATISTICS IO/TIME. Evaluar tambien espacio, tiempo
   de construccion y costo de escritura; el indice abarca una tabla grande.
5. Si ambos SELECT mejoran, medir la asociacion por grupo y el procedimiento
   completo con un estado QA controlado. Estas dos lecturas solas duran menos
   de un segundo en la captura; no permiten explicar un proceso total de minutos.

No se crearon indices en T3QA durante este analisis.

## Resultado de la captura recibida el 21 de octubre de 2026

Fuente: resultados aportados por el usuario, servidor AZCRNMXNEVTD06, base T3QA,
captura 2026-10-21 19:11:36 -06:00. SQL Server 16.0.4305.5 Developer, compatibilidad
160. Todas las tablas del diagnostico son visibles. No se consulto el servidor
directamente ni se crearon indices. Esta seccion reemplaza las decisiones
preliminares del inventario historico conservado mas abajo.

### Decisiones con el inventario actual

| Tabla | Evidencia actual | Decision |
|---|---|---|
| FACTURA_GENERAL, 25,082,494 filas | IDX_FACTURA_GENERAL_FECHA activo: (TIPO_DOCTO,FECHA_PROC_BATMD) INCLUDE(FACTURA,FECHA_FACTURA,CLIENTE_SAP,UBICACION,CTRO). | Descartar otro indice para la carga Prompt: este cubre las columnas de Factura_General que usa la consulta. Tiene 1 seek registrado; medir el plan actual antes de concluir que es suficiente en rendimiento. |
| CFDI_DOCUMENTO_PASO, 41,694,721 filas | CFDI_DOCTO_PASO_BATMD activo con solo FECHA_PROC_BATMD; 786 seeks y 6 scans. Los otros indices empiezan por FACTURA y uno incluye VOIDDOC. | Primera prueba candidata: cobertura de consultas por dia/RFC. Hay acceso temporal existente, pero las otras columnas requieren otra fuente de lectura. No hay evidencia para cuantificar los lookups de este procedimiento sin su plan real. |
| CFDI_HISTORIA_DOCTO_PAC, 73,454,731 filas | CFDI_HISTORIA_DOCTO_CFDI activo por NOTA_VENTA_CFDI; 375 seeks. Dos indices activos por NOTA_VENTA; IX_Ventas_PAC_NotaVenta incluye NOTA_VENTA_CFDI. | No crear otro indice simple por nota o CFDI. Segunda prueba: cubrir NOTA_VENTA en el acceso por CFDI si el detalle agrupado domina. Para preventa, evaluar FECHA_FACTURA como cobertura, con menor prioridad. |
| FACTURA_DETALLE, 91,757,273 filas | FACTURA_INDX activo por FACTURA; FACTDET_PK unico activo por FACTURA,NUM_LINEA; sin INCLUDE. | Candidato de segunda fase para cubrir material/precio/cantidad/importes. Revisar el plan y coordinarlo con Open Items antes de crear un indice ancho sobre esta tabla. |
| PREVENTA_GENERAL, 3,879,484 filas | PREVENTA_DISTPROC_IX tiene CENTRO antes de BATMD. IX_PG_C005 tiene CLIENTE_SAP entre CLASE_FACTURA y FECHA_FACTURA; no usa BATMD como clave. | Candidato especifico por clase/BATMD para no depender de CENTRO. Aplicarlo si la seleccion de preventas resulta costosa. |
| CLIENTE, 11,600,468 filas | CLIENTE_IDX1 unico y activo por SAP/inicio/fin; clustered por RFC. IX_Cliente_SAP_Vigencia e IX_Ventas_Cliente_SAP_Vigencia estan deshabilitados. | Corregir la interpretacion anterior: no hay tres indices activos equivalentes de vigencia. Mantener CLIENTE_IDX1; no reconstruir automaticamente los deshabilitados. RFC tiene cobertura implicita por la clave clustered; Lista_Precio puede requerir lookup. |
| CFDI_AGRUPADO, 3,682,207 filas | CFDI_AGRUPADO_IDX unico activo por NOTA_VENTA_CFDI, con 338 seeks. | El UPDATE por identificador tiene acceso existente. Descartar otro indice simple por esa clave. |
| REGISTRO_FISCAL, 154,783,623 filas | REGFIS_PK unico activo por FACTURA. | La actualizacion de bonificaciones ya puede localizar la factura. No proponer otro indice simple por FACTURA. |
| RF_PROCESOS_LOG, 1,061,404 filas | Dos indices activos por proceso/fecha y fecha/proceso; no se ve PID como clave. | El UPDATE final usa PID; posible candidato estrecho por PID si el plan confirma un scan costoso. Es una consulta por ejecucion, por debajo de las consultas repetidas por grupo en prioridad. |

### Primera prueba propuesta

Evaluar un indice de cobertura en CFDI_DOCUMENTO_PASO, con este diseno inicial:

```sql
-- Propuesta para revisar y medir; no se ejecuta desde el diagnostico.
CREATE NONCLUSTERED INDEX IX_CFDI_Paso_BATMD_RFC_Cobertura
ON T3.CFDI_DOCUMENTO_PASO (FECHA_PROC_BATMD, RFC_CLIENTE)
INCLUDE (FACTURA, CTRO, FECHA_FACTURA_T3, FECHA_FACTURA_V3,
         TIPO_DOCTO, UBICACION, LISTA_PRECIO, CLIENTE_AGRUPADO, VOIDDOC)
WHERE VOIDDOC IS NULL;
```

Cubre las columnas de paso leidas por individuales, agrupacion y asociacion de
notas, incluidos los filtros. No incluye RFC_FACTURA porque estas consultas no
lo leen. Su beneficio potencial es evitar accesos al heap y disponer de un
conjunto mas estrecho para el dia. La segunda clave RFC puede no formar parte
del seek efectivo cuando la fecha se trata como rango; revisar predicados
residuales y lecturas. No elimina necesariamente los sorts de la agrupacion.

Todos esos bloques filtran VOIDDOC IS NULL. Se incluye VOIDDOC tambien en el
indice para evitar limitaciones del uso de indices filtrados por IS NULL,
documentadas por [Microsoft](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/filtered-index-with-column-is-null).
Si casi toda la tabla tiene VOIDDOC NULL, el filtro apenas reducira su tamano:
la mejora esperada procede principalmente de cobertura, no de asumir que el
indice sera pequeno. Construirlo puede requerir leer 41.7 millones de filas,
espacio y log; se debe programar y medir. No se elimina el indice BATMD actual
como parte de la prueba, pues otros procesos pueden utilizarlo.

La alternativa para el detalle, si los planes la justifican, seria
(FACTURA) INCLUDE(MATERIAL,PRECIO_UNIT,CANTIDAD_VTA,VALOR_SUBT,VALOR_IVA,
BONIF_SUBT,BONIF_IVA). El indice por CFDI en historia podria cubrir NOTA_VENTA.
Son cambios separados: no crear los tres simultaneamente al medir la primera
prueba. Para preventas, evaluar (CLASE_FACTURA,FECHA_PROC_BATMD)
INCLUDE(FACTURA,CTRO,CLIENTE_SAP,FECHA_FACTURA,FECHA_CANCELACION)
WHERE FECHA_CANCELACION IS NULL; preservar la seleccion actual C005/C006.

### Limites de la evidencia y medicion siguiente

- La instancia inicio el 17 de octubre de 2026 a las 06:41:37. El uso es acumulado
  de todos los procesos y puede tener reinicios adicionales. Un seek no es una
  fila ni un scan demuestra una lectura completa o un problema de rendimiento.
- Hay indices hoy deshabilitados con contadores anteriores. Su uso historico
  no significa que esten disponibles para el optimizador en la captura actual.
- El inventario muestra heaps grandes, pero su existencia no justifica convertir
  todas las tablas a clustered: eso cambiaria tambien los indices no agrupados.
- El diagnostico no inventario los heaps en la salida de uso (filtra index_id>0).
  Los ceros de user_lookups en indices no agrupados no prueban ausencia de
  RID Lookup al heap. Para CLIENTE, los 19,381 lookups del clustered son globales,
  no atribuibles a este procedimiento.
- Las estadisticas BATMD de paso se actualizaron el 21 de octubre con 7,095
  modificaciones posteriores; las de IDX_FACTURA_GENERAL_FECHA tienen muestreo
  completo y cero modificaciones. No hay motivo para un FULLSCAN general.
- No se recibio plan real, IO/TIME, distribucion de VOIDDOC ni filas por dia.
  No se puede afirmar todavia cual etapa consume mas tiempo o cuanto mejorara.

Siguiente paso: capturar planes y STATISTICS IO/TIME de las consultas de lectura
de ScrIndPrompt, ScrAgrPrompt y la asociacion de notas de un grupo representativo,
antes/despues del candidato. Mantener CAST AS DATE como se acordo y comprobar
su acceso por fecha. Las lecturas aisladas pueden medirse sin ejecutar los INSERT
ni las llamadas a generacion CFDI. Para el tiempo total, preparar una prueba QA
con el mismo estado de datos y sin reejecutar indiscriminadamente el procedimiento.

---

## Antecedente: revision preliminar con el inventario del 9 de octubre

Revision del codigo y de la captura historica de T3QA conservada en
`MSSQL/T3/EAI/Procedures/SF_CFDI_OPEN_ITEMS_DIAGNOSTICO.SQL`, identificada en su
informe de revision como captura del 9 de octubre de 2026. No se consulto T3QA
directamente. Los indices instalados hoy deben confirmarse con el diagnostico
adjunto; no hay una recomendacion de creacion aprobada ni cambios en la base.

## Hallazgos y orden de revision

| Prioridad | Tabla / consulta | Evidencia disponible | Decision inicial |
|---|---|---|---|
| 1 | CFDI_DOCUMENTO_PASO: individuales, grupos y asociacion por grupo | El inventario anterior no incluye esta tabla. El DDL del repositorio no declara indices, lo cual no demuestra su ausencia en T3QA. | Obtener inventario y volumen. Es el primer punto a revisar por sus consultas repetidas dentro del cursor de grupos. Evaluar acceso por fecha/RFC y un indice filtrado a VoidDoc IS NULL, segun distribucion y plan. |
| 1 | FACTURA_GENERAL: carga Prompt por dia BATMD y tipo | FACTURA_PK empieza por Factura; FG_IDX_2 por Fecha_Factura. FG_INDX y PK_FACTURA_FECHA_PROC aparecen deshabilitados. Ninguno de los activos capturados empieza por BATMD. | Evaluar (Fecha_Proc_BATMD,Tipo_Docto) INCLUDE(Factura,Ctro,Fecha_Factura,Ubicacion,Cliente_SAP). El orden inverso tambien es candidato segun selectividad y plan. No habilitar los deshabilitados automaticamente. |
| 2 | PREVENTA_GENERAL: dia BATMD, clase y cancelacion | PREVENTA_DISTPROC_IX empieza por Centro, luego BATMD; la consulta no filtra Centro. IX_PG_C005 empieza por Clase_Factura,Cliente_SAP,Fecha_Factura,Entrega. | Evaluar (Clase_Factura,Fecha_Proc_BATMD) INCLUDE(Factura,Ctro,Cliente_SAP,Fecha_Factura,Fecha_Cancelacion), posiblemente filtrado a Fecha_Cancelacion IS NULL. Confirmar primero si el plan y volumen justifican otro indice. |
| 2 | CFDI_HISTORIA_DOCTO_PAC: detalle de un agrupado | CFDI_HISTORIA_DOCTO_CFDI ya tiene Nota_Venta_CFDI como clave; no aparecen columnas incluidas en la captura. | Ya existe acceso por CFDI. Evaluar cubrir Nota_Venta para evitar acceso adicional a la tabla, solo si el costo observado lo justifica. |
| 2 | CFDI_HISTORIA_DOCTO_PAC: elegibilidad de preventas | CFDI_HIST_DOCTO_PAC_NOTA_IX y IX_Ventas_PAC_NotaVenta empiezan por Nota_Venta; el segundo incluye Nota_Venta_CFDI, no Fecha_Factura. | Ya existe acceso por nota. Evaluar cobertura de Fecha_Factura; el filtro actual acepta historia con fecha nula. No sustituir por un indice filtrado ni NOT EXISTS sin revisar equivalencia. |
| 2 | FACTURA_DETALLE: suma por material/precio para cada CFDI | FACTURA_INDX tiene Factura; FACTDET_PK tiene Factura,Num_Linea; la captura no muestra INCLUDE. | Evaluar (Factura) INCLUDE(Material,Precio_Unit,Cantidad_Vta,Valor_Subt,Valor_IVA,Bonif_Subt,Bonif_IVA). Comparar con los indices propuestos/instalados para Open Items antes de agregar otro indice ancho sobre unos 91.6 millones de registros de la captura anterior. |
| 3 | CLIENTE: SAP y vigencia | CLIENTE_IDX1, IX_Cliente_SAP_Vigencia e IX_Ventas_Cliente_SAP_Vigencia tienen claves solapadas; algunos cubren RFC. No se ve Lista_Precio incluida. | No proponer otro indice completo de cliente de entrada. Medir si los accesos a Lista_Precio son relevantes y luego valorar consolidacion con los otros procesos. |
| 3 | FACTURA_GENERAL: join de individuales por Factura | FACTURA_PK ya tiene Factura como primera clave activa. | Acceso existente. Verificar multiplicidad de Factura antes de reemplazar el join por EXISTS; un indice no resuelve duplicados de negocio. |
| 3 | CFDI_AGRUPADO: UPDATE por Nota_Venta_CFDI | Fuera de la captura previa. | Confirmar acceso por Nota_Venta_CFDI. Puede ser importante si se actualiza un encabezado por grupo en una tabla historica grande. |
| 3 | PREVENTA_DETALLE / REGISTRO_FISCAL: procedimiento de bonificaciones | FACTURA_IDX de Preventa_Detalle ya empieza por Factura; faltan datos de Registro_Fiscal en ese inventario. | Revisar cobertura de Bonif_Subt/Bonif_IVA y acceso a Registro_Fiscal por Factura si la etapa de preventas consume una parte relevante del tiempo. |

Estos son disenos candidatos, no instrucciones para crearlos todos. No se
eliminan indices ni se modifican restricciones basandose en nombres o contadores
de uso aislados. Una clave clustered puede aportar cobertura implicita que debe
considerarse al revisar INCLUDE.

## CAST a DATE y acceso por fecha

Se conserva la decision de comparar solo el dia mediante CAST de columna y
parametro. No se asume que esa conversion siempre cause un scan: SQL Server puede
transformar ciertos predicados de fecha en accesos por rango. Se debe revisar el
plan, las filas leidas frente a las devueltas y los predicados residuales.

La primera alternativa a medir es un indice sobre la columna BATMD existente.
Si el CAST limita el acceso o las estimaciones, comparar con el rango diario y,
si se quiere mantener el CAST, evaluar una columna calculada DATE indexada cuya
expresion corresponda al filtro. Esta ultima opcion modifica la tabla y requiere
revisar expresion, opciones SET y costo de mantenimiento; no es el primer cambio.

## Obtener la evidencia actual

1. Ejecutar `PROC_CFDI_PROCESAR_DOCTOS.INDICES_DIAGNOSTICO.sql` en la base que
   utiliza el procedimiento. La primera salida identifica servidor, base y fecha.
2. Conservar todos los conjuntos de resultados. El script muestra volumen
   aproximado, claves/INCLUDE/filtros, indices deshabilitados, columnas calculadas,
   uso acumulado y estadisticas. No recorre tablas de negocio con COUNT(*).
3. Si hay una ejecucion activa, asignar su sesion a @SPID para capturar sentencia,
   lecturas, espera y plan compilado. Un resultado vacio no prueba que no haya
   bloqueos durante otras ejecuciones.
4. Con un dia representativo, obtener el plan real y STATISTICS IO/TIME en QA.
   El procedimiento inserta datos: no repetirlo como benchmark sin preparar el
   mismo estado inicial y controlar el procesamiento CFDI delegado.
5. Seleccionar un cambio a la vez segun lecturas/tiempo, comparar resultados y
   medir tambien el costo de insercion y espacio. No actualizar toda la base con
   FULLSCAN ni vaciar caches como parte de esta revision.

La edad de una estadistica o pocos seeks por si solos no justifican un cambio.
El uso refleja todos los procesos y una ventana que puede reiniciarse. La falta
de permisos o de visibilidad debe resolverse antes de interpretar salidas vacias.

Referencia: [guia de diseno de indices de Microsoft](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide).
