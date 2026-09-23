# Migración de los reportes de ventas a SQL Server

Entrega: 10 de septiembre de 2026. Se conservan los nombres de las tres carpetas y de sus archivos operativos. Las consultas solo leen tablas; no requieren crear procedimientos, funciones ni tablas permanentes en destino. No utilizan PowerShell durante su operación.

## Carpetas y archivos

| Carpeta | BAT original conservado | SQL conservados | Columnas |
|---|---|---|---:|
| `VentaAdrianG - CFDI` | `ExtractVTAAG.bat` | `Header.sql`, `Extract.sql` | 20 |
| `VentaFelipeG` | `ExtractVTAFG.bat` | `Header.sql`, `Extract.sql` | 5 |
| `VentaFelipeG - CFDI` | `ExtractVTAAG.bat` | `Header.sql`, `Extract.sql` | 23 |

En Felipe CFDI también se conserva y actualiza `ReadMe.txt`. No se copiaron los archivos históricos de Oracle ni el contenido de `Processed`. Los BAT crean su propio directorio `Processed` cuando archivan resultados nuevos.

## Conexión

- Servidor predeterminado: `AZCRNMXNEVTD06`.
- Base predeterminada: `T3QA`, según la confirmación previa del usuario en este proyecto.
- Usuario SQL predeterminado: `AT85233588`.
- Herramienta requerida: `sqlcmd.exe`, disponible en `PATH`.
- Contraseña: se configura directamente al inicio de cada BAT, en la línea `set "SQLCMDPASSWORD="`. Se entrega vacía para completarla localmente. `sqlcmd` la recibe mediante esa variable, sin pasarla como argumento de línea de comandos.

Se puede cambiar la configuración mediante las variables `VTA_SERVER`, `VTA_DATABASE`, `VTA_USER`, `VTA_CODEPAGE` y `VTA_SQL_EXTRA`. La codificación de entrada/salida predeterminada es UTF-8 (`65001`). `VTA_TRUSTED=1` permite autenticación Windows, utilizada únicamente para las pruebas LocalDB de esta entrega.

La cuenta necesita lectura sobre las tablas utilizadas. No se requiere un recurso compartido accesible desde SQL Server: el CSV se escribe en el equipo local mediante `sqlcmd`.

### Validación de conexión a destino

Se intentó una conexión de solo lectura a T3QA. El cliente devolvió que la cadena del certificado del servidor fue emitida por una autoridad no confiable. Por ese motivo no se verificaron objetos ni resultados directamente en T3QA.

Antes de la ejecución operativa, resolver la confianza del certificado con el administrador. Si la política de la organización autoriza expresamente confiar en el certificado presentado, la opción `-C` puede configurarse mediante `VTA_SQL_EXTRA`; omite la validación de la cadena del certificado. No se activa por defecto en esta entrega.

## Operación del soporte técnico

1. Colocar cada carpeta completa en el equipo local. Los BAT resuelven su ubicación mediante `%~dp0`, por lo que admiten rutas con espacios y ejecución desde otro directorio.
2. Abrir `Extract.sql` de la carpeta correspondiente y editar solamente las dos fechas de la parte superior. Las tres variantes usan `YYYY-MM-DD` (conversión explícita con estilo 23). Ejemplo de periodo:

```sql
DECLARE @FechaInicioTexto varchar(10) = '2026-05-01';
DECLARE @FechaFinTexto    varchar(10) = '2026-06-01';
```

3. Editar el BAT y completar `set "SQLCMDPASSWORD="`, colocando la contraseña después de `=` y antes de la comilla final. Si contiene `%`, escribir `%%` por cada signo de porcentaje, debido a la sintaxis de BAT. Si se deja vacía, el proceso se detiene con un mensaje. Esta asignación sustituye cualquier contraseña heredada del entorno.
4. Guardar y ejecutar el BAT con su nombre original, también mediante doble clic. La contraseña queda configurada dentro del archivo y no requiere preparar previamente la sesión de CMD.
5. Revisar el mensaje `OK`, el CSV generado y su copia en `Processed`. Si falla, revisar `Logs`.
6. El envío por correo sigue siendo manual. Los scripts no publican en SharePoint ni envían mensajes.

El inicio del intervalo se incluye y el fin se excluye. Las fechas inválidas, vacías o con inicio mayor o igual al fin se rechazan. Los dos bloques de cada consulta CFDI comparten las variables; ya no es necesario repetir cuatro literales de fecha.

Se mantienen inicialmente los periodos guardados en Oracle: febrero de 2026 para Adrian CFDI, octubre de 2024 para Felipe y julio de 2026 para Felipe CFDI. El mes anterior no se calcula automáticamente: el operador debe seleccionar el periodo requerido.

## Salidas y control de errores

| Variante | Nombre del CSV |
|---|---|
| Adrian CFDI / Felipe CFDI | `VTA_CFDIYYMMDD_HHMM.CSV` |
| Felipe sin CFDI | `VTA_YYMMDD_HHMM.CSV` |

El nombre utiliza la fecha y hora del servidor SQL al comenzar la ejecución, no el periodo consultado. Se conserva el prefijo original, incluida la ausencia de guion bajo entre `VTA_CFDI` y la fecha.

Se corrigió la copia del original: el BAT archiva exactamente el CSV generado, en lugar de buscar `VentaDocs_*.CSV`. Cada reporte se genera primero como temporal; se archiva y se mueve a su nombre final únicamente después de que `sqlcmd` termine sin errores. Un error de consulta no publica un CSV parcial. Si falla una operación de archivos después de completar la consulta, puede quedar una copia en el histórico o un archivo `.tmp`; el log y el código de salida señalan el fallo.

La ejecución genera `Logs/Ejecucion.log` para la obtención de la fecha y un log con el nombre del reporte para la extracción. `sqlcmd -b`, `:ON ERROR EXIT` y la revisión de `ERRORLEVEL` detienen el proceso ante errores.

No se sobrescriben archivos finales del mismo minuto ni resultados históricos existentes. La carpeta `.venta_lock` impide dos ejecuciones simultáneas dentro de la misma carpeta. Los errores detectados liberan los temporales internos; si el equipo o el proceso se interrumpe abruptamente, puede quedar el bloqueo. Antes de retirarlo manualmente, comprobar que no exista otra ejecución activa.

El CSV incluye su encabezado explícito, fechas en `DD/MM/AAAA` y fechas/horas en `DD/MM/AAAA HH:MM:SS`. Los importes utilizan punto decimal, sin separador de miles ni ceros decimales innecesarios. Se escapan comas, comillas y saltos de línea dentro de campos. Las fechas y números no dependen del idioma de sesión SQL Server.

## Reglas de negocio conservadas

| Regla | Adrian CFDI | Felipe sin CFDI | Felipe CFDI |
|---|---|---|---|
| Fecha del filtro | `RF.FECHA_FACTURA` | `RF.FECHA_DOCUMENTO` | `RF.FECHA_FACTURA` |
| C003 / C005 | Signo original | Signo original | Signo original |
| C004 / C006 / C025 | Multiplica por −1 | Signo original | Multiplica por −1 |
| C0FX | Multiplica por −1 | No se incluye | Signo original |
| Bonificaciones separadas | No | No | Sí; sin invertir signo |

En Felipe CFDI, `BONIF_SUBT` y `BONIF_IVA` siguen fuera de la fórmula explícita de `TOTAL`. `FECHA_DOCUMENTO` de esa salida procede de `CD.FECHA_DOCUMENTO`; no cambia el campo usado para filtrar.

Los reportes CFDI conservan la vigencia del cliente, los `LEFT JOIN` que equivalen a los `(+)` de Oracle, las agrupaciones y `UNION ALL`. No se eliminan duplicados ni se cambian las agrupaciones por `PASO.VOIDDOC`, aunque esa columna no aparezca en el CSV.

`INCOBRABLE_NC` conserva la suma de cobranza con `FACTURA='INCOBRABLE'`, `VIA_PAGO='AI'` y nota de crédito informada, sin filtro propio de fecha. Se mantiene el reemplazo de comas del nombre del cliente y el apóstrofo en `DOC_FACTURA`.

`STATUS='Cancelled'` se excluye con comparación binaria para conservar la distinción de mayúsculas/minúsculas del literal. Los estados nulos quedan excluidos, como en la comparación original. Las relaciones de identificadores usan la intercalación de la base; debe comprobarse con los datos reales si existen claves que difieran solo por mayúsculas/minúsculas.

No se corrigieron ni reinterpretaron las diferencias de negocio señaladas en el documento de contexto. Cualquier unificación del signo de C0FX, bonificaciones o fechas requiere una decisión funcional adicional.

## Objetos requeridos

Felipe sin CFDI consulta `T3.REGISTRO_FISCAL` y `T3.REGISTRO_FISCAL_DETALLE`.

Las variantes CFDI consultan además `T3.CLIENTE`, `T3.CFDI_HISTORIA_DOCTO_PAC`, `T3.CFDI_DOCUMENTOS`, `T3.CFDI_DOCUMENTO_PASO` y `T3.CFDI_COBRANZA`.

Se localizaron las definiciones de los siete objetos en el repositorio MSSQL y se utilizaron para las pruebas aisladas. No hay funciones de negocio ni procedimientos almacenados invocados por estas extracciones.

## Pruebas y límites

Pruebas realizadas en SQL Server LocalDB 17.0.4025.3, con compatibilidad 160 y copias de las definiciones del repositorio:

- Ejecución de los tres BAT, incluidos nombres de carpetas con espacios.
- Reportes de 20, 5 y 23 columnas, respectivamente.
- Signos de ventas, documentos de crédito y C0FX; bonificaciones sin invertir signo ni incorporarse al total.
- Inicio incluido, fin excluido, documentos cancelados, cliente no vigente/no encontrado y diferencia entre fecha de documento y factura.
- Cruces opcionales sin CFDI y multiplicidad de `VOIDDOC` conservada.
- Incobrables de una fecha anterior al periodo del reporte.
- Campos con acentos, comas, comillas y CRLF; encabezados y copia histórica idéntica al CSV final.
- Fecha inválida: salida de error, sin CSV publicado y con liberación del bloqueo.

Los datos ficticios produjeron 5 filas para Adrian CFDI, 4 para Felipe y 5 para Felipe CFDI, además de sus encabezados. Estos conteos son de prueba, no corresponden a ventas reales.

No se modificaron datos de T3QA. La prueba directa en motor 16.0.4265.3 queda pendiente de resolver el certificado de conexión. No se dispone de acceso a Oracle para comparar ejecuciones reales en ambos motores; el rendimiento con el volumen operativo y los resultados de negocio deben validarse en destino.
