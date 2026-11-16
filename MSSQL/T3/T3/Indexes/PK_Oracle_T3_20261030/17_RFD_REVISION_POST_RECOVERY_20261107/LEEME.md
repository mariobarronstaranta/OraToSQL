# REGISTRO_FISCAL_DETALLE: revision posterior al incidente

Fecha: 2026-11-07. Base objetivo: T3QA. **No ejecutar nuevamente el lote 17 anterior**, ni siquiera en vista previa: esa vista tambien lee datos completos. Las copias externas no quedan bloqueadas al cambiar este repositorio.

## Que ejecutar ahora

1. En una conexion nueva de SSMS, ejecutar completo `01_ESTADO_Y_CAPACIDADES.sql`. Guardar todos los resultados y mensajes.
2. Ejecutar `02_RECURSOS_Y_LOG.sql`. Si una seccion informa falta de permisos, conservar el mensaje y solicitar ese resultado al administrador; no modificar permisos ni configuracion para obtenerlo.
3. Entregar ambos resultados. Adjuntar hora aproximada de inicio, desconexion y reinicio, y los mensajes de SQL Server ERRORLOG y eventos de Windows alrededor del incidente. El ERRORLOG anterior al reinicio puede estar archivado. Revisar memoria, almacenamiento, errores de E/S y crecimiento/falta de espacio del log. No asumir la causa a partir de 10054.

Estos archivos consultan catalogos y vistas de estado; no cuentan filas de la tabla, no buscan duplicados, no ejecutan ALTER/DROP/CREATE y no cambian la base. Pueden requerir bloqueos breves o permisos: LOCK_TIMEOUT de 5 segundos limita la espera de bloqueos, no su tiempo total. Usar una conexion nueva y cerrarla al terminar, especialmente si se cancela una consulta. Metadatos incompletos por permisos no prueban ausencia de objetos.

## Resultado de revisar el script anterior

El lote corregido 17 validaba nulos y duplicados mediante lecturas de datos. Al aplicar, realizaba otra cuenta con TABLOCKX/HOLDLOCK y, dentro de una unica transaccion:

- Eliminaba IDX_FACTURA_MATERIAL, IX_REGISTRO_FISCAL_DETALLE_FACTURA_MATERIAL e IX_Ventas_RFD_Factura.
- Eliminaba el indice unico REGFEDDET_PK.
- Cambiaba FACTURA y NUM_LINEA a NOT NULL.
- Creaba la PK no agrupada y reconstruia los tres indices auxiliares.

La clave Oracle esperada es **(FACTURA, NUM_LINEA)**. La captura previa indicaba FACTURA varchar(30) y NUM_LINEA decimal(4,0), ambas nullable; necesitamos comprobar el estado actual.

Con 489,144,440 filas, aproximadamente 97 GiB de datos y 148 GiB de indices reportados, agrupar esas operaciones deja una transaccion extensa, bloqueos y mucha escritura pendiente de confirmar o deshacer. Las pruebas funcionales anteriores con tablas pequenas no validaron esta carga operacional. No deben usarse como evidencia de seguridad para esta tabla.

10054 significa perdida de conexion. No identifica por si solo memoria insuficiente, disco lleno, fallo del motor o causa de red. Tras un reinicio, recovery puede rehacer y deshacer transacciones; el tiempo observado es compatible con mucho trabajo pendiente, pero no demuestra la causa ni el resultado final de cada DDL. Una desconexion tampoco prueba que la transaccion no alcanzara a confirmar.

## Decision segun los resultados

| Estado comprobado | Siguiente paso |
| --- | --- |
| Ya existe PK activa correcta y columnas NOT NULL | No repetir la creacion; verificar tambien indices auxiliares. |
| Existe indice UNIQUE activo, sin filtro, sobre las columnas esperadas | Conservarlo durante la evaluacion. Ya impone unicidad, aunque no sustituye una PK ni garantiza NOT NULL. |
| Hay operaciones reanudables pendientes | Evaluar estado y espacio antes de cualquier RESUME/ABORT; estos diagnosticos no cambian su estado. |
| Una o ambas columnas siguen nullable | No generar otro ALTER masivo. Resolver este paso primero en una copia restaurada de tamano representativo. |
| Ambas columnas ya NOT NULL y version/edicion compatibles | Evaluar PK ONLINE y RESUMABLE, con MAXDOP bajo, ventanas de trabajo acotadas y espera de bloqueo de baja prioridad que aborte la propia operacion. |
| No hay capacidad o no existe una ruta compatible | Posponer la PK o disenar una migracion a tabla nueva con espacio, sincronizacion y cambio final probados. No eliminar la proteccion UNIQUE para empezar. |

SQL Server 2022 o posterior permite ADD CONSTRAINT reanudable para PK/UNIQUE; tambien se requiere soporte de ONLINE en la edicion y cumplir sus restricciones. No se adjunta DDL de aplicacion hasta conocer estos resultados. La reconstruccion reanudable de un indice existente no lo convierte en PK.

Una creacion reanudable evita una gran transaccion explicita y puede pausarse, pero sigue consumiendo CPU, E/S, espacio y recursos mientras avanza. MAX_DURATION pausa la construccion; no garantiza desconexion o liberacion de todos los recursos a un segundo exacto. Una operacion pausada conserva estructuras y puede afectar escrituras. MAXDOP=1 reduce paralelismo, no limita todo el consumo. ONLINE tambien necesita bloqueos en determinadas fases.

Cambiar columnas a NOT NULL **no se vuelve reanudable por usar una PK reanudable**. ALTER COLUMN tiene dependencias con indices y no ofrece la misma opcion RESUMABLE. Dividir archivos por operaciones tampoco divide un ALTER o una creacion de PK en lotes de filas. Dejar indices eliminados entre pasos puede perjudicar consultas: no es una solucion automatica.

Antes de autorizar un nuevo DDL: investigar la caida, medir espacio libre en datos/log/tempdb y volumenes, confirmar backups y una restauracion probada en otro entorno, y ensayar la ruta sobre una copia de tamano representativo. Definir con el administrador limites de espacio, log, bloqueo y latencia, supervision y procedimiento de pausa compatible. No se puede prometer riesgo cero ni un recovery corto. No cambiar recovery model, reducir archivos ni reiniciar el servicio como medida de control de carga.

## Fuentes de Microsoft

- [Restricciones de tabla reanudables](https://learn.microsoft.com/en-us/sql/relational-databases/security/resumable-add-table-constraints?view=sql-server-ver16).
- [Restricciones y recursos de operaciones ONLINE](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/guidelines-for-online-index-operations?view=sql-server-ver16).
- [ALTER TABLE y ALTER COLUMN](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql?view=sql-server-ver16).
- [Log de transacciones y recovery](https://learn.microsoft.com/en-us/sql/relational-databases/logs/the-transaction-log-sql-server?view=sql-server-ver16).
