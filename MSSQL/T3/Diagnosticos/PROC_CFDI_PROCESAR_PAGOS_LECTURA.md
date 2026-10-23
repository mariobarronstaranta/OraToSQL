# Captura de lectura para pruebas de PROC_CFDI_PROCESAR_PAGOS

Abrir `PROC_CFDI_PROCESAR_PAGOS_LECTURA.sql` en SSMS y seleccionar la base real
que se desea analizar. El script no cambia la base seleccionada y la muestra
en su primer resultado. Ejecutarlo completo en una misma ventana, sin agregar GO.

## Parametros

En el encabezado se puede indicar la fecha del lote:

```sql
DECLARE @FechaProc date='2026-10-22'; -- Sustituir por un dia real con asignaciones.
DECLARE @Factura varchar(30)=NULL;   -- O indicar una factura concreta.
```

Si @FechaProc se deja NULL, busca el dia mas reciente con asignaciones en los
ultimos 30 dias respecto al reloj del servidor. Si no hay datos en ese periodo,
solicita indicar una fecha; aun devuelve ambiente, metadatos y definiciones.
Con @Factura informado, la busqueda automatica de fecha se limita a esa factura.

La primera captura elige hasta ocho facturas, priorizando las que tienen mas
asignaciones del dia. No garantiza cubrir todos los tipos de documento. Para
ampliar casos, repetir con una factura concreta de cada ruta que exista:
nota de venta con UUID, factura con varios pagos/CM, PendienteT3,
penalizacion, cancelacion o INCOBRABLE. No se necesita inventar facturas si no
existe alguna ruta en esa base.

## Resultados a compartir

Guardar **todos los resultados y los mensajes** en un archivo de texto o RPT.
En SSMS se puede usar Resultados a archivo (Ctrl+Shift+F) antes de ejecutar.
Conservar titulos, nombres de columna y secciones vacias; no enviar solo capturas
de pantalla o el ultimo resultado. Las definiciones se dividen en fragmentos
de 180 caracteres para reducir el truncamiento por columna. El script requiere
SQL Server 2022 por STRING_SPLIT con ordinal, coherente con la version conocida
de T3QA; el primer resultado identifica la version realmente consultada.

| Secciones | Para que se usan |
| --- | --- |
| 01-05 | Version, compatibilidad, collation, alcance por defecto de cursores, tipos, definiciones instaladas y presencia de triggers. |
| 06-07 | Reproducir el enlace de la variable antes/despues de DECLARE sin ejecutar el procedimiento de negocio. |
| 08-13 | Lote y muestra elegidos, cobertura del historial, asignaciones y vigencias con hora frente a DATE. |
| 14-17 | Pagos, clasificacion y detalle fiscal que alimenta FN_TOTAL_FACT. |
| 18-24 | Factura/preventa, detalle, historia PAC, UUID y cancelaciones relacionadas. |
| 25 | Cobranza existente para contrastar saldo y parcialidades; no se genera nueva cobranza. |
| 26-29 | Catalogos aplicables, ejecuciones y errores de los ultimos siete dias y fin de captura. |

El historial se limita a las **200 asignaciones mas recientes por factura**.
La seccion 11 indica expresamente si esta completo o truncado. Si aparece
TRUNCADO, aumentar @MaxHistorialPorFactura o enfocar una factura antes de intentar
reproducir su saldo completo. Las tablas de detalle y cobranza se leen para las
facturas seleccionadas, sin eliminar duplicados existentes. Los fragmentos de
definiciones permiten comprobar que lo instalado coincide con el fuente local.

## Alcance de lectura

Solo hace SELECT sobre tablas/metadatos reales e INSERT en variables locales
del lote. Los dos cursores de diagnostico son LOCAL y usan un valor constante,
sin crear procedimientos ni objetos persistentes. No ejecuta FN_TOTAL_FACT,
PROCESAR_PAGOS, el control posterior, jobs ni cambios de estado. Omite bancos
y cuentas de los resultados; sus longitudes se conservan donde aplica.
No usa NOLOCK ni solicita una transaccion; lecturas concurrentes pueden esperar
por bloqueos y las secciones pueden reflejar momentos distintos. Los resultados
deben interpretarse como muestra, no como auditoria completa de la base.

## Validacion local

Se ejecuto completo sobre la base temporal de la prueba sintetica, con las tablas
reales del repositorio y collation distinta de la instancia. Se verificaron las
secciones principales, la exportacion de definiciones y la ausencia de cambios
en asignaciones, cobranza, bitacoras y estados de componentes de la muestra.
La base temporal fue eliminada. El diagnostico paso; esto no cambia el resultado
fallido de la prueba funcional de los cursores del procedimiento.

Ejecutor reproducible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File MSSQL/T3/T3/Procedures/tests/PROC_CFDI_PROCESAR_PAGOS/Run.ps1 -SoloLectura
```

El modo -SoloLectura guarda su evidencia en `LastRead.txt`. El modo funcional
conserva su propia evidencia en `LastRun.txt` y falla si detecta resultados
incorrectos aun sin excepciones SQL del procedimiento.
