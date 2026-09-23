# Optimización de `EAI_OWNER.SF_PROC_PREINVOICE_IFC`

## 1. Objetivo

Este documento describe los cambios realizados entre:

- procedimiento original: `EAI_OWNER.SF_PROC_PREINVOICE_IFC`;
- procedimiento optimizado: `EAI_OWNER.SF_PROC_PREINVOICE_IFC_OPTIMIZADO`;
- homólogo funcional: `ORA/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_IFC.SQL`.

El objetivo es mejorar el rendimiento y la capacidad de diagnóstico sin alterar los flujos de negocio de facturas, venta directa y notas de débito.

La versión optimizada se creó con un nombre independiente. Por lo tanto, puede desplegarse, probarse y revertirse sin sobrescribir el procedimiento original.

## 2. Archivos involucrados

| Archivo | Función |
|---|---|
| `MSSQL/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_IFC.SQL` | Procedimiento SQL Server original y línea base funcional. |
| `MSSQL/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_IFC_OPTIMIZADO.SQL` | Procedimiento optimizado y script de despliegue. |
| `ORA/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_IFC.SQL` | Referencia de las reglas de negocio provenientes de Oracle. |
| `MSSQL/T3/EAI_OWNER/Procedures/SF_PROC_PREINVOICE_IFC.MD` | Documentación técnica y funcional. |

## 3. Resumen de cambios y ventajas

| Cambio | Procedimiento original | Versión optimizada | Ventaja |
|---|---|---|---|
| Despliegue | Crea o actualiza directamente el procedimiento original. | Crea `SF_PROC_PREINVOICE_IFC_OPTIMIZADO`. | Permite pruebas A/B y reversa segura. |
| Validación de dependencias | Los objetos faltantes se detectan durante la compilación o ejecución. | Valida previamente esquemas, tablas, funciones y procedimientos. | El DBA recibe un error específico antes del despliegue incompleto. |
| Índices | Depende de los índices existentes. | Reutiliza índices equivalentes o crea índices idempotentes. | Reduce búsquedas y eliminaciones por `ROW_ID`, `REFERENCEID` y material. |
| Importes opcionales | Reinicia variables numéricas con texto vacío. | Reinicia importes opcionales con `NULL`. | Evita `SQL-8114` y reproduce la semántica de Oracle. |
| Comparaciones con `NULL` | Usa `COALESCE` en algunas reglas. | Conserva el comportamiento de comparación nula de Oracle. | Evita clasificaciones o conversiones que Oracle no ejecutaría. |
| Registro de errores | Registra número y mensaje general. | Registra número, línea, procedimiento y mensaje. | Reduce el tiempo de diagnóstico. |
| Procesamiento XML | Lee directamente el XML recibido. | Conserva la lectura directa por ser eficiente para este documento. | Evita materialización y escrituras adicionales en `tempdb`. |
| Trazas | Mantiene el identificador funcional original. | Conserva `Object_Type = 'SF_PROC_PREINVOICE_IFC'`. | No rompe consultas o monitoreo existentes. |

## 4. Optimización de accesos

El script revisa los índices existentes antes de crear uno nuevo. No depende exclusivamente del nombre del índice: también verifica la primera columna clave, para reutilizar un índice equivalente.

### 4.1 Mensaje recibido por `ROW_ID`

El procedimiento busca el XML y posteriormente actualiza el mismo registro de `EAI_OWNER.MX_RECEIVE_MESSAGE_LOG`.

Si no existe un índice habilitado cuya primera clave sea `ROW_ID`, se crea:

```sql
IX_MX_RECEIVE_MESSAGE_LOG_ROW_ID
```

Incluye `REFERENCE`, `PROCESSED` y `STATUS`, columnas utilizadas durante el procesamiento.

Ventaja: disminuye el costo de localizar y actualizar el mensaje recibido.

### 4.2 Limpieza de condiciones por referencia

Antes de reconstruir el documento, el procedimiento elimina las condiciones anteriores de la misma referencia.

Si no existe un índice que comience por `REFERENCEID`, se crea:

```sql
IX_TMP_DOCUMENT_CONDITIONS_REFERENCEID
```

Ventaja: reduce el recorrido de `TMP_DOCUMENT_CONDITIONS` durante la limpieza.

### 4.3 Búsqueda de material y conversión UOM

Si no existe un índice que comience por `MATERIAL`, se crea:

```sql
IX_MATERIAL_MATERIAL_UOM
```

El índice incluye `UM`, `CIG_X_CLL`, `CIG_X_PAQ` y `CIG_X_CT`.

Ventaja: acelera la búsqueda de material y puede evitar lecturas adicionales para calcular las conversiones de unidad de medida.

La creación de índices requiere permisos DDL. El DBA debe revisar espacio, índices equivalentes y costo de mantenimiento antes de ejecutar el script en producción.

## 5. Corrección de valores opcionales

En Oracle, una cadena vacía se interpreta como `NULL`. En SQL Server, `N''` sigue siendo una cadena.

El procedimiento original reinicia varios importes de partida con texto vacío y posteriormente los inserta en columnas `NUMERIC` de `TMP_DOCUMENT_DETAIL`. Si el XML no contiene alguna condición opcional, SQL Server puede intentar convertir `N''` a número y producir:

```text
SQL-8114: Error converting data type nvarchar to numeric.
```

La versión optimizada reinicia con `NULL`:

- subtotal, IVA, bonificación y precio unitario;
- valores `ZFSI`, `ZFSK`, `ZT21`, `ZPR0`, `ZEXS`, `ZEXC` y `ZEXO`;
- signos de condiciones;
- textos opcionales en español e inglés.

Ventajas:

- evita conversiones inválidas;
- permite procesar partidas que no contienen todas las condiciones opcionales;
- conserva la equivalencia `'' = NULL` del procedimiento Oracle;
- evita trasladar valores de una partida anterior a la siguiente.

## 6. Equivalencia de comparaciones nulas

### 6.1 Código de compañía

Oracle no entra a un `IF` cuando una comparación produce `NULL`. La versión optimizada evita convertir artificialmente un código de compañía nulo en una cadena vacía.

Ventaja: un `CompanyCode` nulo no se clasifica automáticamente como compañía diferente de México.

### 6.2 Unidad de medida

La versión optimizada conserva la semántica nula al comparar la unidad de la factura con la unidad del material.

Ventaja: una unidad nula no activa una conversión de cantidad que Oracle tampoco ejecutaría.

## 7. Diagnóstico y manejo de errores

El procesamiento continúa protegido por una transacción. Si ocurre un error:

1. se cierran y liberan los cursores que hayan sido declarados o abiertos;
2. se revierte la transacción;
3. se registra el incidente en `EAI_OWNER.MX_EAI_MESSAGE_LOG`;
4. no se relanza la excepción, conservando el contrato del procedimiento existente y de Oracle.

El mensaje optimizado contiene:

- `ERROR_NUMBER()`;
- `ERROR_LINE()`;
- `ERROR_PROCEDURE()`;
- `ERROR_MESSAGE()`.

Ventaja: el equipo puede localizar el punto del fallo sin reproducir inicialmente todo el flujo.

Importante: como el error se registra y no se relanza, una ejecución no debe considerarse exitosa solamente porque el comando `EXEC` terminó. Siempre debe comprobarse el estado del mensaje y la ausencia de errores nuevos en `MX_EAI_MESSAGE_LOG`.

## 8. Reglas y flujos de negocio conservados

### 8.1 Lectura y preparación

- busca el mensaje por `ROW_ID`;
- obtiene el XML y la referencia;
- elimina cabecera, detalle y condiciones anteriores de la misma referencia;
- reconstruye el documento dentro de una transacción.

### 8.2 Partners y referencias

- `AG`: cliente principal y dirección;
- `WE`: destinatario de entrega;
- `RE` y `RSA`: cliente de facturación y pagador;
- referencia `001`: pedido V3;
- referencia `002`: pedido SAP;
- referencia `009`: fecha y hora;
- referencia `017`: factura V3;
- fecha de cabecera `028`: vencimiento.

### 8.3 Organizaciones y clases

Se conservan las reglas para:

- `Nota de Venta` → `C005`;
- `Payable` → `C004`;
- `PROFORMA` → `C006`;
- `ZIG2` → `C022`;
- `ZB1E` → `C019`;
- `ZG` → `C025` o `C031`;
- `ZL` → `C0FX` o `C030`;
- venta directa → `C003`.

También se conserva la actualización de `FacturaV3` para las clases que usan la referencia del mensaje.

### 8.4 Partidas

Por cada `ItemData` se procesan:

- número de partida;
- cantidad y unidad de medida;
- centro y material;
- descripción;
- subtotal, precio, bonificación e IVA;
- condiciones de envío, crédito e impuestos;
- textos ES y EN;
- reglas de material y conversiones UOM.

La regla para números de partida mayores a 9999 continúa usando el contador secuencial.

### 8.5 Casos especiales

Se mantienen:

- materiales `R031` y `R902`;
- material fijo `8800111` cuando corresponde;
- reglas de nota de débito;
- referencia bancaria y fecha especial;
- conversión para `PAQ` y `CASES`;
- clasificación `PDV A51`;
- función `FN_GET_DOC_TYPE`.

### 8.6 Estados y despacho

Se conservan los estados:

- `Processed`;
- `NotApply`;
- `CheckData`;
- `ConfirmCN`;
- `Reject<CompanyCode>`;
- `Review`.

El despacho continúa siendo:

- nota de débito: `EAI_OWNER.DEBITNOTE_TO_IFC`;
- factura normal: `EAI_OWNER.INVOICE_TO_PREVENTA`;
- venta directa: `EAI_OWNER.INVOICE_TO_FACTURA`.

## 9. Desde dónde se llama el procedimiento

En los scripts SQL Server del repositorio existen dos llamadas directas a `EAI_OWNER.SF_PROC_PREINVOICE_IFC`.

### 9.1 Flujo de facturas

La primera llamada se encuentra en:

```text
MSSQL/T3/EAI_OWNER/Package/RECV_INVOICE.SQL
```

La cadena de ejecución es:

```text
Job 550
  → EAI_OWNER.RECV_INVOICE
    → EAI_OWNER.SF_PROC_PREINVOICE_IFC
```

El Job 550 se define en `MSSQL/T3/EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL` y está configurado para ejecutar:

```sql
EXEC [EAI_OWNER].[RECV_INVOICE];
```

Su programación equivalente es cada 10 minutos.

`RECV_INVOICE` selecciona mensajes que cumplen, entre otras, estas condiciones:

- `QUEUE_NAME = 'Invoice'`;
- fecha de creación dentro de la ventana de cinco días;
- `PROCESSED IS NULL`;
- `FN_CHECK_INSTANCE(InstanceName) = 'YES'`;
- configuración `SalesForceOn = 'YES'`.

Por cada mensaje aceptado ejecuta el procedimiento original con el `ROW_ID`, número secuencial, nivel de traza y PID del proceso.

### 9.2 Flujo de pagos y notas de débito

La segunda llamada directa se encuentra en:

```text
MSSQL/T3/EAI_OWNER/Procedures/SF_PROC_CENTRAL_PAYMENT.SQL
```

La cadena completa es:

```text
Job 236
  → EAI_OWNER.RECV_PAYMENT
    → EAI_OWNER.SF_PROC_CENTRAL_PAYMENT
      → EAI_OWNER.SF_PROC_PREINVOICE_IFC
```

El Job 236 se define en `MSSQL/T3/EAI_OWNER/Jobs/01_CREATE_OR_UPDATE_JOBS.SQL` y ejecuta:

```sql
EXEC [EAI_OWNER].[RECV_PAYMENT];
```

También está programado cada 10 minutos.

`RECV_PAYMENT` selecciona mensajes que cumplen, entre otras, estas condiciones:

- `QUEUE_NAME = 'Payment'`;
- fecha de creación dentro de la ventana de veinte días;
- `PROCESSED IS NULL`;
- componente disponible para ejecución;
- `FN_CHECK_INSTANCE(InstanceName) = 'YES'`;
- configuración `SalesForceOn = 'YES'`.

Después llama a `SF_PROC_CENTRAL_PAYMENT`. Este procedimiento delega en `SF_PROC_PREINVOICE_IFC` cuando el mensaje entra al flujo identificado en las trazas como `WA -> DebitNote` y `Payment_MessageType` tiene más de cinco caracteres.

### 9.3 Impacto para activar la versión optimizada

Actualmente ambos llamadores continúan ejecutando:

```sql
[EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
```

Desplegar `SF_PROC_PREINVOICE_IFC_OPTIMIZADO` no cambia automáticamente ninguno de los dos flujos. Para activar completamente la versión optimizada deben evaluarse y modificar explícitamente estas dos llamadas:

1. `EAI_OWNER.RECV_INVOICE`;
2. `EAI_OWNER.SF_PROC_CENTRAL_PAYMENT`.

Cambiar solamente `RECV_INVOICE` optimizaría el flujo de facturas, pero los pagos clasificados como nota de débito seguirían usando el procedimiento original.

La búsqueda estática del repositorio no encontró otras llamadas directas en scripts MSSQL. Antes del cambio productivo, el DBA debe complementar esta revisión consultando dependencias de la instancia y comandos dinámicos que puedan existir fuera del repositorio.

## 10. Consideración sobre calificadores repetidos

El procedimiento Oracle recorre registros secuencialmente y normalmente conserva la última asignación. Tanto el procedimiento SQL Server original como el optimizado utilizan `MAX(CASE...)` o `TOP (1)` en algunos grupos.

El resultado es equivalente cuando cada calificador aparece una sola vez, que debe ser el contrato normal del mensaje. Si un calificador puede aparecer varias veces con valores distintos, el dueño de la interfaz debe definir explícitamente cuál valor tiene prioridad y ese caso debe incluirse en las pruebas funcionales.

Las organizaciones se recorren secuencialmente, por lo que sus reglas especiales conservan el orden documental.

## 11. Dependencias verificadas antes del despliegue

El script comprueba la existencia de:

- esquemas `EAI_OWNER` y `T3`;
- `MX_RECEIVE_MESSAGE_LOG`;
- `TMP_DOCUMENT_HEADER`;
- `TMP_DOCUMENT_DETAIL`;
- `TMP_DOCUMENT_CONDITIONS`;
- `TRACE_EAI_OWNER`;
- `MX_EAI_MESSAGE_LOG`;
- `MX_HASHTABLE`;
- `T3.MATERIAL`;
- `LINE_ITEM_TEXT`;
- `GETCONV`;
- `FN_GET_DOC_TYPE`;
- `DEBITNOTE_TO_IFC`;
- `INVOICE_TO_PREVENTA`;
- `INVOICE_TO_FACTURA`.

Si falta una dependencia, el despliegue se detiene con un mensaje específico.

## 12. Validaciones realizadas

Durante el desarrollo se realizaron:

- revisión del procedimiento original de SQL Server;
- comparación con el procedimiento Oracle;
- compilación real en una base SQL Server LocalDB aislada;
- ejecución funcional con un mensaje sintético de 20 partidas;
- verificación de estado `Processed`;
- verificación de 20 detalles, cantidad total 40 y subtotal 2,000;
- confirmación de cero errores en las ejecuciones aceptadas;
- comparación de cabecera, detalle, condiciones y estado;
- prueba A/B alternando el orden y descartando ejecuciones de calentamiento.

En la prueba sintética, la versión optimizada promedió 23.807 ms frente a 24.394 ms del control derivado del original. Esta medición sólo valida el comportamiento aislado; no sustituye las pruebas del ambiente real.

El procedimiento optimizado también fue probado en el ambiente del proyecto y se confirmó que es más eficiente que el original.

## 13. Pruebas recomendadas antes de producción

Probar como mínimo:

1. factura normal;
2. venta directa;
3. nota de débito;
4. clases especiales `PROFORMA`, `ZIG2`, `ZB1E`, `ZG` y `ZL`;
5. compañía mexicana, no mexicana y nula;
6. UOM `PAQ`, `CASES`, otra unidad y nula;
7. material existente, inexistente y duplicado;
8. partida sin condiciones opcionales;
9. documento con muchas partidas;
10. textos ES y EN con varias líneas;
11. calificadores repetidos;
12. error en cada procedimiento posterior para comprobar rollback y bitácora.

Por cada caso se deben comparar:

- `TMP_DOCUMENT_HEADER`;
- `TMP_DOCUMENT_DETAIL`;
- `TMP_DOCUMENT_CONDITIONS`;
- `MX_RECEIVE_MESSAGE_LOG`;
- `TRACE_EAI_OWNER`;
- `MX_EAI_MESSAGE_LOG`;
- efectos del procedimiento posterior.

Al comparar columnas de texto debe considerarse que `NULL` en la versión optimizada puede ser la representación correcta de una cadena vacía de Oracle.

## 14. Medición de rendimiento

Ejemplo de ejecución:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

EXEC [EAI_OWNER].[SF_PROC_PREINVOICE_IFC_OPTIMIZADO]
    @sRow_ID = N'<ROW_ID_DE_PRUEBA>',
    @nRowNum = 1,
    @nOutput = 0,
    @nPID = NULL;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

Para una comparación confiable:

1. utilizar mensajes equivalentes en datos aislados;
2. alternar el orden original/optimizado;
3. descartar ejecuciones de calentamiento;
4. ejecutar al menos diez muestras por versión;
5. comprobar cero errores nuevos en `MX_EAI_MESSAGE_LOG`;
6. comparar estado y resultados funcionales;
7. capturar duración, CPU, lecturas lógicas, plan real, bloqueos y esperas;
8. separar, cuando sea posible, el tiempo consumido por los procedimientos posteriores.

## 15. Activación

El despliegue del archivo optimizado no cambia los llamadores existentes. Después de la aceptación, el proceso correspondiente debe modificarse explícitamente para ejecutar:

```sql
[EAI_OWNER].[SF_PROC_PREINVOICE_IFC_OPTIMIZADO]
```

Se recomienda conservar temporalmente el procedimiento original durante el periodo de estabilización.

## 16. Reversa

Para retirar solamente el procedimiento optimizado:

```sql
DROP PROCEDURE IF EXISTS [EAI_OWNER].[SF_PROC_PREINVOICE_IFC_OPTIMIZADO];
```

La reversa del llamador consiste en volver a ejecutar:

```sql
[EAI_OWNER].[SF_PROC_PREINVOICE_IFC]
```

Los índices deben eliminarse únicamente después de confirmar con el DBA que no benefician ni son utilizados por otros procesos.
