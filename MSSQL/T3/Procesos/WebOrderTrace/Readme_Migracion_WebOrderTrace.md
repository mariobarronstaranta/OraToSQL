# Evaluación de migración de WebOrderTrace a SQL Server

Fecha: 8 de septiembre de 2026.

Requisito operativo confirmado el 9 de septiembre de 2026: conservar los nombres originales de los BAT y SQL de Oracle. La carpeta principal implementa `Reporte.Bat`, `LoadSFWO_Invoices.Bat`, `LoadSFWO_Orders.Bat`, `ExtractWebOrder.bat`, `Header.sql`, `Extract.sql` y `Extract 370 dias.sql`. Las utilidades nuevas de conexión/instalación quedan en `soporte`.

Actualización de implementación: el usuario autorizó comenzar la migración. La entrega BAT/T-SQL ya fue preparada y validada en LocalDB aislado. Las instrucciones vigentes están en [README.md](README.md). Este archivo conserva la evaluación y las decisiones previas; no acredita instalación ni pruebas en T3QA.

Restricción confirmada por el usuario: no se permite PowerShell. La solución debe conservar los archivos `.bat` como mecanismo de ejecución y coordinación.

## Dictamen y alcance

Es viable migrar WebOrderTrace a SQL Server. No se identificó una dependencia de Oracle que impida hacerlo. Las nueve tablas y la función utilizadas por el proceso existen en destino, según confirmación del usuario, y las definiciones revisadas contienen las columnas que utiliza el proceso.

La evaluación inicial se realizó mediante lectura de scripts y archivos del repositorio. Posteriormente se implementaron la carga desde el cliente, la consulta y los dos reportes, y se probaron en una base local aislada. No se comprobó directamente el despliegue ni se reemplazaron datos en T3QA. Consultar el README operativo para el alcance y los resultados de las pruebas.

El análisis del proceso Oracle está en [Readme_WebOrderTrace.md](../../../../ORA/T3/Procesos/WebOrderTrace/Readme_WebOrderTrace.md).

## 1. Alcance de la migración

| Componente actual | Adaptación necesaria |
|---|---|
| `Reporte.Bat` | Coordinar las etapas y detenerse ante errores. |
| `sqlldr` y archivos `.ctl` | Sustituir la carga por una herramienta compatible con SQL Server y un mapeo explícito de columnas. |
| `Extract.sql` | Convertir la consulta de Oracle a T-SQL, conservando cruces y reglas. |
| `EAI_OWNER.GET_CLEARING_STATUS` | Validar la equivalencia de la versión T-SQL existente. |
| `Header.sql` y `SPOOL` | Generar el CSV mediante una herramienta externa y actualizar el control del reporte. |
| Copias a `Processed` y `UploadSharePoint` | Conservar destinos y formato que requiere el consumidor. |
| Ejecución programada | Configurar cuenta, permisos, horarios y coordinación con otros procesos. |

### Objetos disponibles

El usuario confirmó la existencia de estos objetos en la base destino:

| Objeto | Tipo |
|---|---|
| `EAI_OWNER.WO_TMP_ORDER` | Tabla |
| `EAI_OWNER.WO_TMP_INVOICE` | Tabla |
| `T3.PREVENTA_GENERAL` | Tabla |
| `T3.PREVENTA_DETALLE` | Tabla |
| `T3.FACTURA_GENERAL` | Tabla |
| `T3.FACTURA_DETALLE` | Tabla |
| `EAI.TAO_CARTERA_SAP_LDR` | Tabla |
| `T3.CFDI_COBRANZA` | Tabla |
| `EAI.CONTROL_REPORTE` | Tabla |
| `EAI_OWNER.GET_CLEARING_STATUS` | Función escalar |

El flujo de WebOrderTrace no invoca procedimientos almacenados. Existen otros procedimientos que consumen las mismas tablas, descritos en la sección 3.

## 2. Adaptación de la carga de archivos

No sería suficiente cambiar `sqlldr` por un comando de importación con separador de comas.

Las tablas de SQL Server contienen columnas adicionales que no vienen en los archivos, como `ENTITY_NAME` y campos de relaciones. Además, existen diferencias entre los CSV y los controles actuales en las columnas del creador: `Order.csv` contiene 13 columnas frente a 14 del control, e `Invoice.csv` contiene 15 frente a 16. Falta la columna separada `CreatedBy` que esperan los controles, lo que desplaza el nombre e identificador del creador.

La implementación debe:

- Interpretar correctamente comillas, comas dentro de valores, encabezados y codificación.
- Mapear cada campo del archivo a su columna destino.
- Definir valores para columnas no incluidas, especialmente `INSERT_TS`.
- Validar ambos archivos antes de reemplazar los datos actuales.
- Evitar que una carga fallida deje órdenes y facturas de ejecuciones diferentes.

La carga actual utiliza `TRUNCATE INTO TABLE`: reemplaza los datos de cada tabla. Debe definirse un mecanismo de validación y reemplazo coordinado que conserve esa finalidad sin exponer datos parciales a otros consumidores.

La alternativa principal a evaluar es conservar los `.bat` e invocar `sqlcmd` para ejecutar scripts T-SQL con `BULK INSERT`, `FORMAT = 'CSV'` y una estructura intermedia que corresponda a las columnas del archivo. El soporte nativo de CSV está disponible desde SQL Server 2017. Después de validar ambos archivos, T-SQL realizaría el mapeo y reemplazo coordinado de las tablas destino. Esta opción depende de la versión del motor, los permisos de carga y el acceso del contexto de seguridad utilizado por SQL Server a los archivos.

Una ruta local al equipo que ejecuta el `.bat` no implica que SQL Server pueda leerla. Debe confirmarse una ubicación accesible desde el servidor, por ejemplo una carpeta compartida con los permisos correspondientes. En un servicio de Azure, debe evaluarse el mecanismo de almacenamiento admitido por ese servicio.

`bcp` puede ejecutarse desde un `.bat` y leer archivos del equipo donde se ejecuta. Sin embargo, una importación con separador de comas o un archivo de formato no debe asumirse equivalente a un lector general de CSV: antes de elegir esa alternativa hay que verificar comillas, comas dentro de campos y saltos de línea. Si no es posible usar la carga CSV del motor, quedará pendiente seleccionar un mecanismo compatible con el formato real y las herramientas permitidas. No se contempla PowerShell, ni directa ni indirectamente desde los `.bat`.

Referencias oficiales: [BULK INSERT](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql), [sqlcmd](https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility) y [bcp](https://learn.microsoft.com/en-us/sql/tools/bcp-utility).

### Ejecución y exportación conservando BAT

El diseño propuesto mantiene `Reporte.Bat` y los archivos BAT de carga y extracción como puntos de entrada:

1. Los `.bat` comprueban archivos de entrada e invocan `sqlcmd` para carga, validación y consulta.
2. Los scripts T-SQL propagan los errores; `sqlcmd -b` y la revisión de `ERRORLEVEL` permiten detener las etapas posteriores. Los errores capturados en T-SQL deben volver a propagarse para que el BAT los detecte.
3. La exportación puede realizarse con `bcp queryout`, generando desde SQL las líneas CSV con encabezado, orden y escape de valores explícitos. `bcp` no agrega por sí mismo el encabezado ni resuelve el escape CSV de los valores.
4. Los comandos de archivos del BAT conservan la copia histórica y la entrega final, comprobando el resultado de cada operación.

Debe definirse la conexión entre consulta y exportación: `sqlcmd` y `bcp` abren sesiones diferentes, por lo que una tabla temporal local creada por el primero no estará disponible para el segundo. La implementación deberá usar una consulta exportable o un resultado persistido e identificado por ejecución, según el diseño acordado.

La implementación final utiliza `bcp` para transportar líneas completas desde el cliente y un lector CSV en T-SQL; no requiere que el servidor pueda leer el directorio local. Las salidas se persisten por GUID para exportarlas desde otra conexión. Consultar el README operativo para los modos y los objetos auxiliares implementados.

## 3. Compatibilidad con consumidores de las tablas compartidas

`WO_TMP_INVOICE` también es consultada por estos procedimientos del repositorio SQL Server:

- [T3.PROC_T3_EOD_CONF](../../T3/Procedures/T3.PROC_T3_EOD_CONF.StoredProcedure.sql).
- [T3.PROC_T3_EOD_NOTDELV](../../T3/Procedures/T3.PROC_T3_EOD_NOTDELV.StoredProcedure.sql).

WebOrderTrace no los invoca, pero comparten su tabla de entrada. Esto amplía la revisión de compatibilidad. Su presencia en el repositorio no confirma que estén activos en destino; esa información está pendiente.

Por ejemplo, `PROC_T3_EOD_NOTDELV` compara el estado con:

```sql
Inv.Delivery_Status__c = '"Unsuccessful"'
```

Es decir, espera comillas almacenadas como parte del dato. Un lector normal de CSV entregaría `Unsuccessful` sin esas comillas. Si se cambia esa representación al cargar, este procedimiento podría dejar de encontrar registros.

Antes de implementar habría que elegir entre:

- Conservar la representación que esperan los consumidores actuales.
- Normalizar los datos y adaptar coordinadamente los consumidores afectados.

También debe respetarse `INSERT_TS`, porque `PROC_T3_EOD_CONF` consulta su valor máximo.

La decisión más importante antes de implementar es cómo cargar las tablas compartidas sin alterar lo que esperan los otros procesos.

## 4. Conversión de la consulta a T-SQL

La consulta es convertible, pero hay diferencias de comportamiento que deben revisarse.

| Oracle | Adaptación a SQL Server |
|---|---|
| Outer joins con `(+)` | `LEFT JOIN` explícitos. |
| `DECODE` | `CASE`. |
| `NVL` | `ISNULL` o `COALESCE`, revisando tipos. |
| `SUBSTR` | `SUBSTRING`. |
| `SYSDATE` y `TRUNC` | Fecha/hora y corte a medianoche equivalentes. |
| `TO_NUMBER` | Conversión decimal con validación del formato. |
| `TO_CHAR` | Formato explícito de fechas e importes. |
| Concatenación `\|\|` | Construcción equivalente o exportación de columnas. |
| `DUAL` | `SELECT` sin `FROM`. |

Los puntos que necesitan más cuidado son:

- **Nulos y cadenas vacías:** afectan referencias ZLOB, estados y concatenaciones.
- **Mayúsculas y minúsculas:** las comparaciones dependen de la intercalación de SQL Server.
- **Fechas:** conservar el corte de 35 días a medianoche y la zona horaria operativa.
- **Importes:** mantener precisión, redondeo y tolerancia de compensación menor de `0.50`.
- **Multiplicidad de cruces:** conservar el comportamiento cuando existen varias facturas o registros de cartera relacionados.

La función [GET_CLEARING_STATUS](../../EAI_OWNER/Functions/GET_CLEARING_STATUS.SQL) existente reproduce las ramas principales de compensación, pero eso todavía requiere pruebas de equivalencia con datos conocidos.

La consulta Oracle activa utiliza 35 días para los documentos de T3. Existe una variante de 370 días, pero no es la invocada por `Header.sql`. El usuario confirmó que ambas versiones son necesarias en SQL Server. Debe definirse cómo seleccionar cada periodo y evitar que sus salidas se sobrescriban accidentalmente.

## 5. Contrato del reporte de salida

Debe acordarse conservar:

- Las 26 columnas y su orden.
- El filtro `INV_DELIVERY_STATUS = 'Unsuccessful'`.
- Los formatos de fechas, importes y valores vacíos.
- El apóstrofo que actualmente se antepone a `ORD_ORDER_NUM`.
- El nombre `WebOrder_YYMMDD_HH24MI.CSV`.
- La copia final `PREVENTA_CANCELADA.csv`.
- La codificación y el tratamiento de comillas que acepta el consumidor.

La existencia de la tabla `EAI.CONTROL_REPORTE` no garantiza que exista la fila `AUTO-NOT DELIVERED`: debe verificarse ese registro.

La escritura del archivo debería completarse antes de reemplazar la salida publicada, para evitar que el siguiente proceso lea un archivo incompleto.

La ruta actual de entrega es `E:\IntegrationToolBox\UploadSharePoint\PREVENTA_CANCELADA.csv`. En el flujo revisado solamente se realiza la copia local; no se encontró el componente que publica posteriormente el archivo en SharePoint.

## 6. Validación necesaria antes de operar

La validación debe cubrir:

1. Mismos archivos y mismo corte de datos en Oracle y SQL Server.
2. Conteos y contenido cargado por columna.
3. Comparación del reporte por registros, incluyendo duplicados, importes y estados.
4. Casos de factura sin coincidencia, ZLOB ausente, compensación parcial y campos vacíos.
5. Archivo faltante, mal formado o carga interrumpida.
6. Compatibilidad con los procedimientos que comparten las tablas.
7. Lectura correcta del CSV por la integración posterior.
8. Tiempo de ejecución con volumen habitual y máximo.

La muestra disponible, de aproximadamente 2,300 filas por archivo, no indica un problema de volumen en la carga. El rendimiento del reporte dependerá principalmente del tamaño e índices de preventa, facturación, cartera y cobranza. No se ha medido en destino.

La viabilidad está confirmada a nivel de diseño y código revisado. La equivalencia funcional, el rendimiento y la operación completa quedan pendientes de validación.

## 7. Información confirmada y pendientes de implementación

| Tema | Estado |
|---|---|
| Entorno destino | Servidor `AZCRNMXNEVTD06`, base `T3QA`, versión `16.0.4265.3`, edición Developer, según información del usuario. |
| Lugar de ejecución | Los `.bat` se ejecutarán en el equipo local del usuario, distinto de `AZCRNMXNEVTD06`, dentro de una carpeta local. No se permite PowerShell y el equipo dispone de `sqlcmd` y `bcp`. La ruta absoluta no se proporcionó; se propone resolver entradas e histórico desde la ubicación del BAT mediante `%~dp0`, sin fijar una ruta de instalación. |
| Acceso a archivos | `Order.csv` e `Invoice.csv` estarán en la carpeta local de WebOrderTrace. No se ha confirmado una carpeta compartida accesible desde SQL Server. Por tanto, no debe asumirse que `BULK INSERT` podrá leer directamente esos archivos: se debe evaluar una transferencia desde el cliente mediante `bcp` con tratamiento correcto del CSV, o una ubicación compartida autorizada. |
| Entrega de archivos | El usuario desconoce el origen, la programación y la señal de finalización de entrega. Para pruebas se pueden usar archivos ya completos y ejecutar manualmente; la automatización queda pendiente. |
| Salida | El usuario confirmó conservar las rutas actuales y el mismo consumidor. El histórico será `Processed` dentro de la carpeta de ejecución de WebOrderTrace. La entrega será `E:\IntegrationToolBox\UploadSharePoint\PREVENTA_CANCELADA.csv` en el equipo local que ejecuta el BAT. Antes de las pruebas debe comprobarse que ese destino exista, sea escribible y sea leído por la integración posterior. |
| Procesos compartidos | `PROC_T3_EOD_CONF` y `PROC_T3_EOD_NOTDELV` están activos. El usuario actual informa que en la práctica no sufren interferencia; no se proporcionaron horarios ni se validó concurrencia. Se debe conservar la representación de datos que esperan. |
| Conexión | Autenticación SQL Server con el usuario `AT85233588`. No se registra la contraseña en la documentación. Los permisos efectivos para carga, reemplazo, consulta y control del reporte quedan por verificar. |
| Regla de fechas | Ambas versiones, 35 y 370 días, son necesarias. Queda por definir su selección y cuál entrega el archivo de nombre fijo al consumidor. |
| Validación | No hay acceso a Oracle. El usuario autoriza como enfoque de pruebas utilizar los datos SQL Server proporcionados. Se podrán verificar resultados contra esos datos y las reglas del código, pero no certificar equivalencia completa mediante ejecución paralela en Oracle. |

Los archivos se encuentran en el equipo cliente. La solución implementada usa `bcp` como transporte de texto y analiza el CSV en T-SQL, sin recurso compartido ni PowerShell. La salida de nombre fijo utiliza inicialmente 35 días y el reporte de 370 días queda separado, criterio pendiente de confirmación con el consumidor antes de publicar. La implementación está probada en LocalDB; no se han ejecutado pruebas ni instalado objetos en T3QA.
