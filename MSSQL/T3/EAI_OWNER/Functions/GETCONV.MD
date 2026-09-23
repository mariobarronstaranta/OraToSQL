# EAI_OWNER.GETCONV_OPTIMIZADO

## Objetivo

`GETCONV` traduce valores mediante el catálogo genérico
`EAI_OWNER.MX_HashTable`. La versión optimizada conserva la interfaz escalar:

```sql
EAI_OWNER.GETCONV_OPTIMIZADO(@sType, @sValue)
```

## Contrato funcional conservado

| Escenario | Resultado |
|---|---|
| Existe `Type + Source` | Devuelve `Target` |
| No existe la conversión | Devuelve el mismo `@sValue` |
| `@sValue` es `NULL` | Devuelve `NULL` |
| La fila existe y `Target` es `NULL` | Devuelve `NULL` |

No se reemplazó `Target` nulo con `ISNULL` o `COALESCE`, porque hacerlo cambiaría
la regla histórica. También se conserva `TOP (1)` sin imponer un orden nuevo.

## Optimizaciones

### 1. Función apta para optimización del motor

La función usa `SCHEMABINDING`, permitiendo a SQL Server registrar que depende
de la estructura concreta de `EAI_OWNER.MX_HashTable`. En la validación con
SQL Server LocalDB, la función quedó marcada como determinista y continuó
siendo elegible para *scalar UDF inlining*.

La función original ya era elegible para *inlining*. Por lo tanto,
`SCHEMABINDING` mejora sus metadatos y protege la dependencia, pero no debe
presentarse por sí solo como una reducción importante del tiempo de ejecución.

No se convirtió en función tabular porque eso cambiaría la forma de invocarla y
obligaría a modificar todos los callers con `APPLY`.

### 2. Se conserva el índice existente

`MX_HASHTABLE_IX (Type, Source)` ya permite localizar la conversión mediante
una búsqueda indexada. Se probó agregar `Target` como columna incluida, pero no
se conservó el cambio porque no produjo una mejora consistente.

En la prueba masiva de 50,000 llamadas, el índice original tardó 87 ms y la
variante cubriente 98 ms. Aunque el índice cubriente eliminó un acceso a la
tabla, SQL Server eligió otro plan de ejecución y el tiempo total aumentó.
Modificar globalmente el índice con esa evidencia habría introducido un riesgo
de regresión para los numerosos consumidores.

Los archivos de índices permanecen sin cambios funcionales.

## Alcance e impacto

El análisis estático encontró 393 referencias a `GETCONV` en 72 archivos SQL:
procedimientos y paquetes de `EAI`, `EAI_OWNER` y `T3`. Por esa razón, la
función original no se reemplaza automáticamente en esta etapa.

Para probar la función paralela, cambie únicamente callers controlados en QA y
compare resultados antes de promoverla bajo el nombre original.

## Resultado de rendimiento

Se ejecutaron ocho repeticiones de 100,000 conversiones bajo el mismo conjunto
de datos e índice:

| Versión | Tiempo promedio |
|---|---:|
| `GETCONV` original | 163.56 ms |
| `GETCONV_OPTIMIZADO` | 163.13 ms |

La diferencia aproximada de 0.3% está dentro del ruido normal de una prueba
sintética. No existe evidencia para afirmar que sustituir únicamente la función
reduzca materialmente el tiempo de los procesos.

La optimización de mayor impacto debe hacerse en cada caller de alto volumen:

- evaluar una configuración constante una sola vez y guardarla en una variable;
- convertir una vez cada valor distinto y reutilizar el resultado;
- usar una tabla temporal de equivalencias en cargas masivas;
- evitar invocar `GETCONV` varias veces con los mismos argumentos en una fila.

Estas técnicas ya se aplicaron en procedimientos optimizados del proyecto y
reducen accesos repetidos a `MX_HashTable` sin cambiar el contrato general.

## Validación técnica realizada

La función original y la optimizada se compilaron en una base LocalDB aislada.
Se comprobó igualdad para los siguientes casos:

- conversión encontrada;
- conversión inexistente y retorno del valor original;
- parámetros `NULL`;
- fila encontrada con `Target` nulo;
- fila encontrada con `Target` vacío.

También se verificó en `sys.sql_modules` que la versión optimizada conserva
`is_inlineable = 1` e `inline_type = 1`. Las bases temporales se eliminaron al
terminar las pruebas.

## Compatibilidad con Oracle

El repositorio Oracle contiene numerosos consumidores, pero no incluye el DDL
de la función `EAI_OWNER.GETCONV`. La equivalencia se validó contra el contrato
documentado en la migración MSSQL y contra su uso observable:

- búsqueda por `Type + Source`;
- retorno de `Target` al encontrar una fila;
- retorno del valor original cuando no hay conversión.

## Riesgo de datos duplicados

`MX_HashTable` no tiene una restricción única sobre `(Type, Source)`. Si existen
dos filas para la misma pareja, tanto la función original como la optimizada
pueden devolver cualquiera de sus `Target`. Antes de crear una restricción
única debe ejecutarse este diagnóstico y corregirse el catálogo:

```sql
SELECT [Type], [Source], COUNT(*) AS Repeticiones
FROM EAI_OWNER.MX_HashTable
GROUP BY [Type], [Source]
HAVING COUNT(*) > 1;
```

No se agregó una restricción única porque podría impedir el despliegue si hay
duplicados históricos y cambiaría el comportamiento existente.

## Orden de despliegue en QA

1. Confirmar que exista `MX_HASHTABLE_IX (Type, Source)`.
2. Ejecutar `GETCONV_OPTIMIZADO.SQL`.
3. Comparar ambas funciones con conversiones existentes, inexistentes y nulas.
4. Medir los callers de mayor volumen con planes reales, `STATISTICS IO` y
   `STATISTICS TIME`.
5. Sustituir callers solo después de la aceptación funcional y de rendimiento.

`SCHEMABINDING` impide alterar o eliminar columnas dependientes de
`MX_HashTable` mientras la función exista. Para un cambio futuro de estructura,
el DBA deberá retirar temporalmente la función o su vínculo de esquema.
