> **2026-11-07: REGISTRO_FISCAL_DETALLE suspendida tras incidente y recovery.** No ejecutar las copias anteriores del lote 17, ni en vista previa. Usar [revision posterior al recovery](17_RFD_REVISION_POST_RECOVERY_20261107/LEEME.md). Los instaladores globales 01/05 ahora rechazan una seleccion que incluya esa tabla. Las pruebas historicas no validan la seguridad operacional a esta escala.

# Claves primarias T3 a partir del listado Oracle

## Paquete corregido vigente para lotes 12-17

Diagnostico 14 recibido el 2026-11-06 01:11:08: las seis tablas tienen indices
dependientes en columnas de PK. Usar los seis archivos de
[15_CORRECCIONES_LOTES_12_AL_17](15_CORRECCIONES_LOTES_12_AL_17/README.md)
en lugar de los lotes originales 12-17. Preservan claves, INCLUDE, filtros,
unicidad y estado deshabilitado de 18 auxiliares en total, dentro de la
transaccion de cada tabla. Pruebas locales de aplicacion, conservacion de
indices, rollback y reejecucion aprobadas. Pendiente aplicacion real del usuario.

## Ajuste de collation del diagnostico 14

Corregido error 468 reportado el 2026-11-06 01:08:11: la comparacion de
sys.columns.name con @Origen.Columna no tenia COLLATE DATABASE_DEFAULT.
Se agrego en esa comparacion y en la declaracion @Tablas.NombrePK.
Las otras comparaciones con nombres de catalogo ya tenian collation explicita.
No cambia collation de datos ni de la base. tests_collation_14.py reproduce
468 con un catalogo simulado (SQL_Latin1_General_CP1_CI_AS frente a
Latin1_General_100_CI_AS_KS_WS_SC) y ejecuta el diagnostico corregido completo
en LocalDB, sin cambios permanentes. Reabrir el archivo 14 y ejecutar completo.

## Bloqueo de ASIGNACION_PAGO (2026-11-06)

Resultado T3QA, captura 01:04:49.600: lote 12 con Aplicar=1, cero NULL y
duplicados, error 4922 en ALTER COLUMN PAGO_ID. ERROR_DDL_REVERTIDO indica
rollback de la tabla, incluido DROP ASPAGO_PK. Objeto bloqueante aun no
identificado por el mensaje. No se infiere el estado de los otros lotes.

Ejecutar `14_DIAGNOSTICAR_LOTES_12_AL_17.sql`, solo catalogos: cubre las
seis tablas restantes y todas sus columnas de PK. Incluye indices, INCLUDE,
filtros, estadisticas, dependencias SQL, calculadas, restricciones, FK y
propiedades extendidas de indices. No escanea los registros de negocio.
Asi se pueden preparar correcciones de dependencias para los lotes restantes
antes de reintentar cada tabla. @SoloTabla permite limitar el reporte, pero
por defecto conviene conservar los seis resultados para evitar mas iteraciones.
Pendiente recibir resultados reales; no se han eliminado dependencias.

## Correccion disponible para PAGO

Diagnostico recibido: PAGO_IDX_1 sobre FECHA_TRN bloquea ALTER COLUMN;
reproducido en LocalDB. Usar `13_CORREGIR_PK_PAGO.sql` en lugar del lote
11_PAGO.sql original. Retira y recrea ese indice dentro de la transaccion
de la PK. Pruebas de exito, rollback y reejecucion aprobadas.
Ver `CORRECCION_PAGO_20261106.md`. Resultado real recibido de T3QA:
aplicacion 2026-11-06 00:58:00.890 a 01:02:37.9572807 -06:00, estado CREADA.
Metadatos finales confirman PAGO_PK activa/unica NONCLUSTERED con PAGO_ID
en posicion 1 y FECHA_TRN en posicion 2, ambas NOT NULL; PAGO_IDX_1 activo
no unico NONCLUSTERED sobre FECHA_TRN. Lote PAGO confirmado, sin eliminacion
de filas reportada. Siguiente archivo en el orden: lote 12_ASIGNACION_PAGO.sql.

## Estado informado y bloqueo de PAGO (2026-11-06)

El usuario confirmo el mensaje de aplicacion terminada de la correccion de
PREVENTA_GENERAL: PREVG_PK reemplazado e IX_PG_C005 recreado.
El lote 11_PAGO.sql fallo con 4922 en ALTER COLUMN FECHA_TRN, despues de
prevalidar cero NULL y duplicados (captura 00:38:41.517; final 00:45:15).
ERROR_DDL_REVERTIDO indica rollback completo de la tabla, incluido el
ALTER de PAGO_ID y DROP de PAGO_PK. No identifica el objeto bloqueante.
Ejecutar `12_DIAGNOSTICAR_DEPENDENCIAS_PAGO.sql`, solo lectura de catalogos,
para revisar estado y dependencias de ambas columnas de la clave.
Pendiente recibir resultados para preparar una correccion especifica;
no asumir que la dependencia de PAGO es igual a la de PREVENTA_GENERAL.

## Correccion disponible para PREVENTA_GENERAL

Diagnostico recibido: IX_PG_C005 incluye FACTURA y bloquea ALTER COLUMN.
Error reproducido en LocalDB. Ejecutar `11_CORREGIR_PK_PREVENTA_GENERAL.sql`
en lugar del lote 10 original, primero con @Aplicar=0. Retira y recrea
IX_PG_C005 en la misma transaccion que la PK; rollback completo probado.
Ver `CORRECCION_PREVENTA_20261106.md`. Pendiente aplicacion real por el usuario.

## Incidencia PREVENTA_GENERAL (2026-11-06)

Lote 10 ejecutado con Aplicar=1 en T3QA, captura 00:26:47.970: paso
prevalidacion con cero NULL y duplicados, pero fallo ALTER COLUMN FACTURA
NOT NULL con error 4922 (dependencias). Resultado ERROR_DDL_REVERTIDO:
el manejador ejecuto rollback antes de reportar, incluido el DROP PREVG_PK.
El mensaje recibido no identifica el objeto dependiente. No se modifico
el instalador para eliminar dependencias sin identificarlas.

Ejecutar `10_DIAGNOSTICAR_DEPENDENCIAS_PREVENTA.sql`: solo metadatos,
estado de columna/indice y dependencias (indices, estadisticas, objetos SQL,
columnas calculadas, checks, defaults y FK). Guardar todos los resultados;
abrir el XML final si las definiciones aparecen truncadas.
Probado en LocalDB con indice, estadistica manual y columna calculada;
base temporal eliminada. Pendiente resultado real para corregir el lote.
Los lotes 01-06 permanecen confirmados; no se infiere el estado de 07-09
ni 11-17 a partir del fallo de 10.

## Validar lotes 01 a 06

El usuario reporto haber ejecutado esos seis lotes. Ejecutar
`09_VALIDAR_LOTES_01_AL_06.sql` en T3QA: solo consulta metadatos de sus
54 tablas, sin escanear datos ni incluir los lotes grandes pendientes.
Esperado: 54 PKCorrectas, cero PorRevisar y nueve correctas por lote.
Valida restriccion PK real, indice activo/unico, columnas/orden y NOT NULL.
Informa nombres diferentes como equivalentes si cumplen las validaciones.
El detalle de diferencias permite identificar casos faltantes/no visibles.

`tests_validacion_09.py` aprobado en LocalDB el 2026-11-06: 54 correctas,
tabla ausente, indice unico sin PK, PK deshabilitada, orden de columnas
incorrecto y PK equivalente con otro nombre. Base temporal eliminada.
Resultado real recibido de AZCRNMXNEVTD06 / T3QA, captura
2026-11-06 00:21:55.9039255 -06:00: 54 PK correctas, cero por revisar,
cero equivalentes con otro nombre. Los seis lotes tienen nueve correctas
cada uno; las 54 filas de detalle son OK, NONCLUSTERED activas, con nombres,
columnas y orden Oracle y cero columnas nullable. Sin filas de diferencias.
Lotes 01-06 confirmados. Lotes 07-17 todavia sin confirmacion de aplicacion;
las tres pendientes por datos y 13 ausentes siguen fuera de este validador.

## Ejecucion por lotes (2026-11-06)

Ya se recibieron los tamanos del 07. El paquete
[08_LOTES_PK_20261106/README.md](08_LOTES_PK_20261106/README.md) contiene
17 instaladores autonomos en orden: cuatro lotes de nueve tablas vacias,
dos de nueve pequenas y once archivos individuales. Cada archivo limita
su inventario antes de escanear datos; no ejecutar el 05 global junto con ellos.
Comenzar por `08_LOTES_PK_20261106/01_VACIAS.sql` con `@Aplicar=0`.
Conservan las tres pendientes fuera del alcance y la transaccion por tabla.

## Instalador vigente para los resultados recibidos

Para dividir la aplicacion por volumen (solicitud del 2026-11-06), ejecutar
`07_ORDENAR_TABLAS_POR_TAMANO.sql` y compartir ambos resultados completos.
Consulta catalogos, sin contar filas directamente ni validar duplicados:
ordena candidatas por MB usados del heap/clustered y filas aproximadas.
Reporta aparte pendientes, ausentes y tablas que ya tienen una PK.
El resultado permitira preparar lotes pequenos y archivos individuales para
las tablas grandes; los tamanos no predicen una duracion exacta.
Compilacion/ejecucion comprobada en LocalDB sin tablas T3 (81 omitidas),
sin cambios permanentes. Pendiente recibir los volumenes reales de T3QA.

Ya se recibio el resultado del 04: 65 tablas con datos validos, 13 ausentes y
tres pendientes (CFDI_CATALOGOS_SAT, MOV_CLIENTE, USUARIOS). Usar ahora
`05_APLICAR_PK_TABLAS_MIGRADAS.sql`, primero con `@Aplicar=0`.
Consultar `GUIA_INSTALADOR_05.md` para aplicacion, alcance y pruebas locales.
`06_REVISAR_TRES_PENDIENTES.sql` permite investigar los datos bloqueados.
Las instrucciones siguientes describen el paquete anterior y su historial.

## Retoma del 2026-11-05

El resultado real recibido se resume en `ANALISIS_RESULTADO_20261105.md`:
68 tablas visibles, 13 ausentes/no visibles; 63 indices equivalentes sin
restriccion PK (dos deshabilitados) y cinco tablas sin clave equivalente.
Antes de aplicar cambios, ejecutar `04_VALIDAR_DATOS_Y_PROPIEDADES.sql` y
revisar sus resultados. Solo consulta datos y metadatos; omite las tablas
ausentes. El 01 conserva su comportamiento original y todavia no resuelve
los indices homonimos ni permite omitir tablas ausentes en la aplicacion.

Prueba del 04: `tests_diagnostico_04.py`, aprobada en LocalDB el 2026-11-05.
Verifico 81 claves, omision de 78 tablas de prueba ausentes, datos validos,
NULL/duplicados, duplicados con indice deshabilitado y ausencia de cambios
en PK, nullabilidad e indices. La base temporal fue eliminada. No se ejecuto
contra T3QA; se requiere el resultado del usuario para preparar el reemplazo.

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
