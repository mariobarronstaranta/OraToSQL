# Optimización de `EAI_OWNER.INVOICE_TO_PREVENTA`

## 1. Objetivo

Este documento compara:

- procedimiento original: `EAI_OWNER.INVOICE_TO_PREVENTA`;
- procedimiento candidato: `EAI_OWNER.INVOICE_TO_PREVENTA_OPTIMIZADO`;
- homólogo funcional: `ORA/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA.SQL`.

La optimización busca reducir el procesamiento fila por fila de las partidas sin alterar las reglas de folio, importes, bonificaciones, impuestos, unidad de medida, complemento RF, entrega ni manejo de errores.

El procedimiento original no se reemplaza. La versión optimizada puede desplegarse y probarse de manera independiente.

## 2. Archivos

| Archivo | Propósito |
|---|---|
| `MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA.SQL` | Implementación original de SQL Server. |
| `MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA_OPTIMIZADO.SQL` | Implementación optimizada. |
| `ORA/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA.SQL` | Referencia de reglas de negocio Oracle. |
| `MSSQL/T3/EAI_OWNER/Procedures/INVOICE_TO_PREVENTA.MD` | Este documento. |

## 3. Resumen de cambios

| Área | Original | Optimizado | Beneficio |
|---|---|---|---|
| Detalle común | Cursor y un `INSERT` por partida. | Un solo `INSERT ... SELECT` por conjunto. | Reduce `FETCH`, cambios de contexto y sentencias repetidas. |
| Clases `C030/C031` | Cursor con `WA_CANTIDAD_UMV`. | Conserva la misma ruta. | Mantiene parámetros `OUTPUT` y reglas especiales de UOM. |
| Cálculos | Asignaciones secuenciales por partida. | CTE por etapas que conserva el mismo orden lógico. | Permite que SQL Server optimice el conjunto completo. |
| `T3.Material` | `LEFT JOIN` dentro del origen de detalle. | Se conserva en ambas rutas. | Respeta una relación obligatoria de negocio. |
| `GETCONV` | Una llamada por partida. | Se mantiene dentro de la proyección set-based. | Conserva exactamente el contrato actual de conversiones. |
| Errores | Libera el cursor general. | También libera el cursor especial de detalle si existe. | Evita dejar cursores abiertos durante una excepción. |
| Despliegue | Nombre productivo. | Nombre independiente terminado en `_OPTIMIZADO`. | Facilita pruebas A/B y reversa. |

## 4. Diseño híbrido

### 4.1 Ruta set-based

Para todas las clases distintas de `C030` y `C031`, las partidas se agrupan y se insertan mediante una sola sentencia.

El cálculo se divide en CTE para mantener el orden de las reglas:

1. `DetailData`: normaliza y agrupa las filas temporales.
2. `BaseCalc`: convierte escala monetaria y calcula tasa de IVA y bonificación.
3. `LineCalc`: calcula IVA de envío, IVA de bonificación y subtotal neto.
4. `ClassCalc`: separa el IVA de envío para `C005/C006`.
5. `ReleaseCalc`: aplica la regla de liberación automática al 16 %.
6. `INSERT`: aplica el cálculo final para `C019/C025` y persiste el detalle.

Esta separación es importante porque algunas reglas sobrescriben el resultado de la regla anterior. Cambiar su orden alteraría el importe final.

### 4.2 Ruta especial `C030/C031`

Estas clases continúan usando `ScrDetalle` porque cada partida ejecuta:

```sql
EAI_OWNER.WA_CANTIDAD_UMV
```

El procedimiento devuelve cantidad y UOM mediante parámetros `OUTPUT`. Sustituir esa llamada sin rediseñar y validar primero `WA_CANTIDAD_UMV` podría cambiar la conversión de `MIL`, `PZ` o `PCE`.

La ruta especial conserva el código original para minimizar el riesgo funcional.

## 5. `JOIN` obligatorio a `T3.Material`

El siguiente `LEFT JOIN` se conserva intencionalmente tanto en la ruta rápida como en la ruta especial:

```sql
LEFT JOIN [T3].[Material] AS Mat
    ON <material normalizado> = Mat.Material
```

No debe eliminarse en futuras revisiones. Es una regla indicada expresamente por el equipo responsable.

La versión optimizada también conserva la cardinalidad del procedimiento original. Si `T3.Material` contiene varias filas para un mismo material, las filas participan antes del `GROUP BY` y pueden influir en las sumas. La prueba funcional incluyó deliberadamente dos coincidencias de material y produjo el mismo resultado que el original.

Recomendación para el DBA: verificar que exista un índice cuya primera clave sea `T3.Material.Material`. No se crea automáticamente porque `T3.Material` es una tabla compartida y primero deben revisarse sus índices reales, volumen y costo de escritura.

## 6. Reglas de negocio preservadas

### 6.1 Folio

- `C020/C021/C022`: llama `WA_FOLIO_FACTURA`.
- `C005/C006`: usa la referencia y sustituye `-O-` por `-`.
- `C019/C0FX/C025`: usa la referencia y genera complemento RF.
- `C030/C031`: genera complemento RF y llama `WA_FOLIO_FACTURA`.
- otras clases: usa `FacturaSAP`.

### 6.2 Escala monetaria

Las clases `C005`, `C006`, `C019`, `C0FX`, `C025`, `C030` y `C031` conservan `@nFactorDiv = 100`. Las demás usan factor uno.

### 6.3 Reconstrucción

Se mantiene la validación mediante `T3.Preventa_General.Fecha_Proc_BATMD`. Cuando el folio puede procesarse:

- elimina la cabecera anterior;
- elimina detalle y condiciones anteriores;
- reconstruye `RF_Complemento` cuando corresponde;
- inserta cabecera, condiciones y detalle;
- recalcula los totales de cabecera desde el detalle final.

### 6.4 Partidas

Se preservan:

- agrupación por factura, prefijo, línea, material, UOM y estado;
- cantidad uno para `C019`;
- UOM predeterminada `UA`;
- estado `Q` cuando el producto es `MALO`;
- redondeo monetario a dos decimales;
- separación del envío del subtotal;
- IVA de envío y bonificación;
- límite de bonificación de 100 %;
- recálculo de IVA para liberación automática;
- recálculo especial de IVA para `C019/C025`;
- traducción UOM mediante `GETCONV`.

### 6.5 Procesos posteriores

Se mantienen, en el mismo orden:

1. actualización final de `Preventa_General`;
2. `EAI_OWNER.INVOICE_TO_ENTREGA_PO`;
3. marca `Tmp_Document_Header.Procesado`;
4. asignación de `@pFolioFiscal`;
5. `T3.DELIVERY_WA_OXXO`.

## 7. Decisiones deliberadas

### 7.1 Se conserva `ScrGeneral`

No se eliminó el cursor de cabecera porque el repositorio no demuestra mediante una restricción `UNIQUE` que `ReferenceID` siempre produzca una sola fila. Eliminarlo sin confirmar esa cardinalidad podría cambiar el comportamiento cuando existan cabeceras duplicadas.

### 7.2 Se conserva `GETCONV`

La función usa `TOP (1)` sobre `MX_HASHTABLE`. Reemplazarla por un `JOIN` requiere confirmar primero que `Type + Source` sea único; de lo contrario podría multiplicar detalles. Mantener la función evita introducir esa diferencia funcional.

### 7.3 No se crean índices automáticamente

El script del procedimiento no modifica índices de tablas compartidas. Antes de agregar índices debe consultarse el plan real y comprobar índices equivalentes para:

- `T3.Preventa_General(Factura)`;
- `T3.Preventa_Detalle(Factura)`;
- `T3.Preventa_Condiciones(Factura)`;
- `T3.RF_Complemento(Factura)`;
- `T3.Material(Material)`.

El repositorio ya contiene índices para los accesos por referencia en las tablas temporales y para `MX_HASHTABLE(Type, Source)`; debe confirmarse que estén desplegados en el ambiente de prueba.

## 8. Manejo de errores y transacción

La versión optimizada conserva:

- `SET XACT_ABORT ON`;
- ausencia de una transacción local;
- participación en la transacción abierta por el llamador;
- registro en `EAI_OWNER.MX_EAI_MESSAGE_LOG`;
- `THROW` del error original.

El `CATCH` libera `ScrDetalle` cuando fue creado para `C030/C031` y después libera `ScrGeneral`.

El registro del error puede fallar cuando la transacción heredada queda en estado no confirmable. Esta conducta ya pertenece al contrato actual y no se modificó dentro de una optimización de rendimiento.

## 9. Llamadores actuales

El procedimiento original es invocado por:

```text
SF_PROC_PREINVOICE_IFC       → INVOICE_TO_PREVENTA
SF_PROC_PREINVOICE_INTER     → INVOICE_TO_PREVENTA
```

Desplegar la versión optimizada no cambia estos llamadores. Para activarla deben modificarse explícitamente después de la aceptación funcional.

## 10. Validaciones realizadas

### 10.1 Sintaxis y compilación

- Validación con `SET PARSEONLY ON`: correcta.
- Compilación real en SQL Server LocalDB con contratos de tablas, funciones y procedimientos: correcta.

### 10.2 Equivalencia funcional

Se compararon el original y el optimizado mediante `EXCEPT`, conteo de filas y bitácora.

Caso `C005`:

- ruta set-based;
- dos partidas;
- dos coincidencias deliberadas en `T3.Material`;
- complemento RF;
- cabecera, detalle, condiciones y RF: cero diferencias;
- errores: cero.

Caso `C030`:

- ruta especial con `WA_CANTIDAD_UMV`;
- conversión de `MIL`;
- cabecera, detalle, condiciones y RF: cero diferencias;
- errores: cero.

Matriz adicional:

| Clase | Folio y salidas equivalentes | Errores |
|---|---:|---:|
| `C006` | Sí | 0 |
| `C010` | Sí | 0 |
| `C019` | Sí | 0 |
| `C020` | Sí | 0 |
| `C025` | Sí | 0 |
| `C0FX` | Sí | 0 |

La matriz comparó el folio de salida, conteos y firmas de cabecera, detalle,
condiciones y complemento RF.

### 10.3 Rendimiento sintético

Prueba LocalDB con 150 partidas, procedimientos posteriores sustituidos por stubs, orden alternado y cuatro ejecuciones de calentamiento descartadas:

| Versión | Promedio |
|---|---:|
| Original | 101.017 ms |
| Optimizada | 19.920 ms |
| Mejora observada | 80.28 % |

La prueba terminó con 150 detalles y cero errores.

Esta medición demuestra el beneficio del procesamiento set-based en un entorno aislado. No garantiza el mismo porcentaje en QA o producción porque cambian estadísticas, índices, concurrencia, bloqueos, hardware y costo de los procedimientos posteriores.

## 11. Pruebas obligatorias en QA

Probar como mínimo:

1. una clase sin factor de división;
2. `C005` y `C006` con costo de envío;
3. `C019` y `C025` con recálculo de IVA;
4. `C020/C021/C022` con folio generado;
5. `C030/C031` con UOM `MIL`, `PZ`, `PCE` y sin material;
6. liberación automática `TBC`, `NO` y otro valor configurado;
7. producto `MALO`;
8. bonificación mayor a 100 %;
9. subtotal cero;
10. material único, inexistente y con múltiples coincidencias;
11. varias filas temporales que deban agruparse en una partida;
12. reproceso permitido y documento ya procesado;
13. error en `INVOICE_TO_ENTREGA_PO` y `DELIVERY_WA_OXXO`.

En cada caso deben compararse:

- parámetro `@pFolioFiscal`;
- `T3.Preventa_General`;
- `T3.Preventa_Detalle`;
- `T3.Preventa_Condiciones`;
- `T3.RF_Complemento`;
- `Tmp_Document_Header.Procesado`;
- bitácora de errores y efectos posteriores.

## 12. Ejecución controlada

```sql
DECLARE @Folio VARCHAR(30);

EXEC [EAI_OWNER].[INVOICE_TO_PREVENTA_OPTIMIZADO]
    @sInvoiceID = '<REFERENCE_ID>',
    @pFolioFiscal = @Folio OUTPUT;

SELECT @Folio AS FolioFiscal;
```

No se deben ejecutar original y optimizado simultáneamente sobre la misma referencia: ambos eliminan y reconstruyen las mismas tablas operativas y ejecutan procesos posteriores.

## 13. Activación y reversa

Después de superar QA, los llamadores pueden cambiarse de forma controlada para usar `INVOICE_TO_PREVENTA_OPTIMIZADO`.

La reversa consiste en restaurar la llamada a:

```sql
EAI_OWNER.INVOICE_TO_PREVENTA
```

Para retirar sólo el candidato:

```sql
DROP PROCEDURE IF EXISTS [EAI_OWNER].[INVOICE_TO_PREVENTA_OPTIMIZADO];
```
