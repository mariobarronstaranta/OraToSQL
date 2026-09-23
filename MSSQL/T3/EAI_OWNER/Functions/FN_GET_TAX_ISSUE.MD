# EAI_OWNER.FN_GET_TAX_ISSUE_OPTIMIZADO

## Objetivo

Obtiene el ajuste de IVA asociado con una factura desde
`T3.NDC_ISSUE_IVA`. La versión paralela conserva los parámetros y el retorno
de la función original:

```sql
EAI_OWNER.FN_GET_TAX_ISSUE_OPTIMIZADO(@P_FACTURA)
```

## Reglas conservadas

| Escenario | Resultado |
|---|---:|
| Existe una incidencia | Devuelve `Diferencia` |
| No existe la factura | `0.00` |
| `Diferencia` es `NULL` | `0.00` |
| `@P_FACTURA` es `NULL` | `0.00` |

No se agregó `SUM`, `MAX`, `MIN`, `TOP` ni `ORDER BY`. La implementación
original asigna el valor encontrado a una variable y Oracle recorría un cursor
sin orden; cambiar la selección alteraría el comportamiento cuando hay
duplicados.

## Optimizaciones

### Función con dependencia explícita

`FN_GET_TAX_ISSUE_OPTIMIZADO` utiliza `SCHEMABINDING`. En la validación quedó
marcada como determinista y continuó siendo elegible para *scalar UDF inlining*
con `is_inlineable = 1` e `inline_type = 1`.

Se eliminó una conversión redundante: `Diferencia` ya es `DECIMAL(6,2)`, igual
que el retorno de la función.

### Índice por factura

Se creó el script:

`T3/Indexes/NDC_ISSUE_IVA_FACTURA_IX.SQL`

El índice no único usa:

```sql
([FACTURA]) INCLUDE ([DIFERENCIA])
```

Esto permite localizar una factura sin recorrer `NDC_ISSUE_IVA` y recuperar el
ajuste desde el mismo índice. El script es idempotente y reconoce otro índice
equivalente aunque tenga un nombre diferente.

## Protección por duplicados

La tabla no tiene llave única y `WA_DIF_IVA_SAP_T3` puede insertar otra fila
cuando el ajuste anterior es cero. Debido a que un índice puede modificar el
orden físico de lectura, el script detiene el despliegue con el error `54902`
si una factura tiene dos valores de `Diferencia` contradictorios.

Los duplicados con el mismo ajuste no bloquean el índice porque producen el
mismo resultado. El diagnóstico completo es:

```sql
SELECT Factura, Diferencia, Fecha_Insert, Fecha_Update
FROM T3.NDC_ISSUE_IVA
WHERE Factura IN
(
    SELECT Factura
    FROM T3.NDC_ISSUE_IVA
    WHERE Factura IS NOT NULL
    GROUP BY Factura
    HAVING COUNT(*) > 1
)
ORDER BY Factura, Fecha_Insert, Fecha_Update;
```

No se creó un índice único porque eso modificaría una regla y podría fallar con
datos históricos legítimos o pendientes de depuración.

La validación del script protege el momento del despliegue, pero no evita que
`WA_DIF_IVA_SAP_T3` genere posteriormente nuevos conflictos. Este proceso debe
monitorearse y revisarse antes de considerar una restricción permanente.

## Callers identificados

Se localizaron cinco llamadas distribuidas en cuatro archivos:

- `EAI_OWNER.SF_GET_CREDIT_DATA`.
- `EAI.SF_CFDI_OPEN_ITEMS` original y optimizado.
- `T3.PROC_T3_DQC_PAYMENT`, con dos llamadas.

La función original no se reemplaza automáticamente; los callers deben migrar
de forma controlada después de las pruebas de QA. El índice beneficia tanto a
la función original como a la optimizada.

## Comparación con Oracle

No se encontró el DDL Oracle de `FN_GET_TAX_ISSUE`. Sí se encontraron sus
consumidores Oracle y `WA_DIF_IVA_SAP_T3`, que alimenta la misma tabla. La
versión optimizada conserva el contrato documentado por la migración MSSQL y
el flujo observable en Oracle: obtener la diferencia registrada o cero cuando
no existe un ajuste utilizable.

## Validación funcional

En una base LocalDB aislada se compilaron ambas funciones y se verificó igualdad
para:

- factura encontrada;
- factura inexistente;
- diferencia nula;
- parámetro nulo;
- duplicados con el mismo valor de diferencia.

También se ejecutó dos veces el script del índice para comprobar su
idempotencia. Las bases temporales fueron eliminadas al terminar.

## Pruebas de rendimiento

Resultados del banco sintético LocalDB:

| Patrón | Sin índice | Con índice | Resultado |
|---|---:|---:|---|
| 3,000 llamadas unitarias sobre 20,000 ajustes | 2,438.24 ms | 36.63 ms | 98.5% menos tiempo |
| Consulta masiva de 100,000 filas | 219.24 ms | 221.10 ms | Diferencia no material |

La mejora principal aparece en procedimientos, ciclos o ejecuciones que buscan
una factura a la vez. En consultas masivas SQL Server puede transformar la
función en una operación relacional gracias al *inlining*, por lo que ambos
planes tuvieron tiempos equivalentes.

Como contraparte, cada `INSERT`, `UPDATE` o `DELETE` sobre `NDC_ISSUE_IVA`
deberá mantener el nuevo índice. Este costo debe revisarse en QA junto con
`WA_DIF_IVA_SAP_T3`, aunque normalmente será pequeño frente al ahorro de las
búsquedas unitarias.

Estos resultados son sintéticos. En QA se deben comparar planes reales,
`STATISTICS IO` y `STATISTICS TIME` con volumen representativo.

## Orden de despliegue en QA

1. Ejecutar el diagnóstico de duplicados.
2. Corregir facturas con diferencias contradictorias, si existen.
3. Ejecutar `NDC_ISSUE_IVA_FACTURA_IX.SQL`.
4. Ejecutar `FN_GET_TAX_ISSUE_OPTIMIZADO.SQL`.
5. Comparar ambas funciones con una muestra productiva.
6. Medir los cuatro callers identificados antes de cambiar sus llamadas.

`SCHEMABINDING` impide alterar o eliminar las columnas dependientes mientras
exista la función optimizada. El DBA debe considerar esto en cambios futuros de
estructura.
