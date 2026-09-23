# WebOrderTrace para SQL Server

Migración implementada con BAT, `sqlcmd.exe`, `bcp.exe` y T-SQL. No utiliza PowerShell, Python, un recurso compartido ni `xp_cmdshell` durante la operación.

Actualización del 9 de septiembre de 2026: la carpeta principal conserva los siete nombres originales de operación de Oracle. Las utilidades nuevas de instalación/conexión y las definiciones de procedimientos están en `soporte`, separadas de los archivos que utilizan los operadores.

Destino configurado: `AZCRNMXNEVTD06`, base `T3QA`, usuario SQL `AT85233588`. La contraseña no está incluida en ningún archivo de la entrega.

## Estado de entrega

Los scripts fueron compilados y probados en una base LocalDB aislada, con nivel de compatibilidad 160. La instancia de pruebas utiliza motor 17.x; no se ha probado directamente el motor 16.0.4265.3 de destino. No se instalaron objetos ni se reemplazaron datos en `T3QA` durante el desarrollo.

Con los CSV del repositorio se cargaron 2,339 órdenes y 2,257 facturas y se generaron reportes de 195 registros, más encabezado. Esto valida el flujo de archivos y el filtro con la muestra; no certifica los cruces de negocio de T3QA ni equivalencia con una ejecución de Oracle. Los cruces, estados y ventanas se verificaron adicionalmente con datos controlados.

## Archivos

| Archivo | Función |
|---|---|
| `Reporte.Bat` | Punto de entrada original: coordina la carga conjunta y genera los dos reportes. |
| `LoadSFWO_Invoices.Bat` | Etapa original de transferencia de `Invoice.csv`. |
| `LoadSFWO_Orders.Bat` | Etapa original de transferencia de `Order.csv`. |
| `ExtractWebOrder.bat` | Ejecuta las extracciones con los nombres SQL originales. |
| `Header.sql` | Procesa el lote y calcula ambos periodos mediante `WOT_PROCESS`. |
| `Extract.sql` | Extrae el CSV de 35 días del lote. |
| `Extract 370 dias.sql` | Extrae el CSV de 370 días del lote. |
| `soporte/Config.bat` | Valores predeterminados y comprobación de herramientas/credenciales. |
| `soporte/Prevalidar.bat` | Consulta versión, objetos, control y algunos permisos; no modifica datos. |
| `soporte/Instalar.bat` | Instala tablas auxiliares y procedimientos nuevos. No altera las tablas de negocio ni la función de compensación existente. |
| `soporte/Sql.bat`, `soporte/Bcp.bat` | Invocaciones internas de las herramientas SQL. |
| `upload.fmt` | Transporta cada línea física completa, sin separar campos por comas. |
| `soporte/sql/01_Infraestructura.sql` | Control de ejecuciones, tablas por ejecución, limpieza y lector CSV. |
| `soporte/sql/02_Reporte.sql` | Consulta migrada y serialización CSV de 26 columnas. |
| `soporte/sql/03_Procesar.sql` | Validación, mapeo, reemplazo transaccional y generación de resultados. |
| `tests/` | Pruebas exclusivas para una base aislada. No ejecutar en T3QA. |

## Instalación y configuración

1. Copiar la carpeta completa, incluidos `soporte`, los SQL de la raíz y `upload.fmt`, al equipo local. Colocar `Order.csv` e `Invoice.csv` junto a `Reporte.Bat`.
2. Abrir CMD en esa carpeta y definir `SQLCMDPASSWORD` en el entorno de esa sesión mediante el mecanismo de credenciales de la organización. No colocar la contraseña en los BAT ni en archivos versionados. `sqlcmd` lee esa variable; el envoltorio de `bcp` la pasa a su parámetro de autenticación sin imprimirla. No activar trazas de comandos con credenciales.
3. Ejecutar `soporte\Prevalidar.bat` y revisar el destino, objetos y permisos que muestra.
4. Ejecutar `soporte\Instalar.bat` con una cuenta autorizada para crear tablas y procedimientos en `EAI_OWNER`.
5. Realizar primero `Reporte.bat SOLO_REPORTE` para evaluar los datos ya existentes y revisar la salida local.
6. Ejecutar una carga solo en la ventana operativa acordada: `Reporte.bat LOCAL` reemplaza las dos tablas de entrada, aunque no publica el archivo de integración.

Se pueden definir antes de ejecutar: `WOT_SERVER`, `WOT_DATABASE`, `WOT_USER`, `WOT_CODEPAGE` y `WOT_PUBLISH_DIR`. Los valores de `soporte/Config.bat` se aplican solo si no existe un valor en el entorno. La carpeta base se resuelve mediante `%~dp0`.

La codificación predeterminada es UTF-8 (`WOT_CODEPAGE=65001`), tanto para importación como exportación. Si el contrato real es Windows-1252, configurar `WOT_CODEPAGE=1252` y validar los acentos con el consumidor. Se detectan valores que no pueden representarse en las columnas `varchar` destino. La codificación configurada debe coincidir con los archivos de origen.

`WOT_SQL_EXTRA` y `WOT_BCP_EXTRA` permiten opciones adicionales de conexión administradas por el operador. No contienen opciones predeterminadas para desactivar la validación del certificado. `WOT_TRUSTED=1` se reserva para entornos que utilizan autenticación Windows, como las pruebas LocalDB.

### Permisos

La instalación requiere permisos de creación/alteración de procedimientos y tablas en `EAI_OWNER`. La ejecución usa tablas auxiliares con nombres únicos por lote y SQL dinámico: requiere `CREATE TABLE`, los permisos de esquema correspondientes, lectura/escritura de las tablas auxiliares, ejecución de los procedimientos y lectura de las dependencias de negocio. Para reemplazar las entradas se necesitan `DELETE` e `INSERT` sobre `WO_TMP_ORDER` y `WO_TMP_INVOICE`; para publicar se necesita actualizar `EAI.CONTROL_REPORTE`.

Los scripts no conceden roles ni permisos automáticamente. La cuenta que ejecuta `bcp` también debe poder insertar en las tablas auxiliares creadas por esa ejecución. Un administrador debe verificar los permisos efectivos. No basta con que los diez objetos originales existan.

## Modos de ejecución

```bat
Reporte.bat SOLO_REPORTE
Reporte.bat LOCAL
Reporte.bat PUBLICAR
```

| Modo | Reemplaza órdenes/facturas | Genera 35 y 370 días | Publica integración |
|---|---|---|---|
| `SOLO_REPORTE` | No; usa las tablas existentes | Sí | No |
| `LOCAL` (predeterminado) | Sí, desde los dos CSV | Sí | No |
| `PUBLICAR` | Sí, desde los dos CSV | Sí | Sí, solo 35 días |

`SOLO_REPORTE` crea y limpia datos auxiliares de ejecución; no es una consulta sin escrituras en toda la base. No actualiza el control de publicación.

Dentro de `Reporte.Bat`, las llamadas conservan el orden original: `LoadSFWO_Invoices.Bat`, `LoadSFWO_Orders.Bat` y `ExtractWebOrder.bat`. `Header.sql` realiza la validación y el reemplazo conjunto entre la transferencia y la extracción. Al invocar directamente cualquiera de los dos BAT de carga, se ejecuta el flujo `LOCAL` completo con ambos CSV para conservar la atomicidad; no se reemplaza una sola tabla de forma independiente. `ExtractWebOrder.bat` invocado directamente equivale a `SOLO_REPORTE`.

Los archivos SQL de la raíz son scripts operativos reales. Reciben variables `sqlcmd` (`RunId` y, en `Header.sql`, `Load`); normalmente los invocan los BAT. Las definiciones de los procedimientos permanecen en `soporte/sql` y se instalan una sola vez. La exportación ejecuta `Extract.sql` y `Extract 370 dias.sql` mediante `sqlcmd`, con el CSV ya serializado y sin encabezados adicionales de la herramienta.

La asignación de 35 días a `PREVENTA_CANCELADA.csv` y de 370 días a un archivo separado es el criterio inicial comunicado al usuario. Debe confirmarse con el consumidor antes de la primera publicación operativa.

### Salidas

- `WebOrder_YYMMDD_HHMM.CSV`: periodo de 35 días.
- `WebOrder_370dias_YYMMDD_HHMM.CSV`: periodo de 370 días.
- `Processed`: copia histórica de ambos reportes.
- `Logs/<RunId>.log`: carga, consulta y exportación.
- En modo `PUBLICAR`: `E:\IntegrationToolBox\UploadSharePoint\PREVENTA_CANCELADA.csv`, en el equipo local.

La entrega se copia primero con nombre temporal en la carpeta destino y después se renombra. Se actualiza `AUTO-NOT DELIVERED` solo después de la copia final. La operación de archivos y la transacción SQL no constituyen una transacción distribuida: si falla el control después de copiar, el archivo puede estar publicado y el log señalará el error.

No se eliminan reportes anteriores ni archivos de entrada. Se rechaza una ejecución si ya existe el reporte de 35 días con el mismo minuto, para evitar una sobrescritura local accidental. La fecha del nombre se obtiene del servidor SQL.

## Carga y compatibilidad

`bcp` transfiere líneas completas a tablas exclusivas del lote, numeradas por identidad. El texto se reconstruye en SQL y un lector CSV interpreta campos delimitados, comillas escapadas, CRLF/LF, campos vacíos y saltos de línea dentro de comillas. Se agrega un salto final a una copia local para admitir CSV sin salto al final; nunca se modifica el archivo original.

Se validan encabezados, 13 columnas para órdenes, 15 para facturas, filas de datos, identificadores y tamaños. Los importes deben caber en `decimal(15,2)`, utilizar punto decimal y no llevar separador de miles ni precisión adicional. No se aceptan cargas vacías ni texto reconstruido mayor a 100 MB por archivo.

Los encabezados no se insertan. Se almacena cada valor con comillas canónicas, conservando comparaciones como `Delivery_Status__c = '"Unsuccessful"'`. El nombre del creador se asigna a `CREATEDBY_NAME`, su identificador a `CREATEDBYID`; `CREATEDBY` queda nulo al no existir esa columna en los CSV. Se informa `INSERT_TS` explícitamente en facturas.

Después de validar ambos archivos se reemplazan las dos tablas en una transacción, usando bloqueos de tabla y un bloqueo de aplicación entre ejecuciones WebOrderTrace. Ambos reportes se calculan antes del commit, con el mismo instante de referencia. Si falla la carga o una consulta, se revierte el reemplazo y no queda un reporte parcial del lote.

Los procesos EOD activos no usan necesariamente el mismo bloqueo de aplicación. Los lectores normales pueden esperar mientras se reemplazan los datos; consumidores con lecturas sucias pueden observar estados transitorios. Es necesario acordar la ventana operativa. No se modificaron esos procedimientos.

Los reportes conservan los cruces y agrupaciones del original, excluyendo únicamente el cálculo de `Importe` agregado que no se utiliza en la salida. El CSV se escapa explícitamente y el encabezado tiene posición garantizada. Las comparaciones de identificadores siguen la intercalación de la base; el filtro `Unsuccessful` utiliza comparación binaria para respetar el valor exacto. La función `GET_CLEARING_STATUS` existente se reutiliza sin modificarla.

## Fallos y recuperación

Cada ejecución usa un GUID y tablas `EAI_OWNER.WOT_O_<GUIDsinGuiones>` / `WOT_I_<GUIDsinGuiones>`. Los resultados se guardan en `WOT_OUTPUT` por lote y periodo. `WOT_RUN` conserva el resumen de ejecución incluso después de limpiar los datos auxiliares.

Si una etapa falla, el BAT devuelve un código distinto de cero y conserva `.wot_lock`, el log, las copias de entrada y los objetos auxiliares para revisión. No vuelve a cargar ni publica automáticamente. No deben borrarse esos recursos mientras exista una ejecución activa.

Consultar el GUID en `.wot_lock/run.txt` y revisar `WOT_RUN.State`:

- `CREATED`: la validación o el procesamiento no terminó; el reemplazo no se confirmó.
- `READY`: carga y reportes confirmados. Un fallo posterior de exportación/copia no revierte la carga. Los resultados pueden recuperarse desde `WOT_OUTPUT` sin repetir la carga.
- `EXPORTED`: se completó el flujo solicitado y se limpiaron resultados auxiliares; el modo `LOCAL` también usa este estado y no implica publicación externa.
- `CLEANED`: se limpiaron recursos de una ejecución que no estaba lista.

Para exportar un resultado pendiente, usar `bcp queryout` con `SELECT CsvLine FROM EAI_OWNER.WOT_OUTPUT WHERE RunId='<GUID>' AND Days=35 ORDER BY Seq` (o 370), desde la misma configuración de conexión. Revisar el archivo antes de entregarlo.

Cuando ya no se necesiten los datos del lote, ejecutar `EXEC EAI_OWNER.WOT_CLEANUP @RunId='<GUID>';` en la base correcta. El procedimiento elimina exclusivamente las tablas auxiliares y resultados de ese GUID, no las tablas de negocio. Después, retirar manualmente `.wot_lock` de esa carpeta, previa comprobación de que no haya ejecución activa. Conservar `Logs`.

## Pruebas realizadas

- Compilación de los procedimientos sobre copias del DDL del repositorio, compatibilidad 160.
- CSV con BOM, comas, comillas escapadas, CRLF/LF y campos multilínea.
- Rechazo de comillas sin cerrar e importes inválidos antes de cambiar el destino.
- Mapeo del creador y almacenamiento compatible con los consumidores EOD.
- Documentos recientes y de más de 35 días, estados de procesamiento y compensación.
- Error inyectado después de iniciar el reemplazo: reversión de ambas tablas comprobada.
- BAT y bcp completos con los CSV reales de muestra: 2,339 órdenes, 2,257 facturas.
- Exportación y publicación en carpeta de pruebas: 195 registros, 26 columnas y preservación de coma/CRLF dentro de un campo.
- Revalidación del 9 de septiembre de 2026: coincidencia exacta de los siete nombres operativos con Oracle; carga mediante los BAT originales y extracción mediante `Header.sql`, `Extract.sql` y `Extract 370 dias.sql`; publicación local de prueba con 195 registros, 26 columnas y campo multilínea intacto.

Pendiente en destino: permisos efectivos, rendimiento con datos de T3QA, intercalación, codificación aceptada por el consumidor, ruta local de publicación y coordinación con EOD. No hay acceso a Oracle para comparar ejecuciones paralelas.
