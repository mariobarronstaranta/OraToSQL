# Inventario de indices de T3QA

Ejecutar `T3QA_INVENTARIO_INDICES.sql` completo en SSMS con T3QA seleccionada.
No requiere activar el plan real. Para todas las tablas, dejar @Esquema y
@Objeto en NULL. Tambien incluye vistas indexadas y tablas heap visibles.
Los objetos de sistema se excluyen.

El script consulta catalogos y DMV, y usa tablas temporales de sesion. No cambia
tablas/indices de negocio, no calcula fragmentacion ni actualiza estadisticas.
Esta preparado para SQL Server 2022, la version reportada por T3QA.

## Resultados

| Seccion | Contenido |
|---|---|
| 01_CONTEXTO | Servidor, base, collation, fecha, version y alcance de visibilidad. |
| 02_INVENTARIO | Una fila por indice/heap: tabla o vista, claves ASC/DESC, INCLUDE, unicidad, PK/UNIQUE, filtro, estado, fill factor, bloqueos, espacio, filas, estadisticas y uso. |
| 03_COLUMNAS | Campos por indice: orden, tipo de dato, longitud en bytes, precision/escala, nulos, collation, columna calculada, particion y orden columnstore. |
| 04_PARTICIONES | Filas aproximadas, compresion y ubicacion por particion. |
| 05_ESTADISTICAS | Fechas, muestreo y modificaciones de estadisticas, incluidas las que no tienen indice asociado. |
| 06_INICIO_INSTANCIA | Contexto para interpretar los contadores acumulados de uso. |
| 07_TRACE_ORIGEN / 07_EVENTOS_INDICE | Evidencia historica opcional de creacion, alteracion y eliminacion conservada en archivos del default trace. |
| 08_AVISOS | Limitaciones de fechas/visibilidad/uso y errores de permisos en las secciones opcionales. |

En SSMS puede usarse Resultados a archivo (Ctrl+Shift+F) antes de ejecutar para
guardar todos los conjuntos. Las listas y definiciones largas pueden truncarse
segun las opciones de salida del cliente: conservar tambien 03_COLUMNAS, que
entrega una fila por columna. Las filas no son recomendaciones para eliminar
o crear indices automaticamente.

## Fechas: que se puede conocer

SQL Server no mantiene create_date/modify_date individuales en sys.indexes.
Por eso FechaCreacionIndiceNoDisponible y FechaModificacionIndiceNoDisponible
son NULL; no se reemplazan por fechas que representen otra cosa.

- FechaCreacionTablaOVista y FechaModificacionTablaOVista pertenecen al objeto.
  La ultima tambien puede cambiar al crear/alterar uno de sus indices; no
  identifica cual indice ni todas las modificaciones anteriores.
- FechaCreacionRestriccion y FechaModificacionRestriccion pertenecen a una PK
  o UNIQUE si la hay. Un indice unico independiente no es necesariamente una
  restriccion y no tendra esas fechas.
- FechaActualizacionEstadistica informa de estadisticas, no de cambios de
  definicion del indice ni de sus datos.
- FechaEventoRegistrada es evidencia del trace, con su evento y fase
  Begin/Commit/Rollback. Un evento Begin no acredita una operacion completada.
  Se entregan los identificadores originales sin atribuir una fecha a un indice
  actual solo por coincidencia de nombre. Los nombres e IDs pueden reutilizarse.

El trace puede estar deshabilitado, no ser visible o no conservar ya los eventos.
Se lee desde el archivo actual informado por sys.traces y los rollover
posteriores que encuentre la funcion; no se garantiza recorrer archivos mas
antiguos. La ausencia de eventos no demuestra ausencia de cambios. Puede
omitirse esta seccion con @LeerTrace=0. No se habilita ni configura ningun trace.
Para un historial completo futuro se necesita captura persistente de DDL
(por ejemplo, una sesion de Extended Events o auditoria), fuera del alcance de
este inventario. No permite reconstruir retrospectivamente eventos perdidos.

## Permisos e interpretacion

Para ver todos los objetos y definiciones se necesita visibilidad de metadatos
de toda T3QA, normalmente VIEW DEFINITION. Las DMV de uso/tamano requieren los
permisos de estado/rendimiento correspondientes a SQL Server 2022; consultar
08_AVISOS si una seccion no esta disponible. Leer el trace requiere ALTER TRACE.
El script no concede permisos ni exige sysadmin como unica alternativa.

NULL en uso/tamano/estadisticas significa desconocido, sin registro o no visible;
no debe interpretarse automaticamente como cero. user_updates cuenta operaciones,
no filas. Los contadores corresponden a todos los procesos y pueden reiniciarse
por distintas causas ademas del arranque. No eliminar indices por pocos seeks.

Las claves clustered pueden formar parte implicita de indices no clustered sin
aparecer como INCLUDE declarado. En columnstore, XML, spatial o memoria optimizada,
algunas propiedades/metricas requieren vistas especializadas adicionales. Los
datos de particiones de disco no miden memoria de tablas optimizadas para memoria.

El alcance de tablas/campos indica donde esta definido un indice. Para determinar
que consultas o procedimientos lo utilizan se necesitan sus planes o Query Store.

## Validacion

Se ejecuto el inventario en una base temporal LocalDB con collation
Latin1_General_100_CI_AS_KS_WS_SC, distinta de la de la instancia, usando una
PK, un indice filtrado con INCLUDE y clave descendente, un indice deshabilitado,
una columna calculada persistida y un heap. Se verifico la presencia de indices,
columnas, particiones y estadisticas en la salida. La base temporal se elimino.
No se ejecuto contra T3QA desde el agente. La rama de lectura de archivos de
trace no se valido con eventos historicos reales y requiere validacion en la
instancia destino.

Referencias:

- [sys.indexes](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-indexes-transact-sql).
- [sys.objects y fechas del objeto](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-objects-transact-sql).
- [Object:Created y eventos de DDL](https://learn.microsoft.com/en-us/sql/relational-databases/event-classes/object-created-event-class).
- [fn_trace_gettable, permisos y archivos rollover](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-trace-gettable-transact-sql).
