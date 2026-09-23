# EAI_OWNER.SF_PROC_CENTRAL_PAYMENT_ZV_OPTIMIZADO

## Objetivo

Esta versión procesa pagos centrales ZV desde `EAI_OWNER.tmp_Account_Header` y genera las filas correspondientes en `T3.Pago` y `T3.Asignacion_Pago`. El procedimiento original permanece sin cambios para permitir pruebas comparativas y una adopción controlada.

Archivo de despliegue: `SF_PROC_CENTRAL_PAYMENT_ZV_OPTIMIZADO.SQL`.

## Flujo funcional conservado

1. Recibe la referencia completa en `@pIDocNum` y obtiene el IDoc mediante `SUBSTRING(@pIDocNum, 7, 10)`.
2. Rechaza referencias mayores a 30 caracteres para evitar truncamiento silencioso respecto de Oracle.
3. Consulta `EAI_OWNER.SF_PAYMENT_ALLOC` para impedir que una transacción ya asignada se procese otra vez.
4. Selecciona únicamente movimientos con método suplementario informado, distinto de `Z9` e importe positivo.
5. Construye `Pago_ID` con los dos dígitos del año de compensación y el número de documento de compensación.
6. Obtiene factura, cliente, importe y saldo mediante `EAI_OWNER.SF_GET_INVOICE_DATA`.
7. Si el pago supera el saldo por menos de `0.05`, ajusta el pago al saldo pendiente.
8. Obtiene los datos operativos del cliente mediante `EAI_OWNER.SF_GET_CUSTOMER_DATA`.
9. Si el centro es válido, inserta el pago y su asignación dentro de la misma transacción.
10. Registra uno de los estados: `Processed`, `Customer Invalid`, `Amount > Pending`, `Discarded`, `Not Receivable` o `Tx-Duplicated`.
11. Ante una excepción revierte la transacción y escribe el detalle en `EAI_OWNER.MX_EAI_MESSAGE_LOG`, sin relanzar el error, igual que la versión SQL Server original.

## Cambios de rendimiento

### 1. Cursor con menor volumen de datos

El cursor dejó de transportar `CustomerNumber` e `IDocNumber`, ya que el procedimiento original los asignaba a variables que nunca eran utilizadas. Se conserva `EAI_OWNER.GETCONV` para traducir el método de pago.

Beneficio: reduce el ancho de cada fila y las asignaciones realizadas durante cada `FETCH`. En las pruebas aisladas de una sola fila, conservar `GETCONV` resultó más eficiente que sustituirla por una subconsulta correlacionada.

### 2. Eliminación de un JOIN sin resultado funcional

Se eliminó el `LEFT JOIN EAI_OWNER.Client`. Ni el SQL Server original ni el flujo Oracle usan una columna de ese JOIN para construir el pago. En Oracle existía una segunda conversión llamada `Def_Payment_Method`, pero su resultado nunca se asignaba ni se utilizaba.

Beneficio: evita lecturas de `Client`, reduce el tamaño del plan y elimina el riesgo de multiplicar pagos si hubiera más de una fila de cliente con el mismo `Cliente_SAP`.

### 3. Una actualización de estado por IDoc

El procedimiento original actualiza todas las filas de `tmp_Account_Header` después de cada elemento recorrido. Como cada actualización usa el mismo `IDocNumber`, solamente queda visible el estado de la última iteración cuando la transacción confirma.

La versión optimizada conserva ese estado final en `@sFinalStatus` y realiza un único `UPDATE` al terminar el recorrido.

Beneficio: reduce escrituras, log de transacciones y bloqueos sobre `tmp_Account_Header`, especialmente cuando un IDoc contiene más de un movimiento candidato.

### 4. Cursor mínimo y apropiado para las dependencias existentes

El cursor se conserva como `LOCAL FAST_FORWARD`. No es seguro eliminarlo sin copiar la lógica de `SF_GET_INVOICE_DATA` y `SF_GET_CUSTOMER_DATA`, pues ambos procedimientos devuelven datos mediante parámetros `OUTPUT` para cada referencia.

Beneficio: mantiene una sola fuente de verdad para las reglas de factura y cliente, con el tipo de cursor de menor costo para lectura secuencial.

### 5. Menos trabajo repetido y mejor seguridad transaccional

- Se usa una sola marca de tiempo para `Pago` y `Asignacion_Pago` de la misma operación.
- `SET XACT_ABORT ON` refuerza el rollback ante errores de ejecución.
- `SET NOCOUNT ON` evita mensajes de conteo que no consume el caller.

## Comparación con Oracle

Se revisó `ORA/T3/EAI_OWNER/Procedures/SF_PROC_CENTRAL_PAYMENT_ZV.SQL`. Se conservan las reglas de selección, validación de duplicados, tolerancia de `0.05`, validación del cliente, inserciones, estados y registro de errores.

Diferencias intencionales:

- El JOIN a `EAI_OWNER.Client` fue retirado porque únicamente alimentaba `Def_Payment_Method`, valor que Oracle calcula pero nunca utiliza. El método efectivo continúa siendo la conversión de `Doc.PayMethSupplement`.
- SQL Server conserva una transacción explícita y rollback completo para evitar un `Pago` sin su `Asignacion_Pago`.
- Las trazas detalladas internas de Oracle no se reproducen todas para no agregar escrituras al camino normal. Con `@pOutput > 0` se registran `Begin` y `End`.

## Resultados de validación técnica

La versión fue compilada y ejecutada en una base LocalDB temporal con objetos controlados. Se compararon ambas versiones en los escenarios de pago válido, ajuste menor a `0.05`, importe superior al saldo, cliente inválido, documento no cobrable, duplicado, método `Z9` y método de pago convertido. Las filas operativas, importes y estados coincidieron.

También se provocó un error durante la inserción de `T3.Asignacion_Pago`: la fila previa de `T3.Pago` fue revertida y el error quedó registrado en `MX_EAI_MESSAGE_LOG`.

Medición sintética observada:

| Carga | Original | Optimizado | Lectura del resultado |
|---|---:|---:|---|
| 300 ejecuciones con una fila | 394 ms | 399 ms | Empate técnico; no se afirma mejora para una fila. |
| 30 ejecuciones con 50 filas por IDoc | 564 ms | 275 ms | 51.2 % menos tiempo por consolidar los `UPDATE`. |

Estos tiempos no representan producción: las dependencias fueron simuladas y el hardware, la caché, el volumen y los bloqueos cambian el resultado. La conclusión válida de la prueba es que no se observó una ventaja medible con una sola fila y sí una reducción clara cuando un IDoc contiene muchas filas. La aceptación final debe medirse en QA con datos y planes reales.

## Dependencias

- Funciones: `EAI_OWNER.SF_PAYMENT_ALLOC` y `EAI_OWNER.GETCONV`.
- Procedimientos: `EAI_OWNER.SF_GET_INVOICE_DATA` y `EAI_OWNER.SF_GET_CUSTOMER_DATA`.
- Tablas: `EAI_OWNER.tmp_Account_Header`, `EAI_OWNER.MX_HashTable`, `EAI_OWNER.Trace_EAI_Owner`, `EAI_OWNER.MX_EAI_MESSAGE_LOG`, `T3.Pago` y `T3.Asignacion_Pago`.
- Índices recomendados ya presentes en el proyecto: `TMP_ACCOUNT_HEADER_IXIDOC` y `MX_HASHTABLE_IX`.

## Callers actuales

La búsqueda estática del repositorio muestra que la versión original es llamada desde:

- `EAI_OWNER.SF_PROC_CENTRAL_EXECUTE`
- `EAI_OWNER.SF_PROC_CENTRAL_EXECUTE_NEW`

La versión optimizada usa un nombre distinto y no reemplaza automáticamente esos callers. Para una prueba controlada, el DBA puede invocarla directamente con los mismos parámetros. El cambio de callers debe hacerse solamente después de validar resultados y tiempos con datos representativos.

## Validación recomendada antes de producción

Comparar ambas versiones dentro de una base de QA restaurable usando, como mínimo, estos escenarios:

1. Pago válido y exacto al saldo.
2. Pago superior al saldo por menos de `0.05`.
3. Pago superior al saldo por `0.05` o más.
4. Cliente sin centro válido.
5. Documento no cobrable.
6. IDoc ya asignado.
7. IDoc sin filas candidatas.
8. IDoc con más de una fila candidata.
9. Método de pago con conversión y sin conversión en `MX_HashTable`.
10. Error forzado entre las dos inserciones para comprobar rollback.

Para cada caso deben compararse filas en `T3.Pago`, `T3.Asignacion_Pago`, estado en `tmp_Account_Header` y mensajes de error. Para rendimiento se recomienda ejecutar varias veces, alternar el orden original/optimizado y comparar duración, CPU y lecturas lógicas; una sola ejecución puede estar afectada por caché o bloqueos.
