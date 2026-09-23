# EAI_OWNER.WA_ASIGNACION_PAGO_OPTIMIZADO

## Propósito

Esta versión optimiza la preparación, validación y liberación de asignaciones entre facturas y notas de crédito cargadas en `EAI_OWNER.X_ASIGNACION_PAGO`. El procedimiento original no se modifica.

Archivo de despliegue: `WA_ASIGNACION_PAGO_OPTIMIZADO.SQL`.

## Niveles de ejecución

- `@pLevel <= 10`: calcula importes fiscales y RFC de facturas y notas de crédito.
- `@pLevel <= 100`: consulta los saldos vigentes mediante los procedimientos de factura y crédito.
- Todos los niveles: identifica asignaciones aplicadas, RFC incompatibles, documentos liberados, duplicidades y excedentes.
- `@pLevel >= 1000`: inserta las filas elegibles en `T3.Asignacion_Pago`.
- `@pDays`: resta días a la fecha de asignación durante la liberación.

## Optimizaciones realizadas

### Estrategia adaptativa según el tamaño de la carga

Al comenzar se cuenta el contenido de `X_ASIGNACION_PAGO`. Con hasta 50 filas se usa una ruta directa sin tablas temporales; con más de 50 filas se habilitan la agregación fiscal compartida y la aplicación en bloque de saldos.

Beneficio: evita que el costo fijo de crear objetos en `tempdb` perjudique las ejecuciones pequeñas y conserva la reducción de lecturas en cargas grandes. El umbral de 50 fue validado técnicamente, pero debe confirmarse con datos de QA y puede ajustarse si la distribución productiva es distinta.

### Una agregación fiscal compartida para cargas grandes

El original ejecuta prácticamente la misma agregación sobre `Registro_Fiscal`, `Registro_Fiscal_Detalle` y `Cliente` una vez para facturas y otra para notas. Para más de 50 filas, la versión optimizada crea un catálogo unificado de documentos mediante `UNION`, agrega el detalle una sola vez y reutiliza el resultado para ambos `UPDATE`. La ruta pequeña conserva las dos consultas set-based del original.

Beneficio: reduce lecturas, agregaciones y memoria cuando existen documentos repetidos o un documento aparece en ambos roles.

### Aplicación en bloque de saldos pendientes

Las llamadas a `SF_GET_INVOICE_DATA` y `SF_GET_CREDIT_DATA` no pueden convertirse directamente en una consulta set-based porque retornan datos mediante parámetros `OUTPUT`. Se conserva un cursor `LOCAL FAST_FORWARD` por referencia distinta. En cargas grandes sus resultados se guardan en tablas temporales y se aplican mediante un solo `UPDATE` por tipo de documento; en cargas pequeñas se actualizan directamente para evitar sobrecosto.

Beneficio: evita volver a recorrer `X_ASIGNACION_PAGO` después de cada llamada. La cantidad de actualizaciones pasa de una por documento distinto a una para facturas y una para notas.

### Detección de asignaciones con semi-join

La detección contra `T3.Asignacion_Pago` usa `EXISTS` porque solamente interesa saber si hay al menos una coincidencia.

Beneficio: SQL Server puede detener la búsqueda al encontrar la primera fila y no necesita formar todas las coincidencias del `JOIN`.

### Cálculo único del estado base

El `CASE` que determina `Revisar RFC`, `Documento ya liberado`, `Ok` o `Revisar Asignacion` se calcula una sola vez mediante `CROSS APPLY` y se reutiliza como valor y filtro.

### Liberación materializada

Las filas elegibles y su `Pago_ID` se guardan en `#ReleaseRow`. Ese mismo conjunto alimenta la inserción y la actualización de estado.

Beneficio: evita una segunda consulta a `T3.Registro_Fiscal` y asegura que ambas operaciones trabajen con la misma fotografía lógica dentro de la transacción.

## Reglas de negocio conservadas

- La suma fiscal incluye subtotal, IVA, envío y crédito de cada detalle.
- El cliente debe estar vigente en la fecha de la factura para obtener el RFC.
- Una asignación existente con la misma factura, nota e importe se marca como aplicada.
- Los RFC nulos se comparan con el RFC genérico `XAXX010101000`.
- Las filas válidas no se escriben con `Status_Asignacion = 'Ok'`; conservan su estado anterior, normalmente `NULL`, como en Oracle.
- La validación de duplicidad interna se ejecuta antes de los excedentes.
- Un excedente de nota o factura reemplaza el estado calculado previamente.
- Solamente se liberan importes positivos cubiertos por ambos saldos pendientes.
- La excepción se registra y no se relanza al caller.
- Cuando una excepción deja la transacción confirmable, se conserva el comportamiento Oracle de confirmar el trabajo previo.

## Comparación con Oracle

Se revisó `ORA/T3/EAI_OWNER/Procedures/WA_ASIGNACION_PAGO.SQL`. La versión optimizada conserva el orden funcional de `ScrFacturas`, `ScrNotas`, saldos pendientes, duplicidad, validaciones, excedentes y liberación.

Los cursores Oracle que solamente realizaban actualizaciones fueron convertidos en operaciones relacionales. Los dos cursores restantes son necesarios por las interfaces `OUTPUT` de los procedimientos dependientes.

El identificador de pago conserva el formato Oracle `YYDDDHH` más el consecutivo iniciado en `2501`. Al igual que Oracle, no se introduce un orden funcional donde el cursor original usaba `ROWNUM` sin `ORDER BY`.

## Dependencias

- Procedimientos: `EAI_OWNER.SF_GET_INVOICE_DATA` y `EAI_OWNER.SF_GET_CREDIT_DATA`.
- Tablas de trabajo y bitácora: `EAI_OWNER.X_ASIGNACION_PAGO` y `EAI_OWNER.MX_EAI_MESSAGE_LOG`.
- Tablas operativas: `T3.Registro_Fiscal`, `T3.Registro_Fiscal_Detalle`, `T3.Cliente`, `T3.CFDI_Documentos` y `T3.Asignacion_Pago`.

## Validación técnica realizada

El procedimiento fue compilado y ejecutado en una base LocalDB temporal con el mismo contrato de columnas y dependencias controladas. Se comprobó lo siguiente:

- Coincidencia completa de las 12 columnas de `X_ASIGNACION_PAGO` entre original y optimizado.
- Estados `NULL`, `Revisar RFC`, `Documento ya liberado`, `Asignacion ya aplicada`, `Duplicidad de Asignacion`, `Revisar Asignacion` y `Asignacion Excedente`.
- Misma cantidad y mismos datos funcionales durante la liberación con `@pLevel = 1000` y `@pDays = 2`.
- Conservación de resultados anteriores y creación de la bitácora cuando una consulta de factura falla a mitad del proceso.

Resultados sintéticos observados:

| Prueba | Original | Optimizado | Resultado |
|---|---:|---:|---|
| Nivel 0, 1,000 filas y 1,000 pares distintos | 1,853 ms | 289 ms | 84.4 % menos tiempo. |
| Nivel 0, una fila durante 100 ejecuciones | 988 ms | 889 ms | Sin regresión observada en la ejecución repetida. |

Las dependencias de factura y crédito se simularon para aislar el costo de este procedimiento. Estos tiempos no sustituyen una prueba en QA: en producción influyen el volumen, los índices, la caché, la concurrencia y el costo real de los procedimientos dependientes.

## Callers encontrados

La búsqueda estática del repositorio no encontró otro procedimiento MSSQL que ejecute directamente `EAI_OWNER.WA_ASIGNACION_PAGO`. Esto indica que probablemente se invoca manualmente, desde una aplicación o desde un job no representado como llamada SQL en los procedimientos del repositorio. Debe confirmarse en SQL Agent y con el equipo de operación antes de reemplazar el nombre.

## Despliegue recomendado

1. Ejecutar `WA_ASIGNACION_PAGO_OPTIMIZADO.SQL` en QA.
2. Cargar una copia representativa de `X_ASIGNACION_PAGO`.
3. Ejecutar original y optimizado sobre copias idénticas.
4. Comparar todas las columnas de `X_ASIGNACION_PAGO` y las filas insertadas en `T3.Asignacion_Pago`.
5. Medir duración, CPU, lecturas lógicas, escrituras y bloqueos para los niveles `0`, `100` y `1000`.
6. Cambiar el job o caller únicamente después de la aceptación funcional y de rendimiento.

## Casos mínimos de QA

1. Factura y nota válidas con el mismo RFC.
2. RFC distintos.
3. Documento ya liberado.
4. Asignación previamente aplicada.
5. Duplicidad interna de factura y nota.
6. Excedente acumulado por nota de crédito.
7. Excedente acumulado por factura.
8. Importe cero o negativo.
9. Saldo insuficiente en factura o nota.
10. Liberación con `@pDays = 0` y con un valor mayor a cero.
11. Error durante una consulta de saldo para verificar bitácora y confirmación del trabajo previo.
