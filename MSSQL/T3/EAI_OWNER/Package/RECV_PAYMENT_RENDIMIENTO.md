# Revisión de RECV_PAYMENT — 2026-10-21

Análisis del código del repositorio. Las oportunidades no equivalen a cuellos de
botella medidos en T3QA. No se modificaron procedimientos ni índices.

## Flujo comprobado

`RECV_PAYMENT` consulta el último proceso 408 y llama a `GETCONV`, `LOG_START`,
`FN_CHECK_INSTANCE` por mensaje y `SF_PROC_CENTRAL_PAYMENT`.

El subproceso lee el XML, extrae campos, elimina temporales por `IDocNumber`,
inserta `TMP_ACCOUNT_HEADER` y marca el mensaje. Una rama alternativa llama a
`SF_PROC_PREINVOICE_IFC`, que puede delegar a `DEBITNOTE_TO_IFC`,
`INVOICE_TO_PREVENTA` o `INVOICE_TO_FACTURA`.

El camino normal no llama directamente a `SF_PROC_CENTRAL_PAYMENT_ZV`, `CM`
ni `WA_ASIGNACION_PAGO`. En el repositorio, `SF_PROC_CENTRAL_EXECUTE` llama a
ZV y `T3.PROC_T3_EOD` llama a CENTRAL_EXECUTE. Los triggers y las definiciones
desplegadas deben verificarse antes de atribuir ese procesamiento a la recepción.

## Prioridades

| Prioridad | Hallazgo | Propuesta y condición |
|---|---|---|
| 1 | Cada iteración del coordinador ejecuta `COUNT_BIG(*) FROM @Records`. El lote no cambia. | Calcular una sola vez `@TotalRecords` después del INSERT y usarlo en WHILE. Conserva lote y orden; medir beneficio según tamaño. |
| 1 | Dos DELETE por mensaje buscan `IDocNumber`. | Verificar índice con IDocNumber como primera clave en ambas tablas. El repositorio contiene `TMP_ACCOUNT_HEADER_IXIDOC`; no se encontró equivalente de DETAIL en los índices consolidados. Su ausencia en T3QA aún no está confirmada. |
| 1 | Selección de pendientes por cola, PROCESSED NULL y fecha; orden DOCNUM, CREATED, ROW_ID. Lecturas y actualizaciones por ROW_ID. | Revisar índices y planes reales. Comparar filtro por fecha frente a soporte del orden antes de definir un índice filtrado para pendientes. No incluir XML de forma automática. |
| 2 | Numerosas extracciones XML repiten la ruta ZTMDALLOCPAY. | Probar una extracción relativa a un nodo común. Conservar primer nodo, rutas opcionales, XML vacío y rama Invoice. Cambiar a nodes() sin cuidado puede multiplicar filas o perder documentos sin ese nodo. |
| 2 | `FN_CHECK_INSTANCE` consulta MX_HASHTABLE por cada mensaje y aplica TRIM al Target. | Medir costo y número de instancias distintas. Una caché por instancia puede ahorrar consultas, pero fija la configuración durante el lote: requiere aceptar esa semántica. La función ya usa EXISTS, no cursor. |
| 2 | Consulta inicial MAX(PID) y cierre por PID en RF_PROCESOS_LOG. | Revisar soporte de (PROCESO, PID) y búsquedas por PID. Es costo por lote, no por documento; priorizar según medición. |
| 3 | La rama de preinvoice comparte las dependencias optimizadas para facturas. | Confirmar la versión desplegada y frecuencia de esa rama. No reemplazarla con una copia antigua del repositorio que pierda los ajustes ya aplicados en T3QA. |

Los tipos locales de IDocNumber son VARCHAR(10), tanto variable como columnas
del DDL. No hay evidencia en este código del problema NVARCHAR/VARCHAR que
encarecía los DELETE de facturas y replenishment. Se deben verificar tipos reales.
`GETCONV` se llama una vez en el coordinador y ya consulta por Type/Source:
no es el primer candidato. Las trazas detalladas del parser están condicionadas
a nOutput > 0 y el coordinador pasa 0.

## Transacciones y control de errores

`SF_PROC_CENTRAL_PAYMENT` abre una transacción y, ante error, hace ROLLBACK
completo si hay transacción activa. Si se invoca dentro de una transacción del
llamador, puede revertirla y provocar el desbalance ya observado en otro flujo.
Requiere el patrón de propiedad de transacción/savepoint y tratamiento del estado
no confirmable; no basta con agregar COMMIT o activar XACT_ABORT.

La lectura de estado y LOG_START son operaciones separadas: no garantizan
exclusión entre dos ejecuciones simultáneas. El CATCH del coordinador registra
el error pero no cierra el proceso ni libera el estado. El parser también puede
registrar errores sin propagarlos. Por eso, PROCESO_4 cuenta mensajes recorridos,
no demuestra pagos exitosos. Estas son mejoras de integridad y observabilidad,
no aceleraciones demostradas.

No se recomienda agrupar todos los pagos en una transacción para ahorrar commits
sin medir esperas de log y aceptar el cambio de recuperación por documento.

## Aplicación contable posterior

Se revisó también el contexto de ZV: su código normal ya contiene cursor reducido,
eliminación del JOIN a Client y un UPDATE final por IDoc. No son mejoras nuevas.
Sus consultas de duplicados en SF_PAYMENT_ALLOC y las búsquedas de
SF_GET_INVOICE_DATA podrían requerir índices, pero pertenecen a la aplicación
contable salvo evidencia de ejecución síncrona.

SF_GET_INVOICE_DATA busca factura/entrega/referencia, suma detalle y cobranza.
El OR de las tres referencias, el UNION y los TOP sin ORDER BY no deben
reescribirse sin definir cuál coincidencia prevalece. Los saldos tampoco deben
almacenarse en caché entre pagos que los modifican.

## Siguiente paso

1. En AZCRNMXNEVTD06, seleccionar T3QA.
2. Ejecutar `RECV_PAYMENT_PERF/01_DIAGNOSTICO.sql`, preferentemente después de
   una ejecución normal reciente de Payment.
3. Compartir todos los resultados, duración del lote y cantidad de mensajes
   realmente exitosos.

El script consulta metadatos y caché; no ejecuta pagos, crea índices ni altera
procedimientos. No genera planes XML masivos. Si la caché está vacía o no hay
permisos, lo informa; eso no significa que el costo sea cero.
Con esos resultados se seleccionará la primera modificación y su respaldo,
reversión y prueba. El primer cambio de código candidato es el conteo único;
el candidato de índices más concreto era IDocNumber en TMP_ACCOUNT_DETAIL,
antes de recibir las mediciones siguientes.

## Resultado recibido de T3QA — captura 2026-10-21 13:15

Se revisó el archivo adjunto `75adfbfc-39a9-4a11-9642-09a7a91d0aac/Pasted text.txt`.
La evidencia cambia la prioridad: **no crear por ahora el índice de DETAIL**.

| Operación | Ejecuciones | Media ms | Lecturas por ejecución |
|---|---:|---:|---:|
| INSERT TMP_ACCOUNT_HEADER | 17,087 | 4.6428 | 27.33 |
| Extracción XML del parser (SELECT) | 17,088 | 0.4666 | 0 |
| UPDATE MX_RECEIVE_MESSAGE_LOG | 17,087 | 0.2482 | 17.16 |
| Conteo del WHILE | 17,101 | 0.1888 | 17.55 |
| DELETE TMP_ACCOUNT_HEADER | 17,088 | 0.0362 | 3.00 |
| DELETE TMP_ACCOUNT_DETAIL | 17,088 | 0.0069 | 0 |

HEADER tiene 1,090,377 filas y un índice activo por IDOCNUMBER. Su DELETE ya es
barato. DETAIL no tiene índice, pero tiene cero filas en la captura y su DELETE
no registra lecturas. Ambas columnas son VARCHAR(10). No se justifica repetir
el parche de conversiones de facturas o replenishment.

El INSERT de HEADER es el mayor costo entre las sentencias del parser mostradas:
79.33 segundos acumulados, frente a 2.37 segundos aproximadamente de CPU
(0.1387 ms por ejecución). La diferencia apunta a investigar esperas; no prueba
por sí sola bloqueo ni latencia del log. Hay ocho índices no agrupados en HEADER,
lo que añade mantenimiento, pero no demuestra que alguno sobre. No eliminarlos
sin revisar otros consumidores, uso y planes.

El conteo del WHILE acumula 3.23 segundos en esta caché. Calcularlo una sola vez
sigue siendo una mejora concreta y acotada, pero estos datos no justifican prometer
una aceleración grande solo con ese cambio.

La selección del lote promedia 193.98 ms en ocho ejecuciones y 16,614.5 lecturas.
El control inicial promedia 113.80 ms y 20,707.77 lecturas; el cierre por PID,
34.01 ms y 10,351.38 lecturas (13 ejecuciones). Son costos por lote. Priorizar
según tamaño y frecuencia, sin confundirlos con costos por pago.

FN_CHECK_INSTANCE registra una entrada principal de 45,083 ejecuciones, 0.0322 ms
y dos lecturas por llamada. Es compartida con otros flujos: no atribuir ese total
solo a Payment. Tampoco atribuir las métricas de preinvoice a esta recepción:
la caché no identifica el llamador.

Se reporta un trigger habilitado Z_MX_RECV_MESSAGE en la cola, pero no un trigger
en TMP_ACCOUNT_HEADER. La presencia del trigger de la cola no demuestra que
se ejecute para UPDATE: falta revisar eventos y definición.

Siguiente decisión: obtener duración y cantidad exitosa de un lote reciente,
y medir esperas durante ese lote si persiste lentitud. El reporte no contiene
duración total del procedimiento ni detalle de COMMIT; no permite calcular
documentos/segundo sumando estas medias. Antes de parchear el coordinador se
necesita guardar y verificar su definición desplegada, modificada el 2026-10-06,
para no sustituirla por una versión local distinta.
