# Resultado recibido el 2026-11-05: PK T3

Origen: salida de 03_REVISAR_INDICES_EXISTENTES.sql proporcionada por el usuario.
Servidor AZCRNMXNEVTD06, base T3QA. Captura declarada: 2026-11-05 23:43:11.920.
Alcance: las 81 claves del listado Oracle; no es un inventario de toda la base.

| Clasificacion por tabla | Cantidad |
|---|---:|
| Indice unico activo, nombre/columnas/orden iguales a Oracle; no es PK | 61 |
| Indice unico equivalente deshabilitado; no es PK | 2 |
| Tabla presente sin indices | 4 |
| Tabla presente con otros indices, sin clave equivalente | 1 |
| Tabla ausente o no visible | 13 |
| Total | 81 |

Hay 68 tablas visibles y ninguna PK declarada en este alcance.
Los 63 indices equivalentes son NONCLUSTERED, sin filtro, sin restriccion UNIQUE
y sin FK referenciandolos segun los metadatos recibidos. Todos tienen columnas
de clave declaradas NULL. Esto NO demuestra que existan filas con valores NULL.

Los indices deshabilitados son CLIENTE.CLIENTE_PK y USUARIOS.USUARIO_PK.
Su definicion unica no garantiza la unicidad de los datos actuales.
Las cuatro tablas sin indices son CREDITO_EXPRESS, FACT_T3, FACTD_AGR_T3 y NOTA_T3.
MOV_CLIENTE tiene indices sobre CLIENTE_SAP, pero la clave Oracle requiere CLIENTE_V3.

## Tablas ausentes o no visibles

ECV_DOCS_SUM_WEEK, ECV_DOCS_SUM_WEEK_NEW, FACT_AGR_T3, FACTC_AGR_T3, FACTC_T3, NOTAC_AGR_T3, NOTAC_T3, PED_T3, PEDC_T3, RMA_T3, RMAC_T3, RMAD_T3, VAN_T3.

No crear estas tablas para completar el listado. La futura aplicacion debe
omitirlas y reportarlas; revisar permisos si su ausencia resulta inesperada.

## Siguiente paso

Ejecutar 04_VALIDAR_DATOS_Y_PROPIEDADES.sql completo en T3QA y conservar sus
resultados. Es solo lectura: revisa NULL y duplicados con la collation real,
incluidos los indices deshabilitados. Tambien obtiene INCLUDE, compresion,
filegroup/particionado y opciones no presentes en el reporte anterior.
DATOS_VALIDOS no significa que el DDL ya pueda aplicarse.

Con esos datos se prepara el reemplazo transaccional de los indices compatibles
por restricciones PK, conservando nombre y orden Oracle, y se crean las cinco
claves faltantes cuando los datos lo permitan. Las columnas deben pasar a
NOT NULL. Un fallo debe revertir tanto el indice como la nullabilidad por tabla.
No renombrar ni eliminar indices indiscriminadamente.

El instalador 01 anterior sigue bloqueando indices homonimos y tablas ausentes;
no se ha modificado ni debe usarse aun para resolver estos casos.
No se ejecuto ningun cambio en T3QA desde esta sesion.
