# Claves primarias T3 a partir del listado Oracle

Fuente recibida: `PKS_ORACLE_T3.txt`, copiada sin cambios como
`PKS_ORACLE_T3.origen.txt`. Contiene **81 PK, 146 columnas**. El nombre de cada
restriccion y el orden de sus columnas se toman literalmente del archivo.
`manifest.json` conserva el inventario, huella SHA256 y cotejo del DDL local.

## Uso en SSMS

1. Abrir `01_CREAR_PK_T3.sql`, conectado a la base **T3QA**. Ejecutar completo
   con `@Aplicar bit=0` para obtener la prevalidacion y DDL propuesto. No crea
   objetos permanentes ni modifica datos. El XML DDLPropuesto conserva el
   texto completo si el grid de SSMS trunca la columna SQLPropuesto.
2. Revisar estados y resolver las tablas `BLOQUEADA`. Sus columnas FilasConNull,
   GruposDuplicados y SQLDiagnostico ayudan a investigar; las consultas TOP(20)
   de SQLDiagnostico son solo lectura. El script no borra ni rellena registros.
3. Cambiar a `@Aplicar bit=1` y ejecutar completo para crear las PK. Debe usarse
   sin transaccion externa y con IMPLICIT_TRANSACTIONS OFF. Si la prevalidacion
   encuentra un bloqueo, no aplica ninguna de las PK seleccionadas.
4. Ejecutar `02_VERIFICAR_PK_T3.sql`, de solo lectura, para comparar las
   restricciones instaladas con las 81 esperadas.

Si aparece 56818 (indice con el nombre solicitado ya existente), ejecutar
`03_REVISAR_INDICES_EXISTENTES.sql`. Solo consulta metadatos: compara nombre,
columnas y orden, unicidad, indicador de PK, filtros, estado, nullabilidad y
FK que referencian el indice. No supone que tener el mismo nombre equivale a
tener la PK ni elimina indices para liberar el nombre. Este diagnostico debe
revisarse antes de preparar un cambio para esos casos.

Para una sola tabla, en el 01 usar, por ejemplo:

```sql
DECLARE @SoloTabla sysname=N'MATERIAL';
```

Con NULL se incluyen las 81. Una PK existente con las mismas columnas y orden
se reconoce aunque tenga otro nombre: no se renombra ni reconstruye. Una PK
existente diferente se reporta para revision, sin eliminarla.

## Columnas declaradas NULL

Las columnas de PK deben ser NOT NULL. El DDL local declara muchas como NULL.
Por eso `@ConvertirColumnasANotNull bit=1` incluye ALTER COLUMN NOT NULL cuando
los datos actuales no contienen NULL; forma parte del cambio de esquema al
aplicar, no del diagnostico. Usa los metadatos reales del destino para conservar
tipo, longitud, precision, escala, tipos alias y collation.

Antes de confirmar cada tabla se comparan sus tipos, longitudes, precision,
escala, collation e identidad; un cambio inesperado revierte esa tabla.
Cada ALTER se compila por separado para que ADD CONSTRAINT vea las columnas
ya declaradas NOT NULL, dentro de la misma transaccion.

Si no se desea esa conversion automatica, poner el parametro en 0; las PK
que la necesiten quedaran bloqueadas. No convierte tipos ni trunca valores.
Las PK se crean NONCLUSTERED para no sustituir indices clustered existentes;
es una decision fisica para el destino, no informacion incluida en el listado
Oracle. No replica configuraciones de almacenamiento Oracle que no se recibieron.

## Validaciones y aplicacion

- Comprueba tabla, columnas, tipos/atributos compatibles y colisiones de nombre.
- Detecta filas con cualquier columna de la clave NULL y combinaciones
  duplicadas, con las reglas de comparacion reales de SQL Server. Diferencias
  de collation respecto de Oracle pueden revelar duplicados nuevos.
- Por compatibilidad limita las propuestas automaticas a 32 columnas y
  900 bytes declarados. Definiciones que excedan ese limite, tipos especiales,
  tablas particionadas o de memoria requieren revision especifica.
- No elimina PK, indices, estadisticas ni dependencias. Una dependencia no
  prevista puede impedir ALTER COLUMN; en ese caso el motor devuelve el error
  y la transaccion revierte los cambios de esa tabla.
- Una transaccion por tabla contiene sus ALTER COLUMN y ADD CONSTRAINT. Un
  fallo en DDL detiene el lote y revierte esa tabla. Las anteriores ya creadas
  permanecen; el resultado identifica cada estado. La reejecucion las reconoce.
- La prevalidacion consulta los datos actuales sin NOLOCK. No reserva todas
  las tablas hasta la aplicacion; usar una ventana sin escritores concurrentes.
  La propia creacion de la PK vuelve a validar unicidad/nullabilidad.
- Las revisiones de duplicados y el DDL pueden consumir tiempo y bloquear
  en tablas grandes. No se ha ejecutado este paquete contra T3QA.

Referencia de requisitos de PK:
[Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints).

## Cobertura del repositorio

Se encontraron DDL individuales para 65 tablas. Las siguientes 16 no tienen
ese archivo local; no significa que esten ausentes en la base real. El 01
consulta su existencia y tipos directamente en T3QA cuando se ejecuta:

ECV_DOCS_SUM_WEEK, ECV_DOCS_SUM_WEEK_NEW, FACTC_AGR_T3, FACTC_T3,
FACTURA_GENERAL, FACT_AGR_T3, FACT_T3, NOTAC_AGR_T3, NOTAC_T3, NOTA_T3,
PEDC_T3, PED_T3, RMAC_T3, RMAD_T3, RMA_T3, VAN_T3.

## Pruebas locales

`tests_local.py` usa una base temporal exclusiva de LocalDB, los 65 DDL reales
y 16 tablas ficticias para completar los casos sin DDL local. No infiere de
ellas los tipos de produccion. Prueba vista previa, faltantes, NULL, duplicados,
collation, PK existentes, orden compuesto, conservacion de tipos, indices,
reejecucion y rollback de cambios NOT NULL ante un fallo de creacion.

Resultado: 13 casos aprobados; 81 PK verificadas. Evidencia original:
`tmp/CodexPKT3_4e646a00/RESULTADO.txt`. La base temporal fue eliminada.
