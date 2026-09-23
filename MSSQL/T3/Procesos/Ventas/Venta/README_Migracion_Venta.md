# Venta: flujo de loader.bat para SQL Server

Se migró únicamente el flujo iniciado por `loader.bat`. Se conservan `loader.bat`, `truncate_ldr.sql`, `control.ctl` y `moveDailyInfo.sql`. No se migraron ni se invocan el comparativo, `calculaCControl.sql` o el envío FTP.

Las rutas se resuelven desde la carpeta del BAT, aunque se ejecute desde otra ubicación. No se utiliza `E:\IntegrationToolBox\Venta`, PowerShell, Oracle Client, SQL*Loader ni `xp_cmdshell`. Se requieren `sqlcmd.exe` y `bcp.exe` en el equipo del operador. El servidor no necesita acceder al disco de ese equipo.

## Preparación e instalación

1. Instalar en **T3QA** el archivo `CC_SALESDOC_LDR_TO_CIFRAS.SQL` incluido en esta carpeta. Es una copia del procedimiento revisado en `MSSQL/T3/EAI/Procedures`, con el mismo nombre y lógica de carga parcial. Ejecutarlo crea o actualiza el procedimiento; no procesa ventas. El BAT no instala objetos automáticamente.
2. Confirmar las dependencias de ese procedimiento: las tablas de carga/destino, preventa/factura, controles, logs, la secuencia `EAI_OWNER.ProcessID` y `EAI_OWNER.LOG_START`. Los triggers de destino también deben tener disponibles sus dependencias. La versión antigua incompleta del procedimiento se rechaza mediante un marcador de versión dentro de su definición.
3. Confirmar que `EAI_OWNER.EAI_TRUNC_TABLE` contiene `EAI.TAO_SALES_DOCS_LDR`. La migración mantiene esta autorización y la auditoría en `EAI_OWNER.EAI_TRUNC_LOG`; no agrega autorizaciones automáticamente.
4. Colocar el archivo diario `factura.ready.doc` junto al BAT. Es texto separado por comas, no un documento Word. No se copió automáticamente el archivo histórico de Oracle al directorio operativo nuevo.
5. Completar la clave en `if not defined SQLCMDPASSWORD set "SQLCMDPASSWORD="`. Una variable del mismo nombre ya definida en la sesión tiene prioridad. Dentro del BAT escribir `%%` por cada signo de porcentaje de la clave.
6. Revisar los valores predeterminados: `AZCRNMXNEVTD06`, `T3QA`, `AT85233588`. Se pueden cambiar mediante `VENTA_SERVER`, `VENTA_DATABASE` y `VENTA_USER`.

La cuenta necesita ejecutar el procedimiento y acceder a sus dependencias conforme a los permisos/cadena de propiedad del entorno. Para las sentencias directas del flujo necesita lectura/visibilidad de metadatos, `VIEW DEFINITION` del procedimiento, `ALTER` e `INSERT` sobre `EAI.TAO_SALES_DOCS_LDR`, `UPDATE` del estado de `EAI.T3R_SALES_DOCS_OLD`, lectura de `EAI_TRUNC_TABLE`, inserción en `EAI_TRUNC_LOG` y uso de tablas temporales. Los permisos deben ser revisados por el administrador; este paquete no concede permisos.

### Conexión y certificado

La contraseña no se imprime en los logs. `sqlcmd` la obtiene de `SQLCMDPASSWORD`; bcp la recibe mediante su argumento `-P`. `VENTA_TRUSTED=1` permite autenticación Windows para una cuenta autorizada, como en las pruebas LocalDB.

Si la cadena del certificado de SQL Server no es confiable, debe configurarse su confianza en el equipo. Si se autoriza omitir esa validación para sqlcmd, agregar `set "VENTA_SQL_EXTRA=-C"` en el BAT. No se activa por defecto. `VENTA_BCP_EXTRA` permite opciones del cliente bcp instalado: **no copiar `-C` de sqlcmd a bcp**, donde esa opción indica la página de códigos. Consultar `bcp -?` para las opciones de conexión de la versión instalada.

## Operación del soporte

Abrir CMD y ejecutar `loader.bat`. Esperar el resultado y revisar `moveDailyInfo.log` antes de reintentar. El proveedor debe haber terminado de escribir el archivo antes del inicio de la carga.

| Código del BAT | Resultado | Respaldo |
|---|---|---|
| 0 | Completo, sin documentos rechazados | `processed` |
| 2 | Parcial: documentos válidos confirmados, otros rechazados | `processed\parcial` |
| 1 | Error de conexión, validación o ejecución | `processed\error`, si fue posible iniciar el respaldo |
| 3 | No se pudo terminar el respaldo | Se conserva `.venta_loader_lock` para recuperación |

La existencia de una carpeta `.venta_loader_lock` impide iniciar otra ejecución local. Si quedó por una interrupción o por fallo de respaldo, comprobar primero que no haya un proceso activo y recuperar los archivos antes de retirarla manualmente.

Los códigos del BAT son diferentes de los del procedimiento: el procedimiento devuelve 1 para una carga parcial; el BAT lo traduce a 2. Un error general puede ocurrir después de confirmar algunos documentos: **código 1 no significa que no se haya escrito nada**. No repetir automáticamente sin revisar la bitácora y los documentos involucrados.

## Orden de ejecución

```text
loader.bat
  1. Comprueba requisitos, bloquea la carpeta y copia el archivo de entrada.
  2. sqlcmd ejecuta truncate_ldr.sql:
       - valida dependencias y versión del procedimiento;
       - obtiene un bloqueo SQL que protege todo este flujo;
       - crea una tabla temporal global para recibir las líneas del archivo;
       - solicita al propio loader.bat la carga interna mediante bcp/control.ctl;
       - incluye moveDailyInfo.sql en la misma sesión.
  3. moveDailyInfo.sql:
       - valida completamente el archivo antes de vaciar la tabla de carga;
       - limpia y carga EAI.TAO_SALES_DOCS_LDR, con autorización y auditoría;
       - marca DOC_STATUS='D' para todo CUSTOMER=53545044;
       - confirma esas operaciones juntas;
       - ejecuta EAI.CC_SALESDOC_LDR_TO_CIFRAS, fuera de una transacción externa;
       - comunica resultado completo o parcial al BAT.
  4. loader.bat respalda el archivo exacto y ambos logs; libera temporales.
```

El nombre `truncate_ldr.sql` permanece, pero ahora la limpieza se difiere hasta terminar la validación. La tabla global tiene un nombre distinto por ejecución y desaparece al cerrar la sesión. `control.ctl` ahora contiene un formato XML de bcp que lee líneas completas; SQL valida y separa las 13 columnas.

Los SQL utilizan directivas de sqlcmd y no deben ejecutarse por partes en SSMS. La excepción es `CC_SALESDOC_LDR_TO_CIFRAS.SQL`, que es el script de instalación independiente.

## Contrato de entrada

El archivo conserva sus **13 campos, en este orden, sin encabezado**:

```text
DOC_ORD_R3,DOC_NUM_R3,CUSTOMER_NUMBER,DISTRIBUTOR,CUSTOMER,DOC_DATE,DOC_TYPE,DOC_NUM_REF1,DOC_NUM_REF2,DOC_STATUS,DOC_NETAMT,DOC_TAXAMT,DOC_QTY
```

La línea anterior describe el orden; no debe agregarse al archivo.

- Fecha `YYYYMMDD`, como el original; no es un parámetro `YYYY-MM-DD` de los reportes Extract.
- Importes con punto decimal y hasta dos decimales significativos; cantidades con hasta tres. Se conservan los rangos de las máscaras Oracle y las conversiones de la tabla de carga.
- Codificación predeterminada ISO-8859-1 (`VENTA_CODEPAGE=28591`), conforme a `NLS_LANG` del BAT original. Si el proveedor entrega UTF-8, configurar `65001`.
- Se admiten LF y CRLF y última línea sin terminador. Se ignoran líneas vacías. Se recortan los espacios exteriores de los campos y los vacíos se convierten en NULL.
- No se admiten campos entre comillas ni comas/saltos de línea dentro de un campo. El formato actual de la muestra no los utiliza.
- Se validan longitudes, documento informado, fechas, número de cliente SAP, importes y cantidades antes de modificar tablas. `CUSTOMER` permanece texto en la carga; un valor incompatible con el destino numérico se registra como rechazo por el procedimiento.

Un archivo estructuralmente incorrecto se rechaza completo, a diferencia de SQL*Loader, que podía cargar filas válidas y omitir otras. La **carga parcial por documento** sí se mantiene en el procedimiento, conforme a la decisión del cliente.

## Reglas y respaldo

Se conserva expresamente la actualización masiva del cliente `53545044` a estado D, sin filtro por fecha ni por el archivo actual. Se conserva el procesamiento comercial, producción y otros del procedimiento revisado. El BAT pasa `@pTruncate='N'`: nunca solicita vaciar las tablas finales de cifras.

La limpieza/carga de la tabla intermedia, su auditoría y la regla del cliente forman una transacción. Después se ejecuta el procedimiento con confirmaciones por documento. No existe una transacción que revierta el flujo completo; los registros válidos de una carga parcial permanecen.

El bloqueo SQL usa el mismo recurso que el procedimiento, por lo que también coordina ejecuciones directas de esa versión. No protege contra escritores ajenos que no respeten ese recurso. La espera por bloqueos se limita a 60 segundos; no es el tiempo máximo total del proceso.

Se conservan el archivo original y estos resultados:

- `process.log`: diagnóstico de bcp.
- `moveDailyInfo.log`: validación, SQL, PID, contadores y errores.
- `factura.ready.bad`: rechazos de bcp, si se generan. Los rechazos SQL estructurales se describen en el log; los del procedimiento quedan en `EAI.ERROR_TABLE`.
- Histórico: `factura.processed.AAAAMMDD.HHMMSS_<identificador>.doc`, `factura.log.<mismo sufijo>.txt` y `moveDailyInfo.<mismo sufijo>.log`. La fecha/hora viene de SQL Server, sin depender del formato regional de Windows. El identificador distingue ejecuciones del mismo segundo.

Se archiva la copia exacta que se tomó antes de cargar, incluso si el proveedor después reemplaza el original. Los intentos parciales y fallidos se separan del histórico de éxito. El CSV original nunca se elimina ni se mueve. Si falla la conexión antes de obtener fecha, el respaldo usa el prefijo `sin_fecha` y el identificador del intento.

## Pruebas

`tests/verify.py` crea una base LocalDB temporal con los DDL del repositorio, instala el procedimiento y el trigger de auditoría y ejecuta el BAT real. Python se utiliza únicamente para las pruebas, no para operar este flujo.

Se verifican rutas con espacios, ejecución desde otro directorio, respaldo exacto y sin sobrescritura, caracteres ISO-8859-1, reglas del cliente, repetición, archivos inválidos, carga parcial, rechazo de la versión incompleta y reversión de errores previos al procedimiento. Incluye la muestra histórica de 8,191 filas de `ORA/T3/Procesos/Ventas/Venta`.

No se desplegaron objetos ni se cargaron ventas en T3QA. La disponibilidad de objetos, permisos, certificados y los tiempos con el volumen real deben comprobarse en el entorno destino.
