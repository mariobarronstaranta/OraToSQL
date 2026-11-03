# Resultado 04: el UPDATE espera lecturas de datos

Fuente: `04_Reporte_Original.txt`, captura de AZCRNMXNEVTD06 / T3QA del
03/11/2026 13:20:36 -06:00. La ejecucion estudiada sigue siendo la del
**29/10/2026 00:17:07**; ejecutar el diagnostico no volvio a correr el proceso.

## Hallazgo principal

El UPDATE inicial de Asignacion_Central presenta una carga importante de
lectura fisica y las esperas de lectura dominan el historial recibido.
La prioridad es revisar sus accesos a datos y reducir las lecturas necesarias.

| Medida del UPDATE | Resultado |
|---|---:|
| Duracion | 107.029831 s |
| CPU | 16.456611 s |
| Lecturas logicas | 2,701,949 |
| Lecturas fisicas | **1,314,995** |
| Escrituras logicas reportadas | 0 |
| Query Store query_id / plan_id | **32735 / 8889** |
| Ejecuciones historicas en la ventana | 1, Regular |
| Plan forzado | No |

La cache y Query Store coinciden en duracion, CPU, lecturas logicas y query
hash `0xFCE94AEBA309D33F`. El query_id 28113 tambien tiene el mismo hash,
pero no devuelve ejecuciones de esa ventana: no se debe atribuirle esta corrida.

## Esperas recibidas

| Categoria | Milisegundos acumulados |
|---|---:|
| Buffer IO | **837,576** |
| Parallelism | 109,011 |
| Idle | 2,041 |
| Memory | 619 |
| CPU | 138 |
| Latch | 41 |
| Unknown | 18 |

Buffer IO representa **88.22 % de la suma de las esperas reportadas**, no
88.22 % del tiempo de reloj. La suma de esperas es 949,444 ms y puede superar
los 107,029.831 ms de duracion al acumular esperas concurrentes de trabajadores.
Query Store agrupa por intervalos; no son cronometros independientes que puedan
sumarse al tiempo del UPDATE. La ventana consultada va del 28 al 31 de octubre UTC.

La categoria Buffer IO corresponde a PAGEIOLATCH_%, esperas por lectura de
paginas. [Microsoft: categorias de Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql).
Las lecturas fisicas de la ultima ejecucion se obtuvieron de last_physical_reads.
[Microsoft: sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql).

No aparece la categoria Lock en las filas recibidas. Esto respalda priorizar
lecturas en esta ejecucion, sin afirmar que nunca existan bloqueos en el sistema.
Tampoco demuestra que el almacenamiento sea lento: hace falta separar volumen
de lecturas, acceso elegido, estado de cache y latencia del almacenamiento.
Las esperas Parallelism pueden acompanar a trabajadores esperando datos;
este reporte no justifica cambiar MAXDOP.

## Organizacion y estadisticas

Las tres tablas son **HEAP**, confirmado por sys.indexes:

| Tabla | Filas aproximadas |
|---|---:|
| T3.CFDI_COBRANZA | 56,115,146 |
| T3.REGISTRO_FISCAL | 154,792,173 |
| EAI_OWNER.TMP_ACCOUNT_HEADER | 1,096,194 |

Heap describe la organizacion base; estas tablas tienen indices nonclustered
segun el resultado 01. Esta evidencia no identifica todavia un Table Scan,
un RID Lookup ni la tabla que origina las lecturas. No justifica crear indices
clustered en todas las tablas.

La estadistica automatica de ASIGNACION_ID `_WA_Sys_00000002_0D7A0286` tiene
fecha 28/07 y contador 112,040,853. Es una observacion a revisar con el plan,
pero el indice CFDI_COBRANZA_IDX sobre la misma columna tiene estadisticas
del 21/10 y 11,440 modificaciones. No demuestra que el plan lento dependiera
de la estadistica antigua. FECHA_PROCESO, ASIGNACION_CENTRAL y REGFIS_PK
tambien tienen estadisticas del 21/10. No se propone FULLSCAN masivo.

## Lo que falta: el contenido del plan

Todos los campos XML del archivo estan incompletos. Los dos planes se cortan
durante StatementText, antes de sus operadores. Las definiciones instaladas y
las sentencias tambien estan truncadas. El limite de presentacion de texto
aproximadamente 256 caracteres siguio aplicandose aun al devolver XML.
El parser local confirma que ninguno de los siete campos XML es valido/completo.

Por eso no es posible decidir aun entre estas hipotesis:

- Acceso a cobranzas recientes sin asignacion: evaluar un indice enfocado en
  FECHA_PROCESO / ASIGNACION_CENTRAL IS NULL si el plan muestra lecturas evitables.
- Cruce de compensacion: ya existe TMP_ACCOUNT_HEADER_IX_ACCNT sobre
  CLEARINGDOCNUMBER/FISCALYEAR. Evaluar incluir Assignment si hay lookups costosos.
- Cruce fiscal: ya existe REGFIS_PK unico sobre Factura. Evaluar cobertura de
  Entrega/Referencia si el plan muestra que ese acceso domina el trabajo.

Son alternativas condicionadas al plan, no DDL aprobados. En particular, este
UPDATE no filtra Fecha_Envio: un indice o reescritura enfocados solo en cobranza
pendiente de envio no representan todo su alcance. Antes de cambiar el acceso,
revisar tambien coincidencias multiples de compensacion para no ocultar una
asignacion no determinista mediante un nuevo orden de lectura.

## Siguiente paso

Ejecutar **05_LEER_PLAN_UPDATE.sql** completo, con sus valores por defecto.
Lee exclusivamente el plan 8889 de Query Store y verifica que corresponda al
query_id 32735 y al UPDATE del procedimiento esperado. Muestra operadores,
indices, filas/costos estimados, relaciones entre operadores, parametros
compilados, sugerencias del optimizador y predicados.

Los textos largos y el plan completo se dividen en fragmentos de 180 caracteres,
con identificador y orden. Guardar todos los resultados de SSMS en un TXT,
incluyendo 05_TEXTOS_FRAGMENTADOS. No requiere cambiar opciones de SSMS.
Si el plan ya no esta disponible lo informa y termina sin ejecutar el SP.

Es un plan compilado historico: permite revisar accesos y estimaciones, pero no
incluye contadores reales de cada operador. No se modificaron SP, indices,
estadisticas, datos ni configuracion de T3QA durante este analisis.
