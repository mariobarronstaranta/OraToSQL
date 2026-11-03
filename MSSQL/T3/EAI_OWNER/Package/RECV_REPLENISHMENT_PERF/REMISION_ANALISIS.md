# DELIVERY_IDOC_TO_REMISION: revision de la definicion desplegada

## Ejecucion instrumentada 20/10 13:52

Archivo Resultados_Ejecucion.txt: 18921746 bytes, ~445558 lineas.
Inicio 13:52:18.3550526, fin 13:52:46.5806048, duracion 28225 ms,
CPU inclusiva 9642 ms. TransaccionesSalida=0 y EstadoTransaccion=0.
No se encontraron patrones Msg numero, Error -> ni Warning: en Mensajes.
Esto no descarta errores que el codigo solo inserte en tablas de log.
El archivo no reporta total de documentos completados correctamente.

IO por reporte individual: TMP_DOCUMENT_HEADER maximo 11 lecturas,
TMP_DOCUMENT_DETAIL maximo 13; ya no se ven los accesos de decenas de miles
por operacion que precedian al parche. Acumulados de las lineas IO (no
confundir con contadores exclusivos de cada procedimiento): MATERIAL 24085,
HEADER 23561, DETAIL 13974, REMISION_GENERAL 213, REMISION_DETALLE 8.
No atribuir MATERIAL entero a remisiones: incluye parser y otras llamadas.

Seleccion inicial de pendientes: 8187 lecturas, 96 ms.
Cierre RF_PROCESOS_LOG: 10310 lecturas, 34 ms elapsed/251 ms CPU.
INSERT inicial RF_PROCESOS_LOG: 174 ms, 7 lecturas fisicas.
Indice PID sigue siendo mejora de IO, pero el cierre no domina este lote.

No se repite un bloque reportado de 7.33 segundos. Mayor elapsed interno
reportado excluyendo total: 627 ms; un acceso HEADER de cuatro lecturas
reporta 541 ms/0 CPU. Esto sugiere tiempo ajeno a CPU, pero no identifica
espera/bloqueador concreto. Los tiempos incluyen anidamiento y no se suman.
Las lineas no identifican el procedimiento de cada bloque, por lo que no
se puede asignar una duracion exacta a DELIVERY_IDOC_TO_REMISION.
La emision de ~18 MiB de diagnostico puede afectar el elapsed del lote.

Pedir total de documentos exitosos para calcular throughput. Una medicion
normal posterior debe hacerse sin STATISTICS IO/TIME para comparar rendimiento.
No justificar una reescritura de cursores o un indice de cobertura grande
como solucion de los 7.33 segundos con esta muestra.

## Plan completo recibido: Analisis.sqlplan (754582 bytes)

Plan de cache sin RunTimeCountersPerThread: no contiene filas/tiempos reales
por operador. Hallazgos comprobados en XML:

- ScrData, nodo 10: Index Seek TMP_DOCUMENT_HEADER_IXREF por
  ReferenceID=@sDocument, estimacion 1.01401 filas.
- ScrDetail, nodo 13: Index Seek TMP_DOCUMENT_DETAIL_IDX por
  ReferenceID=@sDocument, estimacion 300.02 filas.
- ScrDetail, nodo 15: RID Lookup al heap para columnas/filtro Cantidad;
  nodo 16: Table Scan MATERIAL de 8791 filas, Hash Match, Sort y
  materializacion en tabla interna de cursor CWT_PrimaryKey.
- La estimacion de ~300 filas contrasta con tres INSERT de detalle observados,
  pero no se dispone de filas reales del SELECT para cuantificar el error.
- El mayor costo estimado de los planes de cursores es ScrDetail (1.37621).
  Son unidades de estimacion, NO segundos ni porcentaje del tiempo real.
- Compilacion visible de los planes de cursores: ScrData 96 ms, ScrDetail
  8 ms, ScrCartones 69 ms, ScrCtroSociedad 0 ms. No explica por si sola
  los 7332 ms inclusivos; tampoco mide toda compilacion de llamadas hijas.
- No se observa en estos accesos el problema de conversion Unicode que
  corregimos en el parser. No agregar otro indice por ReferenceID.

Siguiente medicion: SET STATISTICS IO/TIME durante el siguiente lote manual
habitual con documentos nuevos que incluya remisiones. Guardar Mensajes
completo y volver a consultar 03_DIAGNOSTICO_REMISION. No ejecutar directamente
una referencia ya procesada: se descartaria por existencia y sesgaria la prueba.
Sin medicion real no se justifica aun un indice de cobertura adicional sobre
13 millones de detalles, forzar seeks/joins o reescribir los cursores.

## Resultado del diagnostico enfocado, 20/10 13:29

Sigue siendo la misma unica llamada de 13:16:46: 7332.094 ms, CPU 2571.829 ms,
63765 lecturas. No es una nueva muestra.
INSERT REMISION_GENERAL: 29.426 ms y 11 lecturas.
INSERT REMISION_DETALLE: 3 ejecuciones, 0.160 ms total, 4 lecturas cada una.
Los FETCH visibles son inferiores a 1 ms; no aparece el UPDATE de cartones.
No hay errores registrados en las colas consultadas del dia.
La evidencia no respalda que insertar detalle por cursor o actualizar cartones
explique el tiempo de esta llamada. El riesgo de integridad de cartones sigue
siendo un hallazgo estatico separado.

Catalogos: REMISION_CTRO_SOCIEDAD tiene 9 filas, DISTRIBUIDOR_FISCAL 212,
ZSDFE_SOC 13, MATERIAL 8791, MX_HASHTABLE 5382. No priorizar indices de Ctro
por su ausencia solamente. Tablas grandes: TMP_DOCUMENT_DETAIL 13204337,
TMP_DOCUMENT_HEADER 3178592, REMISION_DETALLE 6271737, REMISION_GENERAL 997706.
Tipos/collation de claves del flujo son VARCHAR compatibles; no se demuestra
un conflicto Unicode como en SF_PROC_REPLENISHMENT.

La lista de sentencias no reconcilia los 7.33 segundos ni las 63765 lecturas
inclusivas. Falta inspeccionar plan completo de cursores/hijos; el resultado
pegado corta cada XML a 256 caracteres. Solicitar la celda PlanXML completa
de 03_PLAN_COMPLETO como .sqlplan/.xml, no repetir otra captura de texto truncada.
El plan de cache permite revisar accesos/estimaciones, pero no adjudicar esperas
historicas; si no resuelve la causa, medir otra remision nueva con plan real/IO
en el proceso habitual sin reprocesar documentos existentes.

Fuente indicada por el usuario:
`MSSQL/T3/T3/Procedures/DELIVERY_IDOC_TO_REMISION.sql`,
exportacion 20/10/2026 13:24:26. No confundir con el archivo antiguo
`DELIVERY_IDOC_TO_REMISION.sql`.

Los 178 documentos del lote 13:16:45–13:17:04 fueron confirmados exitosos.
El parche ReferenceID de SF_PROC_REPLENISHMENT queda validado en ese lote.
La captura registra una llamada de remision de 7332.094 ms, 2571.829 ms CPU
y 63765 lecturas, durante el lote. Es una sola llamada, no una media estable.
El tiempo incluye hijos; no sumarlo al tiempo inclusivo del parser.
La diferencia entre CPU y elapsed no identifica por si sola bloqueo ni IO.

## Cambios respecto a la copia antigua

- Usa EAI_OWNER.getConv, que existe. No requiere crear dbo.getConv.
- El FETCH de detalle recibe unidad antes de cantidad, de acuerdo con el SELECT.
- Ya no libera ScrCtroSociedad despues de la primera lectura de origen.
  El segundo OPEN para destino funciona en el primer encabezado.
- Los parametros ReferenceID/Factura son VARCHAR y las columnas observadas
  tambien: no aplicar automaticamente la solucion NVARCHAR del parser.

## Candidatos y defectos concretos

1. **ScrCartones actualiza por Factura, no por linea** (lineas 186–207 y 470–494).
   El SELECT devuelve una fila por partida/material, pero cada UPDATE modifica
   todas las lineas de esa factura. Con N lineas y K conversiones puede generar
   hasta N*K escrituras, ademas de asignar a todas la cantidad de otra partida.
   La existencia de indice por Factura no corrige la seleccion de filas.
   Propuesta: transportar Num_Linea y actualizar por la clave real de partida,
   o realizar una actualizacion por conjuntos con correspondencia uno a uno.
   Antes: comprobar duplicados de Factura/Num_Linea y cardinalidad de Material;
   probar CAJ/PAQ, conversion integral/no integral, factores cero/NULL, lineas
   repetidas y documentos de varias partidas. Cambia resultados en casos donde
   el codigo actual sobrescribe lineas: no presentarlo como parche solo de tiempo.
   El diagnostico actual no prueba que este bucle consumiera los 7.33 segundos.
2. **ScrDetail inserta por partida**. Candidato a INSERT SELECT una vez medido
   su peso. Preservar filtros positivos, conversiones TH/EA/PC, uso de BaseUM,
   escala de acumulacion NUMERIC(18,2) y efectos de triggers/errores parciales.
   No reemplazar automaticamente la acumulacion por SUM: el redondeo por
   iteracion puede diferir de redondear la suma final.
3. **ScrData y joins**. Los accesos grandes por ReferenceID, Factura, Material
   y Type/Source ya tienen indices. Faltan claves iniciales por Ctro en
   REMISION_CTRO_SOCIEDAD y DISTRIBUIDOR_FISCAL, pero no conocemos tamanos ni
   operador caro. Medir antes de crear indices sobre catalogos posiblemente pequenos.
4. **Cursores desasignados dentro del bucle de encabezados**. ScrCtroSociedad,
   ScrDetail y ScrCartones no pueden reabrirse despues de DEALLOCATE si hay
   un segundo encabezado que los requiera. Conservar CLOSE por vuelta y
   DEALLOCATE final; limpiar segun CURSOR_STATUS tambien en CATCH.
   Solo afecta ramas con varias filas de ScrData; no afirmar que fallo este lote.
5. **Estado entre encabezados**. @nBase_Cantidad se inicializa fuera del bucle
   y no se reinicia por factura. El control de volumen cero puede usar volumen
   anterior. @sSociedadDest tambien puede conservar valor previo si Origen=0000.
6. **FORMAT innecesario**. El calculo de @sRem_Ctro por anio se sobrescribe
   incondicionalmente con @sSociedad antes de usar el folio. Quitar el trabajo
   redundante es posible, pero no explica por si solo los 7.33 segundos.
7. **CATCH registra/imprime y no relanza**. No existe transaccion local de
   documento. Revisar atomicidad y propagacion separadamente de rendimiento.
   La confirmacion de negocio del usuario respalda el lote probado, no elimina
   los riesgos en otras ramas.

## Medicion siguiente

03_DIAGNOSTICO_REMISION.sql consulta todas las sentencias de este procedimiento,
su plan completo, errores de remision y metadatos/tamanos. El diagnostico general
solo entregaba TOP 40 global y no explicaba el tiempo interno de los cursores.
No reprocesar una remision existente para medirla: puede tomar la rama de descarte
y dar una comparacion falsa. Si se necesitan mas muestras, usar documentos nuevos
por el mecanismo habitual y separar arranque/compilacion de llamadas posteriores.

No se modifico la definicion entregada ni se aplicaron cambios a T3QA en esta
revision. Prioridad: localizar el operador costoso y confirmar los datos antes
de combinar cambios de rendimiento con correcciones de partidas.
