# Notas de optimización de `SF_PROC_CENTRAL_INCOBRABLE`

## 1. Objetivo

El archivo `SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO.SQL` crea una versión
paralela:

```text
EAI_OWNER.SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO
```

El procedimiento original no fue modificado y el job 889 continúa llamándolo.
Esto permite comparar resultados y rendimiento antes de cambiar producción.

### 1.1 Dependencias y orden de despliegue

Antes de ejecutar el archivo, el DBA debe confirmar que está conectado a la
instancia correcta y que `USE [T3QA]` corresponde al ambiente destino. Para otro
ambiente se debe cambiar únicamente ese nombre de base de datos.

El script depende de estos objetos existentes:

| Tipo | Objeto |
|---|---|
| Secuencia | `EAI_OWNER.ProcessID` |
| Procedimientos | `EAI_OWNER.LOG_START`, `EAI_OWNER.SF_GET_INVOICE_DATA`, `EAI_OWNER.SF_GET_CREDIT_DATA` |
| Tablas EAI_OWNER | `TMP_ACCOUNT_HEADER`, `TMP_INCO_HEADER`, `TRACE_EAI_OWNER`, `MX_COMPONENTS`, `MX_EAI_MESSAGE_LOG` |
| Tablas T3 | `MOV_CLIENTE`, `PAGO`, `ASIGNACION_PAGO`, `RF_PROCESOS_LOG` |

El propio archivo ejecuta un preflight antes de crear índices. Si falta alguno
de estos objetos, usa errores `51701` a `51715` para detener el despliegue con
el nombre exacto de la dependencia ausente.

El ejecutor del despliegue necesita permiso para crear o modificar el
procedimiento y para crear índices en las tablas indicadas. El contexto que
ejecute el procedimiento necesita permisos sobre sus dependencias, salvo que el
DBA ya los haya resuelto mediante propiedad de esquemas o firma de módulos.
El archivo fija `ANSI_NULLS ON` y `QUOTED_IDENTIFIER ON` antes de crear el
procedimiento para que su comportamiento no dependa de la sesión del DBA.

Orden recomendado:

1. Revisar índices equivalentes y espacio disponible.
2. Ejecutar completo `SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO.SQL` en QA.
3. Confirmar que el procedimiento y los cuatro índices existen.
4. Ejecutar las pruebas de simulación con `@nInsert = 0`.
5. Ejecutar una prueba funcional controlada con `@nInsert = 1`.
6. Comparar resultados y planes antes de modificar el job 889.

## 2. Problemas encontrados en la versión original

La versión original presenta estos puntos de costo:

- Un cursor exterior agrupa documentos de compensación.
- Por cada grupo abre un segundo cursor para sus IDocs.
- `TMP_ACCOUNT_HEADER` se consulta varias veces para el mismo lote.
- Por cada IDoc se ejecuta `SF_GET_INVOICE_DATA` y, si no encuentra factura,
  `SF_GET_CREDIT_DATA`.
- La transacción permanece abierta mientras se recorren ambos cursores y se
  escriben registros de trazabilidad.
- El job 889 llama al procedimiento con `@pOutput = 11`, habilitando detalle de
  trazabilidad por IDoc.
- `TMP_INCO_HEADER` y `T3.MOV_CLIENTE` no tenían en el repositorio índices
  alineados con las búsquedas de este proceso.
- `GETDATE()` se evaluaba muchas veces durante el lote, por lo que diferentes
  consultas podían usar instantes ligeramente distintos.
- `FORMAT` se utilizaba para construir referencias de log.

## 3. Cambios implementados

### 3.1 Procedimiento paralelo

Se creó un objeto con nombre diferente. No se utilizó `ALTER` sobre el original.
El procedimiento conserva los cuatro parámetros:

```sql
@nDays              INT         = 28,
@sClearingDocument  VARCHAR(30) = 'EMPTY',
@nInsert            INT         = 0,
@pOutput            INT         = 0
```

### 3.2 Índices idempotentes

El script crea, si no existen:

| Índice | Tabla | Uso |
|---|---|---|
| `IX_TMP_ACCOUNT_HEADER_INCO_PROCESS` | `EAI_OWNER.TMP_ACCOUNT_HEADER` | Selección del lote y lectura de IDocs. |
| `IX_TMP_ACCOUNT_HEADER_INCO_DUPLICATE` | `EAI_OWNER.TMP_ACCOUNT_HEADER` | Partición por documento/referencia para duplicados. |
| `IX_TMP_INCO_HEADER_DOCUMENT_DATE` | `EAI_OWNER.TMP_INCO_HEADER` | Detección y actualización de grupos existentes. |
| `IX_MOV_CLIENTE_CLIENTE_SAP_INCO` | `T3.MOV_CLIENTE` | Join y búsqueda por `Cliente_SAP`. |

Los índices no deben instalarse a ciegas en producción. El DBA debe revisar:

- Espacio disponible.
- Índices equivalentes existentes en la instancia.
- Duración y bloqueo de la construcción.
- Impacto adicional sobre las escrituras de las cuatro tablas.
- Planes reales antes y después del cambio.

### 3.3 Ventana temporal única

Al iniciar se calculan una sola vez:

```text
@Now
@FromDate
@Cutoff
```

Tanto la selección de grupos como la de IDocs usa esa misma ventana. Esto evita
que entren filas nuevas a mitad del lote y elimina evaluaciones repetidas de
`GETDATE()`.

### 3.4 Materialización de grupos

Los documentos candidatos se cargan una sola vez en `#Groups`, fuera de la
transacción. La consulta utiliza `OPTION (RECOMPILE)` para adaptar el plan al
número de días y al filtro opcional de documento.

`#Groups` contiene:

- Documento de compensación.
- Fecha de compensación.
- Cantidad de IDocs.
- Indicador de grupo nuevo que realmente debe procesarse.

### 3.5 Eliminación del cursor exterior

La versión original abría `curData` y ejecutaba consultas adicionales por cada
documento. La versión optimizada realiza de forma set-based:

- Actualización de `Last_Updated` para grupos existentes.
- Identificación de grupos nuevos.
- Inserción de encabezados en `TMP_INCO_HEADER`.
- Marcado de duplicados.
- Actualización final de `Processed`.

Por tanto, `curData` fue eliminado completamente.

### 3.6 Duplicados con funciones de ventana

Se sustituyó el CTE ejecutado por cada grupo por una operación para todo el
lote usando:

```sql
COUNT(IdocNumber) OVER (...)
ROW_NUMBER() OVER (... ORDER BY IdocNumber DESC)
```

Se sigue marcando solamente el `IdocNumber` mayor de cada referencia repetida.

### 3.7 Tabla de trabajo para IDocs

Los IDocs elegibles se materializan en `#WorkItems` mediante un solo join entre:

```text
TMP_ACCOUNT_HEADER
#Groups
MOV_CLIENTE
```

Se conserva el `INNER JOIN` con `MOV_CLIENTE`: clientes sin correspondencia no
se procesan, igual que en la regla heredada de Oracle.

### 3.8 Un solo cursor residual

Se mantiene `curWorkItems` como `LOCAL FAST_FORWARD`. No se eliminó todavía
porque cada fila realiza una decisión secuencial:

1. Buscar como factura mediante `SF_GET_INVOICE_DATA`.
2. Si no existe, buscar como nota de crédito mediante `SF_GET_CREDIT_DATA`.
3. Comparar saldo pendiente.
4. Insertar Pago/Asignación o actualizar el estado.

Eliminar este cursor correctamente requiere versiones batch de los dos
procedimientos `SF_GET_*`. Cambiarlo sin esa preparación podría modificar el
cálculo de saldos o el orden de aplicación.

### 3.9 Trazabilidad agrupada

Los mensajes generados directamente por la versión optimizada se almacenan en
`#Trace` y se insertan en `Trace_EAI_OWNER` con un solo `INSERT ... SELECT`.

Esto reduce escrituras individuales sobre la tabla permanente. Las trazas que
generan internamente `SF_GET_INVOICE_DATA` y `SF_GET_CREDIT_DATA` permanecen sin
cambio.

Para producción se recomienda ejecutar normalmente con:

```sql
@pOutput = 0
```

Utilizar valores mayores que uno solamente para diagnóstico controlado.

### 3.10 Filtro `@sClearingDocument`

La versión original conservaba el parámetro, pero no lo utilizaba. La versión
optimizada permite una ejecución dirigida cuando contiene un documento real.

Los valores `NULL`, vacío y `EMPTY` significan procesar todos los documentos del
periodo. Cualquier otro valor filtra exactamente por `ClearingDocNumber`.

### 3.11 Transacción

La lectura y agrupación inicial ocurre antes de abrir la transacción. Las
escrituras funcionales continúan en una única transacción para conservar la
atomicidad del lote.

Se utiliza `UPDLOCK, HOLDLOCK` al decidir qué grupos son nuevos. El objetivo es
reducir el riesgo de que dos ejecuciones inserten el mismo encabezado.

No se implementó todavía una transacción por `ClearingDocNumber`, porque eso
cambiaría la atomicidad: grupos anteriores podrían quedar confirmados aunque un
grupo posterior fallara.

### 3.12 Tipo de dato del identificador de proceso

`@nPID` se declaró como `BIGINT`, igual que la secuencia
`EAI_OWNER.ProcessID`. La versión original lo recibía en un `INT`, que fallaría
cuando la secuencia superara `2,147,483,647`. El valor continúa insertándose en
`T3.RF_PROCESOS_LOG.PID`, cuya capacidad es `DECIMAL(10,0)`.

### 3.13 Identificador corto en el log de errores

`EAI_OWNER.MX_EAI_MESSAGE_LOG.QUEUE_NAME` sólo permite 30 caracteres. Por eso,
el bloque `CATCH` registra `SF_PROC_CENTRAL_INCO_OPT`; usar el nombre completo
del procedimiento optimizado provocaría truncamiento y podría ocultar el error
original. `TRACE_EAI_OWNER.OBJECT_TYPE` sí permite 50 caracteres y conserva el
nombre completo.

### 3.14 Longitud de la referencia de documento

Las variables y `#WorkItems.ReferenceDocNumber` usan `VARCHAR(40)`, igual que
`TMP_ACCOUNT_HEADER.REFERENCEDOCNUMBER`. Esto evita truncar silenciosamente una
referencia antes de enviarla a los procedimientos `SF_GET_*`. Dichos
procedimientos conservan su validación propia para referencias mayores de 30
caracteres y retornan sus salidas de error en cero.

### 3.15 Validación explícita del encabezado

Antes de insertar un grupo nuevo se validan restricciones que en el original
fallaban con mensajes genéricos:

- Error `51716`: `ClearingDocNumber` supera los 10 caracteres admitidos por
  `TMP_INCO_HEADER`.
- Error `51717`: el conteo supera los 999,999 registros admitidos por
  `TMP_INCO_HEADER.RECORDS NUMERIC(6,0)`.
- Error `51718`: `ClearingDate` no es una fecha válida en formato `YYYYMMDD`.

Estas validaciones están dentro de la transacción y pasan por el bloque
`CATCH`; el lote se revierte y el error vuelve al llamador mediante `THROW`.

## 4. Diferencias funcionales que deben validarse

Aunque se buscó conservar la lógica, existen cambios intencionales:

1. `@sClearingDocument` ahora sí funciona como filtro.
2. La misma fecha de corte se aplica a grupos e IDocs.
3. Los duplicados se particionan por documento, fecha y referencia. Esto evita
   mezclar el mismo número de compensación entre fechas diferentes.
4. El cursor residual tiene orden explícito por fecha, documento e IDoc. El
   cursor interior original no tenía `ORDER BY`.
5. La trazabilidad del nuevo objeto usa el nombre
   `SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO`.
6. Al finalizar se devuelve un result set con contadores del lote.
7. `@nDays` nulo o negativo genera el error `51700` en vez de ejecutar con una
   ventana inválida.
8. Las referencias de hasta 40 caracteres ya no se truncan antes de llamar a
   los procedimientos `SF_GET_*`; éstos aplican su validación de 30 caracteres.
9. Una fecha, longitud de documento o conteo incompatible con
   `TMP_INCO_HEADER` genera uno de los errores explícitos `51716` a `51718`.
10. El identificador de proceso usa `BIGINT` para ser compatible con toda la
    capacidad de `EAI_OWNER.ProcessID`.

Estas diferencias deben compararse con los resultados esperados por negocio.

## 5. Cambios deliberadamente pendientes

No se implementaron en esta primera versión:

- Versiones batch de `SF_GET_INVOICE_DATA` y `SF_GET_CREDIT_DATA`.
- Eliminación completa del cursor residual.
- Confirmación por cada documento de compensación.
- `sp_getapplock` para impedir ejecuciones simultáneas.
- Cambio del comando del job 889.
- Eliminación o consolidación de índices antiguos potencialmente solapados.

Estos cambios requieren métricas reales y pruebas funcionales adicionales.

## 6. Plan de pruebas obligatorio

### 6.1 Ambiente

Probar únicamente en QA/restauración controlada con una copia representativa de
los datos. No comparar ambos procedimientos consecutivamente sobre las mismas
tablas sin restaurar el estado, porque ambos actualizan encabezados y estados
incluso en algunos caminos de simulación.

### 6.2 Casos funcionales

Incluir al menos:

- Factura con saldo suficiente.
- Factura con saldo insuficiente.
- Nota de crédito con saldo suficiente.
- Nota de crédito con saldo insuficiente.
- Referencia inexistente.
- Importe menor a 500,000.
- Importe igual o mayor a 500,000.
- Referencia duplicada.
- Cliente sin correspondencia en `MOV_CLIENTE`.
- Grupo ya existente en `TMP_INCO_HEADER`.
- Mismo `ClearingDocNumber` en fechas diferentes.
- Ejecución con `@nInsert = 0` y con `@nInsert = 1`.
- Ejecución general y ejecución filtrada por `@sClearingDocument`.
- `@nDays` nulo, negativo, cero y con el valor normal del job.
- Referencia de documento con más de 30 caracteres.
- Fecha de compensación inválida y límites de longitud/conteo del encabezado.

Comparar las tablas:

```text
EAI_OWNER.TMP_ACCOUNT_HEADER
EAI_OWNER.TMP_INCO_HEADER
T3.PAGO
T3.ASIGNACION_PAGO
T3.RF_PROCESOS_LOG
EAI_OWNER.TRACE_EAI_OWNER
```

### 6.3 Rendimiento

Capturar para original y optimizado:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
```

Además registrar:

- Duración total.
- CPU.
- Lecturas lógicas.
- Filas candidatas y procesadas.
- Esperas y bloqueos.
- Tamaño utilizado del transaction log.
- Plan de ejecución real.
- Volumen insertado en `Trace_EAI_OWNER`.

Probar primero con:

```sql
EXEC [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO]
    @nDays = 5,
    @sClearingDocument = NULL,
    @nInsert = 0,
    @pOutput = 0;
```

Después realizar una prueba controlada con inserciones reales.

## 7. Cambio futuro del job 889

El job no fue modificado. Sólo después de obtener equivalencia funcional y una
mejora medible se debe cambiar su step a:

```sql
EXEC [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO]
    @nDays = 5,
    @sClearingDocument = NULL,
    @nInsert = 1,
    @pOutput = 0;
```

Después del cambio deben ejecutarse nuevamente los scripts de validación de
jobs y conservar evidencia del plan anterior y posterior.

## 8. Rollback de esta optimización

El job continúa apuntando al original, por lo que el rollback inmediato es
simple mientras no se cambie ese step:

```sql
DROP PROCEDURE IF EXISTS
    [EAI_OWNER].[SF_PROC_CENTRAL_INCOBRABLE_OPTIMIZADO];
```

Si el DBA confirma que los índices no son usados por otros procesos, puede
retirarlos por separado:

```sql
DROP INDEX IF EXISTS [IX_TMP_ACCOUNT_HEADER_INCO_PROCESS]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER];

DROP INDEX IF EXISTS [IX_TMP_ACCOUNT_HEADER_INCO_DUPLICATE]
    ON [EAI_OWNER].[TMP_ACCOUNT_HEADER];

DROP INDEX IF EXISTS [IX_TMP_INCO_HEADER_DOCUMENT_DATE]
    ON [EAI_OWNER].[TMP_INCO_HEADER];

DROP INDEX IF EXISTS [IX_MOV_CLIENTE_CLIENTE_SAP_INCO]
    ON [T3].[MOV_CLIENTE];
```

No eliminar índices sin revisar `sys.dm_db_index_usage_stats`, planes y
dependencias de otros procedimientos.

## 9. Alcance de la verificación realizada

Se efectuó una revisión estática contra los DDL y procedimientos del
repositorio:

- El `CREATE OR ALTER PROCEDURE` es la primera instrucción de su lote.
- Los bloques `TRY/CATCH`, transacción, rollback y liberación del cursor están
  balanceados.
- Sólo permanece un cursor, declarado `LOCAL FAST_FORWARD`.
- Se verificaron nombres y columnas de las tablas utilizadas.
- Se contrastaron las firmas de `SF_GET_INVOICE_DATA` y
  `SF_GET_CREDIT_DATA`.
- Se validaron longitudes de los identificadores escritos en las tablas de log.
- El procedimiento original y el comando actual del job 889 permanecen sin
  cambios.

Esta revisión no sustituye compilar y ejecutar el archivo en una instancia SQL
Server con el esquema real. Antes de promoverlo, el DBA debe completar las
pruebas funcionales y de rendimiento de la sección 6 y conservar sus
resultados.
