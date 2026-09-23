# `EAI_OWNER.INVOICE_TO_FACTURA_OPTIMIZADO`

## Propósito

`INVOICE_TO_FACTURA_OPTIMIZADO` transforma una factura almacenada en las tablas temporales de `EAI_OWNER` en registros definitivos de factura dentro del esquema `T3`.

La versión optimizada conserva el procedimiento original y se instala con un nombre diferente. Esto permite comparar ambas implementaciones antes de modificar el flujo productivo.

Archivos relacionados:

- Original MSSQL: `INVOICE_TO_FACTURA.SQL`.
- Versión optimizada: `INVOICE_TO_FACTURA_OPTIMIZADO.SQL`.
- Homólogo Oracle: `ORA/T3/EAI_OWNER/Procedures/INVOICE_TO_FACTURA.SQL`.

## Firma

```sql
EAI_OWNER.INVOICE_TO_FACTURA_OPTIMIZADO
    @sInvoiceID    VARCHAR(30),
    @pFolioFiscal VARCHAR(30) OUTPUT
```

- `@sInvoiceID` identifica el encabezado y detalle temporal.
- `@pFolioFiscal` devuelve el folio T3 generado. Se inicializa en `NULL`, como un parámetro `OUT` de Oracle.

## Desde dónde es llamado

La versión original es llamada desde dos variantes del procesamiento de preinvoice IFC:

- `EAI_OWNER.SF_PROC_PREINVOICE_IFC`.
- `EAI_OWNER.SF_PROC_PREINVOICE_IFC_OPTIMIZADO`.

La creación del nuevo procedimiento no modifica esos llamadores. La sustitución debe realizarse únicamente después de las pruebas en QA.

## Flujo funcional

1. Lee `EAI_OWNER.TMP_DOCUMENT_HEADER` usando `ReferenceID`.
2. Convierte el centro a distribuidor.
3. Obtiene el cliente TMD correspondiente al cliente SAP.
4. Convierte `C005` a `C003` y `C006` a `C004`.
5. Determina si una factura existente puede reconstruirse.
6. Calcula bonificación, subtotal e IVA del encabezado.
7. Elimina una ejecución previa del mismo folio.
8. Inserta `T3.RF_Complemento` y `T3.Factura_General`.
9. Agrupa y calcula el detalle completo.
10. Inserta todas las filas en `T3.Factura_Detalle`.
11. Recalcula los totales de `Factura_General` desde el detalle.
12. Marca el encabezado temporal como procesado.
13. Ejecuta `EAI_OWNER.INVOICE_TO_ENTREGA_PO`.
14. Devuelve el folio generado.

## Cambios de rendimiento

### Eliminación de los tres cursores

El original utiliza:

- `ScrGeneral` para el encabezado.
- `ScrValida` para decidir si procesa la factura.
- `ScrDetalle` para calcular e insertar cada línea.

La versión optimizada no contiene cursores ni ciclos `WHILE`.

El encabezado se obtiene mediante asignación directa y la validación se resuelve con una consulta sencilla. El detalle se inserta mediante una sola operación por conjuntos.

### Sin materialización innecesaria del detalle

La optimización no copia todas las líneas a una tabla temporal adicional. Utiliza CTE sucesivas que representan etapas de cálculo y terminan en un único `INSERT ... SELECT`.

Esta decisión evita repetir el problema observado en optimizaciones anteriores de XML, donde el costo de materializar datos podía superar el ahorro obtenido.

### Sustitución de `GETCONV` por búsqueda relacional

El original ejecuta `EAI_OWNER.GETCONV` por cada línea para convertir la unidad de medida. La nueva versión consulta directamente `MX_HashTable` mediante `OUTER APPLY`.

Si no existe conversión, conserva la unidad original, igual que `GETCONV`.

### Integración de `WA_CANTIDAD_UMV`

Para las clases `C030` y `C031`, el original llama `WA_CANTIDAD_UMV` por cada detalle. Esa lógica se integró en la consulta set-based:

- `MIL`: cantidad multiplicada por 1000 y dividida entre `Cig_x_CLL`.
- `PZ` o `PCE`: cantidad dividida entre `Cig_x_CLL`.
- La unidad final se toma de `T3.Material` cuando existe un tamaño de paquete válido.
- Si no existe una conversión aplicable, se conservan cantidad y unidad normales.

### Se conserva el `JOIN` a `T3.Material`

El `LEFT JOIN` con `T3.Material` no fue eliminado. Además de conservar la estructura del procedimiento original, ahora proporciona `Unidad_Med_Vta` y `Cig_x_CLL` para la conversión de `C030/C031`.

### Cálculos divididos en etapas

Las CTE tienen responsabilidades separadas:

- `DetailBase`: agrupa la información temporal.
- `DetailMapped`: convierte la unidad de medida.
- `DetailConverted`: calcula cantidad, importes base y tasa de IVA.
- `DetailCalculated`: calcula bonificaciones, envío y crédito.
- `DetailFinal`: aplica las reglas especiales de IVA.

Esta separación facilita revisar las fórmulas sin ejecutar procesamiento fila por fila.

## Reglas de negocio conservadas

| Regla | Estado |
|---|---|
| `C005` se transforma en `C003` | Conservada |
| `C006` se transforma en `C004` | Conservada |
| Las cuatro clases anteriores utilizan factor divisor 100 | Conservada |
| Factura inexistente o con fecha de proceso `NULL` se puede reconstruir | Conservada |
| Fecha centinela posterior a `2999-01-01` permite reconstrucción | Conservada |
| Ubicación por defecto `TBD` | Conservada |
| Ajuste de subtotal para clases especiales | Conservado |
| Material convertido numéricamente para retirar ceros iniciales | Conservado |
| Material no numérico genera error | Conservado |
| `C019` utiliza cantidad uno por línea antes de agrupar | Conservada |
| Estado de producto `MALO` se convierte en `Q` | Conservado |
| Conversión UOM con fallback al valor original | Conservada |
| Conversión de cantidad `C030/C031` | Conservada e integrada |
| Recalcular IVA para `C025/C019` | Conservado |
| Separación de envío y crédito del subtotal | Conservada |
| IVA de envío y crédito solamente para valores positivos | Conservado |
| Precio unitario basado en subtotal final entre cantidad | Conservado |
| Cantidad cero conserva el error de división del original | Conservado |
| Totales de encabezado recalculados desde el detalle | Conservados |
| Error registrado sin propagarse al integrador | Conservado |

## Comparación con Oracle

Se verificaron el flujo de encabezado, las clases de factura, las fórmulas de detalle, la conversión UOM, el complemento fiscal, la actualización de totales y la llamada final a entrega.

Se mantiene la corrección ya existente en MSSQL para `Bonif_Porc` del encabezado: utiliza la bonificación calculada. El código Oracle utiliza la propia variable antes de asignarla, lo cual puede dejarla en `NULL`.

La condición de compañía `MX10` únicamente asignaba `sRF_Comp`; el bloque condicional que habría controlado `RF_Complemento` está comentado en Oracle. Por eso ambas versiones MSSQL insertan el complemento independientemente de esa bandera.

## Dependencias

### Tablas de entrada

- `EAI_OWNER.TMP_DOCUMENT_HEADER`.
- `EAI_OWNER.TMP_DOCUMENT_DETAIL`.
- `EAI_OWNER.MX_HashTable`.

### Tablas de salida

- `T3.Factura_General`.
- `T3.Factura_Detalle`.
- `T3.RF_Complemento`.
- `EAI_OWNER.MX_EAI_MESSAGE_LOG` para errores.

### Catálogos

- `T3.Material`.
- `T3.Mov_Cliente`, consultada por `FN_GET_CLIENTE_TMD`.

### Funciones y procedimientos

- `EAI.CONV_PLANT_TO_DIST`.
- `EAI_OWNER.FN_GET_CLIENTE_TMD`.
- `EAI_OWNER.INVOICE_TO_ENTREGA_PO`.

La llamada fila por fila a `EAI_OWNER.GETCONV` y a `EAI_OWNER.WA_CANTIDAD_UMV` fue eliminada del procedimiento optimizado.

## Índices que deben revisarse

La ganancia depende de que existan índices adecuados en:

```text
EAI_OWNER.TMP_DOCUMENT_HEADER (ReferenceID)
EAI_OWNER.TMP_DOCUMENT_DETAIL (ReferenceID)
EAI_OWNER.MX_HashTable         (Type, Source) INCLUDE (Target)
T3.Factura_General             (Factura)
T3.Factura_Detalle             (Factura)
T3.RF_Complemento              (Factura)
T3.Material                    (Material) INCLUDE (Unidad_Med_Vta, Cig_x_CLL)
T3.Mov_Cliente                 (Cliente_SAP) INCLUDE (Cliente_V3)
```

No se agregaron índices automáticamente. El DBA debe revisar primero los índices reales para evitar duplicados.

## Benchmark ejecutado

Se construyó una base LocalDB temporal utilizando los tipos reales disponibles en los scripts DDL del repositorio. La prueba utilizó:

- Una factura de clase de entrada `C005`, transformada a `C003`.
- 500 líneas de detalle.
- Materiales existentes en `T3.Material`.
- Conversión de UOM mediante `MX_HashTable`.
- Diez ejecuciones consecutivas de cada versión.
- Los mismos datos e índices para ambas implementaciones.

Resultado observado en esa ejecución:

| Versión | Tiempo acumulado |
|---|---:|
| Original | 3605.449 ms |
| Optimizada | 515.665 ms |
| Mejora observada | 85.70 % |

La comparación de todas las columnas insertadas en `T3.Factura_Detalle` reportó cero diferencias para las 500 líneas.

Este benchmark es sintético y sirve para validar la dirección técnica. No sustituye las pruebas con volumen, estadísticas, hardware y concurrencia reales de QA o producción.

## Pruebas requeridas en QA

Se deben probar como mínimo:

1. `C003`, `C004`, `C005` y `C006` para validar el factor 100.
2. `C019` y `C025` para validar el recálculo de IVA.
3. `C030` y `C031` con unidades `MIL`, `PZ`, `PCE` y otras.
4. Material con `Cig_x_CLL` positivo, cero y `NULL`.
5. Material inexistente.
6. Material no numérico para confirmar el manejo de error.
7. Bonificación, envío y crédito positivos, cero y `NULL`.
8. Cantidad `NULL` y cantidad cero.
9. Factura nueva, procesada y con fecha centinela 2999.
10. Facturas con uno, decenas, cientos y miles de detalles.

Para cada caso se deben comparar:

- Parámetro `@pFolioFiscal`.
- `T3.Factura_General`.
- `T3.Factura_Detalle`.
- `T3.RF_Complemento`.
- Estado de `TMP_DOCUMENT_HEADER`.
- Registro de errores.
- Efecto de `INVOICE_TO_ENTREGA_PO`.

## Medición recomendada

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @Folio VARCHAR(30);

EXEC EAI_OWNER.INVOICE_TO_FACTURA_OPTIMIZADO
    @sInvoiceID = 'REFERENCIA_DE_PRUEBA',
    @pFolioFiscal = @Folio OUTPUT;

SELECT @Folio AS FolioFiscal;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

La base debe restaurarse al mismo estado antes de medir cada versión.

## Activación

Después de aprobar equivalencia y rendimiento, se deben actualizar de manera controlada los llamadores:

```sql
EXEC EAI_OWNER.INVOICE_TO_FACTURA_OPTIMIZADO
    @sInvoiceID = @sReferenceID,
    @pFolioFiscal = @sFolioFiscalDoc OUTPUT;
```

No se realizó este cambio automáticamente.

## Rollback

El rollback consiste en conservar o restaurar la llamada a:

```sql
EAI_OWNER.INVOICE_TO_FACTURA
```

Para retirar únicamente la versión optimizada:

```sql
DROP PROCEDURE IF EXISTS EAI_OWNER.INVOICE_TO_FACTURA_OPTIMIZADO;
```
