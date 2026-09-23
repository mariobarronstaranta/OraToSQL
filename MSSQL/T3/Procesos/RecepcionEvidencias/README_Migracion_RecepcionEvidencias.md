# RecepcionEvidencias para SQL Server

Se conservan `loader.bat`, `truncate_ldr.sql`, `moveInfo.sql`, `control.ctl` y el nombre de entrada `Resultados7_Eleven.csv`. Todos los archivos operativos se resuelven desde la carpeta del BAT, incluso al ejecutarlo desde otra ubicación. No se necesita la ruta `E:\IntegrationToolBox\RecepcionEvidencias`.

El operador ejecuta **loader.bat**. El procesamiento de datos se realiza en SQL Server; `sqlcmd` y `bcp` se ejecutan en el equipo que contiene el CSV. No se utiliza PowerShell, Python, Oracle Client, SQL*Loader, un recurso compartido del servidor ni `xp_cmdshell`. La carpeta `tests` es exclusivamente de desarrollo.

## Antes de ejecutar

1. Configurar la contraseña en la línea `if not defined SQLCMDPASSWORD set "SQLCMDPASSWORD="` de `loader.bat`, después del signo igual. También se admite una variable `SQLCMDPASSWORD` ya definida en la sesión; tiene prioridad. Si la clave contiene `%`, escribir `%%` por cada porcentaje. No agregar comillas alrededor del valor dentro de las comillas existentes de `set`.
2. Confirmar los valores predeterminados: servidor `AZCRNMXNEVTD06`, base `T3QA`, usuario `AT85233588`. Se pueden cambiar en el BAT o mediante `RE_SERVER`, `RE_DATABASE` y `RE_USER`.
3. Mantener el CSV y los cuatro archivos operativos juntos. El proveedor debe terminar de escribir el CSV antes de iniciar la ejecución.
4. Comprobar que `sqlcmd.exe` y `bcp.exe` estén disponibles en `PATH`. Las pruebas se hicieron con el cliente ODBC 18; el formato XML utilizado está soportado por bcp.
5. El usuario necesita acceso a la base, permiso para crear/cargar tablas temporales, `SELECT` y `ALTER`/`INSERT` sobre `EAI.LDR_SHAREPOINT`, `SELECT`/`UPDATE`/`INSERT` sobre `EAI.IFC_FOLIOS_FE`, lectura de `EAI_OWNER.EAI_TRUNC_TABLE` e inserción en `EAI_OWNER.EAI_TRUNC_LOG`. No se crean tablas permanentes ni se despliegan procedimientos automáticamente.
6. La tabla `EAI_OWNER.EAI_TRUNC_TABLE` debe contener `EAI.LDR_SHAREPOINT`. Si falta, el proceso se detiene; no agrega autorizaciones automáticamente.

Para ver los mensajes al finalizar, abrir CMD en esta carpeta y ejecutar `loader.bat`. Éxito devuelve código 0; error devuelve 1. La autenticación Windows mediante `RE_TRUSTED=1` queda disponible para pruebas o una cuenta autorizada para ese modo.

La clave no se imprime en los logs. `sqlcmd` la recibe por variable de entorno; bcp la recibe con su argumento `-P`.

## Certificado del servidor

Si aparece el error de cadena de certificado no confiable, configurar la confianza del certificado en el equipo. Si se autoriza confiar en el certificado presentado, se puede establecer `set "RE_SQL_EXTRA=-C"` en el BAT para sqlcmd. Esa excepción no está activada de forma predeterminada en esta carpeta.

`RE_BCP_EXTRA` permite opciones adicionales del cliente bcp instalado. **No trasladar `-C` de sqlcmd a bcp:** en bcp `-C` indica la página de códigos y ya se utiliza para el CSV. Las opciones de certificado de bcp dependen de la versión del cliente; consultar `bcp -?` antes de configurarlas.

## Funcionamiento

1. Comprueba archivos, herramientas y contraseña; crea `.recepcion_lock` para evitar dos ejecuciones en la misma carpeta.
2. Copia la entrada a un temporal. El CSV original permanece intacto.
3. `truncate_ldr.sql` abre una sesión SQL, obtiene un bloqueo de aplicación para esta carga en la base y crea una tabla temporal global de nombre aleatorio. **Todavía no vacía LDR_SHAREPOINT.**
4. Desde sqlcmd se ejecuta el modo interno de `loader.bat`, que carga cada línea completa mediante bcp y `control.ctl`. El archivo de estado comienza con un error; solo se reemplaza después de terminar la carga sin rechazos. Un fallo bcp no permite ejecutar la actualización.
5. `moveInfo.sql` valida las nueve columnas, la cabecera, longitudes, claves y repeticiones. Omite las líneas vacías y el encabezado.
6. En una sola transacción, limpia y repuebla `EAI.LDR_SHAREPOINT`, registra la limpieza en `EAI_OWNER.EAI_TRUNC_LOG` y aplica los folios a `EAI.IFC_FOLIOS_FE`. Un error revierte esas tres operaciones.
7. Devuelve los contadores, libera los bloqueos y retira los temporales. Si el proceso se interrumpe abruptamente, puede quedar `.recepcion_lock`; comprobar que ya no hay una ejecución activa antes de retirarla.

`control.ctl` conserva su nombre, pero ahora es un formato XML de bcp, no un archivo de control de Oracle. Los SQL contienen directivas de sqlcmd y deben ejecutarse mediante el BAT; no son scripts independientes para ejecutar por partes en SSMS.

## Reglas conservadas y diferencias explícitas

- La relación sigue siendo `FOLIOINTERNO` del CSV con `IFC_FOLIOS_FE.VAR_1`.
- Para un folio existente se actualiza solo `MODIFICACION`; no se reemplaza su `ENTRADA` ni se corrigen duplicados históricos del destino.
- Para un folio nuevo se inserta una fila con `ENTRADA=FOLIORECEPCION`, `CREADOPOR='INTERFACE'` y fecha de creación. Las repeticiones del nuevo folio también dejan informada `MODIFICACION`, como las actualizaciones posteriores del cursor de Oracle.
- Un mismo folio repetido con diferentes recepciones se rechaza para no elegir un valor de forma arbitraria. La muestra incluida no tiene ese conflicto.
- Los contadores mantienen el criterio por registro de entrada: `Actualizaciones = FilasCSV - Insertados`. No necesariamente equivalen al número de filas físicas actualizadas en destino.
- Se utiliza una sola fecha/hora para la aplicación completa. Los identificadores se asignan por orden de folio, no por el orden del CSV. No se exige igualdad de ROW_ID con Oracle.
- El rango de ROW_ID permanece bajo 1000000000. Si la tabla está vacía, comienza en 1; si no hay rango suficiente, falla sin aplicar datos. Se mantiene el tipo de la tabla existente.
- La tabla destino se bloquea para escritura durante la transacción de aplicación para proteger la asignación de identificadores. Puede esperar o bloquear brevemente otros escritores. La espera por bloqueos se limita a 60 segundos; no es un límite del tiempo total del proceso.
- La fecha del CSV permanece como texto; no se convierte el número de fecha de Excel ni se verifican volúmenes porque el proceso original tampoco lo hace.
- El encabezado ya no se guarda en LDR_SHAREPOINT. Con la muestra, se cargan 29 filas de datos, no las 30 líneas reportadas por SQL*Loader.

La lógica de actualización queda en `moveInfo.sql`; no invoca ni modifica el procedimiento compartido `EAI.UPDATE_711_RECEPCION`, cuya versión actual del repositorio puede insertar duplicados. La limpieza y auditoría son explícitas para no heredar los errores silenciados de `EAI.EXECUTE_TRUNCATE`. No requiere `MX_EAI_MESSAGE_LOG`; el diagnóstico de errores queda en los archivos de log.

## Contrato del CSV

Cabecera exacta:

```text
@odata.etag,ItemInternalId,Fecha,Tienda,FolioRecepcion,VolumenTicket,FolioInterno,VolumenNota,CoincideVolumen
```

La codificación predeterminada es UTF-8 (`RE_CODEPAGE=65001`), con BOM opcional, líneas LF o CRLF y última línea con o sin terminador. Para archivos de otro origen, configurar la página de códigos real. Se admite el formato simple de la muestra: nueve campos separados por comas, **sin campos entre comillas ni saltos de línea dentro de un campo**. Los formatos más complejos se rechazan; no se interpretan parcialmente.

Máximo 100 bytes por campo en la tabla de carga y 30 bytes para el folio de recepción del destino. Tienda, folio interno y folio de recepción deben estar informados. No se descarta silenciosamente una fila inválida ni se aplica un archivo vacío.

## Resultados y diagnóstico

- `process.log`: conexión, validaciones, errores SQL y contadores finales.
- `carga.log`: resultado de bcp.
- `RecepcionEvidencias.ready.bad`: filas rechazadas por bcp, si las hay.

Los logs se reemplazan en cada intento que inicia la carga. Guardarlos antes de reintentar si se necesita conservar el diagnóstico. No se produce un CSV de salida ni se mueve el original a un histórico, igual que en el proceso de origen. `RecepcionEvidencias.ready.dsc` ya no se genera.

## Validación

Pruebas aisladas con las definiciones de las cuatro tablas del repositorio, la muestra incluida y variantes inválidas. `tests/verify.py` crea una base LocalDB temporal y la elimina al finalizar. Verifica primera carga, repetición sin duplicados, reversión tras error dentro de la transacción, archivos inválidos, formatos de fin de línea, fallo bcp, autorización de limpieza, concurrencia y codificación.

No se ejecutó la carga en T3QA ni se confirmaron allí los permisos o los objetos. El rendimiento y la interacción con otros procesos deben verificarse en el entorno destino.

Referencias de implementación: [bcp](https://learn.microsoft.com/en-us/sql/tools/bcp/bcp-utility?view=sql-server-ver17), [formatos de carga XML](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/use-a-format-file-to-bulk-import-data-sql-server?view=sql-server-ver17).
