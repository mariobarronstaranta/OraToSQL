# Resultado del plan: primera mejora concreta

El plan historico 8889 confirma un **Table Scan de CFDI_COBRANZA** para el
UPDATE de Asignacion_Central. La primera mejora propuesta es un indice
nonclustered compuesto sobre **(ASIGNACION_CENTRAL, FECHA_PROCESO)**, con
**INCLUDE (ASIGNACION_ID, FACTURA)**. No requiere modificar el procedimiento.

Fuente: `05_Reporte_Original.txt`, captura del 03/11/2026 13:36:47 -06:00,
AZCRNMXNEVTD06 / T3QA. Query_id 32735, plan_id 8889, query hash
`0xFCE94AEBA309D33F`. Plan compilado el 29/10/2026 06:17:07 UTC, no forzado.
El parametro usado al compilar fue @nDias=30. La ejecucion historica asociada,
segun los reportes 01/04, duro 107.029831 s en este UPDATE.

## Integridad y alcance

Se reconstruyeron los 159 fragmentos del plan completo, sin faltantes ni
numeros repetidos. El XML resultante tiene 28,451 caracteres, es valido y se
guardo como `PLAN_8889_RECONSTRUIDO.sqlplan`. Tambien se recupero la sentencia
SQL completa en `UPDATE_QUERY_32735.sql`.

Este es un plan **compilado**, sin RunTimeInformation por operador. Las filas,
costos y reejecuciones que contiene son estimaciones. No demuestra cuantos
registros devolvio realmente cada operador ni reparte los 107 s entre tablas.
Las lecturas y las esperas medidas del reporte 04 complementan esta evidencia.

## Accesos encontrados

| Nodo | Operador y objeto | Evidencia del plan |
|---|---|---|
| 16 | Table Scan T3.CFDI_COBRANZA | 56,115,100 filas estimadas a leer; 15,465.6 filas estimadas despues del filtro. |
| 13 | Table Scan EAI_OWNER.TMP_ACCOUNT_HEADER | 1,096,190 filas estimadas a leer; filtra FiscalYear del anio actual. |
| 12 | Hash Match entre cobranza y compensaciones | Cruza ClearingDocNumber con SUBSTRING(Asignacion_ID,3,10). |
| 17 | Index Seek T3.REGISTRO_FISCAL / REGFIS_PK | Busca Factura; no es un escaneo de las 154.8 millones de filas fiscales. |
| 19 | RID Lookup T3.REGISTRO_FISCAL | Accede al heap para evaluar Entrega/Referencia y los filtros de Assignment. |
| 4 | Hash Match Aggregate | Agrupa por identificador de fila destino y obtiene ANY(Assignment). |
| 0 | Table Update CFDI_COBRANZA | Asigna el valor a la fila de cobranza. |

El nodo 16 aplica estos predicados despues de leer la tabla:

```sql
Cobza.Asignacion_Central IS NULL
AND Cobza.Fecha_Proceso > CAST(DATEADD(DAY,-ISNULL(@nDias,0),GETDATE()) AS date)
```

La expresion de fecha esta en el lado del limite, no envuelve la columna
FECHA_PROCESO. El nuevo indice permite buscar por la igualdad IS NULL de la
primera clave y el rango de la segunda, teniendo disponibles las dos columnas
necesarias para los cruces. El optimizador conserva la decision final de uso.

El indice actual CFDI_COBRANZA_IDX8 sobre FECHA_PROCESO no incluye las otras
columnas requeridas. El indice IDX_BUSQUEDA_PAGOS tiene otras primeras claves
y no cubre ASIGNACION_CENTRAL. Ninguno equivale al candidato observado.

## Sugerencia del optimizador

El XML contiene dos sugerencias con la **misma definicion**, con impactos
estimados 63.0232 y 63.0283. Se consolidan en **un solo indice**, no dos:

```sql
CREATE NONCLUSTERED INDEX [IX_CFDI_COBRANZA_ASIGCENTRAL_FECPROC]
ON [T3].[CFDI_COBRANZA] ([ASIGNACION_CENTRAL], [FECHA_PROCESO])
INCLUDE ([ASIGNACION_ID], [FACTURA]);
```

Ese 63 % es una reduccion hipotetica del costo del plan, no una mejora medida
de tiempo ni una prediccion de cuantos segundos tardara. Las sugerencias se
generan durante optimizacion y requieren validacion con ejecuciones posteriores.
[Microsoft: uso y limitaciones de indices sugeridos](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/tune-nonclustered-missing-index-suggestions).

Se propone inicialmente un indice ordinario sin filtro, directamente respaldado
por el plan. La selectividad historica total de ASIGNACION_CENTRAL IS NULL aun
no se midio; no se agrega por ahora una variante filtrada ni una columna calculada.
No se cambian el corte de dias, el detalle historico ni la llamada al liberador.

## Segunda prioridad y observaciones

REGFIS_PK ya se usa para buscar Factura, pero no cubre Entrega/Referencia: por
eso aparece el RID Lookup. Evaluar su cobertura despues de medir el primer
indice, en lugar de modificar ahora un indice sobre 154.8 millones de registros.
El Table Scan de TMP_ACCOUNT_HEADER tiene un costo estimado mucho menor que
el de cobranza; no se justifica duplicar su indice ClearingDocNumber/FiscalYear.

Las estadisticas de ASIGNACION_ID consultadas por este plan incluyen
CFDI_COBRANZA_IDX del 21/10; no aparece la automatica del 28/07 observada en el
04. Tampoco aparece FECHA_PROCESO/IDX8 entre las estadisticas listadas en el
XML. Esto no demuestra un error de estimacion ni justifica actualizar todas
las estadisticas. El plan no contiene Warnings; sus GrantedMemory=0 y
MaxUsedMemory=0 son campos del plan compilado, no mediciones de memoria real.

ANY(Assignment) indica que el motor puede escoger uno de los valores si el
JOIN devuelve varias alternativas para una fila. El plan no prueba que eso
ocurra con estos datos. La comprobacion previa del script 06 busca solamente
alternativas distintas que pasan **todos los filtros originales** para la
cobranza reciente sin asignacion; acepta duplicados con el mismo Assignment.
Compara bytes y longitud para detectar tambien diferencias de mayusculas o
espacios. Si encuentra alternativas diferentes, no crea el indice y muestra
hasta 20 claves para revisar, sin inventar una regla MIN/MAX.
[Microsoft: UPDATE con multiples valores de origen](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql).

## Pasos preparados

1. Ejecutar `06_INDICE_UPDATE_COBRANZA.sql` con **@Aplicar=0**. Devuelve los
   indices actuales y la propuesta; no lee tablas de negocio ni crea el indice.
   Este modo comprueba metadatos, no construye el indice en una transaccion de ensayo.
2. Para aplicar la mejora, ejecutar completo con **@Aplicar=1** en una ventana
   acordada. La construccion lee 56 millones de filas, ocupa datos/log y puede
   bloquear escritores. Antes hace la comprobacion de alternativas elegibles
   con @nDias=30 para el alcance actual; esa comprobacion tambien puede ser costosa.
   Coordinar la ausencia de escritores/procesos concurrentes durante esa ventana.
3. Si ya existe un indice activo equivalente, incluso con otro nombre y con
   cobertura adicional, el 06 termina sin duplicarlo. Si el nombre esta ocupado
   con otra definicion o estado, informa el conflicto sin sustituirlo.
4. Despues de la siguiente corrida de negocio autorizada, ejecutar
   `07_VALIDAR_MEJORA_UPDATE.sql`. Para aislar el periodo, ajustar @Desde al
   momento de creacion que reporto el 06. El 07 no ejecuta el procedimiento;
   consulta cache y Query Store, muestra uso del indice y nuevas metricas.

Comparar mismo @nDias y carga semejante. Una corrida que encuentre menos datos,
o datos ya asignados por otra ejecucion, no prueba por si sola una mejora.
Los intervalos de Query Store que cruzan el corte pueden mezclar ejecuciones
anteriores y posteriores; revisar tambien las fechas y el plan utilizado.
Los 107.03 s son una referencia de una corrida, no una linea base estadistica.

No se modificaron SP, datos, indices ni configuracion de T3QA. El DDL queda
preparado para revision/aplicacion por el usuario. Pruebas locales: ocho
comprobaciones aprobadas; detalles en `VALIDACION_06_07.txt`.
