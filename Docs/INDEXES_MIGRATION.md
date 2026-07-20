# Migracion de indices y PK

Este documento registra el inventario de indices Oracle, su separacion en
archivos individuales y el estado de conversion a SQL Server.

## Inventario actual

| Schema | DDL individuales Oracle | Normales | Unicos | DDL MSSQL | Pendientes MSSQL |
| --- | ---: | ---: | ---: | ---: | ---: |
| `EAI` | 86 | 56 | 30 | 86 | 0 |
| `EAI_OWNER` | 65 | 63 | 2 | 65 | 0 |

`ORA/T3/EAI_OWNER/Indexes/DDL_INDEX_EAI_OWNER.SQL` es una exportacion
consolidada auxiliar. Sus 65 objetos tambien existen como archivos individuales,
por lo que el consolidado no se suma al total de objetos.

## Convencion de archivos

- Cada archivo individual se llama `<NOMBRE_INDICE>.SQL`.
- Las comillas externas producidas por la exportacion se retiran; las comillas
  dobles que califican schema, tabla, indice y columnas se conservan.
- Cada archivo contiene una sola sentencia y termina en `;`.
- Los indices funcionales Oracle se conservan literalmente en el origen.

## Conversion SQL Server disponible

`MSSQL/T3/EAI/Indexes` contiene los 86 archivos homologos:

| Tipo MSSQL | Cantidad | Tratamiento |
| --- | ---: | --- |
| `NONCLUSTERED INDEX` | 56 | Conserva nombre, tabla, columnas y orden |
| `UNIQUE NONCLUSTERED INDEX` | 2 | Indices unicos independientes de una restriccion |
| `PRIMARY KEY CLUSTERED` | 27 | Creacion condicional si la tabla aun no tiene PK |
| `UNIQUE NONCLUSTERED` constraint | 1 | Creacion condicional por nombre y tabla |

Los scripts eliminan las opciones fisicas exclusivas de Oracle, usan el
filegroup `[PRIMARY]` y verifican los catalogos de SQL Server antes de crear el
objeto. Esto permite ejecutar los archivos despues del DDL consolidado de tablas
sin duplicar las PK o la restriccion unica que ya estan declaradas alli.

La validacion se realizo en una base LocalDB temporal usando los bloques
`CREATE TABLE` reales de las 43 tablas implicadas. Las 43 tablas y los 86
scripts se ejecutaron correctamente; el catalogo temporal reporto 86 indices y
restricciones indexadas para `EAI`.

## Instalador consolidado

`MSSQL/T3/EAI/Indexes/Indices_Consolidados_EAI.SQL` contiene los 86 objetos en
orden alfabetico y permite instalar el lote desde un solo archivo. No incluye
`USE`; debe ejecutarse con la base destino seleccionada y despues de crear el
schema y las tablas.

El consolidado conserva las verificaciones `IF NOT EXISTS`, activa
`SET XACT_ABORT ON` y fue ejecutado dos veces consecutivas en la misma base
LocalDB temporal. Ambas ejecuciones finalizaron correctamente y mantuvieron el
conteo en 86 indices, lo que valida su comportamiento idempotente.

## Conversion SQL Server EAI_OWNER

`MSSQL/T3/EAI_OWNER/Indexes` contiene los 65 archivos homologos:

| Tipo | Cantidad | Tratamiento |
| --- | ---: | --- |
| Indices ordinarios | 55 | `NONCLUSTERED`, con nombre, tabla y columnas homologadas |
| Indices funcionales | 8 | Columna calculada persistida mas `NONCLUSTERED INDEX` |
| PK | 2 | Creacion condicional si la tabla aun no tiene PK |

Siete indices funcionales convierten texto `YYYY-MM-DD` a `date` mediante el
estilo determinista `112`; el octavo materializa `SUBSTRING(TERRITORIO, 17, 4)`.
Las columnas calculadas y los indices se crean de forma condicional.

`DEBIT_OPEN_ITEM_IDX8`, `PAGOS_IDX6` y `PAGOS_IDX7` excedian 1,700 bytes de
llave por combinar dos columnas `VARCHAR(1024)`. La primera columna se conserva
como llave y la segunda se mueve a `INCLUDE`; cada columna incluida tambien
cuenta con un indice individual dentro del lote.

`Indices_Consolidados_EAI_OWNER.SQL` instala los 65 objetos desde un solo
archivo, sin cambiar el contexto de base de datos. Fue ejecutado dos veces en
una base LocalDB temporal sobre las 24 tablas reales; ambas pasadas terminaron
con 65 indices y 8 columnas calculadas, confirmando su idempotencia.

## PK e indices unicos

La exportacion contiene objetos nombrados como PK mediante sentencias
`CREATE UNIQUE INDEX`. En Oracle, ese indice puede respaldar una restriccion de
llave primaria, pero la sentencia del indice no crea por si misma la restriccion
`PRIMARY KEY`.

Antes de convertir un objeto `_PK`:

1. Revisar el DDL de la tabla Oracle y localizar la restriccion `PRIMARY KEY`.
2. Revisar si la tabla SQL Server ya declara esa PK y crea su indice asociado.
3. Crear una PK en SQL Server solo cuando la restriccion Oracle lo confirme.
4. Evitar generar adicionalmente un indice unico duplicado sobre las mismas
   columnas.

## Indices funcionales

`EAI_OWNER` contiene indices basados en expresiones con `TO_DATE` y `SUBSTR`.
SQL Server no permite trasladar esas expresiones Oracle directamente a
`CREATE INDEX`. Cada caso requiere una columna calculada determinista e
indexable, o una decision de rediseño validada con las consultas consumidoras.

## Validacion pendiente

- Probar el lote `EAI` con datos representativos para detectar duplicados antes
  de un despliegue sobre tablas pobladas.
- Revisar tamaño maximo de llave, tipos de columnas y duplicados antes de crear
  indices unicos o PK.
- Confirmar con el DBA el mapeo de `LEGDB_DATA` y `LEGDB_INDX01` a filegroups
  SQL Server; no asumir que ambos corresponden siempre a `[PRIMARY]`.
